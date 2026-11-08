extends SceneTree
## The overlays that hide the game (camera consent, language selection, phone camera connection)
## paint their full-screen backdrop with the bound theme's scrim, so it follows the pollution palette.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const CameraConsentPanelScript = preload("res://scripts/ui/camera_consent_panel.gd")
const LanguageSelectionPanelScript = preload("res://scripts/ui/language_selection_panel.gd")
const PhoneCameraConnectionPanelScript = preload("res://scripts/ui/phone_camera_connection_panel.gd")
## The scrim strength issue #103 settled on, pinned here rather than read back from the theme.
const SCRIM_ALPHA := 0.92

var _failures: Array[String] = []


func _init() -> void:
	_run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("full screen scrim tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_backdrop("CameraConsentBackdrop", func(panel: Node, host: Control) -> void: (panel as CameraConsentPanel).build(host), CameraConsentPanelScript)
	_test_backdrop("LanguageSelectionBackdrop", func(panel: Node, host: Control) -> void: (panel as LanguageSelectionPanel).build(host, true, {"locales": [{"code": "zh", "name": "中文"}]}), LanguageSelectionPanelScript)
	_test_backdrop("PhoneCameraConnectionBackdrop", func(panel: Node, host: Control) -> void: (panel as PhoneCameraConnectionPanel).build(host), PhoneCameraConnectionPanelScript)


func _test_backdrop(backdrop_name: String, build: Callable, panel_script: GDScript) -> void:
	RegistryScript.clear()
	BootScript.install()
	var theme: GameUiTheme = GameUiThemeScript.new()
	theme.configure({"pollution_stage": func() -> Dictionary: return {"palette_key": "pollution_palette_5"}})
	RegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	var host := Control.new()
	root.add_child(host)
	var panel: Node = panel_script.new()
	root.add_child(panel)
	build.call(panel, host)

	var backdrop := host.find_child(backdrop_name, true, false) as ColorRect
	_assert_true(backdrop != null, "%s should exist" % backdrop_name)
	if backdrop != null:
		_assert_eq(backdrop.color, Color(UiPalette.color(UiPalette.POLLUTION_PALETTE_5, "ink"), SCRIM_ALPHA), "%s should be the theme scrim under pollution palette 5" % backdrop_name)

	panel.free()
	host.free()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
