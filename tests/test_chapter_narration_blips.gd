extends SceneTree

const Voice = preload("res://scripts/audio/chapter_narration_blips.gd")
const Narration = preload("res://scripts/ui/chapter_opening_narration.gd")
const SAMPLE_HASHES := [
	"fb12dd627cb04d200a6981d0fc0445f9eb1c914187e475170348d12fed32977d",
	"969e33a00a81a4d16a82cec4b60af76fc86b839611870e22dfd2b831ab1abf46",
	"be93e3c2ff7b500388eb488f30d36b1f5973d5c61f9af2d0f61b29e98e162acf",
	"9f7c38438ae6e41000acc0e7dfaf7117f3908b2a3b7e8965be99d26e4d5cc13c",
	"56d3a23520545bfda9e63acc45ad9578c9cd1c36dff6e4ea7636ff70221ee5ae",
	"50b942f65b0839da66cbb4714f61305341c7e04a8a3f9bf412d226fe1bedfa83",
]

var failures: Array[String] = []
var heard: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	for index in Voice.SAMPLE_PATHS.size():
		_check(FileAccess.get_sha256(Voice.SAMPLE_PATHS[index]) == SAMPLE_HASHES[index], "voice 03 sample %d remains the approved original" % (index + 1))
	var voice := Voice.new()
	root.add_child(voice)
	voice.blip_played.connect(func(character: String, _index: int): heard.append(character))
	voice.play_line("「你好。」 世界！")
	voice.set_process(false)
	_check(heard == ["你"], "opening quotation stays silent and first character starts immediately")
	voice.tick(0.14)
	_check(heard == ["你", "好"], "next character follows the narration cadence")
	voice.tick(0.14)
	voice.tick(0.20)
	_check(heard.size() == 2, "sentence punctuation adds silence")
	voice.tick(0.23)
	_check(heard == ["你", "好", "世"], "closing quotation and whitespace never make a blip")
	voice.tick(0.15)
	voice.tick(0.15)
	voice.tick(0.40)
	_check(heard == ["你", "好", "世", "界"], "punctuation adds no events through the end of the line")
	_check(not voice._active, "completed narration does not loop")
	_check(voice._player.bus == "Master" and voice._player.max_polyphony == 1 and is_equal_approx(voice._player.pitch_scale, 1.0), "approved samples use the existing master volume without pitch changes or overlapping voices")

	heard.clear()
	voice.play_line("甲乙丙丁")
	voice.set_process(false)
	voice.tick(90.0)
	_check(heard == ["甲", "乙"], "a stalled frame emits at most one new blip instead of catching up")
	voice.play_line("新句")
	voice.set_process(false)
	voice.tick(0.14)
	_check(heard == ["甲", "乙", "新", "句"], "advancing interrupts the previous sentence immediately")
	voice.stop()
	voice.tick(100.0)
	_check(not voice.is_speaking() and heard.size() == 4, "stop silences playback and cancels all pending characters")
	voice.play_line("暂停时不积压")
	voice.set_paused(true)
	var before := heard.size()
	voice.tick(100.0)
	voice.play_line("后台的新句")
	voice.set_paused(false)
	voice.tick(100.0)
	_check(heard.size() == before and not voice.is_speaking(), "pause and resume do not replay or queue background narration")
	voice.free()

	heard.clear()
	var panel := Narration.new()
	root.add_child(panel)
	panel._blips.blip_played.connect(func(character: String, _index: int): heard.append(character))
	panel.show()
	panel.show_line(1, "你好", "点击鼠标或触摸板继续")
	panel._blips.set_process(false)
	for frame in 20:
		panel.show_line(1, "你好", "点击鼠标或触摸板继续")
	_check(heard == ["你"] and panel.line_label.text == "你好", "per-frame refresh never restarts audio or changes whole-line text")
	panel.show_line(2, "また", "クリックで次へ")
	panel._blips.set_process(false)
	_check(heard == ["你", "ま"], "a new manually advanced line starts its own audio immediately")
	panel.hide()
	panel.show()
	panel.show_line(2, "また", "クリックで次へ")
	panel._blips.tick(100.0)
	_check(heard.size() == 2 and not panel._blips.is_speaking(), "hiding for settings discards current audio and showing the same line stays quiet")
	panel.show_line(2, "看来", "点击鼠标或触摸板继续")
	panel._blips.set_process(false)
	_check(heard == ["你", "ま", "看"], "changing language replaces the current voice sequence")
	panel.set_audio_paused(true)
	panel._blips.tick(100.0)
	panel.set_audio_paused(false)
	panel.show_line(2, "看来", "点击鼠标或触摸板继续")
	_check(heard.size() == 3 and not panel._blips.is_speaking(), "host focus pause stops voice without a backlog on return")
	panel.show_line(3, "最后", "点击鼠标或触摸板继续")
	var released_voice = panel._blips
	panel.free()
	_check(not is_instance_valid(released_voice), "leaving the scene frees the voice player with the narration panel")
	# Headless frames can finish before the audio mixing thread processes its
	# stopped playbacks. Let the audio server release them before tree shutdown.
	await create_timer(0.15).timeout
	await process_frame
	await process_frame

	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter narration blips tests passed")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
