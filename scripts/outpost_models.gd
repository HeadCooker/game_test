class_name OutpostModels
extends RefCounted
## Shared materials and low-poly meshes for the Raven's salvage equipment.
const METAL := Color("#a9bac1")
const DARK := Color("#263741")
const ORANGE := Color("#ed8a3f")
const TEAL := Color("#59e5de")
const AMBER := Color("#ffd178")
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func part(parent: Node3D, shape: String, at: Vector3, dimensions: Vector3, color: Color, glow := false) -> MeshInstance3D:
	if not meshes.has(shape):
		match shape:
			"round":
				var mesh := CylinderMesh.new()
				mesh.radial_segments = 8
				mesh.rings = 0
				mesh.top_radius = 0.5
				mesh.bottom_radius = 0.5
				mesh.height = 1
				meshes[shape] = mesh
			"shell", "rock":
				var mesh := SphereMesh.new()
				mesh.radius = 0.5
				mesh.height = 1
				mesh.radial_segments = 8 if shape == "shell" else 5
				mesh.rings = 3 if shape == "shell" else 2
				meshes[shape] = mesh
			"taper":
				var mesh := CylinderMesh.new()
				mesh.radial_segments = 6
				mesh.rings = 0
				mesh.top_radius = 0.34
				mesh.bottom_radius = 0.5
				mesh.height = 1
				meshes[shape] = mesh
			_: meshes[shape] = BoxMesh.new()
	var key := color.to_html() + str(glow)
	if not materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.78
		if glow:
			material.emission_enabled = true
			material.emission = color
			material.emission_energy_multiplier = 0.65
		materials[key] = material
	var instance := MeshInstance3D.new()
	instance.mesh = meshes[shape]
	instance.material_override = materials[key]
	instance.position = at
	instance.scale = dimensions
	parent.add_child(instance)
	return instance

static func building(parent: Node3D, key: String, at: Vector3, accent := Color.TRANSPARENT) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = at
	var trim := ORANGE if accent.a == 0 else accent
	part(root, "round", Vector3(0, 0.065, 0), Vector3(0.94, 0.13, 0.94), DARK)
	part(root, "round", Vector3(0, 0.145, 0), Vector3(0.83, 0.07, 0.83), METAL)
	for x in [-0.32, 0.32]:
		part(root, "box", Vector3(x, 0.2, 0.23), Vector3(0.13, 0.09, 0.15), trim)
	match key:
		"core":
			part(root, "taper", Vector3(0, 0.33, 0), Vector3(0.84, 0.35, 0.84), DARK)
			var signal_color := TEAL if accent.a == 0 else accent
			part(root, "taper", Vector3(0, 0.83, 0), Vector3(0.44, 0.74, 0.44), signal_color, true)
			part(root, "round", Vector3(0, 1.18, 0), Vector3(0.53, 0.14, 0.53), METAL)
			for side in [-1, 1]:
				part(root, "box", Vector3(side * 0.31, 0.6, 0), Vector3(0.14, 0.9, 0.27), METAL)
				part(root, "box", Vector3(side * 0.32, 0.62, 0.144), Vector3(0.10, 0.24, 0.02), signal_color, true)
			part(root, "round", Vector3(0, 1.38, 0), Vector3(0.046, 0.32, 0.046), METAL)
			part(root, "shell", Vector3(0, 1.56, 0), Vector3(0.10, 0.10, 0.10), signal_color, true)
		"wall":
			part(root, "box", Vector3(0, 0.34, 0), Vector3(0.91, 0.45, 0.66), DARK)
			part(root, "box", Vector3(0, 0.45, 0.18), Vector3(0.86, 0.38, 0.35), METAL)
			for x in [-0.26, 0.0, 0.26]:
				var stripe := part(root, "box", Vector3(x, 0.49, 0.364), Vector3(0.09, 0.25, 0.014), trim)
				stripe.rotation.z = -0.35
		"miner":
			part(root, "box", Vector3(-0.23, 0.39, 0.08), Vector3(0.35, 0.42, 0.61), trim)
			for x in [-0.35, 0.35]:
				part(root, "box", Vector3(x, 0.57, -0.22), Vector3(0.11, 0.84, 0.12), DARK)
			part(root, "box", Vector3(0, 0.94, -0.22), Vector3(0.76, 0.15, 0.23), METAL)
			var drill := part(root, "taper", Vector3(0.15, 0.49, 0.12), Vector3(0.33, 0.54, 0.33), METAL)
			drill.rotation.x = PI
			root.set_meta("drill", drill)
			part(root, "box", Vector3(-0.23, 0.63, 0.08), Vector3(0.24, 0.09, 0.37), DARK)
			part(root, "round", Vector3(0, 1.07, 0), Vector3(0.26, 0.14, 0.26), DARK)
			var beacon := part(root, "round", Vector3(0, 1.19, 0), Vector3(0.21, 0.14, 0.21), AMBER, true)
			beacon.material_override = beacon.material_override.duplicate()
			beacon.hide()
			root.set_meta("beacon", beacon)
			root.set_meta("marker_height", 1.19)
		"gun":
			# A squat pillbox with side shields and a twin gun cradle.
			var head := weapon_pivot(root, 0.36, 0.77)
			part(head, "box", Vector3(0, 0.05, 0.08), Vector3(0.66, 0.34, 0.61), DARK)
			part(head, "box", Vector3(0, 0.24, 0.12), Vector3(0.57, 0.12, 0.43), METAL)
			for side in [-1, 1]:
				part(head, "box", Vector3(side * 0.32, 0.08, -0.07), Vector3(0.12, 0.36, 0.57), trim)
				barrel(head, Vector3(side * 0.10, 0.1, -0.11), 0.52, 0.11)
			for x in [-0.16, 0.0, 0.16]:
				part(head, "box", Vector3(x, 0.31, 0.18), Vector3(0.07, 0.025, 0.17), DARK)
			muzzle(root, head, Vector3(0, 0.10, -0.63))
		"cannon":
			# Broad armored carriage and a large bore above hydraulic recoil guides.
			part(root, "box", Vector3(0, 0.22, 0.05), Vector3(0.83, 0.19, 0.79), DARK)
			var head := weapon_pivot(root, 0.43, 0.91)
			part(head, "taper", Vector3(0, 0.01, 0.11), Vector3(0.83, 0.53, 0.78), METAL)
			part(head, "box", Vector3(0, 0.26, 0.18), Vector3(0.55, 0.10, 0.44), trim)
			for side in [-1, 1]:
				barrel(head, Vector3(side * 0.24, 0, 0.14), 0.54, 0.095)
			barrel(head, Vector3(0, 0.045, -0.13), 0.58, 0.30)
			muzzle(root, head, Vector3(0, 0.045, -0.71))
		"sniper":
			# An open observation mast supports a long, narrow rail assembly.
			for x in [-0.24, 0.24]:
				for z in [-0.23, 0.23]:
					var strut := part(root, "box", Vector3(x, 0.63, z), Vector3(0.085, 0.90, 0.085), DARK)
					strut.rotation.z = x * 0.47
			part(root, "box", Vector3(0, 1.02, 0), Vector3(0.63, 0.13, 0.63), METAL)
			var head := weapon_pivot(root, 1.15, 1.52)
			part(head, "box", Vector3(0, 0.07, 0.14), Vector3(0.35, 0.24, 0.53), trim)
			for x in [-0.075, 0.075]:
				part(head, "box", Vector3(x, 0.09, -0.47), Vector3(0.09, 0.09, 0.96), DARK)
			part(head, "box", Vector3(0, 0.235, 0.09), Vector3(0.20, 0.10, 0.20), TEAL, true)
			muzzle(root, head, Vector3(0, 0.09, -0.95))
		"tesla":
			# A freestanding insulator stack with split electrodes instead of a barrel.
			part(root, "taper", Vector3(0, 0.36, 0), Vector3(0.74, 0.42, 0.74), trim)
			part(root, "round", Vector3(0, 0.81, 0), Vector3(0.25, 0.91, 0.25), DARK)
			for height in [0.59, 0.79, 0.99, 1.17]:
				part(root, "round", Vector3(0, height, 0), Vector3(0.49, 0.073, 0.49), METAL)
			part(root, "box", Vector3(0, 1.27, 0), Vector3(0.62, 0.105, 0.15), DARK)
			for side in [-1, 1]:
				part(root, "shell", Vector3(side * 0.24, 1.42, 0), Vector3(0.25, 0.31, 0.25), TEAL, true)
			root.set_meta("marker_height", 1.59)
			muzzle(root, root, Vector3(0, 1.42, 0))
		"slow":
			# Low radial radiators surround the chilled central emitter.
			var ice := Color("#85bcff")
			part(root, "round", Vector3(0, 0.38, 0), Vector3(0.76, 0.38, 0.76), DARK)
			for i in 4:
				var angle := i * TAU / 4
				var fin := part(root, "box", Vector3(sin(angle) * 0.31, 0.44, cos(angle) * 0.31), Vector3(0.23, 0.44, 0.09), METAL)
				fin.rotation = Vector3(0.37, angle, 0)
			part(root, "round", Vector3(0, 0.58, 0), Vector3(0.43, 0.11, 0.43), trim)
			part(root, "shell", Vector3(0, 0.65, 0), Vector3(0.36, 0.31, 0.36), ice, true)
			root.set_meta("marker_height", 0.84)
			muzzle(root, root, Vector3(0, 0.7, 0))
	return root

static func weapon_pivot(root: Node3D, height: float, marker_height: float) -> Node3D:
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.position.y = height
	root.set_meta("head", pivot)
	root.set_meta("marker_height", marker_height)
	return pivot

static func barrel(parent: Node3D, origin: Vector3, length: float, bore: float) -> void:
	var tube := part(parent, "round", origin + Vector3(0, 0, -length * 0.5), Vector3(bore, length, bore), DARK)
	tube.rotation.x = PI / 2
	var collar := part(parent, "round", origin + Vector3(0, 0, -length * 0.9), Vector3(bore * 1.26, 0.09, bore * 1.26), METAL)
	collar.rotation.x = PI / 2
	var opening := part(parent, "round", origin + Vector3(0, 0, -length - 0.008), Vector3(bore * 0.72, 0.018, bore * 0.72), Color("#121820"))
	opening.rotation.x = PI / 2

static func muzzle(root: Node3D, parent: Node3D, at: Vector3) -> void:
	var origin := Node3D.new()
	parent.add_child(origin)
	origin.position = at
	root.set_meta("muzzle", origin)

static func creature(parent: Node3D, bug: AlienBug) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var body := Node3D.new()
	root.add_child(body)
	root.set_meta("body", body)
	var color := bug.data.tint.darkened(0.22)
	var width := clampf(bug.data.size / 9.0, 0.32, 0.95)
	var length := width * (1.65 if bug.data.speed >= 20 else 1.33)
	if bug.summoned:
		width *= 0.64
		length *= 0.64
	part(body, "shell", Vector3(0, 0.27, 0.10), Vector3(width, 0.48, length), color)
	part(body, "shell", Vector3(0, 0.24, -length * 0.39), Vector3(width * 0.7, 0.33, width * 0.7), color.darkened(0.38))
	for z in [-0.10, 0.12, 0.32]:
		part(body, "shell", Vector3(0, 0.34, z * length), Vector3(width * 0.91, 0.28, length * 0.39), color.lightened(0.17))
	var legs: Array[Node3D] = []
	for side in [-1, 1]:
		for index in 3:
			var leg := part(body, "box", Vector3(side * width * 0.53, 0.14, (index - 1) * length * 0.29), Vector3(width * 0.60, 0.065, 0.09), color.darkened(0.5))
			leg.rotation.z = side * -0.32
			legs.append(leg)
		part(body, "shell", Vector3(side * width * 0.17, 0.29, -length * 0.61), Vector3(0.07, 0.07, 0.07), AMBER, true)
	root.set_meta("legs", legs)
	if bug.data.ability == "split":
		part(body, "shell", Vector3(0, 0.4, 0.21), Vector3(width * 0.85, 0.49, length * 0.71), Color("#d6b047"), true)
	elif bug.data.ability == "spitter":
		part(body, "shell", Vector3(0, 0.43, 0.15), Vector3(width * 0.78, 0.3, length * 0.65), Color("#94ca47"), true)
	return root
