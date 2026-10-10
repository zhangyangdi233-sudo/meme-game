class_name PropertyBoot
extends RefCounted
## Creates this game's models and binds the property manager.
## install() does not replace a manager that is already bound.

const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const PropertyManagerScript = preload("res://framework/properties/property_manager.gd")
const PropertyFactoryScript = preload("res://framework/properties/property_factory.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

const DEFAULT_MONEY := 18
const DEFAULT_MAX_ACTIONS := 5
const DEFAULT_LOCALE := "zh"
const DEFAULT_MASTER_VOLUME := 80.0


static func install() -> void:
	if ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	var manager = PropertyManagerScript.new()
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.POLLUTION, 0, 0, 100))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.HAS_SAVE, false))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.MONEY, DEFAULT_MONEY))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.ACTIONS_REMAINING, DEFAULT_MAX_ACTIONS))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.AUTOPLAY_ENABLED, false))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.LOCALE, DEFAULT_LOCALE))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.MASTER_VOLUME, DEFAULT_MASTER_VOLUME, 0.0, 100.0))
	ServiceRegistryScript.bind(ServiceKeysScript.PROPERTY_MANAGER, manager)


static func reset_run() -> void:
	install()
	var manager: PropertyManager = ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return
	for property_name in PropertyKeysScript.RUN:
		var found: PropertyModel = manager.model(property_name)
		if found != null:
			found.reset()
