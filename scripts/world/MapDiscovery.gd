extends RefCounted

const CELL := 58.0

var cells: Dictionary = {}
var revealed_all := false
const CITY_RECT := Rect2i(-226, -252, 308, 355)


func is_revealed(cell: Vector2i) -> bool:
	return cells.has(cell) or (revealed_all and CITY_RECT.has_point(cell))


func visit(at: Vector2) -> void:
	var cell := cell_at(at)
	for x in range(-2, 3):
		for z in range(-2, 3):
			var candidate := cell + Vector2i(x, z)
			if cell_center(candidate).distance_squared_to(at) <= (CELL * 1.82) ** 2:
				cells[candidate] = true


func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL), floori(point.y / CELL))


func cell_center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2.ONE * 0.5) * CELL


func export_cells() -> Array:
	var saved: Array = []
	for cell: Vector2i in cells:
		saved.append([cell.x, cell.y])
	return saved


func restore(value: Variant) -> void:
	cells.clear()
	if value is not Array:
		return
	for entry: Variant in value:
		if entry is Array and entry.size() == 2:
			var cell := Vector2i(int(entry[0]), int(entry[1]))
			if CITY_RECT.grow(6).has_point(cell):
				cells[cell] = true


static func clip_line(a: Vector2, b: Vector2, bounds: Rect2) -> PackedVector2Array:
	if bounds.has_point(a) and bounds.has_point(b):
		return PackedVector2Array([a, b])
	var points := PackedVector2Array()
	if bounds.has_point(a):
		points.append(a)
	if bounds.has_point(b):
		points.append(b)
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for index in corners.size():
		var hit: Variant = Geometry2D.segment_intersects_segment(a, b, corners[index], corners[(index + 1) % corners.size()])
		if hit is Vector2 and not points.has(hit):
			points.append(hit)
		if points.size() == 2:
			return points
	return PackedVector2Array()
