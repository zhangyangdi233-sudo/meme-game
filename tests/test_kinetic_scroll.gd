extends SceneTree
## KineticScroll: a phone-like vertical scroll on a ScrollContainer (wheel by a share of the page, smooth, drag with fling).

const KineticScrollScript = preload("res://framework/ui/kinetic_scroll.gd")

const PAGE_HEIGHT := 400.0
const CONTENT_HEIGHT := 2000.0
const STEP := 1.0 / 60.0

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(800, 600)
	await _test_a_wheel_notch_scrolls_a_share_of_the_page()
	await _test_the_wheel_glides_instead_of_jumping()
	await _test_the_wheel_reaches_the_bottom_in_a_few_notches()
	await _test_a_touchpad_pan_scrolls_like_the_wheel()
	await _test_dragging_moves_the_content_with_the_pointer()
	await _test_a_small_wobble_is_not_a_drag()
	await _test_a_fling_keeps_going_and_stops_at_the_edge()
	await _test_a_new_press_stops_a_fling()
	await _test_a_drag_held_still_before_release_does_not_fling()
	await _test_a_lost_release_ends_the_drag()
	await _test_a_settled_scroll_leaves_outside_moves_alone()
	if _failures.is_empty():
		print("kinetic scroll tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_a_wheel_notch_scrolls_a_share_of_the_page() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	kinetic.handle_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	_settle(kinetic)
	_assert_true(
		scroll.scroll_vertical >= int(PAGE_HEIGHT * 0.2),
		"one wheel notch should scroll at least a fifth of the page (got %d)" % scroll.scroll_vertical
	)
	kinetic.handle_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	_settle(kinetic)
	_assert_eq(scroll.scroll_vertical, 0, "a notch up should come back to the top")
	await _free(scroll)


func _test_the_wheel_glides_instead_of_jumping() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	kinetic.handle_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	_assert_eq(scroll.scroll_vertical, 0, "the wheel should not jump before a frame passes")
	kinetic.advance(STEP)
	var partway := scroll.scroll_vertical
	_settle(kinetic)
	var target := scroll.scroll_vertical
	_assert_true(partway > 0 and partway < target, "one frame should move partway to the target (%d of %d)" % [partway, target])
	await _free(scroll)


func _test_the_wheel_reaches_the_bottom_in_a_few_notches() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	var max_scroll := int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	var notches := 0
	while scroll.scroll_vertical < max_scroll and notches < 100:
		kinetic.handle_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
		_settle(kinetic)
		notches += 1
	_assert_true(notches <= 20, "four pages of content should take at most 20 notches (took %d)" % notches)
	_assert_eq(scroll.scroll_vertical, max_scroll, "the wheel should reach the bottom exactly")
	await _free(scroll)


func _test_a_touchpad_pan_scrolls_like_the_wheel() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	var pan := InputEventPanGesture.new()
	pan.delta = Vector2(0.0, 1.0)
	kinetic.handle_input(pan)
	_settle(kinetic)
	_assert_true(scroll.scroll_vertical >= 20, "a touchpad pan step should scroll a readable amount (got %d)" % scroll.scroll_vertical)
	await _free(scroll)


func _test_dragging_moves_the_content_with_the_pointer() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	_assert_true(kinetic.handle_input(_press(Vector2(100, 300), true)), "the feed should take the press so the window behind it does not")
	kinetic.handle_input(_motion(Vector2(100, 250), Vector2(0, -50), Vector2.ZERO))
	kinetic.handle_input(_motion(Vector2(100, 150), Vector2(0, -100), Vector2.ZERO))
	_assert_eq(scroll.scroll_vertical, 150, "dragging up 150 px should scroll 150 px at once")
	_assert_true(kinetic.was_dragged(), "a long move should count as a drag")
	kinetic.handle_input(_press(Vector2(100, 150), false))
	_settle(kinetic)
	_assert_eq(scroll.scroll_vertical, 150, "a drag let go without speed should stay where it was")
	_assert_true(kinetic.was_dragged(), "the drag should still be known when the release reaches a card")
	await _free(scroll)


func _test_a_small_wobble_is_not_a_drag() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	kinetic.handle_input(_press(Vector2(100, 300), true))
	kinetic.handle_input(_motion(Vector2(100, 297), Vector2(0, -3), Vector2.ZERO))
	_assert_true(not kinetic.was_dragged(), "a 3 px wobble should still be a tap")
	_assert_eq(scroll.scroll_vertical, 0, "a wobble should not scroll")
	kinetic.handle_input(_press(Vector2(100, 297), false))
	await _free(scroll)


func _test_a_fling_keeps_going_and_stops_at_the_edge() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	var max_scroll := int(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	kinetic.handle_input(_press(Vector2(100, 300), true))
	kinetic.handle_input(_motion(Vector2(100, 200), Vector2(0, -100), Vector2(0, -3000)))
	kinetic.handle_input(_press(Vector2(100, 200), false))
	var at_release := scroll.scroll_vertical
	kinetic.advance(STEP)
	_assert_true(scroll.scroll_vertical > at_release, "a fling should keep scrolling after the release")
	_settle(kinetic)
	var after_fling := scroll.scroll_vertical
	_assert_true(after_fling > at_release + 300, "a fast fling should carry well past the release (%d -> %d)" % [at_release, after_fling])
	_assert_true(after_fling <= max_scroll, "a fling should stop at the bottom")
	_assert_true(kinetic.is_settled(), "a fling should come to rest")

	kinetic.handle_input(_press(Vector2(100, 300), true))
	kinetic.handle_input(_motion(Vector2(100, 200), Vector2(0, -100), Vector2(0, -20000)))
	kinetic.handle_input(_press(Vector2(100, 200), false))
	_settle(kinetic)
	_assert_eq(scroll.scroll_vertical, max_scroll, "a huge fling should stop exactly at the bottom")
	await _free(scroll)


func _test_a_new_press_stops_a_fling() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	kinetic.handle_input(_press(Vector2(100, 300), true))
	kinetic.handle_input(_motion(Vector2(100, 200), Vector2(0, -100), Vector2(0, -2000)))
	kinetic.handle_input(_press(Vector2(100, 200), false))
	kinetic.advance(STEP)
	kinetic.handle_input(_press(Vector2(100, 200), true))
	var caught := scroll.scroll_vertical
	kinetic.advance(STEP)
	kinetic.advance(STEP)
	_assert_eq(scroll.scroll_vertical, caught, "pressing on a moving feed should catch it")
	_assert_true(kinetic.was_dragged(), "a press that caught a moving feed is a scroll, not a tap on what is under it")
	kinetic.handle_input(_press(Vector2(100, 200), false))
	await _free(scroll)


func _test_a_drag_held_still_before_release_does_not_fling() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	kinetic.handle_input(_press(Vector2(100, 300), true))
	kinetic.handle_input(_motion(Vector2(100, 200), Vector2(0, -100), Vector2(0, -2000)))
	for i in 30:
		kinetic.advance(STEP)
	kinetic.handle_input(_press(Vector2(100, 200), false))
	var at_release := scroll.scroll_vertical
	_settle(kinetic)
	_assert_eq(scroll.scroll_vertical, at_release, "a drag held still for half a second should stop where it was let go")
	await _free(scroll)


func _test_a_lost_release_ends_the_drag() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	kinetic.handle_input(_press(Vector2(100, 300), true))
	kinetic.handle_input(_motion(Vector2(100, 200), Vector2(0, -100), Vector2.ZERO))
	var hover := _motion(Vector2(100, 100), Vector2(0, -100), Vector2.ZERO)
	hover.button_mask = 0
	kinetic.handle_input(hover)
	_assert_eq(scroll.scroll_vertical, 100, "moving with no button held should not keep dragging")
	kinetic.handle_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	_settle(kinetic)
	_assert_true(scroll.scroll_vertical > 100, "the wheel should work again after a lost release")
	await _free(scroll)


func _test_a_settled_scroll_leaves_outside_moves_alone() -> void:
	var scroll := await _make_scroll()
	var kinetic := KineticScrollScript.attach(scroll)
	scroll.scroll_vertical = 300
	kinetic.advance(STEP)
	_assert_eq(scroll.scroll_vertical, 300, "a resting scroll should not undo a move made by someone else (focus, a repaint)")
	kinetic.handle_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	_settle(kinetic)
	_assert_true(scroll.scroll_vertical > 300, "the wheel should go on from where the other move left it")
	await _free(scroll)


func _make_scroll() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(300, PAGE_HEIGHT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var content := Control.new()
	content.custom_minimum_size = Vector2(280, CONTENT_HEIGHT)
	scroll.add_child(content)
	root.add_child(scroll)
	await process_frame
	await process_frame
	return scroll


func _free(scroll: ScrollContainer) -> void:
	scroll.queue_free()
	await process_frame


func _settle(kinetic: Node) -> void:
	for i in 600:
		kinetic.advance(STEP)


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.factor = 1.0
	return event


func _press(position: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	return event


func _motion(position: Vector2, relative: Vector2, velocity: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = relative
	event.velocity = velocity
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(value: Variant, expected: Variant, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(value), str(expected)])
