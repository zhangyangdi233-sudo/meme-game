class_name ListPropertyModel
extends PropertyModel
## A list whose read() is a deep copy.
## add, remove_at, and replace_at store a new copy and notify.


func add(item: Variant) -> void:
	var next: Array = (_value as Array).duplicate(true)
	next.append(_copy(item))
	_commit(next)


func remove_at(index: int) -> void:
	var current := _value as Array
	if index < 0 or index >= current.size():
		push_error("Property '%s' has no index %d" % [property_name, index])
		return
	var next: Array = current.duplicate(true)
	next.remove_at(index)
	_commit(next)


func replace_at(index: int, item: Variant) -> void:
	var current := _value as Array
	if index < 0 or index >= current.size():
		push_error("Property '%s' has no index %d" % [property_name, index])
		return
	var next: Array = current.duplicate(true)
	next[index] = _copy(item)
	_commit(next)
