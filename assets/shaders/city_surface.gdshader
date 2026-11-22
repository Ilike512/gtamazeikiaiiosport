shader_type spatial;
render_mode cull_disabled, diffuse_burley;

global uniform float city_detail;
global uniform float city_textures;
global uniform float city_wetness;
global uniform float city_snow;
uniform int surface_kind = 0;
uniform float grain_strength = 0.055;
uniform sampler2D ground_photo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float random(vec2 tile) {
	return fract(sin(dot(tile, vec2(127.1, 311.7))) * 43758.5453);
}

float noise_field(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(random(i), random(i + vec2(1, 0)), f.x),
		mix(random(i + vec2(0, 1)), random(i + vec2(1, 1)), f.x), f.y);
}

void fragment() {
	vec3 paint = COLOR.rgb;
	if (city_textures < 0.01) {
		ALBEDO = paint;
		ROUGHNESS = 0.91;
	} else {
		vec2 st = UV;
		float broad = noise_field(st * 0.22) - 0.5;
		float fine = 0.0;
		if (city_detail > 0.0) {
			fine = (noise_field(st * 7.1) - 0.5) * grain_strength * city_detail;
		}
		vec3 color = paint * (0.95 + broad * 0.17 + fine);
		float rough = 0.89;
		if (surface_kind == 1) {
			// Dark glass, recessed frames and staggered façade panels in metre-scale UVs.
			float floor_height = COLOR.a > 0.58 ? 3.5 : 3.03;
			vec2 cell = vec2(st.x / 2.32, (st.y - 0.45) / floor_height);
			vec2 p = fract(cell);
			float panel_noise = random(floor(cell));
			float wall_joint = 1.0 - smoothstep(0.014, 0.033, min(p.x, p.y));
			color = color * (1.0 - wall_joint * 0.09 + panel_noise * 0.09);
			float rain_streak = noise_field(vec2(st.x * 2.6, st.y * 0.35));
			color *= 0.90 + rain_streak * 0.17;
			if (COLOR.a > 0.25 && COLOR.a < 0.59 && st.y > 0.55) {
				float edge = max(abs(p.x - 0.5) / 0.30, abs(p.y - 0.55) / 0.27);
				float recess = 1.0 - smoothstep(0.99, 1.035, edge);
				float glass = 1.0 - smoothstep(0.83, 0.88, edge);
				vec3 shade = mix(vec3(0.055, 0.079, 0.099), vec3(0.19, 0.25, 0.28), p.y * 0.66 + panel_noise * 0.3);
				float mullion = 1.0 - smoothstep(0.021, 0.047, abs(p.x - 0.50));
				shade = mix(shade, vec3(0.41, 0.39, 0.36), mullion * 0.78);
				float lintel = smoothstep(0.71, 0.81, p.y);
				shade *= 1.0 - lintel * 0.31;
				color = mix(color, vec3(0.48, 0.44, 0.38), recess * 0.87);
				color = mix(color, shade, glass);
				rough = mix(0.87, 0.34, glass);
				if (panel_noise > 0.94) {
					EMISSION = vec3(0.36, 0.19, 0.075) * glass * 0.13;
				}
			}
			if (COLOR.a >= 0.59 && COLOR.a < 0.90) {
				vec2 shop = fract(vec2(st.x / 3.65, (st.y - 0.37) / 3.65));
				float panel_band = 1.0 - smoothstep(0.48, 0.53, shop.y);
				float street_glass = smoothstep(0.09, 0.16, shop.y) * (1.0 - smoothstep(0.87, 0.93, shop.y));
				float glass = mix(street_glass, smoothstep(0.39, 0.44, shop.y) * (1.0 - smoothstep(0.72, 0.78, shop.y)), step(4.0, st.y));
				float frame = smoothstep(0.016, 0.039, min(fract(shop.x * 3.0), 1.0 - fract(shop.x * 3.0)));
				vec3 reflection = mix(vec3(0.11, 0.16, 0.19), vec3(0.29, 0.36, 0.39), shop.y);
				color = mix(color * (0.92 + panel_band * 0.13), mix(vec3(0.24, 0.27, 0.28), reflection, frame), glass * step(0.62, st.y));
				rough = mix(0.86, 0.31, glass);
			}
			if (COLOR.a >= 0.13 && COLOR.a < 0.24) {
				vec2 rib = fract(vec2(st.x * 3.65, st.y / 2.77));
				float cladding = 0.88 + 0.12 * smoothstep(0.07, 0.26, rib.x);
				color *= cladding * mix(0.76, 1.0, smoothstep(0.41, 0.68, st.y));
				float shutter = (1.0 - smoothstep(0.24, 0.29, abs(fract(st.x / 8.8) - 0.54))) * smoothstep(0.44, 0.49, st.y) * (1.0 - smoothstep(2.8, 2.9, st.y));
				float horizontal = 0.88 + 0.12 * smoothstep(0.06, 0.24, fract(st.y * 5.4));
				color = mix(color, color * horizontal * 0.63, shutter * 0.84);
			}
			if (COLOR.a > 0.9) {
				float row = floor(st.y * 5.1);
				vec2 brick = fract(vec2(st.x * 2.7 + mod(row, 2.0) * 0.5, st.y * 5.1));
				float grout = 1.0 - smoothstep(0.043, 0.075, min(brick.x, brick.y));
				color = mix(color, vec3(0.27, 0.23, 0.19), grout * 0.40);
				vec2 bay = vec2((fract(st.x / 4.5) - 0.5) * 4.5, st.y - 1.32);
				float arch = (1.0 - smoothstep(0.44, 0.53, abs(bay.x))) *
					(1.0 - smoothstep(2.67, 2.81, bay.y + abs(bay.x) * abs(bay.x)));
				arch *= smoothstep(0.08, 0.16, bay.y) * step(5.0, st.x + 2.0);
				color = mix(color, vec3(0.104, 0.135, 0.154), arch * 0.86);
				rough = mix(rough, 0.36, arch);
			}
			vec3 facade_normal = normalize(NORMAL);
			float near_detail = city_detail * city_textures * (1.0 - smoothstep(12.0, 52.0, length(VERTEX)));
			if (near_detail > 0.0) {
				float stone = noise_field(st * 13.5);
				float surface_pits = smoothstep(0.57, 0.9, stone);
				float water_marks = smoothstep(0.53, 0.90, noise_field(st * vec2(7.4, 0.30)));
				float worn_plinth = (1.0 - smoothstep(0.18, 1.14, st.y)) * noise_field(st * 2.8);
				color *= 1.0 - near_detail * (surface_pits * 0.052 + water_marks * 0.091 + worn_plinth * 0.14);
				float relief = (stone - 0.5) * 0.009 * near_detail * smoothstep(0.42, 0.82, rough);
				vec3 tangent_x = cross(dFdy(VERTEX), facade_normal);
				vec3 tangent_y = cross(facade_normal, dFdx(VERTEX));
				float determinant = dot(dFdx(VERTEX), tangent_x);
				vec3 gradient = (dFdx(relief) * tangent_x + dFdy(relief) * tangent_y) * sign(determinant) / max(abs(determinant), 0.0001);
				NORMAL = normalize(facade_normal - gradient);
			}
			color *= mix(0.62, 1.0, smoothstep(0.0, 2.2, st.y));
		}
		if (surface_kind == 2) {
			float damp = smoothstep(0.55, 0.89, noise_field(st * 0.064));
			vec3 aggregate = texture(ground_photo, st / 2.08, (1.0 - city_textures) * 2.6).rgb;
			float worn = noise_field(st * 0.41) * 0.15 + noise_field(st * 0.18) * 0.12;
			color = color * (0.61 + worn + aggregate * 2.04) * (1.0 - damp * 0.22);
			rough = 0.94 - damp * 0.25;
			if (city_detail > 0.0) {
			float relief = dot(aggregate, vec3(0.299, 0.587, 0.114)) * 0.044 * city_detail;
			vec3 surface_normal = normalize(NORMAL);
			vec3 dx = dFdx(VERTEX);
			vec3 dy = dFdy(VERTEX);
			vec3 cross_x = cross(dy, surface_normal);
			vec3 cross_y = cross(surface_normal, dx);
			float determinant = dot(dx, cross_x);
			vec3 gradient = (dFdx(relief) * cross_x + dFdy(relief) * cross_y) * sign(determinant) / max(abs(determinant), 0.0001);
			NORMAL = normalize(surface_normal - gradient * (1.0 - smoothstep(18.0, 78.0, length(VERTEX))));
			}
		}
		if (surface_kind == 3) {
			vec2 slab_uv = vec2(st.x * 2.7 + 0.5 * mod(floor(st.y * 2.20), 2.0), st.y * 2.20);
			vec2 AA = fwidth(slab_uv);
			vec2 edge = min(fract(slab_uv), 1.0 - fract(slab_uv));
			float joint = min(smoothstep(0.026, max(0.07, AA.x), edge.x), smoothstep(0.025, max(0.07, AA.y), edge.y));
			color *= (0.78 + 0.22 * joint) * (0.92 + noise_field(st * 2.0) * 0.14);
		}
		if (surface_kind == 4) {
			vec3 grass = texture(ground_photo, st / 3.8, 0.85 + (1.0 - city_textures) * 2.7).rgb;
			float growth = noise_field(st * 0.078) * 0.28 + noise_field(st * 0.22) * 0.16;
			vec3 soil = grass * vec3(0.70, 0.89, 0.71);
			color = mix(paint, soil, 0.39) * (0.73 + growth);
			rough = 0.96;
		}
		if (surface_kind == 2 || surface_kind == 3) {
			float puddle = smoothstep(0.32, 0.62, noise_field(st * 0.45)) * city_wetness;
			color *= 1.0 - city_wetness * 0.18 - puddle * 0.19;
			rough = mix(rough, 0.15, puddle * 0.87);
			SPECULAR = mix(0.36, 0.52, puddle);
		}
		if (surface_kind != 1 && city_snow > 0.0) {
			float frost = smoothstep(0.33, 0.84, noise_field(st * 0.28));
			float coverage = surface_kind == 4 ? 0.80 : (surface_kind == 2 ? 0.23 : 0.38);
			color = mix(color, vec3(0.72, 0.76, 0.82) * (0.77 + frost * 0.23), city_snow * coverage * (0.58 + frost * 0.42));
		}
		ALBEDO = color;
		ROUGHNESS = rough;
	}
}
