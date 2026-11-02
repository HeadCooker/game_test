extends SceneTree
var game: Node2D
var samples: Array[float] = []
var frames := 0
var previous := 0

func _initialize() -> void:
	call_deferred("begin")

func begin() -> void:
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.started = true
	game.overlay.hide()
	game.phase = game.Phase.ATTACK
	game.wave = 10
	game.spawned = game.waves[9].count
	game.alloy = 100000
	game.core_hp = 1000000
	for y in range(3, 14, 2):
		for x in range(5, 24, 3): game.place_building(Vector2i(x, y), (x + y) % 3)
	for i in 200:
		game.spawned = i
		game.spawn_enemy(game.waves[9])
		game.enemies[-1].hp = 1000000
		game.enemies[-1].max_hp = 1000000
	game.spawned = game.waves[9].count
	previous = Time.get_ticks_usec()
	process_frame.connect(measure)

func measure() -> void:
	var now := Time.get_ticks_usec()
	frames += 1
	if frames > 60: samples.append((now - previous) / 1000.0)
	previous = now
	if frames >= 360:
		samples.sort()
		var total := 0.0
		for sample in samples: total += sample
		var mean := total / samples.size()
		var report := "200 enemies, 42 towers, 1920x1080 Compatibility\nmean %.2f ms / %.1f FPS; p95 %.2f ms\n" % [mean, 1000.0 / mean, samples[int(samples.size() * 0.95)]]
		print(report)
		var file := FileAccess.open("res://build/benchmark.txt", FileAccess.WRITE)
		file.store_string(report)
		file.close()
		process_frame.disconnect(measure)
		game.queue_free()
		await process_frame
		quit()
