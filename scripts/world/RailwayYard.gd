extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const Elevation = preload("res://scripts/world/CityElevation.gd")
const TRACK_START := Vector2(-93.6, -973.4)
const TRACK_END := Vector2(409.2, -670.5)
const METAL := Color("#393b39")
const RUST := Color("#6e4937")
const TANK_PAINT := [Color("#ab9a71"), Color("#b4a381"), Color("#718579"), Color("#9f8e67")]

var _geo := Geometry.new()
var _elevation: Elevation


func build(elevation: Elevation) -> void:
	_elevation = elevation
	var direction := TRACK_START.direction_to(TRACK_END)
	for index in 13:
		var point := TRACK_START + direction * (181.0 + index * 15.5)
		_add_tanker(point, direction, TANK_PAINT[index % TANK_PAINT.size()], index + 1)
	_build_boundary(Vector2(132.0, -801.1), Vector2(236.0, -745.2), false)
	_build_boundary(Vector2(240.0, -741.9), Vector2(353.0, -681.7), true)
	_add_light_tower(Vector2(259.0, -739.8))
	_add_light_tower(Vector2(433.0, -648.1))
	_geo.batch_static(self)


func _add_tanker(point: Vector2, direction: Vector2, paint: Color, wagon_number: int) -> void:
	var car := Node3D.new()
	car.name = "ParkedTankWagon%02d" % wagon_number
	car.position = _elevation.point_at(point, 0.08)
	car.rotation.y = atan2(direction.x, direction.y)
	add_child(car)
	_geo.box(car, Vector3(0, 0.87, 0), Vector3(2.63, 0.34, 14.72), METAL)
	var tank := _geo.taper(car, Vector3(0, 2.19, 0), 11.64, 1.32, 1.32, paint, 20)
	tank.rotation.x = PI * 0.5
	# A single collider keeps the tank and frame solid without colliding each wheel.
	var hull := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 1.28
	capsule.height = 14.05
	shape.shape = capsule
	shape.rotation.x = PI * 0.5
	shape.position.y = 2.19
	hull.add_child(shape)
	car.add_child(hull)
	for side: float in [-1.0, 1.0]:
		var dome := MeshInstance3D.new()
		var oval := SphereMesh.new()
		oval.radius = 1.32
		oval.height = 2.64
		oval.radial_segments = 20
		oval.rings = 7
		dome.mesh = oval
		dome.material_override = _geo.material(paint.darkened(0.06))
		dome.position = Vector3(0, 2.19, side * 5.80)
		dome.scale.z = 0.59
		car.add_child(dome)
		var band := _geo.taper(car, Vector3(0, 2.19, side * 4.5), 0.18, 1.332, 1.332, RUST, 20)
		band.rotation.x = PI * 0.5
		_geo.box(car, Vector3(0, 0.77, side * 7.38), Vector3(0.45, 0.18, 0.63), RUST)
		for axle: float in [4.55, 5.93]:
			var wheel := _geo.taper(car, Vector3(0, 0.43, side * axle), 1.80, 0.41, 0.41, METAL, 14)
			wheel.rotation.z = PI * 0.5
		_geo.box(car, Vector3(side * 1.341, 2.26, -2.2), Vector3(0.043, 0.42, 2.25), Color("#b9a57b"))
		for z: float in [-3.5, 0.9, 2.6, 5.05]:
			_geo.box(car, Vector3(side * 1.275, 1.89, z), Vector3(0.035, 0.27, 0.79), paint.darkened(0.19))
	_geo.taper(car, Vector3(0, 3.63, -0.75), 0.22, 0.37, 0.41, METAL, 12)
	for index in 7:
		_geo.box(car, Vector3(1.31, 1.03 + index * 0.31, -0.74), Vector3(0.18, 0.045, 0.55), METAL)


func _build_boundary(first: Vector2, last: Vector2, wall: bool) -> void:
	var count := ceili(first.distance_to(last) / 3.2)
	var height := 2.86 if wall else 1.45
	var frame := Color("#768183") if wall else Color("#3d5450")
	for index in count:
		var a := _elevation.point_at(first.lerp(last, float(index) / count))
		var b := _elevation.point_at(first.lerp(last, (index + 1.0) / count))
		var span := a.distance_to(b)
		var panel := Node3D.new()
		panel.position = a.lerp(b, 0.5)
		add_child(panel)
		panel.look_at(b)
		_geo.box(panel, Vector3(0, height * 0.5, -span * 0.5), Vector3(0.14, height, 0.138), frame)
		if wall:
			_geo.box(panel, Vector3(0, 1.43, 0), Vector3(0.16, 2.86, span), Color("#96968b"), true)
			_geo.box(panel, Vector3(0.031, 0.81, 0), Vector3(0.161, 0.46, span - 0.045), Color("#786452"))
			_geo.box(panel, Vector3(0.031, 0.38, 0), Vector3(0.161, 0.32, span - 0.045), Color("#56585a"))
		else:
			for level: float in [0.21, 0.61, 1.01, 1.42]:
				_geo.box(panel, Vector3(0, level, 0), Vector3(0.031, 0.026, span), frame)
			for bar in 18:
				_geo.box(panel, Vector3(0, 0.81, span * (bar / 18.0 - 0.5)),
					Vector3(0.016, 1.23, 0.019), frame)


func _add_light_tower(point: Vector2) -> void:
	var at := _elevation.point_at(point)
	var frame := Color("#7f5b50")
	for x: float in [-0.35, 0.35]:
		for z: float in [-0.35, 0.35]:
			_geo.box(self, at + Vector3(x, 7.5, z), Vector3(0.078, 15.0, 0.078), frame)
	for floor_index in 8:
		var y := 0.55 + floor_index * 1.80
		for side: float in [-1.0, 1.0]:
			var brace := _geo.box(self, at + Vector3(0, y, side * 0.35), Vector3(0.072, 1.93, 0.072), frame)
			brace.rotation.z = side * 0.38
			_geo.box(self, at + Vector3(0, y + 0.52, side * 0.35), Vector3(0.72, 0.070, 0.075), frame)
	_geo.box(self, at + Vector3.UP * 15.02, Vector3(1.67, 0.18, 1.43), METAL)
	for side: float in [-1.0, 1.0]:
		_geo.box(self, at + Vector3(side * 0.55, 15.29, 0.10), Vector3(0.57, 0.28, 0.36), Color("#dee0d3"))

