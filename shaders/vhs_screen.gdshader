shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;
uniform float intensity : hint_range(0.0, 1.0) = 0.62;
uniform float pollution : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phosphor_tint : source_color = vec3(0.91, 1.0, 0.76);

float hash21(vec2 value) {
	value = fract(value * vec2(123.34, 456.21));
	value += dot(value, value + 45.32);
	return fract(value.x * value.y);
}

void fragment() {
	float field = floor(mod(TIME * 29.97, 2.0));
	float row = floor(SCREEN_UV.y * 480.0);
	float frame = floor(TIME * 29.97);
	float row_noise = hash21(vec2(row * 0.031, frame));
	float burst = step(0.965 - pollution * 0.08, row_noise);

	vec2 uv = SCREEN_UV;
	float vertical_wobble = sin(uv.y * 34.0 + TIME * 2.6) * 0.0007;
	float head_switch = smoothstep(0.92, 1.0, uv.y) * sin(uv.y * 170.0 - TIME * 25.0) * 0.004;
	float tear_center = fract(TIME * 0.137 + 0.23);
	float tear = exp(-pow((uv.y - tear_center) * 76.0, 2.0));
	float tear_direction = hash21(vec2(frame, 8.0)) - 0.5;
	uv.x += vertical_wobble + head_switch + tear * tear_direction * (0.018 + pollution * 0.012);
	uv.x += (row_noise - 0.5) * burst * (0.012 + pollution * 0.01);
	uv = clamp(uv, vec2(0.001), vec2(0.999));

	vec3 center_color = texture(screen_texture, uv).rgb;
	float chroma = (0.0008 + pollution * 0.0015) * intensity;
	float red = texture(screen_texture, clamp(uv + vec2(chroma, 0.0), vec2(0.001), vec2(0.999))).r;
	float green = center_color.g;
	float blue = texture(screen_texture, clamp(uv - vec2(chroma, 0.0), vec2(0.001), vec2(0.999))).b;
	vec3 color = vec3(red, green, blue);

	float interlace = mix(1.0, 0.84, mod(row + field, 2.0));
	float fine_scan = 0.91 + 0.09 * sin(uv.y * 1500.0 + field * 3.14159265);
	float refresh_band = exp(-pow((fract(uv.y - TIME * 0.235) - 0.5) * 22.0, 2.0));
	float snow = hash21(vec2(floor(uv.x * 720.0) + frame * 0.73, row + frame * 1.37)) - 0.5;
	float dropout = step(0.993 - pollution * 0.025, hash21(vec2(row, floor(TIME * 12.0)))) * (hash21(vec2(uv.x * 90.0, row)) - 0.5);

	color *= mix(1.0, interlace * fine_scan, intensity);
	color += refresh_band * (0.025 + pollution * 0.035) * intensity;
	color += snow * (0.035 + pollution * 0.045) * intensity;
	color += dropout * 0.13 * intensity;
	color = mix(color, color * phosphor_tint, 0.16 + pollution * 0.18);
	float black_ink_guard = 1.0 - smoothstep(0.018, 0.09, max(center_color.r, max(center_color.g, center_color.b)));
	color = mix(color, center_color, black_ink_guard);

	vec2 centered = uv * 2.0 - 1.0;
	float vignette = 1.0 - dot(centered * vec2(0.30, 0.22), centered);
	color *= clamp(vignette, 0.72, 1.0);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
