extends SceneTree
## The desk log watches the feedback text model while it is in the tree and shows it.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const DeskLogScript = preload("res://scripts/ui/desk_log_label.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_deferred")


func _run_deferred() -> void:
	await process_frame
	RegistryScript.clear()
	BootScript.install()
	_test_entering_the_tree_shows_the_current_text()
	_test_later_writes_repaint_the_log()
	_test_a_removed_log_ignores_later_writes()
	_test_a_re_added_log_shows_the_latest_text()
	_test_each_repaint_runs_the_localizer()
	if _failures.is_empty():
		print("desk log label tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _feedback() -> ValuePropertyModel:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return manager.model(PropertyKeysScript.FEEDBACK_TEXT) as ValuePropertyModel


func _test_entering_the_tree_shows_the_current_text() -> void:
	_feedback().write("你停在门前。")
	var log: Label = DeskLogScript.new()
	root.add_child(log)
	_assert_eq(log.text, "你停在门前。", "the log should show the feedback text it finds")
	log.free()


func _test_later_writes_repaint_the_log() -> void:
	var log: Label = DeskLogScript.new()
	root.add_child(log)
	_feedback().write("已保存这条信号。")
	_assert_eq(log.text, "已保存这条信号。", "a later write should repaint the log")
	log.free()


func _test_a_removed_log_ignores_later_writes() -> void:
	var log: Label = DeskLogScript.new()
	root.add_child(log)
	_feedback().write("一")
	root.remove_child(log)
	_feedback().write("二")
	_assert_eq(log.text, "一", "a log outside the tree should not repaint")
	log.free()


func _test_a_re_added_log_shows_the_latest_text() -> void:
	var log: Label = DeskLogScript.new()
	root.add_child(log)
	root.remove_child(log)
	_feedback().write("三")
	root.add_child(log)
	_assert_eq(log.text, "三", "a re-added log should show the latest text")
	log.free()


func _test_each_repaint_runs_the_localizer() -> void:
	var log: Label = DeskLogScript.new()
	log.localize = func(label: Label) -> void: label.text = "[%s]" % label.text
	root.add_child(log)
	_feedback().write("四")
	_assert_eq(log.text, "[四]", "a repaint should localize the new text")
	log.free()


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, expected, actual])
