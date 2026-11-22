extends StaticBody3D

var _district: Node3D
var _stamp := ""
var _height := 0.0
var _collider: CollisionShape3D
var _broken := false
var _lamps: Array[MeshInstance3D] = []
var _sequence := 0.0


func build(district: Node3D, at: Vector3, yaw: float, height: float, kind: String) -> Node3D:
	_district = district
	_height = height
	position = at
	rotation.y = yaw
	_stamp = "%s_%d_%d" % [kind, roundi(at.x * 10.0), roundi(at.z * 10.0)]
	_broken = district.broken_lamps.has(_stamp)
	if _broken:
		hide()
		return null
	var pole := CylinderShape3D.new()
	pole.radius = 0.09
	pole.height = height
	_collider = CollisionShape3D.new()
	_collider.shape = pole
	_collider.position.y = height * 0.5
	add_child(_collider)
	var visual := Node3D.new()
	visual.name = "FixtureGeometry"
	visual.set_meta("moving_geometry", true)
	add_child(visual)
	return visual


func cycle_lamps(lamps: Array[MeshInstance3D], phase_offset: float) -> void:
	_lamps = lamps
	_sequence = phase_offset
	_update_lamps()
	var timer := Timer.new()
	timer.wait_time = 0.35
	timer.timeout.connect(_update_lamps)
	add_child(timer)
	timer.start()


func _update_lamps() -> void:
	var phase := fposmod(Time.get_ticks_msec() * 0.001 + _sequence, 20.0)
	for index in _lamps.size():
		_lamps[index].visible = not _broken and index == (0 if phase >= 9.0 else (1 if phase >= 7.5 else 2))


func receive_vehicle_hit(strength: float, travel: Vector3) -> bool:
	if _broken or strength < 3.1 or _collider == null:
		return false
	_broken = true
	_district.broken_lamps[_stamp] = true
	_update_lamps()
	_collider.set_deferred("disabled", true)
	var loose := RigidBody3D.new()
	loose.mass = 14.0
	loose.collision_layer = 32
	loose.collision_mask = 1
	loose.continuous_cd = true
	add_child(loose)
	loose.position.y = _height * 0.5
	$FixtureGeometry.reparent(loose, true)
	var pole := CollisionShape3D.new()
	pole.shape = _collider.shape
	loose.add_child(pole)
	loose.linear_velocity = travel.normalized() * minf(4.4, strength * 0.38) + Vector3.UP * 0.48
	loose.angular_velocity = Vector3.UP.cross(travel).normalized() * 3.4
	return true

