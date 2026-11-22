extends StaticBody3D

var lamp_head: Node3D
var _visual: Node3D
var _district: Node3D
var _key: String
var _fallen := false
var _collision: CollisionShape3D
var _lens: MeshInstance3D


func build(district: Node3D, site: Vector2, direction: Vector2, geo: RefCounted, lens: StandardMaterial3D) -> void:
	_district = district
	_key = "%d,%d" % [roundi(site.x * 10.0), roundi(site.y * 10.0)]
	position = district.elevation.point_at(site)
	if district.broken_lamps.has(_key):
		hide()
		return

	_visual = Node3D.new()
	_visual.set_meta("moving_geometry", true)
	add_child(_visual)
	var paint := Color("#69726f")
	geo.taper(_visual, Vector3.UP * 3.22, 6.44, 0.035, 0.085, paint, 8)
	var arm: MeshInstance3D = geo.box(_visual, Vector3(direction.x * 0.52, 6.46, direction.y * 0.52),
		Vector3(1.2, 0.055, 0.065), paint)
	arm.rotation.y = -direction.angle()
	lamp_head = geo.box(_visual, Vector3(direction.x * 1.08, 6.41, direction.y * 1.08),
		Vector3(0.48, 0.115, 0.25), Color("#b1a48c"))
	lamp_head.rotation.y = arm.rotation.y
	_lens = geo.box(_visual, lamp_head.position - Vector3.UP * 0.065, Vector3(0.41, 0.027, 0.20), Color("#b7af98"))
	_lens.rotation.y = arm.rotation.y
	_lens.material_override = lens
	add_to_group("working_streetlight")
	_collision = CollisionShape3D.new()
	_collision.position.y = 3.21
	_collision.shape = _pole_shape()
	add_child(_collision)


func receive_vehicle_hit(strength: float, travel: Vector3) -> bool:
	if _fallen or strength < 4.7 or _collision == null:
		return false
	_fallen = true
	_lens.hide()
	_district.broken_lamps[_key] = true
	remove_from_group("working_streetlight")
	_collision.set_deferred("disabled", true)
	var loose := RigidBody3D.new()
	loose.mass = 42.0
	loose.angular_damp = 0.58
	loose.collision_layer = 32
	loose.collision_mask = 1 | 4
	loose.continuous_cd = true
	add_child(loose)
	loose.global_position = global_position + Vector3.UP * 3.24 + travel * 0.15
	_visual.reparent(loose, true)
	var collider := CollisionShape3D.new()
	collider.shape = _pole_shape()
	loose.add_child(collider)
	loose.linear_velocity = travel * minf(strength * 0.28, 5.2) + Vector3.UP * 0.55
	loose.angular_velocity = Vector3.UP.cross(travel).normalized() * clampf(strength * 0.25, 1.2, 5.0)
	return true


func _pole_shape() -> Shape3D:
	var shape := CylinderShape3D.new()
	shape.height = 6.42
	shape.radius = 0.097
	return shape
