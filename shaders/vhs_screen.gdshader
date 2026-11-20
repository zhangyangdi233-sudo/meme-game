shader_type canvas_item;
render_mode unshaded;

// The player's view is a home DV camcorder first, with a trace of VHS tape on top (planner, 2026-11-20; reference: the
// camera of P.T.). The camera part is always there: a slightly bowed lens that fringes towards the corners, soft 480-line
// detail with the edge sharpening of consumer video, colour smeared a few pixels sideways, bright lamps that bleed, a
// sensor that gets noisy in the dark, darker corners. The tape part (wobble, tears, snow, drop-outs) is what the game
// drives through `intensity` and `pollution`; only `tape_share` of it shows until the pollution rises.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float intensity : hint_range(0.0, 1.0) = 0.46;
uniform float pollution : hint_range(0.0, 1.0) = 0.0;
uniform vec3 phosphor_tint : source_color = vec3(0.91, 1.0, 0.76);
// 0 switches the camera off and leaves the tape alone.
uniform float camcorder : hint_range(0.0, 1.0) = 1.0;
// The share of `intensity` the tape effects get while the room is clean: the camera leads, the tape is a trace.
uniform float tape_share : hint_range(0.0, 1.0) = 0.30;
// How far the lens bows the picture: the share by which the middle is pushed in against the corners.
uniform float lens_barrel : hint_range(0.0, 0.5) = 0.10;
// 1 while the player looks at the world with the pointer captured, 0 under a free pointer (`VhsOverlay.set_lens_bowed`).
// The bow goes with it: a bowed picture would show the terminal's words and the menus' buttons away from where a click
// lands. So does most of the fringing and of the grain on black, which small type on a black ground does not survive.
uniform float lens_bow : hint_range(0.0, 1.0) = 1.0;
uniform float lens_fringe : hint_range(0.0, 0.02) = 0.0030;
uniform float lens_vignette : hint_range(0.0, 1.0) = 0.34;
uniform float sensor_noise : hint_range(0.0, 0.3) = 0.060;
uniform float halation : hint_range(0.0, 1.0) = 0.40;

const vec3 LUMA = vec3(0.2126, 0.7152, 0.0722);

// A sample of the screen, never from past the middles of its outermost pixels.
#define TAP(at) texture(screen_texture, clamp(at, pixel * 0.5, vec2(1.0) - pixel * 0.5)).rgb

// Noise from a place. Its inputs must stay small (a pixel index plus a wrapped frame counter, a few thousand at most): a
// 32-bit float loses the fraction of a large product, which turned the grain into stripes after ten minutes of play.
float hash21(vec2 value) {
	vec3 p = fract(vec3(value.xyx) * 0.1031);
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	// Pollution brings the tape back to full strength; a clean room only shows a trace of it.
	float tape = intensity * mix(tape_share, 1.0, pollution);
	float frame = floor(TIME * 29.97);
	float field = mod(frame, 2.0);
	// The frame counter as two small numbers, for the hashes: together they repeat only after half an hour.
	vec2 jump = vec2(mod(frame * 17.0, 251.0), mod(frame * 29.0, 241.0));
	float row = floor(SCREEN_UV.y * 480.0);
	float row_noise = hash21(vec2(row, jump.x));
	float burst = step(0.965 - pollution * 0.08, row_noise);
	vec2 pixel = SCREEN_PIXEL_SIZE;

	// Lens: where on the sensor this pixel looks. The radius runs from 0 at the middle to 1 at the corners whatever
	// the screen's shape, measured in half-heights so the bow is round. The corners keep their place and everything
	// else is pulled in, so nothing is ever sampled from past the frame.
	float aspect = pixel.y / pixel.x;
	vec2 centred = SCREEN_UV * 2.0 - 1.0;
	vec2 on_sensor = vec2(centred.x * aspect, centred.y);
	float r2 = dot(on_sensor, on_sensor) / (aspect * aspect + 1.0);
	float barrel = lens_barrel * camcorder * lens_bow;
	vec2 uv = centred * ((1.0 + barrel * r2) / (1.0 + barrel)) * 0.5 + 0.5;

	// Tape transport, on top of the lens.
	float vertical_wobble = sin(uv.y * 34.0 + TIME * 2.6) * 0.0007;
	float head_switch = smoothstep(0.92, 1.0, uv.y) * sin(uv.y * 170.0 - TIME * 25.0) * 0.004;
	float tear_center = fract(TIME * 0.137 + 0.23);
	float tear_offset = (uv.y - tear_center) * 76.0;
	float tear = exp(-tear_offset * tear_offset);
	float tear_direction = hash21(jump + 8.0) - 0.5;
	uv.x += (vertical_wobble + head_switch + tear * tear_direction * (0.018 + pollution * 0.012)) * tape;
	uv.x += (row_noise - 0.5) * burst * (0.012 + pollution * 0.01) * tape;
	uv = clamp(uv, pixel * 0.5, vec2(1.0) - pixel * 0.5);

	vec3 center_color = TAP(uv);

	// Fringing: the lens splits colour outwards from the middle, the tape sideways. Under a free pointer the lens's
	// share is held to a third, so small coloured type near the corners keeps its ink.
	vec2 outward = (uv - 0.5) * (lens_fringe * camcorder * mix(0.35, 1.0, lens_bow)) * (0.4 + 1.6 * r2);
	vec2 sideways = vec2((0.0008 + pollution * 0.0015) * tape, 0.0);
	vec3 sharp = vec3(TAP(uv + outward + sideways).r, center_color.g, TAP(uv - outward - sideways).b);

	// DV detail: a soft picture, sharpened again by the camera so edges ring a little; colour sits at a quarter of
	// the width (4:1:1), so it smears sideways. Both are held where the terminal's type and the colour of the words
	// the player picks up still read through the camera.
	vec3 soft = (TAP(uv + vec2(pixel.x * 1.5, 0.0)) + TAP(uv - vec2(pixel.x * 1.5, 0.0))
		+ TAP(uv + vec2(0.0, pixel.y * 1.2)) + TAP(uv - vec2(0.0, pixel.y * 1.2))) * 0.25;
	vec3 wide = (TAP(uv + vec2(pixel.x * 4.5, 0.0)) + TAP(uv - vec2(pixel.x * 4.5, 0.0)) + soft * 2.0) * 0.25;
	float luma_sharp = dot(sharp, LUMA);
	float luma_soft = dot(soft, LUMA);
	float luma_wide = dot(wide, LUMA);
	float luma = mix(luma_sharp, luma_soft, 0.40 * camcorder) + (luma_soft - luma_wide) * 0.8 * camcorder;
	vec3 color = vec3(luma) + mix(sharp - vec3(luma_sharp), wide - vec3(luma_wide), 0.45 * camcorder);

	// Bright things bleed: two rings of taps stand in for the glow of a small sensor behind cheap glass.
	vec3 bleed = vec3(0.0);
	for (int index = 0; index < 8; index++) {
		float angle = float(index) * 0.7853982 + 0.3;
		vec2 ring = vec2(cos(angle) * pixel.x, sin(angle) * pixel.y);
		bleed += max(TAP(uv + ring * 11.0) - vec3(0.70), vec3(0.0));
		bleed += max(TAP(uv + ring * 30.0) - vec3(0.70), vec3(0.0)) * 0.6;
	}
	color += bleed * vec3(1.0, 0.94, 0.80) * (0.11 * halation * camcorder);

	// Sensor gain: fine luminance grain and blotchier colour noise, both strongest in the dark.
	float dark = 1.0 - smoothstep(0.0, 0.55, dot(color, LUMA));
	float gain = sensor_noise * camcorder * (0.35 + 0.65 * dark);
	vec2 grain_cell = floor(SCREEN_UV / pixel);
	vec2 chroma_cell = floor(SCREEN_UV / (pixel * 3.0));
	float grain = hash21(grain_cell + jump) - 0.5;
	vec3 chroma_grain = vec3(hash21(chroma_cell + jump.yx), hash21(chroma_cell + jump.yx + vec2(31.0, 7.0)),
		hash21(chroma_cell + jump + vec2(77.0, 13.0))) - 0.5;
	vec3 noise = vec3(grain * gain * 0.9) + chroma_grain * gain * 0.5;
	color += noise;

	// Video levels: a little less colour, blacks that never quite reach black, the two fields of an interlaced frame.
	color = mix(color, vec3(dot(color, LUMA)), 0.10 * camcorder);
	color = color * (1.0 - 0.035 * camcorder) + vec3(0.010, 0.014, 0.011) * camcorder;
	color *= mix(1.0, mix(1.0, 0.955, mod(row + field, 2.0)), 0.6 * camcorder);

	// Tape: scan lines, the refresh band, snow, drop-outs, the tint of an old tube.
	float interlace = mix(1.0, 0.90, mod(row + field, 2.0));
	float fine_scan = 0.94 + 0.06 * sin(uv.y * 1500.0 + field * 3.14159265);
	float band_offset = (fract(uv.y - TIME * 0.235) - 0.5) * 22.0;
	float refresh_band = exp(-band_offset * band_offset);
	float snow = hash21(vec2(floor(uv.x * 720.0), row) + jump.yx) - 0.5;
	float dropout_tick = mod(floor(TIME * 12.0), 509.0);
	float dropout = step(0.993 - pollution * 0.025, hash21(vec2(row, dropout_tick))) * (hash21(vec2(floor(uv.x * 90.0), row) + 3.0) - 0.5);
	color *= mix(1.0, interlace * fine_scan, tape);
	color += refresh_band * (0.020 + pollution * 0.028) * tape;
	color += snow * (0.028 + pollution * 0.036) * tape;
	color += dropout * 0.10 * tape;
	color = mix(color, color * phosphor_tint, 0.06 + pollution * 0.28);

	// Fully black ink (the face scribbles, the terminal's type and its black ground) stays black: no lift and no tint on
	// it. Only what is black to begin with and has no fringed colour of its neighbours on it. The sensor still shows a
	// little of its grain there while the player looks at the world, as a camcorder does in the dark, so a room with
	// its lamps out is not a clean digital black; under a free pointer hardly any.
	float ink_peak = max(max(center_color.r, max(center_color.g, center_color.b)), max(sharp.r, sharp.b));
	float black_ink_guard = 1.0 - smoothstep(0.004, 0.02, ink_peak);
	vec3 ink = center_color + max(noise, vec3(0.0)) * (0.6 * mix(0.25, 1.0, lens_bow));
	color = mix(color, ink, black_ink_guard);

	// The corners of a small lens are darker.
	color *= 1.0 - lens_vignette * camcorder * pow(r2, 1.15);
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
