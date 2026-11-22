extends Node3D


func _ready() -> void:
	var spark := SphereMesh.new()
	spark.radius = 0.13
	spark.height = 0.33
	spark.radial_segments = 7
	spark.rings = 3
	var hot := StandardMaterial3D.new()
	hot.albedo_color = Color("#ff8e30")
	hot.emission_enabled = true
	hot.emission = Color("#ff5f24")
	hot.emission_energy_multiplier = 1.32
	spark.material = hot
	var flames := CPUParticles3D.new()
	flames.amount = 11 if SettingsManager.mobile_battery_saver() else (18 if int(GameManager.settings.quality) < 2 else 32)
	flames.lifetime = 0.64
	flames.spread = 29.0
	flames.direction = Vector3.UP
	flames.gravity = Vector3.UP * 2.0
	flames.initial_velocity_min = 0.8
	flames.initial_velocity_max = 2.4
	flames.scale_amount_min = 0.65
	flames.scale_amount_max = 1.65
	flames.mesh = spark
	add_child(flames)
	var lamp := OmniLight3D.new()
	lamp.light_color = Color("#ff8d44")
	lamp.light_energy = 1.1
	lamp.omni_range = 4.6
	lamp.visible = int(GameManager.settings.quality) > 0
	add_child(lamp)

