extends SceneTree
var failures := 0
var checks := 0

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.started = true
	game.overlay.hide()
	check(game.waves.size() == 10, "Ten wave configurations load")
	check(not game.place_building(Vector2i(0, 5), 0), "Spawn border cannot be built on")
	check(not game.place_building(BattleBoard.CORE, 0), "Core cannot be overwritten")
	var original: int = game.alloy
	check(game.place_building(Vector2i(13, 7), 0), "Valid tower placement succeeds")
	check(game.alloy == original - 45, "Placement charges once")
	check(not game.place_building(Vector2i(13, 7), 0), "Overlapping placement rejected")
	game.alloy = 0
	check(not game.place_building(Vector2i(12, 7), 0), "Unaffordable placement rejected")
	game.board.selected = Vector2i(13, 7)
	game.alloy = 1000
	game.upgrade_selected()
	game.upgrade_selected()
	var upgraded_money: int = game.alloy
	game.upgrade_selected()
	check(game.selected_tower().level == 3 and game.alloy == upgraded_money, "Only two upgrades may be purchased")
	game.selected_tower().hp -= 10
	game.repair_selected()
	check(game.selected_tower().hp == game.selected_tower().max_health(), "Repair restores health")
	game.sell_selected()
	var sold_money: int = game.alloy
	game.sell_selected()
	check(game.alloy == sold_money, "Repeated selling cannot duplicate refund")
	# Seal the core on four sides: the flow must direct a bug into a breakable wall.
	for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		game.place_building(BattleBoard.CORE + direction, 3)
	var cell := Vector2i(14, 0)
	var seen := {}
	var reached_wall := false
	for i in 448:
		check(not seen.has(cell), "Sealed route has no cycle")
		seen[cell] = true
		cell = game.board.next_cell(cell)
		if game.board.buildings.has(cell):
			reached_wall = true
			break
	check(reached_wall, "Sealed core routes to an attackable building")
	game.board.selected = BattleBoard.CORE + Vector2i.UP
	game.sell_selected()
	cell = Vector2i(14, 0)
	for i in 448:
		if cell == BattleBoard.CORE: break
		cell = game.board.next_cell(cell)
		check(not game.board.buildings.has(cell), "Open route avoids buildings")
	check(cell == BattleBoard.CORE, "Opening a gap restores route to core")
	# An enemy actually breaks a blocking wall and can then advance.
	game.spawn_enemy(game.waves[0])
	var breaker: AlienBug = game.enemies[0]
	var wall_cell := BattleBoard.CORE + Vector2i.RIGHT
	var blocker: DefenseTower = game.board.buildings[wall_cell]
	blocker.hp = 1
	breaker.position = game.board.center(wall_cell + Vector2i.RIGHT)
	breaker.destination = wall_cell
	game.update_enemies(0.1)
	check(not game.board.buildings.has(wall_cell), "Enemy destroys a blocking wall")
	var before_move := breaker.position
	game.update_enemies(0.1)
	check(breaker.position != before_move, "Enemy resumes movement after wall destruction")
	game.hit_enemy(breaker, 10000)
	game.update_towers(0.1)
	game.toggle_pause()
	var clock: float = game.timer
	game._process(1.0)
	check(game.timer == clock, "Paused battle clock does not advance")
	game.toggle_pause()
	game.start_wave()
	game._process(0.1)
	check(game.enemies.size() == 1, "Wave spawns an enemy")
	var enemy: AlienBug = game.enemies[0]
	check(not game.place_building(game.board.cell_at(enemy.position), 0), "Enemy occupied cell cannot be built on")
	var reward_money: int = game.alloy
	game.hit_enemy(enemy, 10000)
	game.hit_enemy(enemy, 10000)
	check(game.alloy == reward_money + enemy.data.reward and game.kills == 2, "Dead enemy grants reward only once")
	game.update_towers(0.1)
	# Exercise actual combat for every wave, with a strong test defense.
	game.alloy = 100000
	for y in range(3, 14, 3):
		for x in range(5, 25, 3):
			if game.place_building(Vector2i(x, y), 1):
				game.board.selected = Vector2i(x, y)
				game.upgrade_selected()
				game.upgrade_selected()
	var ticks := 0
	while game.phase < game.Phase.VICTORY and ticks < 30000:
		if game.phase == game.Phase.PREPARE: game.start_wave()
		game._process(0.1)
		ticks += 1
	check(game.phase == game.Phase.VICTORY and game.cleared == 10, "Ten waves, boss and evacuation reach victory")
	var final_phase: int = game.phase
	game.finish(false)
	check(game.phase == final_phase, "Terminal result cannot be overwritten")
	game.queue_free()
	await process_frame
	var fresh = load("res://scenes/main.tscn").instantiate()
	root.add_child(fresh)
	fresh.set_process(false)
	check(fresh.wave == 0 and fresh.enemies.is_empty() and fresh.alloy == 180, "Fresh run resets combat state")
	fresh.overlay.hide()
	fresh.started = true
	fresh.core_hp = 1
	fresh.start_wave()
	fresh.spawn_enemy(fresh.waves[0])
	fresh.enemies[0].position = fresh.board.center(BattleBoard.CORE)
	fresh.enemies[0].destination = BattleBoard.CORE
	fresh.update_enemies(0.1)
	check(fresh.phase == fresh.Phase.DEFEAT, "Core destruction triggers defeat")
	fresh.queue_free()
	await process_frame
	print("CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)
