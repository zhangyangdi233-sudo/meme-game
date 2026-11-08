class_name FlowState
extends RefCounted
## One outer-flow state. Game implements this; Framework only calls enter, exit, and input.

var id := ""


func enter() -> void:
	pass


func exit() -> void:
	pass


func handle_input(_event: InputEvent) -> void:
	pass
