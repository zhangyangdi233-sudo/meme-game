extends SceneTree
## The narrator's voice node: the approved samples load from their wav files, one blip sounds per spoken character on
## the old version's schedule (sample index, interval, gain), punctuation and spaces are silent and pause the line,
## a stalled frame never catches up, and stop or pause drops the rest of the line with no backlog.
## Does not load the main scene.

const NarrationBlipsScript = preload("res://scripts/audio/narration_blips.gd")
const SOURCES_PATH := "res://assets/audio/dialogue/voice_sources.json"

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	if _failures.is_empty():
		print("narration blips tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_samples_are_the_approved_originals()
	await _test_schedule_of_a_line()
	await _test_silent_characters_and_pauses()
	await _test_gain_and_voice_settings()
	await _test_a_stalled_frame_does_not_catch_up()
	await _test_stop_and_pause_leave_no_backlog()
	# Headless frames can end before the audio thread releases stopped playbacks.
	await create_timer(0.15).timeout
	await process_frame


func _voice() -> Node:
	var voice := NarrationBlipsScript.new()
	root.add_child(voice)
	_heard.clear()
	voice.blip_played.connect(func(character: String, sample_index: int) -> void: _heard.append([character, sample_index]))
	return voice


func _release(voice: Node) -> void:
	voice.free()
	await process_frame


func _test_samples_are_the_approved_originals() -> void:
	var sources := JSON.parse_string(FileAccess.get_file_as_string(SOURCES_PATH)) as Dictionary
	var hashes := {}
	for asset: Dictionary in sources.get("assets", []):
		hashes["res://assets/audio/dialogue/" + str(asset.get("path"))] = str(asset.get("sha256"))
	_assert_eq(NarrationBlipsScript.SAMPLE_PATHS.size(), 6, "the narrator should have six samples")
	for path: String in NarrationBlipsScript.SAMPLE_PATHS:
		_assert_eq(FileAccess.get_sha256(path), hashes.get(path, "missing"), "%s should be the approved original recorded in voice_sources.json" % path)


func _test_schedule_of_a_line() -> void:
	var voice := _voice()
	voice.speak("你好，世界。")
	voice.set_process(false)
	var count := NarrationBlipsScript.SAMPLE_PATHS.size()
	_assert_eq(_heard.size(), 1, "the first character should sound at once")
	_assert_eq(_heard[0], ["你", ("你".unicode_at(0) + 0 * 5) % count], "the sample index should be (unicode + index*5) % 6")
	voice.tick(0.129)
	_assert_eq(_heard.size(), 1, "the next character should wait out 0.130 s")
	voice.tick(0.002)
	_assert_eq(_heard[1], ["好", ("好".unicode_at(0) + 1 * 5) % count], "the second character should follow after its interval")
	# The comma at index 2 is silent and holds the line for 0.24 s; the interval of index 1 is 0.130 * 0.95.
	voice.tick(0.130 * 0.95 + 0.001)
	_assert_eq(_heard.size(), 2, "a comma should sound nothing")
	voice.tick(0.239)
	_assert_eq(_heard.size(), 2, "a comma should pause the line for 0.24 s")
	voice.tick(0.002)
	_assert_eq(_heard[2], ["世", ("世".unicode_at(0) + 3 * 5) % count], "the character after a comma should sound once the pause ends")
	# 世 is index 3: interval 0.130 * 1.08.
	voice.tick(0.130 * 1.08 + 0.001)
	_assert_eq(_heard[3], ["界", ("界".unicode_at(0) + 4 * 5) % count], "the last character should sound")
	_assert_true(voice.is_speaking(), "the line is not over while its final pause is pending")
	voice.tick(0.130 * 0.98 + 0.001)
	voice.tick(0.421)
	_assert_eq(_heard.size(), 4, "a full stop should sound nothing")
	_assert_true(not voice._active, "a finished line should not keep scheduling or loop")
	await _release(voice)


func _test_silent_characters_and_pauses() -> void:
	var pauses := {"，": 0.24, "、": 0.24, ",": 0.24, "；": 0.24, ";": 0.24, "：": 0.24, ":": 0.24, "。": 0.42, ".": 0.42, "？": 0.43, "?": 0.43, "！": 0.38, "!": 0.38, "…": 0.40, "‥": 0.40, "—": 0.40, "–": 0.40, "「": 0.0, " ": 0.0}
	for character: String in pauses:
		_assert_true(is_equal_approx(NarrationBlipsScript._punctuation_pause(character), float(pauses[character])), "%s should pause %s s" % [character, str(pauses[character])])
	var voice := _voice()
	voice.speak("「 a")
	voice.set_process(false)
	# The opening quote and the space are silent with no pause: the first sound is 'a' at index 2.
	_assert_eq(_heard.size(), 1, "quotes and spaces should add no blip and no pause")
	_assert_eq(_heard[0][0], "a", "the first character that sounds is the first letter")
	await _release(voice)
	voice = _voice()
	voice.speak("？？？")
	voice.set_process(false)
	_assert_eq(_heard.size(), 0, "a line of punctuation should never sound")
	await _release(voice)


func _test_gain_and_voice_settings() -> void:
	var voice := _voice()
	voice.speak("你好")
	voice.set_process(false)
	var player := voice._player as AudioStreamPlayer
	_assert_true(player.playing, "a blip should play on the voice player")
	_assert_eq(player.max_polyphony, 1, "the voice should never overlap itself")
	_assert_true(is_equal_approx(player.pitch_scale, 1.0), "the blip should keep the approved pitch")
	_assert_eq(player.bus, &"Master", "the voice should sit on the master bus")
	_assert_true(is_equal_approx(player.volume_db, linear_to_db(0.88 * 0.87)), "the first blip's gain should be 0.88 * 0.87")
	for index in 12:
		var gain: float = NarrationBlipsScript._gain_for(index)
		_assert_true(gain >= 0.88 * 0.87 - 0.0001 and gain <= 1.0 * 0.87 + 0.0001, "the gain should stay in the old range at index %d" % index)
	_assert_true(is_equal_approx(NarrationBlipsScript._gain_for(1), (0.88 + 0.12 * pow(sin(1.31), 2.0)) * 0.87), "the gain should follow the old formula")
	await _release(voice)


func _test_a_stalled_frame_does_not_catch_up() -> void:
	var voice := _voice()
	voice.speak("甲乙丙丁")
	voice.set_process(false)
	voice.tick(90.0)
	_assert_eq(_heard.size(), 2, "a stalled frame should emit one new blip, not catch up")
	await _release(voice)


func _test_stop_and_pause_leave_no_backlog() -> void:
	var voice := _voice()
	voice.speak("甲乙丙丁")
	voice.set_process(false)
	voice.stop()
	voice.tick(100.0)
	_assert_eq(_heard.size(), 1, "stop should cancel the rest of the line")
	_assert_true(not voice.is_speaking(), "a stopped voice should not be speaking")
	_heard.clear()
	voice.speak("暂停时")
	voice.set_process(false)
	voice.set_paused(true)
	voice.tick(100.0)
	_assert_true(not voice.is_speaking(), "pausing should stop the line in progress")
	voice.speak("后台的新句")
	_assert_eq(_heard.size(), 1, "a line spoken while paused should stay silent")
	voice.set_paused(false)
	voice.tick(100.0)
	_assert_eq(_heard.size(), 1, "resuming should not replay or queue the missed narration")
	_assert_true(not voice.is_speaking(), "nothing should be speaking after resuming")
	voice.speak("新句")
	voice.set_process(false)
	_assert_eq(_heard.size(), 2, "after resuming a new line should speak")
	await _release(voice)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
