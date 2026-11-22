extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const SlidingEntrance = preload("res://scripts/world/SlidingEntrance.gd")
const Sites = preload("res://scripts/world/StoreSites.gd")
const TILE = preload("res://assets/shaders/diner_tiles.gdshader")
const WOOD := Color("#947253")
const METAL := Color("#292d2e")
const TABLE := Color("#d2ae7e")
const SEAT := Color("#772f29")

var doors: Node3D
var checkout: Vector3
var _geo := Geometry.new()


func build(gate: Node3D, elevation: RefCounted) -> void:
	var site := Sites.BURGER
	position = Vector3(0, site.floor_height, -site.depth * 0.5)
	_geo.box(self, Vector3(0, -0.14, 0), Vector3(site.span, 0.28, site.depth + 0.12), Color("#78736b"), true)
	var tiles := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(site.span, site.depth)
	var ceramic := ShaderMaterial.new()
	ceramic.shader = TILE
	tiles.mesh = plane
	tiles.material_override = ceramic
	tiles.position.y = 0.009
	add_child(tiles)
	var plaster := Color("#ccc1ad")
	_geo.box(self, Vector3(0, 2.2, -15.96), Vector3(36, 4.4, 0.16), plaster, true)
	for side: float in [-1.0, 1.0]:
		_geo.box(self, Vector3(side * 17.92, 2.2, 0), Vector3(0.16, 4.4, 32), plaster, true)
		_geo.box(self, Vector3(side * 10.05, 2.2, 15.94), Vector3(15.9, 4.4, 0.19), METAL, true)
	_geo.box(self, Vector3(0, 4.42, 0), Vector3(36, 0.18, 32), plaster, true)
	doors = SlidingEntrance.new()
	doors.position = Vector3(0, site.floor_height, 0.04)
	gate.add_child(doors)
	doors.build(site.door_width, 2.45, Color("#86a6ab67"))
	doors.build_approach(elevation, 2.5)
	_geo.box(gate, Vector3(0, 3.7, 0.32), Vector3(10.3, 0.87, 0.19), METAL)
	_geo.signage(gate, Vector3(0, 3.72, 0.442), "BURGER STOTIS", 51, Color("#ffe0a2"))
	_geo.signage(self, Vector3(0, 2.96, 15.81), "IŠĖJIMAS", 19, Color("#a2e8a9"), PI)
	_make_counter()
	_make_seating()
	_make_play_corner()
	_add_lights()
	_geo.batch_static(self)


func _make_counter() -> void:
	checkout = to_global(Vector3(0, 0.4, -8.7))
	_geo.box(self, Vector3(0, 0.59, -11.2), Vector3(12.3, 1.18, 1.02), WOOD, true)
	_geo.box(self, Vector3(0, 1.2, -11.2), Vector3(12.52, 0.15, 1.18), Color("#e8d3b0"))
	for x: float in [-3.5, 0.0, 3.5]:
		_geo.box(self, Vector3(x, 1.43, -11.34), Vector3(0.47, 0.32, 0.23), METAL)
		_geo.box(self, Vector3(x, 0.53, -10.67), Vector3(0.92, 0.05, 0.04), METAL)
	var menu := ["MĖSAINIAI", "KOMPLEKTAI", "SPRUNK", "MCPISS"]
	for i in menu.size():
		var at := Vector3(-5.1 + i * 3.4, 3.03, -13.25)
		_geo.box(self, at, Vector3(3.25, 1.24, 0.16), METAL)
		_geo.signage(self, at + Vector3(0, 0.21, 0.10), menu[i], 26, Color("#f3dfb3"))
		_geo.signage(self, at + Vector3(0, -0.27, 0.10), "BURGER STOTIS", 13, Color("#e3af79"))


func _make_seating() -> void:
	for row in 5:
		var z := -7.0 + row * 4.7
		for x: float in [-13.5, -7.3, 7.3]:
			_geo.box(self, Vector3(x, 0.79, z), Vector3(1.9, 0.13, 0.91), TABLE, true)
			_geo.box(self, Vector3(x, 0.39, z), Vector3(0.23, 0.77, 0.56), METAL)
			for side: float in [-1.0, 1.0]:
				_geo.box(self, Vector3(x, 0.47, z + side * 1.01), Vector3(1.64, 0.19, 0.52), SEAT, true)
				_geo.box(self, Vector3(x, 0.77, z + side * 1.26), Vector3(1.71, 0.72, 0.15), METAL)
			_geo.taper(self, Vector3(x, 2.67, z), 0.23, 0.19, 0.44, METAL, 16)
			_geo.box(self, Vector3(x, 3.52, z), Vector3(0.038, 1.49, 0.038), METAL)
	for i in 18:
		_geo.box(self, Vector3(-17.73, 2.05, -6.65 + i * 0.87), Vector3(0.24, 3.88, 0.14), WOOD)


func _make_play_corner() -> void:
	_geo.box(self, Vector3(13.20, 0.09, 6.5), Vector3(7.05, 0.18, 12.7), Color("#3f6665"), true)
	for x: float in [10.1, 16.25]:
		for z: float in [1.0, 5.8, 11.6]:
			_geo.taper(self, Vector3(x, 1.25, z), 2.50, 0.10, 0.10, Color("#cf7a34"))
		for level in 7:
			_geo.box(self, Vector3(x, 0.28 + level * 0.29, 6.3), Vector3(0.025, 0.019, 10.62), Color("#c6a558"))
		for column in 24:
			_geo.box(self, Vector3(x, 1.20, 1.10 + column * 0.45), Vector3(0.020, 2.15, 0.02), Color("#c6a558"))
	var slide := _geo.box(self, Vector3(13.9, 0.89, 6.7), Vector3(0.90, 0.14, 2.93), Color("#347b91"), true)
	slide.rotation.x = -0.44
	_geo.signage(self, Vector3(13, 2.94, 11.62), "ŽAIDIMŲ ZONA", 24, Color("#f2d884"))


func _add_lights() -> void:
	for z: float in [-11.0, -2.0, 8.1]:
		for x: float in [-9.0, 0.0, 9.0]:
			if x == 0.0 and z == -2.0:
				continue
			var lamp := OmniLight3D.new()
			lamp.position = Vector3(x, 3.22, z)
			lamp.light_color = Color("#fff2d8")
			lamp.light_energy = 0.62
			lamp.omni_range = 10.8
			add_child(lamp)

