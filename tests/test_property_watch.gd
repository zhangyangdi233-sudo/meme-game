extends SceneTree
## PropertyWatch registers one screen's listeners, syncs them once, and lets go of all of them.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []
var _money_seen: Array = []
var _actions_seen: Array = []
var _syncing_seen: Array = []
var _watch: PropertyWatchScript


func _init() -> void:
	call_deferred("_run_deferred")


## The tree only reports nodes as inside it once the first frame has run.
func _run_deferred() -> void:
	await process_frame
	_run()
	if _failures.is_empty():
		print("property watch tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_starting_registers_every_model_and_syncs_once()
	_test_later_changes_reach_the_listeners()
	_test_starting_again_does_not_register_twice()
	_test_stopping_unregisters_and_later_writes_are_ignored()
	_test_stopping_twice_is_harmless()
	_test_a_watch_can_start_again_after_stopping()
	_test_a_freed_owner_stops_the_watch()
	_test_read_gives_the_current_value_even_when_stopped()


func _test_starting_registers_every_model_and_syncs_once() -> void:
	var mounted := _mount()
	var owner: Node = mounted["owner"]
	_assert_eq(_listener_count(mounted["money"]), 0, "a new watch should not listen yet")
	_assert_true(not _watch.is_active(), "a new watch should not be active")
	_assert_true(_watch.start(), "starting with every model present should succeed")
	_assert_true(_watch.is_active(), "a started watch should be active")
	_assert_eq(_listener_count(mounted["money"]), 1, "starting should register on the money model")
	_assert_eq(_listener_count(mounted["actions"]), 1, "starting should register on the actions model")
	_assert_eq(_money_seen, [18], "starting should hand over the current money once")
	_assert_eq(_actions_seen, [5], "starting should hand over the current actions once")
	_assert_eq(_syncing_seen, [true, true], "listeners should see the watch as syncing while it starts")
	_assert_true(not _watch.is_syncing(), "a started watch should no longer be syncing")
	_dispose(owner)


func _test_later_changes_reach_the_listeners() -> void:
	var mounted := _mount()
	_watch.start()
	_write_money(mounted, 30)
	_assert_eq(_money_seen, [18, 30], "a change should reach the money listener")
	_assert_eq(_actions_seen, [5], "a change on one model should not reach the other listener")
	_assert_eq(_syncing_seen, [true, true, false], "a change after starting should not count as syncing")
	_dispose(mounted["owner"])


func _test_starting_again_does_not_register_twice() -> void:
	var mounted := _mount()
	_watch.start()
	_assert_true(_watch.start(), "starting again should still report success")
	_assert_eq(_listener_count(mounted["money"]), 1, "starting again should not register twice")
	_assert_eq(_money_seen, [18], "starting again should not hand over the value again")
	_dispose(mounted["owner"])


func _test_stopping_unregisters_and_later_writes_are_ignored() -> void:
	var mounted := _mount()
	_watch.start()
	_watch.stop()
	_assert_true(not _watch.is_active(), "a stopped watch should not be active")
	_assert_eq(_listener_count(mounted["money"]), 0, "stopping should unregister from the money model")
	_assert_eq(_listener_count(mounted["actions"]), 0, "stopping should unregister from the actions model")
	_write_money(mounted, 40)
	_assert_eq(_money_seen, [18], "a stopped watch should ignore later writes")
	_dispose(mounted["owner"])


func _test_stopping_twice_is_harmless() -> void:
	var mounted := _mount()
	_watch.start()
	_watch.stop()
	_watch.stop()
	_assert_eq(_listener_count(mounted["money"]), 0, "stopping twice should leave no listener")
	_dispose(mounted["owner"])


func _test_a_watch_can_start_again_after_stopping() -> void:
	var mounted := _mount()
	_watch.start()
	_watch.stop()
	_write_money(mounted, 40)
	_assert_true(_watch.start(), "a stopped watch should start again")
	_assert_eq(_money_seen, [18, 40], "starting again should hand over the value as it is now")
	_assert_eq(_listener_count(mounted["money"]), 1, "starting again should register once")
	_dispose(mounted["owner"])


func _test_a_freed_owner_stops_the_watch() -> void:
	var mounted := _mount()
	var owner: Node = mounted["owner"]
	_watch.start()
	owner.free()
	_assert_true(not _watch.is_active(), "a freed owner should stop the watch")
	_assert_eq(_listener_count(mounted["money"]), 0, "a freed owner should unregister from the money model")
	_assert_eq(_listener_count(mounted["actions"]), 0, "a freed owner should unregister from the actions model")
	RegistryScript.clear()


func _test_read_gives_the_current_value_even_when_stopped() -> void:
	var mounted := _mount()
	_write_money(mounted, 25)
	_assert_eq(_watch.read(PropertyKeysScript.MONEY), 25, "reading should give the current value without starting")
	_assert_true(not _watch.is_active(), "reading should not start the watch")
	_assert_eq(_listener_count(mounted["money"]), 0, "reading should not register")
	_dispose(mounted["owner"])


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	_money_seen = []
	_actions_seen = []
	_syncing_seen = []
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var owner := Node.new()
	owner.name = "WatchOwner"
	root.add_child(owner)
	_watch = PropertyWatchScript.new(owner, {
		PropertyKeysScript.MONEY: _on_money,
		PropertyKeysScript.ACTIONS_REMAINING: _on_actions,
	})
	return {
		"owner": owner,
		"money": manager.model(PropertyKeysScript.MONEY),
		"actions": manager.model(PropertyKeysScript.ACTIONS_REMAINING),
	}


func _on_money(value: Variant) -> void:
	_money_seen.append(value)
	_syncing_seen.append(_watch.is_syncing())


func _on_actions(value: Variant) -> void:
	_actions_seen.append(value)
	_syncing_seen.append(_watch.is_syncing())


func _write_money(mounted: Dictionary, value: int) -> void:
	(mounted["money"] as PropertyModel).call("write", value)


func _dispose(owner: Node) -> void:
	if owner != null and is_instance_valid(owner):
		owner.free()
	RegistryScript.clear()


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
