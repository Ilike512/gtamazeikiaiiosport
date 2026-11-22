shader_type spatial;
render_mode cull_disabled, depth_draw_never, diffuse_burley, specular_schlick_ggx;

uniform vec4 stain : source_color = vec4(0.27, 0.025, 0.036, 0.88);

void fragment() {
	vec2 point = UV * 2.0 - 1.0;
	float angle = atan(point.y, point.x);
	float boundary = 0.74 + 0.14 * sin(angle * 5.0) + 0.085 * cos(angle * 11.0 + 0.8) + 0.036 * sin(angle * 27.0);
	float distance_to_center = length(point);
	float edge = 1.0 - smoothstep(boundary * 0.88, boundary, distance_to_center);
	float rim = smoothstep(0.42, 0.88, distance_to_center);
	ALBEDO = stain.rgb * mix(0.34, 1.22, rim);
	ROUGHNESS = mix(0.24, 0.78, rim);
	SPECULAR = mix(0.4, 0.19, rim);
	ALPHA = stain.a * edge;
}
