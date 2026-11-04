extends SceneTree
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
 if not ok:
  failures += 1
  push_error(message)
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 game.set_process(false)
 game.started = true
 game.overlay.hide()
 game.alloy = 500
 check(BattleBoard.WIDTH == BattleBoard.HEIGHT, "Square map")
 game._process(100)
 check(game.phase == game.Phase.PREPARE, "No automatic wave start")
 game.place_building(Vector2i(5, 5), 4)
 game.start_wave()
 var miner = game.board.buildings[Vector2i(5, 5)]
 var money: int = game.alloy
 game.update_mining(100)
 check(miner.stored_alloy == 40 and game.alloy == money, "Manual stock capped at forty")
 game.collect_miner(miner)
 game.collect_miner(miner)
 check(game.alloy == money + 40 and game.mined_total == 40, "Collection pays exactly once")
 game.select_action("mine")
 game.use_action(Vector2i(4, 4))
 check(game.mines.size() == 1 and game.alloy == money + 25, "Mine placement charges once")
 check(not game.place_building(Vector2i(4, 4), 0), "Mine prevents overlapping building")
 var bug = game.spawn_enemy(game.waves[0], 0)
 bug.position = game.board.center(Vector2i(4, 4))
 game.tick_mines()
 check(game.mines.is_empty() and bug.hp <= 0, "Mine triggers on approaching bug")
 var parent = game.spawn_enemy(game.waves[0], 7)
 parent.position = game.board.center(Vector2i(6, 6))
 var count: int = game.enemies.size()
 game.hit_enemy(parent, 10000)
 check(game.enemies.size() == count + 3, "Splitter creates three children")
 var child = game.enemies[-1]
 child.emerging = 0
 money = game.alloy
 game.hit_enemy(child, 10000)
 check(game.alloy == money and child.summoned, "Children cannot farm alloy")
 game.select_action("strike")
 game.use_action(Vector2i(6, 6))
 check(game.strike_cooldown == 25, "Strike consumes cooldown")
 game.select_action("strike")
 game.use_action(Vector2i(6, 6))
 check(game.strike_cooldown == 25, "Repeated click cannot bypass cooldown")
 game.queue_free()
 await process_frame
 await create_timer(0.2).timeout
 print("ACTIVE PLAY FAILURES: ", failures)
 quit(1 if failures else 0)
