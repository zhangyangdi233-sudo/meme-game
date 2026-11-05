extends SceneTree
## The slip under a post button: the player's last post, red when the world obeyed it and green when it did not. A
## green slip also says to try again (#125), and says why when pollution voided the sentence.

const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PostSlipScript = preload("res://scripts/ui/post_slip.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_no_post_shows_nothing()
	test_a_red_post_asks_for_nothing_more()
	test_a_green_post_asks_to_try_again()
	test_a_voided_post_says_pollution_stopped_it()
	if _failures.is_empty():
		print("post slip tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_no_post_shows_nothing() -> void:
	var parent := _slip_for({})
	_assert_eq(parent.get_child_count(), 0, "no post should add no slip")
	parent.free()


func test_a_red_post_asks_for_nothing_more() -> void:
	var parent := _slip_for({"kind": "free_sentence", "text": "门是出口", "tier": "rule"})
	var slip := parent.find_child("LastPostSlip", true, false) as Label
	_assert_true(slip != null and slip.text.contains("门是出口"), "a red post should show on the slip")
	_assert_true(parent.find_child("PostRetryHint", true, false) == null, "a red post should not ask to try again")
	parent.free()


func test_a_green_post_asks_to_try_again() -> void:
	for tier in ["misread", "noise"]:
		var parent := _slip_for({"kind": "free_sentence", "text": "我你", "tier": tier})
		var hint := parent.find_child("PostRetryHint", true, false) as Label
		_assert_true(hint != null, "a %s post should ask to try again" % tier)
		_assert_eq(hint.text if hint != null else "", PostSlipScript.MISSED_LINE, "a %s post should say nothing answered" % tier)
		parent.free()


func test_a_voided_post_says_pollution_stopped_it() -> void:
	var parent := _slip_for({"kind": "free_sentence", "text": "房间不亮", "tier": "misread", "voided": true})
	var hint := parent.find_child("PostRetryHint", true, false) as Label
	_assert_eq(hint.text if hint != null else "", PostSlipScript.VOIDED_LINE, "a voided post should say pollution stopped it")
	parent.free()


func _slip_for(post: Dictionary) -> VBoxContainer:
	var parent := VBoxContainer.new()
	PostSlipScript.add_to(parent, post, GameUiThemeScript.new())
	return parent


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
