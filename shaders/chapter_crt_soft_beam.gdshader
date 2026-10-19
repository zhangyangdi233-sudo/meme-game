shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

// One camera-facing light card, not a translucent solid cone. Every boundary
// reaches zero smoothly, including the bottom before it reaches the CRT screen.
uniform vec4 beam_color : source_color = vec4(1.0, 0.99, 0.97, 1.0);
uniform float density : hint_range(0.0, 0.25) = 0.07;

void fragment() {
	float height = clamp(UV.y, 0.0, 1.0);
	float width = mix(0.24, 0.94, smoothstep(0.0, 1.0, height));
	float radius = abs(UV.x - 0.5) * 2.0 / width;
	float cross_section = exp(-3.5 * radius * radius);
	cross_section *= 1.0 - smoothstep(0.55, 1.0, radius);
	float source_fade = smoothstep(0.0, 0.16, height);
	float end_fade = 1.0 - smoothstep(0.58, 1.0, height);
	float light_amount = density * cross_section * source_fade * end_fade;
	// Forward+ adds in linear HDR before encoding; Compatibility blends into
	// sRGB. Match the visible falloff over this shot's black background.
	if (OUTPUT_IS_SRGB) {
		light_amount = mix(12.92 * light_amount, 1.055 * pow(light_amount, 1.0 / 2.4) - 0.055, step(0.0031308, light_amount));
	}
	ALBEDO = beam_color.rgb;
	ALPHA = light_amount;
}
