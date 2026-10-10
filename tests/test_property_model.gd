extends SceneTree
## Property models: factory shape, copies, listeners, boot, and the single pollution value.

const FactoryScript = preload("res://framework/properties/property_factory.gd")
const ListScript = preload("res://framework/properties/list_property_model.gd")
const MapScript = preload("res://framework/properties/map_property_model.gd")
const ValueScript = preload("res://framework/properties/value_property_model.gd")
const ManagerScript = preload("res://framework/properties/property_manager.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("property model tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_factory_picks_a_model_from_the_initial_value()
	_test_value_keeps_bounds_and_rejects_the_wrong_type()
	_test_list_and_map_reads_are_copies()
	_test_register_syncs_and_notifies_every_listener()
	_test_unregister_stops_updates()
	_test_duplicate_names_keep_the_first_object()
	_test_boot_resets_the_same_pollution_model()
	_test_boot_resets_the_same_money_and_actions_models()
	_test_save_and_load_go_through_the_pollution_model()
	_test_save_and_load_go_through_money_and_actions()
	_test_language_and_volume_are_preferences_and_autoplay_is_the_run()
	_test_run_save_carries_autoplay_but_not_preferences()
	_test_ending_choice_lives_only_in_the_run_model()
	_test_phone_state_lives_only_in_the_run_models()
	_test_registering_a_listener_does_not_open_a_screen()


func _test_factory_picks_a_model_from_the_initial_value() -> void:
	var counted: PropertyModel = FactoryScript.create("heat", 150, 0, 100)
	var listed: PropertyModel = FactoryScript.create("bag", ["a"], 0, 100)
	var mapped: PropertyModel = FactoryScript.create("table", {"a": 1})
	_assert_true(counted.get_script() == ValueScript, "a number should become a single-value model")
	_assert_eq(counted.read(), 100, "bounds should clamp the initial number")
	_assert_true(listed.get_script() == ListScript, "an array should become a list model")
	_assert_eq(listed.read(), ["a"], "list bounds should not rewrite the array")
	_assert_true(mapped.get_script() == MapScript, "a dictionary should become a map model")
	_assert_eq(mapped.read(), {"a": 1}, "a map should keep its initial entries")


func _test_value_keeps_bounds_and_rejects_the_wrong_type() -> void:
	var model: ValuePropertyModel = FactoryScript.create("heat", 0, 0, 100) as ValuePropertyModel
	model.write(4)
	model.write("nope")
	_assert_eq(model.read(), 4, "a wrong type should keep the previous value")
	model.write(140)
	_assert_eq(model.read(), 100, "a number above the max should clamp")
	model.write(-8)
	_assert_eq(model.read(), 0, "a number below the min should clamp")


func _test_list_and_map_reads_are_copies() -> void:
	var listed: ListPropertyModel = FactoryScript.create("bag", [{"n": 1}]) as ListPropertyModel
	var heard: Array = []
	listed.register(func(value: Variant) -> void:
		heard.append(value)
	)
	_assert_eq(heard.size(), 1, "registering a list should sync once")
	var notified: Array = heard[0]
	notified.append({"n": 8})
	var copy: Array = listed.read()
	copy.append({"n": 9})
	copy[0]["n"] = 7
	_assert_eq(heard.size(), 1, "editing a list copy should not notify")
	_assert_eq(int(listed.read()[0]["n"]), 1, "editing a list copy should not change the model")
	_assert_eq(listed.read().size(), 1, "appending to a list copy should not change the model")

	var item := {"n": 2}
	listed.add(item)
	item["n"] = 5
	_assert_eq(heard.size(), 2, "adding through the list model should notify")
	_assert_eq(listed.read().size(), 2, "add should store the new item")
	_assert_eq(int(listed.read()[1]["n"]), 2, "add should store a copy of the item")
	listed.replace_at(0, {"n": 3})
	_assert_eq(int(listed.read()[0]["n"]), 3, "replace_at should change the stored item")
	listed.remove_at(1)
	_assert_eq(listed.read().size(), 1, "remove_at should drop the stored item")

	var mapped: MapPropertyModel = FactoryScript.create("table", {"a": 1}) as MapPropertyModel
	var map_heard: Array = []
	mapped.register(func(value: Variant) -> void:
		map_heard.append(value.size())
	)
	var map_copy: Dictionary = mapped.read()
	map_copy["a"] = 9
	map_copy["b"] = 2
	_assert_eq(map_heard.size(), 1, "editing a map copy should not notify")
	_assert_eq(int(mapped.read()["a"]), 1, "editing a map copy should not change the model")
	_assert_true(not mapped.read().has("b"), "adding a key on a copy should not change the model")
	mapped.add("a", 9)
	_assert_eq(map_heard.size(), 1, "adding an existing key should not notify")
	_assert_eq(int(mapped.read()["a"]), 1, "adding an existing key should keep the stored value")
	mapped.add("b", {"n": 2})
	mapped.replace("a", 4)
	mapped.remove("b")
	_assert_eq(int(mapped.read()["a"]), 4, "replace should change the stored entry")
	_assert_true(not mapped.read().has("b"), "remove should drop the stored entry")
	_assert_eq(map_heard.size(), 4, "add, replace, and remove should each notify")


func _test_register_syncs_and_notifies_every_listener() -> void:
	var model: ValuePropertyModel = FactoryScript.create("score", 2) as ValuePropertyModel
	var first: Array = []
	var second: Array = []
	var first_listener := func(value: Variant) -> void:
		first.append(int(value))
	model.register(first_listener)
	model.register(first_listener)
	model.register(func(value: Variant) -> void:
		second.append(int(value))
	)
	model.write(6)
	_assert_eq(first, [2, 6], "the first listener should sync immediately and then see the change once")
	_assert_eq(second, [2, 6], "a second listener should see the same values")


func _test_unregister_stops_updates() -> void:
	var model: ValuePropertyModel = FactoryScript.create("score", 1) as ValuePropertyModel
	var heard: Array = []
	var listener := func(value: Variant) -> void:
		heard.append(int(value))
	model.register(listener)
	model.unregister(listener)
	model.write(3)
	_assert_eq(heard, [1], "an unregistered listener should keep only the sync value")


func _test_duplicate_names_keep_the_first_object() -> void:
	RegistryScript.clear()
	var manager: PropertyManager = ManagerScript.new()
	var first = FactoryScript.create("score", 1)
	var second = FactoryScript.create("score", 9)
	manager.add(first)
	manager.add(second)
	_assert_true(manager.model("score") == first, "adding the same model name twice should keep the first model")
	_assert_eq(manager.model("score").read(), 1, "the rejected model should not replace the stored value")
	_assert_true(manager.model("missing") == null, "a missing model name should be an error result")

	var other = ManagerScript.new()
	RegistryScript.bind(ServiceKeysScript.PROPERTY_MANAGER, manager)
	RegistryScript.bind(ServiceKeysScript.PROPERTY_MANAGER, other)
	_assert_true(RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) == manager, "binding the same service name twice should keep the first object")
	RegistryScript.clear()
	_assert_true(RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) == null, "clear should drop the bound service")


func _test_boot_resets_the_same_pollution_model() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var pollution: ValuePropertyModel = manager.model(PropertyKeysScript.POLLUTION) as ValuePropertyModel
	var has_save: ValuePropertyModel = manager.model(PropertyKeysScript.HAS_SAVE) as ValuePropertyModel
	var pollution_id: int = pollution.get_instance_id()
	_assert_true(PropertyKeysScript.RUN.has(PropertyKeysScript.POLLUTION), "pollution should be saved with the run")
	_assert_true(PropertyKeysScript.UNSAVED.has(PropertyKeysScript.HAS_SAVE), "has_save should not be saved")
	for property_name in PropertyKeysScript.PREFERENCES:
		_assert_true(not PropertyKeysScript.RUN.has(property_name), "preference %s should not be saved with the run" % property_name)
	_assert_eq(pollution.read(), 0, "pollution should start at zero")
	_assert_eq(has_save.read(), false, "has_save should start false")
	pollution.write(140)
	_assert_eq(pollution.read(), 100, "booted pollution should clamp to 100")
	pollution.write(-3)
	_assert_eq(pollution.read(), 0, "booted pollution should clamp to 0")

	var state = StateScript.new()
	state.pollution = 40
	_assert_eq(pollution.read(), 40, "writing the state should write the model")
	pollution.write(22)
	_assert_eq(state.pollution, 22, "the state should read the model instead of a private copy")
	state.new_run()
	_assert_eq(pollution.get_instance_id(), pollution_id, "a new run should keep the same pollution model")
	_assert_eq(state.pollution, 0, "a new run should restore the initial pollution")
	_assert_eq(has_save.read(), false, "a new run should leave the unsaved has_save model alone")


func _test_boot_resets_the_same_money_and_actions_models() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var money: ValuePropertyModel = manager.model(PropertyKeysScript.MONEY) as ValuePropertyModel
	var actions: ValuePropertyModel = manager.model(PropertyKeysScript.ACTIONS_REMAINING) as ValuePropertyModel
	var money_id: int = money.get_instance_id()
	var actions_id: int = actions.get_instance_id()
	_assert_true(PropertyKeysScript.RUN.has(PropertyKeysScript.MONEY), "money should be saved with the run")
	_assert_true(PropertyKeysScript.RUN.has(PropertyKeysScript.ACTIONS_REMAINING), "remaining actions should be saved with the run")
	_assert_eq(money.read(), 18, "money should start at 18")
	_assert_eq(actions.read(), 5, "remaining actions should start at five")

	var state = StateScript.new()
	state.money = 31
	state.actions_remaining = 3
	_assert_eq(money.read(), 31, "writing money on the state should write the model")
	_assert_eq(actions.read(), 3, "writing remaining actions on the state should write the model")
	money.write(7)
	actions.write(1)
	_assert_eq(state.money, 7, "the state should read money from the model")
	_assert_eq(state.actions_remaining, 1, "the state should read remaining actions from the model")
	state.new_run()
	_assert_eq(money.get_instance_id(), money_id, "a new run should keep the same money model")
	_assert_eq(actions.get_instance_id(), actions_id, "a new run should keep the same actions model")
	_assert_eq(state.money, 18, "a new run should restore the initial money")
	_assert_eq(state.actions_remaining, 5, "a new run should restore five actions")


func _test_save_and_load_go_through_the_pollution_model() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var pollution: ValuePropertyModel = manager.model(PropertyKeysScript.POLLUTION) as ValuePropertyModel
	var pollution_id: int = pollution.get_instance_id()
	var source = StateScript.new()
	source.new_run()
	source.pollution = 47
	var save_data: Dictionary = source.to_save_data()
	var state_data: Dictionary = save_data.get("state", {})
	_assert_eq(int(state_data.get("pollution", -1)), 47, "the save should store the model value")
	_assert_true(not state_data.has("has_save"), "the save should not store has_save")
	source.pollution = 2
	var restored = StateScript.new()
	_assert_true(restored.load_save_data(save_data), "a save written from the model should load")
	_assert_eq(restored.pollution, 47, "loading should write pollution back through the model")
	_assert_eq(source.pollution, 47, "source and restored state should share the one pollution model")
	_assert_eq(pollution.get_instance_id(), pollution_id, "loading should not replace the pollution model")
	pollution.write("bad")
	_assert_eq(pollution.read(), 47, "a wrong type on the booted model should keep the loaded value")


func _test_save_and_load_go_through_money_and_actions() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var money: ValuePropertyModel = manager.model(PropertyKeysScript.MONEY) as ValuePropertyModel
	var actions: ValuePropertyModel = manager.model(PropertyKeysScript.ACTIONS_REMAINING) as ValuePropertyModel
	var money_id: int = money.get_instance_id()
	var source = StateScript.new()
	source.new_run()
	source.money = 31
	source.actions_remaining = 3
	var save_data: Dictionary = source.to_save_data()
	var state_data: Dictionary = save_data.get("state", {})
	_assert_eq(int(state_data.get("money", -1)), 31, "the save should store the money model")
	_assert_eq(int(state_data.get("actions_remaining", -1)), 3, "the save should store remaining actions")
	source.money = 2
	source.actions_remaining = 5
	var restored = StateScript.new()
	_assert_true(restored.load_save_data(save_data), "a save written from the models should load")
	_assert_eq(restored.money, 31, "loading should write money back through the model")
	_assert_eq(restored.actions_remaining, 3, "loading should write remaining actions back through the model")
	_assert_eq(source.money, 31, "source and restored state should share the one money model")
	_assert_eq(source.actions_remaining, 3, "source and restored state should share the one actions model")
	_assert_eq(money.get_instance_id(), money_id, "loading should not replace the money model")
	money.write("bad")
	actions.write("bad")
	_assert_eq(money.read(), 31, "a wrong money type should keep the loaded value")
	_assert_eq(actions.read(), 3, "a wrong actions type should keep the loaded value")


func _test_language_and_volume_are_preferences_and_autoplay_is_the_run() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var locale: ValuePropertyModel = manager.model(PropertyKeysScript.LOCALE) as ValuePropertyModel
	var volume: ValuePropertyModel = manager.model(PropertyKeysScript.MASTER_VOLUME) as ValuePropertyModel
	var autoplay: ValuePropertyModel = manager.model(PropertyKeysScript.AUTOPLAY_ENABLED) as ValuePropertyModel
	_assert_true(PropertyKeysScript.PREFERENCES.has(PropertyKeysScript.LOCALE), "language should be a preference")
	_assert_true(PropertyKeysScript.PREFERENCES.has(PropertyKeysScript.MASTER_VOLUME), "volume should be a preference")
	_assert_true(PropertyKeysScript.RUN.has(PropertyKeysScript.AUTOPLAY_ENABLED), "autoplay should be saved with the run")
	_assert_eq(locale.read(), "zh", "language should start as Chinese")
	_assert_eq(volume.read(), 80.0, "volume should start at 80")
	_assert_eq(autoplay.read(), false, "autoplay should start off")
	volume.write(140.0)
	_assert_eq(volume.read(), 100.0, "volume should clamp to 100")

	locale.write("en")
	volume.write(35.0)
	var state = StateScript.new()
	state.set_autoplay_enabled(true)
	_assert_eq(autoplay.read(), true, "turning autoplay on should write the model")
	state.new_run()
	_assert_eq(autoplay.read(), false, "a new run should turn autoplay off again")
	_assert_eq(locale.read(), "en", "a new run should keep the chosen language")
	_assert_eq(volume.read(), 35.0, "a new run should keep the chosen volume")


func _test_run_save_carries_autoplay_but_not_preferences() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var autoplay: ValuePropertyModel = manager.model(PropertyKeysScript.AUTOPLAY_ENABLED) as ValuePropertyModel
	var source = StateScript.new()
	source.new_run()
	source.set_autoplay_enabled(true)
	var state_data: Dictionary = source.to_save_data().get("state", {})
	_assert_eq(state_data.get("autoplay_enabled", null), true, "the run save should store the autoplay model")
	for property_name in PropertyKeysScript.PREFERENCES:
		_assert_true(not state_data.has(property_name), "the run save should not store preference %s" % property_name)
	autoplay.write(false)
	var restored = StateScript.new()
	_assert_true(restored.load_save_data({"version": StateScript.SAVE_DATA_VERSION, "state": state_data}), "the run save should load")
	_assert_eq(autoplay.read(), true, "loading should write autoplay back through the model")


func _test_ending_choice_lives_only_in_the_run_model() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var choice: ValuePropertyModel = manager.model(PropertyKeysScript.ENDING_LANGUAGE_CHOICE) as ValuePropertyModel
	_assert_true(PropertyKeysScript.RUN.has(PropertyKeysScript.ENDING_LANGUAGE_CHOICE), "the ending choice should be saved with the run")
	_assert_eq(choice.read(), "", "the ending choice should start empty")

	var source = StateScript.new()
	source.new_run()
	source.ending_unlocked = true
	_assert_true(source.choose_ending_language("blank"), "choosing an ending language should succeed")
	_assert_eq(choice.read(), "blank", "choosing should write the model")
	_assert_eq(source.ending_language_choice, "blank", "the state should read the model, not keep a copy")
	_assert_true(not source.get_progression_snapshot().has("ending_language_choice"), "the progression snapshot should not carry a second copy")
	_assert_true(not source.choose_ending_language("silence"), "a second choice should be refused")
	_assert_eq(choice.read(), "blank", "a refused choice should keep the model")

	var state_data: Dictionary = source.to_save_data().get("state", {})
	_assert_eq(state_data.get("ending_language_choice", null), "blank", "the run save should store the ending choice model")
	choice.write("")
	var restored = StateScript.new()
	_assert_true(restored.load_save_data({"version": StateScript.SAVE_DATA_VERSION, "state": state_data}), "the run save should load")
	_assert_eq(choice.read(), "blank", "loading should write the ending choice back through the model")
	restored.new_run()
	_assert_eq(choice.read(), "", "a new run should clear the ending choice on the same model")
	choice.write("blank")
	choice.write(3)
	_assert_eq(choice.read(), "blank", "a wrong type should keep the ending choice")


func _test_phone_state_lives_only_in_the_run_models() -> void:
	RegistryScript.clear()
	BootScript.install()
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var open: ValuePropertyModel = manager.model(PropertyKeysScript.PHONE_OPEN) as ValuePropertyModel
	var app: ValuePropertyModel = manager.model(PropertyKeysScript.ACTIVE_APP) as ValuePropertyModel
	var window: ValuePropertyModel = manager.model(PropertyKeysScript.ACTIVE_APP_WINDOW) as ValuePropertyModel
	for key in [PropertyKeysScript.PHONE_OPEN, PropertyKeysScript.ACTIVE_APP, PropertyKeysScript.ACTIVE_APP_WINDOW]:
		_assert_true(PropertyKeysScript.RUN.has(key), "%s should be saved with the run" % key)
	_assert_eq(open.read(), true, "the phone should start open")
	_assert_eq(app.read(), BootScript.DEFAULT_APP, "the current app should start on the default app")
	_assert_eq(window.read(), BootScript.DEFAULT_APP, "the foreground app should start on the default app")

	var source = StateScript.new()
	source.new_run()
	source.set_active_app("notebook")
	_assert_eq(app.read(), "notebook", "choosing an app should write the current app model")
	_assert_eq(window.read(), "notebook", "choosing an app should write the foreground model")
	_assert_eq(source.active_app, "notebook", "the state should read the model, not keep a copy")
	source.set_phone_open(false)
	_assert_eq(open.read(), false, "closing the phone should write the model")
	_assert_eq(window.read(), "", "closing the phone should clear the foreground model")
	_assert_true(not source.get_phone_shell_snapshot().has("phone_open"), "the phone snapshot should not carry a second copy")

	source.set_phone_open(true)
	source.set_active_app("babel")
	var state_data: Dictionary = source.to_save_data().get("state", {})
	_assert_eq(state_data.get("phone_open", null), true, "the run save should store the phone model")
	_assert_eq(state_data.get("active_app_window", null), "babel", "the run save should store the foreground model")
	_assert_true(not state_data.has("phone_visible"), "the run save should not store a second copy of the phone")
	open.write(false)
	app.write("social")
	window.write("")
	var restored = StateScript.new()
	_assert_true(restored.load_save_data({"version": StateScript.SAVE_DATA_VERSION, "state": state_data}), "the run save should load")
	_assert_eq(open.read(), true, "loading should write the phone back through the model")
	_assert_eq(app.read(), "babel", "loading should write the current app back through the model")
	_assert_eq(window.read(), "babel", "loading should write the foreground back through the model")
	restored.new_run()
	_assert_eq(window.read(), BootScript.DEFAULT_APP, "a new run should reset the foreground on the same model")
	open.write(false)
	open.write("yes")
	_assert_eq(open.read(), false, "a wrong type should keep the phone state")


func _test_registering_a_listener_does_not_open_a_screen() -> void:
	var child_count := root.get_child_count()
	var model: ValuePropertyModel = FactoryScript.create("score", 0) as ValuePropertyModel
	model.register(func(_value: Variant) -> void:
		pass
	)
	model.write(5)
	_assert_eq(root.get_child_count(), child_count, "registering a listener should not add a screen")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
