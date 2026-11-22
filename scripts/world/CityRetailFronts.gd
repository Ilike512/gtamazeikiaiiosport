extends RefCounted

const Geometry = preload("res://scripts/world/Geometry.gd")
const SlidingEntrance = preload("res://scripts/world/SlidingEntrance.gd")
const CZ := [
	{"address": "Sodų g. 13-2", "at": Vector2(20.1, -178.47), "heading": PI, "type": "corner"},
	{"address": "Laisvės g. 13-1", "at": Vector2(839.7, -644.05), "heading": 0.89, "type": "arcade"},
	{"address": "Naftininkų g. 12-33", "at": Vector2(375.9, -28.1), "heading": 1.39, "type": "stairs"},
	{"address": "Naftininkų g. 17", "at": Vector2(354.3, 467.8), "heading": 2.80, "type": "metal"}
]
const GLASS := Color("#435b64")
const STONE := Color("#aba18f")
const CHARCOAL := Color("#292e34")
const CREAM := Color("#d8d8ca")
const RED := Color("#ab3741")

var _geo := Geometry.new()


func shop_pins() -> Array:
	var pins: Array = []
	for shop: Dictionary in CZ:
		pins.append({"name": "ČIA Market · " + shop.address, "point": shop.at, "home": false})
	return pins


func build_corner_shops(parent: Node3D, elevation: RefCounted) -> void:
	var frontages := Node3D.new()
	frontages.name = "CiaMarketFrontages"
	parent.add_child(frontages)
	for shop: Dictionary in CZ:
		var gate := Node3D.new()
		gate.name = str(shop.type).capitalize()
		frontages.add_child(gate)
		gate.position = elevation.point_at(shop.at)
		gate.rotation.y = shop.heading
		match str(shop.type):
			"arcade": _arcade(gate)
			"metal": _metal(gate)
			"stairs": _corner(gate, 0.92, 3.5, 6)
			_: _corner(gate, 0.24, 5.0, 2)
	_geo.batch_static(frontages)


func build_gruste(gate: Node3D, site: Dictionary, elevation: RefCounted) -> Node3D:
	var width := float(site.door_width)
	var height := float(site.floor_height)
	var slate := Color("#4b5053")
	var metal := Color("#858b89")
	var dark := Color("#242929")
	var canopy := _geo.box(gate, Vector3(-20.9, 4.58, 0.84), Vector3(53.3, 0.44, 1.70), slate)
	canopy.name = "PutinasCanopy"
	for col in range(-10, 2):
		var x := (col - 0.1) * 4.55
		_geo.box(gate, Vector3(x, 5.17, 0.14), Vector3(4.49, 3.27, 0.22), metal if col % 3 == 1 else slate)
		_geo.box(gate, Vector3(x, 2.92, 0.15), Vector3(4.48, 0.33, 0.21), dark)
		if absf(x) > 3.4:
			_glazing(gate, x, 0.30, 4.18, 2.51, 0.18)
	for x: float in [-41, -34, -26, -18, -10, 5]:
		_geo.box(gate, Vector3(x, 1.96, 0.60), Vector3(0.23, 3.95, 0.19), CHARCOAL)
	for local_x: float in [-5.0, 4.01]:
		_glazing(gate, local_x, 0.23, 4.30, 2.55, 0.28)
	_geo.box(gate, Vector3(0.0, 3.65, 0.58), Vector3(11.3, 1.17, 0.22), site.color)
	_geo.signage(gate, Vector3(0, 3.69, 0.71), "PUTINAS", 52, Color("#f7f1df"))
	_geo.signage(gate, Vector3(-1.43, 5.68, 0.36), "GRŪSTĖ", 42, Color("#dbe9bd"))
	_geo.box(gate, Vector3(-0.15, 7.05, 0.16), Vector3(9.58, 1.26, 0.32), Color("#354a43"))
	_geo.signage(gate, Vector3(-0.15, 7.07, 0.33), "PUTINAS", 57, Color("#e4e1cd"))
	for sign_x: float in [-34.4, -22.9]:
		_geo.signage(gate, Vector3(sign_x, 3.38, 0.36), "PARDUOTUVĖS", 15, Color("#cdcfc4"))
	for x: float in [-26.5, -14.8]:
		_geo.box(gate, Vector3(x, 0.25, 3.5), Vector3(2.5, 0.50, 0.62), CHARCOAL)
		_geo.box(gate, Vector3(x, 0.53, 3.5), Vector3(2.10, 0.14, 0.42), Color("#797049"))
	var street := gate.to_global(Vector3(0, 0, 3.7))
	var approach: float = elevation.height_at(Vector2(street.x, street.z)) - gate.global_position.y - 0.08
	var run := 3.79
	var rise := height - approach
	var access := _geo.box(gate, Vector3(0, (approach + height) * 0.5 - 0.09, 1.80),
		Vector3(width + 0.43, 0.18, Vector2(run, rise).length()), STONE, true)
	access.rotation.x = atan2(rise, run)
	var door := SlidingEntrance.new()
	door.name = "GrusteAutomaticDoors"
	door.position = Vector3(0, height, 0.14)
	gate.add_child(door)
	door.build(width, 2.22, Color("#a4c0b87d"))
	_geo.batch_static(gate)
	return door


func build_rimi(gate: Node3D, site: Dictionary) -> Node3D:
	var width := float(site.door_width)
	var floor_y := float(site.floor_height)
	var canopy := _geo.box(gate, Vector3(3.05, 4.97, 1.94), Vector3(39.0, 0.31, 3.90), CHARCOAL)
	canopy.rotation.z = -0.018
	_geo.box(gate, Vector3(3.05, 4.93, 3.86), Vector3(39.0, 0.25, 0.09), RED)
	_geo.box(gate, Vector3(0.55, 5.78, 3.95), Vector3(11.2, 1.96, 0.31), Color("#d5c3ae"))
	_geo.box(gate, Vector3(0.55, 5.78, 4.13), Vector3(10.93, 1.72, 0.12), RED)
	_geo.signage(gate, Vector3(0.57, 5.95, 4.22), "Rimi", 85, CREAM)
	_geo.signage(gate, Vector3(0.64, 5.19, 4.23), "HYPERMARKET", 23, Color("#f2d26a"))
	for x: float in [-15.1, -7.5, 8.2, 17.2]:
		for direction: float in [-1.0, 1.0]:
			var brace := _geo.box(gate, Vector3(x, 2.54, 3.25), Vector3(0.095, 4.84, 0.15), RED)
			brace.rotation.z = 0.32 * direction
	for column in range(-5, 7):
		var x := column * 3.15
		if absf(x) < width * 0.5 + 0.2:
			continue
		_glazing(gate, x, 0.25, 2.93, 3.77, 0.39)
	_geo.box(gate, Vector3(0, 3.59, 0.42), Vector3(width + 0.16, 1.65, 0.10), GLASS)
	var doorway := SlidingEntrance.new()
	doorway.name = "RimiAutomaticDoors"
	doorway.position.y = floor_y
	doorway.position.z = 0.14
	gate.add_child(doorway)
	doorway.build(width, 2.22, Color("#90b4b481"))
	var ramp := _geo.box(gate, Vector3(0, 0.087, 1.10), Vector3(width + 0.30, 0.13, 2.30), STONE, true)
	ramp.rotation.x = 0.12
	for side: float in [-1.0, 1.0]:
		for i in 3:
			_geo.taper(gate, Vector3((width * 0.5 + 0.55 + i * 1.18) * side, 0.39, 3.95), 0.79, 0.044, 0.046, CHARCOAL, 10)
	_geo.signage(gate, Vector3(11.6, 3.55, 0.49), "La Crêpe", 30, Color("#d65d63"))
	_geo.batch_static(gate)
	return doorway


func _arcade(gate: Node3D) -> void:
	for i in 4:
		var at := -5.40 + i * 3.56
		_glazing(gate, at, 0.36, 3.22, 2.63, 0.48)
		_geo.box(gate, Vector3(at - 1.76, 1.52, 0.68), Vector3(0.39, 3.04, 0.46), STONE)
	_geo.box(gate, Vector3(0, 3.08, 0.55), Vector3(14.52, 0.68, 0.32), STONE)
	var canopy := _geo.box(gate, Vector3(0, 3.83, 0.72), Vector3(14.6, 0.14, 2.05), Color("#7c8380"))
	canopy.rotation.x = 0.33
	_sign(gate, Vector3(-2.3, 3.25, 0.77), 6.5)
	for x: float in [-5.0, -2.1]:
		_geo.box(gate, Vector3(x, 0.42, 1.2), Vector3(1.54, 0.085, 0.28), Color("#955b4a"))
		_geo.box(gate, Vector3(x, 0.66, 1.04), Vector3(1.54, 0.22, 0.061), Color("#955b4a"))


func _metal(gate: Node3D) -> void:
	_geo.box(gate, Vector3(0.0, 2.89, 0.18), Vector3(13.5, 5.79, 0.34), Color("#929b9e"))
	for index in range(16):
		_geo.box(gate, Vector3(0.0, 3.78 + 0.116 * index, 0.37), Vector3(13.35, 0.055, 0.067), Color("#727c83"))
	for x: float in [-4.74, -1.59, 1.56, 4.72]:
		_glazing(gate, x, 0.07, 3.03, 2.17, 0.39)
		_glazing(gate, x, 3.02, 3.02, 0.72, 0.41)
	_geo.box(gate, Vector3(1.57, 2.70, 0.94), Vector3(4.45, 0.12, 1.46), Color("#38735b"))
	_sign(gate, Vector3(1.55, 2.62, 1.70), 4.45)
	for x: float in [-5.4, 4.7]:
		_geo.box(gate, Vector3(x, 0.28, 2.14), Vector3(1.2, 0.56, 0.51), Color("#8d503e"))


func _corner(gate: Node3D, rise: float, width: float, steps: int) -> void:
	var frame := Color("#d6d7cc")
	_geo.box(gate, Vector3(0, rise + 1.29, 0.29), Vector3(width, 2.60, 0.43), frame)
	_glazing(gate, 0, rise + 0.09, width - 0.17, 2.0, 0.53)
	for x: float in [-0.60, 0.60]:
		_geo.box(gate, Vector3(x, rise + 1.12, 0.66), Vector3(0.077, 2.12, 0.13), frame)
	var roof := _geo.box(gate, Vector3(0, rise + 2.62, 0.48), Vector3(width + 0.32, 0.13, 1.03), CHARCOAL)
	roof.rotation.x = 0.17
	_sign(gate, Vector3(0, rise + 2.34, 0.56), width - 0.1)
	for i in steps:
		var front := (steps - i) * 0.31
		var step_height := rise * (i + 1.0) / steps
		_geo.box(gate, Vector3(0.0, step_height * 0.5, 0.40 + front * 0.5), Vector3(width - 0.46, step_height, front), STONE, true)
	if steps > 3:
		for side: float in [-1.0, 1.0]:
			var x := (width * 0.5 - 0.36) * side
			var railing := _geo.box(gate, Vector3(x, 1.02 + rise * 0.5, 1.14), Vector3(0.055, 0.055, 1.89), frame)
			railing.rotation.x = 0.48


func _sign(gate: Node3D, at: Vector3, width: float) -> void:
	_geo.box(gate, at - Vector3.RIGHT * width * 0.25, Vector3(width * 0.5, 0.43, 0.11), RED)
	_geo.box(gate, at + Vector3.RIGHT * width * 0.25, Vector3(width * 0.5, 0.43, 0.11), Color("#357557"))
	_geo.signage(gate, at + Vector3.BACK * 0.073, "ČIA MARKET", 24, CREAM)


func _glazing(gate: Node3D, x: float, y: float, width: float, height: float, depth: float) -> void:
	_geo.box(gate, Vector3(x, y + height * 0.5, depth), Vector3(width, height, 0.084), GLASS)
	for side: float in [-0.49, 0.0, 0.49]:
		_geo.box(gate, Vector3(x + width * side, y + height * 0.5, depth + 0.053), Vector3(0.063, height, 0.1), Color("#aeb9b9"))
	_geo.box(gate, Vector3(x, y + height * 0.70, depth + 0.052), Vector3(width, 0.050, 0.083), Color("#aeb9b9"))

