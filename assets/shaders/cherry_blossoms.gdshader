shader_type spatial;
render_mode cull_disabled;

float seed(vec2 point) {
	return fract(sin(dot(point, vec2(41.7, 127.1))) * 43758.545);
}

void fragment() {
	vec2 uv = UV;
	vec2 silhouette = (uv - vec2(0.5)) * vec2(2.0, 2.23);
	vec2 cell_uv = uv * 24.0;
	vec2 cell = floor(cell_uv);
	float variation = seed(cell);
	vec2 petals = fract(cell_uv) - vec2(0.5);
	float radial = length(petals * vec2(1.0, 1.32)) + variation * 0.165;
	ALPHA = 1.0 - step(0.74 + variation * 0.23, dot(silhouette, silhouette)) * 0.95;
	ALPHA *= 1.0 - step(0.56, radial) * 0.84;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ALBEDO = mix(vec3(0.64, 0.32, 0.45), vec3(0.96, 0.72, 0.77), variation);
	ROUGHNESS = 0.92;
}

