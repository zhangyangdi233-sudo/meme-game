shader_type canvas_item;
// The cream slabs, shown only where the title's red area covers them: the band always,
// the backdrop below its opening edge (see main_menu_red_cover.gdshaderinc).

#include "res://shaders/main_menu_red_cover.gdshaderinc"

uniform vec2 node_origin = vec2(0.0);
uniform sampler2D band_texture : filter_linear;
uniform vec2 band_origin = vec2(0.0, 116.0);
uniform vec2 band_size = vec2(1316.0, 780.0);
uniform sampler2D backdrop_texture : filter_linear;
uniform vec2 backdrop_origin = vec2(0.0);
uniform vec2 backdrop_size = vec2(1323.0, 900.0);

varying vec2 layer_point;

void vertex() {
	layer_point = VERTEX + node_origin;
}

void fragment() {
	float band = cover_alpha_at(band_texture, band_origin, band_size, layer_point);
	float backdrop = cover_alpha_at(backdrop_texture, backdrop_origin, backdrop_size, layer_point);
	backdrop *= cover_open_edge(layer_point) * step(0.0005, reveal);
	COLOR = texture(TEXTURE, UV);
	COLOR.a *= max(band, backdrop);
}
