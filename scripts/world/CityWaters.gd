extends RefCounted

const WaterSurface = preload("res://assets/shaders/city_water.gdshader")
const CityMesh = preload("res://scripts/world/CityMesh.gd")
const TILE_METRES := 184.0

var outlines: Array[PackedVector2Array] = []
var _tiles: Dictionary = {}


func build(parent: Node3D, mapped: Array, elevation: RefCounted) -> void:
	var surface := CityMesh.new()
	for row: Variant in mapped:
		var points: Array = row.points if row is Dictionary else row
		var flowing := row is Dictionary and bool(row.get("flowing", false))
		var polygon := PackedVector2Array()
		var levels: Array[float] = []
		for point: Array in points:
			var sample := Vector2(float(point[0]), float(point[1]))
			polygon.append(sample)
			levels.append(elevation.height_at(sample))
		if polygon.size() < 3 or Geometry2D.triangulate_polygon(polygon).is_empty():
			continue
		outlines.append(polygon)
		levels.sort()
		var level := levels[floori((levels.size() - 1) * (0.42 if flowing else 0.69))] + (0.035 if flowing else 0.10)
		var bounds := Rect2(polygon[0], Vector2.ZERO)
		for point: Vector2 in polygon:
			bounds = bounds.expand(point)
		var entry := {"polygon": polygon, "level": level, "shape": bounds, "depth": 2.9 if flowing else 3.45,
			"flow": Vector2(0.48, -0.20) if flowing else Vector2.ZERO}
		var low := _key(bounds.position - Vector2.ONE * 7.0)
		var high := _key(bounds.end + Vector2.ONE * 7.0)
		for x in range(low.x, high.x + 1):
			for z in range(low.y, high.y + 1):
				var key := Vector2i(x, z)
				if not _tiles.has(key):
					_tiles[key] = []
				_tiles[key].append(entry)
		surface.flat_polygon(polygon, level, Color(0.15, 0.32, 0.38, 1.0 if flowing else 0.0))
	var material := ShaderMaterial.new()
	material.shader = WaterSurface
	var node: MeshInstance3D = surface.make_node(parent, material, false, false)
	if node != null:
		node.name = "LakesAndRivers"


func tile_touches_water(key: Vector2i) -> bool:
	return _tiles.has(key)


func surface_at(at: Vector2) -> Dictionary:
	for entry: Dictionary in _tiles.get(_key(at), []):
		if entry.shape.has_point(at) and Geometry2D.is_point_in_polygon(at, entry.polygon):
			return entry
	return {}


func ground_below(at: Vector2, original: float) -> float:
	var water := surface_at(at)
	if water.is_empty():
		return original
	var polygon: PackedVector2Array = water.polygon
	var shore := INF
	for index in polygon.size():
		var closest := Geometry2D.get_closest_point_to_segment(at, polygon[index], polygon[(index + 1) % polygon.size()])
		shore = minf(shore, closest.distance_squared_to(at))
	var profile := smoothstep(0.0, 9.0, sqrt(shore))
	var bed := float(water.level) - float(water.depth) * profile
	return lerpf(minf(original, float(water.level) + 0.18), bed, smoothstep(0.0, 2.2, sqrt(shore)))


func _key(at: Vector2) -> Vector2i:
	return Vector2i(floori(at.x / TILE_METRES), floori(at.y / TILE_METRES))
