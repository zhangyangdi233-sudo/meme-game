class_name NpcPortraits
extends RefCounted
## Where each NPC portrait's face is, and the chalk scribble animation that covers it.
## Faces are in the portrait's own pixels, measured by eye from the art; a portrait not listed falls back
## to the middle at FALLBACK_FACE_Y of its height. Cover frames are the six drawings in COVER_DIR.

const PORTRAIT_PATHS: Array[String] = [
	"res://assets/image/npc/npc_1_uc.png",
	"res://assets/image/npc/npc_2_uc.png",
	"res://assets/image/npc/npc_3_uc.png",
	"res://assets/image/npc/npc_4_uc.png",
	"res://assets/image/npc/npc_5_uc.png",
	## The special NPC; meant for floor four later, an ordinary NPC in the demo.
	"res://assets/image/npc/npc_sp_uc.png",
]
const FACES := {
	"res://assets/image/npc/npc_1_uc.png": Vector2(158.0, 132.0),
	"res://assets/image/npc/npc_2_uc.png": Vector2(150.0, 128.0),
	"res://assets/image/npc/npc_3_uc.png": Vector2(136.0, 128.0),
	"res://assets/image/npc/npc_4_uc.png": Vector2(148.0, 100.0),
	"res://assets/image/npc/npc_5_uc.png": Vector2(140.0, 96.0),
	"res://assets/image/npc/npc_sp_uc.png": Vector2(184.0, 158.0),
}
const FALLBACK_FACE_Y := 0.18
const COVER_DIR := "res://assets/image/npc/cover"
const COVER_FRAME_COUNT := 6
## How wide the scribble is drawn, in portrait pixels; the drawings are 280 wide.
const COVER_WIDTH_PX := 190.0

## The face center in the portrait's pixels.
static func face_pixel(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ZERO
	if FACES.has(texture.resource_path):
		return FACES[texture.resource_path]
	return Vector2(texture.get_width() * 0.5, texture.get_height() * FALLBACK_FACE_Y)


## The six cover drawings as one array texture. Builds a new one each call; callers keep it.
static func cover_frames() -> Texture2DArray:
	var images: Array[Image] = []
	for index in COVER_FRAME_COUNT:
		var texture := load("%s/%d.png" % [COVER_DIR, index + 1]) as Texture2D
		if texture == null:
			push_error("NpcPortraits: missing cover frame %d" % (index + 1))
			return null
		var image := texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
	var frames := Texture2DArray.new()
	if frames.create_from_images(images) != OK:
		push_error("NpcPortraits: cover frames differ in size")
		return null
	return frames


static func first_cover_frame() -> Texture2D:
	return load("%s/1.png" % COVER_DIR) as Texture2D
