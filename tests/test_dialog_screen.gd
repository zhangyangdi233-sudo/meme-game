extends SceneTree
## Dialog: any panel resolves the dialog screen manager from the service registry and opens it with a spec.
## Buttons are built from the spec, translated, and close the dialog before their callback runs.

const BootScript = preload("res://scripts/game/property_boot.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const LocaleFontScript = preload("res://scripts/ui/locale_font.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PIXEL_FONT_PATH := "res://assets/fonts/BoutiqueBitmap9x9.ttf"
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []
var _warnings := WarningLog.new()


## Collects warnings and script errors pushed while a test runs.
class WarningLog extends Logger:
	var lines: Array[String] = []

	func _log_error(_function: String, _file: String, _line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		# Script errors are kept apart, so a call on an empty Callable is not mistaken for the warning.
		var text := rationale if not rationale.is_empty() else code
		if error_type == ERROR_TYPE_WARNING:
			lines.append("warning: %s" % text)
		elif error_type == ERROR_TYPE_SCRIPT:
			lines.append("error: %s" % text)

	func take() -> Array[String]:
		var taken := lines.duplicate()
		lines.clear()
		return taken


## Records the keys that reach the unhandled stage, like the host's hotkeys.
class HotkeyListener extends Node:
	var keys: Array[int] = []

	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed:
			keys.append((event as InputEventKey).keycode)


class Target extends Node:
	var calls := 0

	func hit() -> void:
		calls += 1


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await process_frame
	root.size = Vector2i(1600, 900)
	OS.add_logger(_warnings)
	await _test_open_from_the_registry_lays_out_translated_buttons_left_to_right()
	_test_a_press_closes_before_its_callback_runs()
	_test_a_button_without_a_callback_only_closes()
	_test_a_stale_callback_is_skipped_with_a_warning()
	_test_a_second_open_is_refused_and_leaves_the_first_alone()
	_test_the_owner_leaving_the_tree_closes_without_callbacks()
	_test_an_earlier_owner_leaving_does_not_close_a_later_dialog()
	_test_cancel_index_takes_escape_and_the_first_focus()
	_test_without_cancel_index_escape_does_nothing()
	await _test_ui_below_cannot_be_clicked_or_focused_while_open()
	_test_the_dialog_follows_the_pollution_palette()
	_test_a_spec_without_one_to_three_buttons_is_refused()
	await _test_ui_added_after_opening_stays_below_for_clicks()
	_test_hotkeys_below_are_held_while_open()
	_test_the_dialog_uses_the_locale_font_and_follows_a_switch_while_open()
	await _test_buttons_ignore_hover_and_underline_keyboard_focus()
	OS.remove_logger(_warnings)
	if _failures.is_empty():
		print("dialog screen tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_open_from_the_registry_lays_out_translated_buttons_left_to_right() -> void:
	var mounted := _mount()
	var pressed: Array[String] = []
	for count in [1, 2, 3]:
		var spec_buttons: Array = []
		for index in count:
			spec_buttons.append({"text": "按钮%d" % index, "callback": pressed.append.bind("%d-%d" % [count, index])})
		var screen := _dialog().open({"message": "确定吗", "buttons": spec_buttons}) as Control
		await process_frame
		_assert_true(screen != null and screen.visible, "%d-button dialog should open from the registry" % count)
		_assert_eq(_label_text(screen, "DialogMessage"), "[确定吗]", "the message should be translated through the bound theme")
		var buttons := _buttons(screen)
		_assert_eq(buttons.size(), count, "the dialog should build one button per spec entry")
		for index in buttons.size():
			_assert_eq(buttons[index].text, "[按钮%d]" % index, "button %d of %d should show its translated text" % [index, count])
			if index > 0:
				_assert_true(buttons[index].global_position.x > buttons[index - 1].global_position.x, "button %d of %d should sit right of the one before" % [index, count])
		var last := buttons.size() - 1
		if last >= 0:
			buttons[last].pressed.emit()
		_assert_eq(pressed.back() if not pressed.is_empty() else "", "%d-%d" % [count, last], "pressing button %d of %d should run its own callback" % [last, count])
		_assert_true(not screen.visible, "pressing a button should close the %d-button dialog" % count)
	_assert_eq(pressed.size(), 3, "each press should run exactly one callback")
	_dispose(mounted)


func _test_a_press_closes_before_its_callback_runs() -> void:
	var mounted := _mount()
	var seen := {}
	var follow_up := func() -> void: seen["follow_up"] = true
	var first := func() -> void:
		seen["visible_during_callback"] = (mounted["screen_ref"] as Array)[0].visible
		seen["reopened"] = _dialog().open({"message": "第二个", "buttons": [{"text": "好", "callback": follow_up}]})
	var screen := _dialog().open({"message": "第一个", "buttons": [{"text": "好", "callback": first}]}) as Control
	(mounted["screen_ref"] as Array).append(screen)
	_buttons(screen)[0].pressed.emit()
	_assert_eq(seen.get("visible_during_callback", true), false, "the dialog should be closed before the callback runs")
	_assert_true(seen.get("reopened") == screen and screen.visible, "a callback should be able to open the next dialog")
	_assert_eq(_label_text(screen, "DialogMessage"), "[第二个]", "the next dialog should show its own message")
	_assert_eq(_buttons(screen).size(), 1, "the next dialog should show only its own buttons")
	_buttons(screen)[0].pressed.emit()
	_assert_true(seen.get("follow_up", false), "the next dialog's button should run the next callback")
	_dispose(mounted)


func _test_a_button_without_a_callback_only_closes() -> void:
	var mounted := _mount()
	var screen := _dialog().open({"message": "提示", "buttons": [{"text": "知道了"}, {"text": "关闭", "callback": Callable()}]}) as Control
	_buttons(screen)[0].pressed.emit()
	_assert_true(not screen.visible, "a button without a callback should close the dialog")
	screen = _dialog().open({"message": "提示", "buttons": [{"text": "知道了", "callback": null}]}) as Control
	_assert_true(screen.visible and _buttons(screen).size() == 1, "a null callback should still open the dialog")
	_buttons(screen)[0].pressed.emit()
	_assert_true(not screen.visible, "a button without a callback should close the dialog")
	screen = _dialog().open({"message": "提示", "buttons": [{"text": "知道了"}, {"text": "关闭", "callback": Callable()}]}) as Control
	_buttons(screen)[1].pressed.emit()
	_assert_true(not screen.visible, "a button with an empty callback should close the dialog")
	_assert_eq(_warnings.take(), [] as Array[String], "an empty callback is not a mistake and should neither warn nor error")
	_dispose(mounted)


func _test_a_stale_callback_is_skipped_with_a_warning() -> void:
	var mounted := _mount()
	var target := Target.new()
	root.add_child(target)
	var screen := _dialog().open({"message": "提示", "buttons": [{"text": "好", "callback": target.hit}]}) as Control
	target.free()
	_buttons(screen)[0].pressed.emit()
	_assert_true(not screen.visible, "a stale callback should still close the dialog")
	var logged := _warnings.take()
	_assert_true(logged.size() == 1 and logged[0].begins_with("warning: "), "a stale callback should be skipped with one warning (got %s)" % str(logged))
	_dispose(mounted)


func _test_a_second_open_is_refused_and_leaves_the_first_alone() -> void:
	var mounted := _mount()
	var pressed: Array[String] = []
	var screen := _dialog().open({"message": "第一个", "buttons": [{"text": "甲", "callback": pressed.append.bind("first")}]}) as Control
	_warnings.take()
	_dialog().open({"message": "第二个", "buttons": [{"text": "乙", "callback": pressed.append.bind("second")}, {"text": "丙"}]})
	var logged := _warnings.take()
	_assert_true(logged.size() == 1 and logged[0].begins_with("warning: "), "a second open should be refused with one warning (got %s)" % str(logged))
	_assert_true(screen.visible, "the first dialog should stay open")
	_assert_eq(_label_text(screen, "DialogMessage"), "[第一个]", "the first dialog should keep its message")
	var buttons := _buttons(screen)
	_assert_eq(buttons.size(), 1, "the first dialog should keep its buttons")
	if buttons.size() == 1:
		_assert_eq(buttons[0].text, "[甲]", "the first dialog should keep its button text")
		buttons[0].pressed.emit()
	_assert_eq(pressed, ["first"] as Array[String], "the first dialog's button should still run its own callback")
	_dispose(mounted)


func _test_the_owner_leaving_the_tree_closes_without_callbacks() -> void:
	var mounted := _mount()
	var owner_node := Node.new()
	root.add_child(owner_node)
	var pressed: Array[String] = []
	var screen := _dialog().open({
		"message": "提示",
		"buttons": [{"text": "好", "callback": pressed.append.bind("ok")}],
		"cancel_index": 0,
		"owner": owner_node,
	}) as Control
	owner_node.free()
	_assert_true(not screen.visible, "the owner leaving the tree should close the dialog")
	_assert_eq(pressed, [] as Array[String], "closing for the owner should run no callback")
	_warnings.take()
	_dialog().open({"message": "下一个", "buttons": [{"text": "好"}]})
	_assert_eq(_warnings.take(), [] as Array[String], "a dialog closed for its owner should accept the next open")
	_assert_true(screen.visible and _label_text(screen, "DialogMessage") == "[下一个]", "the next open should show after the owner closed the last one")
	_dispose(mounted)


func _test_an_earlier_owner_leaving_does_not_close_a_later_dialog() -> void:
	var mounted := _mount()
	var first_owner := Node.new()
	root.add_child(first_owner)
	var screen := _dialog().open({"message": "第一个", "buttons": [{"text": "好"}], "owner": first_owner}) as Control
	_buttons(screen)[0].pressed.emit()
	_dialog().open({"message": "第二个", "buttons": [{"text": "好"}]})
	first_owner.free()
	_assert_true(screen.visible, "an earlier owner leaving should not close a later dialog it does not own")
	_dispose(mounted)


func _test_cancel_index_takes_escape_and_the_first_focus() -> void:
	var mounted := _mount()
	var pressed: Array[String] = []
	var screen := _dialog().open({
		"message": "离开吗",
		"buttons": [
			{"text": "离开", "callback": pressed.append.bind("leave")},
			{"text": "留下", "callback": pressed.append.bind("stay")},
			{"text": "再想想", "callback": pressed.append.bind("later")},
		],
		"cancel_index": 1,
	}) as Control
	var buttons := _buttons(screen)
	_assert_true(buttons.size() == 3 and root.gui_get_focus_owner() == buttons[1], "the cancel button should take the first focus")
	_press_escape()
	_assert_eq(pressed, ["stay"] as Array[String], "escape should press the cancel button")
	_assert_true(not screen.visible, "escape on the cancel button should close the dialog")
	_dispose(mounted)


func _test_without_cancel_index_escape_does_nothing() -> void:
	var mounted := _mount()
	var pressed: Array[String] = []
	var screen := _dialog().open({
		"message": "必须选择",
		"buttons": [{"text": "是", "callback": pressed.append.bind("yes")}, {"text": "否", "callback": pressed.append.bind("no")}],
	}) as Control
	var buttons := _buttons(screen)
	_assert_true(buttons.size() == 2 and root.gui_get_focus_owner() == buttons[0], "without a cancel button the first button should take the focus")
	_press_escape()
	_assert_eq(pressed, [] as Array[String], "escape without a cancel button should press nothing")
	_assert_true(screen.visible, "escape without a cancel button should leave the dialog open")
	_dispose(mounted)


func _test_ui_below_cannot_be_clicked_or_focused_while_open() -> void:
	var mounted := _mount()
	var under := Button.new()
	under.name = "UnderButton"
	under.text = "below"
	under.z_index = 220
	under.position = Vector2(700, 400)
	under.size = Vector2(200, 100)
	(mounted["layer"] as Control).add_child(under)
	var under_presses: Array[int] = []
	under.pressed.connect(func() -> void: under_presses.append(1))
	await process_frame
	var center := under.get_global_rect().get_center()
	_click(center)
	_assert_eq(under_presses.size(), 1, "with no dialog the button below should take a click")

	var screen := _dialog().open({"message": "挡住", "buttons": [{"text": "一"}, {"text": "二"}], "cancel_index": 0}) as Control
	await process_frame
	var buttons := _buttons(screen)
	_click(center)
	_assert_eq(under_presses.size(), 1, "an open dialog should keep clicks from the UI below")
	under.grab_focus()
	_assert_true(root.gui_get_focus_owner() != under and screen.is_ancestor_of(root.gui_get_focus_owner()), "an open dialog should keep the focus from the UI below")
	buttons[1].grab_focus()
	_press_key(KEY_TAB)
	_assert_true(root.gui_get_focus_owner() == buttons[0], "tab from the last dialog button should wrap to the first")
	_press_key(KEY_TAB, true)
	_assert_true(root.gui_get_focus_owner() == buttons[1], "shift-tab from the first dialog button should wrap to the last")

	buttons[0].pressed.emit()
	_click(center)
	_assert_eq(under_presses.size(), 2, "after the dialog closes the button below should take clicks again")
	under.grab_focus()
	_assert_true(root.gui_get_focus_owner() == under, "after the dialog closes the button below should take the focus again")
	_dispose(mounted)


func _test_the_dialog_follows_the_pollution_palette() -> void:
	var mounted := _mount()
	var screen := _dialog().open({"message": "颜色", "buttons": [{"text": "好"}]}) as Control
	_assert_rgb(screen, "DialogSurface", Color("FFF1C9"), "the dialog surface should use the clean surface role")
	_assert_rgb(screen, "DialogFrame", Color("10140F"), "the dialog frame should use the clean ink role")
	var scrim := Harness.find_node_by_name(screen, "DialogScrim") as ColorRect
	_assert_true(scrim != null and scrim.color.a < 1.0, "the scrim should keep the alpha authored in the editor")
	var message := Harness.find_node_by_name(screen, "DialogMessage") as Label
	_assert_eq(Color(message.get_theme_color("font_color"), 1.0), Color("10140F"), "the message should use the clean ink role")
	var button := _buttons(screen)[0]
	_assert_eq((button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Color("FFF1C9"), "a built button should take the clean button style")

	Harness.publish_title_facts(60, false)
	_assert_rgb(screen, "DialogSurface", Color("FFF2B8"), "an open dialog should repaint its surface when the pollution stage changes")
	_assert_rgb(screen, "DialogFrame", Color("0D1009"), "an open dialog should repaint its frame when the pollution stage changes")
	_assert_eq((button.get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Color("FFF2B8"), "an open dialog should repaint its buttons when the pollution stage changes")
	button.pressed.emit()

	screen = _dialog().open({"message": "颜色", "buttons": [{"text": "好"}, {"text": "不"}]}) as Control
	_assert_eq((_buttons(screen)[1].get_theme_stylebox("normal") as StyleBoxFlat).bg_color, Color("FFF2B8"), "buttons built on a later open should take the current palette")
	_dispose(mounted)


func _test_a_spec_without_one_to_three_buttons_is_refused() -> void:
	var mounted := _mount()
	_warnings.take()
	for count in [0, 4]:
		var spec_buttons: Array = []
		for index in count:
			spec_buttons.append({"text": "按钮%d" % index})
		var screen := _dialog().open({"message": "坏的", "buttons": spec_buttons}) as Control
		var logged := _warnings.take()
		_assert_true(logged.size() == 1 and logged[0].begins_with("warning: "), "a spec with %d buttons should be refused with one warning (got %s)" % [count, str(logged)])
		_assert_true(screen != null and not screen.visible, "a spec with %d buttons should leave the dialog closed" % count)
	var good := _dialog().open({"message": "好的", "buttons": [{"text": "好"}]}) as Control
	_assert_true(good.visible and _buttons(good).size() == 1, "a valid spec should open after a refused one")
	_dispose(mounted)


func _assert_rgb(screen: Node, node_name: String, rgb: Color, message: String) -> void:
	var rect := Harness.find_node_by_name(screen, node_name) as ColorRect
	if rect == null:
		_failures.append("missing %s" % node_name)
		return
	_assert_eq(Color(rect.color, 1.0), Color(rgb, 1.0), message)


func _test_ui_added_after_opening_stays_below_for_clicks() -> void:
	var mounted := _mount()
	var screen := _dialog().open({"message": "挡住", "buttons": [{"text": "好"}]}) as Control
	var late := Button.new()
	late.name = "LateOverlayButton"
	late.position = Vector2(100, 100)
	late.size = Vector2(200, 100)
	(mounted["layer"] as Control).add_child(late)
	var presses: Array[int] = []
	late.pressed.connect(func() -> void: presses.append(1))
	await process_frame
	_click(late.get_global_rect().get_center())
	_assert_eq(presses.size(), 0, "UI added to the layer after the dialog opened should still not take clicks")
	_buttons(screen)[0].pressed.emit()
	_dispose(mounted)


func _test_hotkeys_below_are_held_while_open() -> void:
	var mounted := _mount()
	var listener := HotkeyListener.new()
	(mounted["host"] as Node).add_child(listener)
	(mounted["host"] as Node).move_child(listener, 0)
	_press_key(KEY_F)
	_assert_eq(listener.keys, [KEY_F] as Array[int], "with no dialog a hotkey should reach the unhandled stage")
	var screen := _dialog().open({"message": "挡住", "buttons": [{"text": "好"}]}) as Control
	_press_key(KEY_F)
	_press_key(KEY_TAB)
	_assert_eq(listener.keys, [KEY_F] as Array[int], "an open dialog should keep hotkeys from the game below")
	_buttons(screen)[0].pressed.emit()
	_press_key(KEY_F)
	_assert_eq(listener.keys, [KEY_F, KEY_F] as Array[int], "after the dialog closes hotkeys should reach the game again")
	_dispose(mounted)


func _test_the_dialog_uses_the_locale_font_and_follows_a_switch_while_open() -> void:
	var mounted := _mount()
	var pixel_label := Label.new()
	pixel_label.text = "像素"
	(mounted["layer"] as Control).add_child(pixel_label)
	(mounted["theme"] as GameUiTheme).apply_ui_font_theme(pixel_label)
	for locale in ["en", "zh", "ja"]:
		_write_locale(locale)
		var screen := _dialog().open({"message": "字体", "buttons": [{"text": "是"}, {"text": "否"}]}) as Control
		_assert_font(screen, LocaleFontScript.font(locale), "a dialog opened in %s should use that language's font" % locale)
		_buttons(screen)[0].pressed.emit()
	var screen := _dialog().open({"message": "字体", "buttons": [{"text": "是"}, {"text": "否"}]}) as Control
	_write_locale("en")
	_assert_font(screen, LocaleFontScript.font("en"), "switching the language while the dialog is open should swap its font at once")
	_write_locale("zh")
	_assert_font(screen, LocaleFontScript.font("zh"), "switching back while open should swap the font back")
	_assert_eq((pixel_label.get_theme_font("font") as FontFile).resource_path, PIXEL_FONT_PATH, "UI outside the dialog should keep the pixel font")
	_buttons(screen)[0].pressed.emit()
	_dispose(mounted)


func _test_buttons_ignore_hover_and_underline_keyboard_focus() -> void:
	var mounted := _mount()
	var screen := _dialog().open({"message": "焦点", "buttons": [{"text": "是"}, {"text": "否"}]}) as Control
	await process_frame
	for stage in ["clean", "polluted"]:
		for button in _buttons(screen):
			var normal := button.get_theme_stylebox("normal") as StyleBoxFlat
			var hover := button.get_theme_stylebox("hover") as StyleBoxFlat
			_assert_true(hover != null and hover.bg_color == normal.bg_color and hover.border_color == normal.border_color,
				"a %s dialog button should look the same hovered as idle" % stage)
			_assert_eq(button.get_theme_color("font_hover_color"), button.get_theme_color("font_color"), "a %s dialog button's text should not change on hover" % stage)
			var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
			_assert_true(focus != null and not focus.draw_center, "a %s dialog button's focus mark should draw no fill" % stage)
			if focus != null:
				_assert_true(focus.border_width_bottom > 0 and focus.border_width_top == 0 and focus.border_width_left == 0 and focus.border_width_right == 0,
					"a %s dialog button's focus mark should be an underline only" % stage)
				_assert_eq(Color(focus.border_color, 1.0), Color(button.get_theme_color("font_color"), 1.0), "a %s dialog button's underline should be the text color" % stage)
		Harness.publish_title_facts(60, false)
	var buttons := _buttons(screen)
	_assert_true(buttons[0].has_focus() and not buttons[1].has_focus(), "the first button should hold the focus on open")
	_press_key(KEY_TAB)
	_assert_true(buttons[1].has_focus() and not buttons[0].has_focus(), "tab should move the underline to the next button and off the first")
	buttons[0].pressed.emit()
	_dispose(mounted)


func _write_locale(locale: String) -> void:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	manager.model(PropertyKeysScript.LOCALE).write(locale)


func _assert_font(screen: Node, expected: Font, message: String) -> void:
	var message_label := Harness.find_node_by_name(screen, "DialogMessage") as Label
	_assert_true(message_label != null and message_label.get_theme_font("font") == expected, "%s (message)" % message)
	for button in _buttons(screen):
		_assert_true(button.get_theme_font("font") == expected, "%s (%s)" % [message, button.name])


func _click(at: Vector2) -> void:
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = at
		click.global_position = at
		click.pressed = pressed
		root.push_input(click)


func _press_key(keycode: Key, shift: bool = false) -> void:
	for pressed in [true, false]:
		var key := InputEventKey.new()
		key.keycode = keycode
		key.physical_keycode = keycode
		key.shift_pressed = shift
		key.pressed = pressed
		root.push_input(key)


func _press_escape() -> void:
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.physical_keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	var release := escape.duplicate() as InputEventKey
	release.pressed = false
	root.push_input(release)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	Harness.publish_title_facts(0, false)
	var theme: GameUiTheme = GameUiThemeScript.new()
	theme.configure({"locale_translate": func(source: String) -> String: return "[%s]" % source})
	RegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	var host := Node.new()
	host.name = "LayerHost"
	root.add_child(host)
	var canvas := CanvasLayer.new()
	host.add_child(canvas)
	var layer := Control.new()
	layer.name = "UIRoot"
	layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(layer)
	var manager: ScreenManager = ScreenManagerScript.new(GameEventBusScript.new(), DialogScreenScript, host)
	manager.name = "DialogManager"
	host.add_child(manager)
	RegistryScript.bind(ServiceKeysScript.DIALOG, manager)
	return {"host": host, "layer": layer, "manager": manager, "theme": theme, "screen_ref": []}


func _dispose(mounted: Dictionary) -> void:
	var host: Node = mounted["host"]
	if is_instance_valid(host):
		host.free()
	RegistryScript.clear()


func _dialog() -> ScreenManager:
	return RegistryScript.resolve(ServiceKeysScript.DIALOG) as ScreenManager


func _buttons(screen: Node) -> Array[Button]:
	var found: Array[Button] = []
	var row := Harness.find_node_by_name(screen, "DialogButtonRow")
	if row == null:
		return found
	for child in row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


func _label_text(screen: Node, node_name: String) -> String:
	var label := Harness.find_node_by_name(screen, node_name) as Label
	return label.text if label != null else ""


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
