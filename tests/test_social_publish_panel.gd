extends SceneTree
## Social publish panel paints the publish page into the page host it is given. The sentence is composed and posted in
## the notebook (#154); this page only shows the last post and points there. While shown it watches the posts and
## repaints its own page. The old-meme confirm button and its funds outcome are gone.

const BootScript = preload("res://scripts/game/property_boot.gd")
const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const SocialFeedSourceScript = preload("res://scripts/game/social_feed_source.gd")
const SocialPublishPanelScript = preload("res://scripts/ui/social_publish_panel.gd")

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("social publish panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _run() -> void:
	_test_rendering_paints_the_page_into_the_host()
	_test_the_page_composes_nothing_and_points_to_the_notebook()
	_test_the_page_shows_the_last_post()
	_test_the_page_has_no_old_meme_route()
	_test_showing_registers_once_and_hiding_lets_go()
	_test_a_released_page_is_not_repainted()


func _test_rendering_paints_the_page_into_the_host() -> void:
	var mounted := _mount()
	(mounted["panel"] as SocialPublishPanel).render(mounted["host"])
	_assert_true(_find(mounted, "SocialPublishPage") != null, "rendering should paint the publish page into the host")
	_dispose(mounted)


func _test_the_page_composes_nothing_and_points_to_the_notebook() -> void:
	var mounted := _mount()
	(mounted["units"] as ListPropertyModel).replace_all(["门"])
	(mounted["panel"] as SocialPublishPanel).render(mounted["host"])
	for node_name in ["ComposerAnswerPanel", "SocialPublishPostButton", "SocialPublishUnitCounter", "ComposerPreviewLabel"]:
		_assert_true(_find(mounted, node_name) == null, "the publish page should not build %s" % node_name)
	var hint := _find(mounted, "SocialPublishNotebookHint") as Label
	_assert_true(hint != null and hint.text == "在笔记本里拼句、投稿。", "the page should send the player to the notebook")
	_assert_true(_find(mounted, "PublishEmptyLine") != null, "with no post yet the page should say so")
	_dispose(mounted)


func _test_the_page_shows_the_last_post() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	panel.render(mounted["host"])
	panel.set_shown(true)
	_assert_true(_find(mounted, "LastPostSlip") == null, "no post should show no slip")
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var published: ListPropertyModel = manager.model(PropertyKeysScript.PUBLISHED_MEMES)
	published.insert_at(0, {"kind": "free_sentence", "text": "灯亮", "tier": "rule"})
	var slip := _find(mounted, "LastPostSlip") as Label
	_assert_true(slip != null and slip.text.contains("灯亮"), "a post should show on the page by itself")
	_assert_true(_find(mounted, "PublishEmptyLine") == null, "a post should replace the empty line")
	(manager.model(PropertyKeysScript.CHAPTER_ONE_PROGRESS) as MapPropertyModel).replace_all(ProgressScript.jump_to_round(ProgressScript.initial(), 2))
	_assert_true(_find(mounted, "LastPostSlip") == null, "a new round should not show an earlier round's post")
	panel.set_shown(false)
	_dispose(mounted)


func _test_the_page_has_no_old_meme_route() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	panel.render(mounted["host"])
	panel.set_shown(true)
	for node_name in ["SocialPublishButton", "SocialPublishActionBar", "SocialPublishOutcomePanel", "SocialPublishMoneyOutcome"]:
		_assert_true(_find(mounted, node_name) == null, "the publish page should not build %s" % node_name)
	_assert_true(not panel.has_method("get_confirm_button"), "the panel should offer no confirm button")
	var text := Harness.collect_control_text(mounted["host"])
	for word in ["确认发布", "资金", "行动", "DAY"]:
		_assert_true(not text.contains(word), "the publish page should not word %s" % word)
	_dispose(mounted)


func _test_showing_registers_once_and_hiding_lets_go() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	_assert_eq(_listener_count(mounted["published"]), 0, "a new panel should not listen to the posts")
	panel.set_shown(true)
	panel.set_shown(true)
	_assert_eq(_listener_count(mounted["published"]), 1, "showing should register on the posts once")
	_assert_eq(_listener_count(mounted["units"]), 0, "the page should not watch the sentence any more")
	panel.set_shown(false)
	_assert_eq(_listener_count(mounted["published"]), 0, "hiding should unregister from the posts")
	_dispose(mounted)


func _test_a_released_page_is_not_repainted() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	panel.render(mounted["host"])
	panel.set_shown(true)
	var page := _find(mounted, "SocialPublishPage")
	panel.release()
	(mounted["published"] as ListPropertyModel).insert_at(0, {"kind": "free_sentence", "text": "灯亮", "tier": "rule"})
	_assert_true(page != null and _find(mounted, "SocialPublishPage") == page, "a released page should be left to whoever clears the host")
	panel.set_shown(false)
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	RegistryScript.bind(ServiceKeysScript.SOCIAL_FEED_SOURCE, FakeSource.new())
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var host := VBoxContainer.new()
	host.name = "PublishTestHost"
	root.add_child(host)
	var panel: SocialPublishPanel = SocialPublishPanelScript.new()
	panel.name = "SocialPublishPanel"
	root.add_child(panel)
	return {
		"host": host,
		"panel": panel,
		"units": manager.model(PropertyKeysScript.FREE_SENTENCE_UNITS),
		"published": manager.model(PropertyKeysScript.PUBLISHED_MEMES),
	}


## A typed stand-in for the game's social content: day 0 in Chinese.
class FakeSource extends SocialFeedSourceScript:
	func channels() -> Array:
		return []

	func load_texture(_path: String) -> Texture2D:
		return null

	func poster_texture(_poster_cell: int) -> Texture2D:
		return null

	func poster_sheet_path() -> String:
		return ""

	func poster_sheet_count() -> int:
		return 0

	func no_signal_icon_path() -> String:
		return ""

	func player_character_path() -> String:
		return ""

	func visible_post_indices(_followed_handles: Array, _channel: String) -> Array[int]:
		return []

	func post_for_index(_post_index: int) -> Dictionary:
		return {}

	func like_text(_post: Dictionary, _post_index: int, _liked_post_ids: Array) -> String:
		return ""

	func caption_text(_post: Dictionary, _post_index: int) -> String:
		return ""

	func author_id(_post: Dictionary) -> String:
		return ""

	func corrupt_text(text: String) -> String:
		return text

	func translate(text: String) -> String:
		return text

	func floor_label() -> String:
		return "1"

	func player_echo_quote() -> String:
		return ""

	func echo_comment_handle() -> String:
		return ""

	func game_day() -> int:
		return 0

	func pollution() -> int:
		return 0

	func current_locale() -> String:
		return "zh"

	func language_material() -> LanguageMaterial:
		return null


func _find(mounted: Dictionary, node_name: String) -> Node:
	return _find_live(mounted["host"], node_name)


func _find_live(node: Node, node_name: String) -> Node:
	if node.is_queued_for_deletion():
		return null
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_live(child, node_name)
		if found != null:
			return found
	return null


func _dispose(mounted: Dictionary) -> void:
	for key in ["panel", "host"]:
		var node: Node = mounted[key]
		if node != null and is_instance_valid(node):
			node.free()
	RegistryScript.clear()


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
