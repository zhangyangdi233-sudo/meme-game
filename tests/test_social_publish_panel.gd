extends SceneTree
## Social publish panel paints the publish page into the page host it is given.
## While shown it watches the remaining actions, the sentence being composed and the last publish result,
## repaints its own page, and raises the composer and confirm intents on the event bus.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const SocialFeedSourceScript = preload("res://scripts/game/social_feed_source.gd")
const SocialPublishPanelScript = preload("res://scripts/ui/social_publish_panel.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

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
	_test_the_shown_page_follows_remaining_actions()
	_test_the_shown_page_follows_the_sentence()
	_test_the_shown_page_shows_the_last_result()
	_test_showing_registers_once_and_hiding_lets_go()
	_test_a_released_page_is_not_repainted()
	_test_composer_and_confirm_raise_their_intents()


func _test_rendering_paints_the_page_into_the_host() -> void:
	var mounted := _mount()
	(mounted["panel"] as SocialPublishPanel).render(mounted["host"])
	_assert_true(_find(mounted, "SocialPublishPage") != null, "rendering should paint the publish page into the host")
	_assert_true(_find(mounted, "ComposerAnswerPanel") != null, "the publish page should host the sentence area")
	_assert_eq(_label_text(mounted, "SocialPublishUnitCounter"), "0 / 12 字", "the counter should read the source's soft limit")
	_dispose(mounted)


func _test_the_shown_page_follows_remaining_actions() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	var actions: ValuePropertyModel = mounted["actions"]
	(mounted["units"] as ListPropertyModel).replace_all(["门"])
	panel.render(mounted["host"])
	panel.set_shown(true)
	_assert_eq(_post_button_text(mounted), "投稿", "a day with actions left should allow posting")
	actions.write(0)
	_assert_eq(_post_button_text(mounted), "今天不能再投稿", "spending the last action should lock the page by itself")
	actions.write(2)
	_assert_eq(_post_button_text(mounted), "投稿", "refilled actions should unlock the page by itself")
	_dispose(mounted)


func _test_the_shown_page_follows_the_sentence() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	var units: ListPropertyModel = mounted["units"]
	panel.render(mounted["host"])
	panel.set_shown(true)
	_assert_eq(_post_button_text(mounted), "先放入一个字", "an empty sentence should ask for a word")
	_assert_true(_find(mounted, "ComposerAnswerPlaceholder") != null, "an empty sentence should show its placeholder")
	units.replace_all(["门", "开"])
	_assert_eq(_post_button_text(mounted), "投稿", "a placed word should unlock the page by itself")
	_assert_eq(_label_text(mounted, "ComposerPreviewLabel"), "门开", "the preview should join the placed words")
	_assert_eq(_label_text(mounted, "SocialPublishUnitCounter"), "2 / 12 字", "the counter should count the placed words")
	_assert_true(_find(mounted, "ComposerAnswerTile1") != null, "each placed word should get a tile")
	units.replace_all([])
	_assert_eq(_post_button_text(mounted), "先放入一个字", "posting should empty the page by itself")
	_dispose(mounted)


func _test_the_shown_page_shows_the_last_result() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	var result: MapPropertyModel = mounted["result"]
	panel.render(mounted["host"])
	panel.set_shown(true)
	_assert_eq(_label_text(mounted, "SocialPublishMoneyOutcome"), "资金  --", "no publication yet should show no money change")
	result.replace_all({"money_gain": 3, "pollution_gain": 4})
	_assert_eq(_label_text(mounted, "SocialPublishMoneyOutcome"), "资金  +3", "a publication should show its money change by itself")
	_assert_eq(_label_text(mounted, "SocialPublishPollutionOutcome"), "污染  +4%", "a publication should show its pollution change by itself")
	_dispose(mounted)


func _test_showing_registers_once_and_hiding_lets_go() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	for key in ["actions", "units", "result"]:
		_assert_eq(_listener_count(mounted[key]), 0, "a new panel should not listen to %s" % key)
	panel.set_shown(true)
	panel.set_shown(true)
	for key in ["actions", "units", "result"]:
		_assert_eq(_listener_count(mounted[key]), 1, "showing should register on %s once" % key)
	panel.set_shown(false)
	for key in ["actions", "units", "result"]:
		_assert_eq(_listener_count(mounted[key]), 0, "hiding should unregister from %s" % key)
	_dispose(mounted)


func _test_a_released_page_is_not_repainted() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	panel.render(mounted["host"])
	panel.set_shown(true)
	var page := _find(mounted, "SocialPublishPage")
	panel.release()
	(mounted["units"] as ListPropertyModel).add("门")
	_assert_true(page != null and _find(mounted, "SocialPublishPage") == page, "a released page should be left to whoever clears the host")
	_assert_true(panel.get_confirm_button() == null, "a released page should hand back no confirm button")
	_dispose(mounted)


func _test_composer_and_confirm_raise_their_intents() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialPublishPanel
	(mounted["units"] as ListPropertyModel).replace_all(["门", "开"])
	panel.render(mounted["host"])
	var dropped := {"unit": "门", "index": 3}
	_heard.clear()
	(_find(mounted, "ComposerAnswerPanel") as ComposerDropArea).unit_dropped.emit(dropped)
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED, {UiIntentsScript.KEY_DATA: dropped}]], "a drop on the area should raise the whole drag data")
	_heard.clear()
	(_find(mounted, "ComposerAnswerTile0") as ComposerAnswerTile).unit_dropped_before.emit(dropped, 1)
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED, {UiIntentsScript.KEY_DATA: dropped, UiIntentsScript.KEY_BEFORE_INDEX: 1}]], "a drop on a tile should raise the drag data and the index")
	_heard.clear()
	_press(mounted, "ComposerAnswerTile1")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: 1}]], "tapping a placed tile should raise its index")
	_heard.clear()
	_press(mounted, "SocialPublishPostButton")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED, {}]], "the post button should raise its intent")
	_heard.clear()
	var confirm := panel.get_confirm_button()
	_assert_true(confirm != null, "the panel should own the publish confirm button")
	if confirm != null:
		confirm.pressed.emit()
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_PUBLISH_CONFIRM_REQUESTED, {}]], "the confirm button should raise its intent")
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
	(manager.model(PropertyKeysScript.ACTIONS_REMAINING) as ValuePropertyModel).write(2)
	var host := VBoxContainer.new()
	host.name = "PublishTestHost"
	root.add_child(host)
	var panel: SocialPublishPanel = SocialPublishPanelScript.new()
	panel.name = "SocialPublishPanel"
	root.add_child(panel)
	return {
		"host": host,
		"panel": panel,
		"actions": manager.model(PropertyKeysScript.ACTIONS_REMAINING),
		"units": manager.model(PropertyKeysScript.FREE_SENTENCE_UNITS),
		"result": manager.model(PropertyKeysScript.LAST_PUBLISH_RESULT),
	}


## A typed stand-in for the game's social content: day 0 in Chinese, twelve words to a sentence.
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

	func composer_soft_unit_limit() -> int:
		return 12

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


func _post_button_text(mounted: Dictionary) -> String:
	var button := _find(mounted, "SocialPublishPostButton") as Button
	return button.text if button != null else "<missing>"


func _label_text(mounted: Dictionary, node_name: String) -> String:
	var label := _find(mounted, node_name) as Label
	return label.text if label != null else "<missing %s>" % node_name


func _press(mounted: Dictionary, node_name: String) -> void:
	var button := _find(mounted, node_name) as Button
	if button == null:
		_failures.append("missing button %s" % node_name)
		return
	button.pressed.emit()


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
