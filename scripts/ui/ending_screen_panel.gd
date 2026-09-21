class_name EndingScreenPanel
extends Node
## Game-side ending screen: epilogue chrome, language choice buttons, and restart.

signal ending_language_selected(choice_id: String)

var _label_factory: Callable
var _theme_color_fn: Callable
var _restart_fn: Callable
var _translate_fn: Callable
var _set_localized_property_fn: Callable
var _parent: Control


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_parent = parent
	_apply_mount_deps(deps)


func render(state: Dictionary) -> void:
	if _parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	_clear_ending_screen()
	_build_screen(_parent, state)


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_restart_fn = deps.get("restart", Callable())
	_translate_fn = deps.get("translate", Callable())
	_set_localized_property_fn = deps.get("set_localized_property", Callable())


func _clear_ending_screen() -> void:
	if _parent == null:
		return
	var existing := _parent.get_node_or_null("EndingScreen")
	if existing == null:
		return
	_parent.remove_child(existing)
	existing.free()


func _build_screen(parent: Control, state: Dictionary) -> void:
	var screen := Control.new()
	screen.name = "EndingScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.z_index = 120
	screen.set_meta("empty_tower", true)
	parent.add_child(screen)

	var bg := ColorRect.new()
	bg.name = "EndingBlack"
	bg.color = _theme_color_fn.call("ink")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(bg)

	var rule := ColorRect.new()
	rule.name = "EndingSignalRule"
	rule.color = _theme_color_fn.call("flash_text")
	rule.set_anchors_preset(Control.PRESET_CENTER)
	rule.offset_left = -610
	rule.offset_right = 610
	rule.offset_top = 18
	rule.offset_bottom = 24
	rule.rotation = deg_to_rad(-4.0)
	screen.add_child(rule)

	var system_line := _label_factory.call(
		"FLOOR 05  /  NO SIGNAL  /  WISDOM USER NOT FOUND",
		16,
		_theme_color_fn.call("flash_text"),
	) as Label
	system_line.name = "EndingSystemLine"
	system_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	system_line.offset_left = 56
	system_line.offset_top = 42
	system_line.offset_right = -56
	system_line.offset_bottom = 78
	system_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	system_line.set_meta("on_dark", true)
	system_line.set_meta("skip_localization", true)
	screen.add_child(system_line)

	var center := VBoxContainer.new()
	center.name = "EndingContent"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -500
	center.offset_right = 500
	center.offset_top = -248
	center.offset_bottom = 260
	center.add_theme_constant_override("separation", 18)
	screen.add_child(center)

	var title := _label_factory.call("塔顶没有人", 54, _theme_color_fn.call("surface")) as Label
	title.name = "EndingTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_meta("on_dark", true)
	center.add_child(title)

	var epilogue_lines: Array = state.get("epilogue_lines", [])
	var body_text := "\n".join(epilogue_lines)
	var body := _label_factory.call(body_text, 22, _theme_color_fn.call("muted")) as Label
	body.name = "EndingBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.set_meta("on_dark", true)
	body.set_meta("skip_localization", true)
	center.add_child(body)

	if bool(state.get("show_language_choices", false)):
		var prompt := _label_factory.call("你还能留下一个声音。", 20, _theme_color_fn.call("surface")) as Label
		prompt.name = "EndingLanguagePrompt"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.set_meta("on_dark", true)
		center.add_child(prompt)

		var choices := HBoxContainer.new()
		choices.name = "EndingLanguageChoices"
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", 14)
		center.add_child(choices)

		for choice_value in state.get("language_choices", []):
			var choice: Dictionary = choice_value as Dictionary
			var choice_id := str(choice.get("id", ""))
			var button := Button.new()
			button.name = "EndingLanguageChoice_%s" % choice_id
			button.text = str(choice.get("label", ""))
			button.custom_minimum_size = Vector2(172, 58)
			button.pressed.connect(_on_language_choice_pressed.bind(choice_id), CONNECT_DEFERRED)
			button.set_meta("skip_localization", true)
			choices.add_child(button)
	else:
		var result := _label_factory.call(
			_localized_text("你最后说：\n\n%s\n\n发射机把这个声音送回楼下。\n没有人回答。也许所有人都已经同时说完了。\n（这算是语言结束了吗？）\n指示灯没有提供选项。") % str(state.get("language_output", "")),
			27,
			_theme_color_fn.call("surface"),
		) as Label
		result.name = "EndingLanguageResult"
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.set_meta("on_dark", true)
		result.set_meta("skip_localization", true)
		center.add_child(result)

	var residue := _label_factory.call(
		_localized_text("关系残留 %d / 100  ·  %s") % [int(state.get("relationship_residue", 0)), _localized_text(str(state.get("relationship_state_label", "")))],
		16,
		_theme_color_fn.call("muted"),
	) as Label
	residue.name = "EndingResidue"
	residue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	residue.set_meta("on_dark", true)
	residue.set_meta("skip_localization", true)
	center.add_child(residue)

	var restart := Button.new()
	restart.name = "EndingRestartButton"
	restart.text = "重开"
	restart.custom_minimum_size = Vector2(172, 54)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(_on_restart_pressed, CONNECT_DEFERRED)
	if _set_localized_property_fn.is_valid():
		_set_localized_property_fn.call(restart, "text")
	center.add_child(restart)


func _localized_text(source: String) -> String:
	if _translate_fn.is_valid():
		return str(_translate_fn.call(source))
	return source


func _on_language_choice_pressed(choice_id: String) -> void:
	ending_language_selected.emit(choice_id)


func _on_restart_pressed() -> void:
	if _restart_fn.is_valid():
		_restart_fn.call()
