class_name BattleSave
extends RefCounted
const FIELDS := ["alloy", "core_hp", "core_damage", "wave", "cleared", "kills", "elapsed", "timer", "mined_total", "spawn_serial", "rewarded_wave", "last_clear_reward"]

static func capture(game: Node) -> Dictionary:
	var snapshot := {"version": 1, "request_id": game.request.id, "fields": {}, "rng_state": str(game.rng.state), "emergency_waves": game.emergency_waves.duplicate(), "damage_sources": game.damage_sources.duplicate(), "buildings": []}
	for field in FIELDS: snapshot.fields[field] = game.get(field)
	for tower: DefenseTower in game.board.buildings.values():
		snapshot.buildings.append({"type": game.BUILDINGS.find(tower.data), "x": tower.cell.x, "y": tower.cell.y, "level": tower.level, "hp": tower.hp, "invested": tower.invested, "mining": tower.mining_timer, "cooldown": tower.cooldown})
	return snapshot

static func restore(game: Node, snapshot: Dictionary) -> bool:
	if snapshot.get("version", 0) != 1 or snapshot.get("request_id", "") != game.request.id: return false
	for field in FIELDS:
		if snapshot.get("fields", {}).has(field): game.set(field, snapshot.fields[field])
	game.emergency_waves = snapshot.get("emergency_waves", []).duplicate()
	game.damage_sources = snapshot.get("damage_sources", {}).duplicate()
	for tower: DefenseTower in game.board.buildings.values(): tower.queue_free()
	game.board.buildings.clear()
	for record in snapshot.get("buildings", []):
		var index := int(record.type)
		var cell := Vector2i(int(record.x), int(record.y))
		if index < 0 or index >= game.BUILDINGS.size() or not game.board.can_build(cell): continue
		var tower: DefenseTower = game.TOWER_SCENE.instantiate()
		tower.setup(game.BUILDINGS[index], cell)
		game.apply_tower_bonus(tower)
		tower.level = clampi(int(record.level), 1, 3)
		tower.hp = clampf(float(record.hp), 1, tower.max_health())
		tower.invested = int(record.invested)
		tower.mining_timer = float(record.mining)
		tower.cooldown = float(record.get("cooldown", 0))
		tower.position = game.board.center(cell)
		game.board.add_child(tower)
		game.board.buildings[cell] = tower
	game.rng.state = int(snapshot.rng_state)
	game.phase = game.Phase.PREPARE
	game.board.approach_sides = game.waves[mini(game.wave, game.waves.size() - 1)].sides
	game.board.rebuild_routes()
	return true
