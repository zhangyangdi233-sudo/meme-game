extends SceneTree
## The basement CRT terminal's screen: a display of its own holding the social feed and the notebook, one at a time.
## It reads the same models and raises the same intents as the phone, so a word picked on either side shows on both.
## Its tabs and its exit raise their intents; the pointer reaches it as a UV on the CRT's glass.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const BootScript = preload("res://scripts/game/property_boot.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameSocialFeedSourceScript = preload("res://scripts/game/game_social_feed_source.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const LocaleScript = preload("res://scripts/localization/game_locale.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const CrtTerminalPanelScript = preload("res://scripts/ui/crt_terminal_panel.gd")
const GuideScript = preload("res://scripts/game/basement_guide.gd")
const NarrativeCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const LessonScript = preload("res://scripts/game/crt_lesson.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("crt terminal panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	await _test_the_display_shows_the_social_feed_first()
	await _test_a_tab_switches_the_app_and_raises_its_intent()
	await _test_the_exit_raises_its_intent()
	await _test_a_word_held_anywhere_shows_in_the_terminal_notebook()
	await _test_posting_from_the_terminal_raises_the_phone_intent()
	await _test_a_hidden_terminal_lets_go_of_the_models()
	await _test_the_narrator_walks_the_round_through()
	await _test_outside_a_guided_round_the_narrator_is_silent()
	await _test_the_lesson_walks_round_one_from_the_post_to_the_open_door()
	await _test_the_exit_is_always_usable_and_an_open_round_has_no_lesson()
	await _test_the_lesson_speaks_every_language()


func _test_the_display_shows_the_social_feed_first() -> void:
	var panel = await _mount()
	var texture: Texture2D = panel.display_texture()
	_assert_true(texture != null, "the terminal should hand out its display")
	_assert_eq(Vector2(texture.get_size()), Vector2(CrtTerminalPanelScript.DISPLAY_SIZE), "the display should be the terminal's size")
	_assert_eq(panel.selected_app(), "social", "the terminal should open on the social feed")
	var social := _find(panel, "SocialAppWindow") as Control
	var notebook := _find(panel, "TerminalNotebookBody") as Control
	_assert_true(social != null and social.is_visible_in_tree(), "the social feed should show on the terminal")
	_assert_true(_find(social, "SocialChannelTabs") != null, "the terminal's social feed should be painted")
	_assert_true(notebook != null and not notebook.is_visible_in_tree(), "the notebook should wait behind its tab")
	_assert_true(_find(social, "SocialAppInlineCloseButton") == null, "the terminal's feed has no phone window to close")
	# The old version's chrome wording (planner, 2026-11-16).
	_assert_eq((_find(panel, "TerminalTitle") as Label).text, "信号终端", "the terminal's title")
	_assert_eq((_find(panel, "TerminalExit") as Button).text, "退出屏幕", "the terminal's exit")
	_assert_eq((_find(panel, "NotebookCraftButton") as Button).text, "发布", "the notebook's post button")
	var catalog := preload("res://scripts/localization/ui_catalog.gd")
	_assert_eq([catalog.entries("en").get("退出屏幕"), catalog.entries("ja").get("退出屏幕")], ["Leave screen", "画面から離れる"], "the exit in English and Japanese")
	_assert_eq([catalog.entries("en").get("发布"), catalog.entries("ja").get("发布")], ["Post", "投稿"], "the post button in English and Japanese")
	await _dispose(panel)


func _test_a_tab_switches_the_app_and_raises_its_intent() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	_assert_eq(panel.selected_app(), "notebook", "the notebook tab should switch the terminal to the notebook")
	_assert_true((_find(panel, "TerminalNotebookBody") as Control).is_visible_in_tree(), "the notebook should show")
	_assert_true(not (_find(panel, "SocialAppWindow") as Control).is_visible_in_tree(), "the social feed should hide")
	_assert_heard(UiIntentsScript.TERMINAL_APP_SELECTED, {UiIntentsScript.KEY_APP_ID: "notebook"}, "the notebook tab")
	await _click(panel, "TerminalAppSocial")
	_assert_eq(panel.selected_app(), "social", "the social tab should switch back")
	await _dispose(panel)


func _test_the_exit_raises_its_intent() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalExit")
	_assert_heard(UiIntentsScript.TERMINAL_EXIT_REQUESTED, {}, "the exit button")
	var heard_before := _heard.size()
	panel.push_pointer(_mouse_button(true), CrtScreen.MISS)
	panel.push_pointer(_mouse_button(false), CrtScreen.MISS)
	await process_frame
	_assert_eq(_heard.size(), heard_before, "a click off the glass should raise nothing")
	await _dispose(panel)


func _test_a_word_held_anywhere_shows_in_the_terminal_notebook() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	_model(PropertyKeysScript.COLLECTED_CHAR_UNITS).replace_all([{"unit": "门", "locale": "zh", "source_post_id": "floor_13", "day": 1}])
	await process_frame
	await process_frame
	var canvas := _find(panel, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null and canvas.has_tile("门"), "a word held on the phone should show on the terminal's notebook")
	await _dispose(panel)


func _test_posting_from_the_terminal_raises_the_phone_intent() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	_model(PropertyKeysScript.FREE_SENTENCE_UNITS).replace_all(["门"])
	await process_frame
	await process_frame
	await _click(panel, "NotebookCraftButton")
	_assert_heard(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}, "posting from the terminal")
	await _dispose(panel)


func _test_a_hidden_terminal_lets_go_of_the_models() -> void:
	var panel = await _mount()
	await _click(panel, "TerminalAppNotebook")
	panel.set_shown(false)
	_model(PropertyKeysScript.COLLECTED_CHAR_UNITS).replace_all([{"unit": "开", "locale": "zh", "source_post_id": "floor_13", "day": 1}])
	await process_frame
	await process_frame
	var canvas := _find(panel, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas == null or not canvas.has_tile("开"), "a hidden terminal should not repaint")
	panel.set_shown(true)
	await process_frame
	canvas = _find(panel, "NotebookWordCanvas") as WordPhysicsCanvas
	_assert_true(canvas != null and canvas.has_tile("开"), "showing the terminal again should catch up with the models")
	await _dispose(panel)


## #125: the CRT's narrator follows the round from the models: pick, what the post did, the open exit. In round one the
## lesson's caption says what to do until the exit is open, so the narrator hides meanwhile (planner, 2026-11-16).
func _test_the_narrator_walks_the_round_through() -> void:
	var panel = await _mount()
	var progress := _model(PropertyKeysScript.CHAPTER_ONE_PROGRESS)
	progress.replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 2))
	await process_frame
	_assert_eq(_guide_text(panel), _narrated(GuideScript.STEP_PICK, 2), "a fresh round should greet the player")
	_model(PropertyKeysScript.PUBLISHED_MEMES).insert_at(0, {"kind": "free_sentence", "text": "门", "tier": "misread", "round": 2})
	await process_frame
	_assert_eq(_guide_text(panel), _narrated(GuideScript.STEP_MISSED, 2), "a green post should ask to try again")
	_model(PropertyKeysScript.PUBLISHED_MEMES).replace_all([])
	progress.replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
	await process_frame
	var guide := _find(panel, "TerminalGuide") as Label
	_assert_true(not guide.visible, "round one's lesson should hide the narrator while it shows")
	progress.replace_all(ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 1), ["door"]))
	await process_frame
	_assert_eq(_guide_text(panel), _narrated(GuideScript.STEP_OPEN), "an open exit should send the player out")
	await _dispose(panel)


## Round one's locked lesson in Chinese, from the first post to the open exit (the old tutorial, planner 2026-11-16):
## each step lights its holes with the exit always among them and shows its caption; a click outside the holes reaches
## nothing; what would break the step is refused when it comes from this display; leaving and coming back resumes;
## once the exit is open the lesson is gone and the narrator sends the player to the door.
func _test_the_lesson_walks_round_one_from_the_post_to_the_open_door() -> void:
	var panel = await _mount()
	var teaching := LessonScript.teaching_units(RoomContentScript.room(1), "zh")
	_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
	await _frames(3)
	_assert_eq(panel.lesson_step(), LessonScript.STEP_POST, "a fresh round one should ask for a post")
	_assert_lesson(panel, LessonScript.STEP_POST, ["TerminalExit"], "zh", 1)
	var walked := 0
	while panel.lesson_step() in [LessonScript.STEP_POST, LessonScript.STEP_COLLECT] and walked < 8:
		walked += 1
		var lit := _lit_card(panel)
		_assert_true(lit != null, "the post step should light a card")
		if lit == null:
			break
		var other := _unlit_card(panel, lit)
		if other != null:
			_heard.clear()
			await _click_control(panel, other)
			_assert_true(not _heard_name(UiIntentsScript.SOCIAL_CARD_CLICKED), "a click on another card should reach nothing")
		_heard.clear()
		await _click_control(panel, lit)
		_assert_true(_heard_name(UiIntentsScript.SOCIAL_CARD_CLICKED), "the lit card should open")
		await _frames(2)
		_assert_eq(panel.lesson_step(), LessonScript.STEP_COLLECT, "an open post with missing words should ask to pick them")
		_assert_lesson(panel, LessonScript.STEP_COLLECT, ["TerminalExit", "SocialDetailWindow"], "zh")
		var offered := _offered_in_open_post(panel, teaching)
		_assert_true(not offered.is_empty(), "the open post should light at least one missing word")
		_assert_true(not _from_terminal(panel, UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "房", UiIntentsScript.KEY_POST_ID: _open_post_id(panel)}), "another word should be refused")
		_assert_true(not _from_terminal(panel, UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: _open_post_id(panel)}), "a like should be refused")
		_assert_true(_from_terminal(panel, UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: offered[0], UiIntentsScript.KEY_POST_ID: _open_post_id(panel)}), "a lit word should be picked")
		_assert_true(panel.allows_intent(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "房", UiIntentsScript.KEY_POST_ID: "floor_13"}), "the phone's own intents should never be refused")
		# The host picks the lit words up; the models tell the terminal.
		_hold(_held() + offered)
		await _frames(3)
	_assert_true(teaching.all(func(unit: Variant) -> bool: return unit in _held()), "every lesson word should be held: %s" % [_held()])
	_assert_eq(panel.lesson_step(), LessonScript.STEP_NOTEBOOK, "every word held should ask for the notebook")
	_assert_lesson(panel, LessonScript.STEP_NOTEBOOK, ["TerminalExit", "TerminalAppNotebook"], "zh")
	await _click(panel, "TerminalAppSocial")
	_assert_eq(panel.selected_app(), "social", "the feed's tab should not be usable during the lesson")
	_assert_true(not _from_terminal(panel, UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}), "posting before the sentence should be refused")
	await _click(panel, "TerminalAppNotebook")
	await _frames(3)
	_assert_eq(panel.lesson_step(), LessonScript.STEP_COMPOSE, "the notebook should ask for the sentence")
	_assert_lesson(panel, LessonScript.STEP_COMPOSE, ["TerminalExit", "NotebookCanvasFrame", "NotebookSentenceBar"], "zh")
	_assert_true(_from_terminal(panel, UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: teaching[0]}), "a lesson word should be placed")
	_assert_true(not _from_terminal(panel, UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: "房"}), "another word should not be placed")
	panel.set_shown(false)
	await _frames(1)
	_assert_true(panel.lesson_holes().is_empty(), "leaving the screen should take the lesson away")
	panel.set_shown(true)
	await _frames(3)
	_assert_eq(panel.lesson_step(), LessonScript.STEP_COMPOSE, "coming back should resume the step")
	var reversed := teaching.duplicate()
	reversed.reverse()
	_model(PropertyKeysScript.FREE_SENTENCE_UNITS).replace_all(reversed)
	await _frames(3)
	_assert_eq(panel.lesson_step(), LessonScript.STEP_PUBLISH, "the lesson words in any order should ask to post")
	_assert_lesson(panel, LessonScript.STEP_PUBLISH, ["TerminalExit", "NotebookCraftButton", "NotebookSentenceBar"], "zh")
	_heard.clear()
	await _click(panel, "NotebookCraftButton")
	_assert_heard(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED, {}, "the post button")
	_assert_true(not (_find(panel, "TerminalGuide") as Label).visible, "the narrator should stay hidden while the lesson shows")
	# The host judges the post red and opens the exit door.
	_model(PropertyKeysScript.FREE_SENTENCE_UNITS).replace_all([])
	_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 1), ["door"]))
	await _frames(2)
	_assert_eq(panel.lesson_step(), "", "the open exit should end the lesson")
	_assert_true(panel.lesson_holes().is_empty(), "no hole should be left")
	_assert_eq(_guide_text(panel), _narrated(GuideScript.STEP_OPEN), "the narrator should send the player to the door")
	_assert_true(not (_find(panel, "TerminalAppSocial") as Button).disabled, "the buttons should work again")
	_assert_true(_from_terminal(panel, UiIntentsScript.SOCIAL_LIKE_PRESSED, {}), "nothing should be refused once the lesson is over")
	await _dispose(panel)


## The exit button is a hole of every step and always leaves; an open exit (on the phone) means no lesson at all.
func _test_the_exit_is_always_usable_and_an_open_round_has_no_lesson() -> void:
	var panel = await _mount()
	_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
	await _frames(3)
	_heard.clear()
	await _click(panel, "TerminalExit")
	_assert_heard(UiIntentsScript.TERMINAL_EXIT_REQUESTED, {}, "the exit during the lesson")
	_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.deliver(ProgressScript.jump_to_round(ProgressScript.initial(), 1), ["tv"]))
	await _frames(2)
	_assert_eq(panel.lesson_step(), "", "a round whose exit is already open should show no lesson")
	_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 3))
	await _frames(2)
	_assert_eq(panel.lesson_step(), "", "a later round should show no lesson")
	await _dispose(panel)


## English and Japanese read the same lesson with their own words and captions.
func _test_the_lesson_speaks_every_language() -> void:
	for locale: String in ["en", "ja"]:
		var panel = await _mount(locale)
		_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
		await _frames(3)
		_assert_eq(panel.lesson_step(), LessonScript.STEP_POST, "%s: round one should start the lesson" % locale)
		_assert_eq(panel.lesson_caption(), NarrativeCatalogScript.crt_lesson_caption(LessonScript.STEP_POST, locale), "%s: the post caption" % locale)
		_assert_true(_lit_card(panel) != null, "%s: a card should offer a lesson word" % locale)
		var teaching := LessonScript.teaching_units(RoomContentScript.room(1), locale)
		_hold(teaching, locale)
		await _frames(2)
		_assert_eq(panel.lesson_caption(), NarrativeCatalogScript.crt_lesson_caption(LessonScript.STEP_NOTEBOOK, locale), "%s: the notebook caption" % locale)
		await _dispose(panel)


func _test_outside_a_guided_round_the_narrator_is_silent() -> void:
	var panel = await _mount()
	_model(PropertyKeysScript.CHAPTER_ONE_PROGRESS).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 2))
	# From round two composing is left to the player (#127): holding words, the narrator has nothing to say.
	_model(PropertyKeysScript.COLLECTED_CHAR_UNITS).replace_all([{"unit": "门", "locale": "zh", "source_post_id": "floor_13", "day": 1}])
	await process_frame
	var guide := _find(panel, "TerminalGuide") as Label
	_assert_true(guide != null and not guide.visible, "a step without a line should show no narrator")
	await _dispose(panel)


func _guide_text(panel) -> String:
	var guide := _find(panel, "TerminalGuide") as Label
	_assert_true(guide != null and guide.is_visible_in_tree(), "the narrator should show on the terminal")
	return guide.text if guide != null else ""


func _narrated(step: String, round_number: int = 1) -> String:
	return NarrativeCatalogScript.opening_speaker("zh") + NarrativeCatalogScript.basement_guide_line(round_number, step, "zh")


func _frames(count: int) -> void:
	for frame in count:
		await process_frame


## The step's holes are the named controls (the exit among them), and its caption is the catalog's.
func _assert_lesson(panel, step: String, hole_names: Array, locale: String, unnamed: int = 0) -> void:
	var holes: Array[Rect2] = panel.lesson_holes()
	_assert_eq(holes.size(), hole_names.size() + unnamed, "the %s step should light %s" % [step, hole_names])
	for hole_name: String in hole_names:
		var control := _find(panel, hole_name) as Control
		var inside := false
		if control != null:
			for hole in holes:
				inside = inside or hole.has_point(control.get_global_rect().get_center()) or hole.has_point(control.get_global_rect().position + Vector2(2, 2))
		_assert_true(inside, "the %s step should light %s" % [step, hole_name])
	var teaching := LessonScript.teaching_units(RoomContentScript.room(1), locale)
	_assert_eq(panel.lesson_caption(), LessonScript.caption(step, locale, teaching), "the %s step's caption" % step)


func _lit_card(panel) -> Control:
	for hole: Rect2 in panel.lesson_holes():
		for node in _find(panel, "SocialAppWindow").find_children("SocialPostCard*", "Control", true, false):
			var card := node as Control
			if card.is_visible_in_tree() and card.get_global_rect().grow(1.0).encloses(hole):
				return card
	return null


## A visible card the lesson does not light, if the feed shows one.
func _unlit_card(panel, lit: Control) -> Control:
	for node in _find(panel, "SocialAppWindow").find_children("SocialPostCard*", "Control", true, false):
		var card := node as Control
		if card == lit or not card.is_visible_in_tree():
			continue
		var center := card.get_global_rect().get_center()
		if center.y > 140.0 and center.y < 700.0:
			return card
	return null


func _click_control(panel, control: Control) -> void:
	var rect := control.get_global_rect().intersection(Rect2(Vector2(0, 124), Vector2(CrtTerminalPanelScript.DISPLAY_SIZE) - Vector2(0, 124)))
	var uv: Vector2 = rect.get_center() / Vector2(CrtTerminalPanelScript.DISPLAY_SIZE)
	panel.push_pointer(InputEventMouseMotion.new(), uv)
	panel.push_pointer(_mouse_button(true), uv)
	panel.push_pointer(_mouse_button(false), uv)
	await process_frame


func _heard_name(intent_name: String) -> bool:
	for entry in _heard:
		if entry[0] == intent_name:
			return true
	return false


## Whether the lesson would let an intent through had a click on the terminal's display raised it.
func _from_terminal(panel, intent_name: String, payload: Dictionary) -> bool:
	panel.set("_dispatching", true)
	var allowed: bool = panel.allows_intent(intent_name, payload)
	panel.set("_dispatching", false)
	return allowed


func _open_post_id(panel) -> String:
	var social := _find(panel, "TerminalSocialFeedPanel") as SocialFeedPanel
	var source := RegistryScript.resolve(ServiceKeysScript.SOCIAL_FEED_SOURCE) as GameSocialFeedSource
	return str(source.post_for_index(social.detail_post_index()).get("id", ""))


## The lesson words the open post shows as links.
func _offered_in_open_post(panel, teaching: Array) -> Array:
	var offered: Array = []
	var detail := _find(panel, "SocialDetailWindow")
	for node in detail.find_children("*", "RichTextLabel", true, false):
		var text := (node as RichTextLabel).text
		for unit: String in teaching:
			if ("[url=%s]" % unit) in text and unit not in offered:
				offered.append(unit)
		for unit: String in ["房", "间", "亮", "我", "你", "没", "不"]:
			_assert_true(("[url=%s]" % unit) not in text, "the open post should not offer %s during the lesson" % unit)
	return offered


func _held() -> Array:
	var units: Array = []
	for entry in _model(PropertyKeysScript.COLLECTED_CHAR_UNITS).read():
		units.append(str((entry as Dictionary).get("unit", "")))
	return units


func _hold(units: Array, locale: String = "zh") -> void:
	var entries: Array = []
	for unit in units:
		entries.append({"unit": str(unit), "locale": locale, "source_post_id": "floor_13", "day": 1})
	_model(PropertyKeysScript.COLLECTED_CHAR_UNITS).replace_all(entries)


func _mount(locale_code: String = "zh"):
	RegistryScript.clear()
	BootScript.install()
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	var game := Harness.new_state()
	var locale := LocaleScript.new()
	locale.current_locale = locale_code
	var material := LanguageMaterialScript.new()
	material.configure(game, locale)
	var source := GameSocialFeedSourceScript.new()
	source.configure(game, locale, material)
	RegistryScript.bind(ServiceKeysScript.SOCIAL_FEED_SOURCE, source)
	var panel = CrtTerminalPanelScript.new()
	panel.name = "CrtTerminalPanel"
	root.add_child(panel)
	panel.mount({
		"clear_children": func(node: Node) -> void:
			for child in node.get_children():
				node.remove_child(child)
				child.queue_free(),
		"current_locale": func() -> String: return locale_code,
		"char_canvas_position": func(_unit: String, _locale_code: String) -> Vector2: return Vector2(40.0, 40.0),
	})
	panel.set_shown(true)
	await process_frame
	await process_frame
	return panel


## Clicks a control on the terminal's display through the CRT's glass: the pointer arrives as a UV.
func _click(panel, control_name: String) -> void:
	var control := _find(panel, control_name) as Control
	_assert_true(control != null and control.is_visible_in_tree(), "%s should be on the terminal to click" % control_name)
	if control == null:
		return
	var uv: Vector2 = control.get_global_rect().get_center() / Vector2(CrtTerminalPanelScript.DISPLAY_SIZE)
	var motion := InputEventMouseMotion.new()
	panel.push_pointer(motion, uv)
	panel.push_pointer(_mouse_button(true), uv)
	panel.push_pointer(_mouse_button(false), uv)
	await process_frame


func _mouse_button(pressed: bool) -> InputEventMouseButton:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.pressed = pressed
	return click


func _model(property_name: String) -> PropertyModel:
	return (RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager).model(property_name)


func _find(node: Node, wanted_name: String) -> Node:
	return Harness.find_node_by_name(node, wanted_name)


func _dispose(panel) -> void:
	panel.queue_free()
	await process_frame
	RegistryScript.clear()


func _assert_heard(intent_name: String, payload: Dictionary, label: String) -> void:
	for entry in _heard:
		if entry[0] == intent_name:
			_assert_eq(entry[1], payload, "%s should carry its answer" % label)
			return
	_failures.append("%s should raise %s; heard %s" % [label, intent_name, str(_heard)])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
