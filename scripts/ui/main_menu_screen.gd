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
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _observing := false


func present(_context: Dictionary) -> void:
	_stop_observing()
	_start_observing()


func dismiss() -> void:
	_stop_observing()


func _exit_tree() -> void:
	_stop_observing()


func _start_observing() -> void:
	if _observing:
		return
	var pollution := _property_model(PropertyKeysScript.POLLUTION)
	var has_save := _property_model(PropertyKeysScript.HAS_SAVE)
	if pollution == null or has_save == null:
		return
	pollution.register(_on_pollution)
	has_save.register(_on_has_save)
	_observing = true


func _stop_observing() -> void:
	if not _observing:
		return
	_observing = false
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	var pollution := _property_model(PropertyKeysScript.POLLUTION)
	var has_save := _property_model(PropertyKeysScript.HAS_SAVE)
	if pollution != null:
		pollution.unregister(_on_pollution)
	if has_save != null:
		has_save.unregister(_on_has_save)


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


func _property_model(property_name: String) -> PropertyModel:
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		push_error("Main menu cannot see the property service")
		return null
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)
