class_name AlienBug
extends Node2D
var data: EnemyData
var hp: float
var max_hp: float
var destination := Vector2i(-1, -1)
var attack_timer := 0.0
var slow_time := 0.0
var animation := 0.0

func setup(config: EnemyData, multiplier: float) -> void:
	data = config
	max_hp = data.health * multiplier
	hp = max_hp

func _draw() -> void:
	var s := data.size
	var c := data.tint if slow_time <= 0 else Color("8bc9ff")
	var wiggle := sin(animation * 14) * 1.5
	for side in [-1, 1]:
		for offset in [-1, 1]:
			draw_line(Vector2(side * 2, offset * 2), Vector2(side * (s + 2), offset * (s + wiggle)), c.darkened(0.25))
	draw_rect(Rect2(-s, -s, s * 2, s * 2), c.darkened(0.4))
	draw_rect(Rect2(-s + 1, -s + 1, s * 2 - 2, s * 2 - 2), c)
	draw_rect(Rect2(-2, -s, 1, 2), Color("fff3b7"))
	draw_rect(Rect2(1, -s, 1, 2), Color("fff3b7"))
	if hp < max_hp:
		draw_rect(Rect2(-s, -s - 4, s * 2, 1), Color("552c3a"))
		draw_rect(Rect2(-s, -s - 4, s * 2 * maxf(0, hp / max_hp), 1), Color("e5ac79"))
