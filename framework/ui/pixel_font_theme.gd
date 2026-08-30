class_name PixelFontTheme
extends RefCounted
## Pixel-grid Theme: nearest-grid font sizes, crisp bitmap face (no AA/hinting/MSDF).


static func build(font_path: String, grid: int, default_scale: int = 2) -> Theme:
	var theme := Theme.new()
	if ResourceLoader.exists(font_path):
		var font := load(font_path)
		if font is FontFile:
			var font_file := font as FontFile
			font_file.antialiasing = TextServer.FONT_ANTIALIASING_NONE
			font_file.hinting = TextServer.HINTING_NONE
			font_file.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
			font_file.multichannel_signed_distance_field = false
			theme.default_font = font_file
	theme.default_font_size = grid * default_scale
	return theme


static func apply(target: Control, theme: Theme) -> void:
	if target == null or not is_instance_valid(target) or theme == null:
		return
	target.theme = theme


static func snap_size(requested: int, grid: int, min_size: int, max_size: int) -> int:
	var snapped := int(round(float(requested) / float(grid))) * grid
	return clampi(snapped, min_size, max_size)
