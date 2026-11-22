extends RefCounted

const ARRIVAL_DISTANCE := 12.0
const MAX_SNAP_DISTANCE := 180.0
const SNAP_CANDIDATES := 12

var destination := Vector2.INF
var route := PackedVector2Array()
var _graph := AStar2D.new()
var _vertices: Dictionary = {}
var _edges: Array[Vector2i] = []
var _indexed := false
var _next_review := 0


func select(at: Vector2, target: Vector2, roads: Array) -> bool:
	if not _indexed:
		_index(roads)
	var ends := _nearest_edges(target)
	var starts := _nearest_edges(at)
	if ends.is_empty() or starts.is_empty():
		return false
	var best := _path_between(starts, ends)
	if best.is_empty():
		return false
	destination = best[best.size() - 1]
	route = best
	_next_review = Time.get_ticks_msec() + 650
	return true


func remaining_distance(at: Vector2) -> float:
	if route.size() < 2:
		return 0.0
	var nearest := INF
	var rest := 0.0
	var total := 0.0
	for index in range(route.size() - 2, -1, -1):
		var first := route[index]
		var last := route[index + 1]
		if index < 12:
			var point := Geometry2D.get_closest_point_to_segment(at, first, last)
			var gap := at.distance_to(point)
			if gap < nearest:
				nearest = gap
				rest = total + point.distance_to(last)
		total += first.distance_to(last)
	return rest + nearest


func clear() -> void:
	destination = Vector2.INF
	route = PackedVector2Array()


func update(at: Vector2) -> bool:
	if destination == Vector2.INF:
		return false
	if at.distance_to(destination) <= ARRIVAL_DISTANCE:
		clear()
		return true
	if Time.get_ticks_msec() < _next_review:
		return false
	_next_review = Time.get_ticks_msec() + 800
	var closest := 0
	var distance := INF
	for index in mini(route.size() - 1, 10):
		var gap := at.distance_squared_to(Geometry2D.get_closest_point_to_segment(at, route[index], route[index + 1]))
		if gap < distance:
			distance = gap
			closest = index
	if distance > 32.0 * 32.0:
		var new_route := _path_between(_nearest_edges(at), _nearest_edges(destination))
		if not new_route.is_empty():
			route = new_route
	elif closest > 0:
		route = route.slice(closest)
	return false


func _index(roads: Array) -> void:
	_indexed = true
	for segment: Array in roads:
		if float(segment[2]) < 2.6:
			continue
		var a := _vertex(segment[0])
		var b := _vertex(segment[1])
		if a == b or _graph.are_points_connected(a, b):
			continue
		_graph.connect_points(a, b)
		_edges.append(Vector2i(a, b))


func _vertex(at: Vector2) -> int:
	var key := Vector2i((at * 4.0).round())
	if _vertices.has(key):
		return _vertices[key]
	var id := _vertices.size()
	_vertices[key] = id
	_graph.add_point(id, at)
	return id


func _nearest_edges(at: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var distance_squared := MAX_SNAP_DISTANCE * MAX_SNAP_DISTANCE
	for edge: Vector2i in _edges:
		var a := _graph.get_point_position(edge.x)
		var b := _graph.get_point_position(edge.y)
		var point := Geometry2D.get_closest_point_to_segment(at, a, b)
		var gap := point.distance_squared_to(at)
		if gap > distance_squared:
			continue
		result.append({"edge": edge, "at": point, "gap": gap})
		result.sort_custom(func(first: Dictionary, second: Dictionary) -> bool: return first.gap < second.gap)
		if result.size() >= SNAP_CANDIDATES:
			result.resize(SNAP_CANDIDATES)
			distance_squared = result[SNAP_CANDIDATES - 1].gap
	return result


func _path_between(starts: Array[Dictionary], ends: Array[Dictionary]) -> PackedVector2Array:
	# Favor the closest road first, with alternate edges for detached driveways.
	for finish: Dictionary in ends:
		for start: Dictionary in starts:
			var path := _edge_path(start, finish)
			if not path.is_empty():
				return path
	return PackedVector2Array()


func _edge_path(start: Dictionary, finish: Dictionary) -> PackedVector2Array:
	var best := PackedVector2Array()
	var cost := INF
	if start.edge == finish.edge:
		return PackedVector2Array([start.at, finish.at])
	for a: int in [start.edge.x, start.edge.y]:
		for b: int in [finish.edge.x, finish.edge.y]:
			var middle := _graph.get_point_path(a, b)
			if middle.is_empty():
				continue
			var path := PackedVector2Array([start.at])
			path.append_array(middle)
			path.append(finish.at)
			var length := 0.0
			for index in path.size() - 1:
				length += path[index].distance_to(path[index + 1])
			if length < cost:
				best = path
				cost = length
	return best

