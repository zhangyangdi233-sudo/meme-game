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
const DEFAULT_APP := "social"
const DEFAULT_CONVERSATION_PHASE := "idle"
const DEFAULT_CONVERSATION_MODE := "authored"
const DEFAULT_CONVERSATION_ACTOR_TYPE := "npc"


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
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.ENDING_LANGUAGE_CHOICE, ""))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.PHONE_OPEN, true))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.ACTIVE_APP, DEFAULT_APP))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.ACTIVE_APP_WINDOW, DEFAULT_APP))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.NOTEBOOK_TOKENS, []))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.COLLECTED_CHAR_UNITS, []))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.COMPLETED_MEMES, []))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CHAR_CANVAS_POSITIONS, {}))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES, []))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.SOCIAL_LIKED_POST_IDS, []))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_PHASE, DEFAULT_CONVERSATION_PHASE))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_MODE, DEFAULT_CONVERSATION_MODE))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_ACTOR_TYPE, DEFAULT_CONVERSATION_ACTOR_TYPE))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_ACTOR_LABEL, ""))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_PROMPT, ""))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_RESULT_LINE, ""))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_CHOICES, []))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_CAN_CONTINUE, false))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_FEEDBACK, ""))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_REVEAL_INDEX, 0))
	manager.add(PropertyFactoryScript.create(PropertyKeysScript.CONVERSATION_REVEALED_UNITS, []))
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
