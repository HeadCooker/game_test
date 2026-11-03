extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	if OS.get_cmdline_user_args().has("--menu"):
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/preview-menu.png")
		quit()
		return
	game.started = true
	game.overlay.hide()
	game.alloy = 900
	for cell in [Vector2i(11, 6), Vector2i(17, 6), Vector2i(11, 10), Vector2i(17, 10)]:
		game.place_building(cell, 0)
	game.place_building(Vector2i(14, 5), 1)
	game.place_building(Vector2i(14, 11), 2)
	game.place_building(Vector2i(12, 8), 4)
	for x in range(10, 19): game.place_building(Vector2i(x, 4), 3)
	game.wave = 5
	game.board.approach_sides = game.waves[5].sides
	game.start_wave()
	for i in 180: game._process(0.1)
	if OS.get_cmdline_user_args().has("--combat"):
		for enemy: AlienBug in game.enemies: enemy.hp = 0
		game.update_towers(0.0)
		game.effects.clear()
		game.place_building(Vector2i(5, 9), 3)
		var attacker: AlienBug = game.spawn_enemy(game.waves[0], 0)
		attacker.lane_offset = Vector2.ZERO
		attacker.position = game.board.center(Vector2i(5, 8)) + Vector2(0, -0.3)
		attacker.route_from = Vector2i(5, 8)
		attacker.destination = Vector2i(5, 9)
		var ranged: AlienBug = game.spawn_enemy(game.waves[0], 5)
		ranged.position = game.board.center(Vector2i(5, 6))
		ranged.destination = Vector2i(5, 6)
		game.update_enemies(0.05)
		game.update_enemies(0.05)
		for effect in game.effects: effect.life -= 0.06
		game.effect_layer.queue_redraw()
	if OS.get_cmdline_user_args().has("--indicators"):
		for enemy: AlienBug in game.enemies: enemy.hp = 0
		game.update_towers(0.0)
		game.effects.clear()
		for i in 3:
			var shield: AlienBug = game.spawn_enemy(game.waves[0], 6)
			shield.position = game.board.center(Vector2i(10 + i * 3, 7))
			shield.shield_hp = shield.max_shield * (1.0 - i * 0.5)
			shield.hp = shield.max_hp * 0.75
		game.selected_type = -1
		game.board.selected = Vector2i(14, 5)
		game.update_preview()
	game.toggle_pause()
	game.refresh_ui()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/preview.png")
	quit()
