extends RefCounted

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _colors := PackedColorArray()


func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	triangle(a, b, c, tint)
	triangle(a, c, d, tint)


func facade(a: Vector3, b: Vector3, height: float, tint: Color) -> void:
	var c := b + Vector3.UP * height
	var d := a + Vector3.UP * height
	wall(a, b, c, d, tint)


func wall(a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	var length := a.distance_to(b)
	var height := maxf(c.y - b.y, d.y - a.y)
	var lower_a := Vector2(0, height - (d.y - a.y))
	var lower_b := Vector2(length, height - (c.y - b.y))
	_add(a, b, c, lower_a, lower_b, Vector2(length, height), tint)
	_add(a, c, d, lower_a, Vector2(length, height), Vector2(0, height), tint)


func triangle(a: Vector3, b: Vector3, c: Vector3, tint: Color) -> void:
	_add(a, b, c, Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z), tint)


func flat_polygon(outline: PackedVector2Array, height: float, tint: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		var a := outline[indices[index]]
		var b := outline[indices[index + 1]]
		var c := outline[indices[index + 2]]
		triangle(Vector3(a.x, height, a.y), Vector3(b.x, height, b.y), Vector3(c.x, height, c.y), tint)


func strip(a: Vector2, b: Vector2, width: float, y: float, tint: Color) -> void:
	var side := a.direction_to(b).orthogonal() * width * 0.5
	var p := a - side
	var q := b - side
	var r := b + side
	var s := a + side
	quad(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), Vector3(r.x, y, r.y), Vector3(s.x, y, s.y), tint)


func disc(center: Vector2, radius: float, y: float, tint: Color, sides := 9) -> void:
	var base := Vector3(center.x, y, center.y)
	for index in sides:
		var a := center + Vector2.from_angle(index * TAU / sides) * radius
		var b := center + Vector2.from_angle((index + 1) * TAU / sides) * radius
		triangle(base, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), tint)


func make_node(parent: Node3D, material: Material, solid := false, shadows := true) -> MeshInstance3D:
	if _vertices.is_empty():
		return null
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		node.add_child(body)
	return node


func _add(a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, tint: Color) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.length_squared() < 0.5:
		return
	_vertices.append_array(PackedVector3Array([a, b, c]))
	_normals.append_array(PackedVector3Array([normal, normal, normal]))
	_uvs.append_array(PackedVector2Array([uv_a, uv_b, uv_c]))
	_colors.append_array(PackedColorArray([tint, tint, tint]))
