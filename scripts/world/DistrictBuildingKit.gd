extends RefCounted

const MODELS := [
	preload("res://assets/models/buildings/1Story_GableRoof.obj"),
	preload("res://assets/models/buildings/2Story_Balcony.obj"),
	preload("res://assets/models/buildings/3Story_Small.obj")
]


func build(tile: Node3D, row: Array, outline: PackedVector2Array, grade: float, height: float) -> bool:
	if outline.size() != 4 or height < 3.2 or height > 13.0 or not str(row[4]).is_empty():
		return false
	if not row[7].is_empty() or posmod(int(row[0]), 5) != 1:
		return false
	var side := outline[1] - outline[0]
	var alternate := outline[2] - outline[1]
	if absf(side.normalized().dot(alternate.normalized())) > 0.14:
		return false
	var width := maxf(side.length(), alternate.length())
	var depth := minf(side.length(), alternate.length())
	if depth < 3.6 or width < 5.0 or width > depth * 2.45 or width > 30.0:
		return false
	var axis := (side if side.length_squared() >= alternate.length_squared() else alternate).normalized()
	var placement := Basis(Vector3.UP, -axis.angle())
	var center: Vector2 = (outline[0] + outline[2]) * 0.5
	var lot := Node3D.new()
	lot.position = Vector3(center.x, grade - 0.17, center.y)
	lot.basis = placement
	tile.add_child(lot)
	var facade := MeshInstance3D.new()
	var mesh: Mesh = MODELS[0 if height < 5.8 else 1 if height < 9.0 else 2]
	var actual := mesh.get_aabb()
	facade.mesh = mesh
	facade.scale = Vector3(width, height, depth) / actual.size
	facade.position = -Vector3(actual.get_center().x, actual.position.y, actual.get_center().z) * facade.scale
	lot.add_child(facade)
	var building := StaticBody3D.new()
	lot.add_child(building)
	building.add_to_group("city_facade")
	var collider := CollisionShape3D.new()
	var collision := BoxShape3D.new()
	# Leave the upper roof pitch above the collision box for the gable and balcony models.
	collision.size = Vector3(width, height * 0.89, depth)
	collider.shape = collision
	collider.position.y = collision.size.y * 0.5
	building.add_child(collider)
	return true
