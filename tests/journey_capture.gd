extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = root.get_node("Campaign")
	store.slot = 2
	store.profile = store.fresh()
	store.begin_mission(1, [0], "")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mission-intro.png")
	game.started = true
	game.overlay.hide()
	game.place_building(Vector2i(12, 7), 0)
	game.place_building(Vector2i(16, 7), 0)
	game.place_building(Vector2i(14, 10), 4)
	game.start_wave()
	for i in 150: game._process(0.1)
	game.board.selected = Vector2i(12, 7)
	game.selected_type = -1
	game.update_preview()
	game.refresh_ui()
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mission-battle.png")
	game.finish(false)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/mission-result.png")
	game.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	quit()
