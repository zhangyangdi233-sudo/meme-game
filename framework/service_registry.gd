class_name ServiceRegistry
extends RefCounted
## Process-wide table from a string to one shared object.
## The host binds services here. This is not an autoload, so tests can clear it.


static var _bound: Dictionary = {}


static func bind(key: String, service: Object) -> void:
	if key.is_empty() or service == null:
		push_error("ServiceRegistry cannot bind an empty service")
		return
	if _bound.has(key):
		push_error("ServiceRegistry already has '%s'" % key)
		return
	_bound[key] = service


static func resolve(key: String) -> Object:
	if not _bound.has(key):
		push_error("ServiceRegistry has no '%s'" % key)
		return null
	return _bound[key] as Object


static func has(key: String) -> bool:
	return _bound.has(key)


static func clear() -> void:
	_bound.clear()
