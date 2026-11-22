shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float strength : hint_range(0.0, 1.8) = 0.0;
uniform int profile = 0;

void fragment() {
	vec2 p = SCREEN_UV - vec2(0.5);
	float radius = length(p);
	float wave = sin(TIME * 0.75 + radius * (profile == 2 ? 17.0 : 8.0));
	vec2 wobble = vec2(sin(TIME * 0.86 + p.y * 12.0), cos(TIME * 0.70 + p.x * 10.0));
	vec2 warped = p + (wobble * 0.010 + p * wave * 0.035) * strength;
	if (profile == 2) {
		float turn = wave * strength * 0.12;
		warped = mat2(vec2(cos(turn), sin(turn)), vec2(-sin(turn), cos(turn))) * warped;
	}
	vec2 uv = clamp(warped + vec2(0.5), vec2(0.0), vec2(1.0));
	vec2 split = p * strength * (profile == 3 ? 0.053 : 0.026);
	vec3 shifted = vec3(texture(screen, uv + split).r, texture(screen, uv).g, texture(screen, uv - split).b);
	vec3 tint = vec3(0.79, 1.18, 1.05);
	if (profile == 1) {
		tint = vec3(1.28, 0.78, 1.33);
	} else if (profile == 2) {
		tint = vec3(0.78, 1.04, 1.46);
	} else if (profile == 3) {
		tint = vec3(1.25, 1.06, 0.71);
	}
	vec3 source = mix(shifted, shifted * tint + vec3(0.02, 0.015, 0.04), min(strength * 0.65, 0.88));
	source *= 1.0 - smoothstep(0.20, 0.72, radius) * min(strength * 0.26, 0.50);
	COLOR = vec4(source, 1.0);
}
