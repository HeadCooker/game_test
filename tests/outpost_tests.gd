extends SceneTree
## Exercises real mouse input and the campaign entry points for the 3D view.
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func click(point: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)

func next_scene() -> void:
	await process_frame
	await process_frame

func run() -> void:
	var campaign = root.get_node("Campaign")
	campaign.slot = 3
	campaign.profile = campaign.fresh()
	campaign.shared.music = false
	campaign.shared.sound = false
	change_scene_to_file("res://scenes/shell.tscn")
	await next_scene()
	var shell = current_scene
	check(shell.page == "home", "New session opens on the illustrated title")
	shell.show_page("bridge")
	shell.show_page("missions")
	shell.prepare(1)
	click(shell.launch_button.get_global_rect().get_center())
	await next_scene()
	var game = current_scene
	if not is_instance_valid(game) or not "outpost_view" in game:
		push_error("Deployment button did not open the battle")
		quit(1)
		return
	game.set_process(false)
	click(game.overlay_button.get_global_rect().get_center())
	var view: OutpostView = game.outpost_view
	if view == null:
		push_error("Mission one did not mount its 3D view")
		quit(1)
		return
	for resolution in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		root.size = resolution
		await next_scene()
		for cell in [Vector2i(0, 0), Vector2i(15, 0), Vector2i(0, 15), Vector2i(15, 15), BattleBoard.CORE, Vector2i(7, 6)]:
			var at := view.screen_point(game.board.center(cell), 0)
			check(game.pointer_cell(view.get_global_transform_with_canvas() * at) == cell, "Projected tile round-trips: %s %s" % [resolution, cell])
	var tower_cell := Vector2i(7, 7)
	var miner_cell := Vector2i(9, 8)
	var tower_point := view.get_global_transform_with_canvas() * view.screen_point(game.board.center(tower_cell), 0)
	var miner_point := view.get_global_transform_with_canvas() * view.screen_point(game.board.center(miner_cell), 0)
	game.alloy = 600
	click(game.build_buttons[0].get_global_rect().get_center())
	click(tower_point)
	check(game.board.buildings.has(tower_cell), "Clicking a projected tile builds a tower")
	click(game.build_buttons[4].get_global_rect().get_center())
	click(miner_point)
	if not game.board.buildings.has(miner_cell):
		push_error("Clicking a projected tile did not build the miner")
		quit(1)
		return
	game.board.buildings[miner_cell].stored_alloy = 16
	click(miner_point)
	check(game.mined_total == 16 and game.board.selected == miner_cell, "3D miner click collects and selects")
	game.board.buildings[miner_cell].stored_alloy = 20
	game.select_action("mine")
	click(game.build_buttons[0].get_global_rect().get_center())
	check(game.mines.is_empty() and game.action_mode.is_empty(), "HUD click changes tool without planting a mine")
	game.select_action("mine")
	var mine_cell := Vector2i(8, 6)
	click(view.get_global_transform_with_canvas() * view.screen_point(game.board.center(mine_cell), 0))
	check(game.has_mine(mine_cell), "Mine lands on the highlighted grid cell")
	game.strike_cooldown = 12.5
	game.bridge()
	await next_scene()
	campaign.load_profile(3)
	shell = current_scene
	check(shell.page == "bridge", "Returning from battle opens the bridge")
	shell.continue_game()
	await next_scene()
	game = current_scene
	game.set_process(false)
	check(game.outpost_view != null and game.board.buildings.has(tower_cell), "Disk resume reconstructs the 3D mission")
	check(game.board.buildings[miner_cell].stored_alloy == 20 and game.strike_cooldown == 12.5 and game.has_mine(mine_cell), "Disk resume preserves stock, mine and cooldown")
	game.overlay_action()
	game.start_wave()
	game.strike_cooldown = 0
	game.select_action("strike")
	view = game.outpost_view
	click(view.get_global_transform_with_canvas() * view.screen_point(game.board.center(mine_cell), 0))
	check(game.strike_cooldown == 25 and game.effects[-1].to == game.board.center(mine_cell), "Strike lands on the intended tile")
	game.finish(true)
	check(game.overlay_button.text == "返回舰桥", "Result exposes the return action")
	click(game.overlay_button.get_global_rect().get_center())
	await next_scene()
	shell = current_scene
	shell.prepare(2)
	shell.launch_new()
	await next_scene()
	game = current_scene
	check(game.outpost_view == null and game.board.visible, "Later campaign mission keeps its pixel battlefield")
	game.finish(false)
	game.overlay_action()
	await next_scene()
	for i in range(1, 4): campaign.profile.records[str(i)] = {"medals": [true, true, true]}
	campaign.start_expedition([0], "", false)
	campaign.launch_expedition()
	change_scene_to_file("res://scenes/main.tscn")
	await next_scene()
	game = current_scene
	check(game.outpost_view == null and game.board.visible, "Expedition keeps its pixel battlefield")
	game.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	print("OUTPOST FAILURES: ", failures)
	quit(1 if failures else 0)
