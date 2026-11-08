extends SceneTree
## The fact table: every key has one row, boot registers it, and its save list follows the row.

const RegistryScript = preload("res://framework/service_registry.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

const SAVES := [
	PropertyKeysScript.SAVED_WITH_RUN,
	PropertyKeysScript.RESET_WITH_RUN,
	PropertyKeysScript.PREFERENCE,
	PropertyKeysScript.NOT_SAVED,
]

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("property facts tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_every_key_has_exactly_one_row()
	_test_boot_registers_every_row_with_its_initial_value()
	_test_each_save_list_is_the_rows_with_that_save()
	_test_new_run_resets_run_rows_only()
	_test_the_save_writes_exactly_the_saved_run_rows()


func _key_names() -> Array[String]:
	var names: Array[String] = []
	var constants: Dictionary = PropertyKeysScript.new().get_script().get_script_constant_map()
	for constant_name in constants:
		var value: Variant = constants[constant_name]
		if value is String and str(constant_name) not in ["SAVED_WITH_RUN", "RESET_WITH_RUN", "PREFERENCE", "NOT_SAVED"] \
				and not str(constant_name).begins_with("DEFAULT_"):
			names.append(value)
	return names


func _manager() -> PropertyManager:
	RegistryScript.clear()
	BootScript.install()
	return RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager


func _test_every_key_has_exactly_one_row() -> void:
	var rows := {}
	for fact in PropertyKeysScript.FACTS:
		var property_name := str(fact["name"])
		_assert_true(not rows.has(property_name), "%s should have one row" % property_name)
		_assert_true(SAVES.has(fact["save"]), "%s should name a known save list" % property_name)
		rows[property_name] = true
	for property_name in _key_names():
		_assert_true(rows.has(property_name), "%s should have a row in the fact table" % property_name)
	_assert_eq(rows.size(), _key_names().size(), "every row should name a key")


func _test_boot_registers_every_row_with_its_initial_value() -> void:
	var manager := _manager()
	for fact in PropertyKeysScript.FACTS:
		var model: PropertyModel = manager.model(str(fact["name"]))
		_assert_true(model != null, "boot should register %s" % fact["name"])
		if model != null:
			_assert_eq(model.read(), fact["initial"], "%s should start at its row's value" % fact["name"])
	var floor_model := manager.model(PropertyKeysScript.TOWER_FLOOR) as ValuePropertyModel
	floor_model.write(99)
	_assert_eq(floor_model.read(), PropertyKeysScript.MAX_TOWER_FLOOR, "row bounds should reach the model")
	RegistryScript.clear()


func _test_each_save_list_is_the_rows_with_that_save() -> void:
	for fact in PropertyKeysScript.FACTS:
		var property_name := str(fact["name"])
		var save: String = fact["save"]
		for list_save in SAVES:
			_assert_eq(PropertyKeysScript.names_saved_as(list_save).has(property_name), save == list_save,
				"%s should be in the %s list only when its row says so" % [property_name, list_save])
		var is_run := save == PropertyKeysScript.SAVED_WITH_RUN or save == PropertyKeysScript.RESET_WITH_RUN
		_assert_eq(PropertyKeysScript.run_names().has(property_name), is_run, "%s run membership" % property_name)


func _test_new_run_resets_run_rows_only() -> void:
	var manager := _manager()
	var changed := {}
	for fact in PropertyKeysScript.FACTS:
		var model: PropertyModel = manager.model(str(fact["name"]))
		var initial: Variant = fact["initial"]
		var other: Variant
		match typeof(initial):
			TYPE_BOOL: other = not initial
			TYPE_INT: other = int(initial) + 1 if fact.get("max") == null or int(initial) < int(fact["max"]) else int(initial) - 1
			TYPE_FLOAT: other = float(initial) - 1.0
			TYPE_STRING: other = str(initial) + "x"
			TYPE_ARRAY: other = ["x"]
			TYPE_DICTIONARY: other = {"x": 1}
		if model is ListPropertyModel:
			(model as ListPropertyModel).replace_all(other)
		elif model is MapPropertyModel:
			(model as MapPropertyModel).replace_all(other)
		else:
			(model as ValuePropertyModel).write(other)
		changed[fact["name"]] = model.read()
	BootScript.reset_run()
	for fact in PropertyKeysScript.FACTS:
		var model: PropertyModel = manager.model(str(fact["name"]))
		if PropertyKeysScript.run_names().has(fact["name"]):
			_assert_eq(model.read(), fact["initial"], "a new run should reset %s" % fact["name"])
		else:
			_assert_eq(model.read(), changed[fact["name"]], "a new run should keep %s" % fact["name"])
	RegistryScript.clear()


func _test_the_save_writes_exactly_the_saved_run_rows() -> void:
	RegistryScript.clear()
	var state = StateScript.new()
	var saved: Dictionary = state.to_save_data()["state"]
	for fact in PropertyKeysScript.FACTS:
		_assert_eq(saved.has(fact["name"]), fact["save"] == PropertyKeysScript.SAVED_WITH_RUN,
			"the run save should hold %s only when its row says saved with the run" % fact["name"])
	RegistryScript.clear()


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
