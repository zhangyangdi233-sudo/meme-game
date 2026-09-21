extends SceneTree
## Reality HUD snapshot refresh: approach / conversation / world hints paint Reality HUD, not the social feed.

const Harness = preload("res://tests/harness/minimal_game_harness.gd")
const SocialFeedContentScript = preload("res://scripts/game/social_feed_content.gd")

const FEED_SENTINEL := "FEED_SENTINEL_REALITY_HUD"
const WORLD_PROMPT_SENTINEL := "WORLD_PROMPT_SENTINEL_REALITY_HUD"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	await _test_approach_refreshes_world_prompt_not_feed()
	await _test_conversation_refreshes_reality_hud_not_feed()
	await _test_like_does_not_rerun_reality_hud()
	await _test_hud_snapshot_uses_outcome_not_live_world()
	if _failures.is_empty():
		print("reality HUD refresh UI tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_approach_refreshes_world_prompt_not_feed() -> void:
	var game_root := await _boot_street()
	if game_root == null:
		return
	var like_button := _stamp_feed(game_root)
	var approached := _approach_guide_doll(game_root)
	_assert_true(approached, "the street should expose a nearby doll outcome")
	await process_frame

	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	var nearby: Dictionary = game_root._reality_hud_snapshot().get("nearby", {})
	_assert_eq(str(nearby.get("kind", "")), "actor", "approach should publish a nearby actor outcome")
	_assert_true(prompt != null and prompt.visible, "approach should show the world prompt")
	if prompt != null:
		_assert_true(prompt.text.contains("交谈"), "world prompt should offer conversation")
		_assert_true(
			prompt.text.contains(str(nearby.get("actor_label", ""))),
			"world prompt should use the nearby outcome label"
		)
	_assert_feed_untouched(like_button, "approaching an actor")

	game_root.queue_free()
	await process_frame


func _test_conversation_refreshes_reality_hud_not_feed() -> void:
	var game_root := await _boot_street()
	if game_root == null:
		return
	var like_button := _stamp_feed(game_root)
	_assert_true(_approach_guide_doll(game_root), "conversation test should start from a nearby doll")
	_assert_true(game_root._try_reality_interaction(), "F interaction should open the nearby actor")
	await process_frame

	var continue_button := Harness.find_node_by_name(game_root, "RealityConversationContinue") as Button
	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(continue_button != null and continue_button.visible, "conversation should paint Reality HUD chrome")
	if continue_button != null:
		_assert_eq(continue_button.text, "离开", "doll conversation should expose Leave")
	if prompt != null:
		_assert_true(not prompt.visible, "conversation should hide the world prompt")
	_assert_feed_untouched(like_button, "starting a conversation")

	game_root.queue_free()
	await process_frame


func _test_like_does_not_rerun_reality_hud() -> void:
	var game_root := await _boot_street()
	if game_root == null:
		return
	_assert_true(_approach_guide_doll(game_root), "like isolation should start from a nearby doll")
	await process_frame

	var prompt := Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(prompt != null, "Reality HUD should expose a world prompt")
	if prompt != null:
		prompt.text = WORLD_PROMPT_SENTINEL

	var post: Dictionary = SocialFeedContentScript.post_for_index(0, game_root._social_content_deps())
	game_root._on_social_like_pressed(str(post.get("id", "")))
	await process_frame

	prompt = Harness.find_node_by_name(game_root, "WorldPrompt") as Label
	_assert_true(prompt != null and is_instance_valid(prompt), "liking a post should leave the world prompt in place")
	if prompt != null and is_instance_valid(prompt):
		_assert_eq(prompt.text, WORLD_PROMPT_SENTINEL, "liking a post should not re-run Reality HUD content")

	game_root.queue_free()
	await process_frame


func _test_hud_snapshot_uses_outcome_not_live_world() -> void:
	var game_root := await _boot_street()
	if game_root == null:
		return
	_assert_true(_approach_guide_doll(game_root), "HUD snapshot should be readable after approach")
	var snapshot: Dictionary = game_root._reality_hud_snapshot()
	var nearby: Dictionary = snapshot.get("nearby", {})
	var look_pose: Dictionary = snapshot.get("pose", {})
	_assert_eq(str(nearby.get("kind", "")), "actor", "HUD snapshot should carry the nearby outcome")
	_assert_true(nearby.get("actor") == null, "HUD snapshot must not leak the live actor node")
	_assert_true(nearby.get("item") == null, "HUD snapshot must not leak a live item node")
	_assert_true(not str(nearby.get("actor_id", "")).is_empty(), "HUD snapshot should identify the nearby actor by id")
	_assert_true(look_pose.get("player_position") is Vector3, "HUD snapshot should include look pose")
	_assert_true(snapshot.get("conversation") is Dictionary, "HUD snapshot should include the conversation snapshot")

	game_root.queue_free()
	await process_frame


func _boot_street() -> Node:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "reality HUD refresh should load the main scene")
	if scene == null:
		return null
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	game_root._skip_prologue()
	game_root._on_app_pressed("social")
	game_root.set_view_state("npc_up")
	await process_frame
	return game_root


func _approach_guide_doll(game_root: Node) -> bool:
	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	var floor_root := game_root.get_node_or_null("RealityFloor") as Node3D
	var doll := _find_actor(floor_root, "doll")
	if player == null or doll == null:
		_failures.append("street setup should expose the player and a guide doll")
		return false
	player.position = doll.position + Vector3(0.0, 0.0, 1.4)
	game_root._refresh_nearby_reality_actor()
	return str(game_root._reality_hud_snapshot().get("nearby", {}).get("kind", "")) == "actor"


func _stamp_feed(game_root: Node) -> Button:
	var like_button := Harness.find_node_by_name(game_root, "SocialPostLikeButton0") as Button
	_assert_true(like_button != null, "social home should expose a like button")
	if like_button != null:
		like_button.text = FEED_SENTINEL
	return like_button


func _assert_feed_untouched(like_button: Variant, action: String) -> void:
	_assert_true(
		like_button is Button and is_instance_valid(like_button),
		"%s should leave the social feed node in place" % action
	)
	if like_button is Button and is_instance_valid(like_button):
		_assert_eq((like_button as Button).text, FEED_SENTINEL, "%s should not re-run social feed content" % action)


func _find_actor(node: Node, actor_type: String) -> Area3D:
	if node == null:
		return null
	if node is Area3D and str(node.get_meta("actor_type", "")) == actor_type:
		return node as Area3D
	for child in node.get_children():
		var found := _find_actor(child, actor_type)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(value: Variant, expected: Variant, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, str(value), str(expected)])
