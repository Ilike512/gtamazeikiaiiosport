extends RefCounted

const Geometry = preload("res://scripts/world/Geometry.gd")
const StreetFixture = preload("res://scripts/world/StreetFixture.gd")
const CityMesh = preload("res://scripts/world/CityMesh.gd")
const MAST_AT := Vector2(418.48, 430.21)
const BILLBOARD_AT := Vector2(384.20, 388.15)
const MAST_HEIGHTS := [0.0, 8.0, 17.0, 27.0, 37.0, 47.0, 57.0, 67.0, 77.0, 87.0, 96.0]
const MAST_SPANS := [8.5, 7.65, 6.55, 5.55, 4.53, 3.72, 3.04, 2.43, 1.91, 1.43, 1.0]
const LINEN := Color("#bcb7a5")
const BRICK := Color("#b1906d")
const GRAPHITE := Color("#303a3c")

var _geometry := Geometry.new()


func build(tile: Node3D, key: Vector2i, data: Dictionary, district: Node3D, stone: Material) -> void:
	var details := Node3D.new()
	details.name = "ReferenceStreetscape"
	tile.add_child(details)
	if _key(MAST_AT) == key:
		_build_mast(details, district)
	if _key(BILLBOARD_AT) == key:
		_build_junction_screen(details, district)
	for point: Vector2 in [Vector2(361.3, 337.1), Vector2(365.1, 327.5),
			Vector2(375.4, 332.3), Vector2(371.6, 342.9)]:
		if _key(point) == key:
			var toward := (Vector2(369.1, 335.1) - point).normalized()
			build_signal(details, district, district.point_on_ground(Vector3(point.x, 0, point.y), 0.12), toward)
	_promenade(details, data, district, stone)
	for stop: Vector2 in [Vector2(-127.1, 44.8), Vector2(-62.0, 251.0), Vector2(956.0, 576.0)]:
		if _key(stop) == key:
			_zemaitijos_shelter(details, district, stop)
	if _key(Vector2(-290.9, -156.4)) == key:
		_zemaitijos_refuge(details, district, stone)
	if _key(Vector2(302.8, 282.4)) == key:
		_secondhand_frontage(details, district)
	if _key(Vector2(509.4, -640.2)) == key:
		_station_forecourt(details, district)
	if _key(Vector2(801.3, 1292.4)) == key:
		_park_overlook(details, district)
		_pond_edge(details, district)
	_geometry.batch_static(details)


func _build_junction_screen(parent: Node3D, district: Node3D) -> void:
	var roof: float = district.elevation.height_at(Vector2(399.7, 399.0)) + 9.5
	var roof_mount := _anchor(parent, Vector3(BILLBOARD_AT.x, roof, BILLBOARD_AT.y), 2.79)
	roof_mount.name = "Junction2goScreens"
	_geometry.box(roof_mount, Vector3(0, 0.19, 0), Vector3(2.5, 0.38, 2.54), GRAPHITE)
	for direction: float in [0.0, PI * 0.5]:
		var side := _anchor(roof_mount, Vector3.ZERO, direction)
		var dark := Color("#263334")
		_geometry.box(side, Vector3(0, 1.68, 1.30), Vector3(6.45, 2.94, 0.19), dark)
		var panel := _geometry.box(side, Vector3(0, 1.68, 1.412), Vector3(6.22, 2.73, 0.028), Color("#27b4aa"))
		var material := panel.material_override.duplicate() as StandardMaterial3D
		material.emission_enabled = true
		material.emission = Color("#1ba89e")
		material.emission_energy_multiplier = 0.48
		panel.material_override = material
		var title := _geometry.signage(side, Vector3(0, 1.70, 1.44), "2go", 66, Color("#1a3445"))
		title.pixel_size = 0.017


func _station_forecourt(parent: Node3D, district: Node3D) -> void:
	var at := Vector2(509.4, -640.2)
	var plaza := _anchor(parent, district.point_on_ground(Vector3(at.x, 0, at.y), 0.08), -0.55)
	plaza.name = "GelezinkelioStotiesAikste"
	var stone := Color("#9c9081")
	var bronze := Color("#8c7753")
	_geometry.taper(plaza, Vector3(0, 0.09, 0), 0.18, 3.95, 3.95, Color("#9d9885"), 24)
	_geometry.taper(plaza, Vector3(0, 0.48, 0), 0.86, 2.76, 2.55, stone, 24)
	_geometry.taper(plaza, Vector3(0, 0.90, 0), 0.12, 2.84, 2.84, stone.lightened(0.13), 24)
	_geometry.taper(plaza, Vector3(0, 0.98, 0), 0.035, 2.62, 2.62, Color("#486f71"), 24)
	var tiers := [Vector2(1.12, 1.71), Vector2(0.77, 2.35), Vector2(0.48, 2.91)]
	for tier: Vector2 in tiers:
		_geometry.taper(plaza, Vector3(0, tier.y, 0), 0.39, tier.x, tier.x * 0.25, bronze, 14)
		_geometry.taper(plaza, Vector3(0, tier.y - 0.26, 0), 0.67, 0.142, 0.29, bronze, 10)
	_geometry.taper(plaza, Vector3(0, 3.16, 0), 0.27, 0.083, 0.15, bronze, 9)
	for x: float in [-5.25, 5.25]:
		_lantern(_anchor(plaza, Vector3(x, 0, -0.45)))
	for i in 5:
		var x := -4.8 + i * 2.4
		_geometry.taper(plaza, Vector3(x, 0.33, 4.1), 0.66, 0.076, 0.102, GRAPHITE, 8)


func _park_overlook(parent: Node3D, district: Node3D) -> void:
	var at := Vector2(801.3, 1292.4)
	var floor: Vector3 = district.point_on_ground(Vector3(at.x, 0, at.y), 0.12)
	var overlook := _anchor(parent, floor, 1.82)
	overlook.name = "JuodpelkioShoreOverlook"
	var plank := Color("#806d54")
	_geometry.box(overlook, Vector3(0, -0.16, -0.11), Vector3(3.88, 0.21, 8.16), plank, true)
	for n in 17:
		var z := -3.95 + n * 0.48
		_geometry.box(overlook, Vector3(0, 0, z), Vector3(3.9, 0.145, 0.466), plank.lightened((n % 3) * 0.045))
	for side: float in [-1.0, 1.0]:
		for n in 5:
			var z := -3.81 + n * 1.9
			_geometry.box(overlook, Vector3(side * 1.90, 0.49, z), Vector3(0.105, 0.96, 0.105), GRAPHITE)
		_geometry.box(overlook, Vector3(side * 1.90, 0.96, 0), Vector3(0.105, 0.07, 7.72), plank.lightened(0.16))
		_geometry.box(overlook, Vector3(side * 1.90, 0.57, 0), Vector3(0.064, 0.054, 7.72), GRAPHITE)
	_bench(_anchor(overlook, Vector3(0, 0.085, -2.68), PI))
	_lantern(_anchor(overlook, Vector3(-1.54, 0.09, 3.27)))
	var label := _geometry.signage(overlook, Vector3(0, 2.1, -3.53), "JUODPELKIO PARKAS", 17, Color("#e4dfc4"))
	label.pixel_size = 0.009


func _pond_edge(parent: Node3D, district: Node3D) -> void:
	# Place the shore features from the mapped pond contour.
	var pond: Dictionary = district.water_sample(Vector3(916, 0, 1367))
	if pond.is_empty():
		return
	var water_y := float(pond.level)
	var fountain := Node3D.new()
	parent.add_child(fountain)
	fountain.position = Vector3(916, water_y + 0.10, 1367)
	_geometry.taper(fountain, Vector3.ZERO, 0.18, 2.4, 2.43, Color("#536869"), 16)
	for arm in 8:
		var angle := arm * TAU / 8.0
		var point := Vector3(cos(angle), 0, sin(angle))
		_beam(fountain, point * 1.63 + Vector3.UP * 0.10, point * 0.56 + Vector3.UP * 1.27, 0.095, Color("#9acbd0"))
	_geometry.batch_static(fountain)


func _key(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / 184.0), floori(point.y / 184.0))


func _anchor(parent: Node3D, at: Vector3, heading := 0.0) -> Node3D:
	var anchor := Node3D.new()
	anchor.position = at
	anchor.rotation.y = heading
	parent.add_child(anchor)
	return anchor


func _promenade(parent: Node3D, data: Dictionary, district: Node3D, material: Material) -> void:
	var paving := CityMesh.new()
	var lamps := 0
	for road: Array in data.roads:
		if str(road[5]) != "Laisvės g." or float(road[2]) < 7.0:
			continue
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var middle := a.lerp(b, 0.5)
		if middle.y > -390.0 or middle.y < -885.0:
			continue
		var direction := a.direction_to(b)
		var across := direction.orthogonal()
		var span := a.distance_to(b)
		var inner := float(road[2]) * 0.5 + 2.03
		var edge := float(road[2]) * 0.5 + 3.20
		var pieces := maxi(1, ceili(span / 5.0))
		for side: float in [-1.0, 1.0]:
			for part in pieces:
				var from := a.lerp(b, float(part) / pieces)
				var to := a.lerp(b, float(part + 1) / pieces)
				var sidewalk := from.lerp(to, 0.5) + across * edge * side
				if not district._road_clear(sidewalk, data.roads, 0.80) or district._building_at(sidewalk, data.buildings):
					continue
				var offset := across * inner * side
				district._surface_strip(paving, from + offset, to + offset, 2.55, 0.137, LINEN)
				var center := across * (edge + 0.72) * side
				district._surface_strip(paving, from + center, to + center, 1.78, 0.138, BRICK)
			var first := fposmod(-float(road[6]), 18.7)
			for index in range(ceili(span / 18.7)):
				var along := first + index * 18.7
				if along < 2.0 or along > span - 2.0:
					continue
				var point := a + direction * along + across * (inner - 0.53) * side
				if not district._road_clear(point, data.roads, 1.15) or district._building_at(point, data.buildings):
					continue
				var toward := across * side
				var anchor := _anchor(parent, district.point_on_ground(Vector3(point.x, 0, point.y), 0.134),
					atan2(toward.x, toward.y))
				if lamps % 2 == 0:
					_lantern(anchor)
				else:
					_tree_guard(anchor)
					var bench := point - direction * 2.9
					if district._road_clear(bench, data.roads, 1.04):
						_bench(_anchor(parent, district.point_on_ground(Vector3(bench.x, 0, bench.y), 0.138), anchor.rotation.y))
				lamps += 1
	var node := paving.make_node(parent, material, false, false)
	if node != null:
		node.name = "LaisvesBrickPromenade"


func _zemaitijos_shelter(parent: Node3D, district: Node3D, reference: Vector2) -> void:
	var closest := INF
	var center := reference
	var direction := Vector2.RIGHT
	for road: Array in district.map_segments(Vector3(reference.x, 0, reference.y), 52.0):
		if str(road[5]) != "Žemaitijos g.":
			continue
		var edge := Geometry2D.get_closest_point_to_segment(reference, road[0], road[1])
		var distance := edge.distance_squared_to(reference)
		if distance >= closest:
			continue
		closest = distance
		var axis: Vector2 = road[0].direction_to(road[1])
		direction = axis.orthogonal()
		if direction.dot(reference - edge) < 0.0:
			direction = -direction
		center = edge + direction * (float(road[2]) * 0.5 + 2.75)
	if is_inf(closest):
		return
	var stop := _anchor(parent, district.elevation.point_at(center, 0.09), atan2(-direction.x, -direction.y))
	stop.name = "ZemaitijosBusShelter"
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#86a8a166")
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.18
	var frame := Color("#626d68")
	_geometry.box(stop, Vector3(0, 0.035, 0), Vector3(6.8, 0.07, 3.08), LINEN, true)
	for x: float in [-2.46, 0.0, 2.46]:
		for z: float in [-0.73, 0.73]:
			_geometry.box(stop, Vector3(x, 1.21, z), Vector3(0.063, 2.42, 0.069), frame)
	for x: float in [-1.24, 1.24]:
		_geometry.box(stop, Vector3(x, 1.29, -0.73), Vector3(2.39, 1.88, 0.035), frame).material_override = glass
	for x: float in [-2.45, 2.45]:
		_geometry.box(stop, Vector3(x, 1.29, -0.03), Vector3(0.035, 1.88, 1.36), frame).material_override = glass
	_geometry.box(stop, Vector3(0, 2.40, -0.04), Vector3(5.42, 0.12, 1.91), frame)
	var seat := _anchor(stop, stop.to_global(Vector3(0, 0, -0.44)))
	_bench(seat)
	_geometry.box(stop, Vector3(3.09, 1.36, 0.75), Vector3(0.057, 2.72, 0.057), frame)
	_geometry.box(stop, Vector3(3.09, 2.46, 0.76), Vector3(0.43, 0.48, 0.074), Color("#225395"))
	_geometry.signage(stop, Vector3(3.09, 2.46, 0.807), "BUS", 23, Color.WHITE)
	_geometry.batch_static(stop)


func _zemaitijos_refuge(parent: Node3D, district: Node3D, material: Material) -> void:
	var direction := Vector2(0.66, 0.75)
	var cross := direction.orthogonal()
	var center := Vector2(-290.9, -156.4)
	var layout := CityMesh.new()
	for side: float in [-1.0, 1.0]:
		var start := center + direction * side * 1.45
		var end := center + direction * side * 4.05
		district._surface_strip(layout, start, end, 1.26, 0.111, Color("#a5a08e"))
		district._surface_strip(layout, start + direction * side * 0.22, end, 1.04, 0.125, Color("#586241"))
		for stripe in 10:
			var at := center + cross * side * (1.10 + stripe * 0.78)
			district._surface_strip(layout, at - direction * 1.44, at + direction * 1.44, 0.34, 0.109, Color("#d9d6c7"))
		var anchor_at := center + cross * side * 9.04 + direction * side * 0.77
		var sign := _anchor(parent, district.point_on_ground(Vector3(anchor_at.x, 0, anchor_at.y), 0.08),
			atan2(direction.x * side, direction.y * side))
		_geometry.box(sign, Vector3(0, 1.12, 0), Vector3(0.055, 2.24, 0.055), Color("#959b95"))
		_geometry.box(sign, Vector3(0, 2.25, 0), Vector3(0.47, 0.47, 0.046), Color("#235d9f"))
		_geometry.signage(sign, Vector3(0, 2.27, 0.031), "▲", 25, Color.WHITE)
		_geometry.batch_static(sign)
	layout.make_node(parent, material, false, false)


func _secondhand_frontage(parent: Node3D, district: Node3D) -> void:
	var front := Vector2(0.343, -0.939)
	var center := Vector2(302.8, 282.4) - front * 0.29
	var ground: float = district.elevation.height_at(Vector2(334.7, 255.0))
	var shop := _anchor(parent, Vector3(center.x, ground, center.y), atan2(-front.x, -front.y))
	shop.name = "ZemaitijosSecondHandFrontage"
	var anthracite := Color("#464c4d")
	_geometry.box(shop, Vector3(0, 3.47, 0.14), Vector3(14.6, 0.84, 0.31), anthracite)
	_geometry.signage(shop, Vector3(0, 3.5, 0.315), "Second Hand", 35, Color("#e5e1d3"))
	for bay in 7:
		var x := (bay - 3) * 2.08
		_geometry.box(shop, Vector3(x, 1.63, 0.047), Vector3(2.0, 2.66, 0.31), Color("#d8d3c4"))
		_geometry.box(shop, Vector3(x, 1.65, 0.218), Vector3(1.83, 2.38, 0.035), Color("#657679"))
		_geometry.box(shop, Vector3(x, 1.65, 0.244), Vector3(0.053, 2.38, 0.034), anthracite)
	for panel in 30:
		var x := 8.5 + panel * 0.34
		_geometry.box(shop, Vector3(x, 2.38, 0.16), Vector3(0.33, 4.02, 0.31),
			Color("#8b8678").darkened(0.08 * (panel % 3)))
	_geometry.box(shop, Vector3(13.1, 4.45, 0.49), Vector3(10.05, 0.34, 1.25), Color("#9f7b3e"))
	_geometry.batch_static(shop)


func _bench(anchor: Node3D) -> void:
	var wood := Color("#855d44")
	for x: float in [-0.67, 0.67]:
		_geometry.box(anchor, Vector3(x, 0.23, 0), Vector3(0.065, 0.47, 0.53), GRAPHITE)
		_geometry.box(anchor, Vector3(x, 0.65, -0.23), Vector3(0.062, 0.56, 0.07), GRAPHITE)
	for index in 4:
		_geometry.box(anchor, Vector3(0, 0.47, -0.17 + index * 0.12), Vector3(1.78, 0.065, 0.11), wood)
		_geometry.box(anchor, Vector3(0, 0.64 + index * 0.075, -0.245), Vector3(1.78, 0.069, 0.044), wood)


func _tree_guard(anchor: Node3D) -> void:
	_geometry.box(anchor, Vector3(0, 0.013, 0), Vector3(0.94, 0.026, 0.94), Color("#6d604d"))
	for corner: Vector2 in [Vector2(-0.34, -0.34), Vector2(0.34, -0.34), Vector2(0.34, 0.34), Vector2(-0.34, 0.34)]:
		_beam(anchor, Vector3(corner.x, 0, corner.y), Vector3(corner.x * 0.83, 1.25, corner.y * 0.83), 0.026, GRAPHITE)
	for height: float in [0.65, 1.23]:
		for side: float in [-1.0, 1.0]:
			_geometry.box(anchor, Vector3(0, height, 0.30 * side), Vector3(0.62, 0.032, 0.032), GRAPHITE)
			_geometry.box(anchor, Vector3(0.30 * side, height, 0), Vector3(0.032, 0.032, 0.62), GRAPHITE)
	_geometry.taper(anchor, Vector3(0, 1.60, 0), 3.2, 0.043, 0.07, Color("#64523d"), 7)
	for index in 5:
		var angle := index * 2.39996
		var offset := Vector3(cos(angle), 0, sin(angle)) * 0.37
		_geometry.taper(anchor, offset + Vector3.UP * (2.85 + index * 0.16), 1.12, 0.15, 0.64,
			Color("#3f6535").lightened((index % 3) * 0.044), 8)


func _lantern(anchor: Node3D) -> void:
	_geometry.taper(anchor, Vector3(0, 1.93, 0), 3.86, 0.044, 0.078, GRAPHITE, 9)
	_beam(anchor, Vector3(0, 3.64, 0), Vector3(0, 3.99, -0.53), 0.072, GRAPHITE)
	_beam(anchor, Vector3(0, 3.99, -0.53), Vector3(0, 3.86, -0.83), 0.067, GRAPHITE)
	_geometry.taper(anchor, Vector3(0, 3.77, -0.83), 0.18, 0.09, 0.28, GRAPHITE, 9)
	_geometry.taper(anchor, Vector3(0, 3.665, -0.83), 0.055, 0.22, 0.21, Color("#dfd5a7"), 11)


func build_signal(parent: Node3D, district: Node3D, at: Vector3, toward: Vector2) -> void:
	var pole := StreetFixture.new()
	pole.name = "TrafficLight"
	parent.add_child(pole, true)
	var head := pole.build(district, at, atan2(toward.x, toward.y), 3.26, "signal")
	if head == null:
		return
	_geometry.taper(head, Vector3(0, 1.42, 0), 2.84, 0.052, 0.067, Color("#5c6665"), 8)
	_geometry.box(head, Vector3(0, 2.73, 0.07), Vector3(0.38, 1.09, 0.30), GRAPHITE)
	var colors := [Color("#ec4842"), Color("#f2b839"), Color("#43cf6b")]
	var lamps: Array[MeshInstance3D] = []
	for index in 3:
		var y := 3.07 - 0.33 * index
		var lens := _geometry.taper(head, Vector3(0, y, 0.232), 0.037, 0.093, 0.098, colors[index], 10)
		lens.rotation.x = PI * 0.5
		lamps.append(lens)
		var hood := _geometry.box(head, Vector3(0, y + 0.105, 0.276), Vector3(0.29, 0.045, 0.23), GRAPHITE)
		hood.rotation.x = 0.12
	pole.cycle_lamps(lamps, 0.0 if absf(toward.x) > absf(toward.y) else 10.0)


func _build_mast(parent: Node3D, district: Node3D) -> void:
	var mast := _anchor(parent, district.point_on_ground(Vector3(MAST_AT.x, 0, MAST_AT.y), 0.07))
	mast.name = "MazeikiuRRSCommunicationsMast"
	var white := Color("#c9cac0")
	var red := Color("#91403a")
	_geometry.box(mast, Vector3(0, 0.19, 0), Vector3(11.3, 0.38, 11.3), Color("#87877a"), true)
	for tier in range(MAST_HEIGHTS.size() - 1):
		var lower := float(MAST_HEIGHTS[tier])
		var higher := float(MAST_HEIGHTS[tier + 1])
		var width := float(MAST_SPANS[tier]) * 0.5
		var upper_width := float(MAST_SPANS[tier + 1]) * 0.5
		var color := white if tier % 2 == 0 else red
		for side in 3:
			var leg := Vector2.from_angle(side * TAU / 3.0)
			var next := Vector2.from_angle((side + 1) * TAU / 3.0)
			var a := Vector3(leg.x * width, lower, leg.y * width)
			var b := Vector3(next.x * width, lower, next.y * width)
			var c := Vector3(leg.x * upper_width, higher, leg.y * upper_width)
			var d := Vector3(next.x * upper_width, higher, next.y * upper_width)
			_beam(mast, a, c, 0.28 if tier < 3 else 0.155, color)
			_beam(mast, a, b, 0.14, color)
			var mid_a := a.lerp(c, 0.5)
			var mid_b := b.lerp(d, 0.5)
			_beam(mast, a, mid_b, 0.103, color)
			_beam(mast, b, mid_a, 0.103, color)
			_beam(mast, mid_a, d, 0.091, color)
			_beam(mast, mid_b, c, 0.091, color)
	for y: float in [37, 57, 77, 90]:
		var deck := _geometry.box(mast, Vector3(0, y, 0), Vector3(4.8 - y * 0.032, 0.16, 3.48 - y * 0.021), GRAPHITE)
		deck.rotation.y = y * 0.09
		var dish := _geometry.taper(mast, Vector3(1.35, y + 0.76, 0), 0.27, 0.37, 0.87, white, 14)
		dish.rotation.z = PI * 0.5
	_geometry.taper(mast, Vector3(0, 97.45, 0), 5.6, 0.059, 0.13, red, 8)
	var beacon := _geometry.taper(mast, Vector3(0, 100.15, 0), 0.29, 0.17, 0.17, Color("#f65b48"), 8)
	var emission := beacon.material_override.duplicate() as StandardMaterial3D
	emission.emission_enabled = true
	emission.emission = Color("#ed3e25")
	beacon.material_override = emission


func _beam(parent: Node3D, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	var segment := _geometry.box(parent, a.lerp(b, 0.5), Vector3(width, a.distance_to(b), width), color)
	segment.basis = Basis(Quaternion(Vector3.UP, a.direction_to(b)))

