extends SceneTree
## 点阵字体主题:资源存在、许可随包、全局生效、字号吸附到 9 的整数倍。

const PixelFontThemeScript = preload("res://framework/ui/pixel_font_theme.gd")
const FONT_PATH := "res://assets/fonts/BoutiqueBitmap9x9.ttf"
const FONT_GRID := 9
const FONT_MIN := 9
const FONT_MAX := 45

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("ui font theme tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_assert_true(FileAccess.file_exists(FONT_PATH), "the pixel font should ship with the project")
	_assert_true(FileAccess.file_exists("res://assets/fonts/BoutiqueBitmap9x9-OFL.txt"), "the OFL license text must ship alongside the font")
	_assert_true(FileAccess.file_exists("res://assets/fonts/FONT_PROVENANCE.md"), "font provenance should be documented")

	# Framework seam: snap to grid, then clamp to the readable range.
	_assert_true(PixelFontThemeScript.snap_size(12, FONT_GRID, FONT_MIN, FONT_MAX) == 9, "12 should snap to 9")
	_assert_true(PixelFontThemeScript.snap_size(13, FONT_GRID, FONT_MIN, FONT_MAX) == 9, "13 should snap to 9")
	_assert_true(PixelFontThemeScript.snap_size(14, FONT_GRID, FONT_MIN, FONT_MAX) == 18, "14 should snap to 18")
	_assert_true(PixelFontThemeScript.snap_size(17, FONT_GRID, FONT_MIN, FONT_MAX) == 18, "17 should snap to 18")
	_assert_true(PixelFontThemeScript.snap_size(22, FONT_GRID, FONT_MIN, FONT_MAX) == 18, "22 should snap to 18")
	_assert_true(PixelFontThemeScript.snap_size(28, FONT_GRID, FONT_MIN, FONT_MAX) == 27, "28 should snap to 27")
	_assert_true(PixelFontThemeScript.snap_size(32, FONT_GRID, FONT_MIN, FONT_MAX) == 36, "32 should snap to 36")
	_assert_true(PixelFontThemeScript.snap_size(3, FONT_GRID, FONT_MIN, FONT_MAX) == FONT_MIN, "below-min sizes clamp to 9")
	_assert_true(PixelFontThemeScript.snap_size(200, FONT_GRID, FONT_MIN, FONT_MAX) == FONT_MAX, "above-max sizes clamp to 45")

	var theme: Theme = PixelFontThemeScript.build(FONT_PATH, FONT_GRID)
	_assert_true(theme != null, "build should return a Theme")
	_assert_true(theme.default_font_size == FONT_GRID * 2, "default size should be two grid steps")
	_assert_true(theme.default_font is FontFile, "build should attach the shipped FontFile")
	if theme.default_font is FontFile:
		var built_font := theme.default_font as FontFile
		_assert_true(built_font.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "pixel glyphs must not be antialiased")
		_assert_true(built_font.hinting == TextServer.HINTING_NONE, "pixel glyphs must not be hinted")
		_assert_true(not built_font.multichannel_signed_distance_field, "MSDF would blur a bitmap-style face")

	var apply_host := Control.new()
	PixelFontThemeScript.apply(apply_host, theme)
	_assert_true(apply_host.theme == theme, "apply should assign the theme onto the control")
	apply_host.free()

	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		_failures.append("font test should load the main scene")
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	await process_frame

	var ui_root := _find_node_by_name(game_root, "UIRoot") as Control
	_assert_true(ui_root != null and ui_root.theme != null, "the UI root should carry the pixel-font theme")
	if ui_root != null and ui_root.theme != null:
		var font := ui_root.theme.default_font
		_assert_true(font is FontFile, "the wired theme should define a default font")
		if font is FontFile:
			var font_file := font as FontFile
			# 三语字形覆盖:任一语言掉字都会立刻暴露。
			for sample in ["门", "开", "あ", "ド", "A", "7"]:
				_assert_true(font_file.has_char(sample.unicode_at(0)), "the shipped font must cover %s" % sample)

	# 实际标签也必须用吸附后的字号(不是原始值)。
	var probe_label: Label = game_root._label("测试", 13, Color.WHITE)
	_assert_true(probe_label.get_theme_font_size("font_size") % 9 == 0, "labels should render on the pixel grid")

	game_root.queue_free()
	await process_frame


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
