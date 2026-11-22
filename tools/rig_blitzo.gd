extends SceneTree
## Build the playable rig from the supplied FBX using Godot's imported geometry.
## godot --headless --path . --script res://tools/rig_blitzo.gd

const SOURCE := "res://assets/models/supplied/blitzo-character-design/"
const MODEL := SOURCE + "blitzo.fbx"
const OUTPUT := SOURCE + "blitzo_rigged.scn"
const SCALE := 1.85 / 9.86056
const FLOOR_Y := 0.0375
const CENTER_Z := 0.0568
const TEXTURES := {
	"head": "head.png", "glove part": "Glove_Texture.png", "Skull": "Skull.png",
	"Trim": "Boots.png", "longtail": "Longtail.png"
}
const SIDES := [-1, 1]

var _rig := Skeleton3D.new()
var _joints: Dictionary = {}


func _initialize() -> void:
	call_deferred("_bake")


func _bake() -> void:
	if not ResourceLoader.exists(MODEL, "PackedScene"):
		push_error("Import the supplied Blitzo FBX before building its rig.")
		quit(1)
		return
	var source := (load(MODEL) as PackedScene).instantiate() as Node3D
	root.add_child(source)
	var imported := source.find_child("Blitz0", true, false) as MeshInstance3D
	if imported == null:
		push_error("The supplied FBX does not contain the expected Blitz0 mesh.")
		quit(1)
		return
	var actor := Node3D.new()
	actor.name = "Blitzo"
	root.add_child(actor)
	_rig.name = "Skeleton3D"
	actor.add_child(_rig)
	_rig.owner = actor
	_add("root", "", Vector3.ZERO)
	_add("pelvis", "root", _point(Vector3(0, 3.62, CENTER_Z)))
	_add("spine", "pelvis", _point(Vector3(0, 4.58, CENTER_Z)))
	_add("head", "spine", _point(Vector3(0, 6.40, CENTER_Z)))
	_add("tail", "pelvis", _point(Vector3(-0.19, 3.62, CENTER_Z)))
	for side: int in SIDES:
		var suffix := "_L" if side < 0 else "_R"
		_add("upper_arm" + suffix, "spine", _point(Vector3(0, 6.08, CENTER_Z + side * 0.47)))
		_add("forearm" + suffix, "upper_arm" + suffix, _point(Vector3(-0.09, 5.58, CENTER_Z + side * 1.86)))
		_add("hand" + suffix, "forearm" + suffix, _point(Vector3(-0.11, 5.10, CENTER_Z + side * 3.02)))
		_add("thigh" + suffix, "pelvis", _point(Vector3(-0.045, 3.69, CENTER_Z + side * 0.22)))
		_add("calf" + suffix, "thigh" + suffix, _point(Vector3(0.015, 2.17, CENTER_Z + side * 0.27)))
		_add("foot" + suffix, "calf" + suffix, _point(Vector3(-0.10, 0.61, CENTER_Z + side * 0.28)))
	_rig.reset_bone_poses()

	var mesh := ArrayMesh.new()
	for surface in imported.mesh.get_surface_count():
		var material := imported.get_active_material(surface) as StandardMaterial3D
		var arrays := imported.mesh.surface_get_arrays(surface)
		_skin_surface(arrays, imported.global_transform, material.resource_name)
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, _material(material))
	var view := MeshInstance3D.new()
	view.name = "BlitzoMesh"
	view.mesh = mesh
	view.custom_aabb = AABB(Vector3(-1.05, -0.40, -0.75), Vector3(2.10, 2.75, 2.15))
	_rig.add_child(view)
	view.owner = actor
	view.skeleton = NodePath("..")
	view.skin = _rig.create_skin_from_rest_transforms()
	var scene := PackedScene.new()
	var status := scene.pack(actor)
	if status == OK:
		status = ResourceSaver.save(scene, OUTPUT, ResourceSaver.FLAG_COMPRESS)
	print("Blitzo rig: ", error_string(status))
	source.free()
	actor.free()
	quit(status)


func _point(raw: Vector3) -> Vector3:
	return Vector3(raw.z - CENTER_Z, raw.y - FLOOR_Y, -raw.x) * SCALE


func _add(name_on_rig: String, parent: String, global_point: Vector3) -> void:
	var index := _rig.add_bone(name_on_rig)
	var local := global_point
	if not parent.is_empty():
		var parent_joint: Array = _joints[parent]
		_rig.set_bone_parent(index, parent_joint[0])
		local -= parent_joint[1]
	_rig.set_bone_rest(index, Transform3D(Basis.IDENTITY, local))
	_joints[name_on_rig] = [index, global_point]


func _material(original: StandardMaterial3D) -> StandardMaterial3D:
	var result := original.duplicate() as StandardMaterial3D
	var file := str(TEXTURES.get(original.resource_name, ""))
	if not file.is_empty():
		result.albedo_texture = load(SOURCE + file) as Texture2D
		result.albedo_color = Color.WHITE
	result.metallic = 0.0
	result.roughness = 0.88
	result.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	return result


func _skin_surface(arrays: Array, source: Transform3D, part: String) -> void:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	bones.resize(points.size() * 4)
	weights.resize(points.size() * 4)
	var source_normals := source.basis.inverse().transposed()
	for index in points.size():
		var raw := source * points[index]
		var tail := part == "longtail" or (part == "Spikes" and raw.y < 4.35 and raw.x < -0.40)
		var assignment := ["tail", "tail", 0.0] if tail else _weights(raw, part)
		if tail:
			var t := clampf((-raw.x - 0.19) / 9.5, 0.0, 1.0)
			raw.x = lerpf(-0.19, -4.55, t)
			raw.y += 0.82 * sin(t * PI) + 0.62 * t
			raw.z += 0.89 * sin(t * PI * 0.48)
		points[index] = _point(raw)
		var normal := source_normals * normals[index]
		normals[index] = Vector3(normal.z, normal.y, -normal.x).normalized()
		bones[index * 4] = _joints[assignment[0]][0]
		bones[index * 4 + 1] = _joints[assignment[1]][0]
		weights[index * 4] = 1.0 - float(assignment[2])
		weights[index * 4 + 1] = float(assignment[2])
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights


func _weights(p: Vector3, part: String) -> Array:
	var offset := p.z - CENTER_Z
	var side := "_L" if offset < 0.0 else "_R"
	var lateral := absf(offset)
	match part:
		"head", "eyebrow":
			return ["head", "head", 0.0]
		"Spikes":
			return ["spine", "head", smoothstep(6.0, 6.65, p.y)]
		"Pants", "Trim":
			if p.y < 0.88:
				return ["foot" + side, "calf" + side, smoothstep(0.41, 0.88, p.y)]
			if p.y < 2.64:
				return ["calf" + side, "thigh" + side, smoothstep(1.48, 2.64, p.y)]
			return ["thigh" + side, "pelvis", smoothstep(3.22, 3.80, p.y)]
		"glove part", "Material", "skin":
			return ["forearm" + side, "hand" + side, smoothstep(2.63, 3.19, lateral)]
		_:
			if p.y > 4.18 and lateral > 0.43:
				if lateral > 1.27:
					return ["upper_arm" + side, "forearm" + side, smoothstep(1.36, 2.30, lateral)]
				return ["spine", "upper_arm" + side, smoothstep(0.45, 1.07, lateral)]
			if p.y < 3.55 and lateral > 0.19:
				return ["pelvis", "thigh" + side, 0.70 * (1.0 - smoothstep(2.12, 3.55, p.y))]
			return ["pelvis", "spine", smoothstep(3.62, 4.62, p.y)]

