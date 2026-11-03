class_name AlienBug
extends Node2D
var data: EnemyData
var hp: float
var max_hp: float
var destination := Vector2i(-1, -1)
var attack_timer := 0.0
var slow_time := 0.0
var animation := 0.0
var attack_flash := 0.0
var attack_direction := Vector2.ZERO
var route_from := Vector2i(-1, -1)
var route_variant := 0
var lane_offset := Vector2.ZERO
var emerging := 0.0
var shield_hp := 0.0
var max_shield := 0.0
var since_hit := 0.0
var summon_timer := 6.0
var summoned := false
var combat_id := ""

func setup(config: EnemyData, multiplier: float) -> void:
	data = config
	max_hp = data.health * multiplier
	hp = max_hp
	max_shield = data.shield * multiplier
	shield_hp = max_shield

func waypoint(cell: Vector2i) -> Vector2:
	return Vector2(cell * BattleBoard.CELL) + Vector2(8, 8) + lane_offset

func _draw() -> void:
	draw_set_transform(attack_direction * sin(attack_flash / 0.28 * PI) * 3)
	var s := data.size
	if emerging > 0:
		draw_arc(Vector2.ZERO, 6 + sin(animation * 12) * 2, 0, TAU, 12, Color("ff8c67"), 1)
		draw_line(Vector2(-3, -3), Vector2(3, 3), Color("ffd6a0"))
		draw_line(Vector2(3, -3), Vector2(-3, 3), Color("ffd6a0"))
		return
	var c := data.tint if slow_time <= 0 else Color("8bc9ff")
	if attack_flash > 0: c = c.lightened(0.35)
	var wiggle := sin(animation * 14) * 1.5
	for side in [-1, 1]:
		for offset in [-1, 1]:
			draw_line(Vector2(side * 2, offset * 2), Vector2(side * (s + 2), offset * (s + wiggle)), c.darkened(0.25))
	draw_rect(Rect2(-s, -s, s * 2, s * 2), c.darkened(0.4))
	draw_rect(Rect2(-s + 1, -s + 1, s * 2 - 2, s * 2 - 2), c)
	draw_rect(Rect2(-2, -s, 1, 2), Color("fff3b7"))
	draw_rect(Rect2(1, -s, 1, 2), Color("fff3b7"))
	if data.ability == "burrow":
		draw_line(Vector2(-s, s), Vector2(0, s + 3), Color("e7d9ff"), 2)
	if data.ability == "spitter":
		draw_circle(Vector2.ZERO, 2, Color("b4ff6e"))
	if shield_hp > 0:
		draw_arc(Vector2.ZERO, s + 3, 0, TAU, 12, Color("7bbdff"), 1)
	if data.ability == "boss" and hp < max_hp * 0.5:
		draw_arc(Vector2.ZERO, s + 2, 0, TAU, 12, Color("ff4c54"), 2)
	# Shielded enemies always show both bars, including the empty shield track.
	var bar_width := maxf(12, s * 2)
	if max_shield > 0:
		draw_rect(Rect2(-bar_width / 2, -s - 8, bar_width, 2), Color("233c58"))
		draw_rect(Rect2(-bar_width / 2, -s - 8, bar_width * clampf(shield_hp / max_shield, 0, 1), 2), Color("73caff"))
	if hp < max_hp or max_shield > 0:
		draw_rect(Rect2(-bar_width / 2, -s - 5, bar_width, 2), Color("552c3a"))
		draw_rect(Rect2(-bar_width / 2, -s - 5, bar_width * clampf(hp / max_hp, 0, 1), 2), Color("e5ac79"))
