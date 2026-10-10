extends SceneTree
## Phone-shell snapshot refresh: social / phone / action-economy updates paint the phone, not ending or Reality HUD.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const SocialFeedContentScript = preload("res://scripts/game/social_feed_content.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

const HUD_SENTINEL := "HUD_SENTINEL_PHONE_SHELL"
const ENDING_SENTINEL := "ENDING_SENTINEL_PHONE_SHELL"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	await _test_like_refreshes_phone_shell_not_hud()
	await _test_channel_refreshes_phone_shell_not_hud()
	await _test_spend_action_refreshes_phone_shell_not_hud()
	await _test_opening_app_refreshes_phone_shell_not_hud()
	await _test_phone_popup_follows_the_phone_model()
	await _test_like_does_not_rerun_ending()
	if _failures.is_empty():
		print("phone shell refresh UI tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_like_refreshes_phone_shell_not_hud() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return
	game_root._on_app_pressed("social")
	await process_frame

	var like_button := Harness.find_node_by_name(game_root, "SocialPostLikeButton0") as Button
	_assert_true(like_button != null, "social home should expose a like button")
	if like_button != null:
		_assert_true(like_button.text.begins_with("♡"), "an unliked post should show an empty heart")

	var hud := _stamp_hud(game_root)
	var post: Dictionary = SocialFeedContentScript.post_for_index(0, game_root._social_content_deps())
	var post_id := str(post.get("id", ""))
	_assert_true(not post_id.is_empty(), "first feed card should have a post id")
	game_root._on_social_like_pressed(post_id)
	await process_frame

	like_button = Harness.find_node_by_name(game_root, "SocialPostLikeButton0") as Button
	_assert_true(like_button != null, "liking a post should keep the phone-shell like button")
	if like_button != null:
		_assert_true(like_button.text.begins_with("♥"), "phone shell should show the liked heart")
	_assert_hud_untouched(hud, "liking a post")

	game_root.queue_free()
	await process_frame


func _test_channel_refreshes_phone_shell_not_hud() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return
	game_root._on_app_pressed("social")
	await process_frame

	var discover := Harness.find_node_by_name(game_root, "SocialChannelTabUnderlinediscover") as ColorRect
	_assert_true(discover != null and discover.visible, "discover channel should start selected")

	var hud := _stamp_hud(game_root)
	game_root._on_social_channel_pressed("following")
	await process_frame

	discover = Harness.find_node_by_name(game_root, "SocialChannelTabUnderlinediscover") as ColorRect
	var following := Harness.find_node_by_name(game_root, "SocialChannelTabUnderlinefollowing") as ColorRect
	_assert_true(following != null and following.visible, "phone shell should select the following channel")
	_assert_true(discover != null and not discover.visible, "phone shell should deselect discover after a channel change")
	_assert_hud_untouched(hud, "changing the social channel")

	game_root.queue_free()
	await process_frame


func _test_spend_action_refreshes_phone_shell_not_hud() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return
	game_root._on_app_pressed("social")
	game_root.game.free_sentence_units = ["门"]
	game_root._set_social_screen("publish")
	await process_frame

	var post_button := Harness.find_node_by_name(game_root, "SocialPublishPostButton") as Button
	_assert_true(post_button != null, "publish page should expose a post button")
	if post_button != null:
		_assert_eq(post_button.text, "投稿", "publish should start spendable")

	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(prompt != null, "Reality HUD should expose the world prompt")
	if prompt != null:
		prompt.text = HUD_SENTINEL
	var actions_label := game_root._hud_actions_label_ref() as Label
	while game_root.game.can_spend_action():
		_assert_true(game_root.game.spend_action("phone-shell-refresh"), "daily actions should be spendable")
	await process_frame

	post_button = Harness.find_node_by_name(game_root, "SocialPublishPostButton") as Button
	_assert_true(post_button != null, "spending actions should keep the phone-shell publish button")
	if post_button != null:
		_assert_eq(post_button.text, "今天不能再投稿", "phone shell should show spent-action copy")
		_assert_true(post_button.disabled, "phone shell should disable posting after actions are spent")
	_assert_true(prompt != null and is_instance_valid(prompt), "spending actions should leave the world prompt in place")
	if prompt != null and is_instance_valid(prompt):
		_assert_eq(prompt.text, HUD_SENTINEL, "spending actions should not re-run Reality HUD content")
	_assert_true(actions_label != null and is_instance_valid(actions_label), "the status column should keep its actions label")
	if actions_label != null and is_instance_valid(actions_label):
		_assert_eq(actions_label.text, "今日行动\n○ ○ ○ ○ ○", "the status column should update its own action dots")

	game_root.queue_free()
	await process_frame


func _test_opening_app_refreshes_phone_shell_not_hud() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return
	game_root._on_app_pressed("social")
	await process_frame

	var hud := _stamp_hud(game_root)
	game_root._on_app_pressed("babel")
	await process_frame

	var babel := Harness.find_node_by_name(game_root, "BabelAppWindow") as Control
	var heading := Harness.find_node_by_name(game_root, "BabelFloorHeading") as Label
	_assert_true(babel != null and babel.visible, "opening babel should show its phone-shell window")
	_assert_true(heading != null, "phone shell should paint babel content")
	_assert_hud_untouched(hud, "opening a phone app")

	game_root.queue_free()
	await process_frame


func _test_phone_popup_follows_the_phone_model() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	var open: PropertyModel = manager.model(PropertyKeysScript.PHONE_OPEN)
	var popup := Harness.find_node_by_name(game_root, "PhonePopup") as Control
	_assert_true(popup != null and popup.visible, "a new run should show the phone popup")
	_assert_eq(open.changed.get_connections().size(), 1, "the shown phone should listen to the phone model once")

	open.write(false)
	_assert_true(popup != null and not popup.visible, "writing the phone model closed should hide the popup without a refresh")
	open.write(true)
	_assert_true(popup != null and popup.visible, "writing the phone model open should show the popup without a refresh")

	game_root.set_view_state("npc_up")
	await process_frame
	_assert_true(popup != null and not popup.visible, "putting the phone down should hide the popup")
	_assert_eq(open.changed.get_connections().size(), 1, "putting the phone down should keep one registration while the play chrome is shown")
	game_root.set_view_state("phone_down")
	await process_frame
	_assert_true(popup != null and popup.visible, "picking the phone up should show the popup")

	game_root.queue_free()
	await process_frame


func _test_like_does_not_rerun_ending() -> void:
	var game_root := await _boot_gameplay()
	if game_root == null:
		return
	game_root.game.ending_unlocked = true
	game_root._render()
	await process_frame

	var body := Harness.find_node_by_name(game_root, "EndingBody") as Label
	_assert_true(body != null, "unlocking the ending should paint the ending screen")
	if body != null:
		body.text = ENDING_SENTINEL
	var post: Dictionary = SocialFeedContentScript.post_for_index(0, game_root._social_content_deps())
	game_root._on_social_like_pressed(str(post.get("id", "")))
	await process_frame

	body = Harness.find_node_by_name(game_root, "EndingBody") as Label
	_assert_true(body != null and is_instance_valid(body), "liking a post should leave the ending screen in place")
	if body != null and is_instance_valid(body):
		_assert_eq(body.text, ENDING_SENTINEL, "liking a post should not re-run the ending screen")

	game_root.queue_free()
	await process_frame


func _boot_gameplay() -> Node:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "phone shell refresh should load the main scene")
	if scene == null:
		return null
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	game_root._skip_prologue()
	await process_frame
	return game_root


func _stamp_hud(game_root: Node) -> Label:
	var hud := game_root._hud_actions_label_ref() as Label
	_assert_true(hud != null, "Reality HUD should expose an actions label")
	if hud != null:
		hud.text = HUD_SENTINEL
	return hud


func _assert_hud_untouched(hud: Label, action: String) -> void:
	_assert_true(hud != null and is_instance_valid(hud), "%s should leave the Reality HUD node in place" % action)
	if hud != null and is_instance_valid(hud):
		_assert_eq(hud.text, HUD_SENTINEL, "%s should not re-run Reality HUD content" % action)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(value: Variant, expected: Variant, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(value), str(expected)])
