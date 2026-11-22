extends Node3D

signal build_progress(fraction: float, message: String)

const CityMesh = preload("res://scripts/world/CityMesh.gd")
const StoreSites = preload("res://scripts/world/StoreSites.gd")
const PhotographicFacades = preload("res://scripts/world/PhotographicFacades.gd")
const CityWaters = preload("res://scripts/world/CityWaters.gd")
const CityWeather = preload("res://scripts/world/CityWeather.gd")
const PublicSpaces = preload("res://scripts/world/CityPublicSpaces.gd")
const RoadLamp = preload("res://scripts/world/RoadLamp.gd")
const StreetFixture = preload("res://scripts/world/StreetFixture.gd")
const Geometry = preload("res://scripts/world/Geometry.gd")
const CITY_SURFACE = preload("res://assets/shaders/city_surface.gdshader")
const SKY = preload("res://assets/environment/sky.hdr")
const CITY_GRADE = preload("res://assets/environment/CityGrade.gdshader")
const ApartmentSites = preload("res://scripts/world/ApartmentSites.gd")
const ASPHALT_PHOTO = preload("res://assets/environment/asphalt.jpg")
const TURF_PHOTO = preload("res://assets/environment/turf.jpg")
const ASPEN = preload("res://assets/models/aspen.glb")
const Elevation = preload("res://scripts/world/CityElevation.gd")
const LandmarkArchitecture = preload("res://scripts/world/LandmarkArchitecture.gd")
const DistrictBuildingKit = preload("res://scripts/world/DistrictBuildingKit.gd")
const ReferenceDetails = preload("res://scripts/world/ReferenceDetails.gd")
const RailwayYard = preload("res://scripts/world/RailwayYard.gd")
const MAP_PATH := "res://data/city/mazeikiai.json"
const CADASTRAL_BUILDINGS := "res://data/city/grpk_buildings.json"
const SCHOOL_CAMPUSES := "res://data/city/schools.json"
const TILE_SIZE := 184.0
const LIVE_RADIUS := 2
const ASPHALT := Color(0.177, 0.185, 0.198)
const STONE := Color(0.48, 0.46, 0.425)
const GRASS := Color(0.11, 0.161, 0.065)
const MARKING := Color(0.74, 0.72, 0.63)

var _tiles: Dictionary = {}
var _live: Dictionary = {}
var _pending: Array[Vector2i] = []
var _materials: Array[ShaderMaterial] = []
var _sun: DirectionalLight3D
var _environment: Environment
var _center := Vector2i(999, 999)
var _geometry := Geometry.new()
var _landmark_architecture := LandmarkArchitecture.new()
var _building_kit := DistrictBuildingKit.new()
var _photo_facades := PhotographicFacades.new()
var _reference_details := ReferenceDetails.new()
var _tree_parts: Array = []

var _data: Dictionary
var _town_additions: Dictionary
var _named_shops: Dictionary = {}
var _buildings_by_id: Dictionary = {}
var fuel_stations: Array = []
var _replaced_exteriors: Dictionary = {StoreSites.MAXIMA.building: true}
var _horizon: Node3D
var _far_material: StandardMaterial3D
var _horizon_tiles: Dictionary = {}
var _horizon_pending: Array[Vector2i] = []
var _horizon_origin := Vector2i(999, 999)
var _horizon_radius := 0
var _waters := CityWaters.new()
var _weather: Node3D
var _public_spaces := PublicSpaces.new()
var _underwater_view := false
var _parking_polygons: Array[PackedVector2Array] = []
var _forest_tiles: Dictionary = {}
var _retail_cutouts: Array[Dictionary] = []
var elevation := Elevation.new()
var _network: Array = []
var _schools: Array = []
var broken_lamps: Dictionary = {}
var time_of_day := 0.42
var _lamp_lens: StandardMaterial3D
var _lamp_lights: Array[OmniLight3D] = []
var _birds: AudioStream
var _ambience_focus := Vector3.ZERO
var _ambience_update := 0.0
var _night := 0.0


func build(initial: Vector3, staged := false) -> bool:
	if staged:
		await get_tree().process_frame
	build_progress.emit(0.08, "READING CITY MAP")
	_data = GameManager.read_json(MAP_PATH, {})
	if _data.is_empty():
		return false
	_town_additions = GameManager.read_json("res://data/city/town_additions.json", {})
	fuel_stations = GameManager.read_json("res://data/city/fuel_stations.json", [])
	for site: Dictionary in fuel_stations:
		for id: Variant in site.replace:
			_replaced_exteriors[int(id)] = true
	for shop: Dictionary in _town_additions.get("stores", []):
		_named_shops[int(shop.id)] = shop
	elevation.load_grid()
	_prepare_tree()
	_birds = AssetShelf.sound("birdsong", "res://assets/audio/sfx/birdsong.wav")
	for kind in 5:
		var material := ShaderMaterial.new()
		material.shader = CITY_SURFACE
		material.set_shader_parameter("surface_kind", kind)
		if kind == 2:
			material.set_shader_parameter("ground_photo", ASPHALT_PHOTO)
		elif kind == 4:
			material.set_shader_parameter("ground_photo", TURF_PHOTO)
		_materials.append(material)
	_build_environment()
	_weather = CityWeather.new()
	_weather.name = "Weather"
	add_child(_weather)
	await _index_features(staged)
	_public_spaces.index(TILE_SIZE)
	build_progress.emit(0.32, "BUILDING LANDSCAPE")
	if staged:
		await get_tree().process_frame
	await _build_landscape(staged)
	_horizon = Node3D.new()
	_horizon.name = "DistantCity"
	add_child(_horizon)
	_far_material = StandardMaterial3D.new()
	_far_material.vertex_color_use_as_albedo = true
	_far_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_far_material.roughness = 0.94
	_build_maxima_exterior()
	stream_at(initial, not staged)
	if staged:
		# Build the spawn tile and its eight neighbours before enabling physics.
		var count := mini(1 if OS.has_feature("mobile") else 9, _pending.size())
		for index in count:
			build_progress.emit(0.47 + 0.50 * float(index) / count, "BUILDING STARTING AREA %d / %d" % [index + 1, count])
			await get_tree().process_frame
			await _load_tile(_pending.pop_front(), true)
	var spawn_tile: Node3D = _live.get(_tile_at(Vector2(initial.x, initial.z)))
	if spawn_tile == null:
		return false
	var shape := spawn_tile.get_node_or_null("Ground/StaticBody3D/CollisionShape3D") as CollisionShape3D
	return shape != null and shape.shape != null


func _prepare_tree() -> void:
	var sample := ASPEN.instantiate() as Node3D
	add_child(sample)
	var to_local := sample.global_transform.affine_inverse()
	for mesh: MeshInstance3D in sample.find_children("*", "MeshInstance3D", true, false):
		_tree_parts.append([mesh.mesh, to_local * mesh.global_transform])
	sample.free()


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		_load_tile(_pending.pop_front())
	elif not _horizon_pending.is_empty():
		_load_horizon_tile(_horizon_pending.pop_back())


func stream_at(world_position: Vector3, immediate := false) -> void:
	var tile := _tile_at(Vector2(world_position.x, world_position.z))
	if tile == _center:
		return
	_center = tile
	_pending.clear()
	for loaded: Vector2i in _live.keys():
		if maxi(absi(loaded.x - tile.x), absi(loaded.y - tile.y)) > (1 if SettingsManager.mobile_battery_saver() else LIVE_RADIUS + 1):
			_live[loaded].queue_free()
			_live.erase(loaded)
			if _horizon_tiles.has(loaded):
				_horizon_tiles[loaded].show()
	for radius in range(2 if SettingsManager.mobile_battery_saver() else LIVE_RADIUS + 1):
		for x in range(-radius, radius + 1):
			for z in range(-radius, radius + 1):
				if maxi(absi(x), absi(z)) != radius:
					continue
				var key := tile + Vector2i(x, z)
				if _live.has(key):
					continue
				if immediate and radius <= 1:
					_load_tile(key)
				else:
					_pending.append(key)
	_schedule_horizon()


func _schedule_horizon() -> void:
	if _horizon == null:
		return
	var radius := ceili(SettingsManager.view_distance() / TILE_SIZE)
	if radius == _horizon_radius and _horizon_origin == _center:
		return
	_horizon_radius = radius
	_horizon_origin = _center
	_horizon_pending.clear()
	for key: Vector2i in _horizon_tiles.keys():
		if maxi(absi(key.x - _center.x), absi(key.y - _center.y)) > radius + 1:
			_horizon_tiles[key].queue_free()
			_horizon_tiles.erase(key)
	_horizon.visible = radius > LIVE_RADIUS and not SettingsManager.mobile_battery_saver()
	if not _horizon.visible:
		return
	for ring in range(radius, LIVE_RADIUS, -1):
		for x in range(-ring, ring + 1):
			for z in range(-ring, ring + 1):
				if maxi(absi(x), absi(z)) != ring or Vector2(x, z).length() > radius + 0.75:
					continue
				var key := _center + Vector2i(x, z)
				if _tiles.has(key) and not _horizon_tiles.has(key):
					_horizon_pending.append(key)


func _load_horizon_tile(key: Vector2i) -> void:
	var sector := Node3D.new()
	sector.name = "Distant_%d_%d" % [key.x, key.y]
	_horizon.add_child(sector)
	_horizon_tiles[key] = sector
	sector.visible = not _live.has(key)
	var mesh := CityMesh.new()
	var corner := Vector2(key) * TILE_SIZE
	for x in 3:
		for z in 3:
			var step := TILE_SIZE / 3.0
			var a := corner + Vector2(x, z) * step
			var b := a + Vector2(step, 0)
			var c := a + Vector2(step, step)
			var d := a + Vector2(0, step)
			mesh.quad(elevation.point_at(a), elevation.point_at(b), elevation.point_at(c), elevation.point_at(d), Color("#475139"))
	var data: Dictionary = _tiles[key]
	for road: Array in data.roads:
		if float(road[2]) >= 6.0:
			_surface_strip(mesh, road[0], road[1], float(road[2]), 0.04, Color("#565752"))
	for building: Array in data.buildings:
		if int(building[0]) == StoreSites.MAXIMA.building or _replaced_exteriors.has(int(building[0])):
			continue
		var outline: PackedVector2Array = building[3]
		var base: float = elevation.height_at(building[6])
		var profile: Dictionary = PhotographicFacades.PROFILES.get(int(building[0]), {})
		var height := base + PhotographicFacades.model_height(profile, float(building[1]))
		var paint := Color("#8d8b80") if int(building[2]) != 3 else Color("#765d51")
		for index in outline.size():
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index + 1) % outline.size()]
			mesh.wall(Vector3(a.x, base - 0.3, a.y), Vector3(b.x, base - 0.3, b.y),
				Vector3(b.x, height, b.y), Vector3(a.x, height, a.y), paint)
		mesh.flat_polygon(outline, height, paint.darkened(0.23))
	mesh.make_node(sector, _far_material, false, false)


func map_segments(world_position: Vector3, radius: float) -> Array:
	var position_2d := Vector2(world_position.x, world_position.z)
	var least := _tile_at(position_2d - Vector2.ONE * radius)
	var greatest := _tile_at(position_2d + Vector2.ONE * radius)
	var segments: Array = []
	for x in range(least.x - 1, greatest.x + 2):
		for z in range(least.y - 1, greatest.y + 2):
			var tile := Vector2i(x, z)
			if not _tiles.has(tile):
				continue
			for road: Array in _tiles[tile].roads:
				var closest := Geometry2D.get_closest_point_to_segment(position_2d, road[0], road[1])
				if closest.distance_squared_to(position_2d) < (radius * radius):
					segments.append(road)
	return segments


func map_roads() -> Array:
	return _network


func school_pins() -> Array:
	var pins: Array = []
	for campus: Dictionary in _schools:
		pins.append({"point": _v2(campus.point), "name": campus.name, "home": false, "school": true})
	return pins


func settlement_pins() -> Array:
	var pins: Array = []
	for place: Array in _data.get("settlements", []):
		pins.append({"name": str(place[0]), "point": _v2(place[1]), "home": false})
	pins.append({"name": "Ventos upė", "point": Vector2(-167, 1738), "water": true, "home": false})
	return pins


func additional_pins() -> Array:
	var pins: Array = [
		{"name": "Swift Arena", "point": Vector2(1070.6, 864.7), "home": false},
		{"name": "Geležinkelio g. · Rail Yard", "point": Vector2(247.0, -744.0), "home": false}
	]
	for shop: Dictionary in _named_shops.values():
		pins.append({"name": str(shop.name), "point": _v2(shop.point), "home": false, "shop": true})
	for water: Dictionary in _town_additions.get("named_waters", []):
		pins.append({"name": str(water.name), "point": _v2(water.point), "home": false, "water": true})
	return pins


func park_pins() -> Array:
	return _public_spaces.map_pins()


func map_footprints(area: Rect2) -> Array:
	var first := _tile_at(area.position)
	var last := _tile_at(area.end)
	var footprints: Array = []
	for x in range(first.x - 1, last.x + 2):
		for z in range(first.y - 1, last.y + 2):
			var tile := Vector2i(x, z)
			if _tiles.has(tile):
				for building: Array in _tiles[tile].buildings:
					if area.has_point(building[6]):
						footprints.append(building)
	return footprints


func add_paved_apron(outline: PackedVector2Array) -> void:
	_parking_polygons.append(outline)
	var mesh := CityMesh.new()
	_drape_road(mesh, outline, 0.036, Color(0.229, 0.234, 0.237))
	mesh.make_node(self, _materials[2], false, false)


func building_outline(id: int) -> PackedVector2Array:
	var row: Array = _buildings_by_id.get(id, [])
	return PackedVector2Array() if row.is_empty() else row[3]


func _build_maxima_exterior() -> void:
	var row: Array = _buildings_by_id.get(StoreSites.MAXIMA.building, [])
	if row.is_empty():
		return
	var exterior := Node3D.new()
	exterior.name = "MaximaXXExterior"
	add_child(exterior)
	_build_buildings(exterior, [row])


func add_store_parking(gate: Node3D) -> void:
	var lines := CityMesh.new()
	var walks := CityMesh.new()
	for z: float in [7.3, 18.2]:
		for index in range(-6, 7):
			if abs(index) < 2:
				continue
			var x := float(index) * 2.88
			var length := -4.4 if z > 10.0 else 4.4
			var a := gate.to_global(Vector3(x, 0, z))
			var b := gate.to_global(Vector3(x, 0, z + length))
			_surface_strip(lines, Vector2(a.x, a.z), Vector2(b.x, b.z), 0.11, 0.112, MARKING)
	var near := gate.to_global(Vector3(0, 0, 18.3))
	var far := gate.to_global(Vector3(0, 0, 5.4))
	_surface_strip(walks, Vector2(near.x, near.z), Vector2(far.x, far.z), 3.1, 0.111, STONE)
	for x: float in [-18.0, 16.9]:
		var start := gate.to_global(Vector3(x, 0, 10.0))
		var end := gate.to_global(Vector3(x, 0, 14.8))
		_surface_strip(walks, Vector2(start.x, start.z), Vector2(end.x, end.z), 1.4, 0.118, STONE)
	walks.make_node(self, _materials[3], false, false)
	lines.make_node(self, _materials[0], false, false)


func point_on_ground(point: Vector3, lift := 0.0) -> Vector3:
	return elevation.point_at(Vector2(point.x, point.z), lift)


func street_at(world_position: Vector3, nearby: Array) -> String:
	var location := Vector2(world_position.x, world_position.z)
	var best_distance := 38.0 * 38.0
	var name_on_map := ""
	for segment: Array in nearby:
		if str(segment[5]).is_empty():
			continue
		var closest := Geometry2D.get_closest_point_to_segment(location, segment[0], segment[1])
		var distance := closest.distance_squared_to(location)
		if distance < best_distance:
			best_distance = distance
			name_on_map = segment[5]
	return name_on_map


func _index_features(staged: bool) -> void:
	var deadline := Time.get_ticks_usec() + 10000
	var diner_footprint := StoreSites.burger_footprint()
	_retail_cutouts.append({"polygon": diner_footprint, "rect": _outline_rect(diner_footprint)})
	var supplemental_streets: Array = GameManager.read_json("res://data/city/grpk_streets.json", [])
	for row: Array in _data.get("roads", []) + supplemental_streets:
		if staged and Time.get_ticks_usec() >= deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + 10000
		var width := float(row[0])
		var detail: Dictionary = row[5] if row.size() > 5 else {}
		if str(row[3]) == "Žemaitijos g." and bool(row[2]) and is_equal_approx(width, 7.4):
			width = 13.4
			detail = detail.duplicate()
			detail["boulevard"] = true
		_index_line(row[4], "roads", [width, row[1], row[2], row[3]], detail)
	for row: Array in _data.get("rails", []):
		_index_line(row, "rails", [])
	var supplementary: Dictionary = GameManager.read_json(CADASTRAL_BUILDINGS, {})
	var education: Dictionary = GameManager.read_json(SCHOOL_CAMPUSES, {})
	_schools = education.get("campuses", [])
	var school_by_building: Dictionary = {}
	for campus: Dictionary in _schools:
		for id: Variant in campus.buildings:
			school_by_building[int(id)] = campus
	var rows: Array = _data.get("buildings", []) + education.get("buildings", []) + supplementary.get("buildings", [])
	if not rows.any(func(row: Array) -> bool: return int(row[0]) == StoreSites.MAXIMA.building):
		rows.append(StoreSites.MAXIMA_FOOTPRINT)
	for row: Array in rows:
		if staged and Time.get_ticks_usec() >= deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + 10000
		var poly := _points(row[3])
		if poly.size() < 3:
			continue
		var center := _center_of(poly)
		var bucket := _bucket(_tile_at(center))
		var id := int(row[0])
		if id in [StoreSites.MAXIMA.building, StoreSites.GRUSTE.building, StoreSites.LIDL.building, StoreSites.SENUKAI.building, StoreSites.MAXIMA_DAUKSOS.building]:
			var inset := Geometry2D.offset_polygon(poly, -0.18)
			if inset.size() == 1:
				_retail_cutouts.append({"polygon": inset[0], "rect": _outline_rect(inset[0])})
		var campus: Dictionary = school_by_building.get(id, {})
		var height := float(_town_additions.get("height_overrides", {}).get(str(id), row[1]))
		var label := str(campus.get("name", _named_shops.get(id, {}).get("name", row[4])))
		var building := [id, height, int(row[2]), poly, label, bool(row[5]) and height < 8.0, center, campus]
		bucket.buildings.append(building)
		_buildings_by_id[id] = building
	for row: Array in _data.get("signals", []):
		var position := _v2(row)
		_bucket(_tile_at(position)).signals.append(position)
	for row: Array in _data.get("trees", []):
		var point := _v2(row)
		_bucket(_tile_at(point)).trees.append(point)
	for row: Array in _data.get("crossings", []):
		var point := _v2(row)
		var candidates := map_segments(Vector3(point.x, 0, point.y), 5.5)
		var distance := 5.5 * 5.5
		var crossing: Array = []
		for candidate: Array in candidates:
			if not bool(candidate[3]) or float(candidate[2]) < 4.0:
				continue
			var nearest := Geometry2D.get_closest_point_to_segment(point, candidate[0], candidate[1])
			var separation := nearest.distance_squared_to(point)
			if separation < distance:
				distance = separation
				crossing = [nearest, candidate[0].direction_to(candidate[1]), candidate[2]]
		if not crossing.is_empty():
			_bucket(_tile_at(point)).crossings.append(crossing)


func _index_line(vertices: Array, kind: String, extra: Array, detail := {}) -> void:
	var distance := 0.0
	for index in range(vertices.size() - 1):
		var a := _v2(vertices[index])
		var b := _v2(vertices[index + 1])
		if a.distance_squared_to(b) < 0.04:
			continue
		var pieces := ceili(a.distance_to(b) / 36.0)
		for piece in pieces:
			var start := a.lerp(b, float(piece) / pieces)
			var finish := a.lerp(b, float(piece + 1) / pieces)
			var segment := [start, finish] + extra
			_bucket(_tile_at((start + finish) * 0.5))[kind].append(segment)
			if kind == "roads":
				segment.append(distance)
				segment.append(detail)
				_network.append(segment)
			distance += start.distance_to(finish)


func _bucket(key: Vector2i) -> Dictionary:
	if not _tiles.has(key):
		_tiles[key] = {"roads": [], "rails": [], "buildings": [], "trees": [], "crossings": [], "signals": []}
	return _tiles[key]


func _tile_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / TILE_SIZE), floori(point.y / TILE_SIZE))


func _v2(point: Array) -> Vector2:
	return Vector2(float(point[0]), float(point[1]))


func _points(source: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Array in source:
		var vector := _v2(point)
		if result.is_empty() or result[-1].distance_squared_to(vector) > 0.01:
			result.append(vector)
	if result.size() > 1 and result[-1].distance_squared_to(result[0]) < 0.01:
		result.resize(result.size() - 1)
	return result


func _build_environment() -> void:
	_lamp_lens = StandardMaterial3D.new()
	_lamp_lens.albedo_color = Color("#b7af98")
	_lamp_lens.emission_enabled = true
	_lamp_lens.emission = Color("#ffd597")
	_lamp_lens.emission_energy_multiplier = 0.0
	var scene_environment := WorldEnvironment.new()
	scene_environment.name = "WorldEnvironment"
	_environment = Environment.new()
	var sky := Sky.new()
	var atmosphere := PanoramaSkyMaterial.new()
	atmosphere.panorama = SKY
	atmosphere.energy_multiplier = 0.98
	sky.sky_material = atmosphere
	_environment.background_mode = Environment.BG_SKY
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("#ccc5b7")
	_environment.ambient_light_energy = 0.69
	_environment.ambient_light_sky_contribution = 0.16
	_environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_environment.tonemap_exposure = 0.95
	_environment.tonemap_white = 5.8
	_environment.adjustment_enabled = true
	_environment.adjustment_contrast = 1.035
	_environment.adjustment_saturation = 0.95
	_environment.fog_enabled = true
	_environment.fog_mode = Environment.FOG_MODE_EXPONENTIAL
	_environment.fog_light_color = Color("#a39988")
	_environment.fog_light_energy = 0.91
	_environment.fog_sun_scatter = 0.21
	_environment.fog_density = 0.0025
	_environment.fog_height = -4.0
	_environment.fog_height_density = 0.032
	_environment.fog_sky_affect = 0.18
	scene_environment.environment = _environment
	add_child(scene_environment)
	_sun = DirectionalLight3D.new()
	_sun.name = "DirectionalLight3D"
	_sun.rotation_degrees = Vector3(-36, 37, 0)
	_sun.light_color = Color("#ffdfbc")
	_sun.light_energy = 1.06
	_sun.light_angular_distance = 0.65
	_sun.shadow_bias = 0.028
	_sun.shadow_normal_bias = 0.66
	_sun.directional_shadow_max_distance = 140.0
	add_child(_sun)
	var grade_layer := CanvasLayer.new()
	grade_layer.name = "CityPostProcessing"
	grade_layer.layer = -1
	add_child(grade_layer)
	var fullscreen := ColorRect.new()
	fullscreen.name = "CityGrade"
	fullscreen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grade_layer.add_child(fullscreen)
	fullscreen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var grade := ShaderMaterial.new()
	grade.shader = CITY_GRADE
	fullscreen.material = grade
	for index in 6:
		var streetlight := OmniLight3D.new()
		streetlight.light_color = Color("#ffcf91")
		streetlight.omni_range = 15.0
		streetlight.omni_attenuation = 1.12
		streetlight.hide()
		add_child(streetlight)
		_lamp_lights.append(streetlight)
	_set_sun_and_sky()
	_apply_quality()
	GameManager.settings_changed.connect(_apply_quality)


func update_day(delta: float, focus: Vector3, indoors := false) -> void:
	# The full cycle takes 900 gameplay seconds. Pause stops this update.
	time_of_day = fposmod(time_of_day + delta / 900.0, 1.0)
	_weather.update_weather(delta, focus, indoors or _underwater_view, int(GameManager.settings.weather))
	_ambience_focus = focus
	_ambience_update -= delta
	if _ambience_update > 0.0:
		return
	_ambience_update = 0.23
	_set_sun_and_sky()
	_update_lamp_pool()


func _set_sun_and_sky() -> void:
	var phase := (time_of_day - 0.25) * TAU
	var sun_height := sin(phase)
	var daylight := smoothstep(-0.14, 0.23, sun_height)
	_night = 1.0 - smoothstep(-0.17, 0.12, sun_height)
	var horizon := 1.0 - smoothstep(0.02, 0.46, absf(sun_height))
	_sun.rotation_degrees = Vector3(-5.0 - maxf(0.0, sun_height) * 38.0, lerpf(-78.0, 170.0, time_of_day), 0)
	var cloud := 0.0 if not is_instance_valid(_weather) else maxf(_weather.rain, _weather.snow * 0.68)
	_sun.light_energy = lerpf(0.15, 1.06, daylight) * (1.0 - cloud * 0.57)
	_sun.light_color = Color("#869cbd").lerp(Color("#fff0d9").lerp(Color("#ffbf98"), horizon * 0.59), daylight)
	_environment.background_energy_multiplier = lerpf(0.18, 1.0, daylight) * (1.0 - cloud * 0.30)
	_environment.ambient_light_color = Color("#98aaca").lerp(Color("#c4c9c9"), daylight)
	_environment.ambient_light_energy = lerpf(0.39, 0.69, daylight)
	_environment.fog_light_color = Color("#475870").lerp(Color("#a0a7ab"), daylight).lerp(Color("#abb6bd"), cloud * 0.51)
	var density := float(GameManager.settings.fog_density)
	_environment.fog_density = 0.105 if _underwater_view else maxf(0.0, density * (1.0 + cloud * 0.66))
	_environment.fog_enabled = _environment.fog_density > 0.001 or density > 0.0
	if _underwater_view:
		_environment.fog_light_color = Color("#437b83")
		_environment.fog_light_energy = 0.78
	else:
		_environment.fog_light_energy = 0.91
	_lamp_lens.emission_energy_multiplier = _night * 1.45


func _update_lamp_pool() -> void:
	for light: OmniLight3D in _lamp_lights:
		light.hide()
	if _night < 0.03 or _ambience_focus.y > 100.0 or SettingsManager.mobile_battery_saver():
		return
	var candidates: Array[Node] = get_tree().get_nodes_in_group("working_streetlight").filter(func(lamp: Node3D) -> bool:
		return lamp.global_position.distance_squared_to(_ambience_focus) <= 57.0 ** 2)
	candidates.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(_ambience_focus) < b.global_position.distance_squared_to(_ambience_focus))
	for index in mini(candidates.size(), _lamp_lights.size()):
		var light := _lamp_lights[index]
		light.global_position = candidates[index].lamp_head.global_position - Vector3.UP * 0.22
		light.light_energy = 2.2 * _night
		light.show()


func _apply_quality() -> void:
	var grade: ShaderMaterial = $CityPostProcessing/CityGrade.material
	SettingsManager.apply_city(_environment, _sun, grade, GameManager.settings)
	$CityPostProcessing.visible = not SettingsManager.mobile_battery_saver()
	for tile: Node3D in _live.values():
		_apply_greenery(tile)
		_apply_street_detail(tile)
	_schedule_horizon()


func _build_landscape(staged: bool) -> void:
	var deadline := Time.get_ticks_usec() + 10000
	var park := CityMesh.new()
	for row: Array in _data.get("areas", []):
		if staged and Time.get_ticks_usec() >= deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + 10000
		var tint := Color(0.084, 0.128, 0.057) if int(row[0]) == 1 else Color(0.127, 0.166, 0.094)
		var outline := _points(row[1])
		if outline.size() < 3:
			continue
		var extent := _outline_rect(outline)
		# The underlying terrain already supplies grass. Avoid tessellating large forest overlays.
		if extent.get_area() < (22000.0 if SettingsManager.mobile_battery_saver() else 430000.0):
			_drape_polygon(park, outline, 0.011, tint)
		if int(row[0]) == 1:
			var from := _tile_at(extent.position)
			var to := _tile_at(extent.end)
			for x in range(from.x, to.x + 1):
				for z in range(from.y, to.y + 1):
					var key := Vector2i(x, z)
					_forest_tiles.get_or_add(key, []).append(outline)
	park.make_node(self, _materials[4], false, false)
	var parking := CityMesh.new()
	for row: Array in _data.get("lots", []):
		if staged and Time.get_ticks_usec() >= deadline:
			await get_tree().process_frame
			deadline = Time.get_ticks_usec() + 10000
		var outline := _points(row)
		_parking_polygons.append(outline)
		_drape_polygon(parking, outline, 0.022, Color(0.205, 0.216, 0.225))
	parking.make_node(self, _materials[2], false, false)
	var rivers: Array = GameManager.read_json("res://data/city/river_corridor.json", [])
	_waters.build(self, _data.get("water", []) + rivers + _town_additions.get("waters", []), elevation)
	var yard := RailwayYard.new()
	yard.name = "GelezinkelioYard"
	add_child(yard)
	yard.build(elevation)


func water_sample(at: Vector3) -> Dictionary:
	var point := Vector2(at.x, at.z)
	var water := _waters.surface_at(point)
	if water.is_empty():
		return {}
	var floor := _waters.ground_below(point, elevation.height_at(point))
	return {"level": float(water.level), "bed": floor, "flow": water.flow}


func set_underwater_view(value: bool) -> void:
	if _underwater_view != value:
		_underwater_view = value
		_ambience_update = 0.0


func _load_tile(key: Vector2i, staged := false) -> void:
	var tile := Node3D.new()
	tile.name = "City_%d_%d" % [key.x, key.y]
	add_child(tile)
	_live[key] = tile
	if _horizon_tiles.has(key):
		_horizon_tiles[key].hide()
	var data := _bucket(key)
	_build_ground(tile, key)
	if staged:
		await get_tree().process_frame
	_build_streets(tile, data)
	if staged:
		await get_tree().process_frame
	_build_buildings(tile, data.buildings.filter(func(row: Array) -> bool: return not _replaced_exteriors.has(int(row[0]))))
	if staged:
		await get_tree().process_frame
	_decorate(tile, data, key)
	_public_spaces.build(tile, key, self)
	_reference_details.build(tile, key, data, self, _materials[3])
	for signal_point: Vector2 in data.signals:
		var continuous := map_segments(Vector3(signal_point.x, 0, signal_point.y), 11.5)
		if continuous.is_empty():
			continue
		var nearest: Array = continuous[0]
		for road: Array in continuous:
			if float(road[2]) > float(nearest[2]):
				nearest = road
		var direction: Vector2 = nearest[0].direction_to(nearest[1])
		var curb := signal_point + direction.orthogonal() * (float(nearest[2]) * 0.5 + 0.76)
		if not _building_at(curb, data.buildings) and curb.distance_squared_to(Vector2(369, 335)) > 19.0 ** 2:
			_reference_details.build_signal(tile, self, elevation.point_at(curb, 0.10), -direction)


func _build_ground(tile: Node3D, key: Vector2i) -> void:
	var mesh := CityMesh.new()
	var origin := Vector2(key) * TILE_SIZE
	var dense := _waters.tile_touches_water(key)
	var divisions := (16 if SettingsManager.mobile_battery_saver() else 32) if dense else 8
	var step := TILE_SIZE / divisions
	var tile_rect := Rect2(origin, Vector2.ONE * TILE_SIZE)
	var retail := _retail_cutouts.filter(func(mask: Dictionary) -> bool: return mask.rect.intersects(tile_rect))
	for z in divisions:
		for x in divisions:
			var a := origin + Vector2(x * step, z * step)
			var b := a + Vector2(step, 0)
			var c := a + Vector2(step, step)
			var d := a + Vector2(0, step)
			var pa := _riverbed(a) if dense else elevation.point_at(a)
			var pb := _riverbed(b) if dense else elevation.point_at(b)
			var pc := _riverbed(c) if dense else elevation.point_at(c)
			var pd := _riverbed(d) if dense else elevation.point_at(d)
			if retail.is_empty():
				mesh.quad(pa, pb, pc, pd, GRASS)
			else:
				_retail_terrain_face(mesh, pa, pb, pc, GRASS, retail)
				_retail_terrain_face(mesh, pa, pc, pd, GRASS, retail)
	var ground := mesh.make_node(tile, _materials[4], true, false)
	if ground != null:
		ground.name = "Ground"
		var body := ground.get_child(0)
		body.name = "StaticBody3D"
		body.get_child(0).name = "CollisionShape3D"


func _outline_rect(outline: PackedVector2Array) -> Rect2:
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for vertex: Vector2 in outline:
		bounds = bounds.expand(vertex)
	return bounds


func _retail_terrain_face(mesh: CityMesh, a: Vector3, b: Vector3, c: Vector3, tint: Color, masks: Array) -> void:
	var triangle := PackedVector2Array([Vector2(a.x, a.z), Vector2(b.x, b.z), Vector2(c.x, c.z)])
	var bounds := _outline_rect(triangle)
	var parts: Array[PackedVector2Array] = [triangle]
	var clipped := false
	for mask: Dictionary in masks:
		if not bounds.intersects(mask.rect):
			continue
		var outside: Array[PackedVector2Array] = []
		for polygon: PackedVector2Array in parts:
			outside.append_array(Geometry2D.clip_polygons(polygon, mask.polygon))
		parts = outside
		clipped = true
	if not clipped:
		mesh.triangle(a, b, c, tint)
		return
	var u := triangle[1] - triangle[0]
	var v := triangle[2] - triangle[0]
	var denominator := u.cross(v)
	if absf(denominator) < 0.001:
		return
	for shape: PackedVector2Array in parts:
		var indices := Geometry2D.triangulate_polygon(shape)
		var vertices := PackedVector3Array()
		for point: Vector2 in shape:
			var d := point - triangle[0]
			var y := a.y + (b.y - a.y) * d.cross(v) / denominator + (c.y - a.y) * u.cross(d) / denominator
			vertices.append(Vector3(point.x, y, point.y))
		for i in range(0, indices.size(), 3):
			mesh.triangle(vertices[indices[i]], vertices[indices[i + 1]], vertices[indices[i + 2]], tint)


func _riverbed(point: Vector2) -> Vector3:
	return Vector3(point.x, _waters.ground_below(point, elevation.height_at(point)), point.y)


func _drape_polygon(mesh: CityMesh, outline: PackedVector2Array, lift: float, tint: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(outline)
	for index in range(0, indices.size(), 3):
		_ground_triangle(mesh, outline[indices[index]], outline[indices[index + 1]], outline[indices[index + 2]], lift, tint, 0)


func _ground_triangle(mesh: CityMesh, a: Vector2, b: Vector2, c: Vector2, lift: float, tint: Color, depth: int) -> void:
	if depth < 6 and maxf(a.distance_squared_to(b), maxf(b.distance_squared_to(c), c.distance_squared_to(a))) > 460.0:
		var ab := a.lerp(b, 0.5)
		var bc := b.lerp(c, 0.5)
		var ca := c.lerp(a, 0.5)
		_ground_triangle(mesh, a, ab, ca, lift, tint, depth + 1)
		_ground_triangle(mesh, ab, b, bc, lift, tint, depth + 1)
		_ground_triangle(mesh, ca, bc, c, lift, tint, depth + 1)
		_ground_triangle(mesh, ab, bc, ca, lift, tint, depth + 1)
	else:
		mesh.triangle(elevation.point_at(a, lift), elevation.point_at(b, lift), elevation.point_at(c, lift), tint)


func _surface_strip(mesh: CityMesh, a: Vector2, b: Vector2, width: float, lift: float, tint: Color) -> void:
	var side := a.direction_to(b).orthogonal() * width * 0.5
	_drape_road(mesh, PackedVector2Array([a - side, b - side, b + side, a + side]), lift, tint)


func _surface_disc(mesh: CityMesh, center: Vector2, radius: float, lift: float, tint: Color) -> void:
	var ring := PackedVector2Array()
	for index in 16:
		ring.append(center + Vector2.from_angle(index * TAU / 16.0) * radius)
	_drape_road(mesh, ring, lift, tint)


# Match the terrain's two planes per elevation cell so paint and asphalt stay above every slope break.
func _drape_road(mesh: CityMesh, polygon: PackedVector2Array, lift: float, tint: Color) -> void:
	var extent := Rect2(polygon[0], Vector2.ZERO)
	for point: Vector2 in polygon:
		extent = extent.expand(point)
	var step := Elevation.STEP
	var first := Vector2i((extent.position / step).floor())
	var last := Vector2i((extent.end / step).floor())
	for x in range(first.x, last.x + 1):
		for z in range(first.y, last.y + 1):
			var a := Vector2(x, z) * step
			var b := a + Vector2(step, 0)
			var c := a + Vector2(step, step)
			var d := a + Vector2(0, step)
			for plane: PackedVector2Array in [PackedVector2Array([a, b, c]), PackedVector2Array([a, c, d])]:
				for patch: PackedVector2Array in Geometry2D.intersect_polygons(polygon, plane):
					if patch.size() < 3:
						continue
					if Geometry2D.is_polygon_clockwise(patch):
						patch.reverse()
					var root := elevation.point_at(patch[0], lift)
					for index in range(1, patch.size() - 1):
						mesh.triangle(root, elevation.point_at(patch[index], lift), elevation.point_at(patch[index + 1], lift), tint)


func _build_streets(tile: Node3D, data: Dictionary) -> void:
	var road_mesh := CityMesh.new()
	var curb_mesh := CityMesh.new()
	var curb_edges := CityMesh.new()
	var walks := CityMesh.new()
	var decks := CityMesh.new()
	var lines := CityMesh.new()
	var street_detail := CityMesh.new()
	for segment: Array in data.roads:
		var a: Vector2 = segment[0]
		var b: Vector2 = segment[1]
		var width := float(segment[2])
		var service_lane: bool = str(segment[5]) == "Geležinkelio g." and minf(a.x, b.x) < 176.0
		var paved := bool(segment[3]) and not service_lane
		var lane_marks := bool(segment[4]) and not service_lane
		var detail: Dictionary = segment[7]
		var style := str(detail.get("style", ""))
		var walk := style in ["pavers", "cycle"]
		var color := ASPHALT if paved else Color(0.29, 0.265, 0.205)
		if style == "pavers":
			color = STONE
		elif style == "cycle":
			color = Color("#454b4c")
		if bool(detail.get("bridge", false)):
			_build_bridge(tile, decks, a, b, width, color)
			continue
		var surface := walks if walk else road_mesh
		var lift := 0.104 if walk else 0.084 if paved else 0.071
		_surface_strip(surface, a, b, width, lift, color)
		_surface_disc(surface, a, width * 0.5, lift - 0.002, color)
		_surface_disc(surface, b, width * 0.5, lift - 0.004, color)
		if not paved or width < 5.1 or str(segment[5]).is_empty():
			continue
		var length := a.distance_to(b)
		var direction := a.direction_to(b)
		var across := direction.orthogonal() * (width * 0.5 + 0.74)
		var sidewalk_pieces := maxi(1, ceili(length / 3.4))
		for piece in sidewalk_pieces:
			for sign_value: float in [-1.0, 1.0]:
				var start := a.lerp(b, float(piece) / sidewalk_pieces) + across * sign_value
				var finish := a.lerp(b, float(piece + 1) / sidewalk_pieces) + across * sign_value
				if _road_clear(start.lerp(finish, 0.5), data.roads, 0.21):
					var tangent := start.direction_to(finish) * 0.055
					_surface_strip(curb_mesh, start - tangent, finish + tangent, 1.48, 0.127, STONE)
					if width >= 11.8:
						var brick := direction.orthogonal() * sign_value * 0.56
						_surface_strip(walks, start + brick, finish + brick, 0.24, 0.135, Color("#926459"))
					var edge := direction.orthogonal() * sign_value * 0.69
					_surface_strip(curb_mesh, start - edge, finish - edge, 0.117, 0.146, STONE.lightened(0.16))
					curb_edges.facade(elevation.point_at(start - edge, 0.046), elevation.point_at(finish - edge, 0.046), 0.092, STONE.darkened(0.32))
		if int(segment[6]) % 3 != 1 and length >= 12.0:
			_add_street_surfaces(street_detail, a, b, width, data)
		if lane_marks:
			var offset := fposmod(float(segment[6]), 7.0)
			for dash in range(0, ceili(length) + 7, 7):
				var start := maxf(0.0, dash - offset)
				var finish := minf(length, dash - offset + 2.6)
				if finish - start > 0.05:
					var lane_offsets: Array = [-width * 0.25, width * 0.25] if width >= 11.8 else [0.0]
					for lane: float in lane_offsets:
						var stripe := direction.orthogonal() * lane
						_surface_strip(lines, a + direction * start + stripe, a + direction * finish + stripe, 0.116, 0.114, MARKING)
			if width >= 11.8:
				for edge: float in [-0.13, 0.13]:
					var stripe := direction.orthogonal() * edge
					_surface_strip(lines, a + stripe, b + stripe, 0.106, 0.115, MARKING)
	for rail: Array in data.rails:
		var a: Vector2 = rail[0]
		var b: Vector2 = rail[1]
		_surface_strip(road_mesh, a, b, 3.3, 0.063, Color(0.33, 0.285, 0.255))
		var edge := a.direction_to(b).orthogonal() * 0.73
		for side: float in [-1.0, 1.0]:
			_surface_strip(lines, a + edge * side, b + edge * side, 0.07, 0.078, Color(0.58, 0.58, 0.57))
	for crossing: Array in data.crossings:
		var point: Vector2 = crossing[0]
		var along: Vector2 = crossing[1]
		var across := along.orthogonal()
		var count := maxi(3, floori(float(crossing[2]) / 0.66))
		for index in count:
			var stripe := point + across * (index - (count - 1.0) * 0.5) * 0.66
			_surface_strip(lines, stripe - along * 1.36, stripe + along * 1.36, 0.35, 0.109, MARKING)
	curb_mesh.make_node(tile, _materials[3], false, false)
	curb_edges.make_node(tile, _materials[0], false, false)
	road_mesh.make_node(tile, _materials[2], false, false)
	walks.make_node(tile, _materials[3], false, false)
	decks.make_node(tile, _materials[3], true, true)
	lines.make_node(tile, _materials[0], false, false)
	var street_detail_node := street_detail.make_node(tile, _materials[0], false, false)
	if street_detail_node != null:
		street_detail_node.name = "StreetDetail"
		_apply_street_detail(tile)


func _apply_street_detail(tile: Node3D) -> void:
	var detail := tile.get_node_or_null("StreetDetail") as MeshInstance3D
	if detail == null:
		return
	var distance := SettingsManager.street_detail_distance()
	detail.visible = distance > 0.0
	detail.visibility_range_end = distance


func _add_street_surfaces(mesh: CityMesh, a: Vector2, b: Vector2, width: float, data: Dictionary) -> void:
	var along := a.direction_to(b)
	var cross := along.orthogonal()
	var at := a.lerp(b, 0.54)
	# A worn asphalt repair around an inspection cover.
	var cover := at - cross * width * 0.22
	_surface_strip(mesh, cover - along * 0.82, cover + along * 0.94, 1.18, 0.095, ASPHALT.darkened(0.19))
	_surface_disc(mesh, cover, 0.38, 0.102, Color("#62615b"))
	_surface_disc(mesh, cover, 0.31, 0.107, Color("#393c3b"))
	for row in range(-2, 3):
		var ridge := cover + along * row * 0.105
		_surface_strip(mesh, ridge - cross * 0.19, ridge + cross * 0.19, 0.022, 0.111, Color("#676760"))
	# Storm drains inside the asphalt edge, away from junctions and pedestrian crossings.
	for side: float in [-1.0, 1.0]:
		var outer := at + cross * side * (width * 0.5 + 0.30)
		if not _road_clear(outer, data.roads, 0.12):
			continue
		var drain := outer - cross * side * 0.53
		_surface_strip(mesh, drain - along * 0.32, drain + along * 0.32, 0.36, 0.096, Color("#5f605a"))
		_surface_strip(mesh, drain - along * 0.27, drain + along * 0.27, 0.29, 0.101, Color("#303534"))
		for slot in range(-3, 4):
			var bar := drain + along * slot * 0.070
			_surface_strip(mesh, bar - cross * 0.127, bar + cross * 0.127, 0.022, 0.108, Color("#676c68"))
	if width < 7.0 or a.distance_to(b) < 36.0:
		return
	var verge := a.lerp(b, 0.30) + cross * (width * 0.5 + 2.04)
	if not _road_clear(verge, data.roads, 1.64) or _building_at(verge, data.buildings) or not _plantable(verge) or not _outside_retail(verge):
		return
	var anchor := Transform3D(Basis(Vector3(along.x, 0, along.y), Vector3.UP,
		Vector3(-along.y, 0, along.x)), elevation.point_at(verge))
	var metal := Color("#454d4c")
	var wood := Color("#80674d")
	for leg: float in [-0.65, 0.65]:
		_street_box(mesh, anchor, Vector3(leg, 0.23, 0), Vector3(0.11, 0.50, 0.43), metal)
		_street_box(mesh, anchor, Vector3(leg, 0.68, 0.19), Vector3(0.09, 0.42, 0.08), metal)
	_street_box(mesh, anchor, Vector3(0, 0.49, 0.0), Vector3(1.62, 0.10, 0.48), wood)
	_street_box(mesh, anchor, Vector3(0, 0.78, 0.19), Vector3(1.62, 0.22, 0.09), wood)
	_street_box(mesh, anchor, Vector3(1.31, 0.40, 0), Vector3(0.36, 0.80, 0.37), metal)
	_street_box(mesh, anchor, Vector3(1.31, 0.82, 0), Vector3(0.40, 0.10, 0.40), metal.lightened(0.15))


func _street_box(mesh: CityMesh, anchor: Transform3D, center: Vector3, size: Vector3, tint: Color) -> void:
	var half := size * 0.5
	var corners := PackedVector3Array([
		Vector3(-half.x, -half.y, -half.z), Vector3(half.x, -half.y, -half.z),
		Vector3(half.x, -half.y, half.z), Vector3(-half.x, -half.y, half.z)
	])
	var top := Vector3.UP * size.y
	for index in corners.size():
		var first := anchor * (center + corners[index])
		var second := anchor * (center + corners[(index + 1) % corners.size()])
		mesh.wall(second, first, first + top, second + top, tint)
	mesh.quad(anchor * (center + corners[0]) + top, anchor * (center + corners[1]) + top,
		anchor * (center + corners[2]) + top, anchor * (center + corners[3]) + top, tint.lightened(0.08))


func _build_bridge(tile: Node3D, mesh: CityMesh, a: Vector2, b: Vector2, width: float, tint: Color) -> void:
	var axis := a.direction_to(b)
	var side := axis.orthogonal() * (width * 0.50)
	var start := elevation.height_at(a) + 0.13
	var finish := elevation.height_at(b) + 0.13
	var points := [
		Vector3(a.x - side.x, start, a.y - side.y), Vector3(a.x + side.x, start, a.y + side.y),
		Vector3(b.x + side.x, finish, b.y + side.y), Vector3(b.x - side.x, finish, b.y - side.y)
	]
	mesh.quad(points[0], points[1], points[2], points[3], tint.lightened(0.18))
	for lane: Array in [[points[0], points[3]], [points[1], points[2]]]:
		var first: Vector3 = lane[0]
		var last: Vector3 = lane[1]
		mesh.facade(first - Vector3.UP * 0.22, last - Vector3.UP * 0.22, 0.24, Color("#6e6a61"))
		var rail := _geometry.box(tile, first.lerp(last, 0.5) + Vector3.UP * 0.91,
			Vector3(0.10, 0.095, first.distance_to(last)), Color("#626c70"))
		rail.look_at(last + Vector3.UP * 0.91)
		var posts := maxi(1, ceili(first.distance_to(last) / 2.9))
		for i in range(posts + 1):
			var foot := first.lerp(last, float(i) / posts)
			_geometry.box(tile, foot + Vector3.UP * 0.44, Vector3(0.11, 0.96, 0.10), Color("#626c70"))


func _build_buildings(tile: Node3D, buildings: Array) -> void:
	var walls := CityMesh.new()
	var roofs := CityMesh.new()
	var details := CityMesh.new()
	var palette := [
		Color(0.48, 0.40, 0.30), Color(0.40, 0.40, 0.385), Color(0.42, 0.29, 0.22),
		Color(0.39, 0.42, 0.32), Color(0.42, 0.36, 0.31), Color(0.53, 0.453, 0.38)
	]
	for row: Array in buildings:
		if _landmark_architecture.build(tile, row, elevation, _materials[0]):
			continue
		var outline: PackedVector2Array = row[3]
		if Geometry2D.is_polygon_clockwise(outline):
			outline.reverse()
		var height := float(row[1])
		var label := str(row[4])
		if label.begins_with("Maxima") or label.begins_with("Norfa") or label.begins_with("Rimi"):
			height = minf(height, 6.4)
		var foundation := elevation.height_at(_center_of(outline))
		var roof_level := foundation + height
		var kind := int(row[2])
		var base: Color = palette[posmod(int(row[0]), palette.size())]
		base.a = [0.48, 0.18, 0.74, 0.97][kind]
		if kind == 3:
			base = Color(0.65, 0.38, 0.28, 0.98)
		var home := ApartmentSites.entrance_for(int(row[0]))
		var shop := StoreSites.for_building(int(row[0]))
		var profile: Dictionary = PhotographicFacades.PROFILES.get(int(row[0]), {})
		if not shop.is_empty() and shop.id in ["lidl", "senukai", "maxima_dauksos"]:
			base = Color("#bcbcb2") if shop.id == "lidl" else (Color("#7e3c43") if shop.id == "maxima_dauksos" else Color("#81908e"))
			base.a = 0.13
			if shop.has("hall_height"):
				roof_level = foundation + float(shop.hall_height) + 0.62
		var middle := _center_of(outline)
		var city_block := kind == 0 and height >= 11.0 and absf(middle.x - 260.0) < 990.0 and absf(middle.y - 140.0) < 1260.0
		if city_block and profile.is_empty():
			base = [Color("#aca899"), Color("#b6b2a4"), Color("#b3a994"), Color("#b0aba5")][posmod(int(row[0]), 4)]
			base.a = 0.48
		if not profile.is_empty():
			base = profile.base
			base.a = 0.115
			roof_level = foundation + PhotographicFacades.model_height(profile, height)
		if home.is_empty() and shop.is_empty() and profile.is_empty() and _building_kit.build(tile, row, outline, foundation, height):
			continue
		for index in outline.size():
			var a: Vector2 = outline[index]
			var b: Vector2 = outline[(index + 1) % outline.size()]
			var start := elevation.point_at(a, -0.21)
			var finish := elevation.point_at(b, -0.21)
			var face := base
			if int(row[0]) == StoreSites.MAXIMA.building:
				face = Color(0.31, 0.37, 0.42, 0.12)
			elif int(row[0]) in [StoreSites.RIMI.building, StoreSites.GRUSTE.building]:
				face = Color(0.26, 0.29, 0.31, 0.12)
			elif a.distance_to(b) < 2.9 and kind != 3:
				face.a = 0.12
			if city_block and a.distance_to(b) < 19.0 and a.distance_to(b) > 5.0 and posmod(int(row[0]), 4) == 1:
				face = Color("#a69178")
				face.a = 0.17
			if not home.is_empty():
				var entry: Vector2 = Geometry2D.get_closest_point_to_segment(home.entrance, a, b)
				if entry.distance_squared_to(home.entrance) < 0.01:
					var header := elevation.height_at(entry) + ApartmentSites.FLOOR_OFFSET + ApartmentSites.DOOR_HEIGHT
					_build_entry_wall(walls, start, finish, entry, roof_level, face, ApartmentSites.DOOR_WIDTH, header)
					continue
			if not shop.is_empty():
				var entry: Vector2 = Geometry2D.get_closest_point_to_segment(shop.entrance, a, b)
				if entry.distance_squared_to(shop.entrance) < 0.045:
					var header := elevation.height_at(entry) + float(shop.floor_height) + 2.25
					_build_entry_wall(walls, start, finish, entry, roof_level, face, float(shop.door_width), header)
					continue
			walls.wall(start, finish, Vector3(b.x, roof_level, b.y), Vector3(a.x, roof_level, a.y), face)
			if profile.is_empty() and height > 7.0 and a.distance_to(b) > 3.0:
				var side := -a.direction_to(b).orthogonal() * 0.047
				details.facade(elevation.point_at(a + side, 0.06), elevation.point_at(b + side, 0.06), 0.77, base.darkened(0.32))
				details.facade(Vector3(a.x + side.x, roof_level - 0.17, a.y + side.y), Vector3(b.x + side.x, roof_level - 0.17, b.y + side.y), 0.27, base.darkened(0.45))
				if kind == 0 and height > 8.6 and (int(row[0]) + index) % 3 != 0:
					_balconies(details, a, b, height, foundation, base)
		if not profile.is_empty():
			_photo_facades.decorate(tile, details, outline, foundation, profile)
		var roof_color := Color(0.31, 0.33, 0.33) if height > 8.0 else Color(0.41, 0.34, 0.31)
		if bool(row[5]) and outline.size() == 4:
			_gable(roofs, outline, roof_level, roof_color)
		else:
			roofs.flat_polygon(outline, roof_level, roof_color)
			if city_block:
				_roof_fixtures(roofs, outline, roof_level, roof_color)
		if _named_shops.has(int(row[0])):
			_shopfront(tile, outline, label)
		if "bažnyčia" in label or "kultūros centras" in label or "geležinkelio stotis" in label:
			_landmark(tile, outline, roof_level, label)
	var wall := walls.make_node(tile, _materials[1], true)
	if wall != null:
		wall.get_child(0).add_to_group("city_facade")
	roofs.make_node(tile, _materials[0])
	details.make_node(tile, _materials[0])


func _shopfront(tile: Node3D, outline: PackedVector2Array, title: String) -> void:
	var edge := 0
	for i in outline.size():
		if outline[i].distance_squared_to(outline[(i + 1) % outline.size()]) > outline[edge].distance_squared_to(outline[(edge + 1) % outline.size()]):
			edge = i
	var a := outline[edge]
	var b := outline[(edge + 1) % outline.size()]
	var middle := a.lerp(b, 0.5)
	var normal := a.direction_to(b).orthogonal()
	if Geometry2D.is_point_in_polygon(middle + normal * 0.15, outline):
		normal = -normal
	var anchor := Node3D.new()
	anchor.name = title.to_pascal_case() + "Frontage"
	tile.add_child(anchor)
	anchor.position = elevation.point_at(middle + normal * 0.17, 0.06)
	anchor.rotation.y = atan2(normal.x, normal.y)
	var width := minf(a.distance_to(b) * 0.86, 30.0)
	_geometry.box(anchor, Vector3(0, 1.63, 0.02), Vector3(width, 3.14, 0.16), Color("#596c74"))
	for column in range(-4, 5):
		var x := column * width / 9.0
		_geometry.box(anchor, Vector3(x, 1.70, 0.14), Vector3(0.081, 2.69, 0.07), Color("#b2bdba"))
	_geometry.box(anchor, Vector3(0, 3.21, 0.55), Vector3(width, 0.22, 1.24), Color("#92948a"))
	var sign_tint := Color("#e5cf3d") if title.begins_with("Norfa") else Color("#d7dbb4")
	var panel_tint := Color("#ad3330") if title.begins_with("Norfa") else Color("#264b41")
	_geometry.box(anchor, Vector3(0, 3.86, 0.16), Vector3(minf(width - 0.75, 10.0), 0.92, 0.19), panel_tint)
	_geometry.signage(anchor, Vector3(0, 3.87, 0.275), title.to_upper(), 42, sign_tint)


func _roof_fixtures(mesh: CityMesh, outline: PackedVector2Array, y: float, tint: Color) -> void:
	var center := _center_of(outline)
	for index in outline.size():
		var a := outline[index]
		var b := outline[(index + 1) % outline.size()]
		if a.distance_squared_to(b) < 3.0:
			continue
		mesh.facade(Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), 0.27, tint.lightened(0.17))
		if a.distance_to(b) < 14.5 or index % 2 != 0:
			continue
		var along := a.direction_to(b)
		var inward := along.orthogonal()
		if not Geometry2D.is_point_in_polygon(a.lerp(b, 0.5) + inward * 0.59, outline):
			inward = -inward
		for offset: float in [0.23, 0.53, 0.77]:
			var spot := a.lerp(b, offset) + inward * 2.8
			if not Geometry2D.is_point_in_polygon(spot, outline):
				continue
			var end := spot + along * 1.27
			var over := inward * 0.81
			var points := [spot, end, end + over, spot + over]
			for i in 4:
				var p: Vector2 = points[i]
				var q: Vector2 = points[(i + 1) % 4]
				mesh.facade(Vector3(p.x, y, p.y), Vector3(q.x, y, q.y), 0.54, tint.lightened(0.23))
			mesh.flat_polygon(PackedVector2Array(points), y + 0.54, tint.lightened(0.28))
	if Geometry2D.is_point_in_polygon(center, outline):
		mesh.strip(center + Vector2.LEFT * 0.9, center + Vector2.RIGHT * 0.9, 1.75, y + 0.042, tint.lightened(0.12))


func _build_entry_wall(walls: RefCounted, start: Vector3, finish: Vector3, entry: Vector2, roof: float, tint: Color, width: float, head: float) -> void:
	var direction := Vector2(finish.x - start.x, finish.z - start.z).normalized()
	var left := entry - direction * width * 0.5
	var right := entry + direction * width * 0.5
	var a := elevation.point_at(left, -0.21)
	var b := elevation.point_at(right, -0.21)
	walls.wall(start, a, Vector3(a.x, roof, a.z), Vector3(start.x, roof, start.z), tint)
	walls.wall(b, finish, Vector3(finish.x, roof, finish.z), Vector3(b.x, roof, b.z), tint)
	walls.wall(Vector3(a.x, head, a.z), Vector3(b.x, head, b.z),
		Vector3(b.x, roof, b.z), Vector3(a.x, roof, a.z), tint)


func _balconies(details: CityMesh, a: Vector2, b: Vector2, height: float, foundation: float, tint: Color) -> void:
	var direction := a.direction_to(b)
	var out := -direction.orthogonal() * 0.83
	var length := floori(a.distance_to(b))
	for along in range(4, length - 3, 7):
		var center := a + direction * along
		var start := center - direction * 0.91
		var end := center + direction * 0.91
		for floor_index in range(1, mini(7, floori(height / 3.03))):
			var level := foundation + floor_index * 3.03 + 0.49
			var p := Vector3(start.x, level, start.y)
			var q := Vector3(end.x, level, end.y)
			var r := q + Vector3(out.x, 0, out.y)
			var s := p + Vector3(out.x, 0, out.y)
			details.quad(p, q, r, s, tint.lightened(0.19))
			details.facade(s - Vector3.UP * 0.13, r - Vector3.UP * 0.13, 0.55, tint.darkened(0.22))
			details.facade(r, q, 0.40, tint.darkened(0.22))
			details.facade(p, s, 0.40, tint.darkened(0.22))


func _gable(mesh: CityMesh, outline: PackedVector2Array, height: float, tint: Color) -> void:
	var first := outline[0].distance_squared_to(outline[1])
	var second := outline[1].distance_squared_to(outline[2])
	var offset := 0 if first >= second else 1
	var profile: Array[Vector3] = []
	for index in 4:
		var point: Vector2 = outline[(index + offset) % 4]
		profile.append(Vector3(point.x, height, point.y))
	var rise := Vector3.UP * clampf(sqrt(minf(first, second)) * 0.28, 0.55, 3.2)
	var ridge1 := (profile[3] + profile[0]) * 0.5 + rise
	var ridge2 := (profile[1] + profile[2]) * 0.5 + rise
	mesh.quad(profile[0], profile[1], ridge2, ridge1, tint)
	mesh.quad(ridge1, ridge2, profile[2], profile[3], tint.darkened(0.09))
	mesh.triangle(profile[0], ridge1, profile[3], tint.darkened(0.18))
	mesh.triangle(profile[1], profile[2], ridge2, tint.darkened(0.18))


func _landmark(tile: Node3D, outline: PackedVector2Array, height: float, title: String) -> void:
	var point := _center_of(outline)
	if "bažnyčia" in title:
		_geometry.box(tile, Vector3(point.x, height + 2.6, point.y), Vector3(3.8, 5.2, 3.8), Color("#ac7260"))
		_geometry.taper(tile, Vector3(point.x, height + 9.1, point.y), 7.8, 0.20, 2.7, Color("#666b68"), 4)
		_geometry.box(tile, Vector3(point.x, height + 13.5, point.y), Vector3(0.12, 1.9, 0.12), Color("#716757"))
		_geometry.box(tile, Vector3(point.x, height + 13.7, point.y), Vector3(0.98, 0.11, 0.11), Color("#716757"))


func _center_of(poly: PackedVector2Array) -> Vector2:
	var center := Vector2.ZERO
	for point: Vector2 in poly:
		center += point
	return center / maxf(poly.size(), 1.0)


func _decorate(tile: Node3D, data: Dictionary, key: Vector2i) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash(key)
	var signed: Dictionary = {}
	var trees: Array[Vector2] = []
	for road: Array in data.roads:
		if float(road[2]) < 5.1 or str(road[5]).is_empty():
			continue
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var length := a.distance_to(b)
		if length < 12.0:
			continue
		var side := a.direction_to(b).orthogonal()
		var roadside := a.lerp(b, 0.45) + side * (float(road[2]) * 0.5 + 1.15)
		if _building_at(roadside, data.buildings):
			continue
		if bool(road[4]) and random.randf() < 0.68:
			_lamp(tile, roadside, -side)
		var boulevard := str(road[5]) in ["Žemaitijos g.", "Draugystės g.", "Ventos g.", "Skuodo g.", "Naftininkų g."]
		var interval := 11.0 if boulevard else 22.0
		var along := a.direction_to(b)
		for step in range(1, maxi(2, floori(length / interval))):
			for edge: float in [-1.0, 1.0]:
				var tree_at := a + along * minf(step * interval, length * 0.62) + side * edge * (float(road[2]) * 0.5 + 3.6)
				if (not _building_at(tree_at, data.buildings) and _road_clear(tree_at, data.roads, 2.05)
					and _plantable(tree_at) and not trees.any(func(tree: Vector2) -> bool: return tree.distance_squared_to(tree_at) < 52.0)):
					trees.append(tree_at)
		if bool(road[4]) and not signed.has(road[5]) and length > 23.0:
			signed[road[5]] = true
			var at := roadside + a.direction_to(b) * 7.0
			if not _building_at(at, data.buildings):
				_sign(tile, at, road[5], a.direction_to(b))
	for at: Vector2 in data.trees:
		trees.append(at)
	var corner := Vector2(key) * TILE_SIZE
	if not data.buildings.is_empty():
		for run in 168:
			var at := corner + Vector2(random.randf_range(5.0, TILE_SIZE - 5.0), random.randf_range(5.0, TILE_SIZE - 5.0))
			if not _road_clear(at, data.roads, 2.4) or _building_at(at, data.buildings) or not _plantable(at):
				continue
			if trees.any(func(tree: Vector2) -> bool: return tree.distance_squared_to(at) < 94.0):
				continue
			trees.append(at)
	var woods: Array = _forest_tiles.get(key, [])
	if not woods.is_empty():
		for run in 230:
			var at := corner + Vector2(random.randf_range(4.0, TILE_SIZE - 4.0), random.randf_range(4.0, TILE_SIZE - 4.0))
			var covered := woods.any(func(polygon: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(at, polygon))
			if covered and _road_clear(at, data.roads, 4.0) and not _building_at(at, data.buildings) and _plantable(at):
				if not trees.any(func(tree: Vector2) -> bool: return tree.distance_squared_to(at) < 38.0):
					trees.append(at)
	trees = trees.filter(_outside_retail)
	if not trees.is_empty():
		var trunks := StaticBody3D.new()
		trunks.name = "TreeTrunkColliders"
		trunks.add_to_group("tree_trunks")
		var shape := CylinderShape3D.new()
		shape.radius = 0.19
		shape.height = 2.5
		tile.add_child(trunks)
		var placements: Array[Transform3D] = []
		for at: Vector2 in trees:
			var scale_factor := random.randf_range(0.54, 1.12)
			var basis := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_factor)
			placements.append(Transform3D(basis, elevation.point_at(at)))
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = elevation.point_at(at, 1.21)
			trunks.add_child(collision)
		_draw_trees(tile, placements)
		_draw_understory(tile, trees, data, random)
		_apply_greenery(tile)
		if _birds != null and trees.size() > 2 and posmod(key.x * 13 + key.y * 7, 3) != 0:
			var bird_tree := trees[random.randi_range(0, trees.size() - 1)]
			_place_birds(tile, elevation.point_at(bird_tree, 4.0))


func can_place_market_stall(at: Vector2) -> bool:
	var key := _tile_at(at)
	var roofs := map_footprints(Rect2(at - Vector2.ONE * 45.0, Vector2.ONE * 90.0))
	for corner: Vector2 in [at, at + Vector2(2.13, 1.54), at + Vector2(-2.13, 1.54), at + Vector2(-2.13, -1.54), at + Vector2(2.13, -1.54)]:
		if _building_at(corner, roofs):
			return false
		for x in range(-1, 2):
			for z in range(-1, 2):
				var cell := key + Vector2i(x, z)
				if _tiles.has(cell) and not _road_clear(corner, _tiles[cell].roads, 0.72):
					return false
	return true


func _road_clear(at: Vector2, roads: Array, extra: float) -> bool:
	for road: Array in roads:
		var nearest := Geometry2D.get_closest_point_to_segment(at, road[0], road[1])
		var clearance := float(road[2]) * 0.5 + extra
		if nearest.distance_squared_to(at) < clearance * clearance:
			return false
	return true


func _outside_retail(at: Vector2) -> bool:
	for mask: Dictionary in _retail_cutouts:
		if mask.rect.has_point(at) and Geometry2D.is_point_in_polygon(at, mask.polygon):
			return false
	return true


func footstep_uses_grass(at: Vector3) -> bool:
	var point := Vector2(at.x, at.z)
	var tile: Dictionary = _tiles.get(_tile_at(point), {})
	return _road_clear(point, tile.get("roads", []), 0.95) and _plantable(point)


func _plantable(at: Vector2) -> bool:
	for outline: PackedVector2Array in _parking_polygons:
		if Geometry2D.is_point_in_polygon(at, outline):
			return false
	for outline: PackedVector2Array in _waters.outlines:
		if Geometry2D.is_point_in_polygon(at, outline):
			return false
	return true


func _building_at(at: Vector2, footprints: Array) -> bool:
	for building: Array in footprints:
		if Geometry2D.is_point_in_polygon(at, building[3]):
			return true
	return false


func _lamp(tile: Node3D, at: Vector2, toward: Vector2) -> void:
	var lamp := RoadLamp.new()
	tile.add_child(lamp)
	lamp.build(self, at, toward, _geometry, _lamp_lens)


func _place_birds(tile: Node3D, at: Vector3) -> void:
	var call := AudioStreamPlayer3D.new()
	call.name = "CanopyBirds"
	call.position = at
	call.stream = _birds
	call.bus = &"SFX"
	call.volume_db = -8.0
	call.max_distance = 66.0
	call.unit_size = 7.0
	tile.add_child(call)
	var timer := Timer.new()
	call.add_child(timer)
	timer.timeout.connect(func() -> void:
		if _night < 0.65 and call.global_position.distance_squared_to(_ambience_focus) < 65.0 ** 2:
			call.pitch_scale = randf_range(0.78, 1.18)
			call.play()
		timer.start(randf_range(5.0, 15.5)))
	timer.start(randf_range(0.8, 8.2))


func _draw_understory(tile: Node3D, trees: Array[Vector2], data: Dictionary, random: RandomNumberGenerator) -> void:
	var placements: Array[Transform3D] = []
	for tree: Vector2 in trees:
		for index in random.randi_range(1, 3):
			var angle := random.randf_range(0.0, TAU)
			var point := tree + Vector2.from_angle(angle) * random.randf_range(1.5, 4.8)
			if not _road_clear(point, data.roads, 1.65) or _building_at(point, data.buildings) or not _plantable(point):
				continue
			var width := random.randf_range(0.48, 1.28)
			var height := random.randf_range(0.42, 0.95)
			var basis := Basis(Vector3.UP, angle).scaled(Vector3(width, height, width * 0.76))
			placements.append(Transform3D(basis, elevation.point_at(point, height * 0.24)))
	if placements.is_empty():
		return
	var mesh := SphereMesh.new()
	mesh.radial_segments = 7
	mesh.rings = 3
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	mesh.material = material
	var shrubs := MultiMesh.new()
	shrubs.transform_format = MultiMesh.TRANSFORM_3D
	shrubs.use_colors = true
	shrubs.mesh = mesh
	shrubs.instance_count = placements.size()
	for index in placements.size():
		shrubs.set_instance_transform(index, placements[index])
		shrubs.set_instance_color(index, [Color("#576747"), Color("#69783e"), Color("#456044"), Color("#796948")][index % 4])
	var node := MultiMeshInstance3D.new()
	node.name = "RoadsideShrubs"
	node.set_meta("density_mesh", true)
	node.multimesh = shrubs
	node.visibility_range_end = 170.0
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tile.add_child(node)


func _draw_trees(tile: Node3D, placements: Array[Transform3D]) -> void:
	for part: Array in _tree_parts:
		var local_pose: Transform3D = part[1]
		var instances := MultiMesh.new()
		instances.transform_format = MultiMesh.TRANSFORM_3D
		instances.mesh = part[0]
		instances.instance_count = placements.size()
		for index in placements.size():
			instances.set_instance_transform(index, placements[index] * local_pose)
		var group := MultiMeshInstance3D.new()
		group.set_meta("density_mesh", true)
		group.set_meta("tree_detail", true)
		group.multimesh = instances
		tile.add_child(group)


func _apply_greenery(tile: Node3D) -> void:
	var density := clampf(float(GameManager.settings.greenery_density), 0.20, 0.47 if SettingsManager.mobile_battery_saver() else 1.0)
	for child: Node in tile.get_children():
		if child is MultiMeshInstance3D and child.has_meta("density_mesh"):
			child.multimesh.visible_instance_count = ceili(child.multimesh.instance_count * density)
			if child.has_meta("tree_detail"):
				child.visibility_range_end = 205.0 if int(GameManager.settings.quality) == 0 else 0.0
	var trunks := tile.get_node_or_null("TreeTrunkColliders")
	if trunks != null:
		var visible_count := ceili(trunks.get_child_count() * density)
		for shape: CollisionShape3D in trunks.get_children():
			shape.set_deferred("disabled", shape.get_index() >= visible_count)


func _sign(tile: Node3D, at: Vector2, title: String, forward: Vector2) -> void:
	var fixture := StreetFixture.new()
	fixture.name = "RoadSign"
	tile.add_child(fixture, true)
	var sign := fixture.build(self, elevation.point_at(at), atan2(-forward.x, -forward.y), 2.70, "sign")
	if sign == null:
		return
	var base := Vector3.ZERO
	var angle := 0.0
	var width := clampf(title.length() * 0.143 + 0.33, 1.4, 3.1)
	_geometry.taper(sign, base + Vector3.UP * 1.35, 2.7, 0.043, 0.048, Color("#777f7c"), 6)
	var plate := _geometry.box(sign, base + Vector3.UP * 2.35, Vector3(width, 0.31, 0.065), Color("#2f5368"))
	plate.rotation.y = angle
	var front := plate.basis.z * 0.038
	_geometry.signage(sign, plate.position + front, title, 14, Color("#ecebe0"), angle)
	_geometry.signage(sign, plate.position - front, title, 14, Color("#ecebe0"), angle + PI)
