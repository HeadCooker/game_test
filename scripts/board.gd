class_name BattleBoard
extends Node2D
## One shared grid drives placement and enemy routes.
const CELL := 16
const WIDTH := 28
const HEIGHT := 16
const CORE := Vector2i(14, 8)
var buildings: Dictionary = {}
var distance: Dictionary = {}
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

func rebuild_routes() -> void:
	# Reverse weighted Dijkstra: open paths are preferred; sealed bases remain reachable
	# by chewing through buildings. Rebuilt on occupancy changes, never per enemy.
	distance = {CORE: 0.0}
	var open: Array[Vector2i] = [CORE]
	while not open.is_empty():
		var best := 0
		for i in range(1, open.size()):
			if distance[open[i]] < distance[open[best]]:
				best = i
		var cell: Vector2i = open.pop_at(best)
		var cost := 1.0 + (1000.0 if buildings.has(cell) else 0.0)
		for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + step
			if not inside(neighbor):
				continue
			var candidate: float = distance[cell] + cost
			if candidate < distance.get(neighbor, INF):
				distance[neighbor] = candidate
				if not open.has(neighbor):
					open.append(neighbor)

func next_cell(cell: Vector2i) -> Vector2i:
	var result := cell
	var best := INF
	for step in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		var neighbor: Vector2i = cell + step
		if inside(neighbor):
			var cost: float = distance.get(neighbor, INF) + (1000.0 if buildings.has(neighbor) else 0.0)
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
	draw_rect(Rect2(p - Vector2(4, 5), Vector2(8, 10)), Color("65e5ee"))
	draw_rect(Rect2(p - Vector2(2, 3), Vector2(4, 6)), Color("d9fcf4"))
	if inside(hover) and preview_color.a > 0:
		draw_rect(Rect2(Vector2(hover * CELL), Vector2.ONE * CELL), preview_color)
		if preview_radius > 0:
			draw_arc(center(hover), preview_radius, 0, TAU, 48, Color(0.4, 0.9, 0.8, 0.4))
	if inside(selected):
		draw_rect(Rect2(Vector2(selected * CELL), Vector2.ONE * CELL), Color("ffffff"), false)
