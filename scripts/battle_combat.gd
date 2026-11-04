class_name BattleCombat
extends RefCounted

static func update_enemies(game: Node, delta: float) -> void:
	for enemy: AlienBug in game.enemies.duplicate():
		if enemy.hp <= 0: continue
		enemy.animation += delta
		enemy.attack_flash = maxf(0, enemy.attack_flash - delta)
		if enemy.emerging > 0:
			enemy.emerging = maxf(0, enemy.emerging - delta)
			enemy.queue_redraw()
			continue
		enemy.slow_time = maxf(0, enemy.slow_time - delta)
		enemy.attack_timer -= delta
		enemy.since_hit += delta
		if enemy.max_shield > 0 and enemy.since_hit >= 3:
			enemy.shield_hp = minf(enemy.max_shield, enemy.shield_hp + enemy.max_shield * 0.18 * delta)
		var enraged := enemy.data.ability == "boss" and enemy.hp < enemy.max_hp * 0.5
		if enemy.data.ability == "boss":
			enemy.summon_timer -= delta
			if enemy.summon_timer <= 0:
				enemy.summon_timer = 6.0 if enraged else 9.0
				game.summon_minions(enemy)
		var at_waypoint := enemy.position.distance_to(enemy.waypoint(enemy.destination)) < 0.1
		if at_waypoint:
			enemy.route_from = enemy.destination
			enemy.destination = game.board.next_cell(enemy.route_from, enemy.route_variant)
		var target: DefenseTower = game.board.buildings.get(enemy.destination)
		var attacks_core := enemy.position.distance_to(game.board.center(BattleBoard.CORE)) <= enemy.data.attack_range
		if enemy.data.ability == "spitter":
			# Ranged siege stops outside the wall and attacks nearby defenses first.
			var nearest := enemy.data.attack_range
			for tower: DefenseTower in game.board.buildings.values():
				var distance := enemy.position.distance_to(tower.position)
				if distance <= nearest:
					nearest = distance
					target = tower
			if target != null and enemy.position.distance_to(target.position) > enemy.data.attack_range:
				target = null
			if target != null: attacks_core = false
		if target != null or attacks_core:
			if enemy.attack_timer <= 0:
				enemy.attack_timer = enemy.data.attack_interval / (1.5 if enraged else 1.0)
				var damage := enemy.data.damage * (1.5 if enraged else 1.0)
				var impact: Vector2 = game.board.center(BattleBoard.CORE) if attacks_core else target.position
				enemy.attack_flash = 0.28
				enemy.attack_direction = (impact - enemy.position).normalized()
				var ranged := enemy.data.ability == "spitter"
				game.effects.append({"kind": "acid" if ranged else "claw", "from": enemy.position, "to": impact, "color": Color("b4ff6e") if ranged else Color("ff9b76"), "life": 0.32})
				if attacks_core:
					game.board.hit_flash = 0.25
					game.board.queue_redraw()
					game.take_core_damage(damage, enemy.data.title)
					if game.core_hp <= 0:
						game.finish(false)
						return
				else:
					target.hp -= damage
					target.hit_flash = 0.25
					target.queue_redraw()
					if target.hp <= 0: game.remove_building(target)
		else:
			var slow := lerpf(0.45, 1.0, enemy.data.slow_resistance) if enemy.slow_time > 0 else 1.0
			var speed: float = enemy.data.speed * slow * game.speed_multiplier * (1.5 if enraged else 1.0)
			enemy.position = enemy.position.move_toward(enemy.waypoint(enemy.destination), speed * delta)
		enemy.queue_redraw()


static func update_towers(game: Node, delta: float) -> void:
	for tower: DefenseTower in game.board.buildings.values():
		tower.cooldown -= delta
		tower.flash = maxf(0, tower.flash - delta)
		var was_hit := tower.hit_flash > 0
		tower.hit_flash = maxf(0, tower.hit_flash - delta)
		if was_hit: tower.queue_redraw()
		if tower.data.damage <= 0: continue
		if tower.cooldown > 0:
			tower.queue_redraw()
			continue
		var target: AlienBug = null
		var radius := tower.attack_radius()
		var best_score := -INF
		for enemy in game.enemies:
			var distance := tower.position.distance_to(enemy.position)
			if enemy.hp <= 0 or enemy.emerging > 0 or distance >= radius: continue
			var score := -distance
			if tower.data.key == "sniper": score = enemy.max_hp + enemy.max_shield - distance * 0.1
			if score > best_score:
				best_score = score
				target = enemy
		if target == null: continue
		tower.aim = (target.position - tower.position).normalized()
		tower.flash = 0.1
		tower.cooldown = tower.data.interval / (1 + (tower.level - 1) * 0.15)
		var damage: float = tower.data.damage * (1 + (tower.level - 1) * 0.65) * game.damage_multiplier
		var color := tower.data.tint
		game.effects.append({"kind": "shot", "from": tower.position, "to": target.position, "color": color, "life": 0.10})
		if tower.data.key == "cannon":
			var impact := target.position
			game.effects.append({"kind": "blast", "to": impact, "color": color, "life": 0.26})
			for enemy: AlienBug in game.enemies.duplicate():
				if enemy.position.distance_to(impact) < 28: game.hit_enemy(enemy, damage)
		elif tower.data.key == "tesla":
			game.chain_lightning(target, tower.position, damage, color)
		else:
			if tower.data.key == "slow": target.slow_time = 2.0
			game.hit_enemy(target, damage, "piercing" if tower.data.key == "sniper" else "normal")
		if game.sound_enabled and game.sound_cooldown <= 0:
			game.audio.pitch_scale = 0.65 if tower.data.key == "cannon" else 1.0
			game.audio.play()
			game.sound_cooldown = 0.09
		tower.queue_redraw()
	for i in range(game.enemies.size() - 1, -1, -1):
		if game.enemies[i].hp <= 0:
			game.enemies[i].queue_free()
			game.enemies.remove_at(i)


static func chain_lightning(game: Node, first: AlienBug, origin: Vector2, damage: float, color: Color) -> void:
	var visited: Array[AlienBug] = []
	var target := first
	var previous := origin
	for bounce in 4:
		if target == null: break
		visited.append(target)
		game.effects.append({"kind": "shot", "from": previous, "to": target.position, "color": color, "life": 0.22})
		game.hit_enemy(target, damage * pow(0.8, bounce), "energy")
		previous = target.position
		target = null
		var nearest := 44.0
		for other in game.enemies:
			if visited.has(other) or other.hp <= 0 or other.emerging > 0: continue
			var distance := previous.distance_to(other.position)
			if distance < nearest:
				nearest = distance
				target = other

	if game.managed and visited.size() == 4: Campaign.award("chain")


static func hit_enemy(game: Node, enemy: AlienBug, damage: float, mode: String = "normal") -> void:
	var shield_before := enemy.shield_hp
	if enemy.hp <= 0 or enemy.emerging > 0: return
	enemy.since_hit = 0.0
	var remaining := damage
	if mode != "piercing" and enemy.shield_hp > 0:
		var factor := 2.0 if mode == "energy" else 1.0
		var absorbed := minf(enemy.shield_hp, remaining * factor)
		enemy.shield_hp -= absorbed
		remaining -= absorbed / factor
	if game.managed and mode == "energy" and shield_before > 0 and enemy.shield_hp <= 0: Campaign.award("shield")
	if remaining > 0:
		enemy.hp -= remaining if mode == "piercing" else maxf(1, remaining - enemy.data.armor)
	if enemy.hp <= 0:
		if game.managed and mode == "piercing" and enemy.data == game.BUGS[2] and not enemy.summoned: Campaign.rail_kill(enemy.combat_id)
		if enemy.data.ability == "split": game.split_enemy(enemy)
		game.kills += 1
		if not enemy.summoned: game.alloy += enemy.data.reward
		game.effects.append({"kind": "death", "to": enemy.position, "color": enemy.data.tint, "life": 0.3})

