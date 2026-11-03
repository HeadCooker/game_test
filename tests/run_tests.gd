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
	check(breaker.attack_flash > 0 and game.effects.any(func(fx: Dictionary): return fx.kind == "claw"), "Melee attacks produce a lunge and claw impact")
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
	await feedback_checks()
	print("CHECKS: %d | FAILURES: %d" % [checks, failures])
	quit(1 if failures else 0)

func test_game():
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.started = true
	game.overlay.hide()
	game.rng.seed = 20261102
	return game

func feedback_checks() -> void:
	var game = test_game()
	for i in game.build_buttons.size():
		var rect: Rect2 = game.build_buttons[i].get_global_rect()
		check(rect.end.x <= 640 and rect.end.y < 220, "Building choice fits the viewport")
		for j in range(i + 1, game.build_buttons.size()):
			check(not rect.intersects(game.build_buttons[j].get_global_rect()), "Building buttons do not overlap")
	game.alloy = 1000
	game.place_building(Vector2i(13, 7), 0)
	game.board.selected = Vector2i(13, 7)
	game.refresh_ui()
	# Real press / release separated by repeated UI updates reproduces the old bug.
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = game.upgrade_button.get_global_rect().get_center()
	press.global_position = press.position
	press.pressed = true
	root.push_input(press)
	await process_frame
	for i in 5: game.refresh_ui()
	var release := press.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)
	await process_frame
	check(game.selected_tower().level == 2 and not game.paused, "Unpaused preparation upgrade works through a real UI click")
	var before_wait: int = game.alloy
	game._process(5.0)
	check(game.alloy == before_wait, "Waiting during preparation generates no income")
	game.place_building(Vector2i(10, 8), 4)
	game.place_building(Vector2i(10, 9), 4)
	game.place_building(Vector2i(10, 10), 4)
	check(not game.place_building(Vector2i(10, 11), 4), "Miners capped at three")
	var before_station_wait: int = game.alloy
	game._process(5.0)
	check(game.alloy == before_station_wait, "Miners do not produce timed income")
	game.start_wave()
	var mining_before: int = game.alloy
	game.update_mining(5.0)
	check(game.alloy == mining_before + 12, "Three miners each pay four after five combat seconds")
	game.paused = true
	game.update_mining(10.0)
	check(game.alloy == mining_before + 12, "Paused combat does not mine")
	game.paused = false
	game.evacuation = true
	game.update_mining(10.0)
	check(game.alloy == mining_before + 12, "Evacuation does not mine")
	game.evacuation = false
	game.update_mining(2.5)
	game.phase = game.Phase.PREPARE
	game.update_mining(50.0)
	check(game.alloy == mining_before + 12, "Preparation does not advance partial mining progress")
	game.phase = game.Phase.ATTACK
	game.update_mining(2.5)
	check(game.alloy == mining_before + 24, "Partial combat mining progress carries between waves")
	var before_clear: int = game.alloy
	game.grant_clear_reward()
	check(game.alloy == before_clear + game.waves[0].clear_reward, "Wave reward does not include mining payout")
	var after_clear: int = game.alloy
	game.grant_clear_reward()
	check(game.alloy == after_clear, "Wave completion cannot pay twice")
	# Clearing after waiting or immediately gives the same economic result.
	var immediate = test_game()
	var waiting = test_game()
	immediate.start_wave()
	for i in 30: waiting._process(1.0)
	waiting.start_wave()
	immediate.grant_clear_reward()
	waiting.grant_clear_reward()
	check(immediate.alloy == waiting.alloy, "Early wave start has no economic penalty")
	immediate.queue_free()
	waiting.queue_free()
	# Underground attacks start two tiles away, never inside a structure.
	var burrow: AlienBug = game.spawn_enemy(game.waves[2], 4)
	var underground_cell: Vector2i = game.board.cell_at(burrow.position)
	check(maxi(absi(underground_cell.x - BattleBoard.CORE.x), absi(underground_cell.y - BattleBoard.CORE.y)) == 2, "Burrow chooses the core's second ring")
	check(not game.board.buildings.has(underground_cell), "Burrow does not spawn inside a building")
	check(burrow.emerging > 1.0, "Burrow gives an emergence warning")
	var old_core: float = game.core_hp
	game.update_enemies(0.5)
	check(game.core_hp == old_core, "Warning phase cannot attack the core")
	check(not game.place_building(underground_cell, 3), "Cannot build on a warned emergence cell")
	# Shield recovery, counters and ranged siege are behavior tests, not just health checks.
	var shield: AlienBug = game.spawn_enemy(game.waves[0], 6)
	var old_hp: float = shield.hp
	game.hit_enemy(shield, 20)
	check(shield.hp == old_hp and shield.shield_hp == shield.max_shield - 20, "Normal fire first hits shields")
	game.hit_enemy(shield, 10, "energy")
	check(shield.shield_hp == shield.max_shield - 40, "Energy does double shield damage")
	var shield_before: float = shield.shield_hp
	game.hit_enemy(shield, 10, "piercing")
	check(shield.hp == old_hp - 10 and shield.shield_hp == shield_before, "Rail damage bypasses shields")
	shield.since_hit = 3.0
	game.update_enemies(0.5)
	check(shield.shield_hp > shield_before, "Shield regenerates after not being hit")
	var armored: AlienBug = game.spawn_enemy(game.waves[0], 2)
	var armor_hp: float = armored.hp
	game.hit_enemy(armored, 10, "piercing")
	check(armored.hp == armor_hp - 10, "Rail damage bypasses armor")
	var spitter: AlienBug = game.spawn_enemy(game.waves[0], 5)
	spitter.position = game.board.center(Vector2i(13, 4))
	spitter.route_from = Vector2i(13, 4)
	spitter.destination = Vector2i(13, 4)
	var tower: DefenseTower = game.board.buildings[Vector2i(13, 7)]
	var tower_hp: float = tower.hp
	game.update_enemies(0.1)
	check(spitter.attack_flash > 0 and tower.hit_flash > 0 and game.effects.any(func(fx: Dictionary): return fx.kind == "acid"), "Ranged attacks show windup, projectile and target hit feedback")
	check(tower.hp < tower_hp and spitter.position.distance_to(tower.position) > 30, "Spitter attacks structures from range")
	# Chain should hit nearby targets exactly once and never hit a distant one.
	for enemy: AlienBug in game.enemies: enemy.hp = 0
	game.update_towers(0.1)
	var chain_targets: Array[AlienBug] = []
	for i in 5:
		var target: AlienBug = game.spawn_enemy(game.waves[0], 0)
		target.position = Vector2(80 + 20 * i, 80)
		chain_targets.append(target)
	var distant: AlienBug = game.spawn_enemy(game.waves[0], 0)
	distant.position = Vector2(400, 200)
	game.chain_lightning(chain_targets[0], Vector2.ZERO, 5, Color.WHITE)
	var struck := 0
	for target in chain_targets:
		if target.hp < target.max_hp: struck += 1
	check(struck == 4 and distant.hp == distant.max_hp, "Tesla chains to four distinct nearby targets")
	var boss: AlienBug = game.spawn_enemy(game.waves[9], 3)
	boss.position = game.board.center(Vector2i(5, 5))
	boss.destination = Vector2i(5, 5)
	boss.route_from = Vector2i(5, 5)
	boss.hp = boss.max_hp * 0.4
	boss.summon_timer = 0
	var count_before: int = game.enemies.size()
	game.update_enemies(0.1)
	check(game.enemies.size() > count_before and boss.summon_timer == 6.0, "Enraged boss summons reinforcements faster")
	var child: AlienBug = game.enemies[-1]
	child.emerging = 0
	var money_before_child: int = game.alloy
	game.hit_enemy(child, 10000, "piercing")
	check(game.alloy == money_before_child and child.summoned, "Summoned enemies cannot be farmed for money")
	game.queue_free()
	await process_frame
	var navigation = test_game()
	navigation.alloy = 100000
	# A vertical wall with a distant gap: attacking is cheaper than a huge detour.
	for y in range(1, 15): navigation.place_building(Vector2i(12, y), 3)
	var cell := Vector2i(9, 8)
	var breaks_wall := false
	for i in 50:
		cell = navigation.board.next_cell(cell)
		if navigation.board.buildings.has(cell): breaks_wall = true; break
		if cell == BattleBoard.CORE: break
	check(breaks_wall, "A long detour makes enemies choose to breach a wall")
	var diagonal_from := Vector2i(5, 5)
	var diagonal_to := diagonal_from + Vector2i(1, 1)
	navigation.place_building(diagonal_from + Vector2i.RIGHT, 3)
	check(not navigation.board.diagonal_clear(diagonal_from, diagonal_to), "Diagonal paths cannot cut a blocked corner")
	navigation.queue_free()
	await process_frame
	var open_board = test_game()
	open_board.place_building(Vector2i(14, 5), 3)
	var short_route := Vector2i(14, 3)
	var short_route_avoids := true
	for i in 50:
		if short_route == BattleBoard.CORE: break
		short_route = open_board.board.next_cell(short_route)
		if open_board.board.buildings.has(short_route): short_route_avoids = false
	check(short_route == BattleBoard.CORE and short_route_avoids, "A short detour remains preferable to breaching")
	open_board.board.selected = Vector2i(14, 5)
	open_board.sell_selected()
	var walk_cell := Vector2i(3, 2)
	var found_diagonal := false
	for i in 30:
		var next: Vector2i = open_board.board.next_cell(walk_cell)
		var step := next - walk_cell
		if step.x != 0 and step.y != 0: found_diagonal = true
		walk_cell = next
		if walk_cell == BattleBoard.CORE: break
	check(found_diagonal, "Open terrain permits diagonal walking")
	var unique := {}
	for variant in 3:
		var route := ""
		cell = Vector2i(2, 2)
		var seen := {}
		for i in 448:
			if cell == BattleBoard.CORE: break
			check(not seen.has(cell), "Random route preference never cycles")
			seen[cell] = true
			cell = open_board.board.next_cell(cell, variant)
			route += str(cell)
		check(cell == BattleBoard.CORE, "Each route preference reaches core")
		unique[route] = true
	check(unique.size() > 1, "Different route preferences produce different open routes")
	var diagonal_enemy: AlienBug = open_board.spawn_enemy(open_board.waves[0], 0)
	diagonal_enemy.route_from = Vector2i(5, 5)
	diagonal_enemy.destination = Vector2i(6, 6)
	diagonal_enemy.position = diagonal_enemy.waypoint(Vector2i(5, 5))
	check(not open_board.place_building(Vector2i(6, 5), 3), "Cannot place a corner into an enemy's active diagonal segment")
	# With no defenses, the whole run should actually be losable.
	var ticks := 0
	while open_board.phase < open_board.Phase.VICTORY and ticks < 10000:
		if open_board.phase == open_board.Phase.PREPARE: open_board.start_wave()
		open_board._process(0.2)
		ticks += 1
	check(open_board.phase == open_board.Phase.DEFEAT, "Undefended base loses")
	open_board.queue_free()
	await process_frame
