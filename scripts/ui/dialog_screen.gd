@tool
class_name DialogScreen
extends UIBase
## Generic dialog. Any panel resolves its screen manager (ServiceKeys.DIALOG) and opens it with a spec:
## `message` and each button `text` are UI catalog source keys; `buttons` holds 1 to 3 `{text, callback}` from left to right.
## A press closes the dialog first, then runs that button's callback with no arguments.
## `cancel_index` names the button Escape presses and the one focused on open; without it Escape does nothing
## and the first button takes the focus.
## An optional `owner` node leaving the tree closes the dialog without running any callback.
## While open it watches pollution and tints itself (`surface` / `ink` roles, buttons included) for the stage.
## While open it also watches the language and sets the language's formal font (LocaleFont), not the pixel font.
## Buttons look the same hovered as idle; the focused one is underlined in its text color.
## While open the full-screen root takes every click (it stays the last child of its layer, since GUI picking follows
## tree order), the focus stays on the dialog's buttons, and keys the dialog leaves unhandled never reach the game.
## One dialog at a time: an open while one is showing is refused with a warning and changes nothing.


const SCENE_PATH := "res://scenes/ui/dialog.tscn"
const LAYER_NAME := "UIRoot"
const BUTTON_INTENTS := {}
const KEY_MESSAGE := "message"
const KEY_BUTTONS := "buttons"
const KEY_TEXT := "text"
const KEY_CALLBACK := "callback"
const KEY_CANCEL_INDEX := "cancel_index"
const KEY_OWNER := "owner"
const MIN_BUTTONS := 1
const MAX_BUTTONS := 3
const FOCUS_UNDERLINE_WIDTH := 2

const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const LocaleFontScript = preload("res://scripts/ui/locale_font.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")

var _callbacks: Array[Callable] = []
var _open := false
var _cancel_index := -1
var _refocusing := false
var _owner_node: Node
## The theme authored in the scene; each language gets a copy of it, so the shared scene resource is never edited.
var _scene_theme: Theme
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.POLLUTION: _on_pollution,
	PropertyKeysScript.LOCALE: _on_locale,
})


func present(spec: Dictionary) -> void:
	if _open:
		push_warning("Dialog is already open; refused \"%s\"" % str(spec.get(KEY_MESSAGE, "")))
		return
	var entries: Array = spec.get(KEY_BUTTONS, [])
	if entries.size() < MIN_BUTTONS or entries.size() > MAX_BUTTONS:
		push_warning("Dialog needs %d to %d buttons, got %d; refused" % [MIN_BUTTONS, MAX_BUTTONS, entries.size()])
		visible = false
		return
	var message := get_node_or_null("%DialogMessage") as Label
	var row := get_node_or_null("%DialogButtonRow") as HBoxContainer
	if message == null or row == null:
		return
	_set_translated(message, str(spec.get(KEY_MESSAGE, "")))
	for old in row.get_children():
		row.remove_child(old)
		old.queue_free()
	_callbacks.clear()
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var button := Button.new()
		button.name = "DialogButton%d" % index
		_set_translated(button, str(entry.get(KEY_TEXT, "")))
		button.pressed.connect(_on_button_pressed.bind(index))
		row.add_child(button)
		var callback: Variant = entry.get(KEY_CALLBACK)
		_callbacks.append(callback if callback is Callable else Callable())
	_cancel_index = int(spec.get(KEY_CANCEL_INDEX, -1))
	if _cancel_index < 0 or _cancel_index >= _callbacks.size():
		_cancel_index = -1
	_watch_owner(spec.get(KEY_OWNER, null) as Node)
	_open = true
	_chain_focus(row)
	_watch.start()
	_hold_focus(true)
	_hold_top(true)
	_focus_default()


func _input(event: InputEvent) -> void:
	if not _open or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _cancel_index >= 0:
		_on_button_pressed(_cancel_index)


func _unhandled_input(event: InputEvent) -> void:
	if _open and event is InputEventKey:
		get_viewport().set_input_as_handled()


func dismiss() -> void:
	_close()


func _on_button_pressed(index: int) -> void:
	var callback := _callbacks[index]
	_close()
	if callback.is_null():
		return
	if not callback.is_valid():
		push_warning("Dialog button %d callback is no longer valid; skipped" % index)
		return
	callback.call()


func _close() -> void:
	_open = false
	_watch_owner(null)
	_watch.stop()
	_hold_focus(false)
	_hold_top(false)
	visible = false


func _watch_owner(owner_node: Node) -> void:
	if is_instance_valid(_owner_node) and _owner_node.tree_exiting.is_connected(_close):
		_owner_node.tree_exiting.disconnect(_close)
	_owner_node = owner_node
	if is_instance_valid(_owner_node):
		_owner_node.tree_exiting.connect(_close)


func _on_pollution(value: Variant) -> void:
	var stage: Dictionary = PollutionStageScript.stage(int(value))
	apply_palette(UiPaletteScript.palette(str(stage.get("palette_key", "palette_1"))))


## Assigns a new theme rather than editing the current one: assigning repaints at once, an edit only on a later frame.
func _on_locale(value: Variant) -> void:
	if _scene_theme == null:
		_scene_theme = theme if theme != null else Theme.new()
	var localized := _scene_theme.duplicate() as Theme
	localized.default_font = LocaleFontScript.font(str(value))
	theme = localized


## The shared button style, then hover made identical to idle and the focus mark made an underline.
func apply_palette(palette: Dictionary) -> void:
	super.apply_palette(palette)
	var row := get_node_or_null("%DialogButtonRow") as HBoxContainer
	if row == null:
		return
	for child in row.get_children():
		if child is Button:
			_quiet_button(child as Button)


func _quiet_button(button: Button) -> void:
	var ink := button.get_theme_color("font_color")
	button.add_theme_stylebox_override("hover", button.get_theme_stylebox("normal"))
	button.add_theme_color_override("font_hover_color", ink)
	var underline := StyleBoxFlat.new()
	underline.draw_center = false
	underline.border_color = ink
	underline.border_width_bottom = FOCUS_UNDERLINE_WIDTH
	button.add_theme_stylebox_override("focus", underline)


## Tab, shift-tab and the arrow keys wrap around the dialog's buttons instead of leaving the dialog.
func _chain_focus(row: HBoxContainer) -> void:
	var buttons := row.get_children()
	for index in buttons.size():
		var button := buttons[index] as Button
		var next := buttons[(index + 1) % buttons.size()].get_path()
		var previous := buttons[(index - 1 + buttons.size()) % buttons.size()].get_path()
		button.focus_next = next
		button.focus_neighbor_right = next
		button.focus_previous = previous
		button.focus_neighbor_left = previous
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()


func _hold_focus(hold: bool) -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var connected := viewport.gui_focus_changed.is_connected(_on_focus_changed)
	if hold and not connected:
		viewport.gui_focus_changed.connect(_on_focus_changed)
	elif not hold and connected:
		viewport.gui_focus_changed.disconnect(_on_focus_changed)


func _on_focus_changed(control: Control) -> void:
	if _open and not _refocusing and not is_ancestor_of(control):
		_refocusing = true
		_focus_default()
		_refocusing = false


## UI added to the layer while the dialog is open would come later in the tree and take clicks first; move back on top.
func _hold_top(hold: bool) -> void:
	var layer := get_parent()
	if layer == null:
		return
	var connected := layer.child_entered_tree.is_connected(_on_layer_child_entered)
	if hold:
		move_to_front()
		if not connected:
			layer.child_entered_tree.connect(_on_layer_child_entered)
	elif connected:
		layer.child_entered_tree.disconnect(_on_layer_child_entered)


func _on_layer_child_entered(child: Node) -> void:
	if _open and child != self:
		move_to_front.call_deferred()


func _focus_default() -> void:
	var row := get_node_or_null("%DialogButtonRow") as HBoxContainer
	if row == null or row.get_child_count() == 0:
		return
	(row.get_child(maxi(_cancel_index, 0)) as Button).grab_focus()


func _set_translated(control: Control, source: String) -> void:
	control.text = source
	var theme := GameUiThemeScript.bound()
	if theme != null:
		theme.set_localized_property(control, "text")
