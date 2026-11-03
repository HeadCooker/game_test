extends SceneTree
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var store = root.get_node("Campaign")
	store.slot = 3
	for seed_value in [42, 2026, 112]:
		store.profile = store.fresh()
		for index in range(1, 4):
			var loadout: Array = [0]
			for kind in [1, 2]:
				if GameCatalog.unlocked_towers(store.profile).has(kind): loadout.append(kind)
			if not store.begin_mission(index, loadout, ""): break
			var game = load("res://scenes/main.tscn").instantiate()
			root.add_child(game)
			game.set_process(false)
			game.started = true
			game.overlay.hide()
			game.rng.seed = seed_value
			var positions: Array[Vector2i] = []
			for radius in [2, 4, 6]:
				for offset in [Vector2i.LEFT, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1)]:
					var cell: Vector2i = BattleBoard.CORE + offset * radius
					if game.board.inside(cell) and not game.board.rocks.has(cell) and not game.board.forbidden.has(cell): positions.append(cell)
			var ticks := 0
			while game.phase < game.Phase.VICTORY and ticks < 15000:
				if game.phase == game.Phase.PREPARE:
					for cell in [Vector2i(13, 9), Vector2i(15, 9)]:
						if game.station_count() < (2 if index == 3 else 1): game.place_building(cell, 4)
					for i in positions.size():
						if game.board.buildings.has(positions[i]): continue
						var kind := 1 if loadout.has(1) and i % 3 == 2 else 0
						if not game.place_building(positions[i], kind): break
					for tower: DefenseTower in game.board.buildings.values():
						if tower.data.damage > 0 and tower.level < 3 and game.alloy >= tower.upgrade_cost():
							game.board.selected = tower.cell; game.upgrade_selected()
					game.start_wave()
				if ticks % 12 == 0:
					for tower: DefenseTower in game.board.buildings.values():
						if tower.hp < tower.max_health() * 0.5:
							game.board.selected = tower.cell; game.repair_selected()
				game._process(0.15)
				ticks += 1
			var won: bool = game.phase == game.Phase.VICTORY
			print("seed=%d mission=%d result=%s cleared=%d core=%d mining=%d time=%d" % [seed_value, index, "WIN" if won else "LOSS", game.cleared, int(game.core_hp), game.mined_total, int(game.elapsed)])
			game.queue_free()
			await process_frame
			if not won: break
	quit()

