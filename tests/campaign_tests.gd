extends SceneTree
var checks := 0
var failures := 0
var store: Node

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func create_game():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.started = true
	game.overlay.hide()
	return game

func run() -> void:
	store = root.get_node("Campaign")
	store.shared.music = false
	store.slot = 3
	store.profile = store.fresh()
	store.pending = {}
	store.resume_snapshot = {}
	check(not store.begin_mission(2, [0], ""), "Locked mission cannot start")
	check(not store.begin_mission(1, [6], ""), "Locked tower cannot be carried")
	check(not store.begin_mission(1, [0, 0], ""), "Duplicate loadout rejected")
	check(not store.start_expedition([0], "", false), "Expedition locked before mission three")
	check(store.begin_mission(1, [0], ""), "Initial mission starts")
	var game = create_game()
	check(game.managed and game.waves.size() == 4, "Campaign replaces legacy ten-wave mission")
	check(not game.place_building(Vector2i(3, 2), 0), "Rock prevents building")
	check(not game.board.distance.has(Vector2i(3, 2)), "Rock excluded from flow field")
	check(not game.place_building(Vector2i(13, 7), 1), "Unavailable loadout cannot be built")
	check(game.place_building(Vector2i(13, 7), 0), "Carried gun is available")
	game.alloy = 400
	game.board.selected = Vector2i(13, 7)
	game.upgrade_selected()
	game.selected_tower().hp -= 17
	game.place_building(Vector2i(10, 9), 4)
	game.board.buildings[Vector2i(10, 9)].mining_timer = 2.75
	game.timer = 21.5
	game.take_core_damage(27, "工虫")
	var money: int = game.alloy
	var state: String = str(game.rng.state)
	check(game.save_prepare(), "Preparation snapshot saved")
	var saved: Dictionary = store.profile.suspend.duplicate(true)
	game.start_wave()
	game._process(0.1)
	var first: AlienBug = game.enemies[0]
	var first_position := first.position
	var first_kind: EnemyData = first.data
	game.queue_free()
	await process_frame
	store.load_profile(3)
	check(store.continue_battle(), "Profile reload can resume")
	game = create_game()
	check(game.wave == 0 and game.phase == game.Phase.PREPARE and game.timer == 21.5, "Resume restores exact preparation")
	check(game.alloy == money and game.core_hp == 573, "Resume restores money and core")
	var tower: DefenseTower = game.board.buildings[Vector2i(13, 7)]
	check(tower.level == 2 and tower.hp == tower.max_health() - 17, "Upgrade and damage restored")
	check(game.board.buildings[Vector2i(10, 9)].mining_timer == 2.75, "Partial mining restored")
	check(str(game.rng.state) == state, "RNG state survives JSON serialization without precision loss")
	game.start_wave()
	game._process(0.1)
	check(game.enemies[0].data == first_kind and game.enemies[0].position == first_position, "Reload cannot reroll first spawn")
	game.finish(false)
	check(store.profile.records.is_empty() and store.profile.suspend.is_empty(), "Failure clears attempt but does not unlock missions")
	game.queue_free()
	await process_frame
	# Execute all six actual wave sets with a deliberately strong test defense.
	for index in range(1, 7):
		var available := GameCatalog.unlocked_towers(store.profile)
		var loadout: Array = []
		for kind in [1, 6, 5, 0, 2]:
			if available.has(kind) and loadout.size() < 3: loadout.append(kind)
		check(store.begin_mission(index, loadout, "", "evidence"), "Mission %d accepts unlocked configuration" % index)
		game = create_game()
		game.alloy = 100000
		for y in range(2, 14, 2):
			for x in range(3, 26, 3):
				if Vector2i(x, y) == game.board.marker: continue
				var kind: int = loadout[(x + y) % loadout.size()]
				if game.place_building(Vector2i(x, y), kind):
					game.board.selected = Vector2i(x, y)
					game.upgrade_selected()
					game.upgrade_selected()
		for y in range(6, 11):
			for x in range(11, 18):
				if Vector2i(x, y) == game.board.marker: continue
				if game.station_count() < 3: game.place_building(Vector2i(x, y), 4)
		if game.board.inside(game.board.marker): game.place_building(game.board.marker, loadout[0])
		var ticks := 0
		while game.phase < game.Phase.VICTORY and ticks < 15000:
			if game.phase == game.Phase.PREPARE: game.start_wave()
			game._process(0.15)
			for miner in game.board.buildings.values(): game.collect_miner(miner)
			ticks += 1
		check(game.phase == game.Phase.VICTORY, "Mission %d actual combat reaches its completion" % index)
		check(store.profile.records.has(str(index)), "Mission %d persists its record" % index)
		check(store.profile.suspend.is_empty(), "Mission %d clears active checkpoint on completion" % index)
		if index == 3: check(game.mined_total >= 160, "Mining mission counts actual production")
		var flags: Dictionary = store.profile.choices.duplicate(true)
		var result := {"id": game.request.id, "mode": "campaign", "mission": index, "won": true, "medals": [true, true, true], "elapsed": 1, "kills": 1, "choice": "crew", "core_damage": 0}
		check(not store.settle(result) and store.profile.choices == flags, "Duplicate settlement cannot replace story flags")
		game.queue_free()
		await process_frame
	check(store.profile.logs.size() == 12 and store.profile.achievements.has("logs"), "All twelve logs are reachable through optional goals")
	check(GameCatalog.unlocked_towers(store.profile).size() == 5, "All five towers obtainable without grinding")
	check(GameCatalog.unlocked_modules(store.profile).size() == 4, "Three modules and no-module choice unlocked")
	check(store.profile.achievements.has("ending") and store.profile.owned.has("ending_core"), "Campaign ending awards commemorative cosmetic")
	var fixed_choices: Dictionary = store.profile.choices.duplicate(true)
	store.begin_mission(5, [0, 1, 6], "", "crew")
	game = create_game(); game.finish(true); game.queue_free()
	await process_frame
	check(store.profile.choices == fixed_choices, "A fresh replay cannot change first-clear story choices")
	# Mining failure is distinct from core defeat.
	store.begin_mission(3, [0, 1, 2], "")
	game = create_game()
	game.cleared = 8
	game.finish(true)
	check(game.phase == game.Phase.DEFEAT, "Survival alone does not satisfy mining quota")
	game.queue_free()
	await process_frame
	# Module prices, effects, healing once per wave and checkpoint restoration.
	store.begin_mission(4, [0, 1, 5], "scout")
	game = create_game()
	check(is_equal_approx(game.core_max, 540) and game.warning_bonus == 1, "Scout trades health for warning time")
	var burrow: AlienBug = game.spawn_enemy(game.waves[0], 4)
	check(is_equal_approx(burrow.emerging, 2.8), "Scout affects actual emergence")
	game.queue_free()
	await process_frame
	store.begin_mission(4, [0, 1, 5], "industry")
	game = create_game()
	check(game.miner_limit == 4 and game.alloy == 150, "Industry trades starting money for a fourth miner")
	game.queue_free()
	await process_frame
	store.begin_mission(5, [0, 1, 6], "emergency")
	game = create_game()
	game.wave = 1
	game.take_core_damage(430, "工虫")
	check(game.core_hp == 230 and game.alloy == 160, "Emergency spends twenty to heal ten percent")
	game.take_core_damage(80, "工虫")
	check(game.core_hp == 150 and game.alloy == 160, "Emergency only triggers once in the wave")
	game.phase = game.Phase.PREPARE
	game.save_prepare()
	game.queue_free()
	await process_frame
	store.continue_battle()
	game = create_game()
	check(game.emergency_waves.has(1) and game.core_damage == 510, "Emergency usage and cumulative damage survive loading")
	game.queue_free()
	await process_frame
	# Real combat events feed achievement counters once, including after reload.
	store.begin_mission(5, [5, 6, 0], "")
	game = create_game()
	for i in 10:
		var enemy: AlienBug = game.spawn_enemy(game.waves[0], 2)
		game.hit_enemy(enemy, 10000, "piercing")
	var rail_count: int = store.profile.counters.rail
	store.rail_kill(game.enemies[-1].combat_id)
	check(store.profile.counters.rail == rail_count and store.profile.achievements.has("rail"), "Rail kills are deduplicated and achievement unlocks")
	var shield: AlienBug = game.spawn_enemy(game.waves[0], 6)
	game.hit_enemy(shield, 1000, "energy")
	check(store.profile.achievements.has("shield"), "Actual energy shield break unlocks achievement")
	game.finish(false)
	check(store.profile.achievements.has("rail"), "Defeat keeps already earned achievements")
	game.queue_free()
	await process_frame
	# Expedition: frozen offers, single decisions, safe withdrawal, win/failure rewards.
	check(store.start_expedition([0, 1, 6], "", false), "Expedition can start after campaign unlock")
	var original_offers: Array = store.profile.expedition.offers.duplicate(true)
	store.load_profile(3)
	check(store.profile.expedition.offers == JSON.parse_string(JSON.stringify(original_offers)), "Reload preserves exact event and route offers")
	check(store.launch_expedition(), "First expedition stage starts")
	game = create_game()
	check(game.request.mode == "expedition" and game.waves.size() == 5, "Expedition uses independent short wave set")
	game.finish(true)
	game.queue_free()
	await process_frame
	check(store.profile.expedition.stash == 10 and store.profile.expedition.status == "safe", "First stage safely holds ten unbanked badges")
	check(not store.launch_expedition(), "Cannot skip choices at safe node")
	var boon: String = store.profile.expedition.offers[0].boons[0]
	check(store.choose_boon(boon) and not store.choose_boon(boon), "Boon choice can only be applied once")
	check(store.choose_event(0) and not store.choose_event(1), "Event cannot be replayed for repeated reward")
	check(store.choose_route(0) and not store.choose_route(1), "Route is locked after selection")
	var safe_decisions: Dictionary = store.profile.expedition.decisions.duplicate(true)
	store.load_profile(3)
	check(store.profile.expedition.decisions == JSON.parse_string(JSON.stringify(safe_decisions)), "Safe-node choices survive closing and loading")
	check(store.launch_expedition(), "Selected route proceeds")
	game = create_game()
	check(game.battle_bonus.has(GameCatalog.card(boon).effects.keys()[0]), "Chosen boon reaches actual battle stats")
	game.finish(false)
	game.queue_free()
	await process_frame
	check(store.profile.expedition.is_empty() and store.profile.badges == 0, "Failure loses unbanked expedition loot")
	check(store.profile.records.size() == 6, "Expedition failure keeps campaign progress")
	store.start_expedition([0, 1, 6], "", false)
	store.launch_expedition()
	game = create_game(); game.finish(true); game.queue_free()
	await process_frame
	check(store.extract() and store.profile.badges == 10 and not store.extract(), "Withdrawal banks once and cannot be duplicated")
	check(store.profile.achievements.has("extract"), "Withdrawal achievement unlocked")
	store.start_expedition([0, 1, 6], "", true)
	for stage in 3:
		if stage > 0:
			var offer: Dictionary = store.profile.expedition.offers[stage - 1]
			for candidate in offer.boons:
				if not store.profile.expedition.boons.has(candidate): store.choose_boon(candidate); break
			store.choose_event(1)
			store.choose_route(1)
		check(store.launch_expedition(), "Hard expedition node %d launches" % stage)
		game = create_game()
		game.alloy = 100000
		for y in range(2, 14, 2):
			for x in range(3, 26, 3):
				if game.place_building(Vector2i(x, y), 1):
					game.board.selected = Vector2i(x, y); game.upgrade_selected(); game.upgrade_selected()
		var ticks := 0
		while game.phase < game.Phase.VICTORY and ticks < 15000:
			if game.phase == game.Phase.PREPARE: game.start_wave()
			game._process(0.15); ticks += 1
		check(game.phase == game.Phase.VICTORY, "Hard expedition node %d real combat completes" % stage)
		game.queue_free()
		await process_frame
	check(store.profile.expedition.is_empty() and store.profile.badges >= 60 and store.profile.achievements.has("hard"), "Final stage banks full run and unlocks hard achievement")
	var badges: int = store.profile.badges
	check(store.buy("core_amber") and store.profile.badges == badges - 50, "Cosmetic purchase has fixed price")
	check(not store.buy("core_amber"), "Owned cosmetic cannot be bought twice")
	store.save()
	var slot_three_records: int = store.profile.records.size()
	store.load_profile(2)
	check(store.profile.records.is_empty(), "Profiles keep campaign progress independent")
	store.load_profile(3)
	check(store.profile.records.size() == slot_three_records, "Switching profiles restores progress")
	# Render/build every shell page and both types of loadout configuration.
	var shell = load("res://scenes/shell.tscn").instantiate()
	root.add_child(shell)
	for name in ["bridge", "missions", "equipment", "archive", "achievements", "shop", "settings", "expedition"]:
		shell.show_page(name)
		check(shell.content.get_child_count() > 0, "Shell page %s has content" % name)
	shell.prepare(5)
	shell.prepare_expedition(false)
	shell.queue_free()
	await process_frame
	store.save()
	var healthy_path: String = store.path()
	var broken := FileAccess.open(healthy_path, FileAccess.WRITE)
	broken.store_string("{broken")
	broken.close()
	store.load_profile(3)
	check(store.profile.records.size() == 6 and not store.notice.is_empty(), "Corrupt main profile restores the last valid backup")
	check(FileAccess.file_exists(healthy_path + ".damaged"), "Damaged profile is preserved for inspection")
	await create_timer(0.2).timeout
	print("CAMPAIGN CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)

