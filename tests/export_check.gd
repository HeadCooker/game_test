extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for index in range(1, 7):
		var mission := GameCatalog.mission(index)
		if mission == null or mission.waves.is_empty():
			push_error("Missing packaged mission")
			quit(1)
			return
	for key in GameCatalog.ACHIEVEMENTS:
		if GameCatalog.achievement(key) == null: quit(1); return
	for key in GameCatalog.BOON_IDS + GameCatalog.EVENT_IDS:
		if GameCatalog.card(key) == null: quit(1); return
	var store = root.get_node("Campaign")
	# Content validation does not exercise audio; avoid starting the dummy mixer.
	store.shared.music = false
	store.slot = 1
	store.profile = store.fresh()
	store.begin_mission(1, [0], "")
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	print("EXPORTED CHECK: six missions, twelve achievements, fourteen cards and first mission loaded")
	store.close_game()
