extends SceneTree
## Phone launcher, camera consent, and phone-camera connection raise their actions on the event bus.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const CameraConsentPanelScript = preload("res://scripts/ui/camera_consent_panel.gd")
const PhoneCameraConnectionPanelScript = preload("res://scripts/ui/phone_camera_connection_panel.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("phone camera intents tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_intent_names_and_payload_keys()
	_test_launcher_raises_icon_close_and_window_close()
	_test_camera_consent_raises_allow_skip_and_source()
	_test_phone_camera_connection_raises_retry_continue_disable()


func _test_intent_names_and_payload_keys() -> void:
	_assert_eq(UiIntentsScript.APP_ICON_PRESSED, "app_icon_pressed", "app icon intent name")
	_assert_eq(UiIntentsScript.PHONE_CLOSE_REQUESTED, "phone_close_requested", "phone close intent name")
	_assert_eq(UiIntentsScript.APP_WINDOW_CLOSE_REQUESTED, "app_window_close_requested", "app window close intent name")
	_assert_eq(UiIntentsScript.CAMERA_CONSENT_RESOLVED, "camera_consent_resolved", "camera consent intent name")
	_assert_eq(UiIntentsScript.CAMERA_SOURCE_SELECTED, "camera_source_selected", "camera source intent name")
	_assert_eq(UiIntentsScript.PHONE_CAMERA_RETRY, "phone_camera_retry", "phone camera retry intent name")
	_assert_eq(UiIntentsScript.PHONE_CAMERA_CONTINUE, "phone_camera_continue", "phone camera continue intent name")
	_assert_eq(UiIntentsScript.PHONE_CAMERA_DISABLE, "phone_camera_disable", "phone camera disable intent name")
	_assert_eq(UiIntentsScript.KEY_APP_ID, "app_id", "app id payload key")
	_assert_eq(UiIntentsScript.KEY_ALLOWED, "allowed", "allowed payload key")
	_assert_eq(UiIntentsScript.KEY_INDEX, "index", "index payload key")


func _test_launcher_raises_icon_close_and_window_close() -> void:
	_bind_bus()
	var host := Control.new()
	host.size = Vector2(1600, 900)
	root.add_child(host)
	var panel := PhoneLauncherPanel.new()
	root.add_child(panel)
	panel.mount(host, {
		"panel_factory": func() -> PanelContainer: return PanelContainer.new(),
		"label_factory": _label,
		"theme_color": _theme_color,
		"viewport_size": func() -> Vector2: return Vector2(1600, 900),
	})
	panel.set_shown(true)

	_press(host, "PhoneAppIconSocial")
	_assert_eq(_heard, [[UiIntentsScript.APP_ICON_PRESSED, {"app_id": "social"}]], "an app icon should raise its id")
	_heard.clear()
	_press(host, "PhoneHomeCloseButton")
	_assert_eq(_heard, [[UiIntentsScript.PHONE_CLOSE_REQUESTED, {}]], "the phone close button should raise an empty intent")
	_heard.clear()
	var close := panel.get_app_window("babel").find_child("*CloseButton", true, false) as Button
	_assert_true(close != null, "the babel window should have a close button")
	if close != null:
		close.pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.APP_WINDOW_CLOSE_REQUESTED, {"app_id": "babel"}]], "a window close should raise the app id")

	panel.free()
	host.free()
	RegistryScript.clear()


func _test_camera_consent_raises_allow_skip_and_source() -> void:
	_bind_bus()
	var host := Control.new()
	root.add_child(host)
	var panel := CameraConsentPanelScript.new()
	root.add_child(panel)
	panel.build(host, {
		"label_factory": _label,
		"theme_color": _theme_color,
		"soft_style": func(_bg: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
		"populate_camera_source_option": func(option: OptionButton) -> void:
			option.add_item("computer")
			option.add_item("phone"),
	})

	_press(host, "CameraConsentAllowButton")
	_assert_eq(_heard, [[UiIntentsScript.CAMERA_CONSENT_RESOLVED, {"allowed": true}]], "allow should raise allowed true")
	_heard.clear()
	_press(host, "CameraConsentSkipButton")
	_assert_eq(_heard, [[UiIntentsScript.CAMERA_CONSENT_RESOLVED, {"allowed": false}]], "skip should raise allowed false")
	_heard.clear()
	panel.get_source_option().item_selected.emit(1)
	_assert_eq(_heard, [[UiIntentsScript.CAMERA_SOURCE_SELECTED, {"index": 1}]], "choosing a source should raise its index")

	panel.free()
	host.free()
	RegistryScript.clear()


func _test_phone_camera_connection_raises_retry_continue_disable() -> void:
	_bind_bus()
	var host := Control.new()
	root.add_child(host)
	var panel := PhoneCameraConnectionPanelScript.new()
	root.add_child(panel)
	panel.build(host, {
		"label_factory": _label,
		"theme_color": _theme_color,
		"soft_style": func(_bg: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
		"panel_factory": func() -> PanelContainer: return PanelContainer.new(),
		"set_localized_property": func(_node: Object, _property: String, _text: String) -> void: pass,
	})

	_press(host, "PhoneCameraConnectionRetryButton")
	_press(host, "PhoneCameraConnectionContinueButton")
	_press(host, "PhoneCameraConnectionDisableButton")
	_assert_eq(_heard, [
		[UiIntentsScript.PHONE_CAMERA_RETRY, {}],
		[UiIntentsScript.PHONE_CAMERA_CONTINUE, {}],
		[UiIntentsScript.PHONE_CAMERA_DISABLE, {}],
	], "the connection buttons should raise empty intents")

	panel.free()
	host.free()
	RegistryScript.clear()


func _bind_bus() -> void:
	RegistryScript.clear()
	BootScript.install()
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))


func _press(host: Node, button_name: String) -> void:
	var button := host.find_child(button_name, true, false) as BaseButton
	_assert_true(button != null, "%s should exist" % button_name)
	if button != null:
		button.pressed.emit()


func _label(text: String, _size: int, _color: Color) -> Label:
	var label_node := Label.new()
	label_node.text = text
	return label_node


func _theme_color(_key: String) -> Color:
	return Color("F5F7F2")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
