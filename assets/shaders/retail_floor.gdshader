shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform vec4 tile_tint : source_color = vec4(0.65, 0.63, 0.56, 1.0);

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(93.7, 173.3))) * 41758.542);
}

void fragment() {
	vec2 tile = UV / 0.55;
	vec2 q = abs(fract(tile) - 0.5);
	float edge = max(q.x, q.y);
	float seam = 1.0 - smoothstep(0.482 - fwidth(edge), 0.488 + fwidth(edge), edge);
	float shade = 0.91 + hash_cell(floor(tile)) * 0.12;
	vec3 ceramic = tile_tint.rgb * shade;
	ALBEDO = mix(ceramic * 0.64, ceramic, seam);
	ROUGHNESS = mix(0.75, 0.36, seam);
}

