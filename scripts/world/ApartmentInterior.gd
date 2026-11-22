extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const Sites = preload("res://scripts/world/ApartmentSites.gd")
const FLOOR_HEIGHT := 2.88
const RUN := 2.62
const UPPER_LANDING := 1.10
const TURN := UPPER_LANDING - RUN
const PLASTER := Color("#c7beb0")
const PAINT := Color("#687773")
const FLOOR := Color("#a29a89")
const STEEL := Color("#4b5754")
const WOOD := Color("#6f5947")

var _geo := Geometry.new()
var _doors: Array[AnimatableBody3D] = []


func build(resident: String, accent: Color) -> void:
	_floor(0, 0.51, 3.9, 7.5)
	_floor(FLOOR_HEIGHT * 0.5, TURN - 0.85, 3.9, 1.7)
	_floor(FLOOR_HEIGHT, 2.65, 3.9, 3.1)
	_stairs(-0.94, UPPER_LANDING, TURN, 0)
	_stairs(0.94, TURN, UPPER_LANDING, FLOOR_HEIGHT * 0.5)
	_panel(Vector3(-1.94, 2.73, 0.50), Vector3(0.17, 5.46, 7.48), PLASTER)
	_panel(Vector3(1.94, 1.44, 0.50), Vector3(0.17, 2.88, 7.48), PAINT)
	_panel(Vector3(1.94, 4.17, -0.88), Vector3(0.17, 2.58, 4.72), PLASTER)
	_panel(Vector3(1.94, 4.17, 3.59), Vector3(0.17, 2.58, 1.30), PLASTER)
	_panel(Vector3(1.94, 5.24, 2.20), Vector3(0.17, 0.44, 1.48), PLASTER)
	_panel(Vector3(0, 2.73, -3.24), Vector3(3.9, 5.46, 0.19), PLASTER)
	_panel(Vector3(0, 5.51, 0.55), Vector3(3.90, 0.18, 7.6), PLASTER)
	var threshold := Sites.THRESHOLD_Z
	for side: float in [-1.0, 1.0]:
		_panel(Vector3(side * 1.39, 1.38, threshold - 0.07), Vector3(1.21, 2.76, 0.12), PAINT)
	_panel(Vector3(0, 3.855, threshold - 0.07), Vector3(3.9, 3.25, 0.12), PLASTER)
	for side: float in [-1.0, 1.0]:
		_geo.box(self, Vector3(side * 0.765, 1.11, threshold + 0.015), Vector3(0.078, 2.22, 0.22), STEEL)
	_geo.box(self, Vector3(0, 2.22, threshold + 0.015), Vector3(1.59, 0.085, 0.22), STEEL)
	_make_door("EntryDoor", Vector3(-0.727, 0, threshold + 0.015), 0.0, 1.44, 2.14, accent.darkened(0.30), "BUILDING DOOR")
	_geo.box(_doors[0], Vector3(0.72, 1.59, 0.051), Vector3(0.82, 0.47, 0.027), Color("#607d80"))
	_geo.box(self, Vector3(0, 2.49, threshold + 0.40), Vector3(2.22, 0.115, 0.98), STEEL)
	_geo.signage(self, Vector3(0, 2.37, threshold + 0.03), "LAIPTINĖ", 12, Color("#eee7d8"))
	_geo.signage(self, Vector3(0, 2.25, threshold - 0.16), "IŠĖJIMAS", 17, Color("#d6f5dc"), PI)
	var sill := _panel(Vector3(0, -0.12, threshold + 0.36), Vector3(1.46, 0.10, 0.88), FLOOR)
	sill.rotation.x = 0.195
	var up := _geo.signage(self, Vector3(-1.845, 1.84, 1.88), "↑  BUTAI", 15, Color("#e9e2d2"), PI * 0.5)
	up.outline_size = 2
	_geo.box(self, Vector3(-1.75, 1.32, 3.49), Vector3(0.18, 0.48, 0.87), STEEL)
	for index in 4:
		_geo.box(self, Vector3(-1.648, 1.35, 3.19 + index * 0.19), Vector3(0.012, 0.027, 0.10), Color("#292f32"))
	_geo.box(self, Vector3(0, 3.21, -3.126), Vector3(2.08, 1.72, 0.044), Color("#586966"))
	for column in 2:
		_geo.box(self, Vector3(-0.49 + column * 0.98, 3.21, -3.098), Vector3(0.92, 1.56, 0.025), Color("#bacdd2"))
	_light(Vector3(0, 2.48, 3.28), 1.12, 5.4)
	_light(Vector3(0, 4.61, -2.57), 1.48, 6.6)
	_light(Vector3(0, 5.14, 2.45), 1.25, 4.9)
	_apartment(resident, accent)
	_geo.batch_static(self)


func _floor(y: float, z: float, width: float, depth: float) -> void:
	_panel(Vector3(0, y - 0.11, z), Vector3(width, 0.22, depth), FLOOR)


func _panel(at: Vector3, dimensions: Vector3, tint: Color) -> MeshInstance3D:
	return _geo.box(self, at, dimensions, tint, true)


func _stairs(x: float, from_z: float, to_z: float, bottom: float) -> void:
	const STEP_COUNT := 8
	var rise := FLOOR_HEIGHT * 0.5
	var tread := RUN / STEP_COUNT
	var increment := rise / STEP_COUNT
	for step_index in STEP_COUNT:
		var ratio := (step_index + 0.5) / STEP_COUNT
		var at := Vector3(x, bottom + (step_index + 0.5) * increment, lerpf(from_z, to_z, ratio))
		_geo.box(self, at, Vector3(1.70, increment, tread + 0.035), FLOOR)
		_geo.box(self, at + Vector3(0, increment * 0.46, -signf(to_z - from_z) * tread * 0.42),
			Vector3(1.70, 0.026, 0.042), STEEL)
	var angle := atan2(-rise, to_z - from_z)
	if angle < -PI * 0.5:
		angle += PI
	var ramp := StaticBody3D.new()
	ramp.position = Vector3(x, bottom + rise * 0.5 - 0.006, (from_z + to_z) * 0.5)
	ramp.rotation.x = angle
	add_child(ramp)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.76, 0.16, Vector2(RUN, rise).length() + 0.035)
	var collision := CollisionShape3D.new()
	collision.position.y = -0.08
	collision.shape = shape
	ramp.add_child(collision)
	var rail_x := signf(x) * 0.11
	var rail := _panel(Vector3(rail_x, bottom + rise * 0.5 + 0.86, (from_z + to_z) * 0.5),
		Vector3(0.085, 0.065, shape.size.z), STEEL)
	rail.rotation.x = angle
	for index in 7:
		var ratio := (index + 0.5) / 7.0
		_geo.box(self, Vector3(rail_x, bottom + rise * ratio + 0.44, lerpf(from_z, to_z, ratio)),
			Vector3(0.09, 0.88, 0.055), STEEL)


func _apartment(resident: String, accent: Color) -> void:
	var y := FLOOR_HEIGHT
	var parquet := Color("#a38969")
	for offset: float in [-0.11, 2.54]:
		_panel(Vector3(5.27, y + offset, -1.02), Vector3(6.72, 0.22, 4.30), parquet if offset < 0.0 else PLASTER)
		_panel(Vector3(2.92, y + offset, 2.24), Vector3(2.02, 0.22, 2.22), parquet if offset < 0.0 else PLASTER)
	_panel(Vector3(5.27, y + 1.22, -3.2), Vector3(6.72, 2.44, 0.16), PLASTER)
	_panel(Vector3(8.60, y + 1.22, -1.06), Vector3(0.16, 2.44, 4.45), accent.darkened(0.09))
	_panel(Vector3(6.21, y + 1.22, 1.16), Vector3(4.78, 2.44, 0.16), PLASTER)
	_panel(Vector3(3.91, y + 1.22, 2.24), Vector3(0.16, 2.44, 2.32), PLASTER)
	_panel(Vector3(2.91, y + 1.22, 3.36), Vector3(2.0, 2.44, 0.16), PLASTER)
	_make_door("ApartmentDoor", Vector3(1.94, y, 1.49), -PI * 0.5, 1.42, 2.08, WOOD, "APARTMENT DOOR")
	_geo.signage(self, Vector3(1.838, y + 2.26, 2.2), resident, 16, Color("#333638"), -PI * 0.5)
	_geo.box(self, Vector3(2.90, y + 0.01, 2.20), Vector3(1.76, 0.018, 1.27), accent.darkened(0.34))
	for board in 12:
		_geo.box(self, Vector3(2.08 + board * 0.55, y + 0.002, -1.05),
			Vector3(0.017, 0.004, 4.22), Color("#806a50"))
	_panel(Vector3(4.55, y + 0.45, -2.68), Vector3(2.73, 0.90, 0.88), Color("#b1a993"))
	_panel(Vector3(4.55, y + 0.92, -2.68), Vector3(2.78, 0.08, 0.91), STEEL)
	for cupboard in 4:
		_geo.box(self, Vector3(3.56 + cupboard * 0.66, y + 0.48, -2.222),
			Vector3(0.62, 0.65, 0.035), Color("#bfb69c"))
		_geo.box(self, Vector3(3.56 + cupboard * 0.66, y + 0.74, -2.195),
			Vector3(0.18, 0.025, 0.045), STEEL)
	_geo.box(self, Vector3(3.72, y + 0.975, -2.64), Vector3(0.62, 0.018, 0.49), Color("#282c2d"))
	_geo.taper(self, Vector3(5.45, y + 1.014, -2.77), 0.1, 0.13, 0.11, Color("#a18b71"), 16)
	_panel(Vector3(7.40, y + 0.28, -2.53), Vector3(1.90, 0.55, 0.91), accent)
	_panel(Vector3(7.40, y + 0.66, -2.89), Vector3(1.90, 0.54, 0.23), accent.darkened(0.22))
	_geo.box(self, Vector3(7.46, y + 0.012, -0.89), Vector3(1.95, 0.022, 1.52), accent.darkened(0.31))
	_panel(Vector3(7.46, y + 0.26, -0.85), Vector3(1.31, 0.51, 0.55), WOOD)
	_geo.box(self, Vector3(7.41, y + 0.54, -0.85), Vector3(0.29, 0.04, 0.23), Color("#c9ac8b"))
	_light(Vector3(2.95, y + 2.28, 2.42), 1.05, 4.4)
	_light(Vector3(4.35, y + 2.29, -0.56), 1.44, 5.1)
	_light(Vector3(7.32, y + 2.29, -1.39), 1.30, 5.1)


func _make_door(id: String, hinge: Vector3, yaw: float, width: float, height: float, tint: Color, label: String) -> void:
	var door := AnimatableBody3D.new()
	door.name = id
	door.position = hinge
	door.rotation.y = yaw
	door.set_meta("closed_yaw", yaw)
	door.set_meta("open", false)
	door.set_meta("label", label)
	door.set_meta("width", width)
	var center := Vector3(width * 0.5, height * 0.5 + 0.015, 0)
	add_child(door)
	_geo.box(door, center, Vector3(width, height, 0.087), tint)
	for side: float in [-1.0, 1.0]:
		_geo.box(door, Vector3(width - 0.15, 1.01, side * 0.062), Vector3(0.115, 0.047, 0.06), Color("#bdac92"))
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, 0.087)
	collider.shape = shape
	collider.position = center
	door.add_child(collider)
	_doors.append(door)


func _light(at: Vector3, energy: float, reach: float) -> void:
	var fixture := _geo.box(self, at + Vector3.UP * 0.15, Vector3(0.27, 0.10, 0.53), Color("#eee5d4"))
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("#eee5d4")
	glow.emission_enabled = true
	glow.emission = Color("#ffdba6")
	glow.emission_energy_multiplier = 0.26
	fixture.material_override = glow
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("#ffe6c8")
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.35
	add_child(light)


func contains(at: Vector3) -> bool:
	var p := to_local(at)
	var stair := absf(p.x) < 1.92 and p.z > -3.20 and p.z < Sites.THRESHOLD_Z and p.y > -0.16 and p.y < 5.4
	var flat := p.y >= FLOOR_HEIGHT - 0.1 and p.y < 5.4 and p.x >= 1.9 and (
		(p.x < 8.58 and p.z > -3.16 and p.z < 1.16) or (p.x < 3.92 and p.z >= 1.16 and p.z < 3.36))
	return stair or flat


func door_near(at: Vector3) -> AnimatableBody3D:
	var p := to_local(at)
	for door: AnimatableBody3D in _doors:
		var yaw: float = door.get_meta("closed_yaw")
		var center := door.position + Basis(Vector3.UP, yaw) * Vector3(float(door.get_meta("width")) * 0.5, 0, 0)
		if absf(p.y - center.y) < 0.77 and Vector2(p.x - center.x, p.z - center.z).length() < 1.65:
			return door
	return null


func door_label(at: Vector3) -> String:
	var door := door_near(at)
	if door == null:
		return ""
	return ("%s %s" % ["CLOSE" if door.get_meta("open") else "OPEN", door.get_meta("label")])


func toggle_door(at: Vector3) -> bool:
	var door := door_near(at)
	if door == null:
		return false
	var yaw: float = door.get_meta("closed_yaw")
	var offset := Basis(Vector3.UP, -yaw) * (to_local(at) - door.position)
	var opening := not bool(door.get_meta("open"))
	const SWING := 1.68
	var inside_sweep := (offset.z * signf(SWING) <= 0.27 and -offset.z * signf(SWING) < 1.57
		and offset.x > -0.32 and Vector2(offset.x, offset.z).length() < 1.61)
	if not opening and inside_sweep:
		return false
	var tween: Tween = door.get_meta("motion", null) if door.has_meta("motion") else null
	if tween != null:
		tween.kill()
	door.set_meta("open", opening)
	tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(door, "rotation:y", yaw + SWING if opening else yaw, 0.34)
	door.set_meta("motion", tween)
	return true
