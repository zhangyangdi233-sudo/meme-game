extends SceneTree

const HandTrackingStatusScript = preload("res://framework/integrations/hand_tracking_status.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_display_text_covers_all_statuses()
	_test_error_classification()
	_test_ready_source_clearing()
	if _failures.is_empty():
		print("hand tracking status tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


var _failures: Array[String] = []


func _test_display_text_covers_all_statuses() -> void:
	for status in HandTrackingStatusScript.Status.values():
		var text := HandTrackingStatusScript.display_text(status)
		_assert_true(not text.is_empty(), "status %d should map to Chinese display text" % int(status))
	_assert_eq(
		HandTrackingStatusScript.display_text(HandTrackingStatusScript.Status.PERMISSION_DENIED),
		"摄像头不可用或权限被拒绝",
		"permission denial should keep the established Chinese copy"
	)


func _test_error_classification() -> void:
	for status in [
		HandTrackingStatusScript.Status.PORT_UNAVAILABLE,
		HandTrackingStatusScript.Status.PROTOCOL_MISMATCH,
		HandTrackingStatusScript.Status.MISSING_HELPER,
		HandTrackingStatusScript.Status.MISSING_MODEL,
		HandTrackingStatusScript.Status.MISSING_MEDIAPIPE,
		HandTrackingStatusScript.Status.SIDECAR_LAUNCH_FAILED,
		HandTrackingStatusScript.Status.PERMISSION_DENIED,
		HandTrackingStatusScript.Status.TRACKER_ERROR,
	]:
		_assert_true(
			HandTrackingStatusScript.is_error(status),
			"status %d should count as a blocking camera error" % int(status)
		)
	_assert_true(
		not HandTrackingStatusScript.is_error(HandTrackingStatusScript.Status.WAITING_FOR_HANDS),
		"waiting for hands should not be treated as an error"
	)


func _test_ready_source_clearing() -> void:
	for status in [
		HandTrackingStatusScript.Status.PERMISSION_DENIED,
		HandTrackingStatusScript.Status.TRACKER_ERROR,
		HandTrackingStatusScript.Status.SIDECAR_LAUNCH_FAILED,
	]:
		_assert_true(
			HandTrackingStatusScript.clears_ready_source(status),
			"status %d should clear the ready camera source" % int(status)
		)
	_assert_true(
		not HandTrackingStatusScript.clears_ready_source(HandTrackingStatusScript.Status.MISSING_MODEL),
		"missing model should not clear a previously ready source"
	)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
