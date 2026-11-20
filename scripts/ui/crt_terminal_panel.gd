class_name CrtTerminalPanel
extends Node
## The basement CRT terminal's screen: a display of its own (a SubViewport the host hands to the CRT's glass) with the
## Layout scene `scenes/ui/crt_terminal.tscn` for its chrome, and its own social feed and notebook, one at a time.
## They watch the same models and raise the same intents as the phone, so the held words, the sentence and the world
## rules are one copy. Which app shows is this screen's own view. Its tabs and its exit raise their intents.
## Above the apps the round's narrator (`BasementGuide`) says what to do next, read from the models while shown.
## The pointer arrives as a UV on the glass; the panel turns it into a point on its display.
## In round one, until its exit is open, the old version's locked lesson (`CrtLesson`, planner 2026-11-16) lies over
## the apps on this display (`CrtLessonOverlay`): only its highlighted controls and the exit can be used, and an
## intent raised while this display dispatches the pointer is checked against its step (`allows_intent`), so the
## phone, which raises the same intents, stays unrestricted. The narrator's line hides while the lesson shows.

const LAYOUT_SCENE := preload("res://scenes/ui/crt_terminal.tscn")
const BasementGuideScript = preload("res://scripts/game/basement_guide.gd")
const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const CrtLessonScript = preload("res://scripts/game/crt_lesson.gd")
const CrtLessonOverlayScript = preload("res://scripts/ui/crt_lesson_overlay.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const PostSlipScript = preload("res://scripts/ui/post_slip.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const NotebookAppPanelScript = preload("res://scripts/ui/notebook_app_panel.gd")
const SocialFeedPanelScript = preload("res://scripts/ui/social_feed_panel.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")

const DISPLAY_SIZE := Vector2i(960, 720)
const APPS: Array[String] = ["social", "notebook"]
const DEFAULT_APP := "social"
## The feed and the open post sit side by side below the toolbar and the narrator's line.
const APP_TOP := 124.0
const APP_MARGIN := 12.0
## Where a pointer that left the glass is sent, so nothing on the display stays hovered.
const OFF_DISPLAY := Vector2(-100, -100)
## Where a button the lesson disabled keeps whether it was disabled before.
const LOCKED_META := "crt_lesson_saved_disabled"

var _viewport: SubViewport
var _screen: PaletteSceneRoot
var _apps: Control
var _social: SocialFeedPanel
var _notebook: NotebookAppPanel
var _notebook_body: VBoxContainer
var _tabs: Dictionary = {}
var _app := DEFAULT_APP
var _shown := false
## The feed is painted the first time the terminal is entered, not while it waits unseen.
var _social_painted := false
var _held_buttons: Array[MouseButton] = []
var _last_point := OFF_DISPLAY
var _guide: Label
var _current_locale_fn := Callable()
var _lesson_overlay: CrtLessonOverlayScript
## The lesson's step shown now (empty when none), the feed card it lights and whether this display is dispatching
## the pointer (an intent raised meanwhile came from this terminal).
var _lesson_step := ""
## The sentence the lesson last took a stray word out of.
var _lesson_stray_tried: Array = []
var _lesson_card: Control
var _dispatching := false
var _guide_watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.COLLECTED_CHAR_UNITS: _on_guide_model_changed,
	PropertyKeysScript.FREE_SENTENCE_UNITS: _on_guide_model_changed,
	PropertyKeysScript.PUBLISHED_MEMES: _on_guide_model_changed,
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_guide_model_changed,
})


## Builds the display once. `notebook_deps` are the notebook's own (`NotebookAppPanel.configure`).
func mount(notebook_deps: Dictionary) -> void:
	if _viewport != null:
		return
	_viewport = SubViewport.new()
	_viewport.name = "CrtTerminalDisplay"
	_viewport.size = DISPLAY_SIZE
	_viewport.disable_3d = true
	_viewport.handle_input_locally = true
	_viewport.gui_disable_input = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_viewport)
	_screen = LAYOUT_SCENE.instantiate() as PaletteSceneRoot
	_viewport.add_child(_screen)
	# The display is a viewport of its own, so the UI root's pixel-font theme never reaches it; the old terminal
	# read in the bitmap font, so the chrome and the apps get it here.
	_theme().apply_ui_font_theme(_screen)
	_screen.apply_palette(_theme().active_palette())
	_tabs = {
		"social": _screen.find_child("TerminalAppSocial", true, false) as Button,
		"notebook": _screen.find_child("TerminalAppNotebook", true, false) as Button,
	}
	for app_id in _tabs:
		(_tabs[app_id] as Button).pressed.connect(_on_tab_pressed.bind(app_id))
	(_screen.find_child("TerminalExit", true, false) as Button).pressed.connect(_on_exit_pressed)
	_guide = _screen.find_child("TerminalGuide", true, false) as Label
	_current_locale_fn = notebook_deps.get("current_locale", Callable())

	_apps = Control.new()
	_apps.name = "TerminalApps"
	_apps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apps.position = Vector2(APP_MARGIN, APP_TOP)
	_apps.size = Vector2(DISPLAY_SIZE) - Vector2(APP_MARGIN * 2.0, APP_TOP + APP_MARGIN)
	_theme().apply_ui_font_theme(_apps)
	_viewport.add_child(_apps)

	_social = SocialFeedPanelScript.new()
	_social.name = "TerminalSocialFeedPanel"
	add_child(_social)
	_social.mount(_apps, false)
	var half_width := (_apps.size.x - APP_MARGIN) * 0.5
	_fit(_social.get_app_window(), Rect2(Vector2.ZERO, Vector2(half_width, _apps.size.y)))
	_fit(_social.get_detail_window(), Rect2(Vector2(half_width + APP_MARGIN, 0.0), Vector2(half_width, _apps.size.y)))

	_notebook_body = VBoxContainer.new()
	_notebook_body.name = "TerminalNotebookBody"
	_fit(_notebook_body, Rect2(Vector2.ZERO, _apps.size))
	_apps.add_child(_notebook_body)
	_notebook = NotebookAppPanelScript.new()
	_notebook.name = "TerminalNotebookAppPanel"
	add_child(_notebook)
	_notebook.configure(notebook_deps)
	_notebook.render(_notebook_body)
	# The lesson is drawn on this display, above the apps, never on the HUD (the old overlay sat in the CRT's viewport).
	_lesson_overlay = CrtLessonOverlayScript.new()
	_lesson_overlay.visible = false
	_theme().apply_ui_font_theme(_lesson_overlay)
	_viewport.add_child(_lesson_overlay)
	_show_app()


## What the CRT's glass shows.
func display_texture() -> Texture2D:
	return _viewport.get_texture() if _viewport != null else null


func selected_app() -> String:
	return _app


## The terminal is in use: its apps watch the models and its display renders and takes the pointer.
func set_shown(shown: bool) -> void:
	if _viewport == null or _shown == shown:
		return
	_shown = shown
	_viewport.gui_disable_input = not shown
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if shown else SubViewport.UPDATE_DISABLED
	if shown:
		# The chrome and the apps are worded in the current language each time the terminal is entered: the apps are
		# not under the host's interface root, so nobody else does it for them.
		_theme().localize_control_tree(_screen)
		_theme().localize_control_tree(_apps)
		_guide_watch.start()
		_paint_guide()
	else:
		_guide_watch.stop()
		_release_pointer()
		_end_lesson()
	_show_app()
	if shown:
		_refresh_lesson()


## A mouse event that reached the CRT, at `uv` on its glass (top-left origin), or `CrtScreen.MISS` off it.
## A button held when the pointer left the glass is still released, away from every control.
func push_pointer(event: InputEventMouse, uv: Vector2) -> void:
	if not _shown or event == null:
		return
	var on_glass := uv != CrtScreen.MISS
	var button := event as InputEventMouseButton
	if not on_glass:
		if button != null and not button.pressed and _held_buttons.has(button.button_index):
			_held_buttons.erase(button.button_index)
			_send(event, OFF_DISPLAY)
		elif event is InputEventMouseMotion:
			_send(event, OFF_DISPLAY)
		return
	if button != null and button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
		if button.pressed:
			if not _held_buttons.has(button.button_index):
				_held_buttons.append(button.button_index)
		else:
			_held_buttons.erase(button.button_index)
	_send(event, uv * Vector2(DISPLAY_SIZE))


func _send(event: InputEventMouse, point: Vector2) -> void:
	var forwarded := event.duplicate() as InputEventMouse
	forwarded.position = point
	forwarded.global_position = point
	if forwarded is InputEventMouseMotion:
		(forwarded as InputEventMouseMotion).relative = point - _last_point
	_last_point = point
	_dispatching = true
	_viewport.push_input(forwarded, true)
	_dispatching = false


## Leaving lets go of every held button away from the controls, so no button fires on the way out.
func _release_pointer() -> void:
	var held := _held_buttons.duplicate()
	_held_buttons.clear()
	_send(InputEventMouseMotion.new(), OFF_DISPLAY)
	for held_button in held:
		var release := InputEventMouseButton.new()
		release.button_index = held_button
		release.pressed = false
		_send(release, OFF_DISPLAY)
	_viewport.gui_release_focus()


func _show_app() -> void:
	var social_shown := _shown and _app == "social"
	if social_shown and not _social_painted:
		_social_painted = true
		_social.render_app()
		_social.render_companion()
		_theme().apply_ui_theme(_social.get_app_window())
		_theme().localize_control_tree(_apps)
	var notebook_shown := _shown and _app == "notebook"
	_social.get_app_window().visible = social_shown
	_social.update_visibility(social_shown, social_shown)
	_notebook_body.visible = notebook_shown
	_notebook.set_shown(notebook_shown)
	for app_id in _tabs:
		(_tabs[app_id] as Button).set_pressed_no_signal(app_id == _app)


## The language changed: the feed is drawn again the next time it shows (its posts, and the echo under a post left
## open, are worded when they are drawn), and what the display shows now is worded again.
func refresh_language() -> void:
	_social_painted = false
	if _shown:
		_show_app()
		_theme().localize_control_tree(_screen)
		_theme().localize_control_tree(_apps)
		_paint_guide()


## The narrator's line for where the round stands, behind the opening's speaker tag; hidden when the round has none.
func _paint_guide() -> void:
	if _guide == null:
		return
	var locale := str(_current_locale_fn.call()) if _current_locale_fn.is_valid() else "zh"
	var progress := _guide_read(PropertyKeysScript.CHAPTER_ONE_PROGRESS, {}) as Dictionary
	var published := _guide_read(PropertyKeysScript.PUBLISHED_MEMES, []) as Array
	var line := BasementGuideScript.line(
		progress,
		_guide_read(PropertyKeysScript.COLLECTED_CHAR_UNITS, []),
		_guide_read(PropertyKeysScript.FREE_SENTENCE_UNITS, []),
		PostSlipScript.latest(published, progress, locale),
		locale
	)
	# The lesson's caption already says what to do, so the narrator does not say it twice.
	_guide.visible = not line.is_empty() and _lesson_step.is_empty()
	_guide.text = NarrativeSessionCatalogScript.opening_speaker(locale) + line if not line.is_empty() else ""


func _guide_read(property_name: String, fallback: Variant) -> Variant:
	var value: Variant = _guide_watch.read(property_name)
	return value if typeof(value) == typeof(fallback) else fallback


func _on_guide_model_changed(_value: Variant) -> void:
	if not _guide_watch.is_syncing():
		_paint_guide()


## Whether the lesson lets an intent through: anything raised outside this display's pointer dispatch (the phone, the
## host) or with no lesson showing passes; one raised by a click on this display must fit the lesson's step, as the old
## `tutorial_allows` did. The host asks before it routes an intent.
func allows_intent(intent_name: String, payload: Dictionary) -> bool:
	if not _dispatching or not _shown:
		return true
	var current := _current_lesson_step()
	return CrtLessonScript.allows(current, intent_name, payload, _lesson_context())


## The lesson's step shown now, or empty.
func lesson_step() -> String:
	return _lesson_step


## The holes and caption shown, in display coordinates, for tests and captures.
func lesson_holes() -> Array[Rect2]:
	var holes: Array[Rect2] = []
	if _lesson_overlay != null and _lesson_overlay.visible:
		holes = _lesson_overlay.holes()
	return holes


func lesson_caption() -> String:
	return _lesson_overlay.caption_text() if _lesson_overlay != null and _lesson_overlay.visible else ""


## The lesson follows the models, the open post and the app showing; its holes follow the layout and the feed's scroll,
## so it is looked at every frame while the terminal shows, like the old one.
func _process(_delta: float) -> void:
	if _shown:
		_refresh_lesson()


func _refresh_lesson() -> void:
	if _lesson_overlay == null:
		return
	var current := _current_lesson_step()
	if current.is_empty():
		_end_lesson()
		return
	var started := _lesson_step.is_empty()
	_lesson_step = current
	if started:
		_paint_guide()
	# The lit post and the words to pick are on the feed: the lesson brings it back while words are missing.
	if current in [CrtLessonScript.STEP_POST, CrtLessonScript.STEP_COLLECT] and _app != "social":
		_app = "social"
		_show_app()
	var context := _lesson_context()
	if current == CrtLessonScript.STEP_COMPOSE:
		_take_out_stray_word(context)
	var lit: Array = context["offered"] if current == CrtLessonScript.STEP_COLLECT else []
	_social.set_lesson_marking(context["teaching"], lit)
	_lock_buttons(current)
	var holes: Array[Rect2] = []
	_add_hole(holes, _screen.find_child("TerminalExit", true, false) as Control)
	match current:
		CrtLessonScript.STEP_POST:
			_add_hole(holes, _lit_card(context))
		CrtLessonScript.STEP_COLLECT:
			_add_hole(holes, _social.get_detail_window())
		CrtLessonScript.STEP_NOTEBOOK:
			_add_hole(holes, _tabs["notebook"] as Control)
		CrtLessonScript.STEP_COMPOSE:
			_add_hole(holes, _notebook_body.find_child("NotebookCanvasFrame", true, false) as Control)
			_add_hole(holes, _notebook_body.find_child("NotebookSentenceBar", true, false) as Control)
		CrtLessonScript.STEP_PUBLISH:
			_add_hole(holes, _notebook_body.find_child("NotebookCraftButton", true, false) as Control)
			_add_hole(holes, _notebook_body.find_child("NotebookSentenceBar", true, false) as Control)
	_lesson_overlay.visible = true
	_lesson_overlay.present(current, holes, CrtLessonScript.caption(current, _locale(), context["teaching"]))


## A word in the sentence that the lesson's sentence cannot keep (placed on the phone before the lesson) is taken out
## through the composer's own take-out intent, one a frame, so the compose step can always be finished here. A sentence
## already tried is not tried again, so a take-out that changes nothing cannot repeat every frame.
func _take_out_stray_word(context: Dictionary) -> void:
	var sentence: Array = context["sentence"]
	var stray := CrtLessonScript.stray_index(context["teaching"], sentence)
	if stray < 0 or sentence == _lesson_stray_tried:
		return
	_lesson_stray_tried = sentence.duplicate()
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: stray})


## The lesson is over (or the terminal hidden): the overlay goes, the buttons and the feed's marking come back and
## the narrator speaks again.
func _end_lesson() -> void:
	if _lesson_step.is_empty():
		return
	_lesson_step = ""
	_lesson_card = null
	if _lesson_overlay != null:
		_lesson_overlay.visible = false
		_lesson_overlay.present("", [] as Array[Rect2], "")
	_unlock_buttons()
	if _social != null:
		_social.set_lesson_marking([], [])
	_paint_guide()


func _current_lesson_step() -> String:
	var progress := _guide_read(PropertyKeysScript.CHAPTER_ONE_PROGRESS, {}) as Dictionary
	if ChapterOneProgressScript.round_of(progress) != CrtLessonScript.ROUND:
		return ""
	var context := _lesson_context()
	return CrtLessonScript.step(progress, context["teaching"], context["held"], context["sentence"], context["offered"], _app == "notebook")


## What the lesson reads from the models and this display: its words, those held and missing, the sentence, the open
## post and the missing words it offers, and the feed's posts that offer any.
func _lesson_context() -> Dictionary:
	var locale := _locale()
	var teaching := CrtLessonScript.teaching_units(RoomContentScript.room(CrtLessonScript.ROUND), locale)
	var held: Array = MemeGameStateScript.char_units_for_locale(_guide_read(PropertyKeysScript.COLLECTED_CHAR_UNITS, []), locale)
	var missing := CrtLessonScript.missing(teaching, held)
	var open_post_id := ""
	if _social != null and _social.is_detail_open() and _app == "social":
		open_post_id = str(_feed_source().post_for_index(_social.detail_post_index()).get("id", "")) if _feed_source() != null else ""
	var offering_posts: Array = []
	for card in _feed_cards():
		if not CrtLessonScript.offered_by(_card_post_id(card), missing, locale).is_empty():
			offering_posts.append(int(str(card.name).trim_prefix("SocialPostCard")))
	return {
		"teaching": teaching,
		"held": held,
		"missing": missing,
		"sentence": _guide_read(PropertyKeysScript.FREE_SENTENCE_UNITS, []),
		"open_post_id": open_post_id,
		"offered": CrtLessonScript.offered_by(open_post_id, missing, locale),
		"offering_posts": offering_posts,
	}


## The first card of the feed, top to bottom, whose post offers a missing word, scrolled into view when it changes.
## A feed showing another page goes back to its home first.
func _lit_card(context: Dictionary) -> Control:
	var offering: Array = context["offering_posts"]
	var lit: Control = null
	for card in _feed_cards():
		if int(str(card.name).trim_prefix("SocialPostCard")) not in offering:
			continue
		if lit == null or card.get_global_rect().position.y < lit.get_global_rect().position.y - 0.5:
			lit = card
	if lit == null and (_social.current_screen() != "home" or _social.current_channel() != "discover"):
		_social.show_screen("home")
	if lit != _lesson_card and lit != null:
		var scroll := _social.get_app_window().find_child("SocialFeedScroll", true, false) as ScrollContainer
		if scroll != null:
			scroll.ensure_control_visible(lit)
	_lesson_card = lit
	return lit


func _feed_cards() -> Array[Control]:
	var cards: Array[Control] = []
	if _social == null or _social.get_app_window() == null:
		return cards
	for node in _social.get_app_window().find_children("SocialPostCard*", "Control", true, false):
		if not (node as Control).is_queued_for_deletion():
			cards.append(node as Control)
	return cards


func _card_post_id(card: Control) -> String:
	var source := _feed_source()
	if source == null:
		return ""
	return str(source.post_for_index(int(str(card.name).trim_prefix("SocialPostCard"))).get("id", ""))


## A hole around a control on this display, clipped by every clipping control above it; none for a control not shown.
func _add_hole(holes: Array[Rect2], control: Control) -> void:
	if control == null or not control.is_visible_in_tree():
		return
	var rect := control.get_global_rect()
	var parent := control.get_parent() as Control
	while parent != null:
		if parent.clip_contents:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent() as Control
	if rect.has_area():
		holes.append(rect)


## Every button of the display is disabled but the exit and the one the step uses (the notebook tab, the post button),
## as the old lesson did; each keeps what it was, to be given back.
func _lock_buttons(current: String) -> void:
	var allowed: Array[String] = ["TerminalExit"]
	if current == CrtLessonScript.STEP_NOTEBOOK:
		allowed.append("TerminalAppNotebook")
	elif current == CrtLessonScript.STEP_PUBLISH:
		allowed.append("NotebookCraftButton")
	for node in _viewport.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if str(button.name) in allowed:
			if button.has_meta(LOCKED_META):
				button.disabled = bool(button.get_meta(LOCKED_META))
				button.remove_meta(LOCKED_META)
		elif not button.has_meta(LOCKED_META):
			button.set_meta(LOCKED_META, button.disabled)
			button.disabled = true


func _unlock_buttons() -> void:
	if _viewport == null:
		return
	for node in _viewport.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if button.has_meta(LOCKED_META):
			button.disabled = bool(button.get_meta(LOCKED_META))
			button.remove_meta(LOCKED_META)


func _locale() -> String:
	return str(_current_locale_fn.call()) if _current_locale_fn.is_valid() else "zh"


func _feed_source() -> GameSocialFeedSource:
	return ServiceRegistryScript.resolve(ServiceKeysScript.SOCIAL_FEED_SOURCE) as GameSocialFeedSource


func _on_tab_pressed(app_id: String) -> void:
	_app = app_id
	_show_app()
	GameEventBus.raise(UiIntentsScript.TERMINAL_APP_SELECTED, {UiIntentsScript.KEY_APP_ID: app_id})


func _on_exit_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.TERMINAL_EXIT_REQUESTED)


func _fit(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.custom_minimum_size = Vector2.ZERO
	control.position = rect.position
	control.size = rect.size
	control.clip_contents = true


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
