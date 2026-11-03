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
	current_scene = game
	game.place_building(Vector2i(13, 7), 0)
	await process_frame
	await process_frame
	store.close_game()
	if store.profile.suspend.buildings.size() != 1:
		push_error("Window close did not save latest preparation")
		quit(1)
	else:
		print("CLOSE CHECK: latest preparation saved; audio shutdown pending")
