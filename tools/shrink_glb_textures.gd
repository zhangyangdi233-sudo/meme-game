extends SceneTree
## Rewrites a .glb with every embedded image larger than `--max` pixels on a side scaled down to fit (PNG kept), so a
## Blender export can go into the repo at a sensible size. Nothing else changes in meaning: the JSON is written back
## with the same content (whole numbers written as integers, so `1.0` comes back as `1`) and the binary chunk is
## repacked around the smaller images. Only a .glb with its one embedded buffer is handled.
##
##   & $env:GODOT_BIN --headless --script res://tools/shrink_glb_textures.gd -- <in.glb> <out.glb> [--max 1024]

const GLB_MAGIC := 0x46546C67
const CHUNK_JSON := 0x4E4F534A
const CHUNK_BIN := 0x004E4942


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var max_size := 1024
	var paths: Array[String] = []
	var index := 0
	while index < args.size():
		if args[index] == "--max" and index + 1 < args.size():
			max_size = int(args[index + 1])
			index += 2
			continue
		paths.append(args[index])
		index += 1
	if paths.size() != 2:
		push_error("usage: -- <in.glb> <out.glb> [--max 1024]")
		quit(2)
		return
	quit(0 if shrink(paths[0], paths[1], max_size) else 1)


static func shrink(in_path: String, out_path: String, max_size: int) -> bool:
	var bytes := FileAccess.get_file_as_bytes(in_path)
	if bytes.size() < 20 or bytes.decode_u32(0) != GLB_MAGIC:
		push_error("not a glb: %s" % in_path)
		return false
	var json_length := bytes.decode_u32(12)
	if bytes.decode_u32(16) != CHUNK_JSON:
		push_error("the first chunk is not JSON: %s" % in_path)
		return false
	var gltf: Dictionary = JSON.parse_string(bytes.slice(20, 20 + json_length).get_string_from_utf8())
	var bin_at := 20 + json_length
	if bytes.decode_u32(bin_at + 4) != CHUNK_BIN:
		push_error("the second chunk is not BIN: %s" % in_path)
		return false
	var bin := bytes.slice(bin_at + 8, bin_at + 8 + bytes.decode_u32(bin_at))
	var views: Array = gltf["bufferViews"]
	if (gltf.get("buffers", []) as Array).size() != 1 or views.any(func(view: Dictionary) -> bool: return int(view.get("buffer", 0)) != 0):
		push_error("only a glb with its one embedded buffer is handled: %s" % in_path)
		return false
	var replaced := {}
	for image: Dictionary in gltf.get("images", []):
		if not image.has("bufferView"):
			continue
		var view: Dictionary = views[int(image["bufferView"])]
		var start := int(view.get("byteOffset", 0))
		var data := bin.slice(start, start + int(view["byteLength"]))
		var picture := Image.new()
		if picture.load_png_from_buffer(data) != OK and picture.load_jpg_from_buffer(data) != OK:
			push_error("image %s did not decode" % image.get("name", "?"))
			return false
		var longest := maxi(picture.get_width(), picture.get_height())
		if longest <= max_size:
			continue
		var scale := float(max_size) / float(longest)
		picture.resize(maxi(1, roundi(picture.get_width() * scale)), maxi(1, roundi(picture.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
		replaced[int(image["bufferView"])] = picture.save_png_to_buffer()
		image["mimeType"] = "image/png"
		print("%s: %d px -> %d px, %d -> %d bytes" % [image.get("name", "?"), longest, max_size, data.size(), (replaced[int(image["bufferView"])] as PackedByteArray).size()])
	var packed := PackedByteArray()
	for view_index in views.size():
		var view: Dictionary = views[view_index]
		var start := int(view.get("byteOffset", 0))
		var data: PackedByteArray = replaced.get(view_index, bin.slice(start, start + int(view["byteLength"])))
		while packed.size() % 4 != 0:
			packed.append(0)
		view["byteOffset"] = packed.size()
		view["byteLength"] = data.size()
		packed.append_array(data)
	while packed.size() % 4 != 0:
		packed.append(0)
	(gltf["buffers"] as Array)[0]["byteLength"] = packed.size()
	var json_bytes := JSON.stringify(_whole_numbers(gltf), "", false, true).to_utf8_buffer()
	while json_bytes.size() % 4 != 0:
		json_bytes.append(0x20)
	var out := PackedByteArray()
	out.resize(12)
	out.encode_u32(0, GLB_MAGIC)
	out.encode_u32(4, 2)
	out.encode_u32(8, 12 + 8 + json_bytes.size() + 8 + packed.size())
	var header := PackedByteArray()
	header.resize(8)
	header.encode_u32(0, json_bytes.size())
	header.encode_u32(4, CHUNK_JSON)
	out.append_array(header)
	out.append_array(json_bytes)
	header.encode_u32(0, packed.size())
	header.encode_u32(4, CHUNK_BIN)
	out.append_array(header)
	out.append_array(packed)
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	if file == null:
		push_error("cannot write %s" % out_path)
		return false
	file.store_buffer(out)
	file.close()
	print("%s: %d -> %d bytes" % [out_path, bytes.size(), out.size()])
	return true


## Godot's JSON reads every number as a float; glTF wants its counts and indices written as integers, so a whole
## number goes back out as one (a whole float such as 1.0 means the same written as 1).
static func _whole_numbers(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floorf(value) and absf(value) < 9.0e15:
		return int(value)
	if value is Dictionary:
		var copy := {}
		for key: Variant in value:
			copy[key] = _whole_numbers(value[key])
		return copy
	if value is Array:
		var items := []
		for item: Variant in value:
			items.append(_whole_numbers(item))
		return items
	return value
