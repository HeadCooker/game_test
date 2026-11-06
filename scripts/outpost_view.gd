class_name OutpostView
extends Control
## The battle simulation stays in board space. This scene owns only its presentation.
const Art = preload("res://scripts/outpost_models.gd")
const GROUND := preload("res://scripts/outpost_ground.gdshader")
const BATTLE_RECT := Rect2(8, 63, 461, 251)
var game: Node2D
var viewport: SubViewport
var stage: Node3D
var camera: Camera3D
var core_model: Node3D
var actors: Dictionary = {}
var mine_models: Dictionary = {}
var rock_cells: Dictionary
var backdrop := false

func setup(battle: Node2D, rect: Rect2 = BATTLE_RECT) -> void:
	game = battle
	backdrop = battle == null
	position = rect.position
	size = rect.size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE if backdrop else SubViewport.UPDATE_WHEN_VISIBLE
	viewport.msaa_3d = Viewport.MSAA_2X
	add_child(viewport)
	resize_target()
	get_viewport().size_changed.connect(resize_target)
	stage = Node3D.new()
	viewport.add_child(stage)
	build_stage()
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 15.0 if backdrop else 21.2
	camera.far = 120
	stage.add_child(camera)
	var focus := Vector3(2.3, 0, 6.4) if backdrop else Vector3(8, 0, 8)
	var yaw := deg_to_rad(35.0)
	var pitch := deg_to_rad(55.0)
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * 34
	camera.look_at(focus)
	camera.make_current()
	queue_redraw()

func resize_target() -> void:
	var window_scale := get_viewport().get_stretch_transform().get_scale()
	viewport.size = Vector2i(size * window_scale.clamp(Vector2.ONE, Vector2(3, 3)))
	if backdrop: viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func build_stage() -> void:
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	var settings := environment.environment
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("#211921")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("#acc4d5")
	settings.ambient_light_energy = 0.65
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-43, -55, 0)
	sun.light_color = Color("#ffe0b8")
	sun.light_energy = 1.0
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 55
	stage.add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(62, 62)
	ground.mesh = plane
	var soil := ShaderMaterial.new()
	soil.shader = GROUND
	soil.set_shader_parameter("show_grid", not backdrop)
	soil.set_shader_parameter("terrain_size", plane.size.x)
	ground.material_override = soil
	ground.position = Vector3(8, 0, 8)
	stage.add_child(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 261106
	for i in 100:
		var at := Vector3(rng.randf_range(-8, 24), 0.04, rng.randf_range(-7, 25))
		if at.x > -0.6 and at.x < 16.6 and at.z > -0.6 and at.z < 16.6: continue
		var dimensions := Vector3(rng.randf_range(0.6, 4.2), rng.randf_range(0.4, 2.1), rng.randf_range(0.6, 3.2))
		if at.z > 16 or at.x > 16: dimensions.y *= 0.45
		rock(at, dimensions, rng)
	rock_cells = game.board.rocks if not backdrop else {Vector2i(3, 2): true, Vector2i(3, 3): true, Vector2i(3, 4): true, Vector2i(3, 5): true, Vector2i(3, 6): true}
	for cell: Vector2i in rock_cells:
		var point := Vector3(cell.x + 0.5, 0.14, cell.y + 0.5)
		rock(point, Vector3(0.96, rng.randf_range(0.72, 1.04), 1.02), rng)
		rock(point + Vector3(0.25, -0.03, 0.26), Vector3(0.47, 0.34, 0.55), rng)
	for i in 44:
		var at := Vector3(rng.randf_range(0.2, 15.8), 0.014, rng.randf_range(0.2, 15.8))
		var grain := Art.part(stage, "rock", at, Vector3(0.10, 0.035, 0.16), Color("#a86d52"))
		grain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wreckage()
	for side in 2:
		for i in [2, 5, 10, 13]:
			var z := 0.14 if side == 0 else 15.86
			Art.part(stage, "box", Vector3(i + 0.5, 0.026, z), Vector3(0.65, 0.03, 0.075), Art.ORANGE)
	var accent: Color = Color.TRANSPARENT if backdrop else game.board.core_tint
	core_model = Art.building(stage, "core", Vector3(8.5, 0, 8.5), accent)
	if backdrop:
		Art.building(stage, "gun", Vector3(6.5, 0, 7.5))
		Art.building(stage, "miner", Vector3(6.5, 0, 9.5))
		Art.building(stage, "wall", Vector3(5.5, 0, 8.5))

func rock(at: Vector3, dimensions: Vector3, rng: RandomNumberGenerator) -> void:
	var tint := Color("#694137").lerp(Color("#b1795d"), rng.randf())
	var mesh := Art.part(stage, "rock", at, dimensions, tint)
	mesh.rotation = Vector3(0.16, rng.randf_range(0, TAU), 0.18)

func wreckage() -> void:
	var wreck := Node3D.new()
	stage.add_child(wreck)
	wreck.position = Vector3(-2.1, 0.27, 6.6)
	wreck.rotation = Vector3(-0.10, -0.38, -0.15)
	Art.part(wreck, "box", Vector3.ZERO, Vector3(2.2, 0.55, 4.7), Art.DARK)
	Art.part(wreck, "taper", Vector3(0, 0.41, -0.82), Vector3(2.8, 0.75, 2.8), Art.METAL)
	Art.part(wreck, "box", Vector3(0, 0.79, -1.05), Vector3(1.38, 0.23, 1.38), Color("#4a8490"))
	for x in [-1.03, 1.03]:
		Art.part(wreck, "box", Vector3(x, 0.37, 0.76), Vector3(0.36, 0.40, 2.7), Art.METAL)
		Art.part(wreck, "box", Vector3(x, 0.59, 0.65), Vector3(0.37, 0.05, 0.47), Art.ORANGE)
		for z in [0.1, 0.45, 0.8, 1.15, 1.5]:
			Art.part(wreck, "box", Vector3(x * 0.65, 0.31, z), Vector3(0.24, 0.25, 0.09), Art.DARK)
		Art.part(wreck, "round", Vector3(x, 0.08, 2.06), Vector3(0.68, 0.37, 0.68), Art.DARK).rotation.x = PI / 2
	for i in 3:
		var crate := Art.part(stage, "box", Vector3(-0.64 - 0.50 * i, 0.19, 10.4 + 0.43 * i), Vector3(0.46, 0.48, 0.51), Art.ORANGE)
		crate.rotation.y = i * 0.38
	for z in [4.5, 8.9, 12.0]:
		Art.part(stage, "box", Vector3(-0.49, 0.43, z), Vector3(0.08, 1.05, 0.08), Art.DARK)
		Art.part(stage, "box", Vector3(-0.49, 0.99, z), Vector3(0.23, 0.17, 0.20), Art.AMBER, true)

func board_world(point: Vector2, height := 0.025) -> Vector3:
	return Vector3(point.x / BattleBoard.CELL, height, point.y / BattleBoard.CELL)

func screen_point(point: Vector2, height := 0.025) -> Vector2:
	return camera.unproject_position(board_world(point, height)) * size / Vector2(viewport.size)

func cell_at_screen(point: Vector2) -> Vector2i:
	var local := get_global_transform_with_canvas().affine_inverse() * point
	if not Rect2(Vector2.ZERO, size).has_point(local): return Vector2i(-1, -1)
	var pixel := local * Vector2(viewport.size) / size
	var ground: Variant = Plane(Vector3.UP, 0).intersects_ray(camera.project_ray_origin(pixel), camera.project_ray_normal(pixel))
	if ground == null: return Vector2i(-1, -1)
	return game.board.cell_at(Vector2(ground.x, ground.z) * BattleBoard.CELL)

func selectable_cell_at(point: Vector2) -> Vector2i:
	var cell := cell_at_screen(point)
	if game.board.buildings.has(cell): return cell
	var local := get_global_transform_with_canvas().affine_inverse() * point
	if not Rect2(Vector2.ZERO, size).has_point(local): return cell
	var best := 5.0
	for tower: DefenseTower in game.board.buildings.values():
		var height := 0.55
		if actors.has(tower.get_instance_id()):
			height = float(actors[tower.get_instance_id()].get_meta("marker_height", 0.75)) * 0.73
		var distance := local.distance_to(screen_point(tower.position, height))
		if distance < best:
			best = distance
			cell = tower.cell
	return cell

func _process(_delta: float) -> void:
	if backdrop: return
	sync_models()
	queue_redraw()

func sync_models() -> void:
	var live := {}
	for tower: DefenseTower in game.board.buildings.values():
		var id := tower.get_instance_id()
		live[id] = true
		if not actors.has(id): actors[id] = Art.building(stage, tower.data.key, board_world(tower.position, 0), tower.cosmetic_tint)
		var model: Node3D = actors[id]
		model.scale.y = 1 + (tower.level - 1) * 0.08
		if model.has_meta("head"):
			var head: Node3D = model.get_meta("head")
			head.rotation.y = atan2(-tower.aim.x, -tower.aim.y)
			head.position.z = -tower.aim.y * tower.flash * 0.9
			head.position.x = -tower.aim.x * tower.flash * 0.9
		if model.has_meta("drill"):
			var drill: Node3D = model.get_meta("drill")
			drill.position.y = 0.49 + sin(tower.mining_timer * 7) * 0.12
			drill.rotation.y = tower.mining_timer * 12
			var beacon: MeshInstance3D = model.get_meta("beacon")
			beacon.visible = tower.stored_alloy > 0
			if beacon.visible:
				var lens := beacon.material_override as StandardMaterial3D
				lens.emission_energy_multiplier = 0.3 + beacon_pulse() * 2.1
	for bug: AlienBug in game.enemies:
		if bug.hp <= 0: continue
		var id := bug.get_instance_id()
		live[id] = true
		if not actors.has(id): actors[id] = Art.creature(stage, bug)
		var model: Node3D = actors[id]
		model.visible = bug.emerging <= 0
		var lunge := bug.attack_direction * sin(bug.attack_flash / 0.28 * PI) * 4
		model.position = board_world(bug.position + lunge, 0)
		var heading := bug.waypoint(bug.destination) - bug.position
		if bug.attack_flash > 0: heading = bug.attack_direction
		if heading.length_squared() > 0.01: model.rotation.y = atan2(-heading.x, -heading.y)
		var legs: Array = model.get_meta("legs")
		for i in legs.size():
			legs[i].rotation.y = sin(bug.animation * 17 + i * 2.1) * 0.35
		var body: Node3D = model.get_meta("body")
		body.position.y = sin(bug.animation * 15) * 0.025
	for id in actors.keys():
		if not live.has(id):
			actors[id].queue_free()
			actors.erase(id)
	var current_mines := {}
	for mine in game.mines:
		var cell := Vector2i(int(mine.x), int(mine.y))
		current_mines[cell] = true
		if not mine_models.has(cell):
			var point := board_world(game.board.center(cell), 0.08)
			mine_models[cell] = Art.part(stage, "round", point, Vector3(0.43, 0.16, 0.43), Art.AMBER, true)
	for cell in mine_models.keys():
		if not current_mines.has(cell):
			mine_models[cell].queue_free()
			mine_models.erase(cell)

func _draw() -> void:
	if viewport == null: return
	draw_texture_rect(viewport.get_texture(), Rect2(Vector2.ZERO, size), false)
	if backdrop or game.overlay == null or game.overlay.visible: return
	var board: BattleBoard = game.board
	for side in board.approach_sides:
		var entries := [Vector2(128, 1), Vector2(255, 128), Vector2(128, 255), Vector2(1, 128)]
		var edge: Vector2 = entries[side]
		var tip := screen_point(edge.lerp(Vector2(128, 128), 0.05))
		var back := screen_point(edge.lerp(Vector2(128, 128), -0.04))
		var perpendicular := (tip - back).normalized().orthogonal() * 4
		draw_colored_polygon(PackedVector2Array([tip, back + perpendicular, back - perpendicular]), Color("#ff9760"))
	if board.inside(board.selected):
		draw_tile(board.selected, Color("#67e7dd"), 0.09)
		if board.selected_radius > 0: ring(board.center(board.selected), board.selected_radius, Color("#70f0d5"), 0.07)
	if board.inside(board.hover) and (game.selected_type >= 0 or not game.action_mode.is_empty()):
		var boundary := Color(0.96, 0.37, 0.20, 0.10)
		for region in [Rect2(0, 0, 256, 16), Rect2(0, 240, 256, 16), Rect2(0, 16, 16, 224), Rect2(240, 16, 16, 224)]:
			draw_ground_rect(region, boundary)
		for cell in board.forbidden: draw_ground_rect(Rect2(Vector2(cell * BattleBoard.CELL), Vector2.ONE * BattleBoard.CELL), boundary)
	if board.inside(board.hover):
		var color := Color("#7be6d6")
		if board.preview_color.a > 0: color = Color("#7be6d6") if board.preview_color.g > 0.5 else Color("#ff7b62")
		if game.action_mode == "mine":
			color = Color("#ffd178") if game.mine_available(board.hover) else Color("#ff7b62")
			ring(board.center(board.hover), 30, color, 0.04)
		elif game.action_mode == "strike":
			color = Color("#ffd178") if game.phase == game.Phase.ATTACK and not game.paused and game.strike_cooldown <= 0 else Color("#ff7b62")
			ring(board.center(board.hover), 42, color, 0.06)
		elif board.preview_radius > 0:
			ring(board.center(board.hover), board.preview_radius, color, 0.04)
		draw_tile(board.hover, color, 0.16)
	draw_combat()
	for tower: DefenseTower in board.buildings.values():
		var p := screen_point(tower.position, 1.10)
		if actors.has(tower.get_instance_id()):
			var model: Node3D = actors[tower.get_instance_id()]
			var top: float = model.get_meta("marker_height", 0.95)
			p = screen_point(tower.position, top * model.scale.y + 0.08)
		if tower.data.key == "miner" and tower.stored_alloy > 0:
			var pulse := beacon_pulse()
			draw_circle(p, 5 + pulse * 2, Color(1.0, 0.59, 0.14, 0.12 + pulse * 0.3), true, -1, true)
			draw_circle(p, 2.7, Color("#ffb23e").lerp(Color("#fff3a9"), pulse), true, -1, true)
			if pulse > 0.58:
				draw_arc(p, 6 + pulse * 2, 0, TAU, 24, Color(1, 0.72, 0.28, pulse * 0.72), 1, true)
		if tower.hp < tower.max_health(): bar(p + Vector2(0, -5), 13, tower.hp / tower.max_health(), Color("#70e8b2"))
		if tower.hit_flash > 0: hit_glint(p + Vector2(0, 4), Color("#ffba84"), tower.hit_flash * 4)
	for bug: AlienBug in game.enemies:
		if bug.hp <= 0: continue
		if bug.emerging > 0:
			ring(bug.position, 9 + sin(bug.animation * 15) * 3, Color("#ffc875"), 0.20)
			continue
		var p := screen_point(bug.position, 0.65)
		draw_circle(p + Vector2(0, 3), 1.2, Color("#eac391"))
		if bug.hp < bug.max_hp or bug.max_shield > 0: bar(p, 11, bug.hp / bug.max_hp, Color("#ffa780"))
		if bug.max_shield > 0: bar(p - Vector2(0, 3), 11, bug.shield_hp / bug.max_shield, Color("#70caff"))
	if board.hit_flash > 0:
		hit_glint(screen_point(board.center(BattleBoard.CORE), 0.9), Color("#ff9369"), board.hit_flash * 4)

func beacon_pulse() -> float:
	return 0.5 + 0.5 * cos(Time.get_ticks_msec() * TAU / 950.0)

func draw_ground_rect(bounds: Rect2, color: Color) -> void:
	var corners := PackedVector2Array()
	for point in [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]:
		corners.append(screen_point(point))
	draw_colored_polygon(corners, color)

func draw_tile(cell: Vector2i, color: Color, fill: float) -> void:
	var top := Vector2(cell * BattleBoard.CELL)
	var corners := PackedVector2Array()
	for step in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
		corners.append(screen_point(top + step * BattleBoard.CELL))
	draw_colored_polygon(corners, Color(color, fill))
	corners.append(corners[0])
	draw_polyline(corners, color, 0.8, true)

func ring(center: Vector2, radius: float, color: Color, fill: float) -> void:
	var points := PackedVector2Array()
	for i in 40:
		points.append(screen_point(center + Vector2.from_angle(TAU * i / 40.0) * radius))
	if fill > 0: draw_colored_polygon(points, Color(color, fill))
	points.append(points[0])
	draw_polyline(points, color, 0.8, true)

func bar(center: Vector2, width: float, ratio: float, color: Color) -> void:
	var start := center - Vector2(width / 2, 0)
	draw_rect(Rect2(start - Vector2.ONE, Vector2(width + 2, 3)), Color("#211d27"))
	draw_rect(Rect2(start, Vector2(width * clampf(ratio, 0, 1), 1.3)), color)

func hit_glint(point: Vector2, color: Color, alpha: float) -> void:
	var tint := Color(color, clampf(alpha, 0, 1))
	draw_line(point - Vector2(4, 0), point + Vector2(4, 0), tint, 1.2, true)
	draw_line(point - Vector2(0, 3), point + Vector2(0, 3), tint, 1.2, true)

func draw_combat() -> void:
	var particles := 0
	for fx in game.effects:
		var point: Vector2 = fx.to
		var color: Color = fx.color
		match fx.kind:
			"shot":
				var from: Vector2 = fx.from
				var muzzle := from.move_toward(point, 7)
				var start := screen_point(muzzle, 0.56)
				var turret: DefenseTower = game.board.buildings.get(game.board.cell_at(from))
				if turret != null and turret.position.is_equal_approx(from):
					var model: Node3D = actors.get(turret.get_instance_id())
					if model != null and model.has_meta("muzzle"):
						var marker: Node3D = model.get_meta("muzzle")
						start = camera.unproject_position(marker.global_position) * size / Vector2(viewport.size)
				var impact := screen_point(point, 0.32)
				draw_line(start, impact, Color(color, 0.62), 1.4, true)
				draw_line(start, impact, Color("#fff1be"), 0.65, true)
				hit_glint(start, Color("#fff1be"), fx.life * 10)
				hit_glint(impact, color, fx.life * 10)
			"acid", "claw":
				var progress := clampf(1 - fx.life / 0.32, 0, 1)
				var impact := screen_point(point, 0.38)
				if fx.kind == "acid":
					var from: Vector2 = fx.from
					var drop := screen_point(from.lerp(point, progress), 0.34 + sin(progress * PI) * 0.42)
					draw_circle(drop, 2.4, Color("#bcf773"))
					draw_line(drop, drop.lerp(screen_point(from, 0.35), 0.25), Color("#73ca53"), 1.5, true)
				else:
					for offset in [-2, 1, 4]:
						draw_line(impact + Vector2(offset - 3, 3), impact + Vector2(offset + 1, -4), Color(color, 1 - progress), 1.4, true)
			"blast", "shield_break", "death":
				var progress := clampf(1 - fx.life / (0.26 if fx.kind == "blast" else 0.30), 0, 1)
				var radius: float = fx.get("radius", 28 if fx.kind == "blast" else 9)
				ring(point, radius * maxf(0.16, progress), Color(color, 1 - progress), 0.09 * (1 - progress))
				var impact := screen_point(point, 0.34)
				hit_glint(impact, Color("#fff0d2"), 1 - progress)
				if particles < 72:
					for i in 5:
						var dir := Vector2.from_angle(i * TAU / 5 + 0.4)
						draw_circle(impact + dir * progress * (6 + radius * 0.31) - Vector2(0, sin(progress * PI) * 5), 1.5 - progress, Color(color, 1 - progress))
					particles += 5
