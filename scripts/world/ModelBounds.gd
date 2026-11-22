extends RefCounted


static func measure(root: Node3D) -> AABB:
	var bounds := AABB()
	var inverse := root.global_transform.affine_inverse()
	if root is MeshInstance3D and root.mesh != null:
		bounds = root.get_aabb()
	for mesh: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh == null:
			continue
		var local: AABB = (inverse * mesh.global_transform) * mesh.get_aabb()
		bounds = local if not bounds.has_volume() else bounds.merge(local)
	return bounds


static func fit_to_height(root: Node3D, height: float) -> Vector3:
	var bounds := measure(root)
	if bounds.size.y <= 0.001:
		return Vector3.ZERO
	var factor := height / bounds.size.y
	var center := bounds.get_center()
	root.scale *= factor
	root.position -= root.basis * Vector3(center.x, bounds.position.y, center.z)
	return bounds.size * factor
