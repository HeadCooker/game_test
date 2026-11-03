class_name BattleWaves
extends RefCounted

static func tick(game: Node, delta: float) -> void:
	if game.phase == game.Phase.PREPARE:
		game.timer -= delta
		if game.timer <= 0: game.start_wave()
	elif game.evacuation:
		game.timer -= delta
		if game.timer <= 0: game.finish(true)
	else:
		var config: WaveData = game.waves[game.wave - 1]
		game.spawn_timer -= delta
		if game.spawned < config.count and game.spawn_timer <= 0:
			game.spawn_enemy(config)
			game.spawned += 1
			game.spawn_timer = config.spawn_interval
		if game.spawned >= config.count and game.enemies.is_empty():
			game.cleared = game.wave
			game.grant_clear_reward()
			if game.wave == game.waves.size():
				if game.managed and (game.request.mode == "expedition" or int(game.request.mission) != 6):
					game.finish(true)
					return
				game.evacuation = true
				game.timer = 30.0
			else:
				game.phase = game.Phase.PREPARE
				game.timer = game.waves[game.wave].preparation
				game.board.approach_sides = game.waves[game.wave].sides
				if game.managed: game.save_prepare()
