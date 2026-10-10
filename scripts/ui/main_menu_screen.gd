@tool
class_name MainMenuScreen
extends UIBase
## Title layout. Opening watches pollution and has_save; closing stops.
## Palette and the continue button are computed here. They are not models.


const SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LAYER_NAME := "UIRoot"
const BUTTON_INTENTS := {
	"MainMenuStartButton": "start_game",
	"MainMenuContinueButton": "continue_game",
	"MainMenuExitButton": "exit_game",
	"MainMenuLanguageButton": "language_picker",
}

const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.POLLUTION: _on_pollution,
	PropertyKeysScript.HAS_SAVE: _on_has_save,
})


func present(_context: Dictionary) -> void:
	_watch.stop()
	_watch.start()


func dismiss() -> void:
	_watch.stop()


func _on_pollution(value: Variant) -> void:
	var stage: Dictionary = PollutionStageScript.stage(int(value))
	apply_palette(UiPaletteScript.palette(str(stage.get("palette_key", "palette_1"))))


func _on_has_save(value: Variant) -> void:
	var continue_button := get_node_or_null("%MainMenuContinueButton") as Button
	if continue_button == null:
		return
	var saved := bool(value)
	continue_button.disabled = not saved
	continue_button.tooltip_text = "回到上次离开的位置" if saved else "暂无自动存档"
