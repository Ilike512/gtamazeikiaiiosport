extends Node3D

const Bounds = preload("res://scripts/world/ModelBounds.gd")
const Geometry = preload("res://scripts/world/Geometry.gd")
const SUPPLIED := "res://assets/models/supplied/"
const ENTRY := Vector3(-8.0, -0.06, -14.0)
const EXIT := Vector3(-8.0, 0.0, -12.0)
const BOTTLE := Vector3(3.7, 0.0, -7.0)

var view_environment := Environment.new()
var bottle: Node3D
var _geometry := Geometry.new()


func build() -> void:
	view_environment.background_mode = Environment.BG_COLOR
	view_environment.background_color = Color("#131206")
	view_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	view_environment.ambient_light_color = Color("#e0d4a0")
	view_environment.ambient_light_energy = 0.47
	var level := _load_model("psx-backroom/backroom.fbx", self)
	if level != null:
		level.scale *= 12.0
		for part: MeshInstance3D in level.find_children("*", "MeshInstance3D", true, false):
			if part.mesh != null:
				part.create_trimesh_collision()
	else:
		_build_fallback()
	_label(EXIT + Vector3.UP * 1.75, "RETURN TO MAŽEIKIAI")
	_label(Vector3(-8, 2.05, -17.5), "LEVEL 0")
	for point: Vector3 in [Vector3(-8, 2.10, -14), Vector3(4.8, 2.35, -7), Vector3(0, 2.35, -12),
		Vector3(-5, 2.35, -20), Vector3(7, 2.35, -27), Vector3(-7, 2.35, -8), Vector3(12, 2.35, -16)]:
		var light := OmniLight3D.new()
		light.position = point
		light.light_color = Color("#f4e4af")
		light.light_energy = 2.1
		light.omni_range = 8.0
		add_child(light)
	_placement("low-poly-metal-shelf/metal_shelf.glb", Vector3(4.9, -0.22, -7.0), 1.9, PI / 2.0, true)
	_placement("psx-vending-machine/vending_machine.fbx", Vector3(-4.3, -0.22, -7.2), 1.78, -PI / 2.0, true)
	_placement("paulsvids-henry/henry_engine.glb", Vector3(-5.0, -0.22, -12.6), 0.55, PI / 2.0, true)
	bottle = _placement("beer-bottle-psx/beer_bottle.glb", BOTTLE + Vector3.DOWN * 0.22, 0.29, 0.0, false)
	if bottle == null:
		bottle = _geometry.taper(self, BOTTLE - Vector3.UP * 0.07, 0.30, 0.025, 0.046, Color("#87562f"), 10)


func _build_fallback() -> void:
	var yellow := Color("#bbaa73")
	_geometry.box(self, Vector3(0, -0.34, -14), Vector3(25, 0.32, 37), Color("#827357"), true)
	_geometry.box(self, Vector3(0, 2.70, -14), Vector3(25, 0.18, 37), Color("#b8ab8c"), true)
	for x: float in [-12.4, 12.4]:
		_geometry.box(self, Vector3(x, 1.20, -14), Vector3(0.22, 2.9, 37), yellow, true)
	for z: float in [-32.4, 4.4]:
		_geometry.box(self, Vector3(0, 1.20, z), Vector3(25, 2.9, 0.22), yellow, true)
	_geometry.box(self, Vector3(0, 1.2, -14), Vector3(5.5, 2.9, 0.24), yellow, true)
	_geometry.box(self, Vector3(-6, 1.2, -23), Vector3(0.24, 2.9, 10), yellow, true)
	_geometry.box(self, Vector3(7, 1.2, -25), Vector3(5.5, 2.9, 0.24), yellow, true)


func _load_model(name_in_folder: String, parent: Node3D) -> Node3D:
	var path := SUPPLIED + name_in_folder
	if not ResourceLoader.exists(path, "PackedScene"):
		return null
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var root := packed.instantiate() as Node3D
	parent.add_child(root)
	return root


func _placement(path: String, point: Vector3, height: float, yaw: float, solid: bool) -> Node3D:
	var anchor := Node3D.new()
	add_child(anchor)
	var model := _load_model(path, anchor)
	if model == null:
		anchor.queue_free()
		return null
	var size := Bounds.fit_to_height(model, height)
	anchor.position = point
	anchor.rotation.y = yaw
	if solid and size.length_squared() > 0.0001:
		var body := StaticBody3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		var collision := CollisionShape3D.new()
		collision.position.y = size.y * 0.5
		collision.shape = shape
		anchor.add_child(body)
		body.add_child(collision)
	return anchor


func _label(at: Vector3, message: String) -> void:
	var sign := _geometry.signage(self, at, message, 24, Color("#ffedbd"))
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.no_depth_test = false


func near_exit(point: Vector3) -> bool:
	return to_local(point).distance_to(EXIT) < 2.35


func near_bottle(point: Vector3) -> bool:
	return is_instance_valid(bottle) and to_local(point).distance_to(BOTTLE) < 1.55


func take_bottle() -> void:
	if is_instance_valid(bottle):
		bottle.queue_free()
		bottle = null

