class_name BattleBoard
extends Node2D
## One shared grid drives placement and enemy routes.
const CELL := 16
const WIDTH := 28
const HEIGHT := 16
const CORE := Vector2i(14, 8)
var buildings: Dictionary = {}
var hit_flash := 0.0
var distance: Dictionary = {}
var route_fields: Array[Dictionary] = []
const STEPS = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN, Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1)]
var hover := Vector2i(-1, -1)
var preview_color := Color.TRANSPARENT
var selected := Vector2i(-1, -1)
var preview_radius := 0.0
var approach_sides: PackedInt32Array = PackedInt32Array([0])

func _ready() -> void:
	position = Vector2(12, 64)
	rebuild_routes()

func center(cell: Vector2i) -> Vector2:
	return Vector2(cell * CELL) + Vector2.ONE * CELL / 2.0

func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))

func inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < WIDTH and cell.y < HEIGHT

func can_build(cell: Vector2i) -> bool:
	return inside(cell) and cell.x > 0 and cell.y > 0 and cell.x < WIDTH - 1 and cell.y < HEIGHT - 1 and cell != CORE and not buildings.has(cell)

func diagonal_clear(cell: Vector2i, neighbor: Vector2i) -> bool:
	var delta := neighbor - cell
	if delta.x != 0 and delta.y != 0:
		return not buildings.has(cell + Vector2i(delta.x, 0)) and not buildings.has(cell + Vector2i(0, delta.y))
	return true

func entry_cost(cell: Vector2i) -> float:
	if not buildings.has(cell): return 0.0
	var tower: DefenseTower = buildings[cell]
	# A wall costs roughly ten walking tiles: a large detour is no longer free.
	return 4.0 + tower.max_health() / 60.0

func travel_cost(cell: Vector2i, neighbor: Vector2i, variant: int) -> float:
	var noise := float(posmod(neighbor.x * 37 + neighbor.y * 71 + variant * 113 + neighbor.x * neighbor.y * (variant + 1), 17)) / 17.0
	return Vector2(neighbor - cell).length() + noise * 0.5 + entry_cost(neighbor)

func rebuild_routes() -> void:
	# Three positive-cost flow fields give consistent but different route preferences.
	# Diagonals never cross an occupied corner. Fields change only with buildings.
	route_fields.clear()
	for variant in 3:
		var field: Dictionary = {CORE: 0.0}
		var open: Array[Vector2i] = [CORE]
		while not open.is_empty():
			var best := 0
			for i in range(1, open.size()):
				if field[open[i]] < field[open[best]]: best = i
			var cell: Vector2i = open.pop_at(best)
			for step in STEPS:
				var neighbor: Vector2i = cell + step
				if not inside(neighbor) or not diagonal_clear(neighbor, cell): continue
				var candidate: float = field[cell] + travel_cost(neighbor, cell, variant)
				if candidate < field.get(neighbor, INF):
					field[neighbor] = candidate
					if not open.has(neighbor): open.append(neighbor)
		route_fields.append(field)
	distance = route_fields[0]

func next_cell(cell: Vector2i, variant: int = 0) -> Vector2i:
	if cell == CORE: return CORE
	variant = posmod(variant, route_fields.size())
	var field := route_fields[posmod(variant, route_fields.size())]
	var result := cell
	var best := INF
	for step in STEPS:
		var neighbor: Vector2i = cell + step
		if inside(neighbor) and diagonal_clear(cell, neighbor):
			var cost: float = field.get(neighbor, INF) + travel_cost(cell, neighbor, variant)
			if cost < best:
				best = cost
				result = neighbor
	return result

func _draw() -> void:
	draw_rect(Rect2(0, 0, WIDTH * CELL, HEIGHT * CELL), Color("111f2b"))
	for y in HEIGHT:
		for x in WIDTH:
			var cell := Vector2i(x, y)
			var rect := Rect2(Vector2(cell * CELL), Vector2.ONE * CELL)
			if (x * 13 + y * 7) % 11 == 0:
				draw_rect(Rect2(rect.position + Vector2(4, 5), Vector2(3, 2)), Color("26313b"))
			if x == 0 or y == 0 or x == WIDTH - 1 or y == HEIGHT - 1:
				draw_rect(rect, Color("332b36"))
			draw_rect(rect, Color("1b2c38"), false)
	for side in approach_sides:
		var p := Vector2(224, 5)
		if side == 1: p = Vector2(443, 128)
		if side == 2: p = Vector2(224, 251)
		if side == 3: p = Vector2(5, 128)
		draw_circle(p, 4, Color("ff8b64"))
	var p := center(CORE)
	draw_rect(Rect2(p - Vector2(7, 7), Vector2(14, 14)), Color("293e55"))
	draw_rect(Rect2(p - Vector2(4, 5), Vector2(8, 10)), Color("ffae91") if hit_flash > 0 else Color("65e5ee"))
	draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 6)), Color("d9fcf4"))
	if inside(hover) and preview_color.a > 0:
		draw_rect(Rect2(Vector2(hover * CELL), Vector2.ONE * CELL), preview_color)
		if preview_radius > 0:
			draw_arc(center(hover), preview_radius, 0, TAU, 48, Color(0.4, 0.9, 0.8, 0.4))
	if inside(selected):
		draw_rect(Rect2(Vector2(selected * CELL), Vector2.ONE * CELL), Color("ffffff"), false)
