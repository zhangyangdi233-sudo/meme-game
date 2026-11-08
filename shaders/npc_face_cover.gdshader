shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, skip_vertex_transform;
// The chalk scribble over an NPC's face (assets/image/npc/cover/1..6.png).
// It faces the camera like the character billboard under it, sits face_offset off the portrait's center in that
// same camera-facing plane, and is pushed toward the camera so it always draws in front of the character.
// The six drawings play on twos: 12 frames a second, each drawing held two frames.

uniform sampler2DArray cover_frames : source_color, filter_linear, repeat_disable;
uniform float frame_count = 6.0;
uniform float drawings_per_second = 6.0;
uniform float frame_offset = 0.0;
uniform vec2 face_offset = vec2(0.0);
uniform float toward_camera = 0.05;

void vertex() {
	vec3 origin = (MODELVIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 model_scale = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	VERTEX = origin + vec3(VERTEX.xy * model_scale + face_offset, toward_camera);
}

void fragment() {
	float layer = mod(floor(TIME * drawings_per_second + frame_offset), frame_count);
	vec4 chalk = texture(cover_frames, vec3(UV, layer));
	ALBEDO = chalk.rgb;
	ALPHA = chalk.a;
}
