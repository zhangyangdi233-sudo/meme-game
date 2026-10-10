class_name GameEventBus
extends RefCounted
## Game-side intent bus. The host creates one, binds it as a service, and listens; screens only emit. Not an autoload.
## Intent names and their payload keys live in UiIntents.

const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")


signal intent_emitted(intent_name: String, payload: Dictionary)


## A control built at runtime raises its action on the bound bus; with no bus bound there is no host to hear it.
static func raise(intent_name: String, payload: Dictionary = {}) -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.UI_EVENT_BUS):
		return
	var bus := ServiceRegistryScript.resolve(ServiceKeysScript.UI_EVENT_BUS) as GameEventBus
	if bus != null:
		bus.emit_intent(intent_name, payload)


func emit_intent(intent_name: String, payload: Dictionary = {}) -> void:
	intent_emitted.emit(intent_name, payload)
