extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const Sites = preload("res://scripts/world/StoreSites.gd")
const SlidingEntrance = preload("res://scripts/world/SlidingEntrance.gd")
const BLUE := Color("#19618f")
const SILVER := Color("#a5b3bc")
const MULLION := Color("#9ca7ac")
const DARK := Color("#3c4a52")

var _geo := Geometry.new()
var doorway: Node3D


func build(gate: Node3D, district: Node3D) -> void:
	var elevation: RefCounted = district.elevation
	var roof: float = elevation.height_at(Vector2(-62.83, 216.14)) + 6.4 - gate.position.y
	var ground := -0.42
	_band(gate, ground, 1.82, BLUE, 0.12)
	_band(gate, 1.82, roof - 0.81, SILVER, 0.12)
	_band(gate, roof - 0.81, roof, BLUE, 0.18)
	_geo.box(gate, Vector3(-10.5, roof + 0.035, 0.09), Vector3(42.2, 0.091, 0.37), DARK)
	for seam in range(-29, 11, 4):
		if absf(seam) < 1.7:
			continue
		_geo.box(gate, Vector3(seam, roof * 0.48, 0.202), Vector3(0.027, roof - 0.26, 0.036), Color("#718997"))
	for row in 3:
		_geo.box(gate, Vector3(-10.5, 2.21 + row * 0.84, 0.177), Vector3(42.0, 0.017, 0.016), Color("#8395a0"))
	for bay in 6:
		var x := -25.3 + bay * 2.24
		_geo.box(gate, Vector3(x, roof - 1.52, 0.181), Vector3(1.79, 1.05, 0.09), SILVER.lightened(0.14))
		_geo.box(gate, Vector3(x, roof - 1.52, 0.24), Vector3(1.56, 0.86, 0.05), Color("#586972"))
		_geo.box(gate, Vector3(x, roof - 1.52, 0.275), Vector3(0.039, 0.855, 0.035), MULLION)
	_roof_sign(gate, roof)
	_display_windows(gate)
	_glazed_entry(gate)
	_parking_sign(gate, elevation)
	_gallery_signs(elevation)
	var apron := PackedVector2Array()
	for point: Vector3 in [Vector3(-30, 0, 0.2), Vector3(10.5, 0, 0.2), Vector3(8.9, 0, 14.2), Vector3(-26, 0, 13.5)]:
		var at := gate.to_global(point)
		apron.append(Vector2(at.x, at.z))
	district.add_paved_apron(apron)
	for index in 4:
		var x := -9.1 - index * 3.20
		var start := gate.to_global(Vector3(x, 0, 4.9))
		var finish := gate.to_global(Vector3(x, 0, 10.0))
		var a: Vector3 = elevation.point_at(Vector2(start.x, start.z), 0.095)
		var b: Vector3 = elevation.point_at(Vector2(finish.x, finish.z), 0.095)
		var line := _geo.box(self, (a + b) * 0.5, Vector3(0.085, 0.013, a.distance_to(b)), Color("#cccac0"))
		line.look_at(b, Vector3.UP)
		if index < 2:
			var post := gate.to_global(Vector3(x + 1.52, 0, 4.14))
			var base: Vector3 = elevation.point_at(Vector2(post.x, post.z))
			_geo.box(self, base + Vector3.UP * 0.72, Vector3(0.062, 1.44, 0.062), MULLION)
			var panel := _geo.box(self, base + Vector3.UP * 1.62, Vector3(0.39, 0.41, 0.07), Color("#255298"))
			panel.rotation.y = gate.rotation.y
			var sign_at := panel.position + gate.basis.z * 0.048
			_geo.signage(self, sign_at, "P", 19, Color.WHITE, gate.rotation.y)
	_geo.batch_static(gate)


func _display_windows(gate: Node3D) -> void:
	var glass := _geo.material(Color("#426377")).duplicate() as StandardMaterial3D
	glass.roughness = 0.32
	glass.metallic = 0.14
	for index in 5:
		var x := -27.18 + index * 4.16
		_geo.box(gate, Vector3(x, 1.36, 0.216), Vector3(3.87, 1.89, 0.15), DARK)
		_geo.box(gate, Vector3(x, 1.41, 0.303), Vector3(3.68, 1.70, 0.039), SILVER).material_override = glass
		for bar: float in [-0.65, 0.66]:
			_geo.box(gate, Vector3(x + bar, 1.40, 0.337), Vector3(0.062, 1.66, 0.034), MULLION)
	_geo.box(gate, Vector3(5.60, 3.40, 0.26), Vector3(7.95, 0.91, 0.18), BLUE)
	_geo.signage(gate, Vector3(5.60, 3.42, 0.369), "MAXIMA XX", 38, Color.WHITE)


func _gallery_signs(elevation: RefCounted) -> void:
	var bar := Node3D.new()
	var front := Basis(Vector3.UP, Sites.MAXIMA.heading)
	bar.position = elevation.point_at(Vector2(-17.0, 228.8)) + front.z * 0.22
	bar.rotation.y = Sites.MAXIMA.heading
	add_child(bar)
	_geo.box(bar, Vector3(0, 3.15, 0.54), Vector3(5.65, 0.31, 1.38), Color("#586976"))
	_geo.signage(bar, Vector3(0, 3.20, 1.275), "BARAS", 30, Color("#f5f1e0"))
	var bank := Node3D.new()
	bank.position = elevation.point_at(Vector2(1.8, 226.8)) + front.z * 0.23
	bank.rotation.y = Sites.MAXIMA.heading
	add_child(bank)
	_geo.box(bank, Vector3(0, 3.48, 0), Vector3(9.65, 0.63, 0.28), Color("#e4e2d8"))
	_geo.signage(bank, Vector3(0, 3.51, 0.166), "ŠIAULIŲ BANKAS", 35, Color("#2a4d85"))


func _parking_sign(gate: Node3D, elevation: RefCounted) -> void:
	var edge := gate.to_global(Vector3(8.0, 0.0, 9.2))
	var grade: Vector3 = elevation.point_at(Vector2(edge.x, edge.z), 0.02)
	var sign := Node3D.new()
	sign.position = gate.to_local(grade)
	gate.add_child(sign)
	for x: float in [-1.15, 1.15]:
		_geo.box(sign, Vector3(x, 1.41, 0.0), Vector3(0.12, 2.82, 0.12), DARK, true)
	_geo.box(sign, Vector3(0.0, 2.32, 0.0), Vector3(2.88, 0.97, 0.16), Color("#eceff2"))
	for facing: float in [-1.0, 1.0]:
		_geo.signage(sign, Vector3(0.0, 2.46, facing * 0.088), "MAXIMA XX", 29, Color("#183585"), 0.0 if facing > 0 else PI)
		_geo.signage(sign, Vector3(0.0, 2.13, facing * 0.088), "ŽEMAITIJOS G. 20", 14, DARK, 0.0 if facing > 0 else PI)


func _band(gate: Node3D, bottom: float, top: float, tint: Color, thickness: float) -> void:
	var height := top - bottom
	var middle := bottom + height * 0.5
	if bottom >= 3.02:
		_geo.box(gate, Vector3(-10.5, middle, 0.08), Vector3(42.0, height, thickness), tint)
		return
	var half_gap: float = Sites.MAXIMA.door_width * 0.5 + 0.065
	for edges: Vector2 in [Vector2(-31.5, -half_gap), Vector2(half_gap, 10.5)]:
		_geo.box(gate, Vector3((edges.x + edges.y) * 0.5, middle, 0.08), Vector3(edges.y - edges.x, height, thickness), tint)
	if top > 3.02:
		_geo.box(gate, Vector3(0, (3.02 + top) * 0.5, 0.08), Vector3(half_gap * 2.0, top - 3.02, thickness), tint)


func _roof_sign(gate: Node3D, roof: float) -> void:
	for x: float in [-11.3, -6.05, -0.88]:
		_geo.box(gate, Vector3(x, roof + 0.27, 0.05), Vector3(0.077, 0.58, 0.11), DARK)
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Arial Black", "Arial", "Liberation Sans"])
	font.font_weight = 900
	var x := -12.0
	for word: Array in [["MA", "#183585"], ["X", "#bc3446"], ["IMA", "#183585"], [" XX", "#bc3446"]]:
		var width := font.get_string_size(str(word[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 111).x * 0.016
		var sign := _geo.signage(gate, Vector3(x + width * 0.5, roof + 0.93, 0.19), str(word[0]), 111, Color(word[1]))
		sign.font = font
		sign.outline_modulate = Color("#eeeae0")
		sign.outline_size = 7
		x += width + 0.025


func _glazed_entry(gate: Node3D) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("#739ba28f")
	glass.roughness = 0.36
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for column: float in [-3.12, -2.08, 2.08, 3.12]:
		var pane := _geo.box(gate, Vector3(column, 1.79, 1.36), Vector3(0.98, 2.44, 0.08), SILVER, true)
		pane.material_override = glass
		_geo.box(gate, Vector3(column + signf(column) * 0.49, 1.78, 1.42), Vector3(0.052, 2.48, 0.08), MULLION)
	var slider := SlidingEntrance.new()
	slider.name = "AutomaticGlassDoors"
	slider.position = Vector3(0, Sites.MAXIMA.floor_height, 1.34)
	gate.add_child(slider)
	slider.build(Sites.MAXIMA.door_width, 2.14, Color("#89b0b068"))
	doorway = slider
	for end: float in [-1.0, 1.0]:
		_geo.box(gate, Vector3(end * 3.70, 1.34, 0.72), Vector3(0.12, 2.56, 1.32), MULLION)
		_geo.box(gate, Vector3(end * 3.55, 2.83, 1.28), Vector3(0.07, 0.09, 2.55), DARK)
	var canopy := _geo.box(gate, Vector3(0, 2.99, 1.17), Vector3(7.92, 0.15, 2.48), SILVER)
	canopy.rotation.x = 0.10
	_geo.box(gate, Vector3(0, 2.74, 1.42), Vector3(7.91, 0.18, 0.18), DARK)
	_geo.signage(gate, Vector3(0, 2.71, 1.53), "ĮĖJIMAS", 15, Color("#e4f0f2"))
	var ramp := _geo.box(gate, Vector3(0, 0.250, 3.02), Vector3(4.0, 0.14, 3.55), Color("#838b8d"), true)
	ramp.rotation.x = 0.283


static func fit_vestibule(room: Node3D, geo: Geometry) -> void:
	geo.box(room, Vector3(0, 0.012, 8.15), Vector3(4.9, 0.025, 2.95), Color("#5f6969"))
	for side: float in [-1.0, 1.0]:
		geo.box(room, Vector3(side * 3.72, 1.30, 7.03), Vector3(2.60, 2.60, 0.12), Color("#65878e"), true)
		geo.box(room, Vector3(side * 2.43, 1.35, 7.13), Vector3(0.075, 2.70, 0.15), MULLION)
		geo.box(room, Vector3(side * 3.72, 1.03, 7.12), Vector3(2.55, 0.039, 0.07), SILVER)
	geo.box(room, Vector3(0, 2.70, 7.03), Vector3(10.1, 0.31, 0.13), BLUE)
	geo.signage(room, Vector3(0, 2.70, 7.12), "MAXIMA XX", 19, Color.WHITE)

