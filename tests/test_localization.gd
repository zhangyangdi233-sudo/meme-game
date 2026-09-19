extends SceneTree

const LocaleScript = preload("res://scripts/localization/game_locale.gd")
const StateScript = preload("res://scripts/meme_game_state.gd")
const UICatalogScript = preload("res://scripts/localization/ui_catalog.gd")
const StateCatalogScript = preload("res://scripts/localization/state_catalog.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("localization tests passed")
		quit(0)
	else:
		for failure in _failures:
			print("localization test failure: %s" % failure)
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_catalog_coverage_and_dynamic_templates()
	_test_all_script_literals_have_translations()
	_test_language_specific_pickup_units()
	_test_japanese_dialogue_units()
	_test_audited_localization_copy()
	_test_english_reality_dialogue_uses_words()
	await _test_language_selection_and_settings_ui()


func _test_catalog_coverage_and_dynamic_templates() -> void:
	var ui_catalog = UICatalogScript.new()
	var state_catalog = StateCatalogScript.new()
	var ui_en: Dictionary = ui_catalog.entries("en")
	var ui_ja: Dictionary = ui_catalog.entries("ja")
	var state_en: Dictionary = state_catalog.entries("en")
	var state_ja: Dictionary = state_catalog.entries("ja")
	_assert_true(ui_en.size() >= 300 and ui_en.size() == ui_ja.size(), "UI catalog should contain matching English and Japanese coverage")
	_assert_true(state_en.size() >= 315 and state_en.size() == state_ja.size(), "state catalog should contain matching English and Japanese coverage")
	_assert_catalog_parity(ui_en, ui_ja, "UI")
	_assert_catalog_parity(state_en, state_ja, "state")
	_assert_catalog_format_signatures(ui_en, ui_ja, "UI")
	_assert_catalog_format_signatures(state_en, state_ja, "state")

	var locale = LocaleScript.new()
	locale.set_locale("en")
	_assert_eq(locale.translate("继续游戏"), "Continue", "English should translate static menu text")
	_assert_eq(locale.translate("污染 47%"), "CORRUPTION 47%", "English should translate formatted HUD values")
	_assert_eq(locale.translate("访客 000014  ·  最后更新 1998-13-05"), "VISITOR 000014  ·  LAST UPDATE 1998-13-05", "English should translate the zero-padded archive counter")
	_assert_eq(locale.translate("关系残留 23 / 100  ·  仍能认出你"), "RELATIONSHIP RESIDUE 23 / 100  ·  They can still recognize you", "dynamic templates should recursively translate nested state labels")
	for value in ui_en.values():
		_assert_true(not locale.has_untranslated_han(str(value)), "English UI catalog values should not retain Han characters: %s" % str(value))
	for value in state_en.values():
		_assert_true(not locale.has_untranslated_han(str(value)), "English state catalog values should not retain Han characters: %s" % str(value))
	locale.set_locale("ja")
	_assert_eq(locale.translate("继续游戏"), "つづきから", "Japanese should translate static menu text naturally")
	_assert_eq(locale.translate("访客 000014  ·  最后更新 1998-13-05"), "訪問者 000014  ·  最終更新 1998-13-05", "Japanese should translate the zero-padded archive counter")
	locale.set_locale("zh")
	_assert_eq(locale.translate("继续游戏"), "继续游戏", "Chinese should remain the source language")


func _test_all_script_literals_have_translations() -> void:
	var locale = LocaleScript.new()
	locale.set_locale("en")
	var literal_regex := RegEx.new()
	literal_regex.compile("\"((?:\\\\.|[^\"\\\\])*)\"")
	var han_regex := RegEx.new()
	han_regex.compile("[\\x{3400}-\\x{9FFF}]")
	var missing: Array[String] = []
	for path in [
		"res://scripts/babel_meme_game.gd",
		"res://scripts/meme_game_state.gd",
		"res://scripts/reality_floor_generator.gd",
		"res://scripts/ui/prologue_panel.gd",
		"res://scripts/ui/ending_screen_panel.gd",
	]:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			missing.append("unable to read %s" % path)
			continue
		var source := file.get_as_text()
		for match_result in literal_regex.search_all(source):
			var literal := match_result.get_string(1).c_unescape()
			if han_regex.search(literal) == null:
				continue
			if locale.translate(literal) == literal and literal not in missing:
				missing.append(literal)
	_assert_true(missing.is_empty(), "every Chinese script literal should have an English catalog entry; missing (%d):\n%s" % [missing.size(), "\n".join(missing)])


func _test_language_specific_pickup_units() -> void:
	var locale = LocaleScript.new()
	locale.set_locale("en")
	_assert_eq(locale.first_pickable_unit("不存在的十三层"), "The", "English pickup should select a word rather than one Latin letter")
	_assert_eq(locale.pickable_units("Don't lose the signal"), ["Don't", "lose", "the", "signal"], "English pickup should keep contractions and whole words")
	locale.set_locale("ja")
	_assert_eq(locale.first_pickable_unit("不存在的十三层"), "存在", "Japanese pickup should select a lexical unit rather than one character")
	_assert_eq(locale.pickable_units("存在しない13階"), ["存在", "しない", "13階"], "Japanese pickup should preserve kanji, kana, and numbered noun units")
	_assert_eq(locale.pickable_units("最終便のエレベーター"), ["最終便", "エレベーター"], "Japanese pickup should keep a full katakana loanword and filter only a standalone particle")
	_assert_eq(locale.pickable_units("はじめ でんわ のぼる"), ["はじめ", "でんわ", "のぼる"], "Japanese pickup should not strip kana that resemble a leading particle")

	var game = StateScript.new()
	game.new_run()
	_assert_true(game.pick_token("localized-post", {
		"id": "word",
		"text": "nonexistent floor",
		"source_text": "不存在的十三层",
		"content_locale": "en",
		"tags": ["空位"],
		"rarity": 1,
	}), "English token pickup should succeed")
	_assert_eq(str(game.notebook_tokens[0].get("text", "")), "nonexistent floor", "English notes should preserve the exact selected phrase")


func _test_japanese_dialogue_units() -> void:
	var locale = LocaleScript.new()
	locale.set_locale("ja")
	var sentence := "はじめに、でんわで話す。"
	var units := locale.dialogue_units(sentence)
	_assert_eq(units, ["はじめに、", "でんわで", "話す。"], "Japanese dialogue should advance by natural language chunks instead of characters")
	_assert_eq(LocaleScript.split_dialogue_units(sentence, "ja-JP"), units, "state code should be able to reuse the locale-aware dialogue splitter statically")
	_assert_eq("".join(units), sentence, "Japanese dialogue units should preserve the complete sentence")
	_assert_true(units.size() < sentence.length(), "Japanese dialogue should require fewer inputs than its character count")


func _test_audited_localization_copy() -> void:
	var ui_catalog = UICatalogScript.new()
	var state_catalog = StateCatalogScript.new()
	var ui_en: Dictionary = ui_catalog.entries("en")
	var ui_ja: Dictionary = ui_catalog.entries("ja")
	var state_en: Dictionary = state_catalog.entries("en")
	var state_ja: Dictionary = state_catalog.entries("ja")
	_assert_true(not state_en.has("把刚才那句再说一遍。不要替它解释。"), "doctor copy should leave the state catalog after moving to the content catalog")
	_assert_true(not state_en.has("你想说一句普通的话。第七层先开口了。"), "epilogue copy should leave the state catalog after moving to the content catalog")
	_assert_true(not ui_en.has("写着“小月亮”的旧名牌"), "prerequisite labels should leave the UI catalog after moving to the content catalog")
	_assert_true(ui_en.has("沿主路往前走，在右侧第一盏不亮的路灯脚边。"), "prerequisite location hints should remain in the UI catalog for event_log")
	_assert_eq(ui_en["进入第一天"], "Enter Day One", "prologue last-page chrome should stay in the UI catalog")
	_assert_eq(ui_en["继续"], "Continue", "prologue continue chrome should stay in the UI catalog")
	_assert_eq(ui_en["塔顶没有人"], "No One Is at the Top of the Tower", "ending title chrome should stay in the UI catalog")
	_assert_eq(ui_en["重开"], "Start Over", "ending restart chrome should stay in the UI catalog")
	_assert_true(ui_en.has("你最后说：\n\n%s\n\n发射机把这个声音送回楼下。\n没有人回答。也许所有人都已经同时说完了。\n（这算是语言结束了吗？）\n指示灯没有提供选项。"), "ending result template should stay in the UI catalog")
	_assert_true(ui_en.has("关系残留 %d / 100  ·  %s"), "ending residue template should stay in the UI catalog")
	_assert_true(ui_en.has("你低头，手机边框从视野下方亮起来。"), "new-game log chrome should stay in the UI catalog")
	_assert_true(ui_en.has("你回到离开时的位置。"), "continue-game log chrome should stay in the UI catalog")
	_assert_true(not ui_en.has("NO SIGNAL  /  DAY 01  /  PRIVATE FREQUENCY"), "diegetic signal headers should not enter the UI catalog")
	_assert_true(not ui_en.has("TRANSMISSION %02d / %02d"), "diegetic transmission counters should not enter the UI catalog")
	_assert_true(not state_en.has("信号商人"), "removed merchant identity should not survive in the state catalog")
	var locale = LocaleScript.new()
	locale.set_locale("zh")
	_assert_eq(locale.level_display_name(1), "第一层", "Chinese level naming should not use the old region label")
	locale.set_locale("en")
	_assert_eq(locale.level_display_name(4), "LEVEL 4", "English hidden level should use the requested LEVEL naming")
	locale.set_locale("ja")
	_assert_eq(locale.level_display_name(3), "レベル3", "Japanese level naming should use the requested レベル form")
	_assert_eq(state_en["你把我放反了。缝口应该朝着路，不是朝着你。……算了。今天要留哪个字？"], "You set me down backward. The seam should face the road, not you. ...Never mind. Which word are we keeping today?", "English doll dialogue should keep its concrete, conversational rhythm")
	_assert_eq(state_ja["缝线布偶"], "縫い目のあるぬいぐるみ", "Japanese should name the guide doll without shop language")
	_assert_eq(ui_ja["塔下施工档案"], "塔のふもとの工事記録", "Japanese archive title should use natural grammar")
	_assert_eq(ui_ja["末班电梯"], "最終便のエレベーター", "Japanese last-elevator copy should describe the final service")
	_assert_eq(ui_ja["抄写员"], "書記官", "Japanese actor title should use a natural role name")
	_assert_eq(state_ja["发布一个只含 1 个语言单位的基础梗"], "一語だけの基本ミームを投稿する", "Japanese pattern copy should use the same lexical-word unit")
	_assert_eq(ui_ja["在发现瀑布流里关注一个账号，它的帖子会留在这里。"], "「おすすめ」でアカウントをフォローすると、その投稿がここに残る。", "Japanese empty-following guidance should name the actual Discover tab")
	_assert_eq(ui_ja["开启 VHS 质感"], "VHS風表示", "Japanese toggle labels should use compact native UI wording")
	_assert_eq(ui_en["门禁说我没回家我却在屋里"], "The Entry Log Says I Never Came Home. I'm Already Inside.", "English social horror copy should use short native clauses")
	_assert_eq(ui_ja["门禁说我没回家我却在屋里"], "入退室記録では帰っていない。なのに、もう部屋にいる", "Japanese social horror copy should preserve the ordinary-to-impossible pivot")
	_assert_eq(ui_ja["别急着懂。先把它转出去，懂会在后面补票。"], "急いで理解しなくていい。先に拡散して。理解はあとから追いついて、足りないぶんを払う。", "Japanese surreal copy should remain idiomatic without explaining away the metaphor")
	_assert_true(not ui_en.has("梗仓库只在发布页或笔记本中出现。"), "retired Meme Bank guidance should be removed")
	_assert_true(not ui_ja.has("梗仓库只在发布页或笔记本中出现。"), "retired Japanese Meme Bank guidance should be removed")
	_assert_true(not ui_en.has("梗库"), "retired Meme Bank label should be removed")
	_assert_true(not ui_en.has("用滚轮或双指滑动右侧梗环挑选完整梗，再拖入两个槽位；也可以点击梗后再点槽位。"), "retired Meme Ring fusion hint should be removed")
	_assert_true(not ui_en.has("梗仓库只在社交发布页出现。"), "stale publishing-only Meme Bank copy should be removed")
	var aid_descriptions := {
		"现实句子严重失真时，临时压低 18% 的污染噪声。": [
			"After an understanding check fails, increase its success chance by 18 percentage points.",
			"理解判定に失敗したとき、その判定の成功率を18ポイント上げる。",
		],
		"现实句子严重失真时，临时压低 14% 的污染噪声。": [
			"After an understanding check fails, increase its success chance by 14 percentage points.",
			"理解判定に失敗したとき、その判定の成功率を14ポイント上げる。",
		],
		"仅能使用一次，但会压低 32% 的污染噪声。": [
			"One use only. After an understanding check fails, increase its success chance by 32 percentage points.",
			"1回のみ使用可能。理解判定に失敗したとき、その判定の成功率を32ポイント上げる。",
		],
	}
	for source in aid_descriptions:
		var expected: Array = aid_descriptions[source]
		_assert_eq(state_en[source], expected[0], "English aid copy should describe the failed-check bonus")
		_assert_eq(state_ja[source], expected[1], "Japanese aid copy should describe the failed-check bonus")


func _test_english_reality_dialogue_uses_words() -> void:
	var game = StateScript.new()
	game.new_run()
	game.conversation_locale = "en"
	game.notebook_tokens = [
		_english_bridge_token("subject", "I", "subject", "this account", "the patient"),
		_english_bridge_token("action", "remember", "action", "reposts", "reports"),
		_english_bridge_token("object", "home", "object", "the home signal", "a recurring room"),
	]
	_assert_true(game.start_typed_reality_conversation("doctor_floor1", "doctor", "Doctor"), "English doctor dialogue should start")
	game.configure_conversation_locale("en")
	_assert_eq(str(game.conversation_prompt), "Say that line again. Do not explain it for me.", "doctor prompt should come from the content catalog, not GameLocale.translate()")
	_assert_true(game.place_language_token("subject", "subject", "doctor"), "English subject should enter its slot")
	_assert_true(game.place_language_token("action", "action", "doctor"), "English action should enter its slot")
	_assert_true(game.place_language_token("object", "object", "doctor"), "English object should enter its slot")
	var preview: Dictionary = game.get_language_sentence_preview("doctor")
	_assert_eq(str(preview.get("clean_sentence", "")), "I remember home.", "English clean language should join whole words with spaces")
	_assert_eq(str(preview.get("world_sentence", "")), "the patient reports a recurring room.", "English doctor language should use authored whole-word surfaces")
	_assert_true(game.confirm_doctor_sentence(), "complete English doctor sentence should resolve")
	_assert_true(not game.last_clean_sentence.contains("Hajimi"), "removed legacy text should never be injected into the sentence")


func _english_bridge_token(
	token_id: String,
	text: String,
	role: String,
	phone_surface: String,
	doctor_surface: String
) -> Dictionary:
	return {
		"id": token_id,
		"text": text,
		"lexeme_id": "test.%s" % token_id,
		"grammar_roles": [role],
		"phone_surface": phone_surface,
		"doctor_surface": doctor_surface,
		"doll_surface": text,
		"used_worlds": ["phone"],
		"pollution_stage": 1,
	}


func _test_language_selection_and_settings_ui() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load for localization UI tests")
	if scene == null:
		return
	var game_root = scene.instantiate()
	_assert_true(game_root.has_method("new_game"), "main scene script should load for localization UI tests")
	if not game_root.has_method("new_game"):
		return
	root.add_child(game_root)
	await process_frame
	var prefs_path := "user://test_babel_meme_localization_%d.cfg" % Time.get_ticks_usec()
	if FileAccess.file_exists(prefs_path):
		DirAccess.remove_absolute(prefs_path)
	game_root._locale.preferences_path = prefs_path
	_assert_true(game_root.has_method("_build_language_selection_overlay"), "main scene should expose the language selection surface")
	game_root._build_language_selection_overlay(true)
	await process_frame
	await process_frame
	var overlay := game_root._language_overlay as Control
	_assert_true(overlay != null and is_instance_valid(overlay) and overlay.visible, "first-run language selection should cover the main menu")
	_assert_true(_find_ui_node(game_root, "LanguageChoiceZH") != null, "language selection should offer Chinese")
	_assert_true(_find_ui_node(game_root, "LanguageChoiceJA") != null, "language selection should offer Japanese")
	_assert_true(_find_ui_node(game_root, "LanguageChoiceEN") != null, "language selection should offer English")
	game_root._on_language_selected("en")
	await process_frame
	var continue_button := _find_ui_node(game_root, "MainMenuContinueButton") as Button
	_assert_true(continue_button != null, "choosing English should keep the main menu continue button")
	if continue_button != null:
		_assert_eq(continue_button.text, "Continue", "choosing English should rebuild the main menu in English")
	game_root.new_game()
	await process_frame
	var prologue_header := _find_ui_node(game_root, "PrologueSignalHeader") as Label
	var prologue_counter := _find_ui_node(game_root, "PrologueCounter") as Label
	var prologue_continue := _find_ui_node(game_root, "PrologueContinueButton") as Button
	_assert_true(prologue_header != null, "new game should show the prologue overlay")
	if prologue_header != null:
		_assert_eq(prologue_header.text, "NO SIGNAL  /  DAY 01  /  PRIVATE FREQUENCY", "prologue signal header should stay diegetic English")
	if prologue_counter != null:
		_assert_true(str(prologue_counter.text).begins_with("TRANSMISSION "), "prologue counter should stay diegetic English")
	if prologue_continue != null:
		_assert_eq(prologue_continue.text, "Continue", "prologue continue chrome should use the UI catalog")
	var language_option := _find_ui_node(game_root, "SettingsLanguageOption") as OptionButton
	var manual_save := _find_ui_node(game_root, "SettingsManualSaveButton") as Button
	_assert_true(language_option != null, "settings should expose an in-game language switcher")
	_assert_true(manual_save != null, "settings should expose manual save")
	game_root._skip_prologue()
	game_root.game.ending_unlocked = true
	game_root.game.relationship_residue = 10
	game_root._render()
	await process_frame
	var ending_restart := _find_node_by_name(game_root, "EndingRestartButton") as Button
	var ending_residue := _find_node_by_name(game_root, "EndingResidue") as Label
	var ending_system := _find_node_by_name(game_root, "EndingSystemLine") as Label
	_assert_true(ending_restart != null, "ending screen should expose restart chrome")
	if ending_restart != null:
		_assert_eq(ending_restart.text, "Start Over", "ending restart chrome should use the UI catalog")
	if ending_residue != null:
		_assert_eq(ending_residue.text, "RELATIONSHIP RESIDUE 10 / 100  ·  They can still recognize you", "ending residue chrome should translate the UI catalog template")
	if ending_system != null:
		_assert_eq(ending_system.text, "FLOOR 05  /  NO SIGNAL  /  WISDOM USER NOT FOUND", "ending system line should stay diegetic English")
	game_root.game.pollution = 60
	_assert_eq(game_root._corrupt("I want to speak normally."), "□ want to speak □", "English corruption should replace complete words instead of shredding letters")
	game_root.queue_free()
	await process_frame


## Rebuilds queue_free the previous UIRoot, so searching from the game root can still
## reach stale nodes for a frame. Always scope lookups to the current UIRoot.
func _find_ui_node(game_root: Node, target_name: String) -> Node:
	var ui_root := game_root._ui_root as Control
	if ui_root == null or not is_instance_valid(ui_root):
		return null
	return _find_node_by_name(ui_root, target_name)


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_catalog_parity(english: Dictionary, japanese: Dictionary, catalog_name: String) -> void:
	for source in english:
		_assert_true(japanese.has(source), "%s catalog should include Japanese key: %s" % [catalog_name, source])
	for source in japanese:
		_assert_true(english.has(source), "%s catalog should include English key: %s" % [catalog_name, source])


func _assert_catalog_format_signatures(english: Dictionary, japanese: Dictionary, catalog_name: String) -> void:
	for source in english:
		var source_signature := _format_signature(str(source))
		_assert_eq(_format_signature(str(english[source])), source_signature, "%s English placeholders should match source: %s" % [catalog_name, source])
		_assert_eq(_format_signature(str(japanese[source])), source_signature, "%s Japanese placeholders should match source: %s" % [catalog_name, source])


func _format_signature(text: String) -> Array[String]:
	var regex := RegEx.new()
	regex.compile("%(?:02d|d|s|%)")
	var signature: Array[String] = []
	for match_result in regex.search_all(text):
		signature.append(match_result.get_string())
	return signature


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
