extends SceneTree
## The phone's social feed scrolls like a phone (#147): the wheel reaches the bottom in a few notches, a drag
## scrolls the feed, and a card opens on a tap but not at the end of a drag.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")

const STEP := 1.0 / 60.0
const MAX_NOTCHES_TO_BOTTOM := 10

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	await _test_the_wheel_reaches_the_bottom_of_the_feed()
	await _test_a_tap_on_a_card_opens_its_post()
	await _test_a_drag_over_a_card_scrolls_without_opening_it()
	if _failures.is_empty():
		print("social feed scroll tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_the_wheel_reaches_the_bottom_of_the_feed() -> void:
	var game_root := await _boot_feed()
	if game_root == null:
		return
	var scroll := _feed_scroll(game_root)
	var kinetic := _kinetic(scroll)
	if kinetic == null:
		await _free(game_root)
		return
	var bar := scroll.get_v_scroll_bar()
	var max_scroll := int(bar.max_value - bar.page)
	_assert_true(max_scroll > int(bar.page), "the feed should be longer than two pages for this test to mean much")
	var center := scroll.get_global_rect().get_center()
	var notches := 0
	while scroll.scroll_vertical < max_scroll and notches < 200:
		root.push_input(_wheel(center))
		_settle(kinetic)
		notches += 1
	_assert_true(
		notches <= MAX_NOTCHES_TO_BOTTOM,
		"the wheel should reach the bottom of the feed in at most %d notches (took %d)" % [MAX_NOTCHES_TO_BOTTOM, notches]
	)
	_assert_eq(scroll.scroll_vertical, max_scroll, "the wheel should reach the very bottom")
	await _free(game_root)


func _test_a_tap_on_a_card_opens_its_post() -> void:
	var game_root := await _boot_feed()
	if game_root == null:
		return
	var social: SocialFeedPanel = game_root._social_feed_panel
	var card := Harness.find_node_by_name(game_root, "SocialPostCard0") as Control
	_assert_true(card != null, "the feed should show the first post's card")
	if card == null:
		await _free(game_root)
		return
	var point := _card_point(card)
	root.push_input(_button(point, true))
	_assert_true(not social.is_detail_open(), "pressing a card should not open it yet; the press may become a drag")
	root.push_input(_button(point, false))
	_assert_true(social.is_detail_open(), "letting go of a tapped card should open its post")
	await _free(game_root)


func _test_a_drag_over_a_card_scrolls_without_opening_it() -> void:
	var game_root := await _boot_feed()
	if game_root == null:
		return
	var social: SocialFeedPanel = game_root._social_feed_panel
	var scroll := _feed_scroll(game_root)
	var card := Harness.find_node_by_name(game_root, "SocialPostCard0") as Control
	if card == null or scroll == null:
		_assert_true(false, "the feed should show its scroll and first card")
		await _free(game_root)
		return
	var start := _card_point(card)
	var finish := start - Vector2(0, 160)
	root.push_input(_button(start, true))
	root.push_input(_motion(start.lerp(finish, 0.5), (finish - start) * 0.5))
	root.push_input(_motion(finish, (finish - start) * 0.5))
	_assert_true(scroll.scroll_vertical >= 150, "dragging up over a card should scroll the feed (got %d)" % scroll.scroll_vertical)
	root.push_input(_button(finish, false))
	_assert_true(not social.is_detail_open(), "letting go at the end of a drag should not open the card")
	await _free(game_root)


func _boot_feed() -> Node:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "the main scene should load")
	if scene == null:
		return null
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	game_root._skip_chapter_one()
	await process_frame
	game_root._on_app_pressed("social")
	await process_frame
	await process_frame
	_assert_true(_feed_scroll(game_root) != null, "the social app should show its feed")
	return game_root


func _feed_scroll(game_root: Node) -> ScrollContainer:
	return Harness.find_node_by_name(game_root, "SocialFeedScroll") as ScrollContainer


func _kinetic(scroll: ScrollContainer) -> KineticScroll:
	var kinetic := scroll.get_node_or_null("KineticScroll") as KineticScroll if scroll != null else null
	_assert_true(kinetic != null, "the feed should scroll through a KineticScroll")
	return kinetic


## A point on the card's poster, away from its like and follow buttons.
func _card_point(card: Control) -> Vector2:
	var rect := card.get_global_rect()
	return rect.position + Vector2(rect.size.x * 0.5, minf(60.0, rect.size.y * 0.3))


func _settle(kinetic: KineticScroll) -> void:
	for i in 600:
		kinetic.advance(STEP)


func _free(game_root: Node) -> void:
	game_root.queue_free()
	await process_frame


func _wheel(at: Vector2) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_WHEEL_DOWN
	event.pressed = true
	event.factor = 1.0
	event.position = at
	event.global_position = at
	return event


func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = at
	event.global_position = at
	return event


func _motion(at: Vector2, relative: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	return event


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(value: Variant, expected: Variant, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(value), str(expected)])
