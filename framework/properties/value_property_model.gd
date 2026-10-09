class_name ValuePropertyModel
extends PropertyModel
## A single value locked to the type of its initial value.
## Optional bounds clamp ints and floats. A wrong type is rejected.


var _value_type := TYPE_NIL
var _has_bounds := false
var _minimum: Variant
var _maximum: Variant


func _init(property_name: String, initial_value: Variant, minimum: Variant = null, maximum: Variant = null) -> void:
	super(property_name, initial_value)
	_value_type = typeof(initial_value)
	if minimum != null and maximum != null and (_value_type == TYPE_INT or _value_type == TYPE_FLOAT):
		_has_bounds = true
		_minimum = minimum
		_maximum = maximum
		var clamped: Variant = _clamp(initial_value)
		_initial = clamped
		_value = clamped


func write(next: Variant) -> void:
	if typeof(next) != _value_type:
		push_error("Property '%s' rejected %s and kept the previous value" % [property_name, type_string(typeof(next))])
		return
	var stored: Variant = next
	if _has_bounds:
		stored = _clamp(next)
	_commit(stored)


func _clamp(next: Variant) -> Variant:
	if typeof(next) == TYPE_INT:
		return clampi(int(next), int(_minimum), int(_maximum))
	return clampf(float(next), float(_minimum), float(_maximum))
