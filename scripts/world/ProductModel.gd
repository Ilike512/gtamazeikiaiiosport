extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const ModelBounds = preload("res://scripts/world/ModelBounds.gd")
const CC0_GEAR := {
	"service_pistol": "pistol", "sport_pistol": "colt_1911", "old_revolver": "magnum_44",
	"patrol_carbine": "m16", "field_carbine": "ak47", "pump_scattergun": "12_gauge",
	"short_scattergun": "12_gauge", "trainer_blade": "karambit", "field_blade": "karambit",
}


func build(item: Dictionary, extent: float) -> Vector3:
	var asset := str(item.get("model", item.id if str(item.id) in ["phone", "wallet", "street_map", "bus_ticket"] else "bag-flat"))
	var scene_path := "res://assets/models/grocery/%s.glb" % asset
	var supplied := "res://assets/models/supplied/beer-bottle-psx/beer_bottle.glb"
	var imported_beer: bool = item.get("id") == "beer" and ResourceLoader.exists(supplied, "PackedScene")
	if imported_beer:
		scene_path = supplied
	var geo := Geometry.new()
	var root: Node3D = self
	var documented := str(CC0_GEAR.get(str(item.id), ""))
	var gear_path := "res://assets/models/gear/%s.obj" % documented
	if item.has("can_color"):
		var tint := Color.from_string(str(item.can_color), Color.GRAY)
		root = Node3D.new()
		add_child(root)
		geo.taper(root, Vector3.ZERO, 0.165 if str(item.id).begins_with("monster") else 0.13, 0.033, 0.032, tint, 20)
		geo.taper(root, Vector3.UP * (0.083 if str(item.id).begins_with("monster") else 0.065), 0.008, 0.029, 0.030, Color("#c4c8c3"), 20)
	elif not documented.is_empty() and ResourceLoader.exists(gear_path, "Mesh"):
		root = Node3D.new()
		add_child(root)
		var prop := MeshInstance3D.new()
		prop.mesh = load(gear_path)
		root.add_child(prop)
		if prop.mesh.get_aabb().size.z > prop.mesh.get_aabb().size.x:
			prop.rotation.y = -PI * 0.5
		if item.id == "short_scattergun":
			prop.scale.z = 0.72
	elif ResourceLoader.exists(scene_path, "PackedScene"):
		var scene: PackedScene = load(scene_path)
		root = scene.instantiate() as Node3D
		add_child(root)
	else:
		root = Node3D.new()
		add_child(root)
		_packaged(root, geo, asset)
	var bounds := ModelBounds.measure(root)
	var factor := extent / maxf(0.01, maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)))
	root.scale = Vector3.ONE * factor
	root.position = -bounds.get_center() * factor
	var dimensions := (bounds.size * factor).max(Vector3.ONE * 0.045)
	if not imported_beer:
		_product_label(item, geo, dimensions)
	return dimensions


func _product_label(item: Dictionary, geo: RefCounted, dimensions: Vector3) -> void:
	var slug := str(item.id)
	var labels := {
		"cola": ["COLA", Color("#b73b36")],
		"sprunk": ["SPRUNK", Color("#438b3f")],
		"stotis_sprunk": ["SPRUNK", Color("#438b3f")],
		"stotis_mcpiss": ["MCPISS", Color("#e78032")],
		"lemon_lime": ["7UP", Color("#317952")],
		"kvass_bottle": ["KVASS", Color("#785440")],
		"kefyras": ["KEFYRAS", Color("#4a7786")],
		"obuoliu_sultys": ["OBUOLIŲ", Color("#637f41")],
		"gira": ["GIRA", Color("#764b31")],
		"beer": ["LAGER", Color("#ba973e")],
		"nuggets": ["NUGGETS", Color("#b76b3c")],
		"yogurt": ["JOGURTAS", Color("#af5470")],
		"frozen_burgers": ["BURGERS", Color("#b14a34")]
	}
	var tag: Array = labels.get(slug, [])
	if item.has("can_label"):
		tag = [str(item.can_label), Color.from_string(str(item.can_color), Color.GRAY).darkened(0.29)]
	if tag.is_empty():
		return
	var board: MeshInstance3D = geo.box(self, Vector3(0, 0, dimensions.z * 0.50 + 0.005),
		Vector3(dimensions.x * 0.82, dimensions.y * 0.36, 0.01), tag[1])
	var words: Label3D = geo.signage(self, board.position + Vector3.BACK * 0.007, tag[0], 20, Color("#fff4d9"))
	words.pixel_size = dimensions.x / 113.0
	words.outline_size = 0


func _packaged(root: Node3D, geo: RefCounted, asset: String) -> void:
	match asset:
		"game-bomb":
			geo.taper(root, Vector3.ZERO, 0.12, 0.093, 0.093, Color("#843b46"), 12)
			geo.box(root, Vector3.UP * 0.072, Vector3(0.105, 0.027, 0.076), Color("#423c41"))
			geo.box(root, Vector3(0, 0.087, 0.019), Vector3(0.054, 0.011, 0.023), Color("#ffb25b"))
		"game-launcher":
			var body: MeshInstance3D = geo.taper(root, Vector3.ZERO, 0.81, 0.041, 0.053, Color("#565b49"), 15)
			body.rotation.z = PI * 0.5
			geo.box(root, Vector3(0, -0.078, 0), Vector3(0.075, 0.13, 0.074), Color("#38383a"))
		"yoyo":
			for side: float in [-1.0, 1.0]:
				geo.taper(root, Vector3.UP * 0.015 * side, 0.016, 0.053, 0.053, Color("#a453ad"), 16)
			geo.taper(root, Vector3.ZERO, 0.021, 0.028, 0.028, Color("#ded1bc"), 14)
		"weed":
			geo.box(root, Vector3.ZERO, Vector3(0.11, 0.15, 0.053), Color("#827b52"))
			geo.box(root, Vector3(0, 0.057, 0.027), Vector3(0.111, 0.014, 0.008), Color("#b4a777"))
			geo.box(root, Vector3(0, -0.012, 0.029), Vector3(0.072, 0.058, 0.007), Color("#4b603c"))
		"wallet", "street_map", "bus_ticket":
			geo.box(root, Vector3.ZERO, Vector3(0.13, 0.092, 0.031 if asset == "wallet" else 0.008), Color("#5a443c") if asset == "wallet" else Color("#d0bfa0"))
		"dropper":
			geo.taper(root, Vector3.ZERO, 0.094, 0.023, 0.025, Color("#604577"), 12)
			geo.taper(root, Vector3.UP * 0.054, 0.026, 0.011, 0.017, Color("#dedbd3"), 12)
		"patch":
			geo.box(root, Vector3.ZERO, Vector3(0.095, 0.054, 0.012), Color("#8468a0"))
			geo.box(root, Vector3.BACK * 0.008, Vector3(0.061, 0.037, 0.004), Color("#c5b2df"))
		"pill-case":
			geo.taper(root, Vector3.ZERO, 0.071, 0.032, 0.032, Color("#508781"), 12)
			geo.taper(root, Vector3.UP * 0.034, 0.018, 0.034, 0.034, Color("#d6d7d4"), 12)
		"bat":
			geo.taper(root, Vector3.UP * 0.17, 0.55, 0.038, 0.016, Color("#ad7756"), 12)
			geo.taper(root, -Vector3.UP * 0.11, 0.047, 0.023, 0.025, Color("#514436"), 12)
		"hammer", "crowbar", "blade", "wand":
			var head: Color = Color("#946349") if asset != "wand" else Color("#66afae")
			geo.box(root, Vector3(0, -0.05, 0), Vector3(0.037, 0.38 if asset != "blade" else 0.17, 0.041), Color("#414a4a"))
			if asset == "hammer":
				geo.box(root, Vector3(0, 0.145, 0), Vector3(0.22, 0.081, 0.078), head)
			elif asset == "crowbar":
				var bent: MeshInstance3D = geo.box(root, Vector3(0.037, 0.158, 0), Vector3(0.105, 0.038, 0.042), head)
				bent.rotation.z = -0.43
			else:
				geo.box(root, Vector3(0, 0.125, 0), Vector3(0.047, 0.18, 0.027), head)
		"revolver", "compact", "scattergun":
			var long := asset == "scattergun"
			var metal := Color("#404d51")
			var part_length := 0.45 if long else (0.26 if asset == "compact" else 0.16)
			geo.box(root, Vector3(part_length * 0.1, 0.041, 0), Vector3(part_length, 0.061, 0.051), metal)
			var grip: MeshInstance3D = geo.box(root, Vector3(-part_length * 0.28, -0.031, 0), Vector3(0.046, 0.116, 0.047), Color("#60524a"))
			grip.rotation.z = -0.21
			if long:
				geo.box(root, Vector3(0.08, 0.012, 0), Vector3(0.16, 0.051, 0.06), Color("#796047"))
			elif asset == "compact":
				geo.box(root, Vector3(0.01, -0.044, 0), Vector3(0.039, 0.107, 0.035), metal.darkened(0.22))
			else:
				var drum: MeshInstance3D = geo.taper(root, Vector3(-0.014, 0.038, 0), 0.054, 0.040, 0.040, metal.lightened(0.18), 12)
				drum.rotation.z = PI * 0.5
		"phone":
			geo.box(root, Vector3.ZERO, Vector3(0.077, 0.155, 0.014), Color("#363d47"))
			geo.box(root, Vector3(0, 0.005, 0.008), Vector3(0.069, 0.139, 0.002), Color("#416684"))
			geo.box(root, Vector3(0, 0.065, 0.01), Vector3(0.018, 0.005, 0.002), Color("#202933"))
		"vape":
			geo.taper(root, Vector3.ZERO, 0.115, 0.012, 0.013, Color("#5c8e91"), 12)
			geo.taper(root, Vector3.UP * 0.06, 0.023, 0.006, 0.011, Color("#31333b"), 12)
		"toy":
			geo.box(root, Vector3.ZERO, Vector3(0.225, 0.165, 0.061), Color("#b33f38"))
			for index in 3:
				geo.box(root, Vector3(-0.057 + 0.04 * index, -0.025 + index * 0.019, 0.033),
					Vector3(0.062, 0.032, 0.009), [Color("#f4d274"), Color("#68a0bd"), Color("#84b67b")][index])
		"carbine", "scope-rifle":
			geo.box(root, Vector3(-0.03, 0.037, 0), Vector3(0.55, 0.072, 0.043), Color("#303b40"))
			geo.box(root, Vector3(-0.33, 0.016, 0), Vector3(0.12, 0.092, 0.036), Color("#705c46"))
			geo.box(root, Vector3(0.32, 0.054, 0), Vector3(0.20, 0.027, 0.031), Color("#273235"))
			geo.box(root, Vector3(0.03, -0.026, 0), Vector3(0.066, 0.105, 0.038), Color("#272d31"))
			if asset == "scope-rifle":
				var scope: MeshInstance3D = geo.taper(root, Vector3(0, 0.117, 0), 0.24, 0.025, 0.025, Color("#1c282c"), 12)
				scope.rotation.z = PI * 0.5
		"replica":
			geo.box(root, Vector3(0.018, 0.04, 0), Vector3(0.17, 0.032, 0.036), Color("#313947"))
			var grip: MeshInstance3D = geo.box(root, Vector3(-0.044, -0.009, 0), Vector3(0.042, 0.089, 0.031), Color("#252830"))
			grip.rotation.z = -0.27
			geo.box(root, Vector3(0.111, 0.04, 0), Vector3(0.019, 0.026, 0.031), Color("#ea854f"))
		_:
			geo.box(root, Vector3.ZERO, Vector3(0.18, 0.23, 0.087), Color("#b49268"))
