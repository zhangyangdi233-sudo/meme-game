class_name PropertyWatch
extends RefCounted
## One screen's registrations on property models: finds the models, registers every listener, lets go of all of them.
## The screen leaving the tree lets go too, so a freed screen is never called again.
## Starting registers nothing unless every model is found. Each listener gets its model's value once while starting.

const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _owner: Node
var _listeners: Dictionary
var _active := false
var _syncing := false


## `listeners` maps a model name to the Callable that takes that model's value.
func _init(owner: Node, listeners: Dictionary) -> void:
	_owner = owner
	_listeners = listeners
	owner.tree_exiting.connect(stop)


func is_active() -> bool:
	return _active


## True while starting, when each listener is still receiving the value it is registered with.
func is_syncing() -> bool:
	return _syncing


func start() -> bool:
	if _active:
		return true
	var models: Dictionary = {}
	for property_name in _listeners:
		var found := _model(str(property_name))
		if found == null:
			return false
		models[property_name] = found
	_active = true
	_syncing = true
	for property_name in _listeners:
		(models[property_name] as PropertyModel).register(_listeners[property_name])
	_syncing = false
	return true


## The model's value right now, whether or not the watch is started. Null when the model is missing.
func read(property_name: String) -> Variant:
	var found := _model(property_name)
	if found == null:
		return null
	return found.read()


func stop() -> void:
	if not _active:
		return
	_active = false
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	for property_name in _listeners:
		var found := _model(str(property_name))
		if found != null:
			found.unregister(_listeners[property_name])


func _model(property_name: String) -> PropertyModel:
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		push_error("%s cannot see the property service" % _owner.name)
		return null
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)
