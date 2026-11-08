shader_type canvas_item;
// The title's red backdrop, shown only below the opening edge (see main_menu_red_cover.gdshaderinc).

#include "res://shaders/main_menu_red_cover.gdshaderinc"

uniform vec2 node_origin = vec2(0.0);

varying vec2 layer_point;

void vertex() {
	layer_point = VERTEX + node_origin;
}

void fragment() {
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= cover_open_edge(layer_point) * step(0.0005, reveal);
}
