extends SceneTree
## Real collected vocabulary -> shared main submit callback -> saved rules and UI.
## Test profiles are supplied by the runner; no normal user save is read/written.

const State = preload("res://scripts/meme_game_state.gd")
const Pool = preload("res://scripts/narrative/pickup_char_pool.gd")
const Rules = preload("res://scripts/narrative/rule_engine.gd")
const View = preload("res://scripts/ui/rule_publication_view.gd")
const ExistingFlow = preload("res://tests/test_chapter_terminal_flow.gd")
var main: Node
var failures: Array[String] = []
var checks := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = ExistingFlow.FakeReceiver.new()
	main._save_path = "user://rule-publication-test.dat"
	main._locale.preferences_path = "user://rule-publication-test.cfg"
	root.add_child(main)
	main._resolve_camera_consent(false)
	await _test_rule_history()
	await _test_languages_and_save()
	await _test_cancellation()
	await _test_crt_reveal_bounds()
	main.free()
	await _frames(3)
	for message in failures:
		push_error(message)
	if failures.is_empty():
		print("rule publication presentation passed (%d checks; real pickups, submit callback, rule history, locales, Continue, cancellation and phone/CRT text bounds)" % checks)
	quit(0 if failures.is_empty() else 1)

func _fresh(locale: String = "zh") -> void:
	var state := State.new()
	state.new_run()
	state.set_view_state("phone_down")
	main._locale.set_locale(locale)
	main._begin_game_session(state, {}, false)
	main._set_reality_mouse_look(false)
	main._on_app_pressed("notebook")
	await _frames(3)

func _publish(units: Array, locale: String = "zh") -> int:
	main.game.free_sentence_clear()
	for unit in units:
		if not main.game.is_social_char_collected(unit, locale):
			for post_id in Pool.POST_SEEDS:
				if main.game.pick_social_char(post_id, unit, locale).get("picked", false):
					break
		_check(main.game.is_social_char_collected(unit, locale), "source posts genuinely supply %s (%s)" % [unit, locale])
		_check(main.game.free_sentence_place(unit, locale), "collected unit %s enters the shared composer" % unit)
	var count: int = main.game.published_memes.size()
	main._on_composer_submit_pressed()
	_check(main.game.published_memes.size() == count + 1, "the real main callback publishes exactly one draft")
	return -main.game.published_memes.size()

func _test_rule_history() -> void:
	await _fresh()
	main._on_composer_submit_pressed()
	_check(not _presentation_active() and main.game.published_memes.is_empty(), "empty drafts do not animate or create a publication")
	var plain := _publish(["门"])
	_check(not _presentation_active() and not _post(plain).get("is_rule", false), "an ordinary non-rule publication never claims a rule change")
	main._social_channel = "following"
	main._social_detail_open = true
	var positive := _publish(["门", "打", "开"])
	_check(_presentation_active(), "successful rule submission immediately shows the large presentation")
	_check(_label("RuleRevealText").text == "门可以打开", "large feedback displays the canonical changed rule")
	_check(main._load_save_payload().game.state.published_memes.size() == 2, "publication is persisted before its animation finishes")
	_check(_post(positive).rule_current and not _post(positive).negated, "positive door rule is current immediately after submission")
	await _finish_animation()
	_check(main._social_screen == "home" and main._social_channel == "discover" and not main._social_detail_open, "landing reveals discovery waterfall instead of a stale detail or Following page")
	_check(main.game.active_app_window == "social", "phone animation lands in the actual social app")
	_check(main._social_visible_post_indices()[0] == positive, "current rule is first in the waterfall")
	await _check_card(positive, true, false, "zh")

	var negative := _publish(["门", "不", "打", "开"])
	_check(_presentation_active() and _post(negative).rule_current and _post(negative).negated, "negative rule also presents as the current rule")
	_check(not main.game.is_world_rule_active("door|can_open") and not _post(positive).rule_current, "negation suppresses the positive rule and supersedes its old post")
	await _finish_animation()
	await _check_card(negative, true, true, "zh")
	await _check_card(positive, false, false, "zh")

	var duplicate := _publish(["门", "不", "打", "开"])
	_check(_post(duplicate).rule_current and not _post(negative).rule_current and not _post(positive).rule_current, "repeating exactly the same rule leaves only the latest publication current")
	await _finish_animation()
	var light := _publish(["灯", "亮"])
	_check(_post(light).rule_current and _post(duplicate).rule_current, "a different canonical rule does not replace the existing door rule")
	await _finish_animation()
	var ordinary := _publish(["我"])
	var order: Array = main._social_visible_post_indices()
	_check(order[0] == light and order[1] == duplicate and order.find(ordinary) > 1, "all current rules stay above a newer ordinary post")
	_check(not _presentation_active(), "ordinary posting does not replay a previous rule animation")

func _test_languages_and_save() -> void:
	var sentences := {"zh": ["门", "打", "开"], "en": ["door", "can", "open"], "ja": ["ドア", "は", "ひらく"]}
	for source_locale in sentences:
		await _fresh(source_locale)
		var units: Array = sentences[source_locale]
		var original: String = (" " if source_locale == "en" else "").join(units)
		var index := _publish(units, source_locale)
		_check(_post(index).text == original and _post(index).content_locale == source_locale, "publication retains its original %s sentence and locale" % source_locale)
		await _check_reveal_bounds("phone-" + source_locale, Vector2(main.get_viewport().get_visible_rect().size))
		await _finish_animation()
		for ui_locale in ["zh", "en", "ja"]:
			main._locale.set_locale(ui_locale)
			main.game.pollution = 95
			main._render()
			await _frames(3)
			_check(_post(index).text == original and _post(index).rule_text == Rules.rule_display_text("door|can_open", false, ui_locale), "UI language changes canonical rule copy without translating the original %s sentence" % source_locale)
			_check(_label("SocialPostCaption%d" % index).text == original, "pollution and localization preserve the posted original caption")
			await _check_card(index, true, false, ui_locale)
		_check(main._save_progress(), "rule presentation state saves through the ordinary main save path")
		main.show_main_menu()
		_check(main.continue_game(), "ordinary Continue reloads the published rule")
		await _frames(4)
		_check(not _presentation_active() and _post(index).rule_current and _post(index).text == original, "Continue restores current identity and source text without replaying the transient animation")

func _test_cancellation() -> void:
	for action in ["tab", "settings", "menu"]:
		await _fresh()
		var index := _publish(["门", "打", "开"])
		_check(_presentation_active(), "%s case begins with a live rule presentation" % action)
		if action == "tab":
			main._unhandled_input(_key(KEY_TAB))
			_check(main.game.view_state == "npc_up" and not _presentation_active(), "real Tab cancels the presentation and closes the phone")
		elif action == "settings":
			main._unhandled_input(_key(KEY_F10))
			_check(main._settings_open and not _presentation_active(), "real settings shortcut cancels the rule presentation")
		else:
			main.show_main_menu()
			_check(not main._game_started and not _presentation_active(), "returning to the menu cancels the presentation")
		await create_timer(2.7).timeout
		_check(main._load_save_payload().game.state.published_memes.size() == 1, "%s cancellation retains the already-saved publication" % action)
		if action == "tab":
			_check(main.game.view_state == "npc_up" and not _presentation_active(), "cancelled tween cannot reopen the phone after Tab")
		elif action == "settings":
			_check(main._settings_open and main.game.active_app_window == "notebook", "cancelled tween cannot switch apps behind Settings")
			main._unhandled_input(_key(KEY_F10))
		else:
			_check(not main._game_started, "cancelled tween cannot leave the main menu or reopen the phone")
		_check(main.continue_game(), "Continue after cancellation remains available")
		await _frames(3)
		_check(_post(index).rule_current and not _presentation_active(), "cancelled presentation remains saved and never auto-replays on Continue")

func _test_crt_reveal_bounds() -> void:
	var sentences := {"zh": ["门", "打", "开"], "en": ["door", "can", "open"], "ja": ["ドア", "は", "ひらく"]}
	for locale in sentences:
		var state := State.new()
		state.new_run()
		state.start_chapter1()
		state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
		state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
		state.notify_chapter1("opening_door_opened")
		# This bounds regression starts after the input tutorial. Its real UV
		# pickup/drag sequence has separate coverage; vocabulary here is still
		# collected from source posts and submitted by the actual main callback.
		state.chapter1_progress.crt_tutorial = preload("res://scripts/tutorial/chapter_crt_tutorial_state.gd").normalize({
			"focus_started": true, "focus_done": true, "focus_line": 7,
			"lesson_phase": "complete", "locale": locale,
			"collected": sentences[locale], "dragged": sentences[locale], "published": true,
		})
		state.view_state = "npc_up"
		main._locale.set_locale(locale)
		main._begin_game_session(state, {}, false)
		main._set_reality_mouse_look(false)
		await _frames(3)
		var actor: Area3D = main._chapter_actor("chapter1_terminal")
		_check(actor != null, "CRT bounds case has the actual first-basement terminal actor")
		if actor == null:
			continue
		main._reality_player.position = actor.position + Vector3(0, 0, 0.7)
		_check(main._begin_chapter_terminal(), "CRT bounds case enters the real terminal session")
		if not main._chapter_terminal_active():
			continue
		await _frames(3)
		main._on_chapter_terminal_app_pressed("notebook")
		_publish(sentences[locale], locale)
		await _check_reveal_bounds("crt-" + locale, Vector2(1600, 1200))
		main._end_chapter_terminal(false)
		_check(not _presentation_active(), "leaving the CRT cancels the bounded card before restoring shared controls")
		await _frames(3)

func _check_reveal_bounds(context: String, expected_viewport: Vector2) -> void:
	# Inspect the first shaped layout and the fully enlarged hold. In particular,
	# don't reassign sizes here: that would mask the initial zero-width cache bug.
	await _frames(3)
	for phase in ["first-shaped", "hold"]:
		if phase == "hold":
			await create_timer(0.36).timeout
		_check(_presentation_active(), "%s %s keeps a live publication card" % [context, phase])
		var reveal: Control = main._rule_publication_view
		var card := reveal.get_node("RuleRevealCard") as Control
		var card_rect := card.get_global_rect()
		var viewport_rect := Rect2(Vector2.ZERO, expected_viewport)
		_check(reveal.get_viewport().get_visible_rect().size.is_equal_approx(expected_viewport) and reveal.size.is_equal_approx(expected_viewport), "%s uses its actual phone/CRT viewport" % context)
		_check(viewport_rect.grow(0.5).encloses(card_rect) and card.size.y <= expected_viewport.y * 0.5, "%s %s card fits its viewport without expanding to wrapped text minimums" % [context, phase])
		var heading := card.get_node("RuleRevealStatus") as Label
		var sentence := card.get_node("RuleRevealText") as Label
		for label: Label in [heading, sentence]:
			var label_rect := label.get_global_rect()
			var font_size := label.get_theme_font_size("font_size")
			_check(font_size >= (18 if label == heading else 40), "%s %s retains prominent typography" % [context, label.name])
			_check(card_rect.grow(0.5).encloses(label_rect), "%s %s %s label rectangle stays inside the card: label=%s card=%s" % [context, phase, label.name, label_rect, card_rect])
			var visible_characters := 0
			var outside: Array[String] = []
			for character_index in label.text.length():
				var local_bounds := label.get_character_bounds(character_index)
				if not local_bounds.has_area():
					continue
				visible_characters += 1
				var global_bounds: Rect2 = label.get_global_transform() * local_bounds
				if not card_rect.grow(0.5).encloses(global_bounds) or not label_rect.grow(0.5).encloses(global_bounds):
					outside.append("%s:%s" % [label.text[character_index], global_bounds])
			_check(visible_characters >= label.text.replace(" ", "").replace("\n", "").length(), "%s %s actually shapes every visible character" % [context, label.name])
			_check(outside.is_empty(), "%s %s %s glyphs stay inside both label and card: %s" % [context, phase, label.name, outside])
			_check(label.get_visible_line_count() == label.get_line_count(), "%s %s does not silently clip wrapped lines" % [context, label.name])
		_check(not heading.get_global_rect().intersects(sentence.get_global_rect()), "%s %s heading and rule sentence do not overlap" % [context, phase])
		if phase == "hold":
			print("Rule bounds %s: viewport=%s card=%s heading=%s sentence=%s sentence_font=%d" % [context, expected_viewport, card_rect, heading.get_global_rect(), sentence.get_global_rect(), sentence.get_theme_font_size("font_size")])

func _check_card(index: int, current: bool, negated: bool, locale: String) -> void:
	main._render()
	await _frames(3)
	var poster := main.find_child("SocialPostPoster%d" % index, true, false) as PanelContainer
	var ordinary := main.find_child("SocialPostPoster0", true, false) as PanelContainer
	_check(poster != null and poster.get_meta("rule_card", false) and poster.get_meta("rule_current", false) == current, "rendered rule poster exposes stable current/history metadata")
	_check(_label("SocialRuleStatus%d" % index).text == View.status_text(current, locale), "rule badge visibly identifies current versus previous state")
	_check(_label("SocialRuleText%d" % index).text == Rules.rule_display_text(str(_post(index).rule_key), negated, locale), "rendered rule text follows canonical key, polarity and UI locale")
	if poster != null and ordinary != null:
		var style := poster.get_theme_stylebox("panel") as StyleBoxFlat
		var normal := ordinary.get_theme_stylebox("panel") as StyleBoxFlat
		_check(style != null and normal != null and style.bg_color != normal.bg_color, "rule color remains distinct from ordinary posts after a complete theme rerender")
		_check(style.bg_color == (View.CURRENT if current else View.HISTORY), "current and historical rule palettes survive theme application")

func _post(index: int) -> Dictionary:
	return main._social_post_for_index(index)

func _presentation_active() -> bool:
	# Menu teardown intentionally frees the entire gameplay UI subtree.
	return is_instance_valid(main._rule_publication_view) and main._rule_publication_view.active

func _label(node_name: String) -> Label:
	var label := main.find_child(node_name, true, false) as Label
	_check(label != null, "actual UI contains %s" % node_name)
	return label if label != null else Label.new()

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return event

func _finish_animation() -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while _presentation_active() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(not _presentation_active(), "rule reveal naturally lands and finishes without synthetic completion signals")
	await _frames(3)

func _frames(count: int) -> void:
	for index in count:
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
