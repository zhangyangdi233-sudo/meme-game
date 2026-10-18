extends SceneTree
## The day-transition and prologue backdrops stay UiPalette.VOID, and the conversation text outlines stay
## UiPalette.OUTLINE, while the bound theme is on pollution_palette_5. Does not load the main scene.

const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const DayTransitionPanelScript = preload("res://scripts/ui/day_transition_panel.gd")
const ProloguePanelScript = preload("res://scripts/ui/prologue_panel.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

const TRUE_BLACK := Color("000000")
const NEAR_BLACK_OUTLINE := Color("050705")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("void and outline tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_day_transition_backdrop_stays_void()
	_test_prologue_backdrop_stays_void()
	_test_conversation_text_outlines_stay_outline()


func _test_day_transition_backdrop_stays_void() -> void:
	var ui_root := _ui_root_on_pollution_palette_5()
	var panel := DayTransitionPanelScript.new() as DayTransitionPanel
	ui_root.add_child(panel)
	panel.mount(ui_root)
	var black := Harness.find_node_by_name(ui_root, "DayTransitionBlack") as ColorRect
	_assert_true(black != null, "the day transition should build its black backdrop")
	if black != null:
		_assert_eq(black.color, TRUE_BLACK, "the day transition backdrop should stay true black under pollution palette 5")
	ui_root.free()


func _test_prologue_backdrop_stays_void() -> void:
	var ui_root := _ui_root_on_pollution_palette_5()
	var panel := ProloguePanelScript.new() as ProloguePanel
	ui_root.add_child(panel)
	panel.mount(ui_root, {"prologue_lines": ["line"]})
	var black := Harness.find_node_by_name(ui_root, "PrologueBlack") as ColorRect
	_assert_true(black != null, "the prologue should build its black backdrop")
	if black != null:
		_assert_eq(black.color, TRUE_BLACK, "the prologue backdrop should stay true black under pollution palette 5")
	ui_root.free()


func _test_conversation_text_outlines_stay_outline() -> void:
	var ui_root := _ui_root_on_pollution_palette_5()
	var panel := RealityConversationPanel.new()
	ui_root.add_child(panel)
	panel.mount(ui_root, {
		"viewport_size": func() -> Vector2: return Vector2(1600, 900),
		"install_rich_text_effect": func(_label_node: RichTextLabel, _effect: String) -> void: pass,
	})
	for label_name in ["RealityIntentPreview", "RealitySubtitleLabel"]:
		var label := Harness.find_node_by_name(ui_root, label_name) as RichTextLabel
		_assert_true(label != null, "the conversation panel should build %s" % label_name)
		if label != null:
			_assert_eq(label.get_theme_color("font_outline_color"), NEAR_BLACK_OUTLINE, "%s outline should stay near black under pollution palette 5" % label_name)
	ui_root.free()


func _ui_root_on_pollution_palette_5() -> Control:
	RegistryScript.clear()
	var theme := GameUiThemeScript.new() as GameUiTheme
	theme.configure({"pollution_stage": func() -> Dictionary: return {"palette_key": "pollution_palette_5"}})
	RegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	var ui_root := Control.new()
	ui_root.size = Vector2(1600, 900)
	root.add_child(ui_root)
	return ui_root


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
