extends RefCounted

const DATA := "res://data/city/elevation.json"
const STEP := 23.0

var _origin := Vector2(-4600, -4140)
var _width := 0
var _height := 0
var _samples := PackedFloat32Array()


func load_grid() -> void:
	var grid: Dictionary = GameManager.read_json(DATA, {})
	var samples: Array = grid.get("samples", [])
	_width = int(grid.get("width", 0))
	_height = int(grid.get("height", 0))
	if _width >= 2 and _height >= 2 and samples.size() == _width * _height:
		_origin = Vector2(float(grid.origin[0]), float(grid.origin[1]))
		_samples = PackedFloat32Array(samples)


func height_at(point: Vector2) -> float:
	if _samples.is_empty():
		return 0.0
	var relative := (point - _origin) / STEP
	var u := clampf(relative.x, 0.0, _width - 1.0)
	var v := clampf(relative.y, 0.0, _height - 1.0)
	var x := mini(floori(u), _width - 2)
	var z := mini(floori(v), _height - 2)
	var row := z * _width + x
	var dx := u - x
	var dz := v - z
	var a := _samples[row]
	var b := _samples[row + 1]
	var c := _samples[row + _width]
	var d := _samples[row + _width + 1]
	if dz <= dx:
		return a + (b - a) * dx + (d - b) * dz
	return a + (d - c) * dx + (c - a) * dz


func point_at(point: Vector2, lift := 0.0) -> Vector3:
	return Vector3(point.x, height_at(point) + lift, point.y)


func normal_at(point: Vector2) -> Vector3:
	var dx := height_at(point + Vector2(2, 0)) - height_at(point - Vector2(2, 0))
	var dz := height_at(point + Vector2(0, 2)) - height_at(point - Vector2(0, 2))
	return Vector3(-dx, 4.0, -dz).normalized()
