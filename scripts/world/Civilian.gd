extends CharacterBody3D

signal counter_hit(strength: float)

const Clips = preload("res://scripts/player/InteractionClips.gd")
const Gait = preload("res://scripts/player/Gait.gd")
const Ragdoll = preload("res://scripts/world/ActiveRagdoll.gd")
const DEFAULT_MODEL = preload("res://assets/models/pedestrian.glb")
const MODEL_PATHS := [
	"res://assets/models/pedestrian.glb",
	"res://assets/models/pedestrian_hiker.glb",
	"res://assets/models/joris.glb",
	"res://assets/models/characters/road_worker.glb"
]

var pace := 1.38
var model_variant := 0
var route_a := Vector3.ZERO
var route_b := Vector3.ZERO
var cash := 12
var downed := false
var fatal := false
var carried := false
var _opponent: CharacterBody3D
var _counter_timeout := 0.0
var _swing := 0.0
var _swing_lock := 0.0
var _model: Node3D
var _animation: AnimationPlayer
var _hostile := false
var _flee_time := 0.0
var _moving_to_b := true
var _ragdoll: RefCounted
var _injury_load := 0.0
var _bleed_time := 0.0
var _next_drip := 0.0
var _wound: Node3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.37
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.69
	shape.shape = capsule
	shape.position.y = 0.845
	add_child(shape)
	var path: String = MODEL_PATHS[clampi(model_variant, 0, MODEL_PATHS.size() - 1)]
	var model := load(path) as PackedScene if ResourceLoader.exists(path, "PackedScene") else null
	_model = (model if model != null else DEFAULT_MODEL).instantiate() as Node3D
	_model.rotation.y = PI
	add_child(_model)
	for controller: AnimationPlayer in _model.find_children("*", "AnimationPlayer", true, false):
		if controller.has_animation("walk"):
			_animation = controller
			for clip: String in ["idle", "walk", "run"]:
				if controller.has_animation(clip):
					controller.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			var skeletons := _model.find_children("*", "Skeleton3D", true, false)
			if not skeletons.is_empty():
				Gait.install_run(controller, skeletons[0])
				if not controller.has_animation("punch"):
					Clips.install(controller)
				_ragdoll = Ragdoll.new(self, skeletons[0], controller)
			controller.play("walk")
			break


func appearance(tint: Color, height: float, travel_speed: float, wallet: int) -> void:
	pace = travel_speed
	cash = wallet
	_hostile = wallet % 3 == 0
	_model.scale = Vector3.ONE * height
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.get_active_material(surface) as StandardMaterial3D
			if original != null:
				var copy := original.duplicate() as StandardMaterial3D
				copy.albedo_color = original.albedo_color * tint
				mesh.set_surface_override_material(surface, copy)


func steal_wallet() -> int:
	var taken := cash
	cash = 0
	if taken > 0 and not downed:
		_flee_time = 5.0
		_moving_to_b = not _moving_to_b
	return taken


func vehicle_impact(strength: float, direction: Vector3) -> void:
	if downed or _ragdoll == null or not _ragdoll.hit(strength, direction):
		return
	downed = true
	_record_injury(strength * 1.18)
	if strength >= Ragdoll.FALL_THRESHOLD:
		get_tree().call_group("city_impact", "injury", global_position + Vector3.UP * 0.7, direction, strength)


func receive_attack(strength: float, direction: Vector3, attacker: CharacterBody3D, hit_at: Vector3, ranged: bool, kind := "") -> void:
	if fatal and kind != "field_blade":
		get_tree().call_group("city_impact", "injury", hit_at, direction, strength * 0.56)
		return
	if _hostile and not ranged:
		_opponent = attacker
		_counter_timeout = 12.0
	else:
		_flee_time = 4.5
		_moving_to_b = (route_b - global_position).dot(direction) > 0.0
	if _ragdoll != null and _ragdoll.hit(strength, direction):
		downed = true
		_record_injury(strength * (1.25 if ranged else 0.60))
		_swing = 0.0
		_swing_lock = 0.0
	if fatal and downed and _wound == null and kind == "field_blade" and int(GameManager.settings.injury_effects) == 2:
		_wound = _ragdoll.cut(_model, hit_at, direction)
		if _wound != null:
			_bleed_time = 55.0
			get_tree().call_group("city_impact", "injury", _wound.global_position, direction, 27.0)
			return
	get_tree().call_group("city_impact", "injury", hit_at, direction, strength * (1.25 if ranged else 0.48))


func _record_injury(amount: float) -> void:
	_injury_load += amount
	if _injury_load >= 32.0:
		fatal = true
		_bleed_time = maxf(_bleed_time, 33.0 if fatal else 15.0)


func body_position() -> Vector3:
	return _ragdoll.body_position() if downed and _ragdoll != null else global_position


func can_carry() -> bool:
	return fatal and downed and not carried and _ragdoll.phase == Ragdoll.Phase.FALLEN


func carry_toward(at: Vector3) -> void:
	carried = true
	_ragdoll.carry_toward(at)


func release_body(motion: Vector3) -> void:
	carried = false
	_ragdoll.release_body(motion)
	_bleed_time = maxf(_bleed_time, 3.5)


func _drip_if_needed(delta: float) -> void:
	_bleed_time = maxf(_bleed_time - delta, 0.0)
	_next_drip -= delta
	if _next_drip > 0.0 or (not carried and _bleed_time <= 0.0):
		return
	var moving: bool = carried or _ragdoll.body_is_moving()
	var source := _wound.global_position if is_instance_valid(_wound) else body_position()
	var spread := (0.22 if moving else 0.49) if fatal else 0.12
	_next_drip = 0.25 if moving else 0.94
	get_tree().call_group("city_impact", "drip", source, spread)


func _counter_movement(delta: float) -> Vector3:
	if not is_instance_valid(_opponent) or not _opponent.visible or _counter_timeout <= 0.0:
		return Vector3.ZERO
	_counter_timeout -= delta
	var difference := (_opponent.global_position - global_position).slide(Vector3.UP)
	if difference.length_squared() > 15.0 ** 2:
		_counter_timeout = 0.0
		return Vector3.ZERO
	_swing_lock = maxf(_swing_lock - delta, 0.0)
	if _swing > 0.0:
		_swing -= delta
		if _swing <= 0.0 and difference.length_squared() < 1.82 ** 2 and _clear_counter_path():
			counter_hit.emit(13.0)
	elif difference.length_squared() < 1.4 ** 2 and _swing_lock <= 0.0 and _clear_counter_path():
		_swing = 0.21
		_swing_lock = 0.81
		if _animation != null and _animation.has_animation("punch"):
			_animation.play("punch", 0.12)
			_animation.speed_scale = _animation.get_animation("punch").length / 0.47
	return difference


func _clear_counter_path() -> bool:
	var ray := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, _opponent.global_position + Vector3.UP, 1 | 4)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func _physics_process(delta: float) -> void:
	if downed:
		if _bleed_time > 0.0 or carried:
			_drip_if_needed(delta)
		if _ragdoll.tick(delta, fatal):
			downed = false
			_flee_time = 1.8
		return
	if not is_on_floor():
		velocity.y -= 17.0 * delta
	_flee_time = maxf(_flee_time - delta, 0.0)
	var target := route_b if _moving_to_b else route_a
	var travel := Vector3(target.x - position.x, 0, target.z - position.z)
	if travel.length_squared() < 1.1:
		_moving_to_b = not _moving_to_b
	var fighting := _counter_movement(delta)
	if not fighting.is_zero_approx():
		travel = fighting
	var movement := travel.normalized() * pace * (2.05 if _flee_time > 0.0 or not fighting.is_zero_approx() else 1.0)
	if not fighting.is_zero_approx() and (fighting.length_squared() < 1.25 ** 2 or _swing_lock > 0.4):
		movement = Vector3.ZERO
	velocity.x = move_toward(velocity.x, movement.x, 4.9 * delta)
	velocity.z = move_toward(velocity.z, movement.z, 4.9 * delta)
	if travel.length_squared() > 0.05:
		var facing := atan2(-travel.x, -travel.z)
		rotation.y = lerp_angle(rotation.y, facing, 1.0 - exp(-7.5 * delta))
	if _animation != null and not (_swing_lock > 0.35 and _animation.current_animation == "punch"):
		var fleeing := (_flee_time > 0.0 or not fighting.is_zero_approx()) and _animation.has_animation("run")
		var clip := "idle" if movement.is_zero_approx() and _animation.has_animation("idle") else ("run" if fleeing else "walk")
		if _animation.current_animation != clip:
			_animation.play(clip, 0.19)
		_animation.speed_scale = 1.35 if fleeing else clampf(pace / 1.45, 0.63, 1.3)
	move_and_slide()
