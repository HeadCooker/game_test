class_name BattleEconomy
extends RefCounted

static func update_mining(game: Node, delta: float) -> void:
	if not game.started or game.paused or game.overlay.visible or game.phase != game.Phase.ATTACK or game.evacuation: return
	if game.spawned >= game.waves[game.wave - 1].count and game.enemies.is_empty(): return
	for tower: DefenseTower in game.board.buildings.values():
		if tower.data.key != "miner": continue
		tower.mining_timer += delta
		while tower.mining_timer >= game.MINING_INTERVAL:
			tower.mining_timer -= game.MINING_INTERVAL
			tower.stored_alloy = mini(40, tower.stored_alloy + game.mining_yield)
			tower.queue_redraw()



static func grant_clear_reward(game: Node) -> void:
	if game.wave <= game.rewarded_wave: return
	game.rewarded_wave = game.wave
	game.last_clear_reward = game.waves[game.wave - 1].clear_reward
	game.alloy += game.last_clear_reward
	game.economy_changed.emit()

