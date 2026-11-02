extends SceneTree
## Deterministic economy samples, not a substitute for player testing.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for mixed in [false, true]:
		for seed_value in [42, 2026, 112]:
			var game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			game.set_process(false)
			game.started = true
			game.overlay.hide()
			game.rng.seed = seed_value
			var positions: Array[Vector2i] = []
			for radius in [2, 4, 6]:
				for offset in [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1)]:
					positions.append(BattleBoard.CORE + offset * radius)
			var purchase_index := 0
			var ticks := 0
			while game.phase < game.Phase.VICTORY and ticks < 15000:
				if game.phase == game.Phase.PREPARE:
					for i in purchase_index:
						if not game.board.buildings.has(positions[i]):
							var replacement: int = [0, 0, 0, 1, 2, 6, 5, 1, 6][i % 9] if mixed else 0
							game.place_building(positions[i], replacement)
					if mixed and game.wave >= 1 and game.station_count() == 0:
						game.place_building(Vector2i(13, 9), 4)
					while purchase_index < positions.size():
						var kind: int = [0, 0, 0, 1, 2, 6, 5, 1, 6][purchase_index % 9] if mixed else 0
						if not game.place_building(positions[purchase_index], kind): break
						purchase_index += 1
					for tower: DefenseTower in game.board.buildings.values():
						if tower.data.damage > 0 and tower.level < 3 and game.alloy >= tower.upgrade_cost():
							game.board.selected = tower.cell
							game.upgrade_selected()
					game.start_wave()
				if ticks % 12 == 0:
					for tower: DefenseTower in game.board.buildings.values():
						if tower.hp < tower.max_health() * 0.5:
							game.board.selected = tower.cell
							game.repair_selected()
				game._process(0.15)
				ticks += 1
			print("%s seed=%d cleared=%d core=%d money=%d towers=%d result=%s" % ["mixed" if mixed else "gun-only", seed_value, game.cleared, int(game.core_hp), game.alloy, game.board.buildings.size(), "WIN" if game.phase == game.Phase.VICTORY else "LOSS"])
			game.queue_free()
			await process_frame
	quit()
