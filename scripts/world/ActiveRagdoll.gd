extends RefCounted

const SeveredMesh = preload("res://scripts/world/SeveredMesh.gd")
const STUMBLE_THRESHOLD := 3.8
const FALL_THRESHOLD := 8.8
const GET_UP_TIME := 1.2
const BODY_LAYOUT := [
	# Bone, tip bone, length fraction, radius, mass, swing limit, twist limit
	["hips", "spine", 1.8, 0.135, 16.0, 0.0, 0.0],
	["chest", "neck", 2.0, 0.148, 16.0, 50.0, 35.0],
	["head", "", 1.0, 0.100, 4.8, 57.0, 42.0],
	["upperarm_L", "forearm_L", 0.92, 0.067, 3.0, 105.0, 72.0],
	["forearm_L", "hand_L", 1.08, 0.055, 2.1, 105.0, 32.0],
	["upperarm_R", "forearm_R", 0.92, 0.067, 3.0, 105.0, 72.0],
	["forearm_R", "hand_R", 1.08, 0.055, 2.1, 105.0, 32.0],
	["thigh_L", "calf_L", 0.94, 0.088, 6.5, 80.0, 50.0],
	["calf_L", "foot_L", 0.96, 0.066, 4.0, 110.0, 28.0],
	["foot_L", "toe_L", 1.4, 0.054, 1.1, 49.0, 29.0],
	["thigh_R", "calf_R", 0.94, 0.088, 6.5, 80.0, 50.0],
	["calf_R", "foot_R", 0.96, 0.066, 4.0, 110.0, 28.0],
	["foot_R", "toe_R", 1.4, 0.054, 1.1, 49.0, 29.0]
]

enum Phase { INACTIVE, STUMBLE, FALLEN, GETTING_UP }

class MotorBone extends PhysicalBone3D:
	var target := Transform3D.IDENTITY
	var weight := 0.0
	var hold_position := false
	var angular_gain := 10.0
	var damping_gain := 2.5

	func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
		if weight <= 0.0:
			return
		var current := state.transform.basis.orthonormalized().get_rotation_quaternion()
		var error := (target.basis.get_rotation_quaternion() * current.inverse()).normalized()
		if error.w < 0.0:
			error = -error
		var displacement := Vector3(error.x, error.y, error.z) * 2.0
		var torque := (angular_gain * displacement - damping_gain * state.angular_velocity) * mass
		state.apply_torque(torque.limit_length(mass * 8.0) * weight)
		if hold_position:
			var correction := (target.origin - state.transform.origin) * 28.0 - state.linear_velocity * 7.5
			state.apply_central_force((correction - state.total_gravity * 2.2).limit_length(30.0) * mass * weight)


class RecoveryPose extends SkeletonModifier3D:
	var poses: Dictionary = {}
	var blend := 0.0

	func _process_modification_with_delta(_delta: float) -> void:
		if blend <= 0.0:
			return
		var rig := get_skeleton()
		for bone: int in poses:
			rig.set_bone_global_pose(bone, rig.get_bone_global_pose(bone).interpolate_with(poses[bone], blend))


var phase := Phase.INACTIVE
var _actor: CharacterBody3D
var _skeleton: Skeleton3D
var _animation: AnimationPlayer
var _simulator: PhysicalBoneSimulator3D
var _recovery: RecoveryPose
var _bones: Array[MotorBone] = []
var _brace: Array[Transform3D] = []
var _push := Vector3.ZERO
var _elapsed := 0.0
var _settled := 0.0
var _cut := false


func _init(actor: CharacterBody3D, skeleton: Skeleton3D, animation: AnimationPlayer) -> void:
	_actor = actor
	_skeleton = skeleton
	_animation = animation


func hit(strength: float, direction: Vector3) -> bool:
	if strength < STUMBLE_THRESHOLD or phase == Phase.GETTING_UP:
		return false
	if _simulator == null:
		_make_rig()
	if _bones.is_empty():
		return false
	_push = direction.slide(Vector3.UP).normalized()
	if _push.is_zero_approx():
		_push = -_actor.global_basis.z
	_elapsed = 0.0
	_settled = 0.0
	if phase == Phase.INACTIVE:
		_brace.clear()
		for bone: PhysicalBone3D in _bones:
			var pose := _skeleton.global_transform * _skeleton.get_bone_global_pose(bone.get_bone_id()) * bone.body_offset
			pose.basis = pose.basis.orthonormalized()
			_brace.append(pose)
		_actor.collision_layer = 0
		_actor.collision_mask = 0
		_actor.velocity = Vector3.ZERO
		if _animation != null:
			_animation.pause()
		_simulator.active = true
		_simulator.physical_bones_start_simulation()
		phase = Phase.STUMBLE if strength < FALL_THRESHOLD else Phase.FALLEN
	else:
		phase = Phase.FALLEN
	_simulator.influence = 0.9 if phase == Phase.STUMBLE else 1.0
	var kick := _push * minf(strength * (0.31 if phase == Phase.STUMBLE else 0.48), 12.5)
	kick.y = minf(strength * (0.045 if phase == Phase.STUMBLE else 0.12), 3.2)
	for index in _bones.size():
		var bone := _bones[index]
		bone.target = _brace[index]
		bone.weight = 1.0 if phase == Phase.STUMBLE else 0.0
		bone.apply_central_impulse(kick * bone.mass * (1.1 if index < 2 else 0.9))
	return true


func body_position() -> Vector3:
	return _bones[0].global_position if not _bones.is_empty() and phase == Phase.FALLEN else _actor.global_position


func cut(model: Node3D, at: Vector3, direction: Vector3) -> Node3D:
	if _cut or phase != Phase.FALLEN:
		return null
	var head := _simulator.get_node_or_null("head") as PhysicalBone3D
	var torso := _simulator.get_node_or_null("chest") as PhysicalBone3D
	if head == null or torso == null:
		return null
	var severed := head if at.distance_squared_to(head.global_position) < 0.23 ** 2 else torso
	var remaining := torso if severed == head else _bones[0]
	if not SeveredMesh.apply(model, _skeleton, severed.get_bone_id()):
		return null
	_cut = true
	var joint := severed.global_transform * severed.body_offset.affine_inverse()
	var radius := 0.081 if severed == head else 0.159
	_add_cut_cap(severed, joint.origin, radius)
	var wound := _add_cut_cap(remaining, joint.origin, radius * 1.09)
	severed.joint_type = PhysicalBone3D.JOINT_TYPE_NONE
	var impulse := (direction.normalized() * 2.1 + Vector3.UP * 1.05) * severed.mass
	severed.apply_central_impulse(impulse)
	severed.apply_impulse(impulse * 0.38, Vector3.RIGHT * radius)
	return wound


func _add_cut_cap(bone: PhysicalBone3D, world_point: Vector3, radius: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 1.06
	mesh.radial_segments = 12
	mesh.rings = 4
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color("#630c20")
	wet.roughness = 0.36
	mesh.material = wet
	var cap := MeshInstance3D.new()
	cap.mesh = mesh
	bone.add_child(cap)
	cap.position = bone.to_local(world_point)
	return cap


func body_is_moving() -> bool:
	return not _bones.is_empty() and _bones[0].linear_velocity.length_squared() > 0.75


func carry_toward(at: Vector3) -> void:
	if _bones.is_empty() or phase != Phase.FALLEN:
		return
	var pelvis := _bones[0]
	pelvis.target = Transform3D(pelvis.global_basis.orthonormalized(), at)
	pelvis.hold_position = true
	pelvis.weight = 0.88


func release_body(velocity: Vector3) -> void:
	for bone: MotorBone in _bones:
		bone.hold_position = false
		bone.weight = 0.0
		if not velocity.is_zero_approx():
			bone.apply_central_impulse(velocity * bone.mass)


func tick(delta: float, stay_down := false) -> bool:
	_elapsed += delta
	match phase:
		Phase.STUMBLE:
			_drive_brace()
			var pelvis := _bones[0]
			var deviation := pelvis.global_basis.y.normalized().dot(_brace[0].basis.y)
			if deviation < 0.57 or (pelvis.global_position - _brace[0].origin).y < -0.39:
				phase = Phase.FALLEN
				_elapsed = 0.0
				_simulator.influence = 1.0
				for bone: MotorBone in _bones:
					bone.weight = 0.0
			elif _elapsed > 0.46 and pelvis.linear_velocity.length() < 1.12:
				_begin_recovery(false)
		Phase.FALLEN:
			_settled = _settled + delta if _is_resting() else 0.0
			if not stay_down and _elapsed > 0.75 and _settled > 0.32:
				_begin_recovery(true)
		Phase.GETTING_UP:
			var duration := GET_UP_TIME if _long_recovery else 0.37
			var blend_time := 0.52 if _long_recovery else duration
			_recovery.blend = 1.0 - smoothstep(0.0, blend_time, _elapsed)
			if _elapsed >= duration:
				_recovery.active = false
				_recovery.poses.clear()
				_actor.collision_layer = 8
				_actor.collision_mask = 1
				phase = Phase.INACTIVE
				return true
	return false


var _long_recovery := false


func _drive_brace() -> void:
	var shift := _push * minf(1.0, _elapsed * 1.68)
	var lean_axis := Vector3.UP.cross(_push).normalized()
	var lean := sin(clampf(_elapsed / 0.52, 0.0, 1.0) * PI) * 0.20
	for index in _bones.size():
		var bone := _bones[index]
		var target := _brace[index]
		target.origin += shift
		if index != 2:
			var stride := sin(_elapsed * 17.0 + PI * (index % 2)) * 0.23 if index >= 3 else 0.0
			target.basis = Basis(lean_axis, lean + stride) * target.basis
		bone.target = target


func _is_resting() -> bool:
	var pelvis := _bones[0]
	var torso := _bones[1]
	if pelvis.linear_velocity.length_squared() > 0.50 ** 2 or torso.angular_velocity.length_squared() > 1.23 ** 2:
		return false
	var energy := 0.0
	var mass_total := 0.0
	for bone: MotorBone in _bones:
		energy += bone.mass * bone.linear_velocity.length_squared()
		mass_total += bone.mass
		if _elapsed > 5.0 and bone.angular_damp < 4.6:
			bone.angular_damp = 4.6
	return energy / maxf(mass_total, 1.0) < 0.46 ** 2


func _begin_recovery(full: bool) -> void:
	var pelvis := _bones[0].global_position
	var world := _actor.get_world_3d().direct_space_state
	var hit := world.intersect_ray(PhysicsRayQueryParameters3D.create(pelvis + Vector3.UP * 0.34, pelvis - Vector3.UP * 1.25, 1))
	if hit.is_empty() or hit.normal.y < 0.55:
		return
	var global_poses: Dictionary = {}
	for bone: MotorBone in _bones:
		bone.weight = 0.0
		global_poses[bone.get_bone_id()] = bone.global_transform * bone.body_offset.affine_inverse()
	_simulator.physical_bones_stop_simulation()
	_simulator.active = false
	_actor.global_position = hit.position + Vector3.UP * 0.032
	_actor.reset_physics_interpolation()
	var to_skeleton := _skeleton.global_transform.affine_inverse()
	for id: int in global_poses:
		_recovery.poses[id] = to_skeleton * global_poses[id]
	_recovery.blend = 1.0
	_recovery.active = true
	_long_recovery = full
	_elapsed = 0.0
	phase = Phase.GETTING_UP
	if _animation != null:
		_animation.speed_scale = 1.0
		var clip := "get_up" if full and _animation.has_animation("get_up") else "walk"
		_animation.play(clip, -1.0, _animation.get_animation(clip).length / GET_UP_TIME if clip == "get_up" else 1.0)
		_animation.advance(0.0)


func _make_rig() -> void:
	if _skeleton == null or _skeleton.find_bone("hips") < 0:
		return
	_simulator = PhysicalBoneSimulator3D.new()
	_simulator.name = "ImpactSimulator"
	_simulator.active = false
	_skeleton.add_child(_simulator)
	for spec: Array in BODY_LAYOUT:
		var id := _skeleton.find_bone(spec[0])
		if id < 0:
			continue
		var rest := _skeleton.get_bone_global_rest(id)
		var tip := _skeleton.find_bone(spec[1]) if not str(spec[1]).is_empty() else -1
		var axis := rest.basis.inverse() * Vector3.UP * 0.19
		if tip >= 0:
			axis = rest.affine_inverse() * _skeleton.get_bone_global_rest(tip).origin
		var unit := axis.normalized()
		var helper := Vector3.RIGHT if absf(unit.dot(Vector3.RIGHT)) < 0.85 else Vector3.BACK
		var across := helper.slide(unit).normalized()
		var bone := MotorBone.new()
		bone.name = str(spec[0])
		bone.set("bone_name", StringName(spec[0]))
		bone.mass = spec[4]
		bone.linear_damp = 0.92
		bone.angular_damp = 1.95
		bone.friction = 0.78
		bone.bounce = 0.07
		bone.set_meta("pedestrian_actor", _actor)
		bone.collision_layer = 16
		bone.collision_mask = 1
		bone.hold_position = _bones.is_empty()
		bone.angular_gain = 15.0 if spec[0] == "head" else 10.0
		bone.body_offset = Transform3D(Basis(across, unit, across.cross(unit)), axis * 0.5)
		if not _bones.is_empty():
			bone.joint_type = PhysicalBone3D.JOINT_TYPE_CONE
			bone.set("joint_constraints/swing_span", spec[5])
			bone.set("joint_constraints/twist_span", spec[6])
		var capsule := CapsuleShape3D.new()
		capsule.radius = spec[3]
		capsule.height = maxf(axis.length() * float(spec[2]), capsule.radius * 2.0 + 0.015)
		var collision := CollisionShape3D.new()
		collision.shape = capsule
		bone.add_child(collision)
		_simulator.add_child(bone)
		_bones.append(bone)
	_recovery = RecoveryPose.new()
	_recovery.name = "GetUpBlend"
	_recovery.active = false
	_skeleton.add_child(_recovery)
	if _animation != null:
		_install_get_up()


func _install_get_up() -> void:
	if _animation.has_animation("get_up"):
		return
	var action := Animation.new()
	action.length = GET_UP_TIME
	var walk := _animation.get_animation("walk")
	for track in walk.get_track_count():
		var path := walk.track_get_path(track)
		if path.get_subname_count() == 0:
			continue
		var bone := str(path.get_subname(path.get_subname_count() - 1))
		var id := _skeleton.find_bone(bone)
		if id < 0:
			continue
		var type := walk.track_get_type(track)
		if type == Animation.TYPE_ROTATION_3D:
			var dst := action.add_track(type)
			action.track_set_path(dst, path)
			var base := _skeleton.get_bone_rest(id).basis.get_rotation_quaternion()
			var bend := _get_up_bend(bone)
			action.rotation_track_insert_key(dst, 0.0, base * Quaternion(Vector3.RIGHT, bend * 1.15))
			action.rotation_track_insert_key(dst, 0.47, base * Quaternion(Vector3.RIGHT, bend))
			action.rotation_track_insert_key(dst, GET_UP_TIME, walk.rotation_track_interpolate(track, 0.0))
		elif type == Animation.TYPE_POSITION_3D and bone == "hips":
			var dst := action.add_track(type)
			action.track_set_path(dst, path)
			var base := walk.position_track_interpolate(track, 0.0)
			action.position_track_insert_key(dst, 0.0, base - Vector3.UP * 0.65)
			action.position_track_insert_key(dst, 0.47, base - Vector3.UP * 0.36)
			action.position_track_insert_key(dst, GET_UP_TIME, base)
	_animation.get_animation_library("").add_animation("get_up", action)


func _get_up_bend(bone: String) -> float:
	match bone:
		"hips", "spine", "spine1":
			return 0.23
		"thigh_L", "thigh_R":
			return 0.78
		"calf_L", "calf_R":
			return -1.21
		"upperarm_L", "upperarm_R":
			return 0.39
	return 0.0
