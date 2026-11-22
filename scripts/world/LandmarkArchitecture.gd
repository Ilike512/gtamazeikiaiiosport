extends RefCounted

const Geometry = preload("res://scripts/world/Geometry.gd")
const CityMesh = preload("res://scripts/world/CityMesh.gd")
const Elevation = preload("res://scripts/world/CityElevation.gd")
const StoreSites = preload("res://scripts/world/StoreSites.gd")
const FRANCIS := 341370181
const SACRED_HEART := 202668890
const CULTURE := 265251170
const EIFELIS := 252630160
const IKI := 204411452
const MUSEUM := 202668883
const LIBRARY := 243571634
const SWIFT_ARENA := 1285859170
const GLASS := Color("#536d72")
const FRAME := Color("#405458")

var _geo := Geometry.new()


func build(tile: Node3D, row: Array, elevation: Elevation, material: Material) -> bool:
	var id := int(row[0])
	var school: Dictionary = row[7]
	if not school.is_empty() and id != MUSEUM:
		_build_school(tile, row, school, elevation, material)
		return true
	if id not in [FRANCIS, SACRED_HEART, CULTURE, EIFELIS, IKI, MUSEUM, LIBRARY, SWIFT_ARENA]:
		return false
	var building := Node3D.new()
	building.name = "Landmark_%d" % id
	tile.add_child(building)
	var shape: PackedVector2Array = row[3]
	var center: Vector2 = row[6]
	var ground := elevation.height_at(center)
	match id:
		FRANCIS:
			_shell(building, shape, elevation, ground + 8.5, Color("#bfad83"), material)
			_francis_roof(building, shape, center, ground + 8.5, elevation, material)
			_glazing(building, shape, elevation, 4.3, 0.56, 3.2, 3.6)
			_francis_steps(building, elevation)
			_francis_plaza(building, elevation, material)
		SACRED_HEART:
			_shell(building, shape, elevation, ground + 9.0, Color("#9a5943"), material)
			_glazing(building, shape, elevation, 3.6, 0.91, 4.5, 4.4)
			_old_church(building, ground)
		CULTURE:
			_shell(building, shape, elevation, ground + 8.35, Color("#b5a99b"), material)
			_glazing(building, shape, elevation, 3.1, 1.18, 5.8, 2.22)
			_culture(building, elevation, ground)
		EIFELIS:
			_shell(building, shape, elevation, ground + 6.8, Color("#879696"), material, StoreSites.BURGER)
			_eifelis(building, elevation)
		IKI:
			_shell(building, shape, elevation, ground + 6.6, Color("#788582"), material)
			_iki(building, elevation)
		MUSEUM:
			_shell(building, shape, elevation, ground + 8.5, Color("#dedbd0"), material)
			_glazing(building, shape, elevation, 2.42, 0.79, 3.0, 2.20)
			_museum(building, elevation)
			if not school.is_empty():
				var music_school := _anchor(building, Vector2(875.7, -1092.2), elevation, -1.98)
				_geo.signage(music_school, Vector3(0, 2.55, 0.2), "VYTAUTO KLOVOS MUZIKOS MOKYKLA", 18, Color("#495c53"))
		LIBRARY:
			_shell(building, shape, elevation, ground + 9.5, Color("#d9d6cd"), material)
			_library(building, shape, elevation)
		SWIFT_ARENA:
			_shell(building, shape, elevation, ground + 10.2, Color("#41484e"), material)
			_swift_arena(building, shape, elevation)
	_geo.batch_static(building)
	return true


func _build_school(tile: Node3D, row: Array, school: Dictionary, elevation: Elevation, material: Material) -> void:
	var building := Node3D.new()
	building.name = "School_%d" % int(row[0])
	tile.add_child(building)
	var shape: PackedVector2Array = row[3]
	var main_building := int(row[0]) == int(school.main)
	var floors := int(school.floors) if main_building else clampi(floori(float(row[1]) / 3.0), 1, 2)
	var historic := str(school.style) == "historic" and main_building
	var floor_height := 3.48 if historic else 3.21
	var ground := elevation.height_at(row[6])
	var top := ground + floors * floor_height + 0.3
	var tint := Color(school.wall)
	var accent := Color(school.accent)
	_shell(building, shape, elevation, top, tint, material)
	var windows := CityMesh.new()
	var longest := 0.0
	var entry_point := Vector2.ZERO
	var entry_normal := Vector2.UP
	for index in shape.size():
		var a := shape[index]
		var b := shape[(index + 1) % shape.size()]
		var length := a.distance_to(b)
		if length < 3.6:
			continue
		var mid := a.lerp(b, 0.5)
		var along := a.direction_to(b)
		var normal := along.orthogonal()
		if Geometry2D.is_point_in_polygon(mid + normal * 0.28, shape):
			normal = -normal
		var p := mid + normal * 0.072
		if length > longest:
			longest = length
			entry_point = p
			entry_normal = normal
		var p1 := a + normal * 0.10
		var p2 := b + normal * 0.10
		windows.facade(Vector3(p1.x, top - 0.43, p1.y), Vector3(p2.x, top - 0.43, p2.y), 0.31, accent)
		var bays := maxi(1, floori((length - 1.2) / (3.36 if historic else 2.98)))
		for bay in bays:
			var at := p + along * ((bay - (bays - 1.0) * 0.5) * (3.36 if historic else 2.98))
			var half := 0.87 if historic else 1.08
			var left := at - along * half
			var right := at + along * half
			for floor_index in floors:
				var sill := ground + 0.94 + floor_index * floor_height
				windows.facade(Vector3(left.x, sill, left.y), Vector3(right.x, sill, right.y), 1.83, FRAME)
				var inner_left := left + along * 0.10 + normal * 0.03
				var inner_right := right - along * 0.10 + normal * 0.03
				windows.facade(Vector3(inner_left.x, sill + 0.11, inner_left.y), Vector3(inner_right.x, sill + 0.11, inner_right.y), 1.61, GLASS.lightened(0.024 * ((index + floor_index) % 4)))
				var pane := at + normal * 0.065
				windows.facade(Vector3(pane.x - along.x * 0.04, sill + 0.11, pane.y - along.y * 0.04), Vector3(pane.x + along.x * 0.04, sill + 0.11, pane.y + along.y * 0.04), 1.61, tint.lightened(0.16))
			if historic:
				var pilaster := at + along * 1.5 + normal * 0.14
				windows.facade(Vector3(pilaster.x - along.x * 0.16, ground + 0.4, pilaster.y - along.y * 0.16), Vector3(pilaster.x + along.x * 0.16, ground + 0.4, pilaster.y + along.y * 0.16), top - ground - 0.9, accent)
	windows.make_node(building, material)
	if main_building and longest > 4.0:
		var entrance := _anchor(building, entry_point, elevation, atan2(entry_normal.x, entry_normal.y))
		var width := clampf(longest * 0.20, 3.5, 6.1)
		_entry(entrance, width, 2.54, str(school.name).to_upper())
		_geo.box(entrance, Vector3(0, 0.13, 1.30), Vector3(width + 1.35, 0.26, 2.95), accent.darkened(0.25))
		for side: float in [-1.0, 1.0]:
			_geo.box(entrance, Vector3(side * (width * 0.56), 1.51, 1.23), Vector3(0.22, 2.84, 0.22), accent)
		if historic:
			_geo.box(entrance, Vector3(0, 4.02, 0.31), Vector3(width + 1.06, 0.6, 0.32), accent)
			_geo.signage(entrance, Vector3(0, 4.03, 0.5), "ANNO 1919", 19, Color("#625047"))


func _shell(building: Node3D, outline: PackedVector2Array, elevation: Elevation, top: float, tint: Color, material: Material, entrance := {}) -> void:
	var mesh := CityMesh.new()
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var projected := Geometry2D.get_closest_point_to_segment(entrance.entrance, a, b) if not entrance.is_empty() else Vector2.INF
		if not entrance.is_empty() and projected.distance_to(entrance.entrance) < 0.25:
			var offset := a.direction_to(b) * float(entrance.door_width) * 0.5
			var left := projected - offset
			var right := projected + offset
			var header := elevation.height_at(projected) + float(entrance.floor_height) + 2.62
			mesh.wall(elevation.point_at(a, -0.19), elevation.point_at(left, -0.19), Vector3(left.x, top, left.y), Vector3(a.x, top, a.y), tint)
			mesh.wall(elevation.point_at(right, -0.19), elevation.point_at(b, -0.19), Vector3(b.x, top, b.y), Vector3(right.x, top, right.y), tint)
			mesh.wall(Vector3(left.x, header, left.y), Vector3(right.x, header, right.y), Vector3(right.x, top, right.y), Vector3(left.x, top, left.y), tint)
		else:
			mesh.wall(elevation.point_at(a, -0.19), elevation.point_at(b, -0.19), Vector3(b.x, top, b.y), Vector3(a.x, top, a.y), tint)
	mesh.flat_polygon(outline, top, tint.darkened(0.40))
	var shell := mesh.make_node(building, material, true)
	if shell != null:
		shell.get_child(0).add_to_group("city_facade")


func _anchor(building: Node3D, at: Vector2, elevation: Elevation, heading: float) -> Node3D:
	var anchor := Node3D.new()
	anchor.position = elevation.point_at(at)
	anchor.rotation.y = heading
	building.add_child(anchor)
	return anchor


func _glazing(building: Node3D, shape: PackedVector2Array, elevation: Elevation, center_y: float, width: float, height: float, spacing: float) -> void:
	for edge in shape.size():
		var a := shape[edge]
		var b := shape[(edge + 1) % shape.size()]
		var length := a.distance_to(b)
		if length < width + 1.45:
			continue
		var center := a.lerp(b, 0.5)
		var tangent := a.direction_to(b)
		var normal := tangent.orthogonal()
		if Geometry2D.is_point_in_polygon(center + normal * 0.22, shape):
			normal = -normal
		var count := maxi(1, floori((length - 1.25) / spacing))
		for index in count:
			var offset := (index - (count - 1) * 0.5) * spacing
			var anchor := _anchor(building, center + tangent * offset + normal * 0.085, elevation, atan2(normal.x, normal.y))
			_glass(anchor, Vector3(0, center_y, 0), width, height)


func _glass(parent: Node3D, at: Vector3, width: float, height: float, tint := GLASS) -> void:
	_geo.box(parent, at, Vector3(width + 0.15, height + 0.15, 0.1), FRAME)
	_geo.box(parent, at + Vector3.BACK * 0.063, Vector3(width, height, 0.03), tint)
	_geo.box(parent, at + Vector3(0, -height * 0.125, 0.082), Vector3(width, 0.055, 0.034), FRAME)


func _entry(anchor: Node3D, width: float, height: float, label: String) -> void:
	_glass(anchor, Vector3(0, height * 0.49, 0.32), width, height)
	for column in range(-2, 3):
		_geo.box(anchor, Vector3(column * width / 5.0, height * 0.51, 0.413), Vector3(0.072, height, 0.10), FRAME)
	_geo.box(anchor, Vector3(0, height + 0.13, 0.82), Vector3(width + 0.6, 0.27, 1.62), Color("#6a7476"))
	_geo.signage(anchor, Vector3(0, height + 0.5, 0.43), label, 22, Color("#e9e2d3"))


func _francis_roof(building: Node3D, shape: PackedVector2Array, center: Vector2, eaves: float, elevation: Elevation, material: Material) -> void:
	var roof := CityMesh.new()
	var apex := Vector3(center.x + 1.65, eaves + 8.1, center.y + 1.5)
	for index in shape.size():
		var a := shape[index].lerp(center, -0.023)
		var b := shape[(index + 1) % shape.size()].lerp(center, -0.023)
		var start := Vector3(a.x, eaves + 0.05, a.y)
		var finish := Vector3(b.x, eaves + 0.05, b.y)
		var tone := Color("#576663").lightened(0.016 * (index % 4))
		roof.triangle(start, finish, apex, tone)
		if index % 2 == 0:
			_beam(building, start + Vector3.UP * 0.11, apex + Vector3.UP * 0.11, 0.044, tone.lightened(0.13))
	roof.make_node(building, material, true)
	var tower := Node3D.new()
	tower.name = "FrancisBelfry"
	tower.position = apex
	tower.rotation.y = -0.35
	building.add_child(tower)
	var charcoal := Color("#414241")
	_geo.box(tower, Vector3(0, 0.34, 0), Vector3(5.05, 0.68, 5.05), charcoal)
	_geo.box(tower, Vector3(0, 2.15, 0), Vector3(4.3, 3.1, 4.3), Color("#c7b597"))
	for side in 4:
		var face := Node3D.new()
		face.rotation.y = side * PI * 0.5
		tower.add_child(face)
		for x: float in [-1.63, -0.81, 0.0, 0.81, 1.63]:
			_geo.box(face, Vector3(x, 2.12, 2.16), Vector3(0.23, 2.95, 0.21), charcoal)
	_geo.box(tower, Vector3(0, 3.70, 0), Vector3(5.15, 0.39, 5.15), charcoal)
	var spire := _geo.taper(tower, Vector3(0, 10.56, 0), 13.43, 0.11, 3.74, Color("#3b4146"), 4)
	spire.rotation.y = PI * 0.25
	_geo.box(tower, Vector3(0, 18.32, 0), Vector3(0.081, 2.31, 0.095), FRAME)
	_geo.box(tower, Vector3(0, 18.68, 0), Vector3(1.39, 0.078, 0.089), FRAME)
	for at: Vector2 in [Vector2(443.0, 282.8), Vector2(468.2, 335.1)]:
		var turret := _anchor(building, at, elevation, -0.36)
		var y := eaves - turret.position.y
		_geo.taper(turret, Vector3(0, y + 1.64, 0), 3.65, 0.09, 2.26, Color("#779092"), 10)
		for side in 8:
			var unit := Vector2.from_angle(side * TAU / 8.0)
			_beam(turret, Vector3(unit.x * 2.20, y, unit.y * 2.20), Vector3(0, y + 3.52, 0), 0.095, FRAME)


func _francis_steps(building: Node3D, elevation: Elevation) -> void:
	var entry := _anchor(building, Vector2(438.50, 302.5), elevation, -1.58)
	entry.name = "FrancisChurchPortico"
	var sandstone := Color("#b7a589")
	var basalt := Color("#514f49")
	var pale := Color("#d3c5a7")
	var forecourt := CityMesh.new()
	var corners := PackedVector2Array()
	for local: Vector3 in [Vector3(-14.0, 0, 0.3), Vector3(14.0, 0, 0.3), Vector3(13.6, 0, 11.0), Vector3(-13.6, 0, 11.0)]:
		var point := entry.to_global(local)
		corners.append(Vector2(point.x, point.z))
	var paving := Geometry2D.triangulate_polygon(corners)
	for i in range(0, paving.size(), 3):
		forecourt.triangle(elevation.point_at(corners[paving[i]], 0.11), elevation.point_at(corners[paving[i + 1]], 0.11),
			elevation.point_at(corners[paving[i + 2]], 0.11), pale.darkened(0.19))
	var terrace_material := _geo.material(Color("#a49a85")).duplicate() as StandardMaterial3D
	terrace_material.vertex_color_use_as_albedo = true
	forecourt.make_node(building, terrace_material, false, false)
	for step in 5:
		var height := (step + 1) * 0.14
		var depth := 3.8 - step * 0.58
		_geo.box(entry, Vector3(0, height * 0.5, 0.36 + depth * 0.5), Vector3(24.8, height, depth), basalt.lightened(0.03 * step), true)
	_geo.box(entry, Vector3(0, 6.56, 0.55), Vector3(16.1, 1.59, 1.19), sandstone)
	_geo.box(entry, Vector3(0, 7.32, 0.65), Vector3(12.1, 0.75, 0.95), sandstone)
	_geo.box(entry, Vector3(0, 5.72, 0.79), Vector3(16.0, 0.17, 0.69), pale)
	_entry(entry, 6.2, 4.42, "ŠV. PRANCIŠKAUS ASYŽIEČIO")
	for side: float in [-1.0, 1.0]:
		for column in 4:
			var x := (4.8 + column * 1.9) * side
			_geo.box(entry, Vector3(x, 3.08, 0.63), Vector3(1.36, 5.04, 0.46), sandstone)
			_glass(entry, Vector3(x, 2.66, 0.86), 0.29, 3.33, Color("#293635"))
		for handrail: float in [11.9, 13.6]:
			_beam(entry, Vector3(side * handrail, 1.52, 0.72), Vector3(side * handrail, 0.87, 4.11), 0.044, Color("#78817e"))
		var tree := _geo.taper(entry, Vector3(side * 11.32, 1.44, 4.87), 2.15, 0.11, 0.94, Color("#526746"), 9)
		tree.rotation.y = side * 0.33


func _francis_plaza(building: Node3D, elevation: Elevation, material: Material) -> void:
	var course := CityMesh.new()
	var a := Vector2(416.0, 276.0)
	var b := Vector2(396.6, 325.2)
	var direction := a.direction_to(b)
	var normal := Vector2(-direction.y, direction.x)
	var corners := PackedVector2Array([a - normal * 5.3, b - normal * 5.3, b + normal * 3.0, a + normal * 3.0])
	var triangles := Geometry2D.triangulate_polygon(corners)
	for index in range(0, triangles.size(), 3):
		course.triangle(elevation.point_at(corners[triangles[index]], 0.103),
			elevation.point_at(corners[triangles[index + 1]], 0.103), elevation.point_at(corners[triangles[index + 2]], 0.103), Color("#aaa394"))
	course.make_node(building, material, false, false)
	var clock := _anchor(building, Vector2(406.5, 287.5), elevation, -1.35)
	clock.name = "ChurchPlazaClock"
	var iron := Color("#424747")
	var cream := Color("#e3dcca")
	_geo.taper(clock, Vector3(0, 0.17, 0), 0.34, 0.19, 0.27, iron, 10)
	_geo.taper(clock, Vector3(0, 1.25, 0), 2.28, 0.071, 0.13, iron, 10)
	for side: float in [-1.0, 1.0]:
		var surround := _geo.taper(clock, Vector3(0, 2.77, side * 0.05), 0.16, 0.44, 0.44, iron, 28)
		surround.rotation.x = PI * 0.5
		var dial := _geo.taper(clock, Vector3(0, 2.77, side * 0.139), 0.024, 0.365, 0.365, cream, 28)
		dial.rotation.x = PI * 0.5
		for marker in 12:
			var angle := TAU * marker / 12.0
			var tick := _geo.box(clock, Vector3(sin(angle) * 0.293, 2.77 + cos(angle) * 0.293, side * 0.16),
				Vector3(0.018, 0.052, 0.014), iron)
			tick.rotation.z = -angle
		_beam(clock, Vector3(0, 2.77, side * 0.177), Vector3(0.19, 2.95, side * 0.177), 0.023, iron)
		_beam(clock, Vector3(0, 2.77, side * 0.177), Vector3(-0.142, 2.86, side * 0.177), 0.027, iron)
	var rng := RandomNumberGenerator.new()
	rng.seed = 49
	for section in 9:
		var point := a.lerp(b, (section + 0.5) / 9.0)
		var footing := _anchor(building, point + normal * 3.5, elevation, atan2(normal.x, normal.y))
		if section % 3 == 0:
			_geo.box(footing, Vector3(0, 0.48, 0), Vector3(2.33, 0.1, 0.53), Color("#845d43"))
			for x: float in [-0.87, 0.87]:
				_geo.box(footing, Vector3(x, 0.25, 0), Vector3(0.09, 0.50, 0.40), iron)
		else:
			for flower in 9:
				var width := rng.randf_range(0.22, 0.52)
				var height := rng.randf_range(0.25, 0.60)
				var at := Vector3(-1.22 + flower * 0.32, height * 0.5, rng.randf_range(-0.53, 0.53))
				_geo.taper(footing, at, height, width * 0.53, width, Color("#65734a"), 6)
				_geo.taper(footing, at + Vector3.UP * height * 0.43, height * 0.52, 0.052, 0.097,
					[Color("#806691"), Color("#8e769f"), Color("#b37d88"), Color("#ada47d")][flower % 4], 6)
		var rail := _anchor(building, point - normal * 6.0, elevation, atan2(normal.x, normal.y))
		for x: float in [-2.05, 2.05]:
			_geo.taper(rail, Vector3(x, 0.49, 0), 0.98, 0.026, 0.032, Color("#9ba5a1"), 7)
		for y: float in [0.43, 0.84]:
			_beam(rail, Vector3(-2.07, y, 0), Vector3(2.07, y, 0), 0.044, Color("#9ba5a1"))
		_geo.batch_static(footing)
		_geo.batch_static(rail)
	_geo.batch_static(clock)


func _old_church(building: Node3D, ground: float) -> void:
	var axis := Node3D.new()
	axis.position = Vector3(944.1, ground, -894.5)
	axis.rotation.y = -0.86
	building.add_child(axis)
	var brick := Color("#a3634b")
	_geo.box(axis, Vector3(0, 11.6, 3.8), Vector3(7.2, 8.5, 7.4), brick, true)
	_geo.box(axis, Vector3(0, 16.02, 3.8), Vector3(7.5, 0.42, 7.7), brick.darkened(0.27))
	_geo.taper(axis, Vector3(0, 17.22, 3.80), 2.16, 0.21, 4.65, Color("#5c6259"), 4).rotation.y = PI * 0.25
	_geo.box(axis, Vector3(0, 19.15, 3.80), Vector3(0.1, 2.35, 0.1), FRAME)
	_geo.box(axis, Vector3(0, 19.51, 3.80), Vector3(1.22, 0.09, 0.08), FRAME)
	for x: float in [-1.95, 0.0, 1.95]:
		_glass(axis, Vector3(x, 12.76, 7.55), 0.76, 2.65, Color("#494746"))


func _culture(building: Node3D, elevation: Elevation, ground: float) -> void:
	var hall := _anchor(building, Vector2(470.0, 222.4), elevation, -1.92)
	_geo.box(hall, Vector3(0, ground - hall.position.y + 11.0, -7.0), Vector3(31, 5.4, 26), Color("#a29b90"), true)
	_geo.box(hall, Vector3(0, ground - hall.position.y + 15.0, -9.4), Vector3(21.4, 3.7, 13.6), Color("#989489"), true)
	var entry := _anchor(building, Vector2(437.2, 224.9), elevation, -1.94)
	_geo.box(entry, Vector3(0, 4.58, -1.08), Vector3(9.6, 8.8, 2.46), Color("#c5b7a3"))
	_entry(entry, 8.35, 2.85, "MAŽEIKIŲ KULTŪROS CENTRAS")
	for index in 4:
		_geo.box(entry, Vector3(0, 0.035 + index * 0.093, 3.29 - index * 0.37), Vector3(13.4 - index * 0.53, 0.14 + index * 0.13, 2.27), Color("#96948a"))
	var plaque := _geo.box(entry, Vector3(0, 5.59, 0.20), Vector3(5.7, 2.48, 0.14), Color("#47565b"))
	for stripe in 3:
		var colors := [Color("#e2bb60"), Color("#52836b"), Color("#ad565c")]
		var bar := _geo.box(entry, plaque.position + Vector3((stripe - 1) * 0.42, (stripe - 1) * 0.24, 0.08), Vector3(2.68, 0.15, 0.035), colors[stripe])
		bar.rotation.z = 0.23


func _iki(building: Node3D, elevation: Elevation) -> void:
	var facing := _anchor(building, Vector2(535.1, 361.45), elevation, -0.357)
	var teal := Color("#375c59")
	var brick := Color("#855146")
	_geo.box(facing, Vector3(0, 4.94, 0.075), Vector3(69.5, 1.75, 0.18), teal)
	_geo.box(facing, Vector3(0, 0.44, 0.13), Vector3(69.5, 0.86, 0.26), brick)
	for bay in range(-8, 9):
		var x := bay * 3.78
		if absf(x) > 7.4:
			_glass(facing, Vector3(x, 2.03, 0.11), 3.23, 2.24)
	_geo.box(facing, Vector3(0, 3.33, 0.16), Vector3(12.9, 6.46, 0.44), Color("#d5cba8"))
	_geo.box(facing, Vector3(0, 1.42, 0.43), Vector3(8.81, 2.72, 0.13), Color("#394e4b"))
	_geo.box(facing, Vector3(0, 2.97, 0.93), Vector3(11.8, 0.25, 1.39), teal)
	_geo.signage(facing, Vector3(0, 4.86, 0.41), "IKI", 75, Color("#657f25"))
	for x: float in [-27, 26]:
		_geo.box(facing, Vector3(x, 1.22, 0.25), Vector3(6.23, 0.72, 0.15), brick.lightened(0.11))
	_geo.signage(facing, Vector3(-27.02, 1.24, 0.35), "PARDUOTUVĖS", 16, Color("#eadac0"))


func _eifelis(building: Node3D, elevation: Elevation) -> void:
	var entrance := _anchor(building, Vector2(1370.2, 847.1), elevation, 1.422)
	_geo.box(entrance, Vector3(0, 3.81, 0.22), Vector3(36.0, 2.52, 0.31), Color("#424a4a"))
	var panels := [Color("#696762"), Color("#77746c"), Color("#5d605b"), Color("#555650")]
	for row in 4:
		for column in 28:
			var x := -17.36 + column * 1.285
			if absf(x - 7.1) < 4.0 and row < 3:
				continue
			var panel: Color = panels[posmod(column * 7 + row * 5 + floori(column / 5.0), panels.size())]
			_geo.box(entrance, Vector3(x, 3.02 + row * 0.515, 0.397),
				Vector3(1.257, 0.489, 0.045), panel)
	var norfa := _geo.signage(entrance, Vector3(-6.4, 4.88, 0.441), "NORFA XXL", 37, Color("#b7d996"))
	norfa.outline_size = 4
	var jysk := _geo.signage(entrance, Vector3(-13.65, 3.38, 0.441), "JYSK", 29, Color("#dfedf5"))
	jysk.outline_size = 4
	_geo.box(entrance, Vector3(0, 2.53, 1.19), Vector3(33.3, 0.28, 2.43), Color("#536d70"))
	var label := _geo.signage(entrance, Vector3(-5.8, 4.11, 0.407), "EIFELIS", 53, Color("#e0e8e7"))
	label.outline_size = 5
	for index in 11:
		var x := -14.3 + index * 2.79
		if absf(x - 7.1) > 3.2:
			_glass(entrance, Vector3(x, 1.24, 0.35), 2.64, 2.26)
	var front := _anchor(building, Vector2(1349.5, 803.2), elevation, 2.995)
	_geo.box(front, Vector3(0, 2.92, 0.10), Vector3(44.0, 5.65, 0.17), Color("#a1a39b"))
	_geo.box(front, Vector3(0, 5.55, 0.23), Vector3(44.0, 0.81, 0.22), Color("#407980"))
	_geo.box(front, Vector3(2.4, 3.67, 1.44), Vector3(15.3, 0.30, 2.51), Color("#4a5557"))
	for column in 13:
		var x := -20.8 + column * 3.33
		_geo.box(front, Vector3(x, 1.85, 0.25), Vector3(0.12, 3.53, 0.32), Color("#6d7978"))
		_glass(front, Vector3(x + 1.61, 1.79, 0.30), 3.04, 2.55)
	_geo.signage(front, Vector3(4.70, 4.39, 0.47), "ERMITAŽAS", 44, Color("#36593d"))
	_geo.signage(front, Vector3(-11.0, 6.23, 0.48), "EIFELIS", 54, Color("#2d5472"))
	var tower := _anchor(building, Vector2(1381.8, 734.6), elevation, 1.422)
	tower.name = "EifelisTower"
	var wood := Color("#8d7554")
	var levels := [Vector2(3.3, 0.12), Vector2(2.15, 3.45), Vector2(1.31, 7.35), Vector2(0.60, 11.85), Vector2(0.19, 14.1)]
	for level in range(levels.size() - 1):
		var lower: Vector2 = levels[level]
		var higher: Vector2 = levels[level + 1]
		for side in 4:
			var pair := Vector2.from_angle(PI * 0.25 + side * PI * 0.5)
			var next := pair.rotated(PI * 0.5)
			var a := Vector3(pair.x * lower.x, lower.y, pair.y * lower.x)
			var b := Vector3(pair.x * higher.x, higher.y, pair.y * higher.x)
			var c := Vector3(next.x * lower.x, lower.y, next.y * lower.x)
			var d := Vector3(next.x * higher.x, higher.y, next.y * higher.x)
			_beam(tower, a, b, 0.15, wood)
			_beam(tower, a, d, 0.10, wood.darkened(0.12))
			_beam(tower, c, b, 0.10, wood)
			_beam(tower, b, d, 0.14, wood.darkened(0.21))
			var midpoint: Vector3 = a.lerp(b, 0.52)
			var opposed: Vector3 = c.lerp(d, 0.52)
			_beam(tower, midpoint, opposed, 0.072, wood)
	for deck: float in [3.45, 7.35, 11.85]:
		var width := 3.28 if deck < 5.0 else (2.08 if deck < 10.0 else 1.06)
		_geo.box(tower, Vector3(0, deck, 0), Vector3(width, 0.16, width), wood.darkened(0.18))
	_geo.taper(tower, Vector3(0, 14.36, 0), 0.75, 0.03, 0.12, wood.darkened(0.22), 8)


func _swift_arena(building: Node3D, outline: PackedVector2Array, elevation: Elevation) -> void:
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		var span := a.distance_to(b)
		if span < 10.0:
			continue
		var direction := a.direction_to(b)
		var midpoint := a.lerp(b, 0.5)
		var normal := direction.orthogonal()
		if Geometry2D.is_point_in_polygon(midpoint + normal, outline):
			normal = -normal
		var front := _anchor(building, midpoint + normal * 0.09, elevation, atan2(normal.x, normal.y))
		for panel in floori(span / 0.94):
			var x := -span * 0.5 + 0.68 + panel * 0.94
			var tint := Color("#745444") if panel % 6 == 2 else Color("#42464e")
			_geo.box(front, Vector3(x, 5.02, 0.035), Vector3(0.55, 8.48, 0.10), tint)
	var entrance := _anchor(building, Vector2(1070.6, 864.7), elevation, -1.73)
	_geo.box(entrance, Vector3(0, 7.72, 0.15), Vector3(13.4, 1.14, 0.15), Color("#41454b"))
	_geo.signage(entrance, Vector3(0, 7.72, 0.258), "SWIFT ARENA", 58, Color("#d7dbda"))
	_geo.box(entrance, Vector3(2.6, 2.96, 0.98), Vector3(12.2, 0.26, 2.02), Color("#5c6467"))
	for index in 4:
		_glass(entrance, Vector3(-2.0 + 2.72 * index, 1.46, 0.18), 2.64, 2.45)


func _museum(building: Node3D, elevation: Elevation) -> void:
	var entry := _anchor(building, Vector2(917.18, -1056.68), elevation, 0.655)
	_geo.box(entry, Vector3(0, 0.15, 1.30), Vector3(11.7, 0.31, 3.05), Color("#a8a69a"))
	_entry(entry, 4.4, 2.50, "MAŽEIKIŲ MUZIEJUS")
	_glass(entry, Vector3(0, 4.06, 0.37), 4.42, 2.0, Color("#677a6b"))
	for x: float in [-1.65, -0.55, 0.55, 1.65]:
		_geo.box(entry, Vector3(x, 4.06, 0.473), Vector3(0.069, 2.02, 0.11), FRAME)


func _library(building: Node3D, shape: PackedVector2Array, elevation: Elevation) -> void:
	for edge in shape.size():
		var a := shape[edge]
		var b := shape[(edge + 1) % shape.size()]
		if a.distance_to(b) < 9.8:
			continue
		var center := a.lerp(b, 0.5)
		var normal := a.direction_to(b).orthogonal()
		if Geometry2D.is_point_in_polygon(center + normal * 0.27, shape):
			normal = -normal
		var wing := _anchor(building, center + normal * 0.087, elevation, atan2(normal.x, normal.y))
		var count := floori(a.distance_to(b) / 3.5)
		for index in count:
			var x := (index - (count - 1) * 0.5) * 3.48
			for y: float in [1.45, 4.4, 7.3]:
				_glass(wing, Vector3(x + 0.3, y, 0), 2.0, 1.75)
				_geo.box(wing, Vector3(x - 1.12, y, 0.14), Vector3(0.71, 1.92, 0.16), Color("#9b6148"))
				_geo.signage(wing, Vector3(x - 1.12, y, 0.232), ["A", "N", "L", "S", "R"][index % 5], 23, Color("#593e35"))
	var entry := _anchor(building, Vector2(675.41, -857.53), elevation, 2.22)
	_entry(entry, 3.2, 2.4, "HENRIKO NAGIO BIBLIOTEKA")


func _beam(parent: Node3D, from: Vector3, to: Vector3, width: float, tint: Color) -> void:
	var bar := _geo.box(parent, from.lerp(to, 0.5), Vector3(width, width, from.distance_to(to)), tint)
	bar.look_at(parent.to_global(to), Vector3.UP)
