extends Node
signal achievement_unlocked(key: String)
var in_transaction := false
var closing := false
## Local profiles, idempotent rewards and deterministic expedition decisions.
const VERSION := 1
var slot := 1
var profile: Dictionary = {}
var pending: Dictionary = {}
var resume_snapshot: Dictionary = {}
var notice := ""
var shared := {"sound": true, "music": true, "shake": true, "volume": 0.75, "fullscreen": false}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") == OK:
		shared.sound = cfg.get_value("settings", "sound", true)
		shared.music = cfg.get_value("settings", "music", true)
		shared.shake = cfg.get_value("settings", "shake", true)
		shared.volume = cfg.get_value("settings", "volume", 0.75)
		shared.fullscreen = cfg.get_value("settings", "fullscreen", false)
	load_profile(1)
	apply_settings()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not closing: close_game()

func close_game() -> void:
	closing = true
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("save_prepare") and scene.get("managed") and scene.get("phase") == 0:
		if not scene.save_prepare():
			closing = false
			scene.show_overlay("保存失败", notice, "继续防守")
			return
	if scene != null: scene.set_process(false)
	stop_audio(get_tree().root)
	if scene != null: scene.queue_free()
	# Give the audio mixer a tick to release playback references before shutdown.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer:
		node.stop()
		node.stream = null
	for child in node.get_children(): stop_audio(child)

func fresh() -> Dictionary:
	var legacy := ConfigFile.new()
	legacy.load("user://settings.cfg")
	return {"version": VERSION, "records": {}, "logs": [], "achievements": [], "choices": {}, "badges": 0, "owned": [], "cosmetics": {}, "counters": {"rail": 0, "boons": []}, "seen": [], "results": [], "suspend": {}, "active_request": {}, "expedition": {}, "loadout": [0], "module": "", "prototype_best": legacy.get_value("records", "waves", 0)}

func path() -> String:
	return "user://profile_%d.json" % slot

func load_profile(index: int) -> void:
	notice = ""
	slot = clampi(index, 1, 3)
	profile = fresh()
	pending = {}
	resume_snapshot = {}
	var file_path := path()
	if not FileAccess.file_exists(file_path): return
	var loaded = parse_json(FileAccess.get_file_as_string(file_path))
	if not valid_profile(loaded):
		loaded = parse_json(FileAccess.get_file_as_string(file_path + ".bak")) if FileAccess.file_exists(file_path + ".bak") else null
		notice = "档案异常，已尝试恢复备份。原文件保留为 .damaged。"
		DirAccess.copy_absolute(file_path, file_path + ".damaged")
	if valid_profile(loaded):
		profile.merge(loaded, true)
	else:
		notice += " 无可用备份，使用空档案。"

func parse_json(value: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(value) != OK: return null
	return parser.data

func valid_profile(value: Variant) -> bool:
	if not value is Dictionary or value.get("version", 0) != VERSION: return false
	for key in ["records", "choices", "counters", "suspend", "active_request", "expedition", "cosmetics"]:
		if not value.get(key) is Dictionary: return false
	for key in ["logs", "achievements", "seen", "results", "owned", "loadout"]:
		if not value.get(key) is Array: return false
	return true

func save() -> bool:
	var target := path()
	var file := FileAccess.open(target + ".tmp", FileAccess.WRITE)
	if file == null:
		notice = "存档写入失败：%s" % error_string(FileAccess.get_open_error())
		return false
	file.store_string(JSON.stringify(profile))
	file.close()
	if FileAccess.file_exists(target) and valid_profile(parse_json(FileAccess.get_file_as_string(target))):
		DirAccess.copy_absolute(target, target + ".bak")
	var error := DirAccess.rename_absolute(target + ".tmp", target)
	if error != OK: notice = "存档替换失败：" + error_string(error)
	return error == OK

func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.001, float(shared.volume))))
	if DisplayServer.get_name() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if shared.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load("user://settings.cfg")
	for key in shared: cfg.set_value("settings", key, shared[key])
	cfg.save("user://settings.cfg")
	apply_settings()

func unlocked(index: int) -> bool:
	return index == 1 or profile.records.has(str(index - 1))

func id() -> String:
	return "%d-%d-%d" % [Time.get_unix_time_from_system(), Time.get_ticks_usec(), randi()]

func award(key: String) -> void:
	if not GameCatalog.ACHIEVEMENTS.has(key): return
	if not profile.achievements.has(key):
		profile.achievements.append(key)
		achievement_unlocked.emit(key)
		if not in_transaction: save()

func rail_kill(event_id: String) -> void:
	if profile.seen.has(event_id): return
	profile.seen.append(event_id)
	profile.counters.rail += 1
	if profile.counters.rail >= GameCatalog.achievement("rail").target: award("rail")
	save()

func valid_loadout(loadout: Array, module: String) -> bool:
	if loadout.is_empty() or loadout.size() > 3 or not GameCatalog.unlocked_modules(profile).has(module): return false
	var seen := {}
	for value in loadout:
		var number := int(value)
		if seen.has(number) or not GameCatalog.unlocked_towers(profile).has(number): return false
		seen[number] = true
	return true

func begin_mission(index: int, loadout: Array, module: String, choice := "crew") -> bool:
	if index < 1 or index > 6 or not unlocked(index) or not valid_loadout(loadout, module): return false
	profile.loadout = loadout.duplicate()
	profile.module = module
	pending = {"mode": "campaign", "mission": index, "loadout": loadout.duplicate(), "module": module, "choice": choice, "id": id(), "seed": str(randi())}
	profile.active_request = pending.duplicate(true)
	profile.suspend = {}
	resume_snapshot = {}
	return save()

func continue_battle() -> bool:
	if profile.active_request.is_empty(): return false
	pending = profile.active_request.duplicate(true)
	resume_snapshot = profile.suspend.duplicate(true)
	return true

func checkpoint(snapshot: Dictionary) -> bool:
	profile.suspend = snapshot.duplicate(true)
	return save()

func settle(result: Dictionary) -> bool:
	if profile.results.has(result.id): return false
	in_transaction = true
	profile.results.append(result.id)
	profile.suspend = {}
	profile.active_request = {}
	if result.mode == "campaign" and result.won:
		var key := str(int(result.mission))
		var old: Dictionary = profile.records.get(key, {})
		var first := old.is_empty()
		var medals: Array = old.get("medals", [false, false, false]).duplicate()
		for i in 3: medals[i] = bool(medals[i]) or bool(result.medals[i])
		profile.records[key] = {"medals": medals, "best_time": minf(old.get("best_time", INF), result.elapsed), "kills": maxi(old.get("kills", 0), result.kills)}
		if first: profile.choices[key] = {"choice": result.choice, "optional": result.medals[2]}
		for log_id in [key + "a", key + "b" if result.medals[2] else ""]:
			if log_id != "" and not profile.logs.has(log_id): profile.logs.append(log_id)
		award("first")
		if int(result.mission) == 3: award("depth")
		if int(result.mission) == 6:
			award("ending")
			if not profile.owned.has("ending_core"): profile.owned.append("ending_core")
		if profile.logs.size() == 12: award("logs")
	if result.won and result.get("core_damage", 1) == 0: award("untouched")
	if result.mode == "expedition":
		var run: Dictionary = profile.expedition
		if not run.is_empty():
			if result.won:
				run.stash += [10, 15, 25][int(run.cleared)]
				run.cleared += 1
				run.status = "safe"
				if run.cleared == 3:
					profile.badges += run.stash
					award("expedition")
					if run.hard: award("hard")
					profile.expedition = {}
			else: profile.expedition = {}
	in_transaction = false
	save()
	return true

func start_expedition(loadout: Array, module: String, hard: bool) -> bool:
	if not profile.records.has("3") or (hard and not profile.records.has("6")) or not valid_loadout(loadout, module): return false
	var random := RandomNumberGenerator.new()
	random.randomize()
	var run_seed := str(random.seed)
	var offers: Array = []
	var taken: Array = []
	for stage in 2:
		var available := GameCatalog.BOON_IDS.duplicate()
		for j in range(available.size() - 1, 0, -1):
			var pick := random.randi_range(0, j)
			var temp = available[j]; available[j] = available[pick]; available[pick] = temp
		offers.append({"boons": available.slice(0, 3), "event": GameCatalog.EVENT_IDS[random.randi_range(0, 7)], "routes": [{"map": [1, 3, 5][random.randi_range(0, 2)], "modifier": GameCatalog.MODIFIERS.keys()[random.randi_range(0, 3)]}, {"map": [1, 3, 5][random.randi_range(0, 2)], "modifier": GameCatalog.MODIFIERS.keys()[random.randi_range(0, 3)]}]})
	for offer in offers:
		if offer.routes[0] == offer.routes[1]:
			var keys := GameCatalog.MODIFIERS.keys()
			offer.routes[1].modifier = keys[(keys.find(offer.routes[0].modifier) + 1) % keys.size()]
	profile.expedition = {"id": id(), "seed": run_seed, "hard": hard, "cleared": 0, "stash": 0, "status": "ready", "loadout": loadout.duplicate(), "module": module, "boons": taken, "effects": {}, "offers": offers, "decisions": {}, "route": {"map": 1, "modifier": "swarm"}}
	profile.suspend = {}
	profile.active_request = {}
	return save()

func choose_boon(key: String) -> bool:
	var run: Dictionary = profile.expedition
	if run.is_empty() or run.status != "safe" or run.cleared >= 3: return false
	var step := str(int(run.cleared))
	var decision: Dictionary = run.decisions.get(step, {})
	if decision.has("boon") or run.boons.has(key) or not run.offers[int(run.cleared) - 1].boons.has(key): return false
	decision.boon = key
	run.decisions[step] = decision
	run.boons.append(key)
	if not profile.counters.boons.has(key): profile.counters.boons.append(key)
	if profile.counters.boons.size() >= GameCatalog.achievement("boons").target: award("boons")
	return save()

func choose_event(index: int) -> bool:
	var run: Dictionary = profile.expedition
	if run.is_empty() or run.status != "safe" or index < 0 or index > 1: return false
	var step := str(int(run.cleared))
	var decision: Dictionary = run.decisions.get(step, {})
	if decision.has("event"): return false
	var event := GameCatalog.card(run.offers[int(run.cleared) - 1].event)
	decision.event = index
	run.decisions[step] = decision
	for key in event.alternatives[index]:
		if key == "stash": run.stash += int(event.alternatives[index][key])
		else: run.effects[key] = run.effects.get(key, 0.0) + event.alternatives[index][key]
	return save()

func choose_route(index: int) -> bool:
	var run: Dictionary = profile.expedition
	if run.is_empty() or run.status != "safe" or index < 0 or index > 1: return false
	var step := str(int(run.cleared))
	var decision: Dictionary = run.decisions.get(step, {})
	if decision.has("route"): return false
	decision.route = index
	run.decisions[step] = decision
	run.route = run.offers[int(run.cleared) - 1].routes[index].duplicate(true)
	return save()

func launch_expedition() -> bool:
	var run: Dictionary = profile.expedition
	if run.is_empty() or not profile.active_request.is_empty(): return false
	if run.cleared > 0:
		var decision: Dictionary = run.decisions.get(str(int(run.cleared)), {})
		if decision.size() != 3: return false
	var effects: Dictionary = run.effects.duplicate(true)
	for key in run.boons:
		for stat in GameCatalog.card(key).effects: effects[stat] = effects.get(stat, 0.0) + GameCatalog.card(key).effects[stat]
	pending = {"mode": "expedition", "mission": int(run.route.map), "loadout": run.loadout.duplicate(), "module": run.module, "id": run.id + ":" + str(int(run.cleared)), "seed": str(int(run.seed) + int(run.cleared) * 7919), "stage": run.cleared, "modifier": run.route.modifier, "hard": run.hard, "effects": effects, "choice": "crew"}
	run.status = "battle"
	profile.active_request = pending.duplicate(true)
	profile.suspend = {}
	resume_snapshot = {}
	return save()

func extract() -> bool:
	var run: Dictionary = profile.expedition
	if run.is_empty() or run.status != "safe" or run.cleared < 1: return false
	profile.badges += run.stash
	profile.expedition = {}
	profile.suspend = {}
	profile.active_request = {}
	award("extract")
	return save()

func buy(key: String) -> bool:
	if not GameCatalog.SHOP.has(key) or profile.owned.has(key): return false
	var item: Dictionary = GameCatalog.SHOP[key]
	if profile.badges < item.price: return false
	profile.badges -= item.price
	profile.owned.append(key)
	profile.cosmetics[item.slot] = key
	return save()
