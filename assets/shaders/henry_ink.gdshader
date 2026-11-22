shader_type spatial;
render_mode cull_back, diffuse_burley;
uniform sampler2D ink_mask : filter_linear_mipmap;

void fragment() {
	ALBEDO = vec3(0.018, 0.014, 0.013);
	ROUGHNESS = 1.0;
	ALPHA = texture(ink_mask, UV).r;
	ALPHA_SCISSOR_THRESHOLD = 0.47;
}

