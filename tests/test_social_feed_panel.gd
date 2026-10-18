extends SceneTree
## Social feed panel watches the followed authors, liked posts, held words, finished memes, remaining actions,
## the sentence being composed, the last publish result and the published records on their property models.
## It also keeps its own page, channel and open post, and repaints itself when the player moves between them.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const SocialFeedSourceScript = preload("res://scripts/game/social_feed_source.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const DraggableWindowManagerScript = preload("res://framework/ui/draggable_window_manager.gd")

const POSTS := [
	{"id": "post-a", "caption": "甲"},
	{"id": "post-b", "caption": "乙"},
	{"id": "floor_13", "caption": "丙"},
]

var _failures: Array[String] = []
var _heard: Array = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("social feed panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _run() -> void:
	_test_painting_reads_the_bound_source_and_registers_drag_handles()
	_test_the_panel_keeps_no_signal_for_the_host()
	_test_showing_registers_once_and_syncs_both_models()
	_test_following_and_liking_repaint_the_open_feed()
	_test_the_following_channel_lists_followed_authors_only()
	_test_a_list_that_changed_while_hidden_is_painted_on_show()
	_test_hiding_unregisters_and_later_writes_are_ignored()
	_test_a_freed_panel_unregisters()
	_test_a_mounted_panel_is_not_opened_by_a_write()
	_test_showing_registers_the_holdings_and_syncs_the_profile_count()
	_test_a_new_meme_repaints_the_open_profile_by_itself()
	_test_a_new_meme_leaves_the_other_pages_alone()
	_test_showing_syncs_the_pickup_marks_and_a_new_word_repaints_them()
	_test_pickup_marks_take_the_flash_text_of_the_bound_palette()
	_test_the_comments_rule_is_a_hairline_and_cards_keep_their_strong_edge()
	_test_hiding_unregisters_the_holdings_and_later_writes_are_ignored()
	_test_a_freed_panel_unregisters_the_holdings()
	_test_the_open_publish_page_follows_remaining_actions()
	_test_a_channel_tab_repaints_the_feed_by_itself()
	_test_a_nav_button_switches_the_page_by_itself()
	_test_a_card_opens_its_post_and_the_close_button_shuts_it()
	_test_the_tower_base_channel_opens_the_first_post()
	_test_reset_view_returns_to_the_first_page()
	_test_the_open_publish_page_follows_the_sentence()
	_test_the_open_publish_page_shows_the_last_result()
	_test_a_new_publication_repaints_the_open_post_echo()
	_test_showing_registers_the_sentence_and_publishing_and_hiding_lets_go()
	_test_intent_names_and_payload_keys()
	_test_navigation_raises_channel_screen_and_post_intents()
	_test_like_follow_close_and_confirm_raise_their_intents()
	_test_pickup_and_composer_actions_carry_their_answers()
	_test_the_publish_page_belongs_to_its_own_panel()


func _test_painting_reads_the_bound_source_and_registers_drag_handles() -> void:
	var mounted := _mount()
	(mounted["panel"] as SocialFeedPanel).render_app()
	_assert_true(_find(mounted, "SocialChannelTabtower_base") != null, "painting should build the source's channels")
	var windows: DraggableWindowManager = mounted["windows"]
	_assert_true(windows.get_registered_window("app:social") != null, "painting should register the app window with the bound window manager")
	_assert_true(windows.get_registered_window("social-detail") != null, "mounting should register the detail window with the bound window manager")
	for handle_name in ["SocialPhoneStatusBar", "SocialDetailWindowHandle"]:
		var handle := _find(mounted, handle_name)
		_assert_true(handle != null and bool(handle.get_meta("drag_handle", false)), "%s should be a registered drag handle" % handle_name)
	_dispose(mounted)


func _test_the_panel_keeps_no_signal_for_the_host() -> void:
	var signals: Array = (SocialFeedPanel as Script).get_script_signal_list()
	_assert_eq(signals.map(func(entry: Dictionary) -> String: return str(entry["name"])), [], "the social panel should declare no signal for the host to connect")


func _test_showing_registers_once_and_syncs_both_models() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var followed: ListPropertyModel = mounted["followed"]
	var liked: ListPropertyModel = mounted["liked"]
	_assert_eq(_listener_count(followed), 0, "a mounted panel should not listen to follows before it is shown")
	_assert_eq(_listener_count(liked), 0, "a mounted panel should not listen to likes before it is shown")

	followed.replace_all(["post-a"])
	liked.replace_all(["post-b"])
	panel.render_app()
	panel.update_visibility(true, true)
	_assert_eq(_listener_count(followed), 1, "showing should register on the follow model")
	_assert_eq(_listener_count(liked), 1, "showing should register on the like model")
	_assert_eq(_follow_text(mounted, 0), "已关注", "showing should sync a followed author at once")
	_assert_eq(_follow_text(mounted, 1), "关注", "showing should leave other authors unfollowed")
	_assert_true(_like_text(mounted, 1).begins_with("♥"), "showing should sync a liked post at once")
	_assert_true(_like_text(mounted, 0).begins_with("♡"), "showing should leave other posts unliked")
	panel.update_visibility(true, true)
	_assert_eq(_listener_count(followed), 1, "showing again should not register twice")
	_assert_eq(_listener_count(liked), 1, "showing again should not register the likes twice")
	_dispose(mounted)


func _test_following_and_liking_repaint_the_open_feed() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var followed: ListPropertyModel = mounted["followed"]
	var liked: ListPropertyModel = mounted["liked"]
	panel.render_app()
	panel.update_visibility(true, true)
	_assert_eq(_follow_text(mounted, 0), "关注", "an unfollowed author should offer to follow")

	followed.add("post-a")
	_assert_eq(_follow_text(mounted, 0), "已关注", "following should repaint the open feed by itself")
	liked.add("post-a")
	_assert_true(_like_text(mounted, 0).begins_with("♥"), "liking should repaint the open feed by itself")
	followed.replace_all([])
	liked.replace_all([])
	_assert_eq(_follow_text(mounted, 0), "关注", "unfollowing should repaint the open feed by itself")
	_assert_true(_like_text(mounted, 0).begins_with("♡"), "unliking should repaint the open feed by itself")
	_dispose(mounted)


func _test_the_following_channel_lists_followed_authors_only() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var followed: ListPropertyModel = mounted["followed"]
	panel.render_app()
	panel.update_visibility(true, true)
	_press(mounted, "SocialChannelTabfollowing")
	_assert_true(_find(mounted, "SocialFollowingEmptyState") != null, "no follows should show the empty following channel")
	followed.add("post-b")
	_assert_true(_find(mounted, "SocialFollowingEmptyState") == null, "a follow should fill the following channel")
	_assert_true(_find(mounted, "SocialPostFollowButton1") != null, "the followed author's post should appear")
	_assert_true(_find(mounted, "SocialPostFollowButton0") == null, "an unfollowed author's post should stay out")
	_dispose(mounted)


func _test_a_list_that_changed_while_hidden_is_painted_on_show() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var followed: ListPropertyModel = mounted["followed"]
	panel.render_app()
	followed.add("post-a")
	_assert_eq(_follow_text(mounted, 0), "关注", "a hidden panel should not repaint")
	panel.update_visibility(true, true)
	_assert_eq(_follow_text(mounted, 0), "已关注", "showing should paint what changed while hidden")
	_dispose(mounted)


func _test_hiding_unregisters_and_later_writes_are_ignored() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var followed: ListPropertyModel = mounted["followed"]
	var liked: ListPropertyModel = mounted["liked"]
	panel.render_app()
	panel.update_visibility(true, true)
	panel.update_visibility(true, false)
	_assert_eq(_listener_count(followed), 0, "closing the app should unregister from the follow model")
	_assert_eq(_listener_count(liked), 0, "closing the app should unregister from the like model")
	followed.add("post-a")
	_assert_eq(_follow_text(mounted, 0), "关注", "a closed app should no longer receive changes")
	panel.update_visibility(false, true)
	_assert_eq(_listener_count(followed), 0, "a lowered phone should keep the app unregistered")
	_dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var followed: ListPropertyModel = mounted["followed"]
	var liked: ListPropertyModel = mounted["liked"]
	panel.update_visibility(true, true)
	_assert_eq(_listener_count(followed), 1, "a shown panel should listen")
	mounted["panel"] = null
	panel.free()
	_assert_eq(_listener_count(followed), 0, "a freed panel should leave the follow model")
	_assert_eq(_listener_count(liked), 0, "a freed panel should leave the like model")
	_dispose(mounted)


func _test_a_mounted_panel_is_not_opened_by_a_write() -> void:
	var mounted := _mount()
	var followed: ListPropertyModel = mounted["followed"]
	followed.add("post-a")
	_assert_true(_find(mounted, "SocialPhoneView") == null, "a write should not draw a feed nobody asked for")
	_dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	_heard.clear()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent_name: String, payload: Dictionary) -> void: _heard.append([intent_name, payload]))
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var parent := Control.new()
	parent.name = "SocialTestParent"
	parent.size = Vector2(900, 700)
	root.add_child(parent)
	var panel := SocialFeedPanel.new()
	panel.name = "SocialFeedPanel"
	root.add_child(panel)
	var windows: DraggableWindowManager = DraggableWindowManagerScript.new()
	parent.add_child(windows)
	RegistryScript.bind(ServiceKeysScript.WINDOW_MANAGER, windows)
	_bind_source()
	panel.mount(parent)
	return {
		"parent": parent,
		"panel": panel,
		"windows": windows,
		"followed": manager.model(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES),
		"liked": manager.model(PropertyKeysScript.SOCIAL_LIKED_POST_IDS),
		"held": manager.model(PropertyKeysScript.COLLECTED_CHAR_UNITS),
		"memes": manager.model(PropertyKeysScript.COMPLETED_MEMES),
		"actions": manager.model(PropertyKeysScript.ACTIONS_REMAINING),
		"units": manager.model(PropertyKeysScript.FREE_SENTENCE_UNITS),
		"result": manager.model(PropertyKeysScript.LAST_PUBLISH_RESULT),
		"published": manager.model(PropertyKeysScript.PUBLISHED_MEMES),
	}


func _bind_source() -> void:
	if not RegistryScript.has(ServiceKeysScript.UI_THEME):
		RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	RegistryScript.bind(ServiceKeysScript.SOCIAL_FEED_SOURCE, FakeSource.new())


## A typed stand-in for the game's social content: three fixed posts on day 0 in Chinese.
class FakeSource extends SocialFeedSourceScript:
	var _material := LanguageMaterial.new()

	func channels() -> Array:
		return [
			{"id": "discover", "label": "发现"},
			{"id": "following", "label": "关注"},
			{"id": "tower_base", "label": "塔下"},
		]

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

	func visible_post_indices(followed_handles: Array, channel: String) -> Array[int]:
		return SocialFeedContent.visible_post_indices({
			"post_cards": POSTS,
			"author_id": author_id,
		}, followed_handles, channel)

	func post_for_index(post_index: int) -> Dictionary:
		return POSTS[post_index]

	func like_text(post: Dictionary, post_index: int, liked_post_ids: Array) -> String:
		return SocialFeedContent.like_text(post, post_index, liked_post_ids)

	func caption_text(post: Dictionary, _post_index: int) -> String:
		return str(post.get("caption", ""))

	func author_id(post: Dictionary) -> String:
		return str(post.get("id", ""))

	func corrupt_text(text: String) -> String:
		return text

	func translate(text: String) -> String:
		return text

	func floor_label() -> String:
		return "1"

	func player_echo_quote() -> String:
		var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
		var published: Array = manager.model(PropertyKeysScript.PUBLISHED_MEMES).read()
		return "" if published.is_empty() else str((published[0] as Dictionary).get("text", ""))

	func echo_comment_handle() -> String:
		return ""

	func game_day() -> int:
		return 0

	func pollution() -> int:
		return 0

	func current_locale() -> String:
		return "zh"

	func language_material() -> LanguageMaterial:
		return _material


func _test_showing_registers_the_holdings_and_syncs_the_profile_count() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var held: ListPropertyModel = mounted["held"]
	var memes: ListPropertyModel = mounted["memes"]
	_assert_eq(_listener_count(held), 0, "a mounted panel should not listen to held words before it is shown")
	_assert_eq(_listener_count(memes), 0, "a mounted panel should not listen to memes before it is shown")
	memes.add({"id": "meme-1"})
	memes.add({"id": "meme-2"})
	panel.render_app()
	panel.show_screen("profile")
	panel.update_visibility(true, true)
	_assert_eq(_listener_count(held), 1, "showing should register on the held words")
	_assert_eq(_listener_count(memes), 1, "showing should register on the memes")
	_assert_eq(_meme_count_text(mounted), "已合成梗：2", "showing should sync the finished memes at once")
	panel.update_visibility(true, true)
	_assert_eq(_listener_count(memes), 1, "showing again should not register twice")
	_dispose(mounted)


func _test_a_new_meme_repaints_the_open_profile_by_itself() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var memes: ListPropertyModel = mounted["memes"]
	panel.render_app()
	panel.show_screen("profile")
	panel.update_visibility(true, true)
	_assert_eq(_meme_count_text(mounted), "已合成梗：0", "a fresh run should show no finished memes")
	memes.add({"id": "meme-1"})
	_assert_eq(_meme_count_text(mounted), "已合成梗：1", "a new meme should repaint the open profile by itself")
	memes.replace_all([])
	_assert_eq(_meme_count_text(mounted), "已合成梗：0", "clearing the memes should repaint the open profile by itself")
	_dispose(mounted)


func _test_a_new_meme_leaves_the_other_pages_alone() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var memes: ListPropertyModel = mounted["memes"]
	panel.render_app()
	panel.update_visibility(true, true)
	var feed := _find(mounted, "SocialPhoneView")
	memes.add({"id": "meme-1"})
	_assert_true(feed != null and _find(mounted, "SocialPhoneView") == feed, "a new meme should not redraw a page that does not show it")
	_dispose(mounted)


func _test_showing_syncs_the_pickup_marks_and_a_new_word_repaints_them() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var held: ListPropertyModel = mounted["held"]
	panel.render_app()
	panel.open_post(2)
	panel.update_visibility(true, true)
	_assert_true(_pickup_line(mounted).contains("[url=门]"), "a word nobody holds should be marked as pickable")

	held.add({"unit": "门", "locale": "zh", "source_post_id": "floor_13"})
	var line := _pickup_line(mounted)
	_assert_true(not line.contains("[url=门]"), "a word picked up should stop being pickable in the open post")
	_assert_true(line.contains("[color=#8b8f84]门[/color]"), "a word picked up should stay as a gray residue in the open post")
	held.replace_all([])
	_assert_true(_pickup_line(mounted).contains("[url=门]"), "a word given back should be pickable again")
	_dispose(mounted)


func _test_pickup_marks_take_the_flash_text_of_the_bound_palette() -> void:
	var mounted := _mount()
	var theme := RegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
	theme.configure({"pollution_stage": func() -> Dictionary: return {"palette_key": "pollution_palette_5"}})
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.open_post(2)
	panel.update_visibility(true, true)
	var flash_text := UiPalette.color(UiPalette.POLLUTION_PALETTE_5, "flash_text").to_html(false)
	_assert_true(_pickup_line(mounted).contains("[color=#%s][url=门]" % flash_text), "a pickable word should take the bound palette's flash_text: %s" % _pickup_line(mounted))
	_dispose(mounted)


func _test_the_comments_rule_is_a_hairline_and_cards_keep_their_strong_edge() -> void:
	var mounted := _mount()
	var theme := RegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
	theme.configure({"pollution_stage": func() -> Dictionary: return {"palette_key": "pollution_palette_5"}})
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	var card := _find(mounted, "SocialPostCard0") as PanelContainer
	_assert_true(card != null, "the discover feed should show the first post card")
	if card != null:
		## The card edge is an emphasis, not a divider, so it keeps its own strength.
		var strong_edge := Color(UiPalette.color(UiPalette.POLLUTION_PALETTE_5, "muted"), 0.62)
		_assert_eq((card.get_theme_stylebox("panel") as StyleBoxFlat).border_color, strong_edge, "a post card should keep its strong muted edge")
	panel.open_post(2)
	panel.update_visibility(true, true)
	var rule := _find(mounted, "SocialCommentsRule") as ColorRect
	_assert_true(rule != null, "an open post with comments should draw a rule above them")
	if rule != null:
		_assert_eq(rule.color, theme.hairline(), "the comments rule should be the hairline")
	_dispose(mounted)


func _test_hiding_unregisters_the_holdings_and_later_writes_are_ignored() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var held: ListPropertyModel = mounted["held"]
	var memes: ListPropertyModel = mounted["memes"]
	panel.render_app()
	panel.show_screen("profile")
	panel.update_visibility(true, true)
	panel.update_visibility(true, false)
	_assert_eq(_listener_count(held), 0, "closing the app should unregister from the held words")
	_assert_eq(_listener_count(memes), 0, "closing the app should unregister from the memes")
	memes.add({"id": "meme-1"})
	_assert_eq(_meme_count_text(mounted), "已合成梗：0", "a closed app should no longer receive new memes")
	panel.update_visibility(true, true)
	_assert_eq(_meme_count_text(mounted), "已合成梗：1", "showing again should paint what changed while closed")
	_dispose(mounted)


func _test_a_freed_panel_unregisters_the_holdings() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var held: ListPropertyModel = mounted["held"]
	var memes: ListPropertyModel = mounted["memes"]
	panel.update_visibility(true, true)
	mounted["panel"] = null
	panel.free()
	_assert_eq(_listener_count(held), 0, "a freed panel should leave the held words")
	_assert_eq(_listener_count(memes), 0, "a freed panel should leave the memes")
	_dispose(mounted)


## The count line on the profile page, or "<missing>" when that page is not drawn.
func _test_the_open_publish_page_follows_remaining_actions() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var actions: ValuePropertyModel = mounted["actions"]
	(mounted["units"] as ListPropertyModel).replace_all(["门"])
	panel.render_app()
	panel.show_screen("publish")
	panel.update_visibility(true, true)
	_assert_eq(_listener_count(actions), 1, "showing should register on remaining actions once")
	_assert_eq(_post_button_text(mounted), "投稿", "a day with actions left should allow posting")

	actions.write(0)
	_assert_eq(_post_button_text(mounted), "今天不能再投稿", "spending the last action should lock the open publish page by itself")
	actions.write(2)
	_assert_eq(_post_button_text(mounted), "投稿", "refilled actions should unlock the open publish page by itself")

	panel.update_visibility(true, false)
	_assert_eq(_listener_count(actions), 0, "hiding should drop the actions listener")
	_dispose(mounted)

	mounted = _mount()
	panel = mounted["panel"] as SocialFeedPanel
	actions = mounted["actions"]
	panel.render_app()
	panel.update_visibility(true, true)
	var feed := _find(mounted, "SocialPhoneView")
	actions.write(0)
	_assert_true(feed != null and _find(mounted, "SocialPhoneView") == feed, "an action write should not redraw a page without the post button")
	_dispose(mounted)


func _test_a_channel_tab_repaints_the_feed_by_itself() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.update_visibility(true, true)
	_assert_true(_underline_shown(mounted, "discover"), "a fresh feed should select the discover channel")
	_heard.clear()
	_press(mounted, "SocialChannelTabfollowing")
	_assert_true(_underline_shown(mounted, "following"), "pressing a channel tab should select it without the host")
	_assert_true(not _underline_shown(mounted, "discover"), "pressing a channel tab should deselect the old channel")
	_assert_true(_find(mounted, "SocialFollowingEmptyState") != null, "the following channel should list followed authors only")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_CHANNEL_PRESSED, {UiIntentsScript.KEY_CHANNEL: "following"}]], "a channel change should tell the host once which channel")
	_press(mounted, "SocialChannelTabdiscover")
	_assert_true(_find(mounted, "SocialPostFollowButton0") != null, "going back to discover should list every post again")
	_dispose(mounted)


func _test_a_nav_button_switches_the_page_by_itself() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	(mounted["units"] as ListPropertyModel).replace_all(["门"])
	panel.render_app()
	panel.update_visibility(true, true)
	_press(mounted, "SocialChannelTabfollowing")
	_press(mounted, "SocialNavMine")
	_assert_eq(_meme_count_text(mounted), "已合成梗：0", "the profile button should open the profile page without the host")
	_press(mounted, "SocialNavCreate")
	_assert_eq(_post_button_text(mounted), "投稿", "the publish button should open the publish page without the host")
	_press(mounted, "SocialNavHome")
	_assert_true(_find(mounted, "SocialHomePage") != null, "the home button should bring the feed back")
	_assert_true(_underline_shown(mounted, "discover"), "switching pages should land on the discover channel")
	_dispose(mounted)


func _test_a_card_opens_its_post_and_the_close_button_shuts_it() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.update_visibility(true, true)
	var detail := panel.get_detail_window()
	_assert_true(not panel.is_detail_open() and not detail.visible, "a fresh feed should keep the post detail shut")
	_click_card(mounted, 2)
	_assert_true(panel.is_detail_open(), "clicking a card should open its post")
	_assert_true(detail.visible, "an open post should show its window while the app shows")
	_assert_true(_find(mounted, "SocialPickupLineText") != null, "an open post should paint its detail by itself")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: 2}]], "opening a post should tell the host which post")
	_press(mounted, "SocialNavMine")
	_assert_true(not panel.is_detail_open() and not detail.visible, "switching pages should shut the open post")

	_click_card_after_home(mounted, 0)
	_press(mounted, "SocialDetailWindowCloseButton")
	_assert_true(not panel.is_detail_open(), "the close button should shut the post without the host")
	_assert_true(not detail.visible, "a shut post should hide its window")
	_dispose(mounted)


func _test_the_tower_base_channel_opens_the_first_post() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.update_visibility(true, true)
	_heard.clear()
	_press(mounted, "SocialChannelTabtower_base")
	_assert_true(panel.is_detail_open(), "the tower base channel should open the first post")
	_assert_true(_underline_shown(mounted, "tower_base"), "the tower base channel should stay selected while its post is open")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_CHANNEL_PRESSED, {UiIntentsScript.KEY_CHANNEL: "tower_base"}]], "the tower base channel is not the player opening a post, so the tutorial should hear only of the channel change")
	_press(mounted, "SocialDetailWindowCloseButton")
	_assert_true(_underline_shown(mounted, "discover"), "shutting the tower base post should go back to discover")
	_dispose(mounted)


func _test_reset_view_returns_to_the_first_page() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.update_visibility(true, true)
	_press(mounted, "SocialChannelTabfollowing")
	_press(mounted, "SocialNavMine")
	panel.open_post(1)
	panel.reset_view()
	_assert_true(not panel.is_detail_open(), "a new run should shut the open post")
	_assert_true(not panel.get_detail_window().visible, "a new run should hide the post window")
	panel.render_app()
	_assert_true(_find(mounted, "SocialHomePage") != null, "a new run should start on the home page")
	_assert_true(_underline_shown(mounted, "discover"), "a new run should start on the discover channel")
	_dispose(mounted)


func _test_the_open_publish_page_follows_the_sentence() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var units: ListPropertyModel = mounted["units"]
	panel.render_app()
	panel.show_screen("publish")
	panel.update_visibility(true, true)
	_assert_eq(_post_button_text(mounted), "先放入一个字", "an empty sentence should ask for a word")
	_assert_true(_find(mounted, "ComposerAnswerPlaceholder") != null, "an empty sentence should show its placeholder")
	units.replace_all(["门", "开"])
	_assert_eq(_post_button_text(mounted), "投稿", "a placed word should unlock the open publish page by itself")
	_assert_eq(_label_text(mounted, "ComposerPreviewLabel"), "门开", "the preview should join the placed words")
	_assert_eq(_label_text(mounted, "SocialPublishUnitCounter"), "2 / 12 字", "the counter should count the placed words")
	_assert_true(_find(mounted, "ComposerAnswerTile1") != null, "each placed word should get a tile")
	units.replace_all([])
	_assert_eq(_post_button_text(mounted), "先放入一个字", "posting should empty the open publish page by itself")

	_dispose(mounted)

	mounted = _mount()
	panel = mounted["panel"] as SocialFeedPanel
	units = mounted["units"]
	panel.render_app()
	panel.update_visibility(true, true)
	var feed := _find(mounted, "SocialPhoneView")
	units.add("门")
	_assert_true(feed != null and _find(mounted, "SocialPhoneView") == feed, "a sentence write should not redraw a page without the composer")
	_dispose(mounted)


func _test_the_open_publish_page_shows_the_last_result() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var result: MapPropertyModel = mounted["result"]
	panel.render_app()
	panel.show_screen("publish")
	panel.update_visibility(true, true)
	_assert_eq(_label_text(mounted, "SocialPublishMoneyOutcome"), "资金  --", "no publication yet should show no money change")
	result.replace_all({"money_gain": 3, "pollution_gain": 4})
	_assert_eq(_label_text(mounted, "SocialPublishMoneyOutcome"), "资金  +3", "a publication should show its money change by itself")
	_assert_eq(_label_text(mounted, "SocialPublishPollutionOutcome"), "污染  +4%", "a publication should show its pollution change by itself")
	_dispose(mounted)


func _test_a_new_publication_repaints_the_open_post_echo() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var published: ListPropertyModel = mounted["published"]
	panel.render_app()
	panel.update_visibility(true, true)
	panel.open_post(2)
	_assert_true(_find(mounted, "SocialEchoComment") == null, "no publication yet should leave no echo under the post")
	published.insert_at(0, {"id": "free-1-1", "kind": "free_sentence", "text": "门开"})
	_assert_true(_find(mounted, "SocialEchoComment") != null, "a new publication should echo under the open post by itself")
	_dispose(mounted)


func _test_showing_registers_the_sentence_and_publishing_and_hiding_lets_go() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	for key in ["units", "result", "published"]:
		_assert_eq(_listener_count(mounted[key]), 0, "a mounted panel should not listen to %s before it is shown" % key)
	panel.update_visibility(true, true)
	for key in ["units", "result", "published"]:
		_assert_eq(_listener_count(mounted[key]), 1, "showing should register on %s once" % key)
	panel.update_visibility(true, false)
	for key in ["units", "result", "published"]:
		_assert_eq(_listener_count(mounted[key]), 0, "hiding should unregister from %s" % key)
	_dispose(mounted)


func _test_intent_names_and_payload_keys() -> void:
	_assert_eq(UiIntentsScript.SOCIAL_CHANNEL_PRESSED, "social_channel_pressed", "channel intent name")
	_assert_eq(UiIntentsScript.SOCIAL_SCREEN_REQUESTED, "social_screen_requested", "screen intent name")
	_assert_eq(UiIntentsScript.SOCIAL_CARD_CLICKED, "social_card_clicked", "card intent name")
	_assert_eq(UiIntentsScript.SOCIAL_LIKE_PRESSED, "social_like_pressed", "like intent name")
	_assert_eq(UiIntentsScript.SOCIAL_FOLLOW_PRESSED, "social_follow_pressed", "follow intent name")
	_assert_eq(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, "social_pickup_unit_clicked", "pickup intent name")
	_assert_eq(UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED, "social_composer_area_dropped", "area drop intent name")
	_assert_eq(UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED, "social_composer_tile_dropped", "tile drop intent name")
	_assert_eq(UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED, "social_composer_answer_tapped", "answer tap intent name")
	_assert_eq(UiIntentsScript.SOCIAL_CLOSE_REQUESTED, "social_close_requested", "close intent name")
	_assert_eq(UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED, "social_detail_close_requested", "detail close intent name")
	_assert_eq(UiIntentsScript.SOCIAL_PUBLISH_CONFIRM_REQUESTED, "social_publish_confirm_requested", "publish confirm intent name")
	_assert_eq(UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED, "social_composer_submit_requested", "submit intent name")
	_assert_eq(UiIntentsScript.KEY_CHANNEL, "channel", "channel payload key")
	_assert_eq(UiIntentsScript.KEY_SCREEN, "screen", "screen payload key")
	_assert_eq(UiIntentsScript.KEY_POST_INDEX, "post_index", "post index payload key")
	_assert_eq(UiIntentsScript.KEY_POST_ID, "post_id", "post id payload key")
	_assert_eq(UiIntentsScript.KEY_AUTHOR_ID, "author_id", "author id payload key")
	_assert_eq(UiIntentsScript.KEY_META, "meta", "meta payload key")
	_assert_eq(UiIntentsScript.KEY_DATA, "data", "data payload key")
	_assert_eq(UiIntentsScript.KEY_BEFORE_INDEX, "before_index", "before index payload key")
	_assert_eq(UiIntentsScript.KEY_UNIT_INDEX, "unit_index", "unit index payload key")


func _test_navigation_raises_channel_screen_and_post_intents() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.update_visibility(true, true)
	_heard.clear()
	_press(mounted, "SocialNavMine")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_SCREEN_REQUESTED, {UiIntentsScript.KEY_SCREEN: "profile"}]], "a nav button should raise its screen")
	_press(mounted, "SocialNavHome")
	_heard.clear()
	_click_card(mounted, 1)
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: 1}]], "a card click should raise its post index")
	_heard.clear()
	_press(mounted, "SocialDetailWindowCloseButton")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED, {}]], "the detail close button should raise its intent")
	_dispose(mounted)


func _test_like_follow_close_and_confirm_raise_their_intents() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	panel.render_app()
	panel.update_visibility(true, true)
	_heard.clear()
	_press(mounted, "SocialPostLikeButton1")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: "post-b"}]], "a like button should raise its post id")
	_heard.clear()
	_press(mounted, "SocialPostFollowButton0")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_FOLLOW_PRESSED, {UiIntentsScript.KEY_AUTHOR_ID: "post-a"}]], "a follow button should raise its author id")
	_heard.clear()
	_press(mounted, "SocialAppInlineCloseButton")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_CLOSE_REQUESTED, {}]], "the app close button should raise its intent")
	panel.show_screen("publish")
	_heard.clear()
	_press(mounted, "SocialPublishButton")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_PUBLISH_CONFIRM_REQUESTED, {}]], "the publish confirm button should raise its intent")
	_dispose(mounted)


func _test_pickup_and_composer_actions_carry_their_answers() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	(mounted["units"] as ListPropertyModel).replace_all(["门", "开"])
	panel.render_app()
	panel.open_post(2)
	panel.update_visibility(true, true)
	_heard.clear()
	(_find(mounted, "SocialPickupLineText") as RichTextLabel).meta_clicked.emit("门")
	_assert_eq(_heard, [[UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: "门", UiIntentsScript.KEY_POST_ID: "floor_13"}]], "a pickup click should raise the meta and its post")

	panel.show_screen("publish")
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
	_dispose(mounted)


func _test_the_publish_page_belongs_to_its_own_panel() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
	var publish: SocialPublishPanel = null
	for child in panel.get_children():
		if child is SocialPublishPanel:
			publish = child
	_assert_true(publish != null, "mounting should give the social panel one publish panel")
	_assert_true(not panel.has_method("get_confirm_publish_button"), "the social panel should no longer own the publish confirm button")
	panel.render_app()
	panel.show_screen("publish")
	_assert_true(publish != null and publish.get_confirm_button() != null, "the publish screen should be painted by the publish panel")
	panel.show_screen("home")
	_assert_true(publish != null and publish.get_confirm_button() == null, "leaving the publish screen should release the publish page")
	_dispose(mounted)


func _label_text(mounted: Dictionary, node_name: String) -> String:
	var label := _find(mounted, node_name) as Label
	return label.text if label != null else "<missing %s>" % node_name


func _press(mounted: Dictionary, node_name: String) -> void:
	var button := _find(mounted, node_name) as Button
	if button == null:
		_failures.append("missing button %s" % node_name)
		return
	button.pressed.emit()


func _click_card(mounted: Dictionary, post_index: int) -> void:
	var card := _find(mounted, "SocialPostCard%d" % post_index) as Control
	if card == null:
		_failures.append("missing card %d" % post_index)
		return
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	card.gui_input.emit(press)


func _click_card_after_home(mounted: Dictionary, post_index: int) -> void:
	_press(mounted, "SocialNavHome")
	_click_card(mounted, post_index)


func _underline_shown(mounted: Dictionary, channel: String) -> bool:
	var underline := _find(mounted, "SocialChannelTabUnderline%s" % channel) as ColorRect
	return underline != null and underline.visible


func _post_button_text(mounted: Dictionary) -> String:
	var button := _find(mounted, "SocialPublishPostButton") as Button
	return button.text if button != null else "<missing>"


func _meme_count_text(mounted: Dictionary) -> String:
	var label := _find_label_with_prefix(mounted["parent"], "已合成梗")
	return label.text if label != null else "<missing>"


func _pickup_line(mounted: Dictionary) -> String:
	var line := _find(mounted, "SocialPickupLineText") as RichTextLabel
	return line.text if line != null else "<missing>"


func _find_label_with_prefix(node: Node, prefix: String) -> Label:
	if node.is_queued_for_deletion():
		return null
	if node is Label and (node as Label).text.begins_with(prefix):
		return node as Label
	for child in node.get_children():
		var found := _find_label_with_prefix(child, prefix)
		if found != null:
			return found
	return null


## A repaint queues the old cards for deletion, so a node about to go does not count.
func _find(mounted: Dictionary, node_name: String) -> Node:
	return _find_live(mounted["parent"], node_name)


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


func _follow_text(mounted: Dictionary, post_index: int) -> String:
	var button := _find(mounted, "SocialPostFollowButton%d" % post_index) as Button
	return button.text if button != null else "<missing>"


func _like_text(mounted: Dictionary, post_index: int) -> String:
	var button := _find(mounted, "SocialPostLikeButton%d" % post_index) as Button
	return button.text if button != null else "<missing>"


func _dispose(mounted: Dictionary) -> void:
	var panel: Node = mounted["panel"]
	if panel != null and is_instance_valid(panel):
		panel.free()
	var parent: Node = mounted["parent"]
	if parent != null and is_instance_valid(parent):
		parent.free()
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
