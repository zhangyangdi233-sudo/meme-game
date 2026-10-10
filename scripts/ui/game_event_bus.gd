class_name GameEventBus
extends RefCounted
## Game-side intent bus. The host creates one, binds it as a service, and listens; screens only emit. Not an autoload.
## Intent names and their payload keys live in UiIntents.


signal intent_emitted(intent_name: String, payload: Dictionary)


func emit_intent(intent_name: String, payload: Dictionary = {}) -> void:
	intent_emitted.emit(intent_name, payload)
