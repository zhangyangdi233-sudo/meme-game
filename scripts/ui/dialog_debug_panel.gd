@tool
class_name DialogDebugPanel
extends PaletteSceneRoot
## Debug-build title corner panel for checking the Dialog by hand: each button opens a sample dialog
## with one, two or three buttons, and the log names the button that was pressed.

const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const SAMPLE_BUTTON_TEXTS := ["确定", "取消", "稍后"]


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	for count in [1, 2, 3]:
		var opener := get_node_or_null("%%DialogDebugOpen%dButton" % count) as BaseButton
		if opener != null:
			opener.pressed.connect(_open_sample.bind(count))
	var theme := GameUiThemeScript.bound()
	if theme != null:
		apply_palette(theme.active_palette())


func _open_sample(count: int) -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.DIALOG):
		return
	var dialog := ServiceRegistryScript.resolve(ServiceKeysScript.DIALOG) as ScreenManager
	var buttons: Array = []
	for index in count:
		buttons.append({"text": SAMPLE_BUTTON_TEXTS[index], "callback": _report.bind(count, index + 1)})
	var spec := {
		"message": "这是 %d 个按钮的范例对话框。" % count,
		"buttons": buttons,
		"owner": self,
	}
	# The one-button sample has no cancel button, so Escape does nothing there.
	if count > 1:
		spec["cancel_index"] = count - 1
	dialog.open(spec)


func _report(count: int, pressed: int) -> void:
	var line := "%d 键范例：按下第 %d/%d 键" % [count, pressed, count]
	print("[DialogDebugPanel] %s" % line)
	var log := get_node_or_null("%DialogDebugLog") as Label
	if log != null:
		log.text = line
