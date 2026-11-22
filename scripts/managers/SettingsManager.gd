extends Node

const DEFAULTS := {
	"quality": 1, "render_scale": 0.0, "upscaler": 0, "msaa": 0, "shadows": 0,
	"ambient_occlusion": 0, "reflections": 0, "global_illumination": 0, "volume_fog": 0,
	"bloom": 0, "surface_detail": 0, "bloom_strength": 1.0, "weather": 0,
	"fog_density": 0.0025, "fog_height_density": 0.032, "shadow_softness": 1.0,
	"world_textures": 2, "view_distance_km": 0.75, "greenery_density": 0.85,
	"street_detail": 0, "mobile_display": 1, "mobile_power": 0
}
const PRESET_SCALES := [0.60, 0.78, 0.90, 1.0]
const PRESET_SAMPLE_COUNTS := [0, 0, 1, 2]
const SHADOW_ATLASES := [1024, 2048, 3072, 4096]

var _last_atlas := -1


func is_forward_plus() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


func view_distance() -> float:
	var max_distance := 0.65 if mobile_battery_saver() else 2.5
	return clampf(float(GameManager.settings.view_distance_km), 0.30, max_distance) * 1000.0


func quality(settings: Dictionary) -> int:
	return clampi(int(settings.quality), 0, 3)


func mobile_battery_saver() -> bool:
	return OS.has_feature("mobile") and int(GameManager.settings.mobile_power) == 0


func street_detail_distance() -> float:
	var settings: Dictionary = GameManager.settings
	var detail := clampi(int(settings.street_detail), 0, 3)
	if detail == 0:
		return [0.0, 145.0, 235.0, 320.0][quality(settings)]
	return [0.0, 0.0, 145.0, 320.0][detail]


func apply_viewport(viewport: Viewport, settings: Dictionary) -> void:
	var preset := quality(settings)
	var method := RenderingServer.get_current_rendering_method()
	var upscaler := int(settings.upscaler)
	viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	if method == "forward_plus":
		if upscaler == 3:
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR2
		elif upscaler == 2 or (upscaler == 0 and preset < 2):
			viewport.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	var scale_override := float(settings.render_scale)
	viewport.scaling_3d_scale = clampf(scale_override, 0.5, 1.0) if scale_override > 0.01 else PRESET_SCALES[preset]
	var samples := int(settings.msaa)
	var sample_level: int = clampi(samples - 1, 0, 2) if samples > 0 else PRESET_SAMPLE_COUNTS[preset]
	if mobile_battery_saver():
		viewport.scaling_3d_scale = minf(viewport.scaling_3d_scale, 0.57)
		sample_level = 0
	viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][sample_level]
	var shadow := shadow_level(settings)
	if _last_atlas != shadow:
		_last_atlas = shadow
		RenderingServer.directional_shadow_atlas_set_size(SHADOW_ATLASES[shadow], shadow < 2)
	var textures := clampi(int(settings.world_textures), 0, 2)
	RenderingServer.global_shader_parameter_set(&"city_textures", [0.0, 0.45, 1.0][textures])
	var detail := int(settings.surface_detail)
	RenderingServer.global_shader_parameter_set(&"city_detail", float(detail - 1) * 0.5 if detail > 0 else [0.0, 0.55, 0.82, 1.0][preset])


func apply_city(environment: Environment, sun: DirectionalLight3D, grading: ShaderMaterial, settings: Dictionary) -> void:
	var preset := quality(settings)
	var shadows := shadow_level(settings)
	sun.shadow_enabled = shadows > 0 and not mobile_battery_saver()
	sun.directional_shadow_max_distance = [70.0, 112.0, 185.0, 235.0][shadows]
	sun.shadow_blur = [0.60, 0.85, 1.10, 1.32][shadows] * clampf(float(settings.shadow_softness), 0.3, 2.0)
	var renderer := RenderingServer.get_current_rendering_method()
	var advanced := renderer == "forward_plus"
	environment.ssao_enabled = (advanced or renderer == "gl_compatibility") and not mobile_battery_saver() and _enabled(settings, "ambient_occlusion", preset >= 2)
	environment.ssr_enabled = advanced and _enabled(settings, "reflections", preset >= 3)
	environment.sdfgi_enabled = advanced and _enabled(settings, "global_illumination", preset >= 3)
	environment.volumetric_fog_enabled = advanced and _enabled(settings, "volume_fog", preset >= 3)
	environment.fog_density = clampf(float(settings.fog_density), 0.0, 0.012)
	environment.fog_height_density = clampf(float(settings.fog_height_density), 0.0, 0.10)
	environment.fog_enabled = environment.fog_density > 0.0
	environment.volumetric_fog_density = environment.fog_density * 4.4
	environment.glow_enabled = advanced and _enabled(settings, "bloom", false)
	environment.glow_bloom = 0.18
	var glow: float = [0.28, 0.47, 0.54, 0.62][preset] if _enabled(settings, "bloom", true) else 0.0
	grading.set_shader_parameter("bloom_strength", glow * (0.55 if environment.glow_enabled else 1.0) * clampf(float(settings.bloom_strength), 0.0, 1.5))


func shadow_level(settings: Dictionary) -> int:
	var value := int(settings.shadows)
	return clampi(value - 1, 0, 3) if value > 0 else quality(settings)


func _enabled(settings: Dictionary, key: String, default_value: bool) -> bool:
	var override := int(settings[key])
	return default_value if override == 0 else override == 2
