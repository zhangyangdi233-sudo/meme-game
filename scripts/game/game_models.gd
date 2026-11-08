class_name GameModels
extends RefCounted
## The one way Game modules reach a value model and write the feedback line (ADR 0008).
## Installs the boot models first, so a handler or the language material works on an empty registry.

const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")


static func value(property_name: String) -> ValuePropertyModel:
	PropertyBootScript.install()
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name) as ValuePropertyModel


## The line the desk log shows after the last player action.
static func write_feedback(text: String) -> void:
	var model := value(PropertyKeysScript.FEEDBACK_TEXT)
	if model != null:
		model.write(text)
