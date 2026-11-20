extends SceneTree
## The slip under a post button: the player's last post, red when the world obeyed it and green when it did not. A
## green slip also says to try again (#125), and says why when pollution voided the sentence.

const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PostSlipScript = preload("res://scripts/ui/post_slip.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_no_post_shows_nothing()
	test_a_red_post_asks_for_nothing_more()
	test_a_green_post_asks_to_try_again()
	test_a_voided_post_says_pollution_stopped_it()
	test_the_slip_shows_only_a_post_in_the_language_shown()
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


## The planner's 2026-11-20 report: after a switch to Japanese the slip showed the earlier language's text. A post
## written in zh shows nothing once the language is ja; a post written in ja shows; a record without `content_locale`
## counts as zh.
func test_the_slip_shows_only_a_post_in_the_language_shown() -> void:
	var game = StateScript.new()
	game.new_run()
	_assert_true(game.jump_to_basement_round(1), "setup should reach round one")
	game.free_sentence_units = ["房", "间", "亮"]
	game.submit_free_sentence("zh")
	var progress: Dictionary = game.chapter_one_progress
	_assert_eq(str(PostSlipScript.latest(game.published_memes, progress, "zh").get("text", "")), "房间亮", "a zh post should show while zh is shown")
	_assert_true(PostSlipScript.latest(game.published_memes, progress, "ja").is_empty(), "a zh post should not show once ja is shown")
	var parent := _slip_for(PostSlipScript.latest(game.published_memes, progress, "ja"))
	_assert_eq(parent.get_child_count(), 0, "the ja slip should be empty after a zh post")
	parent.free()
	game.free_sentence_units = ["わたし", "あなた"]
	game.submit_free_sentence("ja")
	var ja_post: Dictionary = PostSlipScript.latest(game.published_memes, progress, "ja")
	_assert_eq(str(ja_post.get("text", "")), "わたしあなた", "a ja post should show while ja is shown")
	parent = _slip_for(ja_post)
	var slip := parent.find_child("LastPostSlip", true, false) as Label
	_assert_true(slip != null and slip.text.contains("わたしあなた"), "the ja slip should show the ja post")
	parent.free()
	_assert_eq(str(PostSlipScript.latest(game.published_memes, progress, "zh").get("text", "")), "房间亮", "switching back to zh should show the zh post again")
	var old_record := [{"kind": "free_sentence", "text": "灯亮", "tier": "rule", "round": 1}]
	_assert_true(not PostSlipScript.latest(old_record, progress, "zh").is_empty(), "a record without content_locale should count as zh")
	_assert_true(PostSlipScript.latest(old_record, progress, "ja").is_empty(), "a record without content_locale should not show in ja")
	_assert_true(not PostSlipScript.latest(game.published_memes, progress).is_empty(), "without a locale any language counts (the narrator's step)")


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
