extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")

var _doors: Array[AnimatableBody3D] = []
var _origin: Array[float] = []
var _width := 0.0
var _active := false
var _door_motion: Tween


func build(width: float, height: float, tint: Color) -> void:
	_width = width
	var pane := StandardMaterial3D.new()
	pane.albedo_color = tint
	pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pane.roughness = 0.34
	var geo := Geometry.new()
	for direction: float in [-1.0, 1.0]:
		var leaf := AnimatableBody3D.new()
		var leaf_width := width * 0.5
		leaf.position.x = leaf_width * 0.5 * direction
		add_child(leaf)
		_doors.append(leaf)
		_origin.append(leaf.position.x)
		var glass := geo.box(leaf, Vector3(0, height * 0.5, 0), Vector3(leaf_width - 0.063, height - 0.092, 0.035), tint)
		glass.material_override = pane
		for edge: float in [-1.0, 1.0]:
			geo.box(leaf, Vector3(edge * (leaf_width * 0.5 - 0.025), height * 0.5, 0.0), Vector3(0.05, height, 0.076), Color("#d0d4d0"))
		geo.box(leaf, Vector3(0, height * 0.42, 0), Vector3(leaf_width, 0.086, 0.08), Color("#babfba"))
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(leaf_width - 0.015, height, 0.078)
		collision.shape = shape
		collision.position.y = height * 0.5
		leaf.add_child(collision)


func build_approach(elevation: RefCounted, depth: float, lip := 0.12) -> void:
	var end := to_global(Vector3(0, 0, depth))
	var start := to_global(Vector3(0, 0, lip))
	var pavement_height: float = elevation.height_at(Vector2(end.x, end.z))
	end.y = pavement_height - 0.055
	var travel := end - start
	var ramp := Geometry.new().box(self, to_local(start.lerp(end, 0.5)) - Vector3.UP * 0.085,
		Vector3(_width + 0.5, 0.19, travel.length()), Color("#999b94"), true)
	ramp.rotation.x = atan2(start.y - end.y, depth - lip)


func update_proximity(foot: Vector3, driving: bool) -> void:
	var p := to_local(foot)
	var should_open := absf(p.x) < _width * 0.75 + 0.30 and absf(p.z) < 2.8 and absf(p.y) < 1.9 and not driving
	if should_open == _active:
		return
	_active = should_open
	if _door_motion != null:
		_door_motion.kill()
	_door_motion = create_tween().set_parallel().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_trans(Tween.TRANS_SINE)
	for index in _doors.size():
		var offset := _width * 0.50 * signf(_origin[index]) if _active else 0.0
		_door_motion.tween_property(_doors[index], "position:x", _origin[index] + offset, 0.44)
