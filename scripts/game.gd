extends Node2D
## Main coordinator. Buildings and enemies are scenes, balance lives in data/.
signal economy_changed
signal status_changed
enum Phase { PREPARE, ATTACK, VICTORY, DEFEAT }
const TOWER_SCENE = preload("res://scenes/tower.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BUILDINGS = [preload("res://data/gun.tres"), preload("res://data/cannon.tres"), preload("res://data/slow.tres"), preload("res://data/wall.tres"), preload("res://data/miner.tres"), preload("res://data/tesla.tres"), preload("res://data/sniper.tres")]
const BUGS = [preload("res://data/bug.tres"), preload("res://data/runner.tres"), preload("res://data/armored.tres"), preload("res://data/boss.tres"), preload("res://data/burrow.tres"), preload("res://data/spitter.tres"), preload("res://data/shield.tres")]
var waves: Array[WaveData] = []
const MINER_LIMIT := 3
const SALVAGE_PER_STATION := 12
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
	show_overlay("异星撤离", "采矿前哨已被虫群发现。守住核心，等待撤离。\n\n① 左侧网格自由建塔，四周红色区域禁止建造。\n② 收入来自击杀和过波，等待不产钱。\n③ 按空格暂停并布防，按 Enter 提前迎战。\n④ 点击建筑可升级、维修或出售。\n\n第 3 波起注意地下裂隙，第 5 波起有远程敌人。\n10 波后等待撤离；回收站每过一波额外 +12。", "开始防守")

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
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label_at(canvas, "异星撤离 / OUTPOST 07 · v0.2", Vector2(12, 6), Vector2(300, 20), 16)
	hud = label_at(canvas, "", Vector2(12, 30), Vector2(620, 28), 12)
	label_at(canvas, "防御部署", Vector2(474, 62), Vector2(155, 20), 13)
	var display_order := [0, 1, 2, 3, 4, 5, 6]
	var short_names := ["机枪", "火炮", "减速", "围墙", "回收", "电弧", "狙击"]
	build_buttons.resize(BUILDINGS.size())
	for slot in display_order.size():
		var i: int = display_order[slot]
		var config: BuildingData = BUILDINGS[i]
		var button := button_at(canvas, "%d %s %d" % [i + 1, short_names[i], config.cost], Vector2(474 + (slot % 2) * 80, 84 + (slot / 2) * 33), Vector2(74, 31), choose_building.bind(i))
		button.add_theme_font_size_override("font_size", 9)
		button.tooltip_text = config.title + "：" + building_description(config.key)
		build_buttons[i] = button
	details = label_at(canvas, "", Vector2(474, 220), Vector2(154, 35), 10)
	upgrade_button = button_at(canvas, "升级", Vector2(474, 258), Vector2(74, 24), upgrade_selected)
	repair_button = button_at(canvas, "维修", Vector2(554, 258), Vector2(74, 24), repair_selected)
	sell_button = button_at(canvas, "出售", Vector2(474, 286), Vector2(74, 24), sell_selected)
	pause_button = button_at(canvas, "暂停", Vector2(554, 286), Vector2(74, 24), toggle_pause)
	next_button = button_at(canvas, "提前迎战  Enter", Vector2(474, 318), Vector2(154, 28), start_wave)
	hint = label_at(canvas, "", Vector2(12, 324), Vector2(450, 30), 10)
	button_at(canvas, "重开", Vector2(494, 6), Vector2(60, 22), confirm_restart)
	button_at(canvas, "帮助", Vector2(562, 6), Vector2(66, 22), show_help)
	overlay = ColorRect.new()
	overlay.color = Color(0.015, 0.025, 0.045, 0.96)
	overlay.size = Vector2(640, 360)
	canvas.add_child(overlay)
	overlay_title = label_at(overlay, "", Vector2(64, 35), Vector2(520, 40), 26)
	overlay_body = label_at(overlay, "", Vector2(64, 86), Vector2(520, 195), 11)
	overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_button = button_at(overlay, "", Vector2(64, 288), Vector2(200, 34), overlay_action)
	var sound := CheckButton.new()
	sound.text = "音效"
	sound.position = Vector2(295, 288)
	sound.add_theme_font_override("font", font)
	sound.add_theme_font_size_override("font_size", 12)
	sound.button_pressed = sound_enabled
	sound.toggled.connect(func(value: bool): sound_enabled = value; save_settings())
	overlay.add_child(sound)
	var shake := CheckButton.new()
	shake.text = "震动"
	shake.position = Vector2(420, 288)
	shake.add_theme_font_override("font", font)
	shake.add_theme_font_size_override("font_size", 12)
	shake.button_pressed = shake_enabled
	shake.toggled.connect(func(value: bool): shake_enabled = value; save_settings())
	overlay.add_child(shake)

func show_overlay(title: String, body: String, action: String) -> void:
	overlay_title.text = title
	overlay_body.text = body
	overlay_button.text = action
	overlay.show()

func overlay_action() -> void:
	if phase == Phase.VICTORY or phase == Phase.DEFEAT or overlay_button.text == "确认重开":
		get_tree().reload_current_scene()
		return
	started = true
	overlay.hide()

func confirm_restart() -> void:
	show_overlay("重新开始？", "当前这一局的进度将被清空。\n按 Esc 可返回游戏。", "确认重开")

func show_help() -> void:
	show_overlay("前哨操作手册", "1—7：选择建筑　　左键：建造 / 选中\n右键 / Esc：取消建造、关闭帮助\n空格：暂停 / 继续　　Enter：提前迎战\n\n虫群会斜走，绕路太远时会拆墙，不会穿墙角。\n回收站每过波 +12（最多 3 座），等待没有收益。\n钻地虫有裂隙预警；电弧破盾，狙击无视盾甲。\n选中建筑后，可在右侧升级、维修或出售。", "返回防守")

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
		if event.keycode >= KEY_1 and event.keycode <= KEY_7:
			choose_building(event.keycode - KEY_1)
	if event is InputEventMouseButton and event.pressed and not overlay.visible and phase < Phase.VICTORY:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			selected_type = -1
			board.selected = Vector2i(-1, -1)
			refresh_ui()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var cell := board.cell_at(board.get_local_mouse_position())
			if not board.inside(cell): return
			if board.buildings.has(cell):
				board.selected = cell
				selected_type = -1
				refresh_ui()
			elif selected_type >= 0:
				place_building(cell, selected_type)

func choose_building(index: int) -> void:
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
	return {"gun": "机枪：便宜、高射速，对重甲效果较弱。", "cannon": "火炮：范围爆炸，克制密集虫群。", "slow": "减速：降低移动速度，重甲和首领有抗性。", "wall": "围墙：阻挡并吸引拆墙；远程敌人可隔墙攻击。", "miner": "回收站：每次过波额外 +12 合金，最多 3 座。", "tesla": "电弧：最多连锁 4 个敌人，对护盾造成双倍伤害。", "sniper": "狙击：射程远，优先精英，无视护盾和护甲。"}.get(key, "")

func place_building(cell: Vector2i, index: int) -> bool:
	if phase >= Phase.VICTORY or index < 0 or index >= BUILDINGS.size(): return false
	var data: BuildingData = BUILDINGS[index]
	if not board.can_build(cell) or alloy < data.cost: return false
	if data.key == "miner" and station_count() >= MINER_LIMIT: return false
	for enemy in enemies:
		if enemy_blocks_cell(enemy, cell): return false
	var tower: DefenseTower = TOWER_SCENE.instantiate()
	tower.setup(data, cell)
	tower.position = board.center(cell)
	board.add_child(tower)
	board.buildings[cell] = tower
	alloy -= data.cost
	board.rebuild_routes()
	economy_changed.emit()
	return true

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
	tower.queue_free()
	board.rebuild_routes()
	status_changed.emit()

func toggle_pause() -> void:
	if phase >= Phase.VICTORY: return
	paused = not paused
	refresh_ui()

func start_wave() -> void:
	if phase != Phase.PREPARE or paused or not started or overlay.visible: return
	wave += 1
	phase = Phase.ATTACK
	spawned = 0
	spawn_timer = 0.0
	status_changed.emit()

func _process(delta: float) -> void:
	update_preview()
	if not started or overlay.visible or paused or phase >= Phase.VICTORY:
		return
	elapsed += delta
	sound_cooldown -= delta
	if phase == Phase.PREPARE:
		timer -= delta
		if timer <= 0: start_wave()
	elif evacuation:
		timer -= delta
		if timer <= 0: finish(true)
	else:
		var config := waves[wave - 1]
		spawn_timer -= delta
		if spawned < config.count and spawn_timer <= 0:
			spawn_enemy(config)
			spawned += 1
			spawn_timer = config.spawn_interval
		if spawned >= config.count and enemies.is_empty():
			cleared = wave
			grant_clear_reward()
			if wave == waves.size():
				evacuation = true
				timer = 30.0
			else:
				phase = Phase.PREPARE
				timer = waves[wave].preparation
				board.approach_sides = waves[wave].sides
	update_enemies(delta)
	if phase >= Phase.VICTORY: return
	update_towers(delta)
	for i in range(effects.size() - 1, -1, -1):
		effects[i].life -= delta
		if effects[i].life <= 0: effects.remove_at(i)
	board.position = Vector2(12, 64)
	if shake_enabled and effects.any(func(effect: Dictionary): return effect.kind == "blast" and effect.life > 0.15):
		board.position += Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1))
	ui_timer += delta
	if ui_timer >= 0.1:
		ui_timer = 0.0
		refresh_ui()
	effect_layer.queue_redraw()

func grant_clear_reward() -> void:
	if wave <= rewarded_wave: return
	rewarded_wave = wave
	last_clear_reward = waves[wave - 1].clear_reward + station_count() * SALVAGE_PER_STATION
	alloy += last_clear_reward
	economy_changed.emit()

func update_preview() -> void:
	board.hover = board.cell_at(board.get_local_mouse_position())
	board.preview_color = Color.TRANSPARENT
	board.preview_radius = 0
	if selected_type >= 0 and not overlay.visible:
		var data: BuildingData = BUILDINGS[selected_type]
		var valid := board.can_build(board.hover) and alloy >= data.cost
		for enemy in enemies:
			if enemy_blocks_cell(enemy, board.hover): valid = false
		if data.key == "miner" and station_count() >= MINER_LIMIT: valid = false
		board.preview_color = Color(0.3, 0.9, 0.7, 0.4) if valid else Color(1, 0.3, 0.3, 0.4)
		board.preview_radius = data.radius
	var signature: Array = [board.hover, board.preview_color, board.preview_radius, board.selected, board.approach_sides]
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
	var cell := Vector2i(rng.randi_range(1, 26), 0)
	if side == 1: cell = Vector2i(27, rng.randi_range(1, 14))
	if side == 2: cell = Vector2i(rng.randi_range(1, 26), 15)
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
	if config.boss and spawned == config.count - 1: kind = 3
	if forced_kind >= 0: kind = forced_kind
	if kind == 4:
		var underground := burrow_cell()
		if board.inside(underground): cell = underground
	var enemy: AlienBug = ENEMY_SCENE.instantiate()
	enemy.setup(BUGS[kind], config.health_multiplier)
	enemy.route_variant = rng.randi_range(0, 2)
	enemy.lane_offset = Vector2(rng.randf_range(-2, 2), rng.randf_range(-2, 2))
	enemy.position = enemy.waypoint(cell)
	enemy.destination = cell
	enemy.route_from = cell
	if kind == 4: enemy.emerging = 1.8
	board.add_child(enemy)
	enemies.append(enemy)
	return enemy

func summon_minions(boss: AlienBug) -> void:
	if enemies.size() >= 220: return
	var source := board.cell_at(boss.position)
	var count := 0
	for step in BattleBoard.STEPS:
		var cell: Vector2i = source + step
		if not board.inside(cell) or cell == BattleBoard.CORE or board.buildings.has(cell): continue
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
	for enemy: AlienBug in enemies.duplicate():
		if enemy.hp <= 0: continue
		enemy.animation += delta
		if enemy.emerging > 0:
			enemy.emerging = maxf(0, enemy.emerging - delta)
			enemy.queue_redraw()
			continue
		enemy.slow_time = maxf(0, enemy.slow_time - delta)
		enemy.attack_timer -= delta
		enemy.since_hit += delta
		if enemy.max_shield > 0 and enemy.since_hit >= 3:
			enemy.shield_hp = minf(enemy.max_shield, enemy.shield_hp + enemy.max_shield * 0.18 * delta)
		var enraged := enemy.data.ability == "boss" and enemy.hp < enemy.max_hp * 0.5
		if enemy.data.ability == "boss":
			enemy.summon_timer -= delta
			if enemy.summon_timer <= 0:
				enemy.summon_timer = 6.0 if enraged else 9.0
				summon_minions(enemy)
		var at_waypoint := enemy.position.distance_to(enemy.waypoint(enemy.destination)) < 0.1
		if at_waypoint:
			enemy.route_from = enemy.destination
			enemy.destination = board.next_cell(enemy.route_from, enemy.route_variant)
		var target: DefenseTower = board.buildings.get(enemy.destination)
		var attacks_core := enemy.position.distance_to(board.center(BattleBoard.CORE)) <= enemy.data.attack_range
		if enemy.data.ability == "spitter":
			# Ranged siege stops outside the wall and attacks nearby defenses first.
			var nearest := enemy.data.attack_range
			for tower: DefenseTower in board.buildings.values():
				var distance := enemy.position.distance_to(tower.position)
				if distance <= nearest:
					nearest = distance
					target = tower
			if target != null and enemy.position.distance_to(target.position) > enemy.data.attack_range:
				target = null
			if target != null: attacks_core = false
		if target != null or attacks_core:
			if enemy.attack_timer <= 0:
				enemy.attack_timer = enemy.data.attack_interval / (1.5 if enraged else 1.0)
				var damage := enemy.data.damage * (1.5 if enraged else 1.0)
				if attacks_core:
					core_hp = maxf(0, core_hp - damage)
					if core_hp <= 0:
						finish(false)
						return
				else:
					target.hp -= damage
					if enemy.data.ability == "spitter":
						effects.append({"kind": "shot", "from": enemy.position, "to": target.position, "color": Color("b4ff6e"), "life": 0.24})
					target.queue_redraw()
					if target.hp <= 0: remove_building(target)
		else:
			var slow := lerpf(0.45, 1.0, enemy.data.slow_resistance) if enemy.slow_time > 0 else 1.0
			var speed := enemy.data.speed * slow * (1.5 if enraged else 1.0)
			enemy.position = enemy.position.move_toward(enemy.waypoint(enemy.destination), speed * delta)
		enemy.queue_redraw()

func update_towers(delta: float) -> void:
	for tower: DefenseTower in board.buildings.values():
		tower.cooldown -= delta
		tower.flash = maxf(0, tower.flash - delta)
		if tower.data.damage <= 0: continue
		if tower.cooldown > 0:
			tower.queue_redraw()
			continue
		var target: AlienBug = null
		var radius := tower.data.radius + (tower.level - 1) * 8
		var best_score := -INF
		for enemy in enemies:
			var distance := tower.position.distance_to(enemy.position)
			if enemy.hp <= 0 or enemy.emerging > 0 or distance >= radius: continue
			var score := -distance
			if tower.data.key == "sniper": score = enemy.max_hp + enemy.max_shield - distance * 0.1
			if score > best_score:
				best_score = score
				target = enemy
		if target == null: continue
		tower.aim = (target.position - tower.position).normalized()
		tower.flash = 0.1
		tower.cooldown = tower.data.interval / (1 + (tower.level - 1) * 0.15)
		var damage := tower.data.damage * (1 + (tower.level - 1) * 0.65)
		var color := tower.data.tint
		effects.append({"kind": "shot", "from": tower.position, "to": target.position, "color": color, "life": 0.10})
		if tower.data.key == "cannon":
			var impact := target.position
			effects.append({"kind": "blast", "to": impact, "color": color, "life": 0.26})
			for enemy: AlienBug in enemies.duplicate():
				if enemy.position.distance_to(impact) < 28: hit_enemy(enemy, damage)
		elif tower.data.key == "tesla":
			chain_lightning(target, tower.position, damage, color)
		else:
			if tower.data.key == "slow": target.slow_time = 2.0
			hit_enemy(target, damage, "piercing" if tower.data.key == "sniper" else "normal")
		if sound_enabled and sound_cooldown <= 0:
			audio.pitch_scale = 0.65 if tower.data.key == "cannon" else 1.0
			audio.play()
			sound_cooldown = 0.09
		tower.queue_redraw()
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].hp <= 0:
			enemies[i].queue_free()
			enemies.remove_at(i)

func chain_lightning(first: AlienBug, origin: Vector2, damage: float, color: Color) -> void:
	var visited: Array[AlienBug] = []
	var target := first
	var previous := origin
	for bounce in 4:
		if target == null: break
		visited.append(target)
		effects.append({"kind": "shot", "from": previous, "to": target.position, "color": color, "life": 0.22})
		hit_enemy(target, damage * pow(0.8, bounce), "energy")
		previous = target.position
		target = null
		var nearest := 44.0
		for other in enemies:
			if visited.has(other) or other.hp <= 0 or other.emerging > 0: continue
			var distance := previous.distance_to(other.position)
			if distance < nearest:
				nearest = distance
				target = other

func hit_enemy(enemy: AlienBug, damage: float, mode: String = "normal") -> void:
	if enemy.hp <= 0 or enemy.emerging > 0: return
	enemy.since_hit = 0.0
	var remaining := damage
	if mode != "piercing" and enemy.shield_hp > 0:
		var factor := 2.0 if mode == "energy" else 1.0
		var absorbed := minf(enemy.shield_hp, remaining * factor)
		enemy.shield_hp -= absorbed
		remaining -= absorbed / factor
	if remaining > 0:
		enemy.hp -= remaining if mode == "piercing" else maxf(1, remaining - enemy.data.armor)
	if enemy.hp <= 0:
		kills += 1
		if not enemy.summoned: alloy += enemy.data.reward
		effects.append({"kind": "death", "to": enemy.position, "color": enemy.data.tint, "life": 0.3})

func finish(won: bool) -> void:
	if phase >= Phase.VICTORY: return
	phase = Phase.VICTORY if won else Phase.DEFEAT
	best = maxi(best, cleared)
	save_settings()
	board.position = Vector2(12, 64)
	var summary := "存活 %02d:%02d   /   击杀 %d   /   通过 %d / 10 波\n最高纪录：%d 波\n\n%s" % [int(elapsed) / 60, int(elapsed) % 60, kills, cleared, best, "撤离成功！前哨的研究资料已安全带回。" if won else "核心已失守。注意地下突袭和远程虫，试试搭配电弧与轨道狙击塔。"]
	show_overlay("撤离成功" if won else "信号中断", summary, "再来一局")
	refresh_ui()

func refresh_ui() -> void:
	if hud == null: return
	var status := "准备 %d 秒" % ceili(timer)
	if phase == Phase.ATTACK: status = "撤离 %d 秒" % ceili(timer) if evacuation else "来袭 %d / %d" % [spawned, waves[wave - 1].count]
	if paused: status = "已暂停 · 可建造"
	hud.text = "合金 %d   核心 %d / 600   波次 %d / 10   %s" % [alloy, ceili(core_hp), wave, status]
	for i in build_buttons.size():
		build_buttons[i].modulate = Color("6ef2cc") if selected_type == i else Color.WHITE
	var tower := selected_tower()
	sell_button.disabled = tower == null
	if tower != null:
		var cost := tower.upgrade_cost()
		var repair := ceili((tower.max_health() - tower.hp) / tower.max_health() * tower.data.cost * 0.5)
		details.text = "%s Lv.%d  HP %d/%d\n升级 %d · 维修 %d" % [tower.data.title, tower.level, ceili(tower.hp), int(tower.max_health()), cost, repair]
		upgrade_button.disabled = tower.level >= 3 or tower.data.damage <= 0 or alloy < cost
		repair_button.disabled = repair <= 0 or alloy < repair
		var refund := floori(tower.invested * 0.65 * tower.hp / tower.max_health())
		sell_button.text = "出售 +%d" % refund
	else:
		upgrade_button.disabled = true
		repair_button.disabled = true
		details.text = "击杀 + 过波获得合金\n回收站每过波额外 +12"
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
	hint.text = "来袭：%s · %s\n1—7 选建筑 · 空格暂停 · Enter迎战 · 右键取消" % [direction, threats]

func draw_effects() -> void:
	if board == null: return
	for effect in effects:
		var offset := board.position
		var color: Color = effect.color
		if effect.kind == "shot":
			effect_layer.draw_line(effect.from + offset, effect.to + offset, color, 1)
		elif effect.kind == "blast":
			effect_layer.draw_arc(effect.to + offset, 4 + (0.26 - effect.life) * 90, 0, TAU, 16, color, 2)
		else:
			for i in 4:
				var direction := Vector2.from_angle(i * PI / 2 + 0.5)
				effect_layer.draw_rect(Rect2(effect.to + offset + direction * (0.3 - effect.life) * 30, Vector2(2, 2)), color)

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
