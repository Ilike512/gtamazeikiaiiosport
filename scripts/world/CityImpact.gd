extends Node3D

const Geometry = preload("res://scripts/world/Geometry.gd")
const CityMesh = preload("res://scripts/world/CityMesh.gd")
const INJURY_POOL = preload("res://assets/shaders/injury_pool.gdshader")
const STAIN_LIMIT := 480
const WALL_LIMIT := 72
const BLOOD_LIFE := 2700.0
const BLOOD_FADE := 540.0
const MAX_ACTIVE_SPRAYS := 8
const EquipmentProfiles = preload("res://scripts/world/EquipmentProfiles.gd")

var _geometry := Geometry.new()
var _scars: Array[Node3D] = []
var _serial := 0
var _rubble: Array[RigidBody3D] = []
var _stains: Array[MeshInstance3D] = []
var _blood_particle: SphereMesh
var _sprays: Array[CPUParticles3D] = []
var _effect_age := 0.0
var _next_fade_update := 0.0


func _ready() -> void:
	add_to_group("city_impact")
	_blood_particle = SphereMesh.new()
	_blood_particle.radius = 0.048
	_blood_particle.height = 0.122
	_blood_particle.radial_segments = 6
	_blood_particle.rings = 3
	var wet := StandardMaterial3D.new()
	wet.albedo_color = Color("#880e20")
	wet.roughness = 0.23
	_blood_particle.material = wet


func _process(delta: float) -> void:
	_effect_age += delta
	if _effect_age < _next_fade_update:
		return
	_next_fade_update = _effect_age + 0.8
	for stain: MeshInstance3D in _stains.duplicate():
		var life := float(stain.get_meta("expires")) - _effect_age
		if life <= 0.0:
			_stains.erase(stain)
			stain.queue_free()
		elif bool(stain.get_meta("blood")):
			_apply_stain_opacity(stain, life)


func _apply_stain_opacity(stain: MeshInstance3D, life: float) -> void:
	var tint: Color = stain.get_meta("tint")
	tint.a *= smoothstep(0.0, BLOOD_FADE, life)
	(stain.material_override as ShaderMaterial).set_shader_parameter("stain", tint)
	stain.visible = int(GameManager.settings.injury_effects) > 0


func drip(at: Vector3, span := 0.15) -> void:
	if int(GameManager.settings.injury_effects) == 0:
		return
	var ground := _surface_below(at)
	if not ground.is_empty():
		_ground_stain(ground.position, ground.normal, span, Color("#630a1bd9"), true)


func blood_near(at: Vector3) -> bool:
	for stain: MeshInstance3D in _stains:
		if bool(stain.get_meta("blood")) and stain.global_position.distance_squared_to(at) < 1.0:
			return true
	return false


func save_state() -> Dictionary:
	var stains: Array[Dictionary] = []
	var walls: Array[Dictionary] = []
	for stain: MeshInstance3D in _stains:
		var tint: Color = stain.get_meta("tint")
		stains.append({"point": SaveManager.vector_data(stain.get_meta("surface")), "normal": SaveManager.vector_data(stain.get_meta("normal")),
			"rotation": SaveManager.vector_data(stain.rotation), "scale": SaveManager.vector_data(stain.scale),
			"span": stain.get_meta("span"), "tint": tint.to_html(), "blood": stain.get_meta("blood"),
			"life": float(stain.get_meta("expires")) - _effect_age})
	for scar: Node3D in _scars:
		walls.append(scar.get_meta("damage"))
	return {"stains": stains, "walls": walls}


func restore_state(value: Variant) -> void:
	if value is not Dictionary:
		return
	var stain_rows: Variant = value.get("stains", [])
	if stain_rows is Array:
		for row: Variant in stain_rows.slice(-STAIN_LIMIT):
			if row is not Dictionary or float(row.get("life", 0.0)) <= 0.0:
				continue
			var point := SaveManager.read_vector(row.get("point"), Vector3.INF)
			if not point.is_finite():
				continue
			var normal := SaveManager.read_vector(row.get("normal"), Vector3.UP).normalized()
			if normal.is_zero_approx():
				normal = Vector3.UP
			var span := clampf(float(row.get("span", 0.2)), 0.04, 6.0)
			var tint := Color.from_string(str(row.get("tint", "")), Color("#650d24de"))
			var stain := _ground_stain(point, normal, span, tint, bool(row.get("blood", true)), clampf(float(row.life), 0.0, BLOOD_LIFE))
			stain.rotation = SaveManager.read_vector(row.get("rotation"), stain.rotation)
			stain.scale = SaveManager.read_vector(row.get("scale"), stain.scale).clamp(Vector3.ONE * 0.1, Vector3.ONE * 3.0)
	var wall_rows: Variant = value.get("walls", [])
	if wall_rows is Array:
		for row: Variant in wall_rows.slice(-WALL_LIMIT):
			if row is not Dictionary:
				continue
			var point := SaveManager.read_vector(row.get("point"), Vector3.INF)
			var normal := SaveManager.read_vector(row.get("normal"), Vector3.ZERO).slide(Vector3.UP)
			if point.is_finite() and normal.length_squared() > 0.5:
				_wall_scar(point, normal.normalized(), clampf(float(row.get("strength", 8.0)), 4.1, 64.0), int(row.get("pattern", 0)))


func injury(at: Vector3, direction: Vector3, severity: float) -> void:
	var detail := int(GameManager.settings.injury_effects)
	if detail == 0 or severity < 2.1:
		return
	var heading := direction.slide(Vector3.UP).normalized()
	if heading.length_squared() < 0.1:
		heading = Vector3.FORWARD.rotated(Vector3.UP, randf() * TAU)
	var ground := _surface_below(at)
	if not ground.is_empty():
		var pool := _ground_stain(ground.position, ground.normal, clampf(severity * (0.146 if detail == 2 else 0.054), 0.25, 4.65), Color("#54091bef"), true)
		pool.scale *= 0.5
		create_tween().tween_property(pool, "scale", Vector3(1.14, 1.0, 1.48 if detail == 2 else 0.95), 1.65)
		if detail == 2:
			_scatter_stains(ground.position, heading, severity)
	_blood_spray(at, heading, severity, detail == 2)
	if detail == 2 and severity >= 8.5:
		_blood_spray(at + Vector3.UP * 0.13, heading.rotated(Vector3.UP, randf_range(-0.45, 0.45)), severity * 0.46, false)


func _surface_below(at: Vector3) -> Dictionary:
	var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.85, at - Vector3.UP * 3.25, 1)
	return get_world_3d().direct_space_state.intersect_ray(ray)


func _scatter_stains(at: Vector3, direction: Vector3, severity: float) -> void:
	var side := Vector3.UP.cross(direction)
	for index in clampi(roundi(severity * 1.85), 9, 53):
		var forward := randf_range(-0.56, minf(7.6, severity * 0.27))
		var offset := direction * forward + side * randf_range(-0.9, 0.9) * (0.38 + absf(forward) * 0.32)
		var hit := _surface_below(at + offset)
		if hit.is_empty():
			continue
		var span := randf_range(0.08, 0.41) * (1.0 + severity * 0.023)
		var tint := Color("#700c20e5") if index % 3 == 0 else Color("#480915ef")
		var stain := _ground_stain(hit.position, hit.normal, span, tint, true)
		stain.rotate(hit.normal, atan2(-direction.x, -direction.z) + randf_range(-0.48, 0.48))
		stain.scale.z = randf_range(1.15, 2.05)


func _blood_spray(at: Vector3, direction: Vector3, severity: float, full: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = clampi(roundi(severity * 11.0), 52, 245) if full else 14
	particles.lifetime = 0.91 if full else 0.53
	particles.randomness = 0.25
	particles.mesh = _blood_particle
	particles.direction = (direction * 0.7 + Vector3.UP).normalized()
	particles.spread = 52.0 if full else 31.0
	particles.initial_velocity_min = 1.8
	particles.initial_velocity_max = clampf(severity * 0.39, 2.9, 10.2)
	particles.gravity = Vector3.DOWN * 15.0
	particles.scale_amount_min = 0.28
	particles.scale_amount_max = 1.26 if full else 0.62
	particles.angular_velocity_min = -340.0
	particles.angular_velocity_max = 340.0
	particles.position = at
	add_child(particles)
	particles.emitting = true
	_sprays.append(particles)
	if _sprays.size() > MAX_ACTIVE_SPRAYS:
		_sprays.pop_front().queue_free()
	get_tree().create_timer(1.12, false).timeout.connect(func() -> void:
		if is_instance_valid(particles):
			_sprays.erase(particles)
			particles.queue_free()
	)


func game_flash(at: Vector3, scale := 1.0) -> void:
	var flare := OmniLight3D.new()
	flare.light_color = Color("#ffbc6e")
	flare.light_energy = 2.8
	flare.omni_range = 8.0 * scale
	add_child(flare)
	flare.global_position = at
	var particles := CPUParticles3D.new()
	particles.position = at
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.amount = 26 if SettingsManager.mobile_battery_saver() else roundi(26 * scale)
	particles.spread = 172.0
	particles.lifetime = 0.64
	particles.initial_velocity_min = 3.5
	particles.initial_velocity_max = 9.3 * scale
	particles.scale_amount_min = 0.22
	particles.scale_amount_max = 0.72
	var spark := SphereMesh.new()
	spark.radius = 0.060 * scale
	spark.height = 0.12 * scale
	spark.material = _geometry.material(Color("#e9ab62"))
	particles.mesh = spark
	add_child(particles)
	var fade := flare.create_tween()
	fade.tween_property(flare, "light_energy", 0.0, 0.55)
	fade.tween_callback(flare.queue_free)
	get_tree().create_timer(0.85, false).timeout.connect(particles.queue_free)


func equipment_effect(kind: String, start: Vector3, finish: Vector3, normal: Vector3) -> void:
	if EquipmentProfiles.is_firearm(kind):
		var sound := AudioStreamPlayer3D.new()
		sound.stream = AssetShelf.sound("gunshot", "res://assets/audio/sfx/gunshot_supplied.mp3")
		if sound.stream == null:
			sound.stream = AssetShelf.sound("gunshot", "res://assets/audio/sfx/gunshot.wav")
		sound.bus = &"SFX"
		sound.unit_size = 8.0
		sound.max_distance = 125.0
		if sound.stream != null:
			add_child(sound)
			sound.global_position = start
			sound.finished.connect(sound.queue_free)
			sound.play()
			get_tree().create_timer(0.85).timeout.connect(func() -> void:
				if is_instance_valid(sound):
					sound.queue_free())
		else:
			sound.free()
		var muzzle := OmniLight3D.new()
		muzzle.light_color = Color("#ffc786")
		muzzle.light_energy = 2.1
		muzzle.omni_range = 2.5
		add_child(muzzle)
		muzzle.global_position = start + start.direction_to(finish) * 0.5
		get_tree().create_timer(0.07).timeout.connect(muzzle.queue_free)
	if kind == "marker" and normal.length_squared() > 0.5:
		_ground_stain(finish, normal, 0.48, Color("#d8514ce5"))
		return
	if kind != "baton":
		var tone := Color("#76dbe8") if kind == "pulse" else Color("#ff9f53")
		var trace := _geometry.box(self, (start + finish) * 0.5, Vector3(0.022, 0.022, maxf(start.distance_to(finish), 0.05)), tone)
		trace.look_at(finish, Vector3.UP)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = tone
		trace.material_override = material
		get_tree().create_timer(0.10).timeout.connect(trace.queue_free)
	if kind == "flare":
		var flare := OmniLight3D.new()
		flare.position = finish + normal * 0.07
		flare.light_color = Color("#ffa755")
		flare.omni_range = 6.0
		flare.light_energy = 2.5
		add_child(flare)
		var fade := create_tween()
		fade.tween_property(flare, "light_energy", 0.0, 3.5)
		fade.tween_callback(flare.queue_free)


func _ground_stain(at: Vector3, normal: Vector3, span: float, tint: Color, blood := false, lifetime := BLOOD_LIFE) -> MeshInstance3D:
	var stain := MeshInstance3D.new()
	var shape := PlaneMesh.new()
	shape.size = Vector2(span, span * 0.82)
	var material := ShaderMaterial.new()
	material.shader = INJURY_POOL
	material.set_shader_parameter("stain", tint)
	stain.mesh = shape
	stain.material_override = material
	stain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stain.visibility_range_end = 155.0
	stain.set_meta("surface", at)
	stain.set_meta("normal", normal)
	stain.set_meta("span", span)
	stain.set_meta("tint", tint)
	stain.set_meta("blood", blood)
	stain.set_meta("expires", _effect_age + lifetime)
	if blood:
		_apply_stain_opacity(stain, lifetime)
	add_child(stain)
	var tangent := normal.cross(Vector3.RIGHT).normalized()
	if tangent.length_squared() < 0.5:
		tangent = normal.cross(Vector3.FORWARD).normalized()
	stain.basis = Basis(normal.cross(tangent), normal, tangent).orthonormalized()
	stain.position = at + normal * 0.017
	_stains.append(stain)
	if _stains.size() > STAIN_LIMIT:
		_stains.pop_front().queue_free()
	return stain


func facade_hit(target: Node3D, at: Vector3, normal: Vector3, strength: float) -> void:
	if strength < 4.1:
		return
	var ahead := normal.slide(Vector3.UP).normalized()
	if ahead.length_squared() < 0.08:
		return
	var probe := PhysicsRayQueryParameters3D.create(at + ahead * 0.85, at - ahead * 0.63, 1)
	var surface := get_world_3d().direct_space_state.intersect_ray(probe)
	if not surface.is_empty() and surface.collider == target and absf(surface.normal.y) < 0.40:
		at = surface.position
		ahead = surface.normal.slide(Vector3.UP).normalized()
	var glass := target.is_in_group("breakable_fixture")
	if glass:
		if target.get_meta("broken", false):
			return
		target.set_meta("broken", true)
		target.collision_layer = 0
		target.get_parent().hide()
	_serial += 1
	if not glass:
		_wall_scar(at, ahead, strength)
	_fragments(at, ahead, strength, glass)
	_dust(at, ahead, strength, glass)


func _wall_scar(at: Vector3, normal: Vector3, strength: float, seed := -1) -> void:
	var pattern := _serial if seed < 0 else seed
	var root := Node3D.new()
	add_child(root)
	root.global_position = at + normal * 0.031
	root.look_at(root.global_position + normal)
	_scars.append(root)
	root.set_meta("damage", {"point": SaveManager.vector_data(at), "normal": SaveManager.vector_data(normal), "strength": strength, "pattern": pattern})
	if _scars.size() > WALL_LIMIT:
		_scars.pop_front().queue_free()
	var muck := StandardMaterial3D.new()
	muck.cull_mode = BaseMaterial3D.CULL_DISABLED
	muck.vertex_color_use_as_albedo = true
	muck.roughness = 0.99
	var mesh := CityMesh.new()
	var radius := clampf(strength * 0.104, 0.50, 2.55)
	var crater := Vector3(0.035, -0.02, 0.016)
	for index in 13:
		var theta := TAU * float(index) / 13
		var phi := TAU * (index + 1.0) / 13.0
		var start := Vector2.from_angle(theta) * radius * (0.72 + 0.27 * absf(sin(index * 5 + pattern)))
		var finish := Vector2.from_angle(phi) * radius * (0.72 + 0.27 * absf(sin((index + 1) * 5 + pattern)))
		var a := Vector3(start.x, start.y * 0.63, 0)
		var b := Vector3(finish.x, finish.y * 0.63, 0)
		mesh.triangle(crater, a, b, Color("#514942") if index % 3 == 0 else Color("#68605a"))
	mesh.make_node(root, muck, false, false)
	for line in 8:
		var angle := (line - 3.5) * 0.65 + (pattern % 3) * 0.22
		var extent := radius * (0.83 + (line % 3) * 0.21)
		var delta := Vector2.from_angle(angle) * extent
		var bar := _geometry.box(root, Vector3(delta.x * 0.5, delta.y * 0.5, -0.004), Vector3(extent, 0.021, 0.016), Color("#3c3837"))
		bar.rotation.z = angle


func _fragments(at: Vector3, normal: Vector3, strength: float, glass: bool) -> void:
	var shade := Color("#b0c5c1") if glass else Color("#898174")
	for index in clampi(roundi(strength * 0.69), 4, 15):
		var piece := RigidBody3D.new()
		piece.mass = 0.08 if glass else 0.45
		piece.collision_layer = 32
		piece.collision_mask = 1
		piece.position = at + normal * 0.16
		add_child(piece)
		var extent := randf_range(0.045, 0.17)
		var dimensions := Vector3(extent, extent * (0.22 if glass else 0.66), extent * 0.76)
		_geometry.box(piece, Vector3.ZERO, dimensions, shade.lightened(randf_range(-0.16, 0.17)))
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dimensions
		collider.shape = shape
		piece.add_child(collider)
		var spread := Vector3(sin(index * 2.4), randf_range(0.45, 1.45), cos(index * 3.3))
		piece.linear_velocity = (normal * 1.25 + spread * 0.68) * minf(strength * 0.31, 5.4)
		piece.angular_velocity = spread * 8.0
		_rubble.append(piece)
		if _rubble.size() > 68:
			_rubble.pop_front().queue_free()
		get_tree().create_timer(10.0, false).timeout.connect(func() -> void:
			if is_instance_valid(piece):
				_rubble.erase(piece)
				piece.queue_free())


func _dust(at: Vector3, normal: Vector3, strength: float, glass: bool) -> void:
	var cloud := CPUParticles3D.new()
	cloud.position = at + normal * 0.18
	cloud.emitting = false
	cloud.one_shot = true
	cloud.explosiveness = 0.88
	cloud.lifetime = 0.83
	cloud.amount = clampi(roundi(strength * 3.9), 15, 68)
	cloud.direction = (normal + Vector3.UP * 0.30).normalized()
	cloud.spread = 59.0
	cloud.gravity = Vector3.UP * 0.12
	cloud.initial_velocity_min = 0.6
	cloud.initial_velocity_max = minf(strength * 0.25, 4.2)
	var mesh := SphereMesh.new()
	mesh.radius = 0.10
	mesh.height = 0.20
	mesh.radial_segments = 5
	mesh.rings = 3
	var dust := StandardMaterial3D.new()
	dust.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust.albedo_color = Color("#b1bfba46") if glass else Color("#b2a48c62")
	mesh.material = dust
	cloud.mesh = mesh
	add_child(cloud)
	cloud.emitting = true
	get_tree().create_timer(1.35, false).timeout.connect(cloud.queue_free)
