extends SceneTree
## Social feed panel watches the followed authors, liked posts, held words, finished memes and remaining actions on their property models.
## It also keeps its own page, channel and open post, and repaints itself when the player moves between them.

const BootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

const POSTS := [
	{"id": "post-a", "caption": "甲"},
	{"id": "post-b", "caption": "乙"},
	{"id": "floor_13", "caption": "丙"},
]

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("social feed panel tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
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
	_test_hiding_unregisters_the_holdings_and_later_writes_are_ignored()
	_test_a_freed_panel_unregisters_the_holdings()
	_test_the_open_publish_page_follows_remaining_actions()
	_test_a_channel_tab_repaints_the_feed_by_itself()
	_test_a_nav_button_switches_the_page_by_itself()
	_test_a_card_opens_its_post_and_the_close_button_shuts_it()
	_test_the_tower_base_channel_opens_the_first_post()
	_test_reset_view_returns_to_the_first_page()


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
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var parent := Control.new()
	parent.name = "SocialTestParent"
	parent.size = Vector2(900, 700)
	root.add_child(parent)
	var panel := SocialFeedPanel.new()
	panel.name = "SocialFeedPanel"
	root.add_child(panel)
	panel.mount(parent, _deps())
	return {
		"parent": parent,
		"panel": panel,
		"followed": manager.model(PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES),
		"liked": manager.model(PropertyKeysScript.SOCIAL_LIKED_POST_IDS),
		"held": manager.model(PropertyKeysScript.COLLECTED_CHAR_UNITS),
		"memes": manager.model(PropertyKeysScript.COMPLETED_MEMES),
		"actions": manager.model(PropertyKeysScript.ACTIONS_REMAINING),
	}


func _deps() -> Dictionary:
	var author_id := func(post: Dictionary) -> String: return str(post.get("id", ""))
	return {
		"panel_factory": func(): return PanelContainer.new(),
		"label_factory": func(text: String, _size: int, _color: Color) -> Label:
			var label := Label.new()
			label.text = text
			return label,
		"theme_color": func(_key: String) -> Color: return Color.WHITE,
		"style_fn": func(_fill: Color, _border: Color) -> StyleBoxFlat: return StyleBoxFlat.new(),
		"ui_font_size": func(size: int) -> int: return size,
		"register_draggable": func(_window: Control, _id: String, _handle: Control) -> void: pass,
		"load_texture": func(_path: String): return null,
		"poster_texture": func(_post_index: int): return null,
		"channels": [
			{"id": "discover", "label": "发现"},
			{"id": "following", "label": "关注"},
			{"id": "tower_base", "label": "塔下"},
		],
		"visible_post_indices": func(followed_handles: Array, channel: String) -> Array[int]:
			return SocialFeedContent.visible_post_indices({
				"post_cards": POSTS,
				"author_id": author_id,
			}, followed_handles, channel),
		"post_for_index": func(post_index: int) -> Dictionary: return POSTS[post_index],
		"like_text": func(post: Dictionary, post_index: int, liked_post_ids: Array) -> String:
			return SocialFeedContent.like_text(post, post_index, liked_post_ids),
		"caption_text": func(post: Dictionary, _post_index: int) -> String: return str(post.get("caption", "")),
		"author_id": author_id,
		"floor_label": func() -> String: return "1",
		"language_material": LanguageMaterial.new(),
		"current_locale": func() -> String: return "zh",
		"free_sentence_units": func() -> Array: return ["门"],
	}


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
	var page_changes := _count_page_changes(panel)
	_press(mounted, "SocialChannelTabfollowing")
	_assert_true(_underline_shown(mounted, "following"), "pressing a channel tab should select it without the host")
	_assert_true(not _underline_shown(mounted, "discover"), "pressing a channel tab should deselect the old channel")
	_assert_true(_find(mounted, "SocialFollowingEmptyState") != null, "the following channel should list followed authors only")
	_assert_eq(page_changes[0], 1, "a channel change should tell the host once that the page changed")
	_press(mounted, "SocialChannelTabdiscover")
	_assert_true(_find(mounted, "SocialPostFollowButton0") != null, "going back to discover should list every post again")
	_dispose(mounted)


func _test_a_nav_button_switches_the_page_by_itself() -> void:
	var mounted := _mount()
	var panel := mounted["panel"] as SocialFeedPanel
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
	var opened: Array = []
	panel.post_opened.connect(func(post_index: int) -> void: opened.append(post_index))
	panel.render_app()
	panel.update_visibility(true, true)
	var detail := panel.get_detail_window()
	_assert_true(not panel.is_detail_open() and not detail.visible, "a fresh feed should keep the post detail shut")
	_click_card(mounted, 2)
	_assert_true(panel.is_detail_open(), "clicking a card should open its post")
	_assert_true(detail.visible, "an open post should show its window while the app shows")
	_assert_true(_find(mounted, "SocialPickupLineText") != null, "an open post should paint its detail by itself")
	_assert_eq(opened, [2], "opening a post should tell the host which post")
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
	var opened: Array = []
	panel.post_opened.connect(func(post_index: int) -> void: opened.append(post_index))
	panel.render_app()
	panel.update_visibility(true, true)
	var page_changes := _count_page_changes(panel)
	_press(mounted, "SocialChannelTabtower_base")
	_assert_true(panel.is_detail_open(), "the tower base channel should open the first post")
	_assert_true(_underline_shown(mounted, "tower_base"), "the tower base channel should stay selected while its post is open")
	_assert_eq(opened, [], "the tower base channel is not the player opening a post, so the tutorial should not hear of it")
	_assert_eq(page_changes[0], 1, "the tower base channel should tell the host once that the page changed")
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


func _count_page_changes(panel: SocialFeedPanel) -> Array:
	var count := [0]
	panel.page_changed.connect(func() -> void: count[0] += 1)
	return count


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
