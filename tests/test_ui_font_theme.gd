extends SceneTree
## 点阵字体主题:资源存在、许可随包、GameUiTheme 字号吸附与字形覆盖。

const PixelFontThemeScript = preload("res://framework/ui/pixel_font_theme.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const FONT_PATH := "res://assets/fonts/BoutiqueBitmap9x9.ttf"
const FONT_GRID := 9
const FONT_MIN := 9
const FONT_MAX := 45

var _failures: Array[String] = []


func _init() -> void:
	_run()
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

	var ui_theme := GameUiThemeScript.new()
	ui_theme.configure({
		"ui_font_path": FONT_PATH,
		"ui_font_grid": FONT_GRID,
		"ui_font_min_size": FONT_MIN,
		"ui_font_max_size": FONT_MAX,
	})
	var wired_theme := ui_theme.ensure_ui_font_theme()
	_assert_true(wired_theme != null and wired_theme.default_font is FontFile, "GameUiTheme should build the shipped pixel font")
	if wired_theme.default_font is FontFile:
		var font_file := wired_theme.default_font as FontFile
		for sample in ["门", "开", "あ", "ド", "A", "7"]:
			_assert_true(font_file.has_char(sample.unicode_at(0)), "the shipped font must cover %s" % sample)

	var probe_label: Label = ui_theme.label("测试", 13, Color.WHITE)
	_assert_true(probe_label.get_theme_font_size("font_size") % 9 == 0, "labels should render on the pixel grid")

	ui_theme.configure({
		"ui_font_path": FONT_PATH,
		"ui_font_grid": FONT_GRID,
		"ui_font_min_size": FONT_MIN,
		"ui_font_max_size": FONT_MAX,
		"pollution_stage": func() -> Dictionary: return {"palette_key": "pollution_palette_5"},
	})
	_assert_eq(ui_theme.theme_color("flash_text"), Color("39FF14"), "bound pollution stage should drive one-arg theme_color")
	_assert_eq(str(ui_theme.active_palette().get("name", "")), "pollution_palette_5", "bound pollution stage should select the high-pollution palette")
	_assert_eq(ui_theme.theme_color("flash_text", {"palette_key": "palette_1"}), Color("9CFF24"), "an explicit stage should still override the bound provider")
	_assert_eq(ui_theme.theme_color("flash_text", {}), Color("9CFF24"), "an explicit empty stage should keep the default palette")

	var themed_root := Control.new()
	ui_theme.apply_ui_font_theme(themed_root)
	_assert_true(themed_root.theme == wired_theme, "apply_ui_font_theme should wire the built theme onto controls")
	themed_root.free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
