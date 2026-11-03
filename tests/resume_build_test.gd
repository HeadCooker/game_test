extends SceneTree
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, title: String) -> void:
	if not value:
		failures += 1
		push_error(title)
func game_node():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.overlay_action()
	return game
func run() -> void:
	var store = root.get_node("Campaign")
	store.slot = 3
	store.profile = store.fresh()
	store.begin_mission(1, [0], "")
	var game = game_node()
	game.paused = true
	game.save_prepare()
	game.queue_free()
	await process_frame
	for disk in [false, true]:
		if disk: store.load_profile(3)
		store.continue_battle()
		game = game_node()
		print("RESUME disk=", disk, " loadout=", game.request.loadout, " allowed=", game.allowed_building(0), " disabled=", game.build_buttons[0].disabled)
		check(not game.build_buttons[0].disabled, "Resumed gun button must be enabled")
		game.choose_building(4)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = game.build_buttons[0].get_global_rect().get_center()
		click.global_position = click.position
		click.pressed = true
		root.push_input(click)
		await process_frame
		click = click.duplicate()
		click.pressed = false
		root.push_input(click)
		await process_frame
		check(game.selected_type == 0, "Actual gun click selects gun after resume")
		check(game.place_building(Vector2i(13, 7), 0), "Resumed carried gun can be built")
		check(not game.allowed_building(6), "Locked rail tower remains locked")
		game.queue_free()
		await process_frame
	store.profile = store.fresh()
	for index in range(1, 6): store.profile.records[str(index)] = {"medals": [true, false, false]}
	store.start_expedition([0, 1, 5], "emergency", false)
	store.launch_expedition()
	game = game_node()
	game.emergency_waves = [1]
	game.paused = true
	game.save_prepare()
	game.queue_free()
	await process_frame
	store.load_profile(3)
	store.continue_battle()
	game = game_node()
	for index in [0, 1, 5]:
		check(game.allowed_building(index) and not game.build_buttons[index].disabled, "Expedition carried tower remains selectable after disk resume")
	check(not game.allowed_building(6), "Uncarried but unlocked tower is not granted by normalization")
	check(game.emergency_waves.has(1), "Saved module usage restores integer wave IDs")
	game.queue_free()
	await process_frame
	await create_timer(0.2).timeout
	print("RESUME FAILURES: ", failures)
	quit(1 if failures else 0)
