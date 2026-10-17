class_name GameEventBus
extends RefCounted
## Game-side event bus. The host creates one, binds it as a service, and listens; screens only emit. Not an autoload.
## A UI intent has one listener, the host; intent names and their payload keys live in UiIntents.
## A game event may have many listeners, each subscribed by event name; names and keys live in GameEvents.

const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")


signal intent_emitted(intent_name: String, payload: Dictionary)

## Event name -> listeners, each a Callable taking the payload.
var _listeners: Dictionary = {}


## A control built at runtime raises its action on the bound bus; with no bus bound there is no host to hear it.
static func raise(intent_name: String, payload: Dictionary = {}) -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.UI_EVENT_BUS):
		return
	var bus := ServiceRegistryScript.resolve(ServiceKeysScript.UI_EVENT_BUS) as GameEventBus
	if bus != null:
		bus.emit_intent(intent_name, payload)


## A collaborator raises a game event on the bound bus; with no bus bound nobody is listening.
static func raise_event(event_name: String, payload: Dictionary = {}) -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.UI_EVENT_BUS):
		return
	var bus := ServiceRegistryScript.resolve(ServiceKeysScript.UI_EVENT_BUS) as GameEventBus
	if bus != null:
		bus.emit_event(event_name, payload)


func emit_intent(intent_name: String, payload: Dictionary = {}) -> void:
	intent_emitted.emit(intent_name, payload)


## A listener subscribes while it is in the tree and unsubscribes when it leaves. Subscribing twice delivers once.
func subscribe(event_name: String, listener: Callable) -> void:
	var listeners: Array = _listeners.get(event_name, [])
	if not listeners.has(listener):
		listeners.append(listener)
	_listeners[event_name] = listeners


func unsubscribe(event_name: String, listener: Callable) -> void:
	var listeners: Array = _listeners.get(event_name, [])
	listeners.erase(listener)
	if listeners.is_empty():
		_listeners.erase(event_name)


## Delivers to the listeners subscribed when the event was raised; a listener whose owner was freed is skipped.
func emit_event(event_name: String, payload: Dictionary = {}) -> void:
	for listener in (_listeners.get(event_name, []) as Array).duplicate():
		if (listener as Callable).is_valid():
			(listener as Callable).call(payload)
