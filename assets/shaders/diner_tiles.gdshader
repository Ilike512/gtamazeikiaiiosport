shader_type spatial;

void fragment() {
	vec2 cell = UV * vec2(32.0, 34.0);
	float alternate = mod(floor(cell.x) + floor(cell.y), 2.0);
	float grout = step(0.028, min(min(fract(cell.x), 1.0 - fract(cell.x)),
		min(fract(cell.y), 1.0 - fract(cell.y))));
	vec3 stone = mix(vec3(0.29, 0.276, 0.253), vec3(0.70, 0.645, 0.55), alternate);
	ALBEDO = mix(vec3(0.36, 0.34, 0.30), stone, grout);
	ROUGHNESS = 0.51 + 0.17 * (1.0 - grout);
}

