class_name PropertyModel
extends RefCounted
## One named value and the listeners watching it.
## Registering delivers the current value once, then again whenever it changes.

signal changed(value: Variant)

var property_name := ""
var _initial: Variant
var _value: Variant


func _init(property_name: String, initial_value: Variant) -> void:
	self.property_name = property_name
	_initial = _copy(initial_value)
	_value = _copy(initial_value)


func read() -> Variant:
	return _copy(_value)


func reset() -> void:
	_commit(_copy(_initial))


func register(listener: Callable) -> void:
	if listener.is_null():
		push_error("Property '%s' listener is empty" % property_name)
		return
	if changed.is_connected(listener):
		push_error("Property '%s' listener is already registered" % property_name)
		return
	changed.connect(listener)
	listener.call(read())


func unregister(listener: Callable) -> void:
	if listener.is_null() or not changed.is_connected(listener):
		return
	changed.disconnect(listener)


func _commit(next: Variant) -> void:
	if next == _value:
		return
	_value = next
	changed.emit(read())


func _copy(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value
