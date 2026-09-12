class_name FlowManager
extends RefCounted
## Injects FlowState objects, transitions (exit then enter), forwards input to the current state, and exposes current identity.

var _states: Dictionary = {}
var _current: FlowState = null


func register(state: FlowState) -> void:
	if state == null or state.id.is_empty():
		return
	_states[state.id] = state


func has(id: String) -> bool:
	return _states.has(id)


func current_id() -> String:
	if _current == null:
		return ""
	return _current.id


func handle_input(event: InputEvent) -> void:
	if _current == null:
		return
	_current.handle_input(event)


func transition_to(id: String) -> bool:
	if not _states.has(id):
		return false
	if _current != null:
		_current.exit()
	_current = _states[id]
	_current.enter()
	return true
