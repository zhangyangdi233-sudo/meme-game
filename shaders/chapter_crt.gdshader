shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

uniform sampler2D content_texture : source_color, filter_linear, repeat_disable;
uniform bool vhs_enabled = true;

void fragment() {
	vec2 sample_uv = UV;
	if (vhs_enabled) {
		sample_uv.x += sin(UV.y * 62.0 + TIME * 2.1) * 0.00015;
	}
	vec3 color = texture(content_texture, clamp(sample_uv, vec2(0.0), vec2(1.0))).rgb;
	if (vhs_enabled) {
		// Attenuate before scanlines reach the screen pixel Nyquist limit. Dense
		// unfiltered lines otherwise beat against the projected CRT's pixel grid.
		float cycles_per_pixel = fwidth(UV.y) * 180.0;
		float resolved = 1.0 - smoothstep(0.22, 0.48, cycles_per_pixel);
		float scanline = 0.97 + 0.025 * resolved * sin(UV.y * 180.0 * 6.28318531);
		float refresh = 0.99 + 0.01 * sin(UV.y * 10.0 - TIME * 3.0);
		color *= scanline * refresh;
	}
	ALBEDO = color;
}
