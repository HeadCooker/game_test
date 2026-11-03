extends Control
signal mission_selected(index: int)
const POINTS := [Vector2(42, 61), Vector2(145, 29), Vector2(245, 65), Vector2(345, 25), Vector2(445, 59), Vector2(552, 24)]

func _ready() -> void:
	custom_minimum_size = Vector2(0, 100)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in POINTS.size():
			if event.position.distance_to(POINTS[i]) < 18 and Campaign.unlocked(i + 1):
				mission_selected.emit(i + 1)
				accept_event()
				return

func _draw() -> void:
	draw_rect(Rect2(0, 0, size.x, 96), Color("0d1c28"))
	for i in range(1, POINTS.size()):
		draw_line(POINTS[i - 1], POINTS[i], Color("3a626b"), 1)
	for i in POINTS.size():
		var complete: bool = Campaign.profile.records.has(str(i + 1))
		var color := Color("83e5ce") if complete else (Color("e6ba77") if Campaign.unlocked(i + 1) else Color("485566"))
		draw_arc(POINTS[i], 12, 0, TAU, 20, color)
		draw_circle(POINTS[i], 4, color)
		draw_string(get_theme_default_font(), POINTS[i] + Vector2(-13, 27), "%02d" % (i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, color)
