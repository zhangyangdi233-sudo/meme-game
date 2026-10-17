extends SceneTree
## Unbinding drops only the service still bound under that key.

const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []


func _init() -> void:
	var first := RefCounted.new()
	var second := RefCounted.new()
	RegistryScript.clear()
	RegistryScript.bind("svc", first)
	RegistryScript.unbind("svc", second)
	_assert_true(RegistryScript.resolve("svc") == first, "unbinding another service should keep the bound one")
	RegistryScript.unbind("svc", first)
	_assert_true(not RegistryScript.has("svc"), "unbinding the bound service should drop the key")
	RegistryScript.bind("svc", second)
	_assert_true(RegistryScript.resolve("svc") == second, "the key should accept a new binding after unbinding")
	RegistryScript.clear()
	if _failures.is_empty():
		print("service registry tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
