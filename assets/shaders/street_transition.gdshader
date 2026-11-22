shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D screen_image : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(0.78, 0.83, 0.9, 1.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float fade_to_black : hint_range(0.0, 1.0) = 0.0;
uniform float fog_strength : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec3 scene = textureLod(screen_image, SCREEN_UV, strength * 1.68 + fog_strength * 4.3).rgb;
	float gray = dot(scene, vec3(0.2126, 0.7152, 0.0722));
	float vignette = smoothstep(0.30, 0.71, length((SCREEN_UV - 0.5) * vec2(1.14, 0.94)));
	vec3 mood = mix(scene, vec3(gray) * tint.rgb * (1.0 - vignette * 0.58), strength);
	float cloud = sin(SCREEN_UV.x * 9.0 + SCREEN_UV.y * 14.0 - TIME * 0.34);
	cloud *= 0.5 + 0.5 * sin(SCREEN_UV.y * 11.0 + TIME * 0.26);
	vec3 haze = vec3(0.45, 0.43, 0.44) + vec3(cloud * 0.042);
	mood = mix(mood, haze, fog_strength * (0.67 + 0.25 * vignette));
	COLOR = vec4(mood * (1.0 - fade_to_black), 1.0);
}
