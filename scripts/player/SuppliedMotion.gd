extends RefCounted

const HENRY := {
	"thigh_L": "Base HumanLLeg1", "thigh_R": "Base HumanRLeg1",
	"calf_L": "Base HumanLLeg2", "calf_R": "Base HumanRLeg2",
	"foot_L": "Base HumanLLegAnkle", "foot_R": "Base HumanRLegAnkle",
	"upper_arm_L": "Base HumanLUpperarm", "upper_arm_R": "Base HumanRArmUpperarm",
	"forearm_L": "Base HumanLForearm", "forearm_R": "Base HumanRArmForearm",
	"hand_L": "Base HumanLPalm", "hand_R": "Base HumanRArmPalm"
}
const INK = preload("res://assets/shaders/henry_ink.gdshader")
const FACE_MASK := "res://assets/models/supplied/henry-stickmin/03 - Default_Opacity.png"
const JOINTS := ["thigh_L", "thigh_R", "calf_L", "calf_R", "foot_L", "foot_R",
	"upper_arm_L", "upper_arm_R", "forearm_L", "forearm_R", "hand_L", "hand_R", "tail"]

var _joints: Dictionary = {}
var _model: Node3D
var _skeleton: Skeleton3D
var _floor_y := 0.0
var _phase := 0.0
var _stride := 0.0
var _forward := Vector3.FORWARD


func _init(model: Node3D, skeleton: Skeleton3D) -> void:
	_model = model
	_skeleton = skeleton
	_floor_y = model.position.y
	if skeleton == null:
		return
	var henry := skeleton.find_bone("Base HumanPelvis") >= 0
	for part: String in JOINTS:
		var index := skeleton.find_bone(str(HENRY.get(part, part)) if henry else part)
		if index >= 0:
			_joints[part] = [index, skeleton.get_bone_global_pose(index)]
	if henry:
		_forward = Vector3.BACK
		_restore_henry_materials()
		for side: String in ["_L", "_R"]:
			_balance_henry_leg(side)
	else:
		for side: String in ["_L", "_R"]:
			_lower_arm(side)
	for part: String in _joints:
		var info: Array = _joints[part]
		var index: int = info[0]
		var neutral := skeleton.get_bone_pose_rotation(index)
		var basis := skeleton.get_bone_global_pose(index).basis.orthonormalized()
		_joints[part] = [index, neutral, basis.inverse() * Vector3.RIGHT,
			basis.inverse() * Vector3.UP]


func _restore_henry_materials() -> void:
	for mesh: MeshInstance3D in _model.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_active_material(0)
		if material == null:
			continue
		match material.resource_name:
			"02 - Default", "Solid Glass":
				mesh.hide()
			"03 - Default":
				if ResourceLoader.exists(FACE_MASK, "Texture2D"):
					var ink := ShaderMaterial.new()
					ink.shader = INK
					ink.set_shader_parameter("ink_mask", load(FACE_MASK))
					mesh.set_surface_override_material(0, ink)
				else:
					mesh.hide()


func _balance_henry_leg(side: String) -> void:
	var hip := _original("thigh" + side).origin
	var knee := _original("calf" + side).origin
	var ankle := _original("foot" + side).origin
	var upper_length := hip.distance_to(knee)
	var lower_length := knee.distance_to(ankle)
	var laid_ankle := Vector3(0.055 if side == "_L" else -0.055, 0.030 if side == "_L" else 0.050, 0.045)
	var hip_to_ankle := hip.direction_to(laid_ankle)
	var distance := minf(hip.distance_to(laid_ankle), upper_length + lower_length - 0.0003)
	var ahead := _forward.slide(hip_to_ankle).normalized()
	var projection := (upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * distance)
	var bend := sqrt(maxf(0.0, upper_length * upper_length - projection * projection))
	var laid_knee := hip + hip_to_ankle * projection + ahead * bend
	_align("thigh" + side, hip.direction_to(knee), hip.direction_to(laid_knee))
	_align("calf" + side, knee.direction_to(ankle), laid_knee.direction_to(laid_ankle))
	var foot_basis := _original("foot" + side).basis.orthonormalized()
	# Remove the crossing step from the left shoe while keeping its own bind orientation.
	if side == "_L":
		foot_basis = Basis(Vector3.RIGHT, 0.30) * foot_basis
	_set_global_rotation("foot" + side, foot_basis)


func _lower_arm(side: String) -> void:
	var upper := _original("upper_arm" + side).origin
	var elbow := _original("forearm" + side).origin
	var wrist := _original("hand" + side).origin
	var outward := -1.0 if side == "_L" else 1.0
	_align("upper_arm" + side, upper.direction_to(elbow), Vector3(outward * 0.26, -1.0, 0.08).normalized())
	_align("forearm" + side, elbow.direction_to(wrist), Vector3(outward * 0.18, -1.0, -0.20).normalized())


func _original(part: String) -> Transform3D:
	return _joints[part][1]


func _align(part: String, original_direction: Vector3, target: Vector3) -> void:
	var original := _original(part).basis.orthonormalized()
	_set_global_rotation(part, Basis(Quaternion(original_direction, target)) * original)


func _set_global_rotation(part: String, basis: Basis) -> void:
	var index: int = _joints[part][0]
	var parent := _skeleton.get_bone_parent(index)
	var parent_basis := _skeleton.get_bone_global_pose(parent).basis.orthonormalized()
	_skeleton.set_bone_pose_rotation(index, (parent_basis.inverse() * basis).get_rotation_quaternion())
	_skeleton.force_update_all_bone_transforms()


func update(delta: float, speed: float, airborne: bool, action: String, swimming: bool) -> void:
	_stride = move_toward(_stride, clampf(speed / 5.2, 0.0, 1.0), delta * 5.0)
	_phase = fposmod(_phase + delta * (4.9 + speed * 0.92), TAU)
	var step := sin(_phase)
	_model.position.y = _floor_y + absf(step) * _stride * 0.024
	var grabbing := action == "grab_cash"
	var pitch := -0.36 if swimming else (0.16 if grabbing else (0.08 if airborne else -0.06 * _stride))
	_model.rotation.x = lerpf(_model.rotation.x, pitch, 1.0 - exp(-delta * 10.0))
	_model.rotation.z = step * _stride * 0.025
	var forward_angle := -_forward.z
	var holds_to_face := action in ["consume", "drink", "eat"]
	var points_hand := holds_to_face or action in ["punch", "fire", "rifle_fire", "throw_item", "grab_cash"]
	if action == "hit_react":
		_model.rotation.x = lerpf(_model.rotation.x, 0.18, 1.0 - exp(-delta * 12.0))
	_pose("head", -0.22 if action == "drink" else (0.11 if action == "eat" else 0.0), 0.0, delta)
	for side: String in ["_L", "_R"]:
		var cycle := _phase + (PI if side == "_L" else 0.0)
		var swing := sin(cycle) * _stride
		var lift := maxf(0.0, cos(cycle)) * _stride
		var thigh := 0.37 * swing if not airborne else 0.23
		var calf := -0.46 * lift if not airborne else -0.37
		_pose("thigh" + side, thigh * forward_angle, 0.0, delta)
		_pose("calf" + side, calf * forward_angle, 0.0, delta)
		_pose("foot" + side, (-0.68 * thigh - 0.75 * calf) * forward_angle, 0.0, delta)
		_pose("upper_arm" + side, (-0.38 * swing + (0.89 if points_hand and side == "_R" else 0.0)) * forward_angle, 0.0, delta)
		var hand_lift := 0.0
		if side == "_R":
			hand_lift = (1.27 if action == "drink" else 1.06) if holds_to_face else (0.43 if grabbing else 0.0)
		_pose("forearm" + side, ((0.14 if swimming else 0.0) + 0.24 * lift + hand_lift) * forward_angle, 0.0, delta)
	_pose("tail", -0.055 * absf(step), 0.17 * step * (0.3 + _stride), delta)


func seat(steer: float, delta: float) -> void:
	var direction := -_forward.z
	_model.rotation.x = lerpf(_model.rotation.x, -0.05, minf(delta * 10.0, 1.0))
	_model.rotation.z = lerpf(_model.rotation.z, -0.09 * steer, minf(delta * 9.0, 1.0))
	for side: String in ["_L", "_R"]:
		var sign_side := -1.0 if side == "_L" else 1.0
		_pose("thigh" + side, 1.28 * direction, 0.0, delta)
		_pose("calf" + side, -1.49 * direction, 0.0, delta)
		_pose("foot" + side, 0.19 * direction, 0.0, delta)
		_pose("upper_arm" + side, (0.72 + steer * 0.31 * sign_side) * direction, -sign_side * 0.08, delta)
		_pose("forearm" + side, 0.67 * direction, 0.0, delta)


func _pose(part: String, angle: float, turn: float, delta: float) -> void:
	if not _joints.has(part):
		return
	var data: Array = _joints[part]
	var target: Quaternion = data[1] * Quaternion(data[2], angle) * Quaternion(data[3], turn)
	_skeleton.set_bone_pose_rotation(data[0],
		_skeleton.get_bone_pose_rotation(data[0]).slerp(target, 1.0 - exp(-delta * 17.0)))

