extends SceneTree

const CONTROLLER_PATH := "res://scripts/tutorial/floor_two_map_unlock.gd"
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	if not FileAccess.file_exists(CONTROLLER_PATH):
		_check(false, "floor-two map introduction has an isolated pausable controller")
	else:
		_test_timeline(load(CONTROLLER_PATH))
		_test_cancellation(load(CONTROLLER_PATH))
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("floor two map unlock tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)

func _test_timeline(script: Script) -> void:
	var controller: Node = script.new()
	var events: Array = []
	controller.reveal_started.connect(func(): events.append("reveal"))
	controller.brightness_changed.connect(func(value: float): events.append(value))
	controller.finished.connect(func(): events.append("finished"))
	controller.update(10.0)
	_check(events.is_empty() and not controller.active(), "idle time cannot produce an unlock")
	controller.begin()
	_check(controller.active() and events == [0.0], "begin immediately presents a gray icon without granting access")
	controller.update(0.52)
	_check(events == [0.0], "phone slides in for 0.52 seconds before revealing the map")
	controller.update(10.0, true)
	_check(events == [0.0] and controller.active(), "settings or focus pause freezes the slide/hold timer")
	controller.begin()
	controller.update(0.24)
	_check(events == [0.0], "duplicate begin does not reset or skip the gray hold")
	controller.update(0.02)
	_check(events.has("reveal") and not events.has("finished"), "brightening starts after the phone is visible and its gray hold finishes")
	controller.update(0.40)
	var halfway: float = events.back()
	_check(halfway > 0.0 and halfway < 1.0, "icon genuinely passes through intermediate brightness")
	var before_pause := events.duplicate()
	controller.update(30.0, true)
	controller.update(-1.0)
	controller.update(NAN)
	controller.update(INF)
	_check(events == before_pause, "pause and invalid deltas cannot advance the animation or corrupt its brightness")
	controller.update(0.50)
	_check(events.back() == 1.0 and controller.active(), "fully lit icon remains on screen before controls return")
	controller.update(0.61)
	_check(controller.active() and not events.has("finished"), "the introduction lasts at least 2.2 seconds")
	controller.update(0.02)
	_check(not controller.active() and events.back() == "finished", "2.30 seconds completes exactly once and releases the host")
	controller.update(20.0)
	_check(events.count("finished") == 1 and events.count("reveal") == 1, "future frames cannot repeat unlock or reveal signals")
	controller.free()

func _test_cancellation(script: Script) -> void:
	var controller: Node = script.new()
	var finished_count := [0]
	var values: Array = []
	controller.finished.connect(func(): finished_count[0] += 1)
	controller.brightness_changed.connect(func(value: float): values.append(value))
	controller.begin()
	controller.update(1.0)
	controller.cancel()
	var cancelled := values.duplicate()
	controller.update(10.0)
	_check(not controller.active() and finished_count[0] == 0 and values == cancelled, "cancelling leaves no delayed callback or unauthorized map reward")
	controller.begin()
	_check(values.back() == 0.0 and controller.active(), "Continue can safely restart an unfinished introduction from gray")
	controller.update(3.0)
	_check(not controller.active() and finished_count[0] == 1 and values.back() == 1.0, "a resumed introduction can complete normally")
	controller.free()
	var reentrant: Node = script.new()
	var signals_after_cancel: Array = []
	reentrant.reveal_started.connect(func(): reentrant.cancel())
	reentrant.brightness_changed.connect(func(value: float): signals_after_cancel.append(value))
	reentrant.finished.connect(func(): signals_after_cancel.append("finished"))
	reentrant.begin()
	reentrant.update(10.0)
	_check(not reentrant.active() and signals_after_cancel == [0.0], "a host cancellation inside a signal stops the old update immediately")
	reentrant.free()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
