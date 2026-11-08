@tool
class_name DialogDebugPanel
extends PaletteSceneRoot
## Debug-build title corner panel for checking the title by hand: each button opens a sample dialog
## with one, two or three buttons, and the log names the button that was pressed.
## The save simulation overrides only the has_save model, so START can be checked with and without a save;
## it never writes the save file. It shows the actual save beside it.
## It also shows, live, how many seconds START has been held (the start_hold_seconds model).

const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const SaveSlotScript = preload("res://scripts/game/save_slot.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const SAMPLE_BUTTON_TEXTS := ["确定", "取消", "稍后"]
const SAVE_FOLLOW := "follow"
const SAVE_SIMULATED := "simulated"
const SAVE_EMPTY := "empty"
const SAVE_BUTTONS := {
	SAVE_FOLLOW: "DialogDebugSaveFollowButton",
	SAVE_SIMULATED: "DialogDebugSaveYesButton",
	SAVE_EMPTY: "DialogDebugSaveNoButton",
}

var _save_slot: SaveSlotScript
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.START_HOLD_SECONDS: _on_start_held,
})


## The save file the panel reads to show and follow the actual save.
func configure(save_slot: SaveSlotScript) -> void:
	_save_slot = save_slot


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	for count in [1, 2, 3]:
		var opener := get_node_or_null("%%DialogDebugOpen%dButton" % count) as BaseButton
		if opener != null:
			opener.pressed.connect(_open_sample.bind(count))
	for mode in SAVE_BUTTONS.keys():
		var choice := _save_button(mode)
		if choice != null:
			choice.pressed.connect(_simulate_save.bind(mode))
	_show_save_choice(SAVE_FOLLOW)
	_watch.start()
	var theme := GameUiThemeScript.bound()
	if theme != null:
		apply_palette(theme.active_palette())


func _open_sample(count: int) -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.DIALOG):
		return
	var dialog := ServiceRegistryScript.resolve(ServiceKeysScript.DIALOG) as ScreenManager
	var buttons: Array = []
	for index in count:
		buttons.append({
			DialogScreenScript.KEY_TEXT: SAMPLE_BUTTON_TEXTS[index],
			DialogScreenScript.KEY_CALLBACK: _report.bind(count, index + 1),
		})
	var spec := {
		DialogScreenScript.KEY_MESSAGE: "这是 %d 个按钮的范例对话框。" % count,
		DialogScreenScript.KEY_BUTTONS: buttons,
		DialogScreenScript.KEY_OWNER: self,
	}
	# The one-button sample has no cancel button, so Escape does nothing there.
	if count > 1:
		spec[DialogScreenScript.KEY_CANCEL_INDEX] = count - 1
	dialog.open(spec)


func _report(count: int, pressed: int) -> void:
	var line := "%d 键范例：按下第 %d/%d 键" % [count, pressed, count]
	print("[DialogDebugPanel] %s" % line)
	var log := get_node_or_null("%DialogDebugLog") as Label
	if log != null:
		log.text = line


## A debug tool, not a player action, so it writes the model itself instead of raising an intent.
func _simulate_save(mode: String) -> void:
	_show_save_choice(mode)
	var has_save := GameModelsScript.value(PropertyKeysScript.HAS_SAVE)
	if has_save == null:
		return
	match mode:
		SAVE_SIMULATED:
			has_save.write(true)
		SAVE_EMPTY:
			has_save.write(false)
		_:
			has_save.write(_actual_save())


func _show_save_choice(mode: String) -> void:
	for each in SAVE_BUTTONS.keys():
		var choice := _save_button(each)
		if choice != null:
			choice.set_pressed_no_signal(each == mode)
	var actual := get_node_or_null("%DialogDebugSaveActual") as Label
	if actual != null:
		actual.text = "实际存档：有" if _actual_save() else "实际存档：无"


func _on_start_held(value: Variant) -> void:
	var held := get_node_or_null("%DialogDebugHoldTime") as Label
	if held != null:
		held.text = "START 按住：%.2f 秒" % float(value)


func _actual_save() -> bool:
	return _save_slot != null and _save_slot.has_progress()


func _save_button(mode: String) -> BaseButton:
	return get_node_or_null("%" + str(SAVE_BUTTONS[mode])) as BaseButton
