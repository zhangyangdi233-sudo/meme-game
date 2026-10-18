extends SceneTree
## Flashback overlay panel: its phases are painted from the bound UI theme's palette, and a later pollution stage
## repaints them on the next build. Does not load the main scene.

const FlashbackOverlayPanelScript = preload("res://scripts/ui/flashback_overlay_panel.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []


func _init() -> void:
	_test_phases_follow_the_pollution_palette_on_the_next_build()
	RegistryScript.clear()
	if _failures.is_empty():
		print("flashback overlay panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_phases_follow_the_pollution_palette_on_the_next_build() -> void:
	RegistryScript.clear()
	var stage := {"palette_key": "palette_1"}
	var theme := GameUiThemeScript.new() as GameUiTheme
	theme.configure({"pollution_stage": func() -> Dictionary: return stage})
	RegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	var ui_root := Control.new()
	root.add_child(ui_root)
	var panel := FlashbackOverlayPanelScript.new() as FlashbackOverlayPanel
	ui_root.add_child(panel)
	panel.mount(ui_root)

	panel.build_phases()
	_assert_scene_colors(panel, UiPalette.PALETTE_1, "palette 1")

	stage["palette_key"] = "pollution_palette_5"
	panel.refresh_colors()
	panel.build_phases()
	_assert_scene_colors(panel, UiPalette.POLLUTION_PALETTE_5, "pollution palette 5")
	ui_root.free()


func _assert_scene_colors(panel: FlashbackOverlayPanel, palette: Dictionary, label: String) -> void:
	var doll_scene := panel.get_director().get_node_or_null("FlashbackPhaseDollScene")
	if doll_scene == null:
		_failures.append("the doll scene phase should be built (%s)" % label)
		return
	var bg := doll_scene.get_child(0) as ColorRect
	_assert_eq(bg.color, UiPalette.color(palette, "ink"), "the doll scene backdrop should be %s ink" % label)
	for probe in [["FlashbackEchoRow0", "surface"], ["FlashbackUnregisteredCard", "flash_text"]]:
		var text_label := Harness.find_node_by_name(panel.get_director(), probe[0]) as Label
		if text_label == null:
			_failures.append("%s should be built (%s)" % [probe[0], label])
			continue
		var painted := Color(text_label.get_theme_color("font_color"), 1.0)
		_assert_eq(painted, UiPalette.color(palette, probe[1]), "%s should be %s %s" % [probe[0], label, probe[1]])


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(actual), str(expected)])
