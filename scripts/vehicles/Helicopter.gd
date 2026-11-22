extends CharacterBody3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const VehicleFire = preload("res://scripts/vehicles/VehicleFire.gd")

const CRUISE_SPEED := 43.0
const CLIMB_SPEED := 9.0
const MAX_HEIGHT := 185.0

var occupied := false
var crashing := false
var _crash_finished := false
var controls_enabled := true
var replica := false
var pad_height := 0.0
var _rotor: Node3D
var _tail_rotor: Node3D
var _rotor_audio: AudioStreamPlayer3D
var _spool := 0.0
var _geo := Geometry.new()

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_rotor_audio = AudioStreamPlayer3D.new()
	_rotor_audio.bus = &"SFX"
	_rotor_audio.stream = AssetShelf.sound("helicopter_rotor", "res://assets/audio/sfx/helicopter_rotor.mp3", true)
	_rotor_audio.unit_size = 20.0
	_rotor_audio.max_distance = 125.0
	_rotor_audio.volume_db = -40.0
	add_child(_rotor_audio)
	var paint := Color("#365e64")
	var dark := Color("#1e282d")
	var silver := Color("#acb8b3")
	var glass := Color("#345069")
	_pod(Vector3(0, 1.12, 0), Vector3(2.15, 1.72, 4.1), paint)
	var cockpit := _pod(Vector3(0, 1.45, -0.91), Vector3(1.94, 1.18, 2.14), glass)
	cockpit.material_override = _geo.material(glass).duplicate()
	cockpit.material_override.roughness = 0.21
	_pod(Vector3(0, 1.74, 0.25), Vector3(1.52, 0.84, 2.85), paint)
	_geo.box(_visual, Vector3(0, 1.55, -1.97), Vector3(0.08, 0.53, 0.14), paint)
	_geo.box(_visual, Vector3(0, 1.47, 3.19), Vector3(0.53, 0.47, 3.39), paint)
	_geo.box(_visual, Vector3(0, 1.48, 4.50), Vector3(1.92, 0.10, 0.61), silver)
	var fin := _geo.box(_visual, Vector3(0, 2.02, 4.60), Vector3(0.13, 1.23, 0.70), paint)
	fin.rotation.x = -0.34
	for side: float in [-1.0, 1.0]:
		var x := side * 0.88
		_geo.box(_visual, Vector3(x, 0.13, -0.08), Vector3(0.10, 0.10, 3.83), dark)
		for z: float in [-1.29, 1.42]:
			_geo.box(_visual, Vector3(x * 0.96, 0.37, z), Vector3(0.09, 0.52, 0.11), silver)
		var light_color := Color("#dc4447") if side < 0.0 else Color("#92b45a")
		_pod(Vector3(side * 0.91, 1.52, 4.51), Vector3(0.18, 0.13, 0.21), light_color)
		_geo.box(_visual, Vector3(side * 0.99, 1.19, 0.48), Vector3(0.035, 0.065, 0.39), silver)
	_rotor = _blade_hub(Vector3(0, 2.49, 0.0), 5.02, 0.17)
	_tail_rotor = _blade_hub(Vector3(0.20, 2.29, 4.66), 0.66, 0.09)
	_tail_rotor.rotation.z = PI * 0.5
	_geo.taper(_visual, Vector3(0, 2.27, 0), 0.43, 0.13, 0.17, dark, 10)
	_geo.batch_static(_visual)


func _pod(at: Vector3, size: Vector3, tint: Color) -> MeshInstance3D:
	var form := SphereMesh.new()
	form.radial_segments = 24
	form.rings = 12
	var model := MeshInstance3D.new()
	model.mesh = form
	model.material_override = _geo.material(tint)
	model.scale = size
	model.position = at
	_visual.add_child(model)
	return model


func _blade_hub(at: Vector3, radius: float, width: float) -> Node3D:
	var hub := Node3D.new()
	hub.position = at
	_visual.add_child(hub)
	var color := Color("#303737")
	for rotation_in_degrees: float in [0.0, 90.0, 180.0, 270.0]:
		var arm := Node3D.new()
		arm.rotation_degrees.y = rotation_in_degrees
		hub.add_child(arm)
		_geo.box(arm, Vector3(0, 0, -radius * 0.54), Vector3(width, 0.034, radius * 0.92), color)
		_geo.box(arm, Vector3(0, 0, -radius), Vector3(width, 0.035, radius * 0.09), Color("#cec7a2"))
	return hub


func _process(delta: float) -> void:
	_spool = move_toward(_spool, 1.0 if occupied else 0.0, delta * 0.68)
	if _rotor_audio.stream != null:
		if _spool > 0.025:
			_rotor_audio.pitch_scale = lerpf(0.66, 1.0, _spool)
			_rotor_audio.volume_db = lerpf(-35.0, -9.0, _spool)
			if not _rotor_audio.playing:
				_rotor_audio.play()
		elif _rotor_audio.playing:
			_rotor_audio.stop()
	_rotor.rotate_y(delta * _spool * 27.0)
	_tail_rotor.rotate_object_local(Vector3.UP, delta * _spool * 37.0)


func _physics_process(delta: float) -> void:
	if crashing and not _crash_finished:
		velocity.y -= delta * 13.0
		_visual.rotation.z = move_toward(_visual.rotation.z, 0.43, delta * 0.24)
		move_and_slide()
		if get_slide_collision_count() > 0:
			_crash_finished = true
			velocity = Vector3.ZERO
			get_tree().call_group("city_impact", "game_flash", global_position + Vector3.UP * 0.7)
		return
	if not occupied or replica:
		return
	var thrust := 0.0
	var yaw := 0.0
	var vertical := 0.0
	if controls_enabled:
		thrust = Input.get_axis("move_back", "move_forward")
		yaw = Input.get_axis("move_right", "move_left")
		var descend := maxf(Input.get_action_strength("dive"), Input.get_action_strength("sprint"))
		vertical = Input.get_action_strength("jump_brake") - descend
	rotation.y += yaw * delta * 1.40
	var ahead := -global_basis.z * thrust * CRUISE_SPEED
	velocity.x = move_toward(velocity.x, ahead.x, 14.0 * delta)
	velocity.z = move_toward(velocity.z, ahead.z, 14.0 * delta)
	var target_climb := vertical * CLIMB_SPEED
	if global_position.y > pad_height + MAX_HEIGHT:
		target_climb = minf(target_climb, 0.0)
	velocity.y = move_toward(velocity.y, target_climb, 11.0 * delta)
	move_and_slide()
	_visual.rotation.x = lerpf(_visual.rotation.x, -thrust * 0.15, 1.0 - exp(-delta * 3.7))
	_visual.rotation.z = lerpf(_visual.rotation.z, yaw * 0.20, 1.0 - exp(-delta * 3.7))


func start_crash(motion: Vector3) -> void:
	if crashing:
		return
	crashing = true
	velocity = motion
	var fire := VehicleFire.new()
	fire.name = "EngineFire"
	fire.position = Vector3(0.0, 1.59, 0.77)
	add_child(fire)


func ground_below(at: Vector3, depth: float) -> Dictionary:
	var probe := PhysicsRayQueryParameters3D.create(at, at - Vector3.UP * depth, 1, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(probe)

