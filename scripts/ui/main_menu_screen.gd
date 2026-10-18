@tool
class_name MainMenuScreen
extends UIBase
## Title layout. Opening watches pollution and has_save; closing stops.
## Palette and what START raises are computed here. They are not models.
## START continues when a save exists and starts a new game otherwise.
## With a save, holding START (mouse, or a confirm key or pad button on a focused START) for HOLD_SECONDS opens
## the restart dialog right away; that hold's release raises nothing. A shorter hold is a plain press.
## Without a save the hold never opens the dialog and its release starts a new game.
## The hint above START shows only with a save, pale until START is hovered or focused.


const SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LAYER_NAME := "UIRoot"
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const START_BUTTON := "MainMenuStartButton"
const HINT_LABEL := "MainMenuHoldHint"
const BUTTON_INTENTS := {
	START_BUTTON: UiIntentsScript.START_GAME,
	"MainMenuExitButton": UiIntentsScript.EXIT_GAME,
	"MainMenuLanguageButton": UiIntentsScript.LANGUAGE_PICKER,
}
const HOLD_SECONDS := 0.8
## UI catalog source keys of the restart dialog.
const RESTART_QUESTION := "确定要重新开始游戏吗？"
const RESTART_YES := "是"
const RESTART_NO := "否"
## The hint's look, sampled from the art mock (Restart_prompt_uc / _c) until art sends final values.
## Fixed colors, not palette roles; the font is the menu's current pixel font.
const HINT_COLOR_IDLE := Color("8d303880")
const HINT_COLOR_ACTIVE := Color("8f2f37")
const HINT_FONT := preload("res://assets/fonts/BoutiqueBitmap9x9.ttf")

const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.POLLUTION: _on_pollution,
	PropertyKeysScript.HAS_SAVE: _on_has_save,
})
var _saved := false
var _holding := false
var _held_seconds := 0.0
## The current press already opened the restart dialog, so its release raises nothing.
var _hold_fired := false
var _start_hovered := false
var _start_focused := false


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	var start := _start_button()
	if start == null:
		return
	start.button_down.connect(_on_start_down)
	start.button_up.connect(_on_start_up)
	start.mouse_entered.connect(_on_start_hover.bind(true))
	start.mouse_exited.connect(_on_start_hover.bind(false))
	start.focus_entered.connect(_on_start_focus.bind(true))
	start.focus_exited.connect(_on_start_focus.bind(false))
	var hint := _hint()
	if hint != null:
		hint.add_theme_font_override("font", HINT_FONT)
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


func _on_pollution(value: Variant) -> void:
	var stage: Dictionary = PollutionStageScript.stage(int(value))
	apply_palette(UiPaletteScript.palette(str(stage.get("palette_key", "palette_1"))))


func _on_has_save(value: Variant) -> void:
	_saved = bool(value)
	var hint := _hint()
	if hint != null:
		hint.visible = _saved


func _intent_for(button_name: String, intent_name: String) -> String:
	if button_name != START_BUTTON:
		return intent_name
	if _hold_fired:
		return ""
	if _saved:
		return UiIntentsScript.CONTINUE_GAME
	return intent_name


func _on_start_down() -> void:
	_hold_fired = false
	_holding = true
	_held_seconds = 0.0
	set_process(true)


func _on_start_up() -> void:
	_end_hold()


## Release comes after the press it ends, so clearing `_hold_fired` here cannot let that press through.
func _end_hold() -> void:
	_holding = false
	_hold_fired = false
	_held_seconds = 0.0
	set_process(false)
	_write_held(0.0)


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


## Dark while START shows its hover art (hovered or focused), pale otherwise.
func _paint_hint() -> void:
	var hint := _hint()
	if hint != null:
		hint.add_theme_color_override("font_color", HINT_COLOR_ACTIVE if _start_hovered or _start_focused else HINT_COLOR_IDLE)


func _start_button() -> BaseButton:
	return get_node_or_null("%" + START_BUTTON) as BaseButton


func _hint() -> Label:
	return get_node_or_null("%" + HINT_LABEL) as Label
