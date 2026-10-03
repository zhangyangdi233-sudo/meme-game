@tool
class_name MainMenuScreen
extends UIBase
## Title layout. The screen manager reads these constants; this script does not wire buttons.


const SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LAYER_NAME := "UIRoot"
const BUTTON_INTENTS := {
	"MainMenuStartButton": "start_game",
	"MainMenuContinueButton": "continue_game",
	"MainMenuExitButton": "exit_game",
	"MainMenuLanguageButton": "language_picker",
}


func present(context: Dictionary) -> void:
	var palette: Dictionary = context.get("palette", {})
	if not palette.is_empty():
		apply_palette(palette)
	var continue_button := get_node_or_null("%MainMenuContinueButton") as Button
	if continue_button == null:
		return
	var has_save := bool(context.get("has_save", false))
	continue_button.disabled = not has_save
	continue_button.tooltip_text = "回到上次离开的位置" if has_save else "暂无自动存档"
