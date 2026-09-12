extends "res://framework/flow/flow_state.gd"
## Test double that records enter, exit, and input for FlowManager.

var log: Array[String] = []
var inputs: Array = []


func _init(p_id: String, p_log: Array[String]) -> void:
	id = p_id
	log = p_log


func enter() -> void:
	log.append("%s:enter" % id)


func exit() -> void:
	log.append("%s:exit" % id)


func handle_input(event: InputEvent) -> void:
	inputs.append(event)
	log.append("%s:input" % id)
