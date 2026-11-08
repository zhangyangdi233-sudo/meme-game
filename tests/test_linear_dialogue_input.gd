extends SceneTree
## Which key presses type the next unit of a conversation line, and how long an NPC's reply stays before the
## conversation moves on by itself.

const TypingKeysScript = preload("res://scripts/game/typing_keys.gd")
const ReplyClockScript = preload("res://scripts/game/conversation_reply_clock.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_text_keys_type_a_unit()
	test_arrows_modifiers_and_repeats_do_not_type()
	test_a_reply_waits_by_its_length()
	test_a_paused_reply_does_not_run_out()
	if _failures.is_empty():
		print("linear dialogue input tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_text_keys_type_a_unit() -> void:
	_assert_true(TypingKeysScript.types_a_unit(_key(KEY_A, "a".unicode_at(0))), "a letter should type")
	_assert_true(TypingKeysScript.types_a_unit(_key(KEY_7, "7".unicode_at(0))), "a digit should type")
	_assert_true(TypingKeysScript.types_a_unit(_key(KEY_SPACE, 32)), "space should type")
	_assert_true(TypingKeysScript.types_a_unit(_key(KEY_COMMA, ",".unicode_at(0))), "punctuation should type")
	_assert_true(TypingKeysScript.types_a_unit(_key(KEY_F, 0)), "a letter key held by an input method should still type")
	var shifted := _key(KEY_A, "A".unicode_at(0))
	shifted.shift_pressed = true
	_assert_true(TypingKeysScript.types_a_unit(shifted), "a shifted letter should type")


func test_arrows_modifiers_and_repeats_do_not_type() -> void:
	for keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_TAB, KEY_ENTER, KEY_ESCAPE, KEY_F9, KEY_BACKSPACE]:
		_assert_true(not TypingKeysScript.types_a_unit(_key(keycode, 0)), "key %s should not type" % OS.get_keycode_string(keycode))
	var repeat := _key(KEY_A, "a".unicode_at(0))
	repeat.echo = true
	_assert_true(not TypingKeysScript.types_a_unit(repeat), "a held key's repeat should not type")
	var release := _key(KEY_A, "a".unicode_at(0))
	release.pressed = false
	_assert_true(not TypingKeysScript.types_a_unit(release), "a release should not type")
	var shortcut := _key(KEY_C, "c".unicode_at(0))
	shortcut.ctrl_pressed = true
	_assert_true(not TypingKeysScript.types_a_unit(shortcut), "a ctrl shortcut should not type")
	var alt := _key(KEY_X, "x".unicode_at(0))
	alt.alt_pressed = true
	_assert_true(not TypingKeysScript.types_a_unit(alt), "an alt combination should not type")


func test_a_reply_waits_by_its_length() -> void:
	var short: float = ReplyClockScript.reading_seconds("好。")
	var long: float = ReplyClockScript.reading_seconds("护灯人把手从灯杆上拿开，等你把名字说完整。他没有再说别的，只把灯罩转回原处。")
	_assert_true(short >= 2.0, "even a short reply should stay long enough to read")
	_assert_true(long > short + 2.0, "a longer reply should stay longer")
	var english: float = ReplyClockScript.reading_seconds("The lamp keeper lifts his hand from the post and waits for you to finish the name.")
	_assert_true(english > short, "a long English reply should stay longer than a short one")
	var clock := ReplyClockScript.new()
	clock.begin("好。")
	_assert_true(clock.is_running(), "a begun reply should be running")
	_assert_true(not clock.advance(short - 0.1, false), "the reply should still show just before its time")
	_assert_true(clock.advance(0.2, false), "the reply should run out once its time passed")
	_assert_true(not clock.is_running(), "a finished reply should stop")
	_assert_true(not clock.advance(10.0, false), "a finished reply should report once")


func test_a_paused_reply_does_not_run_out() -> void:
	var clock := ReplyClockScript.new()
	clock.begin("好。")
	_assert_true(not clock.advance(60.0, true), "a paused reply should not run out")
	_assert_true(clock.is_running(), "a paused reply should keep waiting")
	clock.cancel()
	_assert_true(not clock.is_running(), "a cancelled reply should stop")
	_assert_true(not clock.advance(60.0, false), "a cancelled reply should never report")


func _key(keycode: Key, unicode: int) -> InputEventKey:
	var key := InputEventKey.new()
	key.keycode = keycode
	key.physical_keycode = keycode
	key.unicode = unicode
	key.pressed = true
	return key


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
