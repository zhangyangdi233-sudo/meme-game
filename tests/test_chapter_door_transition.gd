extends SceneTree

const TRANSITION_PATH := "res://scripts/world/chapter_door_transition.gd"
const DOOR_PATH := "res://scripts/world/chapter_door.gd"
const CAMERA_DESTINATION := Vector3(0.0, 1.5, 2.0)
const LOOK_TARGET := Vector3(0.0, 1.5, 0.0)

var _failures: Array[String] = []
var _checks: int = 0
var _transition_script: Script
var _door_script: Script


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert_true(FileAccess.file_exists(TRANSITION_PATH), "chapter door transition component must exist")
	if FileAccess.file_exists(TRANSITION_PATH):
		_transition_script = load(TRANSITION_PATH) as Script
		_assert_true(_transition_script != null and _transition_script.can_instantiate(), "chapter door transition must compile")
	_door_script = load(DOOR_PATH) as Script
	if _transition_script != null and _transition_script.can_instantiate():
		await _test_validation_and_duplicate_begin()
		await _test_ordered_transition_and_old_room_release()
		await _test_pause_each_phase()
		await _test_cancel_and_tree_exit()
		await _test_participant_exit_cancels_transition()
		await _test_cancelled_owner_notification()
	await process_frame
	if _failures.is_empty():
		print("chapter door transition tests passed (%d checks; real camera and door tweens)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_validation_and_duplicate_begin() -> void:
	var fixture := _new_fixture()
	var transition: Node = fixture.transition
	_assert_true(not transition.is_active(), "new transition must be idle")
	_assert_true(not transition.begin(null, fixture.ui, fixture.door, CAMERA_DESTINATION, LOOK_TARGET), "missing camera must reject startup")
	_assert_true(not transition.begin(fixture.camera, null, fixture.door, CAMERA_DESTINATION, LOOK_TARGET), "missing UI must reject startup")
	_assert_true(not transition.begin(fixture.camera, fixture.ui, null, CAMERA_DESTINATION, LOOK_TARGET), "missing door must reject startup")
	var unbound := Node3D.new()
	fixture.host.add_child(unbound)
	_assert_true(not transition.begin(fixture.camera, fixture.ui, unbound, CAMERA_DESTINATION, LOOK_TARGET), "node without door contract must reject startup")
	_assert_true(_overlay(fixture) == null, "invalid startup must not leave a black overlay")
	_assert_true(_begin(fixture), "valid transition should begin")
	_assert_true(transition.is_active(), "accepted transition must immediately report active")
	_assert_true(not _begin(fixture), "active transition must reject a duplicate begin")
	_assert_true(fixture.ui.get_child_count() == 1, "duplicate begin must not create duplicate overlays")
	var overlay := _overlay(fixture)
	_assert_true(overlay != null and overlay.z_index == 25, "transition overlay must use z index 25 below settings")
	if overlay != null:
		_assert_true(overlay.mouse_filter == Control.MOUSE_FILTER_IGNORE, "transition overlay must not intercept settings input")
		_assert_true(overlay.anchor_left == 0.0 and overlay.anchor_top == 0.0 and overlay.anchor_right == 1.0 and overlay.anchor_bottom == 1.0, "transition overlay must cover the complete UI root")
		_assert_near(overlay.color.a, 0.0, "transition must start transparent")
	transition.cancel()
	await process_frame
	fixture.host.free()


func _test_ordered_transition_and_old_room_release() -> void:
	var fixture := _new_fixture(0.22)
	var transition: Node = fixture.transition
	var events: Array[String] = []
	var room_alpha := [0.0]
	fixture.door.opened.connect(func() -> void: events.append("opened"))
	transition.room_requested.connect(func() -> void:
		events.append("room")
		room_alpha[0] = _overlay(fixture).color.a
		# The receiving room controller replaces old-room geometry synchronously.
		fixture.door.free()
		fixture.camera.global_position = Vector3(5.0, 2.0, 5.0)
	)
	transition.finished.connect(func() -> void: events.append("finished"))
	_assert_true(_begin(fixture), "ordered transition should begin")
	await create_timer(0.12).timeout
	_assert_true(fixture.camera.global_position.distance_to(Vector3(0.0, 1.5, 4.0)) > 0.01, "approach must visibly move the camera")
	_assert_near(fixture.pivot.rotation.y, 0.0, "door must stay closed while camera approaches")
	_assert_true(events.is_empty(), "approach must not switch rooms")
	await _wait_until(func() -> bool: return events.has("opened"), 1.0, "door should finish opening after approach")
	_assert_vector(fixture.camera.global_position, CAMERA_DESTINATION, "camera must reach the authored doorway position")
	_assert_true((-fixture.camera.global_basis.z).dot((LOOK_TARGET - CAMERA_DESTINATION).normalized()) > 0.999, "camera must look at the door after approach")
	_assert_true(events == ["opened"], "door opening must finish before requesting a room")
	await create_timer(0.12).timeout
	_assert_true(_overlay(fixture).color.a > 0.0 and _overlay(fixture).color.a < 1.0, "door completion must smoothly fade to black")
	_assert_true(events == ["opened"], "room replacement must wait for complete black")
	await _wait_until(func() -> bool: return events.has("room"), 0.6, "blackout should request next room")
	_assert_near(room_alpha[0], 1.0, "room replacement must happen behind fully opaque black")
	_assert_true(transition.is_active(), "room replacement must keep input locked through fade-in")
	await create_timer(0.04).timeout
	_assert_near(_overlay(fixture).color.a, 1.0, "new room must remain black during hold")
	await _wait_until(func() -> bool: return events.has("finished"), 0.8, "fade-in should complete after old door has been freed")
	await process_frame
	_assert_true(events == ["opened", "room", "finished"], "transition must emit each stage exactly once and in order")
	_assert_true(not transition.is_active() and _overlay(fixture) == null, "finished transition must become idle and remove its overlay")
	_assert_vector(fixture.camera.global_position, Vector3(5.0, 2.0, 5.0), "fade-in must preserve the receiving room's new camera spawn")
	await create_timer(0.2).timeout
	_assert_true(events.size() == 3, "completed transition must never emit duplicate terminal events")
	fixture.host.free()


func _test_pause_each_phase() -> void:
	var fixture := _new_fixture(0.45)
	var transition: Node = fixture.transition
	var room_count := [0]
	var finished_count := [0]
	transition.room_requested.connect(func() -> void:
		room_count[0] += 1
		transition.set_paused(true)
	)
	transition.finished.connect(func() -> void: finished_count[0] += 1)
	_begin(fixture)
	await create_timer(0.09).timeout
	transition.set_paused(true)
	var camera_position: Vector3 = fixture.camera.global_position
	await create_timer(0.42).timeout
	_assert_vector(fixture.camera.global_position, camera_position, "settings pause must freeze camera approach")
	_assert_near(fixture.pivot.rotation.y, 0.0, "paused approach must not start opening door")
	_assert_true(room_count[0] == 0, "paused approach must not request room")
	transition.set_paused(false)
	await _wait_until(func() -> bool: return fixture.pivot.rotation.y > 0.05, 0.7, "resuming approach must eventually start the door")
	transition.set_paused(true)
	var door_angle: float = fixture.pivot.rotation.y
	await create_timer(0.55).timeout
	_assert_near(fixture.pivot.rotation.y, door_angle, "settings pause must freeze the independently owned door tween")
	_assert_near(_overlay(fixture).color.a, 0.0, "paused opening must not start blackout")
	transition.set_paused(false)
	await _wait_until(func() -> bool: return _overlay(fixture).color.a > 0.05, 0.9, "resuming door must eventually begin blackout")
	transition.set_paused(true)
	var fade_alpha: float = _overlay(fixture).color.a
	await create_timer(0.45).timeout
	_assert_near(_overlay(fixture).color.a, fade_alpha, "settings pause must freeze fade to black")
	_assert_true(room_count[0] == 0, "paused blackout must not request room")
	transition.set_paused(false)
	await _wait_until(func() -> bool: return room_count[0] == 1, 0.6, "resuming blackout must request next room")
	await create_timer(0.6).timeout
	_assert_near(_overlay(fixture).color.a, 1.0, "pause from room callback must freeze black hold and prevent fade-in")
	_assert_true(finished_count[0] == 0, "paused black hold must not finish transition")
	transition.set_paused(false)
	await _wait_until(func() -> bool: return _overlay(fixture).color.a < 0.95, 0.6, "resuming black hold must start fade-in")
	transition.set_paused(true)
	fade_alpha = _overlay(fixture).color.a
	await create_timer(0.45).timeout
	_assert_near(_overlay(fixture).color.a, fade_alpha, "settings pause must freeze fade-in")
	_assert_true(finished_count[0] == 0, "paused fade-in must not release transition lock")
	transition.set_paused(false)
	await _wait_until(func() -> bool: return finished_count[0] == 1, 0.6, "resuming fade-in must finish once")
	_assert_true(room_count[0] == 1 and finished_count[0] == 1, "pause cycles must preserve single delivery")
	fixture.host.free()


func _test_cancel_and_tree_exit() -> void:
	for exit_tree in [false, true]:
		var fixture := _new_fixture(0.4)
		var transition: Node = fixture.transition
		var room_count := [0]
		var finished_count := [0]
		transition.room_requested.connect(func() -> void: room_count[0] += 1)
		transition.finished.connect(func() -> void: finished_count[0] += 1)
		_begin(fixture)
		await _wait_until(func() -> bool: return fixture.pivot.rotation.y > 0.05, 0.7, "cancel fixture must reach opening")
		if exit_tree:
			fixture.host.remove_child(transition)
		else:
			transition.cancel()
			transition.cancel()
		var stopped_camera: Vector3 = fixture.camera.global_position
		await create_timer(1.25).timeout
		_assert_true(room_count[0] == 0 and finished_count[0] == 0, "cancel or tree exit must not request room or signal completion")
		_assert_true(not transition.is_active() and _overlay(fixture) == null, "cancel or tree exit must clear active state and overlay")
		_assert_true(fixture.door.get_signal_connection_list("opened").is_empty(), "cancel or tree exit must disconnect door completion")
		_assert_vector(fixture.camera.global_position, stopped_camera, "cancel must stop writing camera transforms")
		if exit_tree:
			transition.free()
		fixture.host.free()


func _test_participant_exit_cancels_transition() -> void:
	var fixture := _new_fixture()
	var transition: Node = fixture.transition
	var room_count := [0]
	var finished_count := [0]
	transition.room_requested.connect(func() -> void: room_count[0] += 1)
	transition.finished.connect(func() -> void: finished_count[0] += 1)
	_begin(fixture)
	fixture.door.free()
	await create_timer(0.5).timeout
	_assert_true(not transition.is_active() and _overlay(fixture) == null, "unexpected old-door removal must cancel and clean up")
	_assert_true(room_count[0] == 0 and finished_count[0] == 0, "invalidated participant must not produce a room change")
	fixture.host.free()


func _test_cancelled_owner_notification() -> void:
	var probe := _new_fixture()
	var available: bool = probe.transition.has_signal("cancelled")
	_assert_true(available, "an interrupted transition must expose cancelled so its owner can release input and retry")
	probe.host.free()
	if not available:
		return
	for scenario in ["explicit", "silent", "participant", "request_rejected", "tree_exit", "finished", "idle"]:
		var fixture := _new_fixture(0.05)
		var transition: Node = fixture.transition
		var cancelled_count := [0]
		var finished_count := [0]
		var room_count := [0]
		var clean_before_notification := [false]
		transition.connect("cancelled", func() -> void:
			cancelled_count[0] += 1
			clean_before_notification[0] = not transition.is_active() and _overlay(fixture) == null and fixture.door.get_signal_connection_list("opened").is_empty()
		)
		transition.finished.connect(func() -> void: finished_count[0] += 1)
		transition.room_requested.connect(func() -> void: room_count[0] += 1)
		if scenario != "idle":
			_assert_true(_begin(fixture), "cancel notification fixture starts: %s" % scenario)
		match scenario:
			"explicit":
				transition.cancel()
				transition.cancel()
			"silent":
				transition.cancel(false)
			"participant":
				fixture.host.remove_child(fixture.camera)
			"request_rejected":
				fixture.door.set_locked(true)
				await create_timer(0.5).timeout
			"tree_exit":
				fixture.host.remove_child(transition)
			"finished":
				await _wait_until(func() -> bool: return finished_count[0] == 1, 2.0, "successful transition finishes normally")
			"idle":
				transition.cancel()
		await process_frame
		var should_notify: bool = scenario in ["explicit", "participant", "request_rejected"]
		_assert_true(cancelled_count[0] == (1 if should_notify else 0), "%s reports only its expected cancelled notification" % scenario)
		if should_notify:
			_assert_true(clean_before_notification[0], "cancel cleans camera/door bindings and cover before notifying the owner: %s" % scenario)
		_assert_true(finished_count[0] == (1 if scenario == "finished" else 0), "cancelled is separate from successful finished: %s" % scenario)
		_assert_true(room_count[0] == (1 if scenario == "finished" else 0), "cancellation never commits a room transfer: %s" % scenario)
		_assert_true(not transition.is_active(), "terminal lifecycle leaves transition idle: %s" % scenario)
		if scenario == "participant":
			fixture.camera.free()
		if scenario == "tree_exit":
			transition.free()
		fixture.host.free()


func _new_fixture(door_duration: float = 0.2) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var camera := Camera3D.new()
	host.add_child(camera)
	camera.position = Vector3(0.0, 1.5, 4.0)
	var ui := Control.new()
	host.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var pivot := Node3D.new()
	host.add_child(pivot)
	var body := StaticBody3D.new()
	host.add_child(body)
	var blocker := CollisionShape3D.new()
	blocker.shape = BoxShape3D.new()
	body.add_child(blocker)
	var door: Node3D = _door_script.new()
	host.add_child(door)
	door.bind(pivot, blocker, 90.0, door_duration)
	door.set_locked(false)
	var transition: Node = _transition_script.new()
	host.add_child(transition)
	return {"host": host, "camera": camera, "ui": ui, "door": door, "pivot": pivot, "transition": transition}


func _begin(fixture: Dictionary) -> bool:
	return fixture.transition.begin(fixture.camera, fixture.ui, fixture.door, CAMERA_DESTINATION, LOOK_TARGET)


func _overlay(fixture: Dictionary) -> ColorRect:
	for child in fixture.ui.get_children():
		if child is ColorRect and not child.is_queued_for_deletion():
			return child as ColorRect
	return null


func _wait_until(predicate: Callable, timeout_seconds: float, message: String) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	_assert_true(predicate.call(), message)


func _assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) < 0.001, "%s (expected %.3f, got %.3f)" % [message, expected, actual])


func _assert_vector(actual: Vector3, expected: Vector3, message: String) -> void:
	_assert_true(actual.distance_to(expected) < 0.001, "%s (expected %s, got %s)" % [message, expected, actual])
