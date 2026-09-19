extends SceneTree

const Harness = preload("res://tests/harness/minimal_game_harness.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "doll UI flow should load the main scene")
	if scene != null:
		var game_root = scene.instantiate()
		root.add_child(game_root)
		game_root._locale.set_locale("zh")
		game_root.new_game()
		game_root._skip_prologue()
		await process_frame

		_assert_true(Harness.find_node_by_name(game_root, "PhoneAppIconShop") == null, "phone launcher must not retain the removed shop")
		_assert_true(Harness.find_node_by_name(game_root, "ShopAppWindow") == null, "shop window must not exist")
		_assert_true(not game_root.has_method("_on_buy_meme_frame_pressed"), "purchase callback must stay removed")

		game_root.set_view_state("npc_up")
		await process_frame
		var doll := _find_actor_by_type(game_root, "doll")
		_assert_true(doll != null, "the current floor should contain the user's stitched guide doll")
		if doll != null:
			var billboard := doll.get_node_or_null("Billboard") as Sprite3D
			_assert_true(billboard != null and billboard.texture != null, "the doll should render with the user-authored artwork")
			_assert_true(bool(doll.get_meta("guide_character", false)), "the world actor should be marked as the guide character")
			game_root._reality_scene_adapter.player.position = doll.position + Vector3(0.0, 0.0, 1.4)
			game_root._refresh_nearby_reality_actor()
			_assert_true(game_root._reality_scene_adapter.nearby_actor == doll, "approaching the doll should select it for interaction")
			_assert_true(game_root._try_reality_interaction(), "the physical doll should open its authored conversation")
			_assert_eq(game_root.game.conversation_actor_type, "doll", "doll interaction should enter the doll conversation branch")
			var choices: Array = game_root.game.get_typed_reality_choices()
			_assert_eq(choices.size(), 3, "the guide should offer three authored tutorial responses")
			if not choices.is_empty():
				var actions_before: int = game_root.game.actions_remaining
				game_root._on_reality_choice_selected(str(choices[0].get("id", "")))
				for _step in 256:
					if game_root.game.conversation_phase != "typing":
						break
					game_root._advance_typed_reality_character()
				_assert_true(bool(game_root.game.conversation_reward.get("guided", false)), "finishing the doll reply should advance the tutorial")
				_assert_eq(game_root.game.owned_meme_frames, 0, "the guide should no longer grant an obsolete meme frame")
				_assert_eq(game_root.game.actions_remaining, actions_before, "speaking to the tutorial guide should not consume a daily action")
				_assert_eq(str(game_root.game.get_tutorial_step().get("id", "")), "open_social", "guide discovery should advance the tutorial to the phone")
				_assert_true(bool(doll.get_meta("claimed", false)), "the world doll should remember that its first guidance was heard")
				if game_root.session_mode() == "narrative":
					game_root._narrative_director.finish_action_spend_animation()

		game_root.queue_free()
		await process_frame

	if _failures.is_empty():
		print("doll UI flow tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _token(token_id: String, text: String, role: String, phone_surface: String, doctor_surface: String) -> Dictionary:
	return Harness.craft_token(token_id, text, role, phone_surface, doctor_surface)


func _find_actor_by_type(game_root: Node, actor_type: String) -> Area3D:
	if game_root._reality_scene_adapter.floor == null:
		return null
	for actor in game_root._reality_scene_adapter.floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == actor_type:
			return actor
	return null


func _find_node_by_name(node: Node, target_name: String) -> Node:
	return Harness.find_node_by_name(node, target_name)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
