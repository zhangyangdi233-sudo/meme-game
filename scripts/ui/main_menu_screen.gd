@tool
class_name MainMenuScreen
extends UIBase
## Title layout. Opening watches pollution and has_save; closing stops.
## Palette and what START raises are computed here. They are not models.
## START continues when a save exists and starts a new game otherwise.


const SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LAYER_NAME := "UIRoot"
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const BUTTON_INTENTS := {
	"MainMenuStartButton": UiIntentsScript.START_GAME,
	"MainMenuExitButton": UiIntentsScript.EXIT_GAME,
	"MainMenuLanguageButton": UiIntentsScript.LANGUAGE_PICKER,
}

const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.POLLUTION: _on_pollution,
	PropertyKeysScript.HAS_SAVE: _on_has_save,
})
var _saved := false


func present(_context: Dictionary) -> void:
	_watch.stop()
	_watch.start()


func dismiss() -> void:
	_watch.stop()


func _on_pollution(value: Variant) -> void:
	var stage: Dictionary = PollutionStageScript.stage(int(value))
	apply_palette(UiPaletteScript.palette(str(stage.get("palette_key", "palette_1"))))


func _on_has_save(value: Variant) -> void:
	_saved = bool(value)


func _intent_for(button_name: String, intent_name: String) -> String:
	if button_name == "MainMenuStartButton" and _saved:
		return UiIntentsScript.CONTINUE_GAME
	return intent_name
