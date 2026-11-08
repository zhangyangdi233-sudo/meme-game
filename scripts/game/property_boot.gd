class_name PropertyBoot
extends RefCounted
## Creates this game's models from the fact table and binds the property manager.
## install() does not replace a manager that is already bound.

const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const PropertyManagerScript = preload("res://framework/properties/property_manager.gd")
const PropertyFactoryScript = preload("res://framework/properties/property_factory.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")


static func install() -> void:
	if ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	var manager = PropertyManagerScript.new()
	for fact in PropertyKeysScript.FACTS:
		manager.add(PropertyFactoryScript.create(str(fact["name"]), fact["initial"], fact.get("min"), fact.get("max")))
	ServiceRegistryScript.bind(ServiceKeysScript.PROPERTY_MANAGER, manager)


static func reset_run() -> void:
	install()
	var manager: PropertyManager = ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return
	for property_name in PropertyKeysScript.run_names():
		var found: PropertyModel = manager.model(property_name)
		if found != null:
			found.reset()
