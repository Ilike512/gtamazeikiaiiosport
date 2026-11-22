extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const Apartment = preload("res://scripts/world/ApartmentInterior.gd")
const ApartmentSites = preload("res://scripts/world/ApartmentSites.gd")
const RetailHall = preload("res://scripts/world/RetailHall.gd")
const Maxima = preload("res://scripts/world/MaximaFrontage.gd")
const Sites = preload("res://scripts/world/StoreSites.gd")
const SlidingEntrance = preload("res://scripts/world/SlidingEntrance.gd")
const Product = preload("res://scripts/world/ProductModel.gd")
const Market = preload("res://scripts/world/MarketStalls.gd")
const Retail = preload("res://scripts/world/CityRetailFronts.gd")
const Diner = preload("res://scripts/world/EifelisDiner.gd")

const PLACES := {
	"maxima": Sites.MAXIMA,
	"rovana": Sites.ROVANA,
	"rimi": Sites.RIMI,
	"gruste": Sites.GRUSTE,
	"lidl": Sites.LIDL,
	"maxima_dauksos": Sites.MAXIMA_DAUKSOS,
	"senukai": Sites.SENUKAI,
	"swedbank": {
		"name": "Swedbank", "address": "Žemaitijos g. 1A",
		"entrance": Vector2(-345.0, -265.9), "outside": Vector2(-345.0, -263.1), "heading": 0.0,
		"aisles": 0, "span": 28.0, "depth": 24.0, "color": Color("#9b632f"), "bank": true
	},
	"sed": {
		"name": "SED", "address": "Senamiesčio kvartalas",
		"entrance": Vector2(797.4, -875.6), "outside": Vector2(797.4, -872.8), "heading": 0.0,
		"aisles": 0, "span": 23.0, "depth": 24.0, "color": Color("#3f6e57"), "bank": true
	},
	"culture": {
		"name": "Kultūros centras", "address": "Naftininkų g.",
		"entrance": Vector2(435.0, 222.7), "outside": Vector2(431.3, 220.8), "heading": -PI / 2,
		"aisles": 0, "span": 21.0, "color": Color("#536a74")
	},
	"burger": Sites.BURGER
}

var _district: Node3D
var _geometry := Geometry.new()
var _rooms: Dictionary = {}
var _homes: Dictionary = {}
var _doors: Dictionary = {}
var _sliding: Dictionary = {}
var _checkouts: Dictionary = {}
var _bank_targets: Dictionary = {}
var groceries: Array[Dictionary] = []
var _halls: Dictionary = {}
var _markets: Node3D
var _retail := Retail.new()


func build(district: Node3D, staged := false) -> void:
	_district = district
	_markets = Market.new()
	_markets.name = "MarketStalls"
	add_child(_markets)
	_markets.build(district)
	_retail.build_corner_shops(self, district.elevation)
	for id: String in PLACES:
		if staged:
			await get_tree().process_frame
		var spec: Dictionary = PLACES[id]
		var floor_point: Vector3 = _district.elevation.point_at(spec.entrance, 0.025)
		var gate := Node3D.new()
		gate.position = floor_point
		gate.rotation.y = spec.heading
		add_child(gate)
		_doors[id] = gate
		if id == "maxima":
			var frontage := Maxima.new()
			add_child(frontage)
			frontage.build(gate, _district)
			_sliding[id] = frontage.doorway
			_build_hall(id)
			continue
		if id == "rimi":
			_sliding[id] = _retail.build_rimi(gate, spec)
			var pavement := PackedVector2Array()
			for local: Vector3 in [Vector3(-17, 0, 0.32), Vector3(20.2, 0, 0.32), Vector3(19, 0, 14.8), Vector3(-16, 0, 15.2)]:
				var at := gate.to_global(local)
				pavement.append(Vector2(at.x, at.z))
			_district.add_paved_apron(pavement)
			_build_room(id)
			continue
		if id == "gruste":
			_sliding[id] = _retail.build_gruste(gate, spec, _district.elevation)
			var forecourt := PackedVector2Array()
			for local: Vector3 in [Vector3(-46, 0, 0.3), Vector3(5.5, 0, 0.3), Vector3(5.5, 0, 19.3), Vector3(-46, 0, 18.2)]:
				var at := gate.to_global(local)
				forecourt.append(Vector2(at.x, at.z))
			_district.add_paved_apron(forecourt)
			var parking_marker := Node3D.new()
			gate.add_child(parking_marker)
			parking_marker.position.x = -20.5
			_district.add_store_parking(parking_marker)
			_build_hall(id)
			continue
		if id in ["lidl", "senukai", "maxima_dauksos"]:
			_build_anchor_store(id, gate, spec)
			continue
		if id == "burger":
			var diner := Diner.new()
			diner.name = "EifelisBurgerStotis"
			gate.add_child(diner)
			diner.build(gate, _district.elevation)
			_rooms[id] = diner
			_sliding[id] = diner.doors
			_checkouts[id] = diner.checkout
			continue
		if id == "rovana":
			_build_rovana_front(gate)
			_build_room(id)
			continue
		if id == "culture":
			_district.add_paved_apron(PackedVector2Array([
				Vector2(423.5, 207.8), Vector2(438.7, 216.1), Vector2(442.0, 233.1),
				Vector2(424.4, 242.4), Vector2(413.5, 229.0)
			]))
			continue
		_geometry.box(gate, Vector3(0, 1.38, 0.09), Vector3(3.52, 2.77, 0.23), Color("#30424a"))
		for side: float in [-1.0, 1.0]:
			var pane := _geometry.box(gate, Vector3(side * 0.83, 1.27, 0.223), Vector3(1.52, 2.4, 0.06), Color("#536f7b"), true)
			pane.get_child(0).add_to_group("breakable_fixture")
			_geometry.box(gate, Vector3(side * 0.09, 1.22, 0.275), Vector3(0.035, 0.38, 0.055), Color("#ced2d0"))
		_geometry.box(gate, Vector3(0, 2.96, 0.11), Vector3(4.40, 0.56, 0.36), spec.color)
		_geometry.signage(gate, Vector3(0, 2.96, 0.326), str(spec.name).to_upper(), 30, Color.WHITE)


	for id: String in ApartmentSites.HOMES:
		var spec: Dictionary = ApartmentSites.HOMES[id]
		var apartment := Apartment.new()
		apartment.name = id
		apartment.rotation.y = spec.heading
		apartment.position = _district.elevation.point_at(spec.entrance, ApartmentSites.FLOOR_OFFSET)
		apartment.position -= apartment.basis.z * ApartmentSites.THRESHOLD_Z
		add_child(apartment)
		apartment.build(spec.resident, spec.color)
		_homes[id] = apartment


func home_at(at: Vector3) -> String:
	for id: String in _homes:
		if _homes[id].contains(at):
			return id
	return ""


func home_camera_distance(id: String, at: Vector3) -> float:
	var home: Node3D = _homes[id]
	var local := home.to_local(at)
	return lerpf(2.25, 4.5, smoothstep(3.2, ApartmentSites.THRESHOLD_Z, local.z))


func home_door_at(at: Vector3) -> Node3D:
	for home: Node3D in _homes.values():
		if home.door_near(at) != null:
			return home
	return null


func update_store_doors(foot: Vector3, driving: bool) -> void:
	for door: Node3D in _sliding.values():
		door.update_proximity(foot, driving)
	for id: String in _halls:
		if foot.distance_squared_to(_doors[id].global_position) < 78.0 ** 2:
			_halls[id].build_fixtures(groceries)


func walk_in_at(at: Vector3) -> String:
	for id: String in _sliding:
		if _halls.has(id):
			if _halls[id].contains(at):
				return id
			continue
		var local: Vector3 = _rooms[id].to_local(at)
		var spec: Dictionary = PLACES[id]
		if absf(local.x) < float(spec.span) * 0.5 - 0.04 and absf(local.z) < float(spec.depth) * 0.5 and local.y > -0.35 and local.y < 3.9:
			return id
	return ""


func walk_in_prompt(at: Vector3) -> String:
	for id: String in _sliding:
		var p: Vector3 = _sliding[id].to_local(at)
		if p.z >= -0.2 and p.z < 4.3 and absf(p.x) < 3.4 and absf(p.y) < 2.5:
			return name_of(id)
	return ""


func _build_anchor_store(id: String, gate: Node3D, spec: Dictionary) -> void:
	var accent: Color = spec.color
	var tint := Color("#efd13c") if id == "lidl" else Color("#eef1ee")
	var sliding := SlidingEntrance.new()
	sliding.position = Vector3(0, spec.floor_height, 0.035)
	gate.add_child(sliding)
	sliding.build(spec.door_width, 2.23, Color("#89a4b066"))
	sliding.build_approach(_district.elevation, 2.65, float(spec.threshold_depth) - 0.07)
	_sliding[id] = sliding
	var fascia_span := 44.0 if id == "lidl" else 35.0
	var siding := Color("#c9d0d0") if id == "lidl" else (Color("#87343b") if id == "maxima_dauksos" else Color("#798886"))
	for course in 4:
		_geometry.box(gate, Vector3(0, 2.88 + course * 0.46, 0.064), Vector3(fascia_span, 0.418, 0.14),
			siding.darkened(course * 0.023))
	for side: float in [-1.0, 1.0]:
		for window in 4:
			var x := side * (4.0 + window * 2.63)
			_geometry.box(gate, Vector3(x, 1.47, 0.129), Vector3(2.4, 1.79, 0.085), Color("#557079"))
			_geometry.box(gate, Vector3(x, 1.47, 0.186), Vector3(0.057, 1.79, 0.042), Color("#c5cccb"))
	_geometry.box(gate, Vector3(0, 2.73, 0.57), Vector3(7.25, 0.17, 1.72), Color("#333d41"))
	_geometry.box(gate, Vector3(0, 3.46, 0.16), Vector3(7.8, 1.06, 0.26), accent)
	_geometry.signage(gate, Vector3(0, 3.52, 0.326), str(spec.name).to_upper(), 54, tint)
	_geometry.signage(gate, Vector3(0, 2.59, 1.451), "ĮĖJIMAS", 17, Color("#edeae0"))
	for side: float in [-1.0, 1.0]:
		_geometry.box(gate, Vector3(side * (spec.door_width * 0.5 + 0.12), 1.28, 0.14),
			Vector3(0.17, 2.71, 0.29), Color("#565f62"))
	var apron := PackedVector2Array()
	for corner: Vector3 in [Vector3(-5.5, 0, 0.07), Vector3(5.5, 0, 0.07),
		Vector3(5.5, 0, 5.7), Vector3(-5.5, 0, 5.7)]:
		var at := gate.to_global(corner)
		apron.append(Vector2(at.x, at.z))
	_district.add_paved_apron(apron)
	_build_hall(id)


func _build_rovana_front(gate: Node3D) -> void:
	var facade := Color("#a6a1a0")
	var gray := Color("#383d3c")
	_geometry.box(gate, Vector3(0, 2.97, 0.14), Vector3(10.7, 0.51, 0.38), facade)
	for side: float in [-1.0, 1.0]:
		_geometry.box(gate, Vector3(3.03 * side, 1.42, 0.13), Vector3(4.24, 2.83, 0.24), facade)
		_geometry.box(gate, Vector3(2.61 * side, 1.5, 0.268), Vector3(2.83, 1.86, 0.04), Color("#476175"))
		for mullion: float in [-0.48, 0.48]:
			_geometry.box(gate, Vector3(2.61 * side + mullion, 1.50, 0.29), Vector3(0.061, 1.87, 0.037), gray)
		_geometry.box(gate, Vector3(side * 1.04, 1.45, 0.24), Vector3(0.15, 2.56, 0.35), gray)
	_geometry.box(gate, Vector3(1.46, 2.95, 0.37), Vector3(5.01, 0.57, 0.17), Color("#222a2b"))
	_geometry.signage(gate, Vector3(1.46, 3.03, 0.465), "ROVANA", 31, Color.WHITE)
	_geometry.signage(gate, Vector3(1.46, 2.77, 0.465), "ŽŪKLĖ IR LAISVALAIKIS", 9, Color("#d3ded4"))
	var sliding := SlidingEntrance.new()
	sliding.position = Vector3(0, Sites.ROVANA.floor_height, 0.12)
	gate.add_child(sliding)
	sliding.build(Sites.ROVANA.door_width, 2.2, Color("#7fa4bd93"))
	_sliding.rovana = sliding
	var ramp := _geometry.box(gate, Vector3(0, 0.14, 1.13), Vector3(2.17, 0.12, 2.30), facade, true)
	ramp.rotation.x = 0.16


func gate_at(position_nearby: Vector3, distance := 4.6) -> String:
	var point := Vector2(position_nearby.x, position_nearby.z)
	for id: String in PLACES:
		if _sliding.has(id):
			continue
		var door: Node3D = _doors[id]
		if absf(position_nearby.y - door.position.y) < 2.5 and point.distance_to(PLACES[id].entrance) <= distance and door.to_local(position_nearby).z > -0.38:
			return id
	return ""


func outside_point(id: String) -> Vector3:
	return _district.elevation.point_at(PLACES[id].outside, 0.06)


func enter(id: String) -> Vector3:
	if not _rooms.has(id):
		_build_room(id)
	return _rooms[id].global_position + Vector3(0, 0.08, float(PLACES[id].get("depth", 20.0)) * 0.5 - 2.7)


func room_exit_near(id: String, player_position: Vector3) -> bool:
	var center: Vector3 = _rooms[id].global_position
	return player_position.distance_to(center + Vector3(0, 0.3, float(PLACES[id].get("depth", 20.0)) * 0.5 - 1.5)) <= 2.7


func checkout_near(id: String, player_position: Vector3) -> bool:
	if _halls.has(id):
		return _halls[id].checkout_near(player_position)
	return _checkouts.has(id) and player_position.distance_to(_checkouts[id]) < 2.7


func stock_for(id: String) -> Node3D:
	return _halls[id].stock if _halls.has(id) else null


func shop_ground(id: String, at: Vector3) -> Vector3:
	return _halls[id].grounded(at) if _halls.has(id) else at


func is_bank(id: String) -> bool:
	return bool(PLACES.get(id, {}).get("bank", false))


func bank_target_near(id: String, where: Vector3, index: int) -> bool:
	if not _bank_targets.has(id) or index < 0 or index >= _bank_targets[id].size():
		return false
	return where.distance_to(_bank_targets[id][index].global_position) < 2.15


func bank_target_position(id: String, index: int) -> Vector3:
	return _bank_targets[id][index].global_position


func animate_bank_pickup(id: String, index: int, at: Vector3) -> void:
	var pickup: Node3D = _bank_targets[id][index].get_node("Cash")
	pickup.show()
	var gather := pickup.create_tween().set_trans(Tween.TRANS_CUBIC)
	gather.tween_property(pickup, "global_position", at + Vector3.UP * 1.1, 0.64)
	gather.tween_callback(pickup.hide)


func set_bank_progress(id: String, index: int) -> void:
	for item: int in _bank_targets.get(id, []).size():
		var token: Node3D = _bank_targets[id][item]
		if item == index:
			var cash := token.get_node("Cash") as Node3D
			cash.position = Vector3.ZERO
			cash.show()
		token.visible = item == index


func name_of(id: String) -> String:
	return str(PLACES[id].name)


func map_pins() -> Array:
	var pins: Array = [
		{"point": Vector2(459, 308), "name": "Šv. Pranciškaus bažnyčia", "home": false},
		{"point": Vector2(944, -892), "name": "Švč. Jėzaus Širdies bažnyčia", "home": false},
		{"point": Vector2(916, -1057), "name": "Mažeikių muziejus", "home": false},
		{"point": Vector2(518, 355), "name": "IKI · Sedos g. 18", "home": false},
		{"point": Vector2(674, -857), "name": "Henriko Nagio biblioteka", "home": false},
		{"point": Vector2(-5.9, 224.8), "name": "Šiaulių Bankas · Žemaitijos g. 20", "home": false},
		{"point": Vector2(-20.5, 231.0), "name": "Baras · Žemaitijos g. 20", "home": false}
	]
	for id: String in PLACES:
		var place: Dictionary = PLACES[id]
		var title := "%s · %s" % [place.name, place.address] if id in ["gruste", "maxima", "swedbank", "lidl", "senukai", "maxima_dauksos"] else str(place.name)
		pins.append({"point": place.entrance, "name": title, "home": false, "shop": true, "primary": id == "maxima"})
	for site: Dictionary in ApartmentSites.HOMES.values():
		pins.append({"point": site.entrance, "name": site.name, "home": true})
	for market: Dictionary in Market.POINTS:
		pins.append({"point": market.center, "name": market.name, "home": false})
	pins.append_array(_district.school_pins())
	pins.append_array(_district.park_pins())
	pins.append_array(_district.additional_pins())
	pins.append_array(_retail.shop_pins())
	return pins


func _build_hall(id: String) -> void:
	var spec: Dictionary = PLACES[id]
	var hall := RetailHall.new()
	hall.name = id.capitalize() + "Interior"
	hall.position.y = float(spec.floor_height)
	_doors[id].add_child(hall)
	hall.build_shell(spec, _district.building_outline(int(spec.building)))
	_rooms[id] = hall
	_halls[id] = hall
	if id == "maxima":
		var vestibule := Node3D.new()
		vestibule.name = "MaximaVestibule"
		vestibule.position.z = -8.8
		hall.add_child(vestibule)
		Maxima.fit_vestibule(vestibule, _geometry)


func _build_room(id: String) -> void:
	var spec: Dictionary = PLACES[id]
	var origin := Vector3(float(PLACES.keys().find(id)) * 65.0, 212.0, 0.0)
	var room := Node3D.new()
	room.name = id.capitalize() + "Interior"
	var seamless := spec.has("room_offset")
	if seamless:
		var gate: Node3D = _doors[id]
		room.position = spec.room_offset
		gate.add_child(room)
	else:
		room.position = origin
		add_child(room)
	_rooms[id] = room
	var span := float(spec.span)
	var side := span * 0.5
	var finish := Color("#d0caba")
	var ceiling := Color("#dedbd1")
	var frame := Color("#424951")
	var gray := Color("#a2a29a")
	var depth := float(spec.get("depth", 20.0))
	var front := depth * 0.5
	_geometry.box(room, Vector3(0, -0.16, 0), Vector3(span, 0.32, depth + 0.24), gray, true)
	_geometry.box(room, Vector3(0, 4.4, 0), Vector3(span, 0.3, depth), ceiling, true)
	for sign_x: float in [-1.0, 1.0]:
		_geometry.box(room, Vector3(sign_x * side, 2.16, 0), Vector3(0.25, 4.32, depth), finish, true)
	_geometry.box(room, Vector3(0, 2.16, -front), Vector3(span, 4.32, 0.25), finish, true)
	if seamless:
		var gap := float(spec.door_width)
		var width := (span - gap) * 0.5
		for sign_x: float in [-1.0, 1.0]:
			_geometry.box(room, Vector3(sign_x * (gap + width) * 0.5, 2.16, front), Vector3(width, 4.32, 0.22), finish, true)
		_geometry.box(room, Vector3(0, 3.38, front), Vector3(gap, 1.88, 0.22), finish, true)
	else:
		_geometry.box(room, Vector3(0, 2.16, front), Vector3(span, 4.32, 0.25), finish, true)
		_geometry.box(room, Vector3(0, 1.38, front - 0.16), Vector3(3.5, 2.75, 0.11), frame)
		_geometry.box(room, Vector3(0, 1.42, front - 0.23), Vector3(3.19, 2.46, 0.11), Color("#64838a"))
	_geometry.signage(room, Vector3(0, 2.66, front - 0.14), "IŠĖJIMAS", 20, Color("#c8f3d8"), PI)
	if id == "rovana":
		_make_gear_store(room)
		return
	for line in range(-4, 5):
		_geometry.box(room, Vector3(0, 0.002, line * 2.0), Vector3(span - 0.12, 0.006, 0.023), Color("#787f7d"))
	for line in range(-4, 5):
		_geometry.box(room, Vector3(line * span / 10.0, 0.004, 0), Vector3(0.025, 0.006, 19.9), Color("#777e7c"))
	var lights := [Vector3(-side * 0.57, 3.98, -4), Vector3(side * 0.57, 3.98, -4),
		Vector3(-side * 0.55, 3.98, 5), Vector3(side * 0.55, 3.98, 5)]
	for place: Vector3 in lights:
		_geometry.box(room, place + Vector3.UP * 0.24, Vector3(2.41, 0.14, 0.29), Color("#f1eee2"))
		var light := OmniLight3D.new()
		light.position = place
		light.light_energy = 0.67
		light.light_color = Color("#fff0df")
		light.omni_range = 15.0
		light.omni_attenuation = 1.33
		room.add_child(light)
	_geometry.box(room, Vector3(0, 3.63, -9.61), Vector3(span - 1.0, 0.45, 0.085), spec.color)
	_geometry.signage(room, Vector3(0, 3.63, -9.54), str(spec.name).to_upper(), 27, Color.WHITE)
	if int(spec.aisles) > 0:
		_make_shop(room, spec, id)
	elif is_bank(id):
		_make_bank(room, id, spec.color)
	else:
		_make_lobby(room, side)
	_geometry.batch_static(room)


func _make_shop(room: Node3D, spec: Dictionary, id: String) -> void:
	var aisles := int(spec.aisles)
	var palette := [Color("#805b56"), Color("#799366"), Color("#9e8356"), Color("#487d8f"), Color("#9b8c7e")]
	for row in aisles:
		var x := (row - (aisles - 1) * 0.5) * 3.65
		_geometry.box(room, Vector3(x, 0.81, -1.5), Vector3(0.27, 1.63, 8.35), Color("#605f5b"), true)
		for shelf in 4:
			var y := 0.16 + shelf * 0.39
			_geometry.box(room, Vector3(x, y, -1.5), Vector3(1.19, 0.058, 8.41), Color("#a9a7a0"), shelf == 0)
			if id == "maxima":
				continue
			for box_index in 10:
				for face: float in [-1.0, 1.0]:
					var product := Vector3(x + face * 0.39, y + 0.14, -5.10 + box_index * 0.73)
					_geometry.box(room, product, Vector3(0.26, 0.23, 0.36), palette[(row * 3 + shelf + box_index) % palette.size()])
		var sign := _geometry.box(room, Vector3(x, 2.35, 2.76), Vector3(1.26, 0.27, 0.14), spec.color)
		_geometry.signage(room, sign.position + Vector3.BACK * 0.105, ["DARŽOVĖS", "DUONA", "GĖRIMAI", "KAVA", "PIENAS"][row], 10, Color.WHITE)
	var till := Vector3(-float(spec.span) * 0.23, 0.9, 5.2)
	_geometry.box(room, till, Vector3(2.65, 0.89, 0.89), spec.color, true)
	_geometry.box(room, till + Vector3(0.54, 0.58, 0), Vector3(0.72, 0.42, 0.11), Color("#323b40"))
	_geometry.signage(room, till + Vector3(0, 1.12, 0.1), "KASA", 22, Color("#fff3cc"))
	_checkouts[id] = room.to_global(till + Vector3(0, 0, 1.35))


func _make_gear_store(room: Node3D) -> void:
	var walnut := Color("#644c3d")
	_geometry.box(room, Vector3(0, 0.55, -1.92), Vector3(6.95, 1.1, 0.89), walnut, true)
	var case_top := _geometry.box(room, Vector3(0, 1.24, -1.92), Vector3(6.95, 0.29, 0.79), Color("#83a8a34d"))
	case_top.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_geometry.box(room, Vector3(0, 1.86, -3.48), Vector3(6.92, 1.49, 0.22), Color("#4c5751"))
	_geometry.signage(room, Vector3(0, 2.92, -3.3), "SPORTO INVENTORIUS", 23, Color("#e9dbab"))
	for index in 5:
		var item := Product.new()
		room.add_child(item)
		item.position = Vector3((index - 2) * 1.25, 1.18, -1.90)
		item.rotation.y = PI * 0.30
		item.build({"id": "sample", "model": "replica" if index < 3 else "carbine"}, 0.46 if index < 3 else 0.83)
	for side: float in [-1.0, 1.0]:
		var lamp := OmniLight3D.new()
		lamp.position = Vector3(side * 2.1, 3.7, -0.15)
		lamp.light_color = Color("#fff0cb")
		lamp.light_energy = 1.13
		lamp.omni_range = 8.1
		room.add_child(lamp)
	_checkouts.rovana = room.to_global(Vector3(0.0, 0.70, -0.25))
	_geometry.batch_static(room)


func _make_bank(room: Node3D, id: String, accent: Color) -> void:
	var side := float(PLACES[id].span) * 0.5
	_geometry.box(room, Vector3(0, 0.013, 3.0), Vector3(4.8, 0.02, 14.8), accent.darkened(0.48))
	for sign_x: float in [-1.0, 1.0]:
		for booth in 3:
			var at := Vector3(sign_x * (side - 2.35), 0.61, -4.6 + booth * 4.1)
			_geometry.box(room, at, Vector3(2.36, 1.22, 1.42), Color("#aaa79f"), true)
			_geometry.box(room, at + Vector3(0, 0.72, 0), Vector3(2.41, 0.13, 1.48), Color("#e8e0d2"))
			_geometry.box(room, at + Vector3(0.26, 0.97, 0.16), Vector3(0.57, 0.40, 0.09), Color("#37434e"))
			_geometry.box(room, at + Vector3(sign_x * 1.56, 0.51, -0.85), Vector3(0.05, 2.12, 2.9), Color("#7aa0a462"))
			_geometry.signage(room, at + Vector3(0, 1.59, 0.21), "0%d" % (booth + 1), 23, accent)
		_geometry.box(room, Vector3(sign_x * (side - 3.1), 0.33, 7.3), Vector3(3.6, 0.54, 0.83), accent, true)
		_geometry.box(room, Vector3(sign_x * (side - 3.1), 0.75, 7.6), Vector3(3.6, 0.55, 0.23), accent.darkened(0.10))
	for desk in range(-1, 2):
		_geometry.box(room, Vector3(desk * 2.6, 1.83, -7.33), Vector3(2.2, 1.04, 0.052), Color("#8daead75"))
		_geometry.box(room, Vector3(desk * 2.6 - 0.53, 1.54, -7.14), Vector3(0.60, 0.45, 0.07), Color("#32434d"))
	_geometry.box(room, Vector3(0, 0.62, -7.2), Vector3(8.5, 1.25, 1.3), accent.darkened(0.39), true)
	_geometry.box(room, Vector3(0, 1.27, -7.2), Vector3(8.6, 0.10, 1.36), Color("#d7d5ca"), true)
	_geometry.signage(room, Vector3(0, 2.47, -9.49), "KLIENTŲ APTARNAVIMAS", 21, Color("#343635"))
	var targets: Array[Node3D] = []
	for at: Vector3 in [Vector3(-5.6, 0.9, 2.1), Vector3(4.4, 0.9, -4.6), Vector3(-1.0, 0.9, -5.3)]:
		var token := Node3D.new()
		token.position = at
		room.add_child(token)
		var bills := Node3D.new()
		bills.name = "Cash"
		token.add_child(bills)
		for note in 4:
			_geometry.box(bills, Vector3(0.032 * note, 0.012 * note, 0), Vector3(0.23, 0.014, 0.104), Color("#83ac83"))
		var label := Label3D.new()
		label.position.y = 0.30
		label.text = "◆"
		label.modulate = Color("#ffc77d")
		label.pixel_size = 0.009
		label.font_size = 52
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		token.add_child(label)
		token.hide()
		targets.append(token)
	_bank_targets[id] = targets


func _make_lobby(room: Node3D, side: float) -> void:
	var rug := Color("#885b53")
	_geometry.box(room, Vector3(0, 0.006, 0), Vector3(4.2, 0.014, 15.2), rug)
	_geometry.box(room, Vector3(0, 0.52, -7.68), Vector3(11.6, 1.08, 3.9), Color("#8f7060"), true)
	_geometry.signage(room, Vector3(0, 2.45, -8.89), "BILIETAI   /   INFORMACIJA", 23, Color("#f1dbc0"))
	for direction: float in [-1.0, 1.0]:
		for row in 3:
			var at := Vector3(direction * side * 0.71, 0.53, row * 4.5 - 4.5)
			_geometry.box(room, at, Vector3(0.67, 0.48, 2.73), Color("#69534d"), true)
			_geometry.box(room, at + Vector3(direction * 0.31, 0.32, 0), Vector3(0.14, 0.78, 2.73), Color("#69534d"))

