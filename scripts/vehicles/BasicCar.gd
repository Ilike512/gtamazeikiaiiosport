extends RigidBody3D

signal wreck_created
signal incident(description: String, severity: int)
signal occupant_impact(strength: float)

const VehicleFire = preload("res://scripts/vehicles/VehicleFire.gd")

const MODEL = preload("res://assets/models/hatchback.glb")
const TireGrip = preload("res://scripts/vehicles/TireGrip.gd")
const VehicleShell = preload("res://scripts/vehicles/VehicleShell.gd")
const Geometry = preload("res://scripts/world/Geometry.gd")
const POLICE_EXTERIOR = preload("res://assets/models/traffic/PoliceSedan.fbx")
const VARIANTS := {
	"hatchback": {"name": "Hatchback", "mass": 1370.0, "length": 1.0, "width": 1.0, "height": 1.0, "radius": 0.316, "power": 7800.0, "speed": 59.0, "drag": 1.22},
	"sedan": {"name": "Family sedan", "mass": 1550.0, "length": 1.14, "width": 1.05, "height": 1.0, "radius": 0.334, "power": 8800.0, "speed": 65.0, "drag": 1.16, "model": "res://assets/models/sedan.glb"},
	"van": {"name": "Delivery van", "mass": 2020.0, "length": 1.37, "width": 1.14, "height": 1.52, "radius": 0.352, "power": 7500.0, "speed": 54.0, "drag": 1.72, "model": "res://assets/models/van.glb"},
	"coupe": {"name": "Mid-engine coupe", "mass": 1460.0, "length": 1.08, "width": 1.06, "height": 0.78, "radius": 0.343, "power": 10700.0, "speed": 75.0, "drag": 1.06, "model": "res://assets/models/coupe.glb"},
	"limbo": {"name": "Limbo", "mass": 1420.0, "length": 1.08, "width": 1.06, "height": 0.78, "radius": 0.343, "power": 11500.0, "speed": 55.56, "drag": 1.07, "model": "res://assets/models/coupe.glb"},
	"police": {"name": "Policija patrol car", "mass": 1615.0, "length": 1.14, "width": 1.05, "height": 1.0, "radius": 0.334, "power": 9200.0, "speed": 67.0, "drag": 1.16, "model": "res://assets/models/sedan.glb"}
}
const ENGINE := "res://assets/audio/sfx/engine.wav"
const DOOR := "res://assets/audio/sfx/door.wav"
const IMPACT := "res://assets/audio/sfx/impact.wav"

const WHEEL_RADIUS := 0.316
const REFERENCE_MASS := 1480.0

@export_group("Chassis")
@export_range(0.5, 2.0, 0.01) var mass_multiplier := 1.08
@export var center_of_mass_offset := Vector3(0, 0.075, 0.05)

@export_group("Suspension")
@export_range(0.20, 0.70, 0.01, "suffix:m") var suspension_travel := 0.48
@export_range(12000.0, 70000.0, 100.0, "suffix:N/m") var spring_stiffness := 26500.0
@export_range(1000.0, 8500.0, 50.0, "suffix:N·s/m") var damper_strength := 2850.0
@export_range(0.5, 1.5, 0.01) var rebound_damping_ratio := 1.12

@export_group("Tires")
@export_range(0.45, 1.8, 0.01) var tire_grip := 1.37
@export_range(0.6, 1.4, 0.01) var rear_grip_scale := 1.12
@export_range(3.0, 18.0, 0.5, "suffix:°") var peak_slip_angle := 8.0
@export_range(0.35, 1.0, 0.01) var sliding_grip_ratio := 0.85

@onready var _wheel_mounts: Array[Node] = $Suspension.get_children()

var occupied := false
var autopilot := false
var input_enabled := true
var speed := 0.0
var condition := 100.0
var wrecked := false
var wallet := 0
var variant := "hatchback"
var vehicle_name := "Hatchback"
var _radius := WHEEL_RADIUS
var _power := 7800.0
var _speed_limit := 59.0
var _drag := 1.22
var _steering_wheel: Node3D
var _wheel_rest := Basis.IDENTITY
var _driver_eye := Vector3(-0.36, 0.72, 0.23)

var _driver_door: Node3D
var _door_rest_rotation := 0.0
var _door_motion: Tween
var _auto_throttle := 0.0
var _auto_steer := 0.0
var _auto_brake := false
var _last_velocity := Vector3.ZERO
var _impact_delay := 0.0
var _sweep_delay := 0.0
var _impact_probe := BoxShape3D.new()
var _body_panel: MeshInstance3D
var _deformable: Array[MeshInstance3D] = []
var _detach_points: Array[MeshInstance3D] = []
var _crash_memory: Dictionary = {}
var _paint_materials: Array[StandardMaterial3D] = []
var _steering := 0.0
var _wheel_travel := PackedFloat32Array()
var _hubs: Array[Node3D] = []
var _wheels: Array[Node3D] = []
var _brake_lights: Array[StandardMaterial3D] = []
var _engine: AudioStreamPlayer3D
var _door: AudioStreamPlayer3D
var _impact: AudioStreamPlayer3D
var _braking := false
var parking_interaction := false
var _half_width := 0.88
var _siren: AudioStreamPlayer3D
var _horn: AudioStreamPlayer3D
var _beacons: Array[StandardMaterial3D] = []
var _flash_clock := 0.0
var _pursuit := false
var _recovery_pending := false
var _recovery_pose := Transform3D.IDENTITY


func _ready() -> void:
	if not VARIANTS.has(variant):
		variant = "hatchback"
	var spec: Dictionary = VARIANTS[variant]
	mass = float(spec.mass) * mass_multiplier
	_wheel_travel.resize(_wheel_mounts.size())
	_wheel_travel.fill(suspension_travel)
	vehicle_name = str(spec.name)
	_half_width = float(spec.width) * 0.88
	_radius = float(spec.radius)
	_power = float(spec.power)
	_speed_limit = float(spec.speed)
	_drag = float(spec.drag)
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = center_of_mass_offset
	continuous_cd = true
	linear_damp = 0.012
	angular_damp = 0.59
	can_sleep = false
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	contact_monitor = true
	max_contacts_reported = 6

	var physics := PhysicsMaterial.new()
	physics.friction = 0.55
	physics.bounce = 0.08
	physics_material_override = physics
	var collision: CollisionShape3D = $ChassisCollision
	var hull := ConvexPolygonShape3D.new()
	var points := PackedVector3Array([
		Vector3(-0.74, -0.25, -1.90), Vector3(0.74, -0.25, -1.90),
		Vector3(-0.83, 0.23, -2.08), Vector3(0.83, 0.23, -2.08),
		Vector3(-0.82, -0.25, 1.90), Vector3(0.82, -0.25, 1.90),
		Vector3(-0.82, 0.28, 2.07), Vector3(0.82, 0.28, 2.07),
		Vector3(-0.59, 0.73, -0.45), Vector3(0.59, 0.73, -0.45),
		Vector3(-0.62, 0.67, 1.20), Vector3(0.62, 0.67, 1.20)
	])
	for index in points.size():
		points[index] *= Vector3(float(spec.width), float(spec.height), float(spec.length))
	hull.points = points
	collision.shape = hull
	if variant == "police":
		_build_cabin($Visuals, spec)
		_build_patrol($Visuals, spec)
	else:
		_build_road_car($Visuals, spec)

	_engine = AudioStreamPlayer3D.new()
	_engine.stream = AssetShelf.sound("engine", ENGINE, true)
	_engine.bus = &"SFX"
	_engine.volume_db = -17.0
	_engine.max_distance = 28.0
	add_child(_engine)
	_door = AudioStreamPlayer3D.new()
	_door.stream = AssetShelf.sound("door", DOOR)
	_door.bus = &"SFX"
	_door.volume_db = -11.0
	add_child(_door)
	_impact = AudioStreamPlayer3D.new()
	_impact.stream = AssetShelf.sound("impact", IMPACT)
	_impact.bus = &"SFX"
	_impact.max_distance = 37.0
	add_child(_impact)
	_horn = AudioStreamPlayer3D.new()
	_horn.bus = &"SFX"
	_horn.max_distance = 48
	_horn.unit_size = 7.0
	_horn.volume_db = -7.0
	_horn.position.z = -1.22
	var horn_sample := {"hatchback": "horn_supplied_1.mp3", "sedan": "horn_supplied_2.mp3", "coupe": "horn_supplied_2.mp3", "limbo": "horn_supplied_2.mp3"}
	var fallback := "horn_" + ("sedan" if variant == "coupe" else variant) + ".wav"
	_horn.stream = AssetShelf.sound("horn_" + variant, "res://assets/audio/sfx/" + str(horn_sample.get(variant, fallback)))
	if _horn.stream == null:
		_horn.stream = AssetShelf.sound("horn_" + variant, "res://assets/audio/sfx/" + fallback)
	add_child(_horn)
	if variant == "limbo":
		set_paint(Color("#f4c524"))


func _build_cabin(shell: Node3D, spec: Dictionary) -> void:
	var selected_model: PackedScene = MODEL
	if spec.has("model") and ResourceLoader.exists(spec.model, "PackedScene"):
		selected_model = load(spec.model) as PackedScene
	var model := selected_model.instantiate() as Node3D
	model.position = Vector3(0, -0.54, -0.09)
	model.rotation.y = PI
	shell.add_child(model)
	_steering_wheel = model.find_child("steering_wheel", true, false) as Node3D
	if _steering_wheel != null:
		_wheel_rest = _steering_wheel.basis
		_driver_eye = to_local(_steering_wheel.global_position) + Vector3(0.0, 0.31, 0.46)
	for part: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var part_name := str(part.name)
		part.visible = part_name in ["interior", "steering_wheel_mesh", "pillar_lining"] or part_name.begins_with("card_")
		if part_name == "card_FL":
			part.hide()


func _build_road_car(shell: Node3D, spec: Dictionary) -> void:
	var packed: PackedScene = load(spec.model) if spec.has("model") else MODEL
	var model: Node3D = packed.instantiate()
	model.position.y = -0.54
	model.rotation.y = PI
	shell.add_child(model)
	_driver_door = model.find_child("door_L" if variant == "coupe" else "door_FL", true, false) as Node3D
	_body_panel = model.find_child("body", true, false) as MeshInstance3D
	if _driver_door == null:
		_split_driver_door(shell, model)
	else:
		_door_rest_rotation = _driver_door.rotation.y
		for part: MeshInstance3D in _driver_door.find_children("*", "MeshInstance3D", true, false):
			if str(part.name).ends_with("_body") or str(part.name).ends_with("_skin"):
				_deformable.append(part)
	_deformable.append(_body_panel)

	_steering_wheel = model.find_child("steering_wheel", true, false) as Node3D
	if _steering_wheel != null:
		_wheel_rest = _steering_wheel.basis
		_driver_eye = to_local(_steering_wheel.global_position) + Vector3(0.0, 0.31, 0.46)
	for index in 4:
		var suffix: String = ["FL", "FR", "RL", "RR"][index]
		var wheel := model.find_child("wheel_" + suffix, true, false) as Node3D
		var hub := Node3D.new()
		hub.name = "Wheel_" + suffix
		hub.position = shell.to_local(wheel.global_position)
		shell.add_child(hub)
		wheel.reparent(hub)
		_wheel_mounts[index].position = Vector3(hub.position.x, 0.055, hub.position.z)
		_hubs.append(hub)
		_wheels.append(wheel)
	for part: MeshInstance3D in shell.find_children("*", "MeshInstance3D", true, false):
		var part_name := str(part.name)
		if part_name.begins_with("caliper_") and not str(part.get_parent().name).begins_with("steer_"):
			part.hide()
		if part_name in ["bonnet_body", "bonnet_skin", "boot_body", "boot_skin", "spoiler", "wing_skin"]:
			_deformable.append(part)
			_detach_points.append(part)
		_prepare_exterior_materials(part)


func _split_driver_door(shell: Node3D, model: Node3D) -> void:
	var source := _body_panel
	var hinge_z := -1.65 if variant == "van" else -0.84
	var hinge := Vector3(-_half_width * 0.94, 0, hinge_z)
	var relative := shell.global_transform.affine_inverse() * source.global_transform
	var roof_height := 1.55 if variant == "van" else 0.88
	var segments := VehicleShell.divide(source, relative, hinge, _half_width, roof_height, variant)
	source.hide()
	source.queue_free()
	_body_panel = MeshInstance3D.new()
	_body_panel.name = "Exterior"
	_body_panel.mesh = segments[0]
	shell.add_child(_body_panel)
	_driver_door = Node3D.new()
	_driver_door.name = "DriverDoor"
	_driver_door.position = hinge
	shell.add_child(_driver_door)
	var skin := MeshInstance3D.new()
	skin.mesh = segments[1]
	_driver_door.add_child(skin)
	_deformable.append(skin)
	for name_on_model: String in ["mirror_L", "glass_side_L"]:
		var part := model.find_child(name_on_model, true, false) as Node3D
		if part != null:
			part.reparent(_driver_door)


func _build_patrol(shell: Node3D, spec: Dictionary) -> void:
	var model: Node3D = POLICE_EXTERIOR.instantiate()
	var y_scale := _radius / 0.40
	model.scale = Vector3(float(spec.width) * 0.66, y_scale, 0.82 + (float(spec.length) - 1.0) * 0.32)
	model.rotation.y = PI
	model.position.y = -0.29 - 0.40 * y_scale
	shell.add_child(model)
	var prefix := "Police Sedan"
	var imported: MeshInstance3D = model.find_child(prefix, true, false)
	var hinge := Vector3(-_half_width * 0.94, 0, -0.92)
	var relative := shell.global_transform.affine_inverse() * imported.global_transform
	var segments := VehicleShell.divide(imported, relative, hinge, _half_width, 0.78 if variant != "van" else 1.02, variant)
	_body_panel = MeshInstance3D.new()
	_body_panel.name = "Exterior"
	_body_panel.mesh = segments[0]
	shell.add_child(_body_panel)
	_deformable.append(_body_panel)
	imported.hide()
	_driver_door = Node3D.new()
	_driver_door.name = "DriverDoor"
	_driver_door.position = hinge
	shell.add_child(_driver_door)
	var door_skin := MeshInstance3D.new()
	door_skin.mesh = segments[1]
	_driver_door.add_child(door_skin)
	_deformable.append(door_skin)
	for panel: MeshInstance3D in [_body_panel, door_skin]:
		_prepare_exterior_materials(panel)
	var index := 0
	for part: String in ["front left", "front right", "rear left", "rear right"]:
		var wheel: Node3D = model.find_child(prefix + " wheel " + part, true, false)
		var hub := Node3D.new()
		hub.name = "Wheel_" + part.replace(" ", "_")
		hub.position = shell.to_local(wheel.global_position)
		shell.add_child(hub)
		wheel.reparent(hub)
		if variant != "hatchback":
			_wheel_mounts[index].position = Vector3(hub.position.x, 0.055, hub.position.z)
		_hubs.append(hub)
		_wheels.append(wheel)
		index += 1
	var geo := Geometry.new()
	var length := float(spec.length)
	for z: float in [-1.97 * length, 2.02 * length]:
		var bumper := geo.box(shell, Vector3(0, -0.151, z), Vector3(_half_width * 1.68, 0.15, 0.20), Color("#2a2c2e"))
		bumper.name = "Bumper"
		_deformable.append(bumper)
		_detach_points.append(bumper)
	if variant == "police":
		geo.signage(shell, Vector3(-_half_width - 0.026, 0.19, 0.35), "POLICIJA", 25, Color("#eaf1eb"), -PI * 0.5)
		geo.signage(shell, Vector3(_half_width + 0.026, 0.19, 0.35), "POLICIJA", 25, Color("#eaf1eb"), PI * 0.5)
		_siren = AudioStreamPlayer3D.new()
		_siren.stream = AssetShelf.sound("police_siren", "res://assets/audio/sfx/patrol_supplied.mp3", true)
		if _siren.stream == null:
			_siren.stream = AssetShelf.sound("police_siren", "res://assets/audio/sfx/patrol_recording.ogg", true)
		_siren.bus = &"SFX"
		_siren.volume_db = -13
		_siren.max_distance = 125.0
		add_child(_siren)


func _prepare_exterior_materials(panel: MeshInstance3D) -> void:
	for surface in panel.mesh.get_surface_count():
		var imported := panel.get_active_material(surface) as StandardMaterial3D
		if imported == null:
			continue
		var material := imported.duplicate() as StandardMaterial3D
		panel.set_surface_override_material(surface, material)
		var label := imported.resource_name
		match label:
			"windows", "glass", "glass_clear":
				material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				material.cull_mode = BaseMaterial3D.CULL_DISABLED
				material.albedo_color = Color(0.42, 0.53, 0.55, 0.35)
				material.roughness = 0.29
			"rear lights", "light_rear", "light_rear_body", "lamp_red_body", "lens_red":
				material.emission_enabled = true
				material.emission = Color("#e03935")
				material.emission_energy_multiplier = 0.05
				_brake_lights.append(material)
			"flashers siren red", "flashers siren blue":
				material.emission_enabled = true
				material.emission = Color("#ff334d") if label.ends_with("red") else Color("#426cff")
				_beacons.append(material)
			_:
				if variant == "police" and label.begins_with("body"):
					material.albedo_color = Color("#15784d") if label.ends_with("black") else Color("#e0e6e1")
				elif label in ["paint", "paint_body"] or (label.begins_with("body") and not label.ends_with("black") and not label.ends_with("white")):
					material.albedo_color = Color("#387980")
					material.metallic = 0.30
					material.roughness = 0.34
					_paint_materials.append(material)


func set_pursuit(value: bool) -> void:
	if _pursuit == value:
		return
	_pursuit = value
	if _siren != null and _siren.stream != null:
		if value:
			_siren.play()
		else:
			_siren.stop()


func set_driver(value: bool, play_door := true) -> void:
	occupied = value
	sleeping = false
	if play_door:
		animate_driver_door(true)
		get_tree().create_timer(0.30, false).timeout.connect(animate_driver_door.bind(false))
	if occupied and not wrecked:
		if _engine.stream != null:
			_engine.play()
	else:
		_engine.stop()


func honk() -> void:
	if not wrecked and _horn.stream != null:
		_horn.play()


func animate_driver_door(open: bool) -> void:
	if _door.stream != null:
		_door.play()
	if not is_instance_valid(_driver_door):
		return
	if _door_motion != null:
		_door_motion.kill()
	_door_motion = create_tween().set_trans(Tween.TRANS_SINE)
	_door_motion.tween_property(_driver_door, "rotation:y", _door_rest_rotation - (0.96 if open else 0.0), 0.26)


func driver_side_point() -> Vector3:
	var pose := Transform3D(Basis(Vector3.UP, heading()), global_position)
	return pose * Vector3(-_half_width - 0.53, 0, -0.34)


func set_paint(color: Color) -> void:
	for material: StandardMaterial3D in _paint_materials:
		material.albedo_color = color


func set_traffic_input(throttle: float, steer: float, brake: bool) -> void:
	_auto_throttle = throttle
	_auto_steer = steer
	_auto_brake = brake


func take_glovebox() -> int:
	var taken := wallet
	wallet = 0
	return taken


func apply_impact(strength: float, at: Vector3, inward: Vector3) -> void:
	if wrecked:
		return
	condition = clampf(condition - maxf(strength - 5.6, 0.0) * 0.97, 0.0, 100.0)
	if strength > 5.35:
		_impact.volume_db = lerpf(-19.0, -4.5, clampf(strength / 18.0, 0.0, 1.0))
		_impact.play()
		_dent(at, inward, minf(strength * 0.020, 0.43))
	if strength >= 23.0 and not _detach_points.is_empty():
		_drop_loose_panel(at, inward, strength)
	if condition <= 16.0:
		_ignite()
	if condition <= 0.0:
		_make_wreck()


func restore_condition(saved: float) -> void:
	condition = clampf(saved, 0.0, 100.0)
	if condition <= 16.0:
		_ignite()
	if condition <= 0.0 and not wrecked:
		_make_wreck()


func _ignite() -> void:
	if has_node("EngineFire"):
		return
	var fire := VehicleFire.new()
	fire.name = "EngineFire"
	fire.position = Vector3(0.06, 0.62, -1.24)
	add_child(fire)


func _make_wreck() -> void:
	_ignite()
	wrecked = true
	_engine.stop()
	var smoke := CPUParticles3D.new()
	smoke.position = Vector3(0.12, 0.48, -1.46)
	smoke.amount = 29
	smoke.lifetime = 2.2
	smoke.direction = Vector3(0.13, 1.0, 0.11)
	smoke.gravity = Vector3(0.22, 0.55, 0.08)
	smoke.spread = 23.0
	smoke.initial_velocity_min = 0.67
	smoke.initial_velocity_max = 1.35
	smoke.scale_amount_min = 0.52
	smoke.scale_amount_max = 1.44
	var sprite := SphereMesh.new()
	sprite.radius = 0.24
	sprite.height = 0.49
	sprite.radial_segments = 7
	sprite.rings = 3
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.16, 0.17, 0.17, 0.23)
	sprite.material = material
	smoke.mesh = sprite
	add_child(smoke)
	wreck_created.emit()


func _dent(at: Vector3, inward: Vector3, amount: float) -> void:
	var local_normal := global_basis.inverse() * inward
	var local_hit := to_local(at)
	var zone := Vector2i(roundi(local_hit.x), roundi(local_hit.z))
	var remaining := 1.0 - clampf(float(_crash_memory.get(zone, 0.0)), 0.0, 0.78)
	_crash_memory[zone] = 1.0 - remaining + amount
	var crush := global_basis * (local_normal + Vector3.UP * 0.07).normalized()
	for panel: MeshInstance3D in _deformable:
		if not is_instance_valid(panel) or panel.mesh == null:
			continue
		var source := panel.mesh
		var revised := ArrayMesh.new()
		var model_transform := panel.global_transform
		var direction := model_transform.basis.inverse() * crush
		var changed := false
		for surface in source.get_surface_count():
			var arrays := source.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var radius := 1.0 + amount * 1.6
			for index in vertices.size():
				var point := model_transform * vertices[index] - at
				var distance := Vector3(point.x, point.y * 1.27, point.z).length()
				if distance < radius:
					var falloff := 1.0 - smoothstep(0.0, radius, distance)
					var crease := sin(point.y * 11.4 + point.x * 4.8 + point.z * 4.2) * 0.20
					var lip := smoothstep(radius * 0.56, radius * 0.71, distance) * (1.0 - smoothstep(radius * 0.73, radius, distance))
					vertices[index] += direction * (falloff * (1.0 + crease) - lip * 0.13) * amount * remaining
					changed = true
			arrays[Mesh.ARRAY_VERTEX] = vertices
			revised.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
			revised.surface_set_material(surface, panel.get_active_material(surface))
		if changed:
			panel.mesh = revised


func _drop_loose_panel(at: Vector3, inward: Vector3, strength: float) -> void:
	var candidate: MeshInstance3D
	var best := 1.35 ** 2
	for panel: MeshInstance3D in _detach_points:
		var center := panel.global_transform * panel.get_aabb().get_center()
		var distance := center.distance_squared_to(at)
		if distance < best:
			candidate = panel
			best = distance
	if candidate == null:
		return
	_detach_points.erase(candidate)
	_deformable.erase(candidate)
	var debris := RigidBody3D.new()
	debris.mass = 7.0
	debris.collision_layer = 32
	debris.collision_mask = 1 | 4
	debris.angular_damp = 0.65
	get_parent().add_child(debris)
	debris.global_position = candidate.global_transform * candidate.get_aabb().get_center()
	candidate.reparent(debris, true)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.78, 0.15, 0.27)
	collision.shape = shape
	debris.add_child(collision)
	debris.linear_velocity = linear_velocity * 0.43 + inward * minf(2.0, strength * 0.12) + Vector3.UP * 1.6
	debris.angular_velocity = Vector3(1.4, 3.4, 2.3)
	get_tree().create_timer(15.0, false).timeout.connect(debris.queue_free)


func heading() -> float:
	var axis := global_basis.z
	return atan2(axis.x, axis.z)


func driver_avatar_transform() -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, _driver_eye + Vector3(0.0, -0.74, 0.08))


func passenger_avatar_transform() -> Transform3D:
	return global_transform * Transform3D(Basis.IDENTITY, Vector3(-_driver_eye.x, _driver_eye.y - 0.74, _driver_eye.z + 0.08))


func cockpit_transform(yaw: float, pitch: float) -> Transform3D:
	var swivel := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	return global_transform * Transform3D(swivel, _driver_eye)


func reset_pose(location: Vector3, yaw: float) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, yaw), location)
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	speed = 0.0
	_last_velocity = Vector3.ZERO
	sleeping = false
	reset_physics_interpolation()


func request_recovery(pose: Transform3D) -> void:
	_recovery_pose = pose
	_recovery_pending = true
	sleeping = false


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if _recovery_pending:
		_recovery_pending = false
		state.transform = _recovery_pose
		state.linear_velocity = Vector3.ZERO
		state.angular_velocity = Vector3.ZERO
		_last_velocity = Vector3.ZERO
		_wheel_travel.fill(suspension_travel)
		_steering = 0.0
		speed = 0.0
		_impact_delay = 0.65
		reset_physics_interpolation.call_deferred()
		return
	_impact_delay = maxf(0.0, _impact_delay - state.step)
	if _impact_delay <= 0.0:
		_report_collisions(state)
	var transform_now := state.transform
	var up := transform_now.basis.y
	var forward := -transform_now.basis.z
	speed = state.linear_velocity.dot(forward)
	_sweep_delay = maxf(0.0, _sweep_delay - state.step)
	if occupied and absf(speed) > 3.0 and _sweep_delay <= 0.0:
		_sweep_pedestrians(state, forward if speed >= 0.0 else -forward)
	var driving := occupied and input_enabled and not wrecked
	var throttle := Input.get_action_strength("move_forward") - Input.get_action_strength("move_back") if driving else 0.0
	var steer := Input.get_action_strength("move_right") - Input.get_action_strength("move_left") if driving else 0.0
	_braking = (driving and Input.is_action_pressed("jump_brake")) or (not occupied and not autopilot) or wrecked
	if autopilot and not wrecked:
		throttle = _auto_throttle
		steer = _auto_steer
		_braking = _auto_brake
	if parking_interaction:
		_braking = true
		throttle = 0.0
		steer = 0.0
	var changing_direction := throttle * speed < -0.75
	var steer_limit := lerpf(0.55, 0.12, smoothstep(6.0, 35.0, absf(speed)))
	var steer_target := steer * steer_limit
	var steer_response := 4.4 if absf(steer_target) < absf(_steering) else 3.1
	_steering = move_toward(_steering, steer_target, state.step * steer_response)
	var drag := state.linear_velocity * (15.0 + state.linear_velocity.length() * _drag)
	drag.y = 0.0
	state.apply_central_force(-drag)
	for index in _wheel_mounts.size():
		_apply_wheel(state, index, up, forward, throttle, _braking or changing_direction)
	_last_velocity = state.linear_velocity


func _sweep_pedestrians(state: PhysicsDirectBodyState3D, direction: Vector3) -> void:
	_sweep_delay = 0.045
	var velocity := absf(speed)
	var offset := 1.61 + velocity * 0.020
	_impact_probe.size = Vector3(_half_width * 2.0 + 0.25, 1.38, 1.12 + velocity * 0.064)
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _impact_probe
	query.transform = Transform3D(state.transform.basis, state.transform.origin + direction * offset + Vector3.UP * 0.14)
	query.collision_mask = 8
	for hit: Dictionary in state.get_space_state().intersect_shape(query, 8):
		var target := hit.collider as CharacterBody3D
		if target != null and target.has_method("vehicle_impact") and not target.downed:
			_resolve_impact.call_deferred(target, maxf(6.0, velocity * 1.15), target.global_position + Vector3.UP * 0.55, -direction)


func _report_collisions(state: PhysicsDirectBodyState3D) -> void:
	var strongest := 2.9
	var target: Node3D
	var hit_point := Vector3.ZERO
	var hit_normal := Vector3.ZERO
	for index in state.get_contact_count():
		var other := state.get_contact_collider_object(index) as Node3D
		if other == null:
			continue
		var point := state.get_contact_collider_position(index)
		var toward_center := (state.transform.origin - point).slide(Vector3.UP).normalized()
		var normal := state.get_contact_local_normal(index)
		if absf(normal.y) > 0.80 and not other.has_method("vehicle_impact") and not other.has_method("receive_vehicle_hit"):
			continue
		normal = normal.slide(Vector3.UP).normalized()
		if absf(normal.dot(toward_center)) < 0.48:
			normal = toward_center
		elif normal.dot(toward_center) < 0.0:
			normal = -normal
		if normal.is_zero_approx():
			continue
		var impulse := state.get_contact_impulse(index).slide(Vector3.UP).length() / mass
		var relative := _last_velocity - state.get_contact_collider_velocity_at_position(index)
		var incoming := maxf(-relative.dot(normal), 0.0)
		var force := maxf(incoming, minf(impulse * 0.90, relative.slide(Vector3.UP).length() + 1.4))
		if other.is_in_group("tree_trunks"):
			force = minf(force, relative.slide(Vector3.UP).length())
		if force > strongest:
			target = other
			strongest = force
			hit_point = point
			hit_normal = normal
	if target != null:
		_impact_delay = 0.43
		_resolve_impact.call_deferred(target, strongest, hit_point, hit_normal)


func _resolve_impact(target: Node3D, force: float, at: Vector3, inward: Vector3) -> void:
	if not is_instance_valid(target):
		return
	if target.has_method("vehicle_impact"):
		target.vehicle_impact(force, -inward)
		apply_impact(force * 0.28, at, inward)
		if occupied and force >= 4.1:
			incident.emit("PEDESTRIAN COLLISION", 2 if force >= 8.8 else 1)
		return
	if target.has_method("receive_vehicle_hit") and target.receive_vehicle_hit(force, -inward):
		apply_impact(force * 0.22, at, inward)
		if occupied:
			incident.emit("PUBLIC PROPERTY DAMAGE", 1)
		return
	if occupied and force > 16.5:
		occupant_impact.emit(force)
	apply_impact(force, at, inward)
	if target.is_in_group("city_facade") or target.is_in_group("breakable_fixture"):
		get_tree().call_group("city_impact", "facade_hit", target, at, inward, force)
		if occupied and force >= 7.8:
			incident.emit("BUILDING COLLISION", 1)


func _apply_wheel(state: PhysicsDirectBodyState3D, index: int, up: Vector3, forward: Vector3, throttle: float, braking: bool) -> void:
	var mount: Marker3D = _wheel_mounts[index]
	var hub := state.transform * mount.position
	var ray := PhysicsRayQueryParameters3D.create(hub, hub - up * (suspension_travel + _radius), 1, [get_rid()])
	var space := state.get_space_state()
	var hit := space.intersect_ray(ray)
	while not hit.is_empty() and hit.collider.is_in_group("tree_trunks"):
		var excluded := ray.exclude
		excluded.append(hit.rid)
		ray.exclude = excluded
		hit = space.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < 0.48 or hit.normal.dot(up) < 0.48:
		_wheel_travel[index] = minf(_wheel_travel[index] + state.step * 2.3, suspension_travel)
		return

	var contact: Vector3 = hit.position
	var normal: Vector3 = hit.normal
	var offset := contact - state.transform.origin
	var point_velocity := state.linear_velocity + state.angular_velocity.cross(offset - state.center_of_mass)
	var travel := clampf(hub.distance_to(contact) - _radius, 0.015, suspension_travel)
	_wheel_travel[index] = travel
	var compression := suspension_travel - travel
	var bump_stop := smoothstep(0.72, 1.0, compression / suspension_travel)
	var motion := point_velocity.dot(normal)
	var damping := damper_strength * (rebound_damping_ratio if motion > 0.0 else 1.0)
	var suspension_scale := mass / REFERENCE_MASS
	var normal_force := maxf(0.0, (spring_stiffness * compression * (1.0 + bump_stop * 0.85) - damping * motion) * suspension_scale)
	state.apply_force(normal * normal_force, hub - state.transform.origin)

	var front := index < 2
	var axle_forward := (Basis(up, -_steering) * forward if front else forward).slide(normal).normalized()
	var axle_right := axle_forward.cross(normal)
	var along := point_velocity.dot(axle_forward)
	var sideways := point_velocity.dot(axle_right)
	var longitudinal := _longitudinal_demand(along, throttle, braking, front)
	var slip := atan2(sideways, maxf(absf(along), 1.8))
	var nominal_load := mass * 9.8 * 0.25
	var load_sensitivity := clampf(1.10 - 0.10 * normal_force / nominal_load, 0.72, 1.10)
	var grip := normal_force * tire_grip * load_sensitivity * (1.0 if front else rear_grip_scale)
	var peak := deg_to_rad(peak_slip_angle * (1.0 if front else 1.22))
	var slip_capacity := minf(absf(sideways) * mass * 0.23 / maxf(state.step, 0.008), grip)
	var forces := TireGrip.forces(slip, longitudinal, grip, peak, sliding_grip_ratio, Vector2(along, sideways).length())
	forces.y = clampf(forces.y, -slip_capacity, slip_capacity)
	state.apply_force(axle_forward * forces.x + axle_right * forces.y, offset)


func _longitudinal_demand(along: float, throttle: float, braking: bool, front: bool) -> float:
	if braking:
		var limit := 5900.0 if front else 4250.0
		return clampf(-along * 2900.0, -limit, limit)
	if front or absf(throttle) <= 0.02:
		return -along * 19.0
	var governor := 13.0 if throttle < 0.0 else _speed_limit
	var motor := lerpf(_power, _power * 0.57, smoothstep(2.0, governor, absf(speed)))
	if autopilot or throttle < 0.0:
		motor *= 0.59
	if absf(speed) >= governor:
		return -along * 19.0
	return throttle * motor - along * 19.0


func _process(delta: float) -> void:
	if is_instance_valid(_steering_wheel):
		_steering_wheel.basis = _wheel_rest * Basis(Vector3.BACK, -_steering * 5.6)
	for index in _hubs.size():
		_hubs[index].position.y = _wheel_mounts[index].position.y - _wheel_travel[index]
		_hubs[index].rotation.y = -_steering if index < 2 else 0.0
		_wheels[index].rotate(Vector3.RIGHT, -speed * delta / _radius)
	if not _beacons.is_empty():
		_flash_clock += delta
		for index in _beacons.size():
			var pulse := fmod(_flash_clock + index * 0.27, 0.58) < 0.18
			_beacons[index].emission_energy_multiplier = 2.6 if _pursuit and pulse else 0.0
	_engine.pitch_scale = 0.69 + minf(absf(speed) * 0.046, 1.68)
	for light: StandardMaterial3D in _brake_lights:
		light.emission_energy_multiplier = 2.3 if _braking and occupied else 0.05
