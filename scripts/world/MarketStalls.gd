extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const POINTS := [
	{"center": Vector2(373.6, 477.0), "name": "Sedos turgelis", "yaw": 0.35},
	{"center": Vector2(980.5, 433.5), "name": "Mažeikių turgus", "yaw": -0.13}
]
const PRODUCE := [Color("#a73529"), Color("#ca744f"), Color("#587847"), Color("#96734c"), Color("#bdaf77")]

var _geo := Geometry.new()
var _placed: Array[Vector2] = []


func build(district: Node3D) -> void:
	for area: Dictionary in POINTS:
		var center: Vector2 = area.center
		var built := 0
		var basis := Basis(Vector3.UP, area.yaw)
		for row in 4:
			for index in 5:
				if built >= 5:
					break
				var shift := basis * Vector3(index * 4.3 - 8.6, 0, row * 5.0 - 7.5)
				var at := center + Vector2(shift.x, shift.z)
				if not district.can_place_market_stall(at):
					continue
				var stand := Node3D.new()
				stand.position = district.elevation.point_at(at, 0.08)
				stand.basis = basis
				add_child(stand)
				_build_stand(stand, built)
				_placed.append(at)
				built += 1
	_geo.batch_static(self)


func _build_stand(stand: Node3D, design: int) -> void:
	var canvas := [Color("#527962"), Color("#a7916d"), Color("#536a7f")][design % 3] as Color
	var timber := Color("#625e51")
	var side := Color("#d4c3a6")
	for x: float in [-1.70, 1.70]:
		for z: float in [-1.11, 1.11]:
			_geo.box(stand, Vector3(x, 1.16, z), Vector3(0.077, 2.32, 0.076), timber, true)
	_geo.box(stand, Vector3(0, 0.67, 0.65), Vector3(3.35, 0.93, 0.42), timber, true)
	_geo.box(stand, Vector3(0, 1.16, 0.51), Vector3(3.55, 0.11, 0.93), side)
	var roof := _geo.box(stand, Vector3(0, 2.48, 0), Vector3(3.89, 0.11, 2.52), canvas)
	roof.rotation.x = 0.10
	for stripe in 6:
		_geo.box(stand, Vector3(-1.62 + stripe * 0.64, 2.32, 1.28), Vector3(0.60, 0.18, 0.09),
			canvas.lightened(0.20) if stripe % 2 == 0 else canvas)
	for crate in 5:
		var x := -1.32 + crate * 0.64
		_geo.box(stand, Vector3(x, 1.26, 0.57), Vector3(0.55, 0.14, 0.49), timber.lightened(0.17))
		for batch in 6:
			var color: Color = PRODUCE[(design + crate) % PRODUCE.size()]
			var point := Vector3(x - 0.16 + batch % 3 * 0.162, 1.37, 0.44 + floori(batch / 3.0) * 0.18)
			_geo.taper(stand, point, 0.11, 0.054, 0.075, color, 7)
	var tags := ["DARŽOVĖS", "OBUOLIAI", "GĖLĖS", "UOGOS", "MEDUS"]
	_geo.signage(stand, Vector3(0, 2.08, 1.25), tags[design], 14, Color("#fff3d7"))
