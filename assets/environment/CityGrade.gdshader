shader_type canvas_item;
render_mode unshaded, blend_disabled;

uniform sampler2D scene_color : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float saturation : hint_range(0.0, 1.5) = 0.87;
uniform float bloom_strength : hint_range(0.0, 1.0) = 0.47;
uniform float bloom_threshold : hint_range(0.0, 1.0) = 0.61;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.105;

float luminance(vec3 sample_color) {
	return dot(sample_color, vec3(0.2126, 0.7152, 0.0722));
}

vec3 highlight(vec3 sample_color) {
	return sample_color * smoothstep(bloom_threshold, min(1.0, bloom_threshold + 0.26), luminance(sample_color));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 source = textureLod(scene_color, uv, 0.0).rgb;
	vec3 narrow = highlight(textureLod(scene_color, uv, 3.0).rgb);
	vec3 medium = highlight(textureLod(scene_color, uv, 4.8).rgb);
	vec3 wide = highlight(textureLod(scene_color, uv, 6.1).rgb);
	vec3 grading = mix(vec3(luminance(source)), source, saturation);
	grading *= mix(vec3(0.986, 1.003, 1.018), vec3(1.016, 1.004, 0.984), smoothstep(0.1, 0.82, luminance(source)));
	vec3 halo = (narrow * 0.32 + medium * 0.39 + wide * 0.29) * vec3(1.04, 1.0, 0.93);
	// Leave headroom for the halo as the tone-mapped source approaches white.
	grading += halo * bloom_strength * (vec3(1.0) - clamp(grading, vec3(0.0), vec3(1.0)));
	vec2 centered = (uv - vec2(0.5)) * vec2(1.3, 1.0);
	grading *= 1.0 - vignette_strength * smoothstep(0.23, 0.77, length(centered));
	COLOR = vec4(grading, 1.0);
}
