class_name RuntimeTextureCache
extends RefCounted
## Loads a texture from disk once and hands back the same one afterwards.
## Raw image files load without an import; imported resources load through the engine.

## Path to the loaded texture. Shared with SocialFeedContent, which slices the poster sheet from it.
var textures: Dictionary = {}


func load_texture(path: String) -> Texture2D:
	if textures.has(path):
		return textures[path]
	var image := Image.new()
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var err := image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = image.load_webp_from_buffer(bytes)
		if err != OK:
			return null
		var texture := ImageTexture.create_from_image(image)
		textures[path] = texture
		return texture
	if FileAccess.file_exists("%s.import" % path):
		var resource := load(path)
		if resource is Texture2D:
			textures[path] = resource
			return resource
	return null
