extends Node2D
## Main coordinator. Buildings and enemies are scenes, balance lives in data/.
signal economy_changed
signal status_changed
enum Phase { PREPARE, ATTACK, VICTORY, DEFEAT }
const TOWER_SCENE = preload("res://scenes/tower.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BUILDINGS = [preload("res://data/gun.tres"), preload("res://data/cannon.tres"), preload("res://data/slow.tres"), preload("res://data/wall.tres"), preload("res://data/miner.tres"), preload("res://data/tesla.tres"), preload("res://data/sniper.tres")]
const BUGS = [preload("res://data/bug.tres"), preload("res://data/runner.tres"), preload("res://data/armored.tres"), preload("res://data/boss.tres"), preload("res://data/burrow.tres"), preload("res://data/spitter.tres"), preload("res://data/shield.tres"), preload("res://data/splitter.tres")]
var mines: Array = []
var strike_cooldown := 0.0
var action_mode := ""
var action_button: Button
var managed := false
var request: Dictionary = {}
var mission: MissionData
var core_max := 600.0
var core_damage := 0.0
var damage_sources: Dictionary = {}
var mined_total := 0
var spawn_serial := 0
var emergency_waves: Array = []
var miner_limit := 3
var mining_yield := 4
var damage_multiplier := 1.0
var speed_multiplier := 1.0
var warning_bonus := 0.0
var battle_bonus: Dictionary = {}
var mission_hud: Label
var achievement_toast: Label
var toast_time := 0.0
var result_return: Button
var result_retry: Button
var waves: Array[WaveData] = []
const MINER_LIMIT := 3
const MINING_INTERVAL := 5.0
const MINING_YIELD := 4
var board: BattleBoard
var enemies: Array[AlienBug] = []
var phase := Phase.PREPARE
var alloy := 180
var core_hp := 600.0
var wave := 0
var cleared := 0
var kills := 0
var elapsed := 0.0
var timer := 40.0
var spawn_timer := 0.0
var spawned := 0
var last_clear_reward := 0
var rewarded_wave := 0
var evacuation := false
var paused := false
var started := false
var selected_type := 0
var effects: Array[Dictionary] = []
var effect_layer: Node2D
var rng := RandomNumberGenerator.new()
var font: SystemFont
var hud: Label
var hint: Label
var details: Label
var next_button: Button
var pause_button: Button
var upgrade_button: Button
var repair_button: Button
var sell_button: Button
var build_buttons: Array[Button] = []
var overlay: ColorRect
var overlay_title: Label
var overlay_body: Label
var overlay_button: Button
var shake_enabled := true
var best := 0
var sound_enabled := true
var music: AudioStreamPlayer
var audio: AudioStreamPlayer
var shot_sound: AudioStreamWAV
var sound_cooldown := 0.0
var ui_timer := 0.0
var preview_signature: Array = []

func _ready() -> void:
	rng.randomize()
	for i in range(1, 11):
		waves.append(load("res://data/wave_%02d.tres" % i))
	load_settings()
	board = BattleBoard.new()
	add_child(board)
	configure_mission()
	effect_layer = Node2D.new()
	add_child(effect_layer)
	effect_layer.draw.connect(draw_effects)
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	make_audio()
	make_ui()
	economy_changed.connect(refresh_ui)
	status_changed.connect(refresh_ui)
	refresh_ui()
	show_overlay("异星撤离", "采矿前哨已被虫群发现。守住核心，等待撤离。\n\n① 左侧网格自由建塔，四周红色区域禁止建造。\n② 采矿进攻时生产，点击采矿机收货。\n③ 按空格暂停并布防，按 Enter 开始下一波，无准备倒计时。\n④ 点击建筑可升级、维修或出售。\n\n注意地下裂隙与远程敌人；裂囊虫死亡分裂成三只幼虫。\n10 波后等待撤离；采矿机只在进攻时产矿，点击建筑领取。", "开始防守")


	if managed:
		Campaign.achievement_unlocked.connect(show_achievement)
		if not Campaign.resume_snapshot.is_empty():
			BattleSave.restore(self, Campaign.resume_snapshot)
			Campaign.resume_snapshot = {}
		show_overlay(mission.title if request.mode == "campaign" else "随机远征 · 第%d站" % (int(request.stage) + 1), (mission.briefing if request.mode == "campaign" else expedition_brief()) + "\n\n新版操作：无准备倒计时，Enter开波。Q布雷(15)，E定点轰炸(免费/25秒冷却)。点击采矿机收货，金色圆点表示有库存，最多存40。", "开始防守")
		save_prepare()
		refresh_ui()
		music = AudioStreamPlayer.new()
		music.stream = load("res://audio/battle.wav")
		music.volume_db = -16
		add_child(music)
		if Campaign.shared.get("music", true): music.play()

func show_achievement(key: String) -> void:
	if achievement_toast == null: return
	achievement_toast.text = "◆ 成就：" + GameCatalog.achievement(key).title
	toast_time = 5.0

func configure_mission() -> void:
	if Campaign.pending.is_empty(): return
	managed = true
	request = Campaign.pending.duplicate(true)
	request.loadout = GameCatalog.normalize_tower_ids(request.loadout)
	selected_type = int(request.loadout[0])
	rng.seed = int(request.seed)
	Campaign.pending = {}
	mission = GameCatalog.mission(int(request.mission))
	waves.clear()
	for source in mission.waves: waves.append(GameCatalog.wave_copy(source))
	for point in mission.rocks:
		var cell := Vector2i(roundi(point.x * 15.0 / 27.0), int(point.y))
		if cell != BattleBoard.CORE: board.rocks[cell] = true
	for point in mission.forbidden: board.forbidden[Vector2i(roundi(point.x * 15.0 / 27.0), int(point.y))] = true
	board.marker = Vector2i(roundi(mission.marker.x * 15.0 / 27.0), mission.marker.y) if mission.marker.x >= 0 else mission.marker
	board.rocks.erase(board.marker)
	board.ground_tint = mission.tint
	battle_bonus = request.get("effects", {}).duplicate(true)
	if request.mode == "expedition":
		board.marker = Vector2i(-1, -1)
		waves.clear()
		for i in 5:
			var config := GameCatalog.wave_copy(load("res://data/wave_%02d.tres" % (i + 1)))
			config.count = 20 + i * 12
			config.health_multiplier = 1.0 + int(request.stage) * 0.08
			config.preparation = 30
			config.boss = false
			if request.modifier == "swarm": config.count = ceili(config.count * 1.2)
			if request.modifier == "armor": config.armored_ratio += 0.08
			if request.modifier == "tunnel": config.burrow_ratio += 0.10
			if request.get("hard", false): config.health_multiplier *= 1.2
			config.health_multiplier *= 1.0 + battle_bonus.get("enemy_health", 0.0)
			waves.append(config)
		if request.modifier == "haste": speed_multiplier = 1.15
	core_max += battle_bonus.get("core", 0.0)
	alloy += int(battle_bonus.get("alloy", 0))
	mining_yield += int(battle_bonus.get("mining", 0))
	damage_multiplier += battle_bonus.get("damage", 0.0)
	speed_multiplier *= 1.0 + battle_bonus.get("enemy_speed", 0.0)
	warning_bonus += battle_bonus.get("warning", 0.0)
	if request.module == "scout":
		core_max *= 0.9
		warning_bonus += 1
	if request.module == "industry":
		miner_limit = 4
		alloy -= 30
	core_hp = core_max
	timer = waves[0].preparation
	board.approach_sides = waves[0].sides
	board.rebuild_routes()
	var core_skin: String = Campaign.profile.cosmetics.get("core", "")
	if core_skin == "core_amber": board.core_tint = Color("ffc477")
	if core_skin == "ending_core": board.core_tint = Color("e9dcff")

func expedition_brief() -> String:
	return "轮机长：这次行动没有增援。三站结束前，战利品都不算安全。\n场地：%s\n威胁：%s\n每站重新建造；临时强化保留。战后可主动撤回，失败丢失未带回徽记。\n未带回：%d 枚；本场胜利新增：%d 枚。" % [mission.title, GameCatalog.MODIFIERS.get(request.modifier, ""), Campaign.profile.expedition.get("stash", 0), [10, 15, 25][int(request.stage)]]

func allowed_building(index: int) -> bool:
	return not managed or index in [3, 4] or request.loadout.has(index)

func save_prepare() -> bool:
	if not managed or phase != Phase.PREPARE: return false
	return Campaign.checkpoint(BattleSave.capture(self))

func bridge() -> void:
	if not managed: return
	if phase == Phase.ATTACK:
		show_overlay("返回舰桥？", "当前战斗不会保存。继续任务时，将回到本波开始前的准备阶段。\n随机种子、装备和准备进度不会重新抽取。", "确认返回舰桥")
		return
	if phase == Phase.PREPARE and not save_prepare():
		show_overlay("保存失败", Campaign.notice, "继续防守")
		return
	get_tree().change_scene_to_file("res://scenes/shell.tscn")

func retry_mission() -> void:
	if not managed or request.mode != "campaign": return
	if Campaign.begin_mission(int(request.mission), request.loadout, request.module, request.choice):
		get_tree().reload_current_scene()

func optional_complete() -> bool:
	if mission == null: return false
	match mission.optional_rule:
		"miner": return station_count() >= 1
		"two_miners": return station_count() >= 2
		"core80": return core_hp >= core_max * 0.8
		"marker":
			var target: DefenseTower = board.buildings.get(board.marker)
			return target != null and target.data.damage > 0
	return false

func take_core_damage(amount: float, source: String) -> void:
	core_damage += amount
	damage_sources[source] = damage_sources.get(source, 0.0) + amount
	core_hp = maxf(0, core_hp - amount)
	if managed and request.module == "emergency" and core_hp > 0 and core_hp <= core_max * 0.3 and not emergency_waves.has(wave):
		emergency_waves.append(wave)
		if alloy >= 20:
			alloy -= 20
			core_hp = minf(core_max, core_hp + core_max * 0.1)


func label_at(parent: Node, text: String, pos: Vector2, size: Vector2, font_size: int = 11) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("c6d8e3"))
	parent.add_child(label)
	return label

func button_at(parent: Node, text: String, pos: Vector2, size: Vector2, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 11)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("15232f")
	style.border_color = Color("29404e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	style.content_margin_left = 3
	style.content_margin_right = 3
	button.add_theme_stylebox_override("normal", style)
	var hover_style := style.duplicate() as StyleBoxFlat
	hover_style.bg_color = Color("294452")
	hover_style.border_color = Color("65d9c2")
	button.add_theme_stylebox_override("hover", hover_style)
	button.add_theme_stylebox_override("pressed", hover_style)
	var disabled_style := style.duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color("101a23")
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func make_ui() -> void:
	BattleUI.make_ui(self)

func show_overlay(title: String, body: String, action: String) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_button.text = action
	overlay.show()

func overlay_action() -> void:
	if managed and overlay_button.text == "确认重开":
		if request.mode == "campaign": retry_mission()
		elif Campaign.continue_battle(): get_tree().reload_current_scene()
		return
	if managed and (phase >= Phase.VICTORY or overlay_button.text == "确认返回舰桥"):
		get_tree().change_scene_to_file("res://scenes/shell.tscn")
		return
	if phase == Phase.VICTORY or phase == Phase.DEFEAT or overlay_button.text == "确认重开":
		get_tree().reload_current_scene()
		return
	started = true
	overlay.hide()

func confirm_restart() -> void:
	show_overlay("重新开始？", ("战役将按原配置重新开始。" if request.get("mode", "") == "campaign" else "将回到本波准备阶段，奖励不会重新抽取。") + "\n按 Esc 可返回游戏。" if managed else "当前这一局的进度将被清空。\n按 Esc 可返回游戏。", "确认重开")

func show_help() -> void:
	show_overlay("前哨操作手册", "1—7：选择建筑　　左键：建造 / 选中\n右键 / Esc：取消建造、关闭帮助\n空格：暂停 / 继续　　Enter：提前迎战\n\n虫群会斜走，绕路太远时会拆墙，不会穿墙角。\n采矿机在进攻中每5秒存4，点击收货，上限40。\nQ选择地雷：15合金，接近触发；E选择轰炸：免费，冷却25秒。\n钻地虫有裂隙预警；电弧破盾，狙击无视盾甲。\n选中建筑后，可在右侧升级、维修或出售。", "返回防守")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if overlay.visible and started and phase < Phase.VICTORY:
				overlay.hide()
			else:
				selected_type = -1
				board.selected = Vector2i(-1, -1)
			refresh_ui()
		if overlay.visible: return
		if event.keycode == KEY_SPACE: toggle_pause()
		if event.keycode == KEY_ENTER: start_wave()
		if event.keycode == KEY_Q: select_action("mine")
		if event.keycode == KEY_E: select_action("strike")
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			choose_building(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed and not overlay.visible and phase < Phase.VICTORY:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			action_mode = ""
			selected_type = -1
			board.selected = Vector2i(-1, -1)
			refresh_ui()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var cell := board.cell_at(board.get_local_mouse_position())
			if not board.inside(cell): return
			if action_mode != "":
				use_action(cell)
				return
			if board.buildings.has(cell):
				collect_miner(board.buildings[cell])
				board.selected = cell
				selected_type = -1
				refresh_ui()
			elif selected_type >= 0:
				place_building(cell, selected_type)

func choose_building(index: int) -> void:
	action_mode = ""
	if not allowed_building(index): return
	selected_type = index
	board.selected = Vector2i(-1, -1)
	refresh_ui()

func enemy_blocks_cell(enemy: AlienBug, cell: Vector2i) -> bool:
	if enemy.hp <= 0: return false
	if board.cell_at(enemy.position) == cell or enemy.destination == cell or enemy.route_from == cell: return true
	var delta := enemy.destination - enemy.route_from
	if absi(delta.x) == 1 and absi(delta.y) == 1:
		return cell == enemy.route_from + Vector2i(delta.x, 0) or cell == enemy.route_from + Vector2i(0, delta.y)
	return false

func station_count() -> int:
	var count := 0
	for tower: DefenseTower in board.buildings.values():
		if tower.data.key == "miner": count += 1
	return count

func building_description(key: String) -> String:
	return {"gun": "机枪：便宜、高射速，对重甲效果较弱。", "cannon": "火炮：范围爆炸，克制密集虫群。", "slow": "减速：降低移动速度，重甲和首领有抗性。", "wall": "围墙：阻挡并吸引拆墙；远程敌人可隔墙攻击。", "miner": "采矿机：进攻中每5秒存4合金，点击收货，最多存40；准备、暂停及撤离不计时，最多 %d 座。" % miner_limit, "tesla": "电弧：最多连锁 4 个敌人，对护盾造成双倍伤害。", "sniper": "狙击：射程远，优先精英，无视护盾和护甲。"}.get(key, "")

func place_building(cell: Vector2i, index: int) -> bool:
	if phase >= Phase.VICTORY or index < 0 or index >= BUILDINGS.size(): return false
	var data: BuildingData = BUILDINGS[index]
	if not allowed_building(index): return false
	if not board.can_build(cell) or alloy < data.cost: return false
	for mine in mines:
		if int(mine.x) == cell.x and int(mine.y) == cell.y: return false
	if data.key == "miner" and station_count() >= miner_limit: return false
	for enemy in enemies:
		if enemy_blocks_cell(enemy, cell): return false
	var tower: DefenseTower = TOWER_SCENE.instantiate()
	tower.setup(data, cell)
	apply_tower_bonus(tower)
	tower.position = board.center(cell)
	board.add_child(tower)
	board.buildings[cell] = tower
	alloy -= data.cost
	board.rebuild_routes()
	economy_changed.emit()
	return true

func apply_tower_bonus(tower: DefenseTower) -> void:
	tower.range_bonus = battle_bonus.get("range", 0.0)
	if tower.data.key == "wall": tower.health_multiplier = 1.0 + battle_bonus.get("wall", 0.0)
	tower.hp = tower.max_health()
	if managed and Campaign.profile.cosmetics.get("tower", "") == "tower_violet": tower.cosmetic_tint = Color("c3a2f2")

func selected_tower() -> DefenseTower:
	return board.buildings.get(board.selected) as DefenseTower

func upgrade_selected() -> void:
	var tower := selected_tower()
	if tower == null or tower.level >= 3 or tower.data.damage <= 0 or phase >= Phase.VICTORY: return
	var cost := tower.upgrade_cost()
	if alloy < cost: return
	alloy -= cost
	tower.invested += cost
	tower.level += 1
	tower.hp = tower.max_health()
	tower.queue_redraw()
	economy_changed.emit()

func repair_selected() -> void:
	var tower := selected_tower()
	if tower == null or phase >= Phase.VICTORY: return
	var cost := ceili((tower.max_health() - tower.hp) / tower.max_health() * tower.data.cost * 0.5)
	if cost <= 0 or alloy < cost: return
	alloy -= cost
	tower.hp = tower.max_health()
	tower.queue_redraw()
	economy_changed.emit()

func sell_selected() -> void:
	var tower := selected_tower()
	if tower == null or phase >= Phase.VICTORY: return
	alloy += floori(tower.invested * 0.65 * tower.hp / tower.max_health())
	remove_building(tower)
	economy_changed.emit()

func remove_building(tower: DefenseTower) -> void:
	board.buildings.erase(tower.cell)
	if board.selected == tower.cell: board.selected = Vector2i(-1, -1)
	tower.queue_free()
	board.rebuild_routes()
	status_changed.emit()

func toggle_pause() -> void:
	if phase >= Phase.VICTORY: return
	paused = not paused
	refresh_ui()

func start_wave() -> void:
	if phase != Phase.PREPARE or paused or not started or overlay.visible: return
	if managed and not save_prepare(): return
	wave += 1
	phase = Phase.ATTACK
	spawned = 0
	spawn_timer = 0.0
	status_changed.emit()

func _process(delta: float) -> void:
	if managed and music != null and phase < Phase.VICTORY and Campaign.shared.get("music", true) and not music.playing: music.play()
	update_preview()
	if not started or overlay.visible or paused or phase >= Phase.VICTORY:
		return
	if toast_time > 0:
		toast_time = maxf(0, toast_time - delta)
		if toast_time == 0 and achievement_toast != null: achievement_toast.text = ""
	strike_cooldown = maxf(0, strike_cooldown - delta)
	tick_mines()
	elapsed += delta
	sound_cooldown -= delta
	update_mining(delta)
	if board.hit_flash > 0:
		board.hit_flash = maxf(0, board.hit_flash - delta)
		if board.hit_flash == 0: board.queue_redraw()
	BattleWaves.tick(self, delta)
	if phase >= Phase.VICTORY: return
	update_enemies(delta)
	if phase >= Phase.VICTORY: return
	update_towers(delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if effects[i].life <= 0: effects.remove_at(i)
	board.position = Vector2(108, 64)
	if shake_enabled and effects.any(func(effect: Dictionary): return effect.kind == "blast" and effect.life > 0.15):
		board.position += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	ui_timer += delta
	if ui_timer >= 0.1:
		ui_timer = 0.0
		refresh_ui()
	effect_layer.queue_redraw()

func update_mining(delta: float) -> void:
	BattleEconomy.update_mining(self , delta)

func grant_clear_reward() -> void:
	BattleEconomy.grant_clear_reward(self)

func update_preview() -> void:
	var tower := selected_tower()
	board.selected_radius = tower.attack_radius() if tower != null else 0.0
	board.hover = board.cell_at(board.get_local_mouse_position())
	board.preview_color = Color.TRANSPARENT
	board.preview_radius = 0
	if selected_type >= 0 and not overlay.visible:
		var data: BuildingData = BUILDINGS[selected_type]
		var valid := board.can_build(board.hover) and alloy >= data.cost
		for enemy in enemies:
			if enemy_blocks_cell(enemy, board.hover): valid = false
		if data.key == "miner" and station_count() >= miner_limit: valid = false
		board.preview_color = Color(0.3, 0.9, 0.7, 0.4) if valid else Color(1, 0.3, 0.3, 0.4)
		board.preview_radius = data.radius
	var signature: Array = [board.hover, board.preview_color, board.preview_radius, board.selected, board.selected_radius, board.approach_sides]
	if signature != preview_signature:
		preview_signature = signature
		board.queue_redraw()

func burrow_cell() -> Vector2i:
	# Prefer a ring two tiles from the core; expand only when it is full.
	for radius in range(2, 5):
		var candidates: Array[Vector2i] = []
		for y in range(-radius, radius + 1):
			for x in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius: continue
				var cell := BattleBoard.CORE + Vector2i(x, y)
				if not board.can_build(cell): continue
				var occupied := false
				for other in enemies:
					if enemy_blocks_cell(other, cell): occupied = true; break
				if not occupied: candidates.append(cell)
		if not candidates.is_empty(): return candidates[rng.randi_range(0, candidates.size() - 1)]
	return Vector2i(-1, -1)

func spawn_enemy(config: WaveData, forced_kind: int = -1) -> AlienBug:
	var side: int = config.sides[rng.randi_range(0, config.sides.size() - 1)]
	var cell := Vector2i(rng.randi_range(1, BattleBoard.WIDTH - 2), 0)
	if side == 1: cell = Vector2i(BattleBoard.WIDTH - 1, rng.randi_range(1, BattleBoard.HEIGHT - 2))
	if side == 2: cell = Vector2i(rng.randi_range(1, BattleBoard.WIDTH - 2), BattleBoard.HEIGHT - 1)
	if side == 3: cell = Vector2i(0, rng.randi_range(1, 14))
	var roll := rng.randf()
	var kind := 0
	var accumulated := 0.0
	var ratios := [config.fast_ratio, config.armored_ratio, config.burrow_ratio, config.spitter_ratio, config.shield_ratio]
	var kinds := [1, 2, 4, 5, 6]
	for i in ratios.size():
		accumulated += ratios[i]
		if roll < accumulated:
			kind = kinds[i]
			break
	if wave >= 2 and spawned % (4 if wave == 3 else 9) == 1: kind = 7
	if config.boss and spawned == config.count - 1: kind = 3
	if forced_kind >= 0: kind = forced_kind
	if kind == 4:
		var underground := burrow_cell()
		if board.inside(underground): cell = underground
	var enemy: AlienBug = ENEMY_SCENE.instantiate()
	enemy.setup(BUGS[kind], config.health_multiplier)
	spawn_serial += 1
	enemy.combat_id = "%s:%d:%d" % [request.get("id", "prototype"), wave, spawn_serial]
	enemy.route_variant = rng.randi_range(0, 2)
	enemy.lane_offset = Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
	enemy.position = enemy.waypoint(cell)
	enemy.destination = cell
	enemy.route_from = cell
	if kind == 4: enemy.emerging = 1.8 + warning_bonus
	board.add_child(enemy)
	enemies.append(enemy)
	return enemy

func summon_minions(boss: AlienBug) -> void:
	if enemies.size() >= 220: return
	var source := board.cell_at(boss.position)
	var count := 0
	for step in BattleBoard.STEPS:
		var cell: Vector2i = source + step
		if not board.inside(cell) or cell == BattleBoard.CORE or board.buildings.has(cell) or board.rocks.has(cell): continue
		var occupied := false
		for other in enemies:
			if enemy_blocks_cell(other, cell): occupied = true; break
		if occupied: continue
		var child := spawn_enemy(waves[wave - 1], 1)
		child.position = child.waypoint(cell)
		child.route_from = cell
		child.destination = cell
		child.summoned = true
		child.emerging = 0.8
		count += 1
		if count == 3: break

func update_enemies(delta: float) -> void:
	BattleCombat.update_enemies(self , delta)

func update_towers(delta: float) -> void:
	BattleCombat.update_towers(self , delta)

func chain_lightning(first: AlienBug, origin: Vector2, damage: float, color: Color) -> void:
	BattleCombat.chain_lightning(self , first, origin, damage, color)

func hit_enemy(enemy: AlienBug, damage: float, mode: String = "normal") -> void:
	BattleCombat.hit_enemy(self , enemy, damage, mode)

func finish(won: bool) -> void:
	if phase >= Phase.VICTORY: return
	if managed and request.mode == "campaign" and mined_total < mission.mining_required: won = false
	phase = Phase.VICTORY if won else Phase.DEFEAT
	if not managed: best = maxi(best, cleared)
	save_settings()
	board.position = Vector2(108, 64)
	var summary := "存活 %02d:%02d   /   击杀 %d   /   通过 %d / 10 波\n最高纪录：%d 波\n\n%s" % [int(elapsed) / 60, int(elapsed) % 60, kills, cleared, best, "撤离成功！前哨的研究资料已安全带回。" if won else "核心已失守。注意地下突袭和远程虫，试试搭配电弧与轨道狙击塔。"]
	show_overlay("撤离成功" if won else "信号中断", summary, "再来一局")
	if managed:
		var medals := [won, won and core_hp >= core_max * 0.6, won and optional_complete()]
		var result := {"id": request.id, "mode": request.mode, "mission": request.mission, "won": won, "medals": medals, "elapsed": elapsed, "kills": kills, "choice": request.choice, "core_damage": core_damage}
		Campaign.settle(result)
		if music != null:
			music.stream = load("res://audio/success.wav" if won else "res://audio/failure.wav")
			if sound_enabled: music.play()
		var cause := ""
		var most := 0.0
		for key in damage_sources:
			if damage_sources[key] > most: most = damage_sources[key]; cause = key
		var failure_tip := "注意地下裂隙与远程腐蚀虫，返回舰桥调整炮塔配置。"
		if int(request.mission) <= 2: failure_tip = "优先补齐核心附近火力，及时升级和维修；采矿机提供战斗收入。"
		if cause == "重甲虫": failure_tip = "重甲虫伤害最多：搭配火炮或轨道狙击，及时升级。"
		if not won and core_hp > 0 and cleared == waves.size() and mined_total < mission.mining_required and request.mode == "campaign": failure_tip = "开采目标未完成：提早部署并保护采矿机。"
		var body := "通过 %d/%d 波 · 击杀 %d · 存活 %02d:%02d\n核心受伤来源：%s\n" % [cleared, waves.size(), kills, int(elapsed) / 60, int(elapsed) % 60, cause if cause != "" else "无"]
		if request.mode == "campaign":
			body += "勋章：完成[%s] 生命60%%[%s] 可选目标[%s]\n" % ["✓" if medals[0] else "—", "✓" if medals[1] else "—", "✓" if medals[2] else "—"]
			body += mission.log_main if won else failure_tip
			if won and int(request.mission) == 6: body = ending_text() + "\n\n" + body
		else:
			body += "本次未带回收益已丢失。永久成果保留。" if not won else ("远征完成，徽记已安全入库。" if Campaign.profile.expedition.is_empty() else "已抵达安全节点；可撤回或继续探索。")
		show_overlay("任务完成" if won else "前哨失联", body, "返回舰桥")
		result_retry.visible = not won and request.mode == "campaign"
	refresh_ui()

func ending_text() -> String:
	var rescue: Dictionary = Campaign.profile.choices.get("2", {})
	var archive: Dictionary = Campaign.profile.choices.get("5", {})
	return "渡鸦号越过云层。信标与地面网络一同沉默。\n" + ("轮机长：最后一组幸存者也在船上。" if rescue.get("optional", false) else "轮机长：还有一组呼叫，再也没有得到回答。") + "\n" + ("人员名单被保存，失踪者终于有了名字。" if archive.get("choice", "crew") == "crew" else "实验资料被发出，公司再也无法否认这一切。") + "\n" + ("舰载人工智能：观察哨记录已并入公开证据。" if Campaign.profile.choices.get("4", {}).get("optional", false) else "舰载人工智能：阵列旁路的最后一段记录仍然缺失。")

func refresh_ui() -> void:
	if hud == null: return
	var status := "布防就绪 · 手动开波"
	if phase == Phase.ATTACK: status = "撤离 %d 秒" % ceili(timer) if evacuation else "来袭 %d / %d" % [spawned, waves[wave - 1].count]
	if paused: status = "已暂停 · 可建造"
	hud.text = "合金 %d   核心 %d/%d   波次 %d/%d   %s" % [alloy, ceili(core_hp), int(core_max), wave, waves.size(), status]
	for i in build_buttons.size():
		build_buttons[i].disabled = not allowed_building(i)
		build_buttons[i].modulate = Color("6ef2cc") if selected_type == i else Color.WHITE
	if managed and mission_hud != null:
		var objective := "开采 %d/%d" % [mined_total, mission.mining_required] if mission.mining_required > 0 and request.mode == "campaign" else "可选目标 " + ("已满足" if optional_complete() else "未满足")
		if int(request.mission) == 2 and request.mode == "campaign": objective += " · 接驳 %d/3批" % (int(cleared >= 2) + int(cleared >= 3) + int(cleared >= waves.size()))
		if int(request.mission) == 5 and request.mode == "campaign": objective += " · 解码 %d/3" % (int(cleared >= 2) + int(cleared >= 4) + int(cleared >= waves.size()))
		mission_hud.text = mission.title + " · " + objective if request.mode == "campaign" else "远征 %d/3 · 未带回 %d 徽记" % [int(request.stage) + 1, Campaign.profile.expedition.get("stash", 0)]
	var tower := selected_tower()
	sell_button.disabled = tower == null
	if tower != null:
		var cost := tower.upgrade_cost()
		var repair := ceili((tower.max_health() - tower.hp) / tower.max_health() * tower.data.cost * 0.5)
		details.text = "%s Lv.%d  HP %d/%d\n升级 %d · 维修 %d" % [tower.data.title, tower.level, ceili(tower.hp), int(tower.max_health()), cost, repair]
		if tower.data.key == "miner": details.text = "采矿机：待收 %d/40\n点击建筑收取 · 进攻时产矿" % tower.stored_alloy
		upgrade_button.disabled = tower.level >= 3 or tower.data.damage <= 0 or alloy < cost
		repair_button.disabled = repair <= 0 or alloy < repair
		var refund := floori(tower.invested * 0.65 * tower.hp / tower.max_health())
		sell_button.text = "出售 +%d" % refund
	else:
		upgrade_button.disabled = true
		repair_button.disabled = true
		details.text = "采矿点击收货，满40停产\n每台5秒存%d · 最多%d台" % [mining_yield, miner_limit]
		sell_button.text = "出售"
	pause_button.text = "继续" if paused else "暂停"
	next_button.disabled = phase != Phase.PREPARE or paused
	var direction := ""
	for side in board.approach_sides:
		direction += ["北 ", "东 ", "南 ", "西 "][side]
	var intel: WaveData = waves[mini(wave, waves.size() - 1)] if phase == Phase.PREPARE else waves[maxi(0, wave - 1)]
	var threats := "普通虫"
	if intel.armored_ratio > 0: threats += " / 重甲"
	if intel.burrow_ratio > 0: threats += " / 地下突袭"
	if intel.spitter_ratio > 0: threats += " / 腐蚀远程"
	if intel.shield_ratio > 0: threats += " / 护盾"
	if intel.boss: threats += " / 巢母"
	if wave >= 1: threats += " / 裂囊分裂"
	threats = ["接触", "突袭", "裂囊潮", "突破", "围攻", "决战"][mini(wave if phase == Phase.PREPARE else maxi(0, wave - 1), 5)] + " · " + threats
	hint.text = "来袭：%s · %s\nQ布雷(15) · E轰炸(免费/冷却25秒) · 点击采矿收货" % [direction, threats]
	if action_button != null: action_button.text = "E 轰炸 " + ("就绪" if strike_cooldown <= 0 else "%d秒" % ceili(strike_cooldown))

func draw_effects() -> void:
	if board == null: return
	for mine in mines:
		effect_layer.draw_circle(board.center(Vector2i(int(mine.x), int(mine.y))) + board.position, 4, Color("ffe38a"))
	for effect in effects:
		var offset := board.position
		var color: Color = effect.color
		if effect.kind == "shot":
			effect_layer.draw_line(effect.from + offset, effect.to + offset, color, 1)
		elif effect.kind == "claw" or effect.kind == "acid":
			var progress: float = 1.0 - effect.life / 0.32
			color.a = minf(1, effect.life / 0.12)
			var impact: Vector2 = effect.to + offset
			if effect.kind == "acid":
				var tip: Vector2 = effect.from.lerp(effect.to, minf(1, progress * 2.5)) + offset
				effect_layer.draw_line(effect.from + offset, tip, Color(0.55, 0.85, 0.25, color.a * 0.5), 2)
				effect_layer.draw_circle(tip, 3, color)
			else:
				var tip: Vector2 = effect.from.lerp(effect.to, minf(1, progress * 4)) + offset
				effect_layer.draw_line(effect.from + offset, tip, Color(1, 0.4, 0.25, color.a * 0.5), 2)
				for slash in [-3, 3]:
					effect_layer.draw_line(impact + Vector2(slash - 3, -6), impact + Vector2(slash + 3, 5), color, 2)
			effect_layer.draw_arc(impact, 3 + progress * 9, 0, TAU, 12, color, 1)
		elif effect.kind == "blast":
			effect_layer.draw_arc(effect.to + offset, 4 + (0.26 - effect.life) * 90, 0, TAU, 16, color, 2)
		else:
			for i in 4:
				var direction := Vector2.from_angle(i * PI / 2 + 0.5)
				effect_layer.draw_rect(Rect2(effect.to + offset + direction * (0.3 - effect.life) * 30, Vector2(2, 2)), color)

func select_action(kind: String) -> void:
	if phase >= Phase.VICTORY: return
	action_mode = kind
	selected_type = -1
	board.selected = Vector2i(-1, -1)
	refresh_ui()

func collect_miner(tower: DefenseTower) -> void:
	if tower.data.key != "miner" or phase >= Phase.VICTORY: return
	alloy += tower.stored_alloy
	mined_total += tower.stored_alloy
	tower.stored_alloy = 0
	tower.queue_redraw()
	economy_changed.emit()

func use_action(cell: Vector2i) -> void:
	if not board.inside(cell) or phase >= Phase.VICTORY: return
	if action_mode == "mine":
		if alloy < 15 or mines.size() >= 8 or not board.can_build(cell): return
		for mine in mines:
			if int(mine.x) == cell.x and int(mine.y) == cell.y: return
		alloy -= 15
		mines.append({"x": cell.x, "y": cell.y})
	elif action_mode == "strike":
		if phase != Phase.ATTACK or paused or strike_cooldown > 0: return
		strike_cooldown = 25.0
		blast_at(board.center(cell), 42, 90)
	action_mode = ""
	effect_layer.queue_redraw()
	refresh_ui()

func blast_at(point: Vector2, radius: float, damage: float) -> void:
	effects.append({"kind": "blast", "to": point, "color": Color("ffe38a"), "life": 0.26})
	for enemy: AlienBug in enemies.duplicate():
		if enemy.position.distance_to(point) <= radius: hit_enemy(enemy, damage)

func tick_mines() -> void:
	if phase != Phase.ATTACK: return
	for index in range(mines.size() - 1, -1, -1):
		var mine: Dictionary = mines[index]
		var point := board.center(Vector2i(int(mine.x), int(mine.y)))
		for enemy: AlienBug in enemies:
			if enemy.hp > 0 and enemy.emerging <= 0 and enemy.position.distance_to(point) < 12:
				mines.remove_at(index)
				blast_at(point, 30, 70)
				break

func split_enemy(parent: AlienBug) -> void:
	if enemies.size() >= 240: return
	var cell := board.cell_at(parent.position)
	for index in 3:
		var child := spawn_enemy(waves[maxi(0, wave - 1)], 1)
		child.position = parent.position + Vector2(index - 1, 0) * 2
		child.destination = cell
		child.route_from = cell
		child.summoned = true
		child.emerging = 0.4
		child.hp = 20
		child.max_hp = 20

func make_audio() -> void:
	# Original synthetic laser tick: no external sound assets.
	audio = AudioStreamPlayer.new()
	audio.volume_db = -24
	add_child(audio)
	shot_sound = AudioStreamWAV.new()
	shot_sound.format = AudioStreamWAV.FORMAT_8_BITS
	shot_sound.mix_rate = 22050
	var samples := PackedByteArray()
	for i in 1102:
		var time := float(i) / 22050
		var sample := sin(TAU * (950 * time - 4000 * time * time)) * (1.0 - float(i) / 1102) * 70
		samples.append(int(sample) & 255)
	shot_sound.data = samples
	audio.stream = shot_sound

func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load("user://settings.cfg") != OK: return
	shake_enabled = bool(config.get_value("settings", "shake", true))
	sound_enabled = bool(config.get_value("settings", "sound", true))
	best = clampi(int(config.get_value("records", "waves", 0)), 0, 10)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "shake", shake_enabled)
	config.set_value("settings", "sound", sound_enabled)
	config.set_value("records", "waves", best)
	config.save("user://settings.cfg")
	if managed:
		Campaign.shared.sound = sound_enabled
		Campaign.shared.shake = shake_enabled
		Campaign.save_settings()

func _exit_tree() -> void:
	for player in [audio, music]:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	shot_sound = null
