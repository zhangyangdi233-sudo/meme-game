class_name PropertyManager
extends RefCounted
## Stores models by name. It does not hold raw values and it does not notify listeners.


var _models: Dictionary = {}


func add(model: PropertyModel) -> void:
	if model == null:
		push_error("PropertyManager cannot add an empty model")
		return
	if _models.has(model.property_name):
		push_error("PropertyManager already has '%s'" % model.property_name)
		return
	_models[model.property_name] = model


func model(property_name: String) -> PropertyModel:
	if not _models.has(property_name):
		push_error("PropertyManager has no '%s'" % property_name)
		return null
	return _models[property_name] as PropertyModel
