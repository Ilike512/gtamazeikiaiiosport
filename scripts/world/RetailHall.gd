extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const CityMesh = preload("res://scripts/world/CityMesh.gd")
const StoreGoods = preload("res://scripts/world/StoreGoods.gd")
const TILE = preload("res://assets/shaders/retail_floor.gdshader")
const RACK := Color("#deded0")
const METAL := Color("#626f71")
const CART := Color("#929996")
const WHITE := Color("#f2ede0")
const GOODS := [Color("#ae5246"), Color("#b5974d"), Color("#759262"), Color("#d4bc83"), Color("#68899b"), Color("#92728a")]
const DEPARTMENTS := ["DUONA", "GĖRIMAI", "BAKALĖJA", "SALDUMYNAI", "UŽKANDŽIAI", "PIENO PRODUKTAI", "BUITIES PREKĖS", "KAVA IR ARBATA"]

var footprint := PackedVector2Array()
var stock: Node3D
var checkout_points: Array[Vector3] = []
var _site: Dictionary
var _height := 4.6
var _fixtures_ready := false
var _geometry := Geometry.new()
var _accent: Color


func build_shell(site: Dictionary, mapped: PackedVector2Array) -> void:
	_site = site
	_height = float(site.hall_height)
	_accent = site.color
	for point: Vector2 in mapped:
		var local := to_local(Vector3(point.x, global_position.y, point.y))
		footprint.append(Vector2(local.x, local.z))
	var inset := Geometry2D.offset_polygon(footprint, -0.14)
	if inset.size() == 1:
		footprint = inset[0]
	var floor := CityMesh.new()
	var ceiling := CityMesh.new()
	var walls := CityMesh.new()
	floor.flat_polygon(footprint, 0.0, Color.WHITE)
	ceiling.flat_polygon(footprint, _height, Color.WHITE)
	for edge in footprint.size():
		var a := footprint[edge]
		var b := footprint[(edge + 1) % footprint.size()]
		var closest := Geometry2D.get_closest_point_to_segment(Vector2.ZERO, a, b)
		if closest.length_squared() < 0.28:
			var direction := a.direction_to(b)
			var left := closest - direction * (float(site.door_width) * 0.5 + 0.05)
			var right := closest + direction * (float(site.door_width) * 0.5 + 0.05)
			_wall(walls, a, left, 0.0, _height)
			_wall(walls, left, right, 2.27, _height)
			_wall(walls, right, b, 0.0, _height)
		else:
			_wall(walls, a, b, 0.0, _height)
	var ceramic := ShaderMaterial.new()
	ceramic.shader = TILE
	ceramic.set_shader_parameter("tile_tint", Color("#c9c5b9") if site.id == "maxima" else Color("#c5c4af"))
	floor.make_node(self, ceramic, true, false).name = "ContinuousShopFloor"
	var ceiling_material := _geometry.material(Color("#c7c6ba")).duplicate() as StandardMaterial3D
	ceiling_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	ceiling_material.emission_enabled = true
	ceiling_material.emission = Color("#b9b7af")
	ceiling_material.emission_energy_multiplier = 0.16
	ceiling.make_node(self, ceiling_material, true, false)
	var wall_material := _geometry.material(Color("#c4c4b7")).duplicate() as StandardMaterial3D
	wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	walls.make_node(self, wall_material)
	var threshold := float(site.threshold_depth)
	_geometry.box(self, Vector3(0, -0.085, (threshold - 0.43) * 0.5),
		Vector3(float(site.door_width) + 0.05, 0.17, threshold + 0.43), Color("#858777"), true)
	_geometry.box(self, Vector3(0, 0.006, -1.48), Vector3(float(site.door_width) + 0.75, 0.013, 2.64), Color("#646a63"))
	_label(self, Vector3(0, 2.59, -0.55), "IŠĖJIMAS", 18, Color("#9df3b7"), PI)


func _wall(mesh: RefCounted, a: Vector2, b: Vector2, bottom: float, top: float) -> void:
	mesh.wall(Vector3(a.x, bottom, a.y), Vector3(b.x, bottom, b.y),
		Vector3(b.x, top, b.y), Vector3(a.x, top, a.y), Color.WHITE)


func contains(at: Vector3) -> bool:
	var position_in_hall := to_local(at)
	return position_in_hall.y >= -0.40 and position_in_hall.y <= _height and Geometry2D.is_point_in_polygon(Vector2(position_in_hall.x, position_in_hall.z), footprint)


func grounded(at: Vector3) -> Vector3:
	var local := to_local(at)
	local.y = 0.06
	return to_global(local)


func checkout_near(at: Vector3) -> bool:
	var local := to_local(at)
	for checkout: Vector3 in checkout_points:
		if local.distance_squared_to(checkout) < 2.20 ** 2:
			return true
	return false


func build_fixtures(groceries: Array[Dictionary]) -> void:
	if _fixtures_ready:
		return
	_fixtures_ready = true
	var fixtures := Node3D.new()
	fixtures.name = "DepartmentsAndCheckouts"
	add_child(fixtures)
	var shelves: Array[Vector2] = []
	match _site.id:
		"maxima":
			_maxima(fixtures, shelves)
		"lidl":
			_lidl(fixtures, shelves)
		"maxima_dauksos":
			_maxima_dauksos(fixtures, shelves)
		"senukai":
			_senukai(fixtures)
		_:
			_putinas(fixtures, shelves)
	stock = StoreGoods.new()
	stock.name = "PickableShelfStock"
	add_child(stock)
	if not shelves.is_empty():
		stock.stock_shelves(groceries, shelves)
	_lighting(fixtures)
	_geometry.batch_static(fixtures)


func _maxima(parent: Node3D, shelves: Array[Vector2]) -> void:
	for index in 6:
		_checkout(parent, Vector2(-21.2 + index * 3.1, -7.1), index + 1, index > 3)
	_department(parent, Vector2(-14.0, -3.0), "KASOS", 7.0)
	var center := _fixtures_parent(parent, "EntranceServices")
	_carts(center, Vector2(3.82, -2.4))
	for kiosk: Array in [[-23.5, "PAŠTAS"], [-17.2, "KOSMETIKA"], [-10.8, "GYVŪNŲ PREKĖS"]]:
		_counter(center, Vector2(kiosk[0], -2.05), 4.6, kiosk[1], Color("#506d82"))
	_counter(center, Vector2(8.35, -7.2), 6.0, "INFORMACIJA", Color("#396587"))
	_department(parent, Vector2(5.5, -14.0), "VAISIAI IR DARŽOVĖS", 8.2)
	for x: float in [3.2, 8.0]:
		for z: float in [-19.4, -25.2, -31.0]:
			_produce(parent, Vector2(x, z))
	for index in 6:
		var x := -24.0 + index * 3.8
		var live := index < 5
		var at := Vector2(x, -22.0)
		_gondola(parent, at, 15.0, index, not live)
		if live:
			shelves.append(at)
		_gondola(parent, Vector2(x, -43.2), 16.5, index + 2, true)
	_department(parent, Vector2(-15, -32.4), "MAISTO PREKĖS", 8.8)
	_freezers(parent, Vector2(6.5, -37.4), "ŠALDYTI PRODUKTAI", 4)
	_counter(parent, Vector2(6.3, -49.5), 11.5, "KEPYKLA", Color("#875b42"))
	_counter(parent, Vector2(-9.5, -56.2), 14.1, "ŠVIEŽIA MĖSA IR ŽUVIS", Color("#685754"))
	_freezers(parent, Vector2(-23.5, -58.8), "PIENO PRODUKTAI", 4)
	for index in 4:
		_gondola(parent, Vector2(-22.5 + index * 4.9, -67.5), 7.4, index + 4, true)
	_department(parent, Vector2(-13.2, -62.5), "BUITIES PREKĖS", 7.1)


func _putinas(parent: Node3D, shelves: Array[Vector2]) -> void:
	_carts(parent, Vector2(3.38, -2.9))
	for index in 5:
		_checkout(parent, Vector2(-19.0 + index * 3.05, -6.92), index + 1, false)
	_department(parent, Vector2(-12.5, -3.6), "KASOS", 6.0)
	_counter(parent, Vector2(-31.5, -3.1), 7.0, "VAISTINĖ", Color("#5c7854"))
	_counter(parent, Vector2(-41.2, -3.1), 7.0, "PROVINCIJA", Color("#827154"))
	_department(parent, Vector2(-1.55, -12.8), "VAISIAI IR DARŽOVĖS", 8.0)
	for at: Vector2 in [Vector2(1.7, -18), Vector2(-3.6, -22.6), Vector2(1.7, -25.3), Vector2(-42.3, -15.4), Vector2(-42.3, -20.8)]:
		_produce(parent, at)
	for index in 7:
		var x := -39.0 + index * 4.76
		var live := index >= 2
		var at := Vector2(x, -20.25)
		_gondola(parent, at, 14.9, index, not live)
		if live:
			shelves.append(at)
		_gondola(parent, Vector2(x + 0.5, -37.4), 13.4, index + 2, true)
	_department(parent, Vector2(-23, -29.7), "BAKALĖJA", 8.0)
	_counter(parent, Vector2(-3.8, -39.5), 11.4, "KULINARIJA", Color("#75644c"))
	_counter(parent, Vector2(-17.6, -46.4), 10.4, "KEPYKLA", Color("#846449"))
	_freezers(parent, Vector2(-32.2, -45.95), "ŠALDYTI PRODUKTAI", 4)
	_counter(parent, Vector2(-4.5, -53.3), 8.4, "PIENO PRODUKTAI", Color("#60716d"))


func _maxima_dauksos(parent: Node3D, shelves: Array[Vector2]) -> void:
	_carts(parent, Vector2(4.0, -2.3))
	_department(parent, Vector2(-12.2, -2.8), "KASOS", 7.5)
	for index in 4:
		_checkout(parent, Vector2(-15.0 + index * 3.4, -5.5), index + 1, index == 3)
	for index in 7:
		var z := -13.5 - (index % 2) * 6.6
		var x := -16.0 + index * 4.65
		var at := Vector2(x, z)
		if not Geometry2D.is_point_in_polygon(at + Vector2(0, -4.2), footprint):
			continue
		_gondola(parent, at, 8.4, index, index >= 4)
		if index < 4:
			shelves.append(at)
	_department(parent, Vector2(8.0, -9.0), "ŠVIEŽIAS MAISTAS", 7.3)
	for x in [5.3, 11.0, 16.7]:
		var at := Vector2(x, -6.2)
		if Geometry2D.is_point_in_polygon(at, footprint):
			_produce(parent, at)
	_counter(parent, Vector2(1.4, -22.3), 6.2, "KEPYKLA", Color("#855f45"))
	_department(parent, Vector2(-14.2, -21.0), "BUITIES PREKĖS", 6.8)
	_freezers(parent, Vector2(-16.0, -28.2), "ŠALDYTI PRODUKTAI", 3)


func _lidl(parent: Node3D, shelves: Array[Vector2]) -> void:
	_carts(parent, Vector2(3.85, -2.9))
	for index in 5:
		_checkout(parent, Vector2(-18.0 + index * 3.25, -5.0), index + 1, index >= 3)
	_department(parent, Vector2(-10.5, -2.25), "KASOS", 8.0)
	_department(parent, Vector2(16, -4.7), "VAISIAI IR DARŽOVĖS", 9.0)
	for x: float in [8.0, 13.0, 18.0, 23.0]:
		_produce(parent, Vector2(x, -8.0))
	for index in 9:
		var at := Vector2(-24.0 + index * 5.65, -14.9)
		_gondola(parent, at, 8.0, index, index >= 5)
		if index < 5:
			shelves.append(at)
	_counter(parent, Vector2(16.0, -21.5), 12.0, "ŠVIEŽIA KEPYKLA", Color("#845e46"))
	_freezers(parent, Vector2(-8, -23), "ŠALDYTI PRODUKTAI", 5)
	_counter(parent, Vector2(2.0, -24.4), 8.3, "PIENO PRODUKTAI", Color("#6d8390"))
	_counter(parent, Vector2(11.0, -3.0), 5.2, "LIDL PLUS", Color("#24578b"))
	_department(parent, Vector2(-18, -10.0), "LIDL PASIŪLYMAI", 7.0)


func _senukai(parent: Node3D) -> void:
	_carts(parent, Vector2(-3.8, -3.1))
	for index in 4:
		_checkout(parent, Vector2(4.0 + index * 3.55, -6.5), index + 1, false)
	_department(parent, Vector2(9.7, -3.3), "KASOS", 8.1)
	var zones := ["ĮRANKIAI", "ELEKTRA", "APŠVIETIMAS", "DAŽAI", "STATYBINĖS MEDŽIAGOS", "SODO PREKĖS"]
	for row in 2:
		for index in 6:
			var at := Vector2(-15.0 + index * 6.0, -20.0 - row * 16.0)
			_hardware_rack(parent, at, zones[index], index)
	for index in 3:
		var at := Vector2(-14.0 + index * 6.0, -52.0)
		for tier in 4:
			_geometry.box(parent, Vector3(at.x, 0.22 + tier * 0.19, at.y), Vector3(4.9, 0.17, 0.94), Color("#aa8663"), true)
	var service := Vector2(9.7, -53.6)
	_counter(parent, service, 9.8, "PREKIŲ ATSIĖMIMAS  /  ĮRANKIŲ NUOMA", Color("#536247"))
	checkout_points.append(Vector3(service.x, 0.0, service.y + 1.4))


func _hardware_rack(parent: Node3D, at: Vector2, title: String, index: int) -> void:
	var frame := Color("#637176")
	var rail := Color("#c88234")
	_geometry.box(parent, Vector3(at.x, 1.84, at.y), Vector3(1.32, 3.68, 10.6), frame, true)
	for layer in 4:
		var y := 0.31 + layer * 0.89
		_geometry.box(parent, Vector3(at.x, y, at.y), Vector3(1.91, 0.11, 11.0), rail)
		for stack in 8:
			for side: float in [-1.0, 1.0]:
				var tint: Color = GOODS[(index + layer + stack) % GOODS.size()]
				_geometry.box(parent, Vector3(at.x + side * 0.70, y + 0.34, at.y - 4.7 + stack * 1.32),
					Vector3(0.45, 0.55, 1.06), tint.darkened(0.15))
	_department(parent, at + Vector2(0.0, 5.73), title, 4.95)


func _fixtures_parent(parent: Node3D, title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	parent.add_child(node)
	return node


func _department(parent: Node3D, position_in_hall: Vector2, title: String, span: float) -> void:
	var at := Vector3(position_in_hall.x, 3.38, position_in_hall.y)
	_geometry.box(parent, at, Vector3(span, 0.45, 0.16), _accent)
	for side: float in [-1.0, 1.0]:
		var hang := _height - at.y - 0.22
		_geometry.box(parent, at + Vector3(span * 0.40 * side, 0.22 + hang * 0.5, 0),
			Vector3(0.034, hang, 0.034), METAL)
	_label(parent, at + Vector3.BACK * 0.10, title, 26, WHITE)
	_label(parent, at + Vector3.FORWARD * 0.10, title, 26, WHITE, PI)


func _checkout(parent: Node3D, at: Vector2, number: int, self_service: bool) -> void:
	var x := at.x
	var z := at.y
	_geometry.box(parent, Vector3(x, 0.44, z), Vector3(0.81, 0.88, 2.71), _accent, true)
	_geometry.box(parent, Vector3(x, 0.89, z - 0.49), Vector3(0.86, 0.11, 1.55), Color("#343938"))
	_geometry.box(parent, Vector3(x, 0.96, z + 0.66), Vector3(0.82, 0.09, 0.75), CART)
	_geometry.box(parent, Vector3(x + 0.40, 1.12, z + 0.06), Vector3(0.16, 0.57, 0.51), METAL)
	_geometry.box(parent, Vector3(x + 0.47, 1.38, z - 0.08), Vector3(0.42, 0.30, 0.08), Color("#25343b"))
	_geometry.box(parent, Vector3(x + 0.47, 1.38, z - 0.126), Vector3(0.34, 0.22, 0.012), Color("#77a79d"))
	var nameplate := Vector3(x + 0.53, 2.99, z)
	_geometry.box(parent, nameplate, Vector3(1.62, 0.46, 0.12), Color("#386375") if self_service else _accent)
	_label(parent, nameplate + Vector3.FORWARD * 0.073, "%02d" % number, 25, WHITE, PI)
	_label(parent, nameplate + Vector3.BACK * 0.073, "%02d" % number, 25, WHITE)
	if self_service:
		_label(parent, nameplate + Vector3(0, -0.34, -0.073), "SAVITARNA", 14, WHITE, PI)
		_label(parent, nameplate + Vector3(0, -0.34, 0.073), "SAVITARNA", 14, WHITE)
	checkout_points.append(Vector3(x + 1.0, 0.0, z - 0.81))


func _gondola(parent: Node3D, at: Vector2, length: float, index: int, decorate: bool) -> void:
	_geometry.box(parent, Vector3(at.x, 0.86, at.y), Vector3(1.02, 1.72, length), METAL, true)
	for shelf in 4:
		var y := 0.16 + shelf * 0.39
		_geometry.box(parent, Vector3(at.x, y, at.y), Vector3(1.33, 0.06, length + 0.06), RACK)
		for edge: float in [-1.0, 1.0]:
			_geometry.box(parent, Vector3(at.x + edge * 0.68, y + 0.028, at.y), Vector3(0.028, 0.045, length), WHITE)
		if decorate or shelf >= 2:
			for place in floori(length / 0.92):
				for side: float in [-1.0, 1.0]:
					var product_height := 0.11 + ((place + shelf + index) % 3) * 0.054
					var z := at.y - length * 0.5 + 0.49 + place * 0.92
					var tint: Color = GOODS[(place + shelf * 2 + index) % GOODS.size()]
					_geometry.box(parent, Vector3(at.x + side * 0.594, y + product_height * 0.5 + 0.032, z),
						Vector3(0.16, product_height, 0.66), tint)
	for front: float in [-1.0, 1.0]:
		_geometry.box(parent, Vector3(at.x, 0.77, at.y + front * length * 0.50), Vector3(1.41, 1.54, 0.16), RACK)
	var sign_at := Vector3(at.x, 2.50, at.y + length * 0.5 + 0.12)
	_geometry.box(parent, sign_at, Vector3(1.79, 0.40, 0.16), _accent)
	_label(parent, sign_at + Vector3.BACK * 0.10, DEPARTMENTS[index % DEPARTMENTS.size()], 16, WHITE)


func _produce(parent: Node3D, at: Vector2) -> void:
	_geometry.box(parent, Vector3(at.x, 0.48, at.y), Vector3(2.25, 0.96, 3.32), Color("#715f49"), true)
	for row in 3:
		for col in 3:
			var p := Vector3(at.x + (col - 1) * 0.72, 1.02, at.y + (row - 1) * 1.05)
			var tint: Color = GOODS[(row * 3 + col + int(absf(at.x))) % GOODS.size()]
			_geometry.box(parent, p, Vector3(0.67, 0.16, 0.96), tint)
			_geometry.box(parent, p + Vector3.UP * 0.081, Vector3(0.57, 0.057, 0.84), tint.lightened(0.22))


func _counter(parent: Node3D, at: Vector2, width: float, title: String, tint: Color) -> void:
	_geometry.box(parent, Vector3(at.x, 0.56, at.y), Vector3(width, 1.12, 0.91), tint, true)
	_geometry.box(parent, Vector3(at.x, 1.15, at.y), Vector3(width + 0.12, 0.13, 1.08), WHITE)
	_geometry.box(parent, Vector3(at.x, 2.45, at.y - 0.33), Vector3(width, 0.40, 0.089), tint)
	_label(parent, Vector3(at.x, 2.45, at.y - 0.274), title, 22, WHITE)
	for i in floori(width / 1.03):
		var x := at.x - width * 0.5 + 0.53 + i * 1.03
		_geometry.box(parent, Vector3(x, 1.26, at.y - 0.14), Vector3(0.76, 0.095, 0.46), GOODS[i % GOODS.size()])


func _freezers(parent: Node3D, midpoint: Vector2, title: String, units: int) -> void:
	_department(parent, midpoint + Vector2(0, 2.28), title, 6.0)
	for i in units:
		var x := midpoint.x + (i - (units - 1) * 0.5) * 2.36
		var z := midpoint.y
		_geometry.box(parent, Vector3(x, 0.48, z), Vector3(2.29, 0.96, 1.12), Color("#bfc9c4"), true)
		_geometry.box(parent, Vector3(x, 0.99, z), Vector3(2.23, 0.08, 1.08), Color("#6a9299"))
		for stripe: float in [-0.39, 0.39]:
			_geometry.box(parent, Vector3(x + stripe, 1.044, z), Vector3(0.039, 0.034, 1.07), CART)


func _carts(parent: Node3D, at: Vector2) -> void:
	for index in 4:
		var z := at.y - index * 0.42
		_geometry.box(parent, Vector3(at.x, 0.52, z), Vector3(0.65, 0.09, 0.74), CART)
		for side: float in [-1.0, 1.0]:
			_geometry.box(parent, Vector3(at.x + side * 0.30, 0.73, z), Vector3(0.054, 0.43, 0.77), CART)
			_geometry.box(parent, Vector3(at.x + side * 0.24, 0.19, z - 0.28), Vector3(0.12, 0.19, 0.13), METAL)
		_geometry.box(parent, Vector3(at.x, 0.96, z + 0.33), Vector3(0.65, 0.041, 0.07), _accent)


func _lighting(parent: Node3D) -> void:
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color("#edeae0")
	lamp.emission_enabled = true
	lamp.emission = Color("#fff5df")
	lamp.emission_energy_multiplier = 0.82
	var aabb := Rect2(footprint[0], Vector2.ZERO)
	for point: Vector2 in footprint:
		aabb = aabb.expand(point)
	for x in range(ceili(aabb.position.x / 7.0) * 7, floori(aabb.end.x), 7):
		for z in range(ceili(aabb.position.y / 7.0) * 7, floori(aabb.end.y), 7):
			var point := Vector2(x, z)
			if not Geometry2D.is_point_in_polygon(point, footprint):
				continue
			if not Geometry2D.is_point_in_polygon(point + Vector2(1.85, 0), footprint) or not Geometry2D.is_point_in_polygon(point - Vector2(1.85, 0), footprint):
				continue
			var at := Vector3(point.x, _height - 0.18, point.y)
			var strip := _geometry.box(parent, at, Vector3(3.66, 0.066, 0.35), WHITE)
			strip.material_override = lamp
			if x % 14 == 0 and z % 14 == 0:
				var light := OmniLight3D.new()
				light.position = at - Vector3.UP * 0.33
				light.omni_range = 14.0
				light.omni_attenuation = 1.1
				light.light_energy = 1.6
				light.light_color = Color("#fff3dd")
				parent.add_child(light)


func _label(parent: Node3D, at: Vector3, title: String, size_on_sign: int, tint: Color, yaw := 0.0) -> void:
	var label := _geometry.signage(parent, at, title, size_on_sign, tint, yaw)
	label.pixel_size = 0.013
	label.shaded = false
	label.double_sided = false

