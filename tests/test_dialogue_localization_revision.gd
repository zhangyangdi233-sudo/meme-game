extends SceneTree

const Locale = preload("res://scripts/localization/game_locale.gd")
const Content = preload("res://scripts/narrative/language_corruption_content.gd")
const Opening = preload("res://scripts/narrative/chapter_opening_content.gd")
const State = preload("res://scripts/meme_game_state.gd")
const Journey = preload("res://scripts/progression/floor_two_journey.gd")
const AUTHORED_ZH_OPENING := [
	"你好", "看来你又一次遗忘了我……", "哎……", "这是常有的事", "我告诉过你",
	"但你总是意气用事", "我多么努力的帮你理智的做着决定", "可是它……", "每次都在关键时刻", "把我关起来",
	"看来……", "你也被它关起来了", "没事……", "我能帮你如何出去", "因为这一切都只是你自己创造的幻觉",
	"按理来说", "其实你比我更了解这里", "我知道你现在在想什么", "你在想……", "“这个旁白是谁啊”",
	"“我为啥说不出话”", "“我就是想体验一下这个’游戏’”", "“它在这里指指点点是什么意思”", "请记住",
	"你的目标是逃出这里", "你才是这具身体的“主人”", "（游戏中出现敲门声）", "看来你潜意识已经准备好了", "去吧！", "埃弥亣……",
]
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var locale = Locale.new()
	for index in AUTHORED_ZH_OPENING.size():
		_check(Opening.LINES[str(index + 1)].zh == AUTHORED_ZH_OPENING[index], "Chinese opening manuscript stays verbatim at line %d" % (index + 1))
	var sentence := "はじめに、でんわで話す。"
	var units: Array[String] = Locale.split_dialogue_units(sentence, "ja-JP")
	_check(units.size() == sentence.length() and "".join(units) == sentence, "Japanese typing preserves text and advances one character per key")
	for unit in units:
		_check(unit.length() == 1, "every Japanese typing unit contains exactly one character")
	locale.set_locale("ja")
	_check(locale.pickable_units("存在しない13階") == ["存在", "しない", "13階"], "dialogue changes do not change the lexical pickup pool")
	var sources: Array[String] = []
	for value in [Content.REALITY_DIALOGUES_BY_FLOOR, Content.REALITY_FOLLOWUPS_BY_NPC_INDEX, Content.KEY_NPC_DIALOGUES_BY_FLOOR, Content.DOLL_ENCOUNTERS_BY_FLOOR]:
		_collect_dialogue_sources(value, sources)
	for progress in [{}, {"accepted": true}, {"accepted": true, "visited_turn_ids": ["turn_1", "turn_2"]}, {"accepted": true, "visited_turn_ids": ["turn_1", "turn_2"], "map_unlocked": true}]:
		for actor_id in ["floor2_wayfinder", "floor2_cartographer"]:
			_collect_dialogue_sources(Journey.dialogue_for(actor_id, progress), sources)
	for code in ["en", "ja"]:
		locale.set_locale(code)
		for source in sources:
			var translated: String = locale.translate(source)
			_check(translated != source and not translated.is_empty(), "%s translates authored dialogue: %s" % [code, source])
			if code == "en":
				_check(not locale.has_untranslated_han(translated), "English dialogue has no untranslated Chinese")
		for number in range(1, 31):
			if not Opening.is_spoken_line(number):
				continue
			_check(Opening.line_text(number, code) != Opening.line_text(number, "zh"), "%s opening line %d uses the translated manuscript" % [code, number])
	var state = State.new()
	state.new_run()
	state.pollution = 100
	state.completed_memes = [{"title": "一整段旧句子"}]
	state.start_typed_reality_conversation("floor_1_npc0", "npc", "住户")
	state.configure_conversation_locale("ja")
	state.conversation_choices = [{"id": "ja", "sentence": sentence}]
	state.select_typed_reality_choice("ja")
	for index in sentence.length():
		var result: Dictionary = state.advance_typed_reality_character()
		_check(result.advanced and state.conversation_reveal_index == index + 1, "Japanese advances exactly one unit even with corruption")
		if index < state.conversation_revealed_units.size():
			_check(str(state.conversation_revealed_units[index].display).length() == 1, "corruption never inserts a multi-character chunk into Japanese typing")
	await _test_real_language_selection()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("dialogue localization revision tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)

func _collect_dialogue_sources(value: Variant, result: Array[String]) -> void:
	if value is Array:
		for child in value:
			_collect_dialogue_sources(child, result)
	elif value is Dictionary:
		for key in value:
			if key in ["line", "result", "sentence", "interrupt", "failure_line", "success_line", "guide_feedback", "speaker", "actor_label", "repeat_line"] and value[key] is String:
				var source: String = value[key]
				if not source.is_empty() and source not in result:
					result.append(source)
			else:
				_collect_dialogue_sources(value[key], result)

func _test_real_language_selection() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	_check(main.has_method("start_chapter1_game"), "the actual game scene compiles for language selection")
	if not main.has_method("start_chapter1_game"):
		main.free()
		return
	main._save_path = "user://test_dialogue_localization_revision.dat"
	main._locale.preferences_path = "user://test_dialogue_localization_revision.cfg"
	main._camera_session_decided = true
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._on_language_selected("ja")
	main.start_chapter1_game()
	await process_frame
	main._animate_world(2.1)
	main._refresh_chapter_opening_narration()
	_check(main._locale.current_locale == "ja", "starting a new game retains the selected Japanese locale")
	_check(main._chapter_opening_narration.line_label.text == Opening.line_text(1, "ja"), "the actual white-door overlay shows the Japanese manuscript")
	main._on_language_selected("en")
	main._refresh_chapter_opening_narration()
	_check(main._chapter_opening_narration.line_label.text == Opening.line_text(1, "en"), "the actual white-door overlay refreshes to English")
	main._set_reality_mouse_look(false)
	main.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
