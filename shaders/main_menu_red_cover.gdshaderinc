// Where the title's red area covers, in MainMenuLayer pixels.
// Closed, the red area is only the band (main_menu_triangle_s); opening swings its upper edge up
// around the tip on the right until it is the backdrop's (menu_bg) upper edge.
// The band and the backdrop share the tip and the lower right edge, so only A and B move.
// The points are sampled from the art at the 1600x900 layout; move them with the art.

uniform float reveal : hint_range(0.0, 1.0) = 0.0;

const vec2 COVER_TIP = vec2(1318.0, 112.0);
const vec2 COVER_A_CLOSED = vec2(0.0, 694.0);
const vec2 COVER_A_OPEN = vec2(0.0, -2.0);
const vec2 COVER_B_OPEN = vec2(975.0, -2.0);
const float COVER_EDGE_SOFTNESS = 1.25;

// Signed distance to the line a->b; positive on the side the red area grows into (below the edge).
float cover_side(vec2 a, vec2 b, vec2 p) {
	vec2 d = normalize(b - a);
	vec2 n = vec2(-d.y, d.x);
	return dot(p - a, n);
}

// 1 below the moving upper edge A->B->tip, 0 above, soft over a pixel or so.
float cover_open_edge(vec2 p) {
	float t = clamp(reveal, 0.0, 1.0);
	vec2 b_closed = mix(COVER_A_CLOSED, COVER_TIP, COVER_B_OPEN.x / COVER_TIP.x);
	vec2 a = mix(COVER_A_CLOSED, COVER_A_OPEN, t);
	vec2 b = mix(b_closed, COVER_B_OPEN, t);
	float side = min(cover_side(a, b, p), cover_side(b, COVER_TIP, p));
	return smoothstep(-COVER_EDGE_SOFTNESS, COVER_EDGE_SOFTNESS, side);
}

// Alpha of a texture laid out at origin with size, sampled at layer point p; 0 outside it.
float cover_alpha_at(sampler2D tex, vec2 origin, vec2 size, vec2 p) {
	vec2 uv = (p - origin) / max(size, vec2(1.0));
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		return 0.0;
	}
	return texture(tex, uv).a;
}
