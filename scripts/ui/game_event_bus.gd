class_name GameEventBus
extends RefCounted
## Game-side intent bus. The host creates one and listens; screens only emit. Not an autoload.


signal intent_emitted(intent_name: String)


func emit_intent(intent_name: String) -> void:
	intent_emitted.emit(intent_name)
