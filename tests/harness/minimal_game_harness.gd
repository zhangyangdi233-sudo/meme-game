extends RefCounted
## Shared helpers for module-only tests: MemeGameState setup and Control-tree probes.

const StateScript = preload("res://scripts/meme_game_state.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")


static func new_state() -> RefCounted:
	var state := StateScript.new()
	state.new_run()
	return state


static func find_node_by_name(node: Node, wanted_name: String) -> Node:
	if node == null:
		return null
	if node.name == wanted_name:
		return node
	for child in node.get_children():
		var found := find_node_by_name(child, wanted_name)
		if found != null:
			return found
	return null


## Names every retired guide or test aid still found under `game_root`: the doll guide window, the
## playtest panel, the tower app, TEST floating words in the 3D street or TEST text in the UI.
static func guidance_leftovers(game_root: Node) -> Array[String]:
	var found: Array[String] = []
	for retired_name in ["DollGuideOverlay", "DollGuidePanel", "PlaytestAssistPanel", "PlaytestAssistPanelHost",
			"BabelAppWindow", "BabelAppPanel", "PhoneAppIconBabel"]:
		if find_node_by_name(game_root, retired_name) != null:
			found.append(retired_name)
	for node in game_root.find_children("*", "Label3D", true, false):
		var label := node as Label3D
		if label.name == "PlaytestMarker" or label.text.contains("TEST"):
			found.append("%s (%s)" % [label.name, label.text])
	if collect_control_text(game_root).contains("TEST"):
		found.append("TEST text in the UI")
	return found


## The open Dialog's buttons from left to right, skipping ones already queued for deletion.
static func dialog_buttons(screen: Node) -> Array[Button]:
	var found: Array[Button] = []
	var row := find_node_by_name(screen, "DialogButtonRow")
	if row == null:
		return found
	for child in row.get_children():
		if child is Button and not child.is_queued_for_deletion():
			found.append(child as Button)
	return found


## Pushes an Escape press and release into the viewport.
static func press_escape(viewport: Viewport) -> void:
	for pressed in [true, false]:
		var escape := InputEventKey.new()
		escape.keycode = KEY_ESCAPE
		escape.physical_keycode = KEY_ESCAPE
		escape.pressed = pressed
		viewport.push_input(escape)


static func collect_control_text(root: Node) -> String:
	var result := ""
	if root is Label or root is Button or root is RichTextLabel or root is LineEdit:
		result += str(root.get("text")) + "\n"
	for child in root.get_children():
		result += collect_control_text(child)
	return result


static func craft_token(
	token_id: String,
	text: String,
	role: String,
	phone_surface: String,
	doctor_surface: String,
	lexeme_id: String = ""
) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": lexeme_id if not lexeme_id.is_empty() else "test.%s" % token_id,
		"grammar_roles": [role],
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": text,
		"tags": ["test"],
		"rarity": 1,
	}


static func publish_title_facts(pollution_value: int, has_save: bool) -> void:
	PropertyBootScript.install()
	var manager: PropertyManager = ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return
	var pollution: ValuePropertyModel = manager.model(PropertyKeysScript.POLLUTION) as ValuePropertyModel
	var saved: ValuePropertyModel = manager.model(PropertyKeysScript.HAS_SAVE) as ValuePropertyModel
	if pollution != null:
		pollution.write(pollution_value)
	if saved != null:
		saved.write(has_save)


## Switches the game language the way the language picker does: by writing the locale model.
static func write_locale(locale_code: String) -> void:
	PropertyBootScript.install()
	var manager: PropertyManager = ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager != null:
		manager.model(PropertyKeysScript.LOCALE).write(locale_code)


## Binds a fresh UI theme painted from `palette_key`, replacing any bound theme.
static func bind_ui_theme(palette_key: String) -> GameUiTheme:
	var stage := {"palette_key": palette_key}
	var theme := GameUiThemeScript.new() as GameUiTheme
	theme.configure({"pollution_stage": func() -> Dictionary: return stage})
	if ServiceRegistryScript.has(ServiceKeysScript.UI_THEME):
		ServiceRegistryScript.unbind(ServiceKeysScript.UI_THEME, ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME))
	ServiceRegistryScript.bind(ServiceKeysScript.UI_THEME, theme)
	return theme
