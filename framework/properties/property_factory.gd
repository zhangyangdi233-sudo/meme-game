class_name PropertyFactory
extends RefCounted
## Builds a model from the initial value's type.
## An array becomes a list, a dictionary becomes a map, and anything else becomes a single value.
## Bounds are forwarded to that single value. This script does not know game names.


static func create(property_name: String, initial_value: Variant, minimum: Variant = null, maximum: Variant = null) -> PropertyModel:
	if typeof(initial_value) == TYPE_ARRAY:
		return ListPropertyModel.new(property_name, initial_value)
	if typeof(initial_value) == TYPE_DICTIONARY:
		return MapPropertyModel.new(property_name, initial_value)
	return ValuePropertyModel.new(property_name, initial_value, minimum, maximum)
