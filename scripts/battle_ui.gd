class_name BattleUI
extends RefCounted

static func make_ui(game: Node) -> void:
	var canvas := CanvasLayer.new()
	game.add_child(canvas)
	game.label_at(canvas, "异星撤离 · v0.4.1", Vector2(12, 6), Vector2(300, 20), 16)
	game.achievement_toast = game.label_at(canvas, "", Vector2(220, 8), Vector2(200, 20), 10)
	game.hud = game.label_at(canvas, "", Vector2(12, 30), Vector2(620, 28), 12)
	game.label_at(canvas, "防御部署", Vector2(474, 62), Vector2(155, 20), 13)
	var display_order := [0, 1, 2, 3, 4, 5, 6]
	var short_names := ["机枪", "火炮", "减速", "围墙", "采矿", "电弧", "狙击"]
	game.build_buttons.resize(game.BUILDINGS.size())
	for slot in display_order.size():
		var i: int = display_order[slot]
		var config: BuildingData = game.BUILDINGS[i]
		var button: Button = game.button_at(canvas, "%d %s %d" % [i + 1, short_names[i], config.cost], Vector2(474 + (slot % 2) * 80, 84 + (slot / 2) * 33), Vector2(74, 31), game.choose_building.bind(i))
		button.add_theme_font_size_override("font_size", 9)
		button.tooltip_text = config.title + "：" + game.building_description(config.key)
		game.build_buttons[i] = button
	game.details = game.label_at(canvas, "", Vector2(474, 220), Vector2(154, 35), 10)
	game.upgrade_button = game.button_at(canvas, "升级", Vector2(474, 258), Vector2(74, 24), game.upgrade_selected)
	game.repair_button = game.button_at(canvas, "维修", Vector2(554, 258), Vector2(74, 24), game.repair_selected)
	game.sell_button = game.button_at(canvas, "出售", Vector2(474, 286), Vector2(74, 24), game.sell_selected)
	game.pause_button = game.button_at(canvas, "暂停", Vector2(554, 286), Vector2(74, 24), game.toggle_pause)
	game.next_button = game.button_at(canvas, "提前迎战  Enter", Vector2(474, 318), Vector2(154, 28), game.start_wave)
	game.mission_hud = game.label_at(canvas, "", Vector2(12, 48), Vector2(450, 15), 9)
	game.hint = game.label_at(canvas, "", Vector2(12, 324), Vector2(450, 30), 10)
	game.button_at(canvas, "重开", Vector2(494, 6), Vector2(60, 22), game.confirm_restart)
	game.button_at(canvas, "帮助", Vector2(562, 6), Vector2(66, 22), game.show_help)
	if game.managed: game.button_at(canvas, "舰桥", Vector2(428, 6), Vector2(58, 22), game.bridge)
	game.overlay = ColorRect.new()
	game.overlay.color = Color(0.015, 0.025, 0.045, 0.96)
	game.overlay.size = Vector2(640, 360)
	canvas.add_child(game.overlay)
	game.overlay_title = game.label_at(game.overlay, "", Vector2(64, 35), Vector2(520, 40), 26)
	var body_scroll := ScrollContainer.new()
	body_scroll.position = Vector2(64, 86)
	body_scroll.size = Vector2(520, 155 if game.managed else 195)
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	game.overlay.add_child(body_scroll)
	var body_box := VBoxContainer.new()
	body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_scroll.add_child(body_box)
	game.overlay_body = game.label_at(body_box, "", Vector2.ZERO, Vector2(500, 0), 11)
	game.overlay_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	game.overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	game.overlay_button = game.button_at(game.overlay, "", Vector2(64, 288), Vector2(200, 34), game.overlay_action)
	var sound := CheckButton.new()
	sound.text = "音效"
	sound.position = Vector2(295, 288)
	sound.add_theme_font_override("font", game.font)
	sound.add_theme_font_size_override("font_size", 12)
	sound.button_pressed = game.sound_enabled
	sound.toggled.connect(func(value: bool): game.sound_enabled = value; game.save_settings())
	game.overlay.add_child(sound)
	var shake := CheckButton.new()
	shake.text = "震动"
	shake.position = Vector2(420, 288)
	shake.add_theme_font_override("font", game.font)
	shake.add_theme_font_size_override("font_size", 12)
	shake.button_pressed = game.shake_enabled
	shake.toggled.connect(func(value: bool): game.shake_enabled = value; game.save_settings())
	game.overlay.add_child(shake)
	if game.managed:
		game.result_retry = game.button_at(game.overlay, "按原配置重试", Vector2(280, 250), Vector2(170, 28), game.retry_mission)
		game.result_retry.hide()

