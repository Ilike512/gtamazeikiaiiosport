extends Control

const MapDiscovery = preload("res://scripts/world/MapDiscovery.gd")

var _details: Control
var _roads: Array
var _buildings: Array
var _relief: Color


func build(cell: Vector2i, district: Node3D) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size = Vector2.ONE * MapDiscovery.CELL
	position = Vector2(cell) * MapDiscovery.CELL
	var bounds := Rect2(position, size)
	var center := bounds.get_center()
	var altitude: float = district.elevation.height_at(center)
	_relief = Color("#293d3d").lightened(clampf((altitude + 13.0) * 0.010, 0.0, 0.15))

	for road: Array in district.map_segments(Vector3(center.x, 0, center.y), size.length() * 0.65):
		var line := MapDiscovery.clip_line(road[0], road[1], bounds.grow(6.0))
		if line.size() == 2:
			_roads.append([line[0] - position, line[1] - position, road[2], road[3], road[4]])
	for building: Array in district.map_footprints(bounds.grow(58.0)):
		var outline: PackedVector2Array = building[3]
		var local := PackedVector2Array()
		for point: Vector2 in outline:
			local.append(point - position)
		if not Geometry2D.triangulate_polygon(local).is_empty():
			_buildings.append([local, Color("#54635d") if str(building[4]).is_empty() else Color("#6b6c5c")])

	_details = Control.new()
	_details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_details)
	_details.draw.connect(_draw_footprints)
	var road_layer := Control.new()
	road_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(road_layer)
	road_layer.draw.connect(_draw_roads.bind(road_layer))


func show_buildings(detail: bool) -> void:
	_details.visible = detail


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), _relief)


func _draw_footprints() -> void:
	for footprint: Array in _buildings:
		_details.draw_colored_polygon(footprint[0], footprint[1])


func _draw_roads(layer: Control) -> void:
	for main: bool in [false, true]:
		for road: Array in _roads:
			if bool(road[4]) != main:
				continue
			var width := clampf(float(road[2]) * 0.90, 1.25, 8.0)
			var tint := Color("#d7c2a3") if main else (Color("#93a39c") if road[3] else Color("#607d77"))
			layer.draw_line(road[0], road[1], Color("#19292c"), width + 1.6)
			layer.draw_line(road[0], road[1], tint, width)
