@tool
class_name MainMenuScreen
extends UIBase
## Title layout. Opening watches pollution and has_save; closing stops.
## Palette and what START raises are computed here. They are not models.
## START continues when a save exists and starts a new game otherwise.
## With a save, holding START (mouse, or a confirm key or pad button on a focused START) for HOLD_SECONDS opens
## the restart dialog right away; that hold's release raises nothing. A shorter hold is a plain press.
## Without a save the hold never opens the dialog and its release starts a new game.
## With a save, a ring fills clockwise while START is held: around the cursor for a mouse hold (following it),
## on START's center for a key or pad hold. It hides, empty, on release or once the dialog opens.
## The hint above START shows only with a save, pale until START is hovered or focused.
## While open the hint follows the language in that language's formal font (LocaleFont), not the pixel font.


const SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LAYER_NAME := "UIRoot"
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const START_BUTTON := "MainMenuStartButton"
const HINT_LABEL := "MainMenuHoldHint"
const HOLD_RING := "MainMenuHoldRing"
const BUTTON_INTENTS := {
	START_BUTTON: UiIntentsScript.START_GAME,
	"MainMenuExitButton": UiIntentsScript.EXIT_GAME,
	"MainMenuLanguageButton": UiIntentsScript.LANGUAGE_PICKER,
}
const HOLD_SECONDS := 1.2
## UI catalog source keys of the restart dialog.
const RESTART_QUESTION := "确定要重新开始游戏吗？"
const RESTART_YES := "是"
const RESTART_NO := "否"
## The hint's look, sampled from the art mock (Restart_prompt_uc / _c) until art sends final values.
## Fixed colors, not palette roles. The pixel font set in the scene is only the editor's stand-in for the locale font.
const HINT_COLOR_IDLE := Color("8d303880")
const HINT_COLOR_ACTIVE := Color("8f2f37")

const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const LocaleFontScript = preload("res://scripts/ui/locale_font.gd")
const HoldRingScript = preload("res://scripts/ui/hold_ring.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.POLLUTION: _on_pollution,
	PropertyKeysScript.HAS_SAVE: _on_has_save,
	PropertyKeysScript.LOCALE: _on_locale,
})
var _saved := false
var _holding := false
var _held_seconds := 0.0
## The current press already opened the restart dialog, so its release raises nothing.
var _hold_fired := false
var _start_hovered := false
var _start_focused := false
## The press that started the current hold was the left mouse button, so the ring follows `_cursor` instead of sitting on START.
var _held_by_mouse := false
var _cursor := Vector2.ZERO


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var start := _start_button()
	if start == null:
		return
	start.gui_input.connect(_on_start_input)
	start.button_down.connect(_on_start_down)
	start.button_up.connect(_on_start_up)
	start.mouse_entered.connect(_on_start_hover.bind(true))
	start.mouse_exited.connect(_on_start_hover.bind(false))
	start.focus_entered.connect(_on_start_focus.bind(true))
	start.focus_exited.connect(_on_start_focus.bind(false))
	_paint_hint()


func present(_context: Dictionary) -> void:
	_watch.stop()
	_watch.start()
	var hint := _hint()
	var theme := GameUiThemeScript.bound()
	if hint != null and theme != null:
		theme.set_localized_property(hint, "text")


func dismiss() -> void:
	_watch.stop()
	_end_hold()


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		super._process(delta)
		return
	if not _holding:
		return
	_held_seconds += delta
	_write_held(_held_seconds)
	if _saved and not _hold_fired and _held_seconds >= HOLD_SECONDS:
		_hold_fired = true
		_open_restart_dialog()
	_paint_ring()


func _on_pollution(value: Variant) -> void:
	var stage: Dictionary = PollutionStageScript.stage(int(value))
	apply_palette(UiPaletteScript.palette(str(stage.get("palette_key", "palette_1"))))


func _on_has_save(value: Variant) -> void:
	_saved = bool(value)
	var hint := _hint()
	if hint != null:
		hint.visible = _saved


func _on_locale(value: Variant) -> void:
	var hint := _hint()
	if hint != null:
		hint.add_theme_font_override("font", LocaleFontScript.font(str(value)))


func _intent_for(button_name: String, intent_name: String) -> String:
	if button_name != START_BUTTON:
		return intent_name
	if _hold_fired:
		return ""
	if _saved:
		return UiIntentsScript.CONTINUE_GAME
	return intent_name


## The signal comes before the button's own handling, so the press's source is known by `button_down`.
## Only a press before the hold starts picks the source; a wheel turn or a key during the hold leaves the ring where it is.
## While pressed by mouse the button keeps the mouse, so motion off START still arrives here.
func _on_start_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_cursor = _start_button().get_global_transform() * (event as InputEventMouse).position
	if _holding or not event.is_pressed():
		return
	var mouse := event as InputEventMouseButton
	_held_by_mouse = mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT


func _on_start_down() -> void:
	_hold_fired = false
	_holding = true
	_held_seconds = 0.0
	set_process(true)
	_paint_ring()


func _on_start_up() -> void:
	_end_hold()


## Release comes after the press it ends, so clearing `_hold_fired` here cannot let that press through.
func _end_hold() -> void:
	_holding = false
	_hold_fired = false
	_held_seconds = 0.0
	set_process(false)
	_write_held(0.0)
	_paint_ring()


func _open_restart_dialog() -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.DIALOG):
		return
	var dialog := ServiceRegistryScript.resolve(ServiceKeysScript.DIALOG) as ScreenManager
	dialog.open({
		DialogScreenScript.KEY_MESSAGE: RESTART_QUESTION,
		DialogScreenScript.KEY_BUTTONS: [
			{DialogScreenScript.KEY_TEXT: RESTART_YES, DialogScreenScript.KEY_CALLBACK: _restart},
			{DialogScreenScript.KEY_TEXT: RESTART_NO},
		],
		DialogScreenScript.KEY_CANCEL_INDEX: 1,
		DialogScreenScript.KEY_OWNER: self,
	})


func _restart() -> void:
	GameEventBus.raise(UiIntentsScript.RESTART_REQUESTED)


## How long START has been held, for the debug panel; zero when it is not held.
func _write_held(seconds: float) -> void:
	var held := GameModelsScript.value(PropertyKeysScript.START_HOLD_SECONDS)
	if held != null:
		held.write(seconds)


## Tracked from the signals: while they are emitted the button's own hover and focus state may not have changed yet.
func _on_start_hover(hovered: bool) -> void:
	_start_hovered = hovered
	_paint_hint()


func _on_start_focus(focused: bool) -> void:
	_start_focused = focused
	_paint_hint()


## Shown only while a hold with a save can still open the dialog. Progress is the debug panel's held seconds over HOLD_SECONDS.
func _paint_ring() -> void:
	var ring := _ring()
	if ring == null:
		return
	ring.visible = _holding and _saved and not _hold_fired
	ring.progress = _held_seconds / HOLD_SECONDS if ring.visible else 0.0
	if not ring.visible:
		return
	if _held_by_mouse:
		ring.center_at(_cursor)
		return
	var start := _start_button()
	if start != null:
		ring.center_at(start.get_global_rect().get_center())


## Dark while START shows its hover art (hovered or focused), pale otherwise.
func _paint_hint() -> void:
	var hint := _hint()
	if hint != null:
		hint.add_theme_color_override("font_color", HINT_COLOR_ACTIVE if _start_hovered or _start_focused else HINT_COLOR_IDLE)


func _start_button() -> BaseButton:
	return get_node_or_null("%" + START_BUTTON) as BaseButton


func _hint() -> Label:
	return get_node_or_null("%" + HINT_LABEL) as Label


func _ring() -> HoldRingScript:
	return get_node_or_null("%" + HOLD_RING) as HoldRingScript
