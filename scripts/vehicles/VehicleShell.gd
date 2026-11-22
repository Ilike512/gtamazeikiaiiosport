extends RefCounted

static var _parts: Dictionary = {}


static func divide(body: MeshInstance3D, relative: Transform3D, hinge: Vector3, width: float, height: float, key: String) -> Array:
	if _parts.has(key):
		return _parts[key]
	var outside := ArrayMesh.new()
	var door := ArrayMesh.new()
	var edges := [
		Plane(Vector3.LEFT, width * 0.62),
		Plane(Vector3.BACK, hinge.z),
		Plane(Vector3.FORWARD, -hinge.z - 1.24),
		Plane(Vector3.UP, -0.21),
		Plane(Vector3.DOWN, -height)
	]
	var normal_basis := relative.basis.inverse().transposed()
	for surface in body.mesh.get_surface_count():
		var source := body.mesh.surface_get_arrays(surface)
		var material := body.get_active_material(surface)
		var points: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = source[Mesh.ARRAY_INDEX]
		var outside_tool := SurfaceTool.new()
		outside_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		outside_tool.set_material(material)
		var door_tool := SurfaceTool.new()
		door_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		door_tool.set_material(material)
		var count := indices.size() if not indices.is_empty() else points.size()
		var door_vertices := 0
		var shell_vertices := 0
		for index in range(0, count - 2, 3):
			var poly: Array[Vector3] = []
			var map: Array[Vector3] = []
			for corner in 3:
				var vertex := indices[index + corner] if not indices.is_empty() else index + corner
				poly.append(relative * points[vertex])
				map.append((normal_basis * normals[vertex]).normalized())
			var partition := _partition(poly, map, edges)
			for fragment: Array in partition[0]:
				shell_vertices += _triangulate(outside_tool, fragment, Vector3.ZERO)
			door_vertices += _triangulate(door_tool, partition[1], hinge)
		if shell_vertices > 0:
			outside_tool.index()
			outside_tool.commit(outside)
		if door_vertices > 0:
			door_tool.index()
			door_tool.commit(door)
	_parts[key] = [outside, door]
	return _parts[key]


static func _partition(points: Array[Vector3], normals: Array[Vector3], edges: Array) -> Array:
	var inside: Array = []
	for index in points.size():
		inside.append([points[index], normals[index]])
	var exterior: Array = []
	for edge: Plane in edges:
		var positive: Array = []
		var negative: Array = []
		for index in inside.size():
			var a: Array = inside[index]
			var b: Array = inside[(index + 1) % inside.size()]
			var da := edge.distance_to(a[0])
			var db := edge.distance_to(b[0])
			if (da < 0.0) != (db < 0.0):
				var t := da / (da - db)
				var intersection := [
					(a[0] as Vector3).lerp(b[0], t),
					(a[1] as Vector3).lerp(b[1], t).normalized()
				]
				if da >= 0.0:
					positive.append(a)
				else:
					negative.append(a)
				positive.append(intersection)
				negative.append(intersection)
			elif da >= 0.0:
				positive.append(a)
			else:
				negative.append(a)
		if negative.size() >= 3:
			exterior.append(negative)
		inside = positive
		if inside.size() < 3:
			return [exterior, []]
	return [exterior, inside]


static func _triangulate(target: SurfaceTool, corners: Array, origin: Vector3) -> int:
	for index in range(1, corners.size() - 1):
		for vertex: Array in [corners[0], corners[index], corners[index + 1]]:
			target.set_normal(vertex[1])
			target.add_vertex(vertex[0] - origin)
	return maxi(0, (corners.size() - 2) * 3)
