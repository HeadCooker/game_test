extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
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
	game.toggle_pause()
	game.refresh_ui()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/preview.png")
	quit()
