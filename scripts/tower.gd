class_name DefenseTower
extends Node2D
var data: BuildingData
var cell: Vector2i
var hp: float
var level := 1
var invested := 0
var cooldown := 0.0
var aim := Vector2.UP
var flash := 0.0

func setup(config: BuildingData, grid_cell: Vector2i) -> void:
	data = config
	cell = grid_cell
	hp = data.health
	invested = data.cost

func max_health() -> float:
	return data.health * (1.0 + (level - 1) * 0.4)

func upgrade_cost() -> int:
	return int(data.cost * (0.8 + level * 0.4))

func _draw() -> void:
	var color := data.tint
	draw_rect(Rect2(-7, -6, 14, 13), Color("080e18"))
	draw_rect(Rect2(-6, -7, 12, 12), color.darkened(0.45))
	draw_rect(Rect2(-5, -6, 10, 9), color)
	if data.key == "wall":
		draw_line(Vector2(-5, 0), Vector2(5, 0), color.darkened(0.4), 2)
	elif data.key == "miner":
		draw_rect(Rect2(-3, -4, 6, 6), Color("192536"))
		draw_line(Vector2(-2, 4), Vector2(3, -4), Color("e8c7ff"), 2)
	else:
		draw_rect(Rect2(-3, -4, 6, 6), Color("273649"))
		if data.key == "tesla":
			draw_arc(Vector2.ZERO, 4, 0, TAU, 8, color.lightened(0.4), 2)
			draw_line(Vector2(-1, -5), Vector2(2, 2), Color("ffffff"), 1)
		else:
			draw_line(Vector2.ZERO, aim * (12 if data.key == "sniper" else 9), Color("ebf5ed") if flash > 0 else color.lightened(0.3), 2 if data.key == "sniper" else 3)
		for i in level:
			draw_rect(Rect2(-5 + i * 4, 4, 2, 2), Color("f6d782"))
	if hp < max_health():
		draw_rect(Rect2(-7, 8, 14, 2), Color("492d3b"))
		draw_rect(Rect2(-7, 8, 14 * maxf(0, hp / max_health()), 2), Color("70e8b2"))
