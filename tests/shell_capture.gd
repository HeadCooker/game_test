extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = root.get_node("Campaign")
	store.slot = 3
	store.profile = store.fresh()
	var shell = load("res://scenes/shell.tscn").instantiate()
	root.add_child(shell)
	for name in ["bridge", "missions", "brief", "expedition", "achievements", "settings"]:
		if name == "brief": shell.prepare(1)
		else: shell.show_page(name)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://build/%s.png" % name)
	# Preview a later save without touching any player profile.
	for i in range(1, 7): store.profile.records[str(i)] = {"medals": [true, true, false]}
	store.start_expedition([0, 1, 6], "", false)
	store.profile.expedition.cleared = 1
	store.profile.expedition.stash = 10
	store.profile.expedition.status = "safe"
	shell.show_page("expedition")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/expedition-safe.png")
	shell.prepare(5)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://build/loadout.png")
	shell.queue_free()
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
	quit()
