extends SceneTree
## The F9 chapter debug panel (debug builds only) shows the basement round from the chapter progress model and asks
## to jump to a round with one button per round.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const PanelScene = preload("res://scenes/ui/chapter_debug_panel.tscn")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	RegistryScript.clear()
	BootScript.install()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	var panel := PanelScene.instantiate() as Control
	root.add_child(panel)
	await process_frame
	_test_each_round_button_asks_to_jump_there(panel)
	_test_the_status_follows_the_chapter_progress(panel)
	panel.queue_free()
	await process_frame
	RegistryScript.clear()
	if _failures.is_empty():
		print("chapter debug panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_each_round_button_asks_to_jump_there(panel: Control) -> void:
	for round_number in range(1, ProgressScript.BASEMENT_ROUND_COUNT + 1):
		_heard.clear()
		var button := panel.find_child("ChapterDebugRound%dButton" % round_number, true, false) as Button
		_assert_true(button != null, "the panel should offer round %d" % round_number)
		if button == null:
			continue
		button.pressed.emit()
		_assert_eq(_heard, [[UiIntentsScript.CHAPTER_ROUND_JUMP_REQUESTED, {UiIntentsScript.KEY_INDEX: round_number}]], "round %d's button should ask to jump there" % round_number)


func _test_the_status_follows_the_chapter_progress(panel: Control) -> void:
	var status := panel.find_child("ChapterDebugStatus", true, false) as Label
	var progress := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER).model(PropertyKeysScript.CHAPTER_ONE_PROGRESS) as MapPropertyModel
	progress.replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 3))
	_assert_true(status != null and status.text.contains("3 / 5"), "the status should show round three: %s" % (status.text if status != null else "missing"))
	progress.replace_all(ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 3), true))
	_assert_true(status != null and status.text.contains("出口：开"), "the status should show the open exit: %s" % (status.text if status != null else "missing"))
	progress.replace_all(ProgressScript.tower())
	_assert_true(status != null and status.text.contains("十字路口"), "the status should show the crossroads past chapter one: %s" % (status.text if status != null else "missing"))


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
