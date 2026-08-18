extends SceneTree
## 点阵字体主题:资源存在、许可随包、全局生效、字号吸附到 9 的整数倍。

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
	_assert_true(FileAccess.file_exists("res://assets/fonts/BoutiqueBitmap9x9.ttf"), "the pixel font should ship with the project")
	_assert_true(FileAccess.file_exists("res://assets/fonts/BoutiqueBitmap9x9-OFL.txt"), "the OFL license text must ship alongside the font")
	_assert_true(FileAccess.file_exists("res://assets/fonts/FONT_PROVENANCE.md"), "font provenance should be documented")

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
		_assert_true(font != null, "the theme should define a default font")
		if font is FontFile:
			var font_file := font as FontFile
			_assert_true(font_file.antialiasing == TextServer.FONT_ANTIALIASING_NONE, "pixel glyphs must not be antialiased")
			_assert_true(font_file.hinting == TextServer.HINTING_NONE, "pixel glyphs must not be hinted")
			_assert_true(not font_file.multichannel_signed_distance_field, "MSDF would blur a bitmap-style face")
			# 三语字形覆盖:任一语言掉字都会立刻暴露。
			for sample in ["门", "开", "あ", "ド", "A", "7"]:
				_assert_true(font_file.has_char(sample.unicode_at(0)), "the shipped font must cover %s" % sample)

	# 字号吸附:任何请求都落在 9 的整数倍上,且保持在可读区间。
	for requested in [12, 13, 14, 17, 22, 28, 32, 3, 200]:
		var snapped: int = game_root._ui_font_size(requested)
		_assert_true(snapped % 9 == 0, "font size %d should snap to the 9px grid, got %d" % [requested, snapped])
		_assert_true(snapped >= 9 and snapped <= 45, "snapped size %d should stay inside the readable range" % snapped)
	_assert_true(game_root._ui_font_size(13) == 9 or game_root._ui_font_size(13) == 18, "snapping should pick the nearest grid step")

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
