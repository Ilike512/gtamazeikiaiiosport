extends Node3D

var rain := 0.0
var snow := 0.0
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _loop: AudioStreamPlayer
var _time := 0.0


func _ready() -> void:
	_rain = _precipitation(true)
	_snow = _precipitation(false)
	_loop = AudioStreamPlayer.new()
	_loop.bus = &"SFX"
	_loop.stream = AssetShelf.sound("rain", "res://assets/audio/sfx/rain.wav", true)
	_loop.volume_db = -55
	add_child(_loop)
	GameManager.settings_changed.connect(_apply_particle_budget)
	_apply_particle_budget()


func update_weather(delta: float, follow: Vector3, inside: bool, setting: int) -> void:
	global_position = follow + Vector3.UP * 14.0
	_time += delta
	var forecast := setting
	if forecast == 0:
		var phase := fposmod(_time + 18.0, 244.0)
		forecast = 1 if phase < 57.0 or (phase >= 118.0 and phase < 141.0) else 2 if phase < 118.0 else 3
	rain = move_toward(rain, 1.0 if forecast == 2 else 0.0, delta * 0.34)
	snow = move_toward(snow, 1.0 if forecast == 3 else 0.0, delta * 0.24)
	_rendering(rain, snow)
	_rain.emitting = rain > 0.13 and not inside
	_snow.emitting = snow > 0.13 and not inside
	if rain > 0.08 and not _loop.playing and _loop.stream != null:
		_loop.play()
	if _loop.playing:
		_loop.volume_db = lerpf(-52.0, -15.0 - (13.0 if inside else 0.0), rain)
		if rain <= 0.002:
			_loop.stop()


func _apply_particle_budget() -> void:
	var economy := SettingsManager.mobile_battery_saver()
	_rain.amount = 240 if economy else 1840
	_snow.amount = 110 if economy else 480


func _exit_tree() -> void:
	_rendering(0.0, 0.0)


func _rendering(wet: float, icy: float) -> void:
	RenderingServer.global_shader_parameter_set(&"city_wetness", wet)
	RenderingServer.global_shader_parameter_set(&"city_snow", icy)


func _precipitation(is_rain: bool) -> CPUParticles3D:
	var particles := CPUParticles3D.new()
	particles.name = "DrivingRain" if is_rain else "DriftingSnow"
	particles.emitting = false
	particles.lifetime = 1.23 if is_rain else 5.7
	particles.preprocess = particles.lifetime
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(22, 5, 23)
	particles.direction = Vector3(0.19, -1.0, 0.09).normalized()
	particles.initial_velocity_min = 10.6 if is_rain else 1.16
	particles.initial_velocity_max = 14.2 if is_rain else 2.1
	particles.spread = 6.0 if is_rain else 16.0
	particles.gravity = Vector3(1.2, -10.0, 0.22) if is_rain else Vector3(0.46, -0.53, 0.20)
	particles.scale_amount_min = 0.47
	particles.scale_amount_max = 1.12
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var shape := QuadMesh.new()
	shape.size = Vector2(0.023, 0.75) if is_rain else Vector2(0.093, 0.093)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color("#c5e0ee72") if is_rain else Color("#e9f2f5bd")
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	if is_rain:
		var falloff := Gradient.new()
		falloff.colors = PackedColorArray([Color.TRANSPARENT, Color.WHITE, Color("#b9d0e000")])
		falloff.offsets = PackedFloat32Array([0.0, 0.72, 1.0])
		var texture := GradientTexture2D.new()
		texture.gradient = falloff
		texture.width = 4
		texture.height = 32
		texture.fill_to = Vector2(0.0, 1.0)
		material.albedo_texture = texture
	shape.material = material
	particles.mesh = shape
	add_child(particles)
	return particles
