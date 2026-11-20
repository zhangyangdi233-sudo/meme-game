shader_type spatial;
render_mode unshaded, cull_front, depth_test_disabled, shadows_disabled, fog_disabled;

// Chapter one's portal (planner's design of 2026-10-31, after Viewfinder): what the hands' frame held still for three
// seconds leaves in the room. From the eye that fixed it the frame is a rectangle; in the room it is everything that
// eye saw through that rectangle, from `frame_near` on. Whatever of the room lies in there is replaced by the other
// world, seen from wherever the player stands now (the other world's camera follows the player's), and where the
// frame's edge meets the walls, the floor and the ceiling it is a paper sticker pasted on them.
// The mesh is a box around the room drawn from inside, so every pixel of the room is asked: the room's own point behind
// the pixel is rebuilt from the depth buffer and taken into the fixing eye's space.

uniform sampler2D depth_texture : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear, repeat_disable;
// The other world as its camera draws it, or (used up) a picture of it taken from the fixing eye.
uniform sampler2D other_world : source_color, filter_linear, repeat_disable;
// The room's space to the fixing eye's (x right, y up, looking down -z).
uniform mat4 to_frame = mat4(1.0);
// The frame as that eye saw it, in tangents: left, bottom, right, top.
uniform vec4 frame_tangents = vec4(-0.3, -0.2, 0.3, 0.2);
// How far in front of the fixing eye the other world begins (metres).
uniform float frame_near = 0.9;
// The sticker's width as a share of the frame's height.
uniform float border = 0.03;
// How much of the sticker is pasted yet, clockwise from the frame's top left corner: 1 once the portal is fixed.
uniform float progress = 1.0;
// 1 shows `other_world` as a flat picture pasted where the frame was (a portal that is used up): `picture_rect` is the
// part of the picture the frame covered (x, y, width, height in its UV).
uniform float flat_picture = 0.0;
uniform vec4 picture_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec3 paper : source_color = vec3(0.80, 0.77, 0.66);

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	// Nothing was drawn behind this pixel: there is no room to replace.
	if (depth <= 0.000001) {
		discard;
	}
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz / view.w, 1.0)).xyz;
	vec3 seen = (to_frame * vec4(world, 1.0)).xyz;
	float ahead = -seen.z;
	if (ahead < frame_near) {
		discard;
	}
	vec2 low = frame_tangents.xy;
	vec2 high = frame_tangents.zw;
	// Where in the frame the fixing eye saw this point: (0, 0) its lower left corner, (1, 1) its upper right.
	vec2 place = (seen.xy / ahead - low) / (high - low);
	if (place.x < 0.0 || place.x > 1.0 || place.y < 0.0 || place.y > 1.0) {
		discard;
	}
	// The sticker: a band along the frame's edge, as wide everywhere as `border` of the frame's height.
	vec2 size = high - low;
	vec2 to_edge = min(place, 1.0 - place) * size;
	float edge = min(to_edge.x, to_edge.y);
	float band = border * size.y;
	if (edge < band) {
		// How far round the frame this point lies, clockwise from the top left corner (0..1).
		float around;
		if (to_edge.y <= to_edge.x) {
			around = place.y > 0.5 ? place.x * 0.25 : 0.5 + (1.0 - place.x) * 0.25;
		} else {
			around = place.x > 0.5 ? 0.25 + (1.0 - place.y) * 0.25 : 0.75 + place.y * 0.25;
		}
		if (around > progress) {
			discard;
		}
		// Paper under the room's own light: the lit surface it is pasted on says how bright it is here.
		vec3 under = texture(screen_texture, SCREEN_UV).rgb;
		float lit = dot(under, vec3(0.2126, 0.7152, 0.0722));
		float cut = smoothstep(0.0, band * 0.18, edge) * smoothstep(0.0, band * 0.18, band - edge);
		ALBEDO = paper * (0.10 + 2.4 * lit) * mix(0.55, 1.0, cut);
	} else if (flat_picture > 0.5) {
		vec2 at = picture_rect.xy + vec2(place.x, 1.0 - place.y) * picture_rect.zw;
		vec3 picture = texture(other_world, at).rgb;
		// A used-up portal is a print of the other world: a little grey, and lit by the room like the paper round it.
		vec3 under = texture(screen_texture, SCREEN_UV).rgb;
		float lit = dot(under, vec3(0.2126, 0.7152, 0.0722));
		ALBEDO = mix(vec3(dot(picture, vec3(0.2126, 0.7152, 0.0722))), picture, 0.7) * (0.35 + 1.6 * lit);
	} else {
		ALBEDO = texture(other_world, SCREEN_UV).rgb;
	}
}
