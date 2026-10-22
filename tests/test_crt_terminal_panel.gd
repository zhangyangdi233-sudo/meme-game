extends SceneTree
## The basement CRT terminal's screen: a display of its own holding the social feed and the notebook, one at a time.
## It reads the same models and raises the same intents as the phone, so a word picked on either side shows on both.
## Its tabs and its exit raise their intents; the pointer reaches it as a UV on the CRT's glass.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameSocialFeedSourceScript = preload("res://scripts/game/game_social_feed_source.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const LocaleScript = preload("res://scripts/localization/game_locale.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const CrtTerminalPanelScript = preload("res://scripts/ui/crt_terminal_panel.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("crt terminal panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	await _test_the_display_shows_the_social_feed_first()
	await _test_a_tab_switches_the_app_and_raises_its_intent()
	await _test_the_exit_raises_its_intent()
	await _test_a_word_held_anywhere_shows_in_the_terminal_notebook()
	await _test_posting_from_the_terminal_raises_the_phone_intent()
	await _test_a_hidden_terminal_lets_go_of_the_models()


func _test_the_display_shows_the_social_feed_first() -> void:
	var panel = await _mount()
	var texture: Texture2D = panel.display_texture()
	_assert_true(texture != null, "the terminal should hand out its display")
	_assert_eq(Vector2(texture.get_size()), Vector2(CrtTerminalPanelScript.DISPLAY_SIZE), "the display should be the terminal's size")
	_assert_eq(panel.selected_app(), "social", "the terminal should open on the social feed")
	var social := _find(panel, "SocialAppWindow") as Control
	var notebook := _find(panel, "TerminalNotebookBody") as Control
	_assert_true(social != null and social.is_visible_in_tree(), "the social feed should show on the terminal")
	_assert_true(_find(social, "SocialChannelTabs") != null, "the terminal's social feed should be painted")
	_assert_true(notebook != null and not notebook.is_visible_in_tree(), "the notebook should wait behind its tab")
	_assert_true(_find(social, "SocialAppInlineCloseButton") == null, "the terminal's feed has no phone window to close")
	await _dispose(panel)


func _test_a_tab_switches_the_app_and_raises_its_intent() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	_assert_eq(panel.selected_app(), "notebook", "the notebook tab should switch the terminal to the notebook")
	_assert_true((_find(panel, "TerminalNotebookBody") as Control).is_visible_in_tree(), "the notebook should show")
	_assert_true(not (_find(panel, "SocialAppWindow") as Control).is_visible_in_tree(), "the social feed should hide")
	_assert_heard(UiIntentsScript.TERMINAL_APP_SELECTED, {UiIntentsScript.KEY_APP_ID: "notebook"}, "the notebook tab")
	await _click(panel, "TerminalAppSocial")
	_assert_eq(panel.selected_app(), "social", "the social tab should switch back")
	await _dispose(panel)


func _test_the_exit_raises_its_intent() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalExit")
	_assert_heard(UiIntentsScript.TERMINAL_EXIT_REQUESTED, {}, "the exit button")
	var heard_before := _heard.size()
	panel.push_pointer(_mouse_button(true), CrtScreen.MISS)
	panel.push_pointer(_mouse_button(false), CrtScreen.MISS)
	await process_frame
	_assert_eq(_heard.size(), heard_before, "a click off the glass should raise nothing")
	await _dispose(panel)


func _test_a_word_held_anywhere_shows_in_the_terminal_notebook() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	_model(PropertyKeysScript.COLLECTED_CHAR_UNITS).replace_all([{"unit": "门", "locale": "zh", "source_post_id": "floor_13", "day": 1}])
	await process_frame
	await process_frame
	var canvas := _find(panel, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null and canvas.has_tile("门"), "a word held on the phone should show on the terminal's notebook")
	await _dispose(panel)


func _test_posting_from_the_terminal_raises_the_phone_intent() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	_model(PropertyKeysScript.FREE_SENTENCE_UNITS).replace_all(["门"])
	await process_frame
	await process_frame
	await _click(panel, "NotebookCraftButton")
	_assert_heard(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}, "posting from the terminal")
	await _dispose(panel)


func _test_a_hidden_terminal_lets_go_of_the_models() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	panel.set_shown(false)
	_model(PropertyKeysScript.COLLECTED_CHAR_UNITS).replace_all([{"unit": "开", "locale": "zh", "source_post_id": "floor_13", "day": 1}])
	await process_frame
	await process_frame
	var canvas := _find(panel, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas == null or not canvas.has_tile("开"), "a hidden terminal should not repaint")
	panel.set_shown(true)
	await process_frame
	canvas = _find(panel, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null and canvas.has_tile("开"), "showing the terminal again should catch up with the models")
	await _dispose(panel)


func _mount():
	RegistryScript.clear()
	BootScript.install()
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	var game := Harness.new_state()
	var locale := LocaleScript.new()
	var material := LanguageMaterialScript.new()
	material.configure(game, locale)
	var source := GameSocialFeedSourceScript.new()
	source.configure(game, locale, material)
	RegistryScript.bind(ServiceKeysScript.SOCIAL_FEED_SOURCE, source)
	var panel = CrtTerminalPanelScript.new()
	panel.name = "CrtTerminalPanel"
	root.add_child(panel)
	panel.mount({
		"clear_children": func(node: Node) -> void:
			for child in node.get_children():
				node.remove_child(child)
				child.queue_free(),
		"current_locale": func() -> String: return "zh",
		"char_canvas_position": func(_unit: String, _locale_code: String) -> Vector2: return Vector2(40.0, 40.0),
	})
	panel.set_shown(true)
	await process_frame
	await process_frame
	return panel


## Clicks a control on the terminal's display through the CRT's glass: the pointer arrives as a UV.
func _click(panel, control_name: String) -> void:
	var control := _find(panel, control_name) as Control
	_assert_true(control != null and control.is_visible_in_tree(), "%s should be on the terminal to click" % control_name)
	if control == null:
		return
	var uv: Vector2 = control.get_global_rect().get_center() / Vector2(CrtTerminalPanelScript.DISPLAY_SIZE)
	var motion := InputEventMouseMotion.new()
	panel.push_pointer(motion, uv)
	panel.push_pointer(_mouse_button(true), uv)
	panel.push_pointer(_mouse_button(false), uv)
	await process_frame


func _mouse_button(pressed: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	return click


func _model(property_name: String) -> PropertyModel:
	return (RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager).model(property_name)


func _find(node: Node, wanted_name: String) -> Node:
	return Harness.find_node_by_name(node, wanted_name)


func _dispose(panel) -> void:
	panel.queue_free()
	await process_frame
	RegistryScript.clear()


func _assert_heard(intent_name: String, payload: Dictionary, label: String) -> void:
	for entry in _heard:
		if entry[0] == intent_name:
			_assert_eq(entry[1], payload, "%s should carry its answer" % label)
			return
	_failures.append("%s should raise %s; heard %s" % [label, intent_name, str(_heard)])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
