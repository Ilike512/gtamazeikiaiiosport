shader_type spatial;
render_mode cull_disabled, blend_mix, depth_draw_never, shadows_disabled;

global uniform float city_wetness;
varying vec3 world_point;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(124.7, 281.3))) * 45384.31);
}

void vertex() {
	world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world_point.xz;
	float flow = mix(0.42, 1.26, COLOR.a);
	float swell = sin(dot(p, vec2(0.48, 0.34)) + TIME * flow);
	float small = cos(dot(p, vec2(-1.48, 1.24)) - TIME * 1.83);
	float fine = sin(dot(p, vec2(2.94, 4.6)) + TIME * 2.17);
	vec2 cell = floor(p * 3.4);
	float seed = hash(cell);
	float pulse = fract(TIME * 1.12 + seed);
	float radius = length(fract(p * 3.4) - vec2(0.5));
	float drops = smoothstep(0.032, 0.006, abs(radius - pulse * 0.54)) * (1.0 - pulse) * city_wetness;
	vec3 normal_world = normalize(vec3(swell * 0.104 + small * 0.055, 1.0, small * 0.082 + fine * 0.037));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz) * (FRONT_FACING ? 1.0 : -1.0);
	float fresnel = pow(1.0 - abs(dot(normalize(VIEW), NORMAL)), 3.9);
	vec3 water = mix(vec3(0.038, 0.16, 0.19), vec3(0.12, 0.25, 0.29), swell * 0.5 + 0.5);
	vec3 sky = vec3(0.36, 0.49, 0.53);
	ALBEDO = mix(water, sky, fresnel * 0.78) + drops * vec3(0.17, 0.24, 0.27);
	ROUGHNESS = 0.18 + city_wetness * 0.10;
	SPECULAR = 0.70;
	ALPHA = mix(0.74, 0.96, fresnel);
}
