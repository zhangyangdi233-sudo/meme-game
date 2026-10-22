class_name CrtTerminalPanel
extends Node
## The basement CRT terminal's screen: a display of its own (a SubViewport the host hands to the CRT's glass) with the
## Layout scene `scenes/ui/crt_terminal.tscn` for its chrome, and its own social feed and notebook, one at a time.
## They watch the same models and raise the same intents as the phone, so the held words, the sentence and the world
## rules are one copy. Which app shows is this screen's own view. Its tabs and its exit raise their intents.
## The pointer arrives as a UV on the glass; the panel turns it into a point on its display.

const LAYOUT_SCENE := preload("res://scenes/ui/crt_terminal.tscn")
const NotebookAppPanelScript = preload("res://scripts/ui/notebook_app_panel.gd")
const SocialFeedPanelScript = preload("res://scripts/ui/social_feed_panel.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")

const DISPLAY_SIZE := Vector2i(960, 720)
const APPS: Array[String] = ["social", "notebook"]
const DEFAULT_APP := "social"
## The feed and the open post sit side by side below the toolbar.
const APP_TOP := 76.0
const APP_MARGIN := 12.0
## Where a pointer that left the glass is sent, so nothing on the display stays hovered.
const OFF_DISPLAY := Vector2(-100, -100)

var _viewport: SubViewport
var _screen: PaletteSceneRoot
var _apps: Control
var _social: SocialFeedPanel
var _notebook: NotebookAppPanel
var _notebook_body: VBoxContainer
var _tabs: Dictionary = {}
var _app := DEFAULT_APP
var _shown := false
## The feed is painted the first time the terminal is entered, not while it waits unseen.
var _social_painted := false
var _held_buttons: Array[MouseButton] = []
var _last_point := OFF_DISPLAY


## Builds the display once. `notebook_deps` are the notebook's own (`NotebookAppPanel.configure`).
func mount(notebook_deps: Dictionary) -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.name = "CrtTerminalDisplay"
	_viewport.size = DISPLAY_SIZE
	_viewport.disable_3d = true
	_viewport.handle_input_locally = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_screen = LAYOUT_SCENE.instantiate() as PaletteSceneRoot
	_viewport.add_child(_screen)
	_screen.apply_palette(_theme().active_palette())
	_tabs = {
		"social": _screen.find_child("TerminalAppSocial", true, false) as Button,
		"notebook": _screen.find_child("TerminalAppNotebook", true, false) as Button,
	}
	for app_id in _tabs:
		(_tabs[app_id] as Button).pressed.connect(_on_tab_pressed.bind(app_id))
	(_screen.find_child("TerminalExit", true, false) as Button).pressed.connect(_on_exit_pressed)

	_apps = Control.new()
	_apps.name = "TerminalApps"
	_apps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apps.position = Vector2(APP_MARGIN, APP_TOP)
	_apps.size = Vector2(DISPLAY_SIZE) - Vector2(APP_MARGIN * 2.0, APP_TOP + APP_MARGIN)
	_viewport.add_child(_apps)

	_social = SocialFeedPanelScript.new()
	_social.name = "TerminalSocialFeedPanel"
	add_child(_social)
	_social.mount(_apps, false)
	var half_width := (_apps.size.x - APP_MARGIN) * 0.5
	_fit(_social.get_app_window(), Rect2(Vector2.ZERO, Vector2(half_width, _apps.size.y)))
	_fit(_social.get_detail_window(), Rect2(Vector2(half_width + APP_MARGIN, 0.0), Vector2(half_width, _apps.size.y)))

	_notebook_body = VBoxContainer.new()
	_notebook_body.name = "TerminalNotebookBody"
	_fit(_notebook_body, Rect2(Vector2.ZERO, _apps.size))
	_apps.add_child(_notebook_body)
	_notebook = NotebookAppPanelScript.new()
	_notebook.name = "TerminalNotebookAppPanel"
	add_child(_notebook)
	_notebook.configure(notebook_deps)
	_notebook.render(_notebook_body)
	_show_app()


## What the CRT's glass shows.
func display_texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null


func selected_app() -> String:
	return _app


## The terminal is in use: its apps watch the models and its display renders and takes the pointer.
func set_shown(shown: bool) -> void:
	if _viewport == null or _shown == shown:
		return
	_shown = shown
	_viewport.gui_disable_input = not shown
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if shown:
		# The chrome is worded in the current language each time the terminal is entered.
		_theme().localize_control_tree(_screen)
	else:
		_release_pointer()
	_show_app()


## A mouse event that reached the CRT, at `uv` on its glass (top-left origin), or `CrtScreen.MISS` off it.
## A button held when the pointer left the glass is still released, away from every control.
func push_pointer(event: InputEventMouse, uv: Vector2) -> void:
	if not _shown or event == null:
		return
	var on_glass := uv != CrtScreen.MISS
	var button := event as InputEventMouseButton
	if not on_glass:
		if button != null and not button.pressed and _held_buttons.has(button.button_index):
			_held_buttons.erase(button.button_index)
			_send(event, OFF_DISPLAY)
		elif event is InputEventMouseMotion:
			_send(event, OFF_DISPLAY)
		return
	if button != null and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if button.pressed:
			if not _held_buttons.has(button.button_index):
				_held_buttons.append(button.button_index)
		else:
			_held_buttons.erase(button.button_index)
	_send(event, uv * Vector2(DISPLAY_SIZE))


func _send(event: InputEventMouse, point: Vector2) -> void:
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = point
	forwarded.global_position = point
	if forwarded is InputEventMouseMotion:
		(forwarded as InputEventMouseMotion).relative = point - _last_point
	_last_point = point
	_viewport.push_input(forwarded, true)


## Leaving lets go of every held button away from the controls, so no button fires on the way out.
func _release_pointer() -> void:
	var held := _held_buttons.duplicate()
	_held_buttons.clear()
	_send(InputEventMouseMotion.new(), OFF_DISPLAY)
	for held_button in held:
		var release := InputEventMouseButton.new()
		release.button_index = held_button
		release.pressed = false
		_send(release, OFF_DISPLAY)
	_viewport.gui_release_focus()


func _show_app() -> void:
	var social_shown := _shown and _app == "social"
	if social_shown and not _social_painted:
		_social_painted = true
		_social.render_app()
		_theme().apply_ui_theme(_social.get_app_window())
	var notebook_shown := _shown and _app == "notebook"
	_social.get_app_window().visible = social_shown
	_social.update_visibility(social_shown, social_shown)
	_notebook_body.visible = notebook_shown
	_notebook.set_shown(notebook_shown)
	for app_id in _tabs:
		(_tabs[app_id] as Button).set_pressed_no_signal(app_id == _app)


func _on_tab_pressed(app_id: String) -> void:
	_app = app_id
	_show_app()
	GameEventBus.raise(UiIntentsScript.TERMINAL_APP_SELECTED, {UiIntentsScript.KEY_APP_ID: app_id})


func _on_exit_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.TERMINAL_EXIT_REQUESTED)


func _fit(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.custom_minimum_size = Vector2.ZERO
	control.position = rect.position
	control.size = rect.size
	control.clip_contents = true


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
