class_name MapPropertyModel
extends PropertyModel
## A map whose read() is a deep copy.
## add, remove, replace, and replace_all store a new copy and notify.


func add(key: Variant, value: Variant) -> void:
	var current := _value as Dictionary
	if current.has(key):
		push_error("Property '%s' already has '%s'" % [property_name, str(key)])
		return
	var next := current.duplicate(true)
	next[key] = _copy(value)
	_commit(next)


func remove(key: Variant) -> void:
	var current := _value as Dictionary
	if not current.has(key):
		push_error("Property '%s' has no '%s'" % [property_name, str(key)])
		return
	var next := current.duplicate(true)
	next.erase(key)
	_commit(next)


func replace(key: Variant, value: Variant) -> void:
	var current := _value as Dictionary
	if not current.has(key):
		push_error("Property '%s' has no '%s'" % [property_name, str(key)])
		return
	var next := current.duplicate(true)
	next[key] = _copy(value)
	_commit(next)


func replace_all(entries: Dictionary) -> void:
	_commit(_copy(entries))
