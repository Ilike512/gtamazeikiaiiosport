extends RefCounted

var _materials: Dictionary = {}
var _meshes: Dictionary = {}


func material(tint: Color) -> StandardMaterial3D:
	if not _materials.has(tint):
		var result := StandardMaterial3D.new()
		result.albedo_color = tint
		result.roughness = 0.9
		if tint.a < 0.99:
			result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_materials[tint] = result
	return _materials[tint]


func box(parent: Node3D, position: Vector3, size: Vector3, tint: Color, solid := false) -> MeshInstance3D:
	if not _meshes.has(size):
		var model := BoxMesh.new()
		model.size = size
		_meshes[size] = model
	var mesh := MeshInstance3D.new()
	mesh.mesh = _meshes[size]
	mesh.material_override = material(tint)
	mesh.position = position
	parent.add_child(mesh)
	if solid:
		var body := StaticBody3D.new()
		mesh.add_child(body)
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return mesh


func batch_static(parent: Node3D) -> void:
	var groups: Dictionary = {}
	for mesh: MeshInstance3D in parent.find_children("*", "MeshInstance3D", true, false):
		if mesh.is_queued_for_deletion() or mesh.mesh == null or mesh.material_override == null or mesh.get_child_count() > 0:
			continue
		if mesh.get_parent() is AnimatableBody3D or mesh.get_parent().has_meta("moving_geometry"):
			continue
		var at := mesh.global_position
		var key := "%d:%d:%d:%d" % [
			floori(at.x / 48.0), floori(at.z / 48.0),
			mesh.mesh.get_instance_id(), mesh.material_override.get_instance_id()
		]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(mesh)
	var to_local := parent.global_transform.affine_inverse()
	for group: Array in groups.values():
		if group.size() < 4:
			continue
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = group[0].mesh
		instances.instance_count = group.size()
		var batch := MultiMeshInstance3D.new()
		batch.material_override = group[0].material_override
		for index in group.size():
			instances.set_instance_transform(index, to_local * group[index].global_transform)
			group[index].queue_free()
		batch.multimesh = instances
		parent.add_child(batch)


func taper(parent: Node3D, position: Vector3, height: float, top: float, bottom: float, tint: Color, sides := 7) -> MeshInstance3D:
	var model := CylinderMesh.new()
	model.height = height
	model.top_radius = top
	model.bottom_radius = bottom
	model.radial_segments = sides
	model.rings = 1
	var mesh := MeshInstance3D.new()
	mesh.mesh = model
	mesh.material_override = material(tint)
	mesh.position = position
	parent.add_child(mesh)
	return mesh


func signage(parent: Node3D, position: Vector3, text: String, text_size: int, tint: Color, angle := 0.0) -> Label3D:
	var label := Label3D.new()
	label.position = position
	label.rotation.y = angle
	label.text = text
	label.font_size = text_size
	label.pixel_size = 0.016
	label.modulate = tint
	label.outline_size = 0
	label.no_depth_test = false
	parent.add_child(label)
	return label
