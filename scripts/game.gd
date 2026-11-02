extends Node2D
## Main coordinator. Buildings and enemies are scenes, balance lives in data/.
signal economy_changed
signal status_changed
enum Phase { PREPARE, ATTACK, VICTORY, DEFEAT }
const TOWER_SCENE = preload("res://scenes/tower.tscn")
const ENEMY_SCENE = preload("res://scenes/enemy.tscn")
const BUILDINGS = [preload("res://data/gun.tres"), preload("res://data/cannon.tres"), preload("res://data/slow.tres"), preload("res://data/wall.tres"), preload("res://data/miner.tres")]
const BUGS = [preload("res://data/bug.tres"), preload("res://data/runner.tres"), preload("res://data/armored.tres"), preload("res://data/boss.tres")]
var waves: Array[WaveData] = []
var board: BattleBoard
var enemies: Array[AlienBug] = []
var phase := Phase.PREPARE
var alloy := 180
var core_hp := 600.0
var wave := 0
var cleared := 0
var kills := 0
var elapsed := 0.0
var timer := 45.0
var spawn_timer := 0.0
var spawned := 0
var income_timer := 0.0
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
	show_overlay("异星撤离", "采矿前哨已被虫群发现。守住核心，等待撤离。\n\n① 左侧网格自由建塔，四周红色区域禁止建造。\n② 炮塔自动攻击；采矿机每 5 秒产出 4 合金。\n③ 按空格暂停并布防，按 Enter 提前迎战。\n④ 点击建筑可升级、维修或出售。\n\n10 波虫潮后守住 30 秒，即可撤离。", "开始防守")

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
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func make_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	label_at(canvas, "异星撤离  /  OUTPOST 07", Vector2(12, 6), Vector2(300, 20), 16)
	hud = label_at(canvas, "", Vector2(12, 30), Vector2(620, 28), 12)
	label_at(canvas, "防御部署", Vector2(474, 62), Vector2(155, 20), 13)
	for i in BUILDINGS.size():
		var config: BuildingData = BUILDINGS[i]
		var button := button_at(canvas, "%d  %s   %d" % [i + 1, config.title, config.cost], Vector2(474, 86 + 26 * i), Vector2(154, 23), choose_building.bind(i))
		build_buttons.append(button)
	details = label_at(canvas, "", Vector2(474, 219), Vector2(154, 35), 10)
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
	overlay_body = label_at(overlay, "", Vector2(64, 86), Vector2(520, 195), 13)
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
	show_overlay("前哨操作手册", "1—5：选择建筑　　左键：建造 / 选中\n右键 / Esc：取消建造、关闭帮助\n空格：暂停 / 继续　　Enter：提前迎战\n\n围墙能拖住敌人；完全封路后虫群会拆墙。\n火炮造成范围伤害，减速塔让虫群移动变慢。\n采矿机会占用空间且容易被破坏，请保护它。\n选中建筑后，可在右侧升级、维修或出售。", "返回防守")

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
		if event.keycode >= KEY_1 and event.keycode <= KEY_5:
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

func place_building(cell: Vector2i, index: int) -> bool:
	if phase >= Phase.VICTORY or index < 0 or index >= BUILDINGS.size(): return false
	var data: BuildingData = BUILDINGS[index]
	if not board.can_build(cell) or alloy < data.cost: return false
	for enemy in enemies:
		if enemy.hp > 0 and (board.cell_at(enemy.position) == cell or enemy.destination == cell): return false
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
	income_timer += delta
	if income_timer >= 5.0:
		income_timer -= 5.0
		var income := 2
		for tower: DefenseTower in board.buildings.values():
			if tower.data.key == "miner": income += 4
		alloy += income
		economy_changed.emit()
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
			alloy += 25 + wave * 4
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
	refresh_ui()
	effect_layer.queue_redraw()

func update_preview() -> void:
	board.hover = board.cell_at(board.get_local_mouse_position())
	board.preview_color = Color.TRANSPARENT
	board.preview_radius = 0
	if selected_type >= 0 and not overlay.visible:
		var data: BuildingData = BUILDINGS[selected_type]
		var valid := board.can_build(board.hover) and alloy >= data.cost
		for enemy in enemies:
			if board.cell_at(enemy.position) == board.hover or enemy.destination == board.hover: valid = false
		board.preview_color = Color(0.3, 0.9, 0.7, 0.4) if valid else Color(1, 0.3, 0.3, 0.4)
		board.preview_radius = data.radius
	board.queue_redraw()

func spawn_enemy(config: WaveData) -> void:
	var side: int = config.sides[spawned % config.sides.size()]
	var cell := Vector2i(rng.randi_range(2, 25), 0)
	if side == 1: cell = Vector2i(27, rng.randi_range(2, 13))
	if side == 2: cell = Vector2i(rng.randi_range(2, 25), 15)
	if side == 3: cell = Vector2i(0, rng.randi_range(2, 13))
	var roll := rng.randf()
	var kind := 0
	if roll < config.armored_ratio: kind = 2
	elif roll < config.armored_ratio + config.fast_ratio: kind = 1
	if config.boss and spawned == config.count - 1: kind = 3
	var enemy: AlienBug = ENEMY_SCENE.instantiate()
	enemy.setup(BUGS[kind], config.health_multiplier)
	enemy.position = board.center(cell)
	enemy.destination = cell
	board.add_child(enemy)
	enemies.append(enemy)

func update_enemies(delta: float) -> void:
	for enemy in enemies:
		if enemy.hp <= 0: continue
		enemy.animation += delta
		enemy.slow_time = maxf(0, enemy.slow_time - delta)
		enemy.attack_timer -= delta
		var cell := board.cell_at(enemy.position)
		if enemy.position.distance_to(board.center(enemy.destination)) < 0.1:
			enemy.destination = board.next_cell(cell)
		var target: DefenseTower = board.buildings.get(enemy.destination)
		var attacks_core := cell == BattleBoard.CORE or (enemy.destination == BattleBoard.CORE and enemy.position.distance_to(board.center(BattleBoard.CORE)) < 17)
		if target != null or attacks_core:
			if enemy.attack_timer <= 0:
				enemy.attack_timer = 1.0
				if attacks_core:
					core_hp = maxf(0, core_hp - enemy.data.damage)
					if core_hp <= 0:
						finish(false)
						return
				else:
					target.hp -= enemy.data.damage
					target.queue_redraw()
					if target.hp <= 0: remove_building(target)
		else:
			var speed := enemy.data.speed * (0.45 if enemy.slow_time > 0 else 1.0)
			enemy.position = enemy.position.move_toward(board.center(enemy.destination), speed * delta)
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
		var best_distance := radius
		for enemy in enemies:
			var distance := tower.position.distance_to(enemy.position)
			if enemy.hp > 0 and distance < best_distance:
				best_distance = distance
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
			for enemy in enemies.duplicate():
				if enemy.position.distance_to(impact) < 28: hit_enemy(enemy, damage)
		else:
			if tower.data.key == "slow": target.slow_time = 2.0
			hit_enemy(target, damage)
		if sound_enabled and sound_cooldown <= 0:
			audio.pitch_scale = 0.65 if tower.data.key == "cannon" else 1.0
			audio.play()
			sound_cooldown = 0.09
		tower.queue_redraw()
	for i in range(enemies.size() - 1, -1, -1):
		if enemies[i].hp <= 0:
			enemies[i].queue_free()
			enemies.remove_at(i)

func hit_enemy(enemy: AlienBug, damage: float) -> void:
	if enemy.hp <= 0: return
	enemy.hp -= maxf(1, damage - enemy.data.armor)
	if enemy.hp <= 0:
		kills += 1
		alloy += enemy.data.reward
		effects.append({"kind": "death", "to": enemy.position, "color": enemy.data.tint, "life": 0.3})

func finish(won: bool) -> void:
	if phase >= Phase.VICTORY: return
	phase = Phase.VICTORY if won else Phase.DEFEAT
	best = maxi(best, cleared)
	save_settings()
	board.position = Vector2(12, 64)
	var summary := "存活 %02d:%02d   /   击杀 %d   /   通过 %d / 10 波\n最高纪录：%d 波\n\n%s" % [int(elapsed) / 60, int(elapsed) % 60, kills, cleared, best, "撤离成功！前哨的研究资料已安全带回。" if won else "核心已失守。试试保护采矿机，搭配火炮与减速塔。"]
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
	upgrade_button.disabled = true
	repair_button.disabled = true
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
		details.text = "点击建筑查看详情\n基础补给：每 5 秒 +2 合金"
		sell_button.text = "出售"
	pause_button.text = "继续" if paused else "暂停"
	next_button.disabled = phase != Phase.PREPARE or paused
	var direction := ""
	for side in board.approach_sides:
		direction += ["北 ", "东 ", "南 ", "西 "][side]
	hint.text = "来袭方向：%s  |  1—5 选建筑 · 右键取消\n空格 暂停布防 · Enter 迎战 · 点击建筑管理" % direction

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
