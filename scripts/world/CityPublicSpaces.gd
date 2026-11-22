extends RefCounted

const Geometry = preload("res://scripts/world/Geometry.gd")
const CityMesh = preload("res://scripts/world/CityMesh.gd")
const Water = preload("res://assets/shaders/city_water.gdshader")
const CHERRY_MODEL := "res://assets/models/cherry_blossom.glb"
const CherryPetals = preload("res://assets/shaders/cherry_blossoms.gdshader")
const PARKS := [
	{"name": "Sodų skveras", "point": Vector2(112.0, -242.0), "places": [
		["sign", Vector2(75.0, -231.5), 0.16], ["playground", Vector2(126.2, -230.2), 0.35],
		["fountain", Vector2(105.8, -280.8), 0.0], ["bench", Vector2(115.2, -252.3), -0.34],
		["bench", Vector2(150.3, -258.2), -0.29], ["lamp", Vector2(103.0, -243.4), 0.0]
	]},
	{"name": "Melioratorių parkelis", "point": Vector2(-609.0, -222.0), "places": [
		["sign", Vector2(-587.0, -224.0), 1.63], ["fountain", Vector2(-603.3, -221.7), 0.0],
		["wood_play", Vector2(-660.6, -249.3), 0.97], ["bench", Vector2(-636.8, -215.8), 0.1],
		["bench", Vector2(-623.6, -246.0), -0.58], ["lamp", Vector2(-650.0, -216.4), 0.0]
	]},
	{"name": "Senamiesčio parkas", "point": Vector2(954.0, -982.0), "places": [
		["gabion", Vector2(947.2, -925.2), -0.75], ["wood_play", Vector2(980.3, -985.5), 0.0],
		["bench", Vector2(966.8, -965.8), 0.30], ["bench", Vector2(995.2, -942.0), -0.73],
		["lamp", Vector2(954.8, -996.5), 0.0], ["lamp", Vector2(974.7, -953.1), 0.0]
	]},
	{"name": "Juodpelkio parkas", "point": Vector2(801.0, 1255.0), "places": [
		["sign", Vector2(777.0, 1253.0), 2.7], ["bench", Vector2(863.7, 1292.3), -0.63],
		["bench", Vector2(935.0, 1326.0), -0.33], ["lamp", Vector2(839.4, 1280.0), 0.0],
		["lamp", Vector2(876.5, 1300.1), 0.0], ["lamp", Vector2(918.7, 1320.8), 0.0],
		["lamp", Vector2(959.0, 1333.5), 0.0], ["wood_play", Vector2(877.4, 1295.4), 0.7]
	]},
	{"name": "Senjorų parkas", "point": Vector2(480.0, 920.0), "places": [
		["sign", Vector2(441.0, 928.0), 1.2], ["bench", Vector2(469.0, 936.0), -0.2],
		["cherry", Vector2(451.0, 905.0), 0.7], ["cherry", Vector2(462.0, 912.0), 2.2],
		["cherry", Vector2(473.0, 919.0), 1.1], ["cherry", Vector2(483.0, 924.0), 2.9],
		["cherry", Vector2(496.0, 928.0), 3.8]
	]},
	{"name": "Pavasario skveras", "point": Vector2(892.0, 520.0), "places": [
		["sign", Vector2(868.0, 519.0), 2.7], ["bench", Vector2(896.0, 531.0), 0.22],
		["bench", Vector2(916.0, 527.0), 1.8]
	]},
	{"name": "Vyturių takas", "point": Vector2(257.0, -128.0), "places": [
		["sign", Vector2(226.0, -263.0), -0.18], ["bench", Vector2(248.7, -162.1), 1.1]
	]},
	{"name": "Pavenčių paplūdimys", "point": Vector2(40.4, 1467.0), "places": [
		["sign", Vector2(54.0, 1460.0), 2.8], ["bench", Vector2(63.1, 1476.0), -0.9],
		["changing_cabin", Vector2(53.5, 1483.1), 2.0]
	]},
	{"name": "Nepriklausomybės skveras", "point": Vector2(1155.0, -631.0), "places": []},
	{"name": "V. Burbos skverelis", "point": Vector2(743.0, -843.0), "places": []}
]

var _geometry := Geometry.new()
var _barriers: Dictionary = {}
var _props: Dictionary = {}
var _gate_keys := {}
var _tile_size := 184.0
var _petal_material: ShaderMaterial


func index(tile_size: float) -> void:
	_tile_size = tile_size
	var imported: Dictionary = GameManager.read_json("res://data/city/street_details.json", {})
	for row: Array in imported.get("furniture", []):
		if str(row[0]) == "gate":
			var gate := _vector(row[1])
			_gate_keys[Vector2i(roundi(gate.x), roundi(gate.y))] = true
	for row: Array in imported.get("barriers", []):
		var line: Array = row[2]
		for i in range(1, line.size()):
			var from := _vector(line[i - 1])
			var to := _vector(line[i])
			var axis := from.direction_to(to)
			var length := from.distance_to(to)
			var first := 1.15 if _at_gate(from) else 0.0
			var last := length - (1.15 if _at_gate(to) else 0.0)
			if last - first < 0.60:
				continue
			var pieces := ceili((last - first) / 18.0)
			for piece in pieces:
				var a := from + axis * lerpf(first, last, float(piece) / pieces)
				var b := from + axis * lerpf(first, last, float(piece + 1) / pieces)
				_barriers.get_or_add(_key(a.lerp(b, 0.5)), []).append([a, b, str(row[0]), float(row[1]), str(row[3])])
	var designed := PackedVector2Array()
	for park: Dictionary in PARKS:
		for spot: Array in park.places:
			_props.get_or_add(_key(spot[1]), []).append([spot[0], spot[1], spot[2], park.name])
			designed.append(spot[1])
	for row: Array in imported.get("furniture", []):
		if row[0] not in ["bench", "fountain", "playground", "waste_basket"]:
			continue
		var at := _vector(row[1])
		if _clear_of_designed(at, designed):
			_props.get_or_add(_key(at), []).append([row[0], at, deg_to_rad(float(row[2])), ""])
	for row: Array in imported.get("parks", []):
		if row[2] != "playground":
			continue
		var center := Vector2.ZERO
		for raw: Array in row[3]:
			center += _vector(raw)
		center /= row[3].size()
		if center != Vector2.ZERO and _clear_of_designed(center, designed):
			_props.get_or_add(_key(center), []).append(["wood_play", center, 0.0, ""])


func _clear_of_designed(at: Vector2, designed: PackedVector2Array) -> bool:
	for point: Vector2 in designed:
		if at.distance_squared_to(point) < 9.0 ** 2:
			return false
	return true


func _at_gate(at: Vector2) -> bool:
	return _gate_keys.has(Vector2i(roundi(at.x), roundi(at.y)))


func _key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / _tile_size), floori(at.y / _tile_size))


func _vector(row: Array) -> Vector2:
	return Vector2(float(row[0]), float(row[1]))


func map_pins() -> Array:
	var pins: Array = []
	for park: Dictionary in PARKS:
		pins.append({"name": park.name, "point": park.point, "park": true, "home": false})
	return pins


func build(tile: Node3D, key: Vector2i, district: Node3D) -> void:
	var fences: Array = _barriers.get(key, [])
	if not fences.is_empty():
		var root := StaticBody3D.new()
		root.name = "MappedFences"
		tile.add_child(root)
		for span: Array in fences:
			_make_fence(root, span, district)
	for record: Array in _props.get(key, []):
		var kind: String = record[0]
		var point: Vector2 = record[1]
		if kind == "lamp":
			district._lamp(tile, point, Vector2(-1.0, 0.0))
			continue
		var fixture := Node3D.new()
		fixture.name = kind.capitalize()
		tile.add_child(fixture, true)
		fixture.position = district.elevation.point_at(point, 0.035)
		fixture.rotation.y = float(record[2])
		match kind:
			"bench": _bench(fixture)
			"fountain": _fountain(fixture)
			"playground", "wood_play": _playground(fixture, kind == "wood_play")
			"sign", "gabion": _sign(fixture, record[3], kind == "gabion")
			"changing_cabin": _changing_cabin(fixture)
			"cherry":
				_add_cherry(fixture)
			"waste_basket":
				_geometry.taper(fixture, Vector3(0, 0.39, 0), 0.78, 0.28, 0.21, Color("#414b48"), 12)
	_geometry.batch_static(tile)


func _make_fence(root: StaticBody3D, span: Array, district: Node3D) -> void:
	var a: Vector3 = district.elevation.point_at(span[0])
	var b: Vector3 = district.elevation.point_at(span[1])
	var length := a.distance_to(b)
	var height := float(span[3])
	var kind: String = span[2]
	var solid := kind in ["wall", "retaining", "hedge"]
	var thickness := 0.38 if solid else 0.085
	var color := Color("#4c5953")
	if solid:
		color = Color("#526149") if kind == "hedge" else Color("#9a8e80")
		if span[4] == "brick":
			color = Color("#875849")
		_beam(root, a + Vector3.UP * height * 0.5, b + Vector3.UP * height * 0.5, height, thickness, color)
		if kind != "hedge":
			_beam(root, a + Vector3.UP * height, b + Vector3.UP * height, 0.12, thickness + 0.08, color.lightened(0.13))
	else:
		color = Color("#786450") if kind == "wood" else color
		var count := maxi(2, roundi(length / (0.30 if kind == "wood" else 0.22)))
		for index in range(count + 1):
			var at := a.lerp(b, float(index) / count)
			var post := 0.095 if index % 12 == 0 else (0.13 if kind == "wood" else 0.031)
			_geometry.box(root, at + Vector3.UP * height * 0.51, Vector3(post, height * 1.02, post), color)
		for y: float in [0.23, 0.81]:
			_beam(root, a + Vector3.UP * height * y, b + Vector3.UP * height * y, 0.062, 0.058, color)
	var shape := BoxShape3D.new()
	shape.size = Vector3(thickness, height, length)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	root.add_child(collision)
	collision.position = a.lerp(b, 0.5) + Vector3.UP * height * 0.5
	collision.look_at(b + Vector3.UP * height * 0.5)


func _beam(parent: Node3D, a: Vector3, b: Vector3, height: float, width: float, tint: Color) -> void:
	var segment := _geometry.box(parent, a.lerp(b, 0.5), Vector3(width, height, a.distance_to(b)), tint)
	segment.look_at(parent.to_global(b))


func _bench(parent: Node3D) -> void:
	var steel := Color("#3d4747")
	var wood := Color("#8d5442")
	for side: float in [-0.69, 0.69]:
		_geometry.box(parent, Vector3(side, 0.32, 0), Vector3(0.081, 0.62, 0.47), steel)
		_geometry.box(parent, Vector3(side, 0.59, -0.21), Vector3(0.071, 0.63, 0.071), steel)
	for i in 4:
		_geometry.box(parent, Vector3(0, 0.46, (i - 1.5) * 0.11), Vector3(1.91, 0.065, 0.092), wood)
	for i in 3:
		_geometry.box(parent, Vector3(0, 0.59 + i * 0.105, -0.24), Vector3(1.91, 0.079, 0.055), wood)


func _sign(parent: Node3D, name_on_sign: String, stone: bool) -> void:
	if stone:
		var wall := _geometry.taper(parent, Vector3(0, 0.42, 0), 0.82, 2.67, 2.73, Color("#958b7a"), 18)
		wall.scale.z = 0.45
		for column in 14:
			_geometry.box(parent, Vector3(-2.39 + column * 0.36, 0.43, 1.05), Vector3(0.034, 0.72, 0.055), Color("#65645e"))
		_geometry.signage(parent, Vector3(0, 0.95, 1.20), name_on_sign, 37, Color("#905948"))
		return
	var panel := Color("#365248")
	for x: float in [-0.84, 0.84]:
		_geometry.box(parent, Vector3(x, 0.72, 0), Vector3(0.10, 1.44, 0.10), panel)
	_geometry.box(parent, Vector3(0, 1.28, 0.02), Vector3(2.57, 0.49, 0.10), panel)
	_geometry.signage(parent, Vector3(0, 1.29, 0.09), name_on_sign, 24, Color("#edf0d9"))


func _fountain(parent: Node3D) -> void:
	var ring := TorusMesh.new()
	ring.inner_radius = 1.58
	ring.outer_radius = 1.91
	var curb := MeshInstance3D.new()
	curb.mesh = ring
	curb.material_override = _geometry.material(Color("#85837b"))
	curb.position.y = 0.21
	curb.scale.y = 1.8
	parent.add_child(curb)
	var stone := _geometry.taper(parent, Vector3.ZERO, 0.12, 1.71, 1.72, Color("#838b88"), 28)
	stone.position.y = 0.10
	var pool := CityMesh.new()
	pool.disc(Vector2.ZERO, 1.67, 0.195, Color(0.16, 0.32, 0.37, 0.0), 32)
	var material := ShaderMaterial.new()
	material.shader = Water
	pool.make_node(parent, material, false, false)
	_geometry.taper(parent, Vector3(0, 0.32, 0), 0.33, 0.087, 0.14, Color("#727674"), 10)


func _add_cherry(parent: Node3D) -> void:
	if not ResourceLoader.exists(CHERRY_MODEL, "PackedScene"):
		_geometry.taper(parent, Vector3(0, 1.45, 0), 2.9, 0.14, 0.22, Color("#65534a"))
		_geometry.taper(parent, Vector3(0, 3.4, 0), 1.8, 1.1, 1.9, Color("#dca4b5"))
		return
	var model := load(CHERRY_MODEL) as PackedScene
	if model == null:
		return
	if _petal_material == null:
		_petal_material = ShaderMaterial.new()
		_petal_material.shader = CherryPetals
	var tree := model.instantiate() as Node3D
	tree.scale *= 0.72
	for mesh: MeshInstance3D in tree.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.get_active_material(surface)
			var bloom := source != null and "blossom" in source.resource_name.to_lower()
			mesh.set_surface_override_material(surface, _petal_material if bloom else _geometry.material(Color("#65534a")))
	parent.add_child(tree)


func _changing_cabin(parent: Node3D) -> void:
	var wood := Color("#896e59")
	for side: float in [-1.0, 1.0]:
		for board in 8:
			var x := 0.15 * board
			_geometry.box(parent, Vector3(side * 0.80, 1.02, x - 0.52), Vector3(0.079, 2.04, 0.151), wood)
	_geometry.box(parent, Vector3(0.0, 1.02, -0.55), Vector3(1.55, 2.04, 0.08), wood, true)
	_geometry.box(parent, Vector3(0.55, 1.02, 0.61), Vector3(0.52, 2.04, 0.08), wood, true)
	var roof := _geometry.box(parent, Vector3(0, 2.08, 0.02), Vector3(1.81, 0.12, 1.55), Color("#5f6664"))
	roof.rotation.x = -0.12


func _playground(parent: Node3D, wood: bool) -> void:
	var post := Color("#735747") if wood else Color("#d09c3e")
	var rail := Color("#845c3e") if wood else Color("#a1463c")
	var base := Color("#91826b") if wood else Color("#b9ab86")
	_geometry.box(parent, Vector3(0, -0.025, 0.19), Vector3(5.7, 0.08, 6.5), base)
	for x: float in [-0.78, 0.78]:
		for z: float in [-0.74, 0.74]:
			_geometry.box(parent, Vector3(x, 1.12, z), Vector3(0.13, 2.24, 0.13), post)
	_geometry.box(parent, Vector3(0, 1.08, 0), Vector3(1.65, 0.14, 1.64), rail, true)
	_geometry.box(parent, Vector3(0, 2.33, 0), Vector3(1.99, 0.21, 1.92), rail)
	for i in 5:
		_geometry.box(parent, Vector3(0, i * 0.205 + 0.18, 1.12), Vector3(0.98, 0.075, 0.11), post)
	var slide := _geometry.box(parent, Vector3(0, 0.61, -1.75), Vector3(0.84, 0.07, 2.18), Color("#9ba6aa"), true)
	slide.rotation.x = -0.49
	for x: float in [-0.48, 0.48]:
		var border := _geometry.box(parent, Vector3(x, 0.67, -1.75), Vector3(0.079, 0.18, 2.19), rail)
		border.rotation.x = -0.49

