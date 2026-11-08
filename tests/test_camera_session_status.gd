extends SceneTree
## The camera session words its status label from the tracking status and translates it through the bound UI theme.

const CameraSessionScript = preload("res://scripts/integrations/camera_session.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const HandTrackingStatusScript = preload("res://framework/integrations/hand_tracking_status.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

var _failures: Array[String] = []


func _init() -> void:
	RegistryScript.clear()
	_test_the_status_label_is_translated_through_the_bound_theme()
	_test_a_language_switch_retranslates_the_status_label()
	_test_without_a_theme_the_status_label_shows_the_source_text()
	RegistryScript.clear()
	if _failures.is_empty():
		print("camera session status tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _bind_theme(prefix: Array) -> GameUiTheme:
	var theme: GameUiTheme = GameUiThemeScript.new()
	theme.configure({"locale_translate": func(source: String) -> String: return "%s%s" % [prefix[0], source]})
	RegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	return theme


func _session_with_label() -> CameraSession:
	var session: CameraSession = CameraSessionScript.new()
	session.status_label = Label.new()
	session.tracking_status = HandTrackingStatusScript.Status.DISABLED
	return session


func _test_the_status_label_is_translated_through_the_bound_theme() -> void:
	var theme := _bind_theme(["en:"])
	var session := _session_with_label()
	session.refresh_status_ui()
	var source := HandTrackingStatusScript.display_text(HandTrackingStatusScript.Status.DISABLED)
	_assert_eq(session.status_label.text, "en:%s" % source, "the status label should be translated by the bound theme")
	session.status_label.free()
	session.free()
	RegistryScript.unbind(ServiceKeysScript.UI_THEME, theme)


func _test_a_language_switch_retranslates_the_status_label() -> void:
	var prefix := ["en:"]
	var theme := _bind_theme(prefix)
	var session := _session_with_label()
	session.refresh_status_ui()
	prefix[0] = "ja:"
	theme.localize_control_tree(session.status_label)
	var source := HandTrackingStatusScript.display_text(HandTrackingStatusScript.Status.DISABLED)
	_assert_eq(session.status_label.text, "ja:%s" % source, "a language switch should retranslate from the source text")
	session.status_label.free()
	session.free()
	RegistryScript.unbind(ServiceKeysScript.UI_THEME, theme)


func _test_without_a_theme_the_status_label_shows_the_source_text() -> void:
	var session := _session_with_label()
	session.refresh_status_ui()
	var source := HandTrackingStatusScript.display_text(HandTrackingStatusScript.Status.DISABLED)
	_assert_eq(session.status_label.text, source, "with no theme bound the label should show the source text")
	session.status_label.free()
	session.free()


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
