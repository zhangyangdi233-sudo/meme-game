extends SceneTree
## In the main scene, the host routes the reality conversation intents itself. The reality HUD builds no doctor
## sentence composer, and leaving a spoken conversation runs the progress check: at the threshold the floor moves.

const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "the main scene should load")
	if scene != null:
		var game_root := scene.instantiate()
		root.add_child(game_root)
		game_root._locale.set_locale("zh")
		game_root.new_game()
		game_root._skip_chapter_one()
		# The street's cast starts on the second floor; the first is the empty crossroads.
		game_root.game.tower_floor = 2
		game_root._refresh_play_surfaces()
		await process_frame
		_test_the_host_no_longer_keeps_the_transient_selections(game_root)
		_test_the_reality_hud_builds_no_doctor_composer(game_root)
		await _test_conversation_intents_choose_and_leave(game_root)
		game_root.queue_free()
		await process_frame

	if _failures.is_empty():
		print("reality intents scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _feedback() -> String:
	var manager := RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	return str(manager.model(PropertyKeysScript.FEEDBACK_TEXT).read())


func _test_the_host_no_longer_keeps_the_transient_selections(game_root: Node) -> void:
	var fields: Array[String] = []
	for property in game_root.get_property_list():
		fields.append(str(property.get("name", "")))
	_assert_true(not fields.has("_reality_hover_choice_id"), "the host should not keep the hovered choice")
	_assert_true(not fields.has("_selected_language_token_id"), "the host should not keep the selected token")
	_assert_true(not fields.has("log_text"), "the host should not keep the feedback text")
	_assert_true(not fields.has("selected_meme_id"), "the host should not keep the selected meme")


func _test_the_reality_hud_builds_no_doctor_composer(game_root: Node) -> void:
	_assert_true(game_root.find_child("RealityLanguageComposerPanel", true, false) == null, "the host should not build the doctor sentence composer")
	_assert_true(game_root.find_child("RealityLanguageComposer", true, false) == null, "the reality HUD should hold no composer overlay")
	var fields: Array[String] = []
	for property in game_root.get_property_list():
		fields.append(str(property.get("name", "")))
	_assert_true(not fields.has("_reality_language_composer_panel"), "the host should keep no composer panel")
	_assert_true(not fields.has("_doctor_sentence_intent_handler"), "the host should keep no doctor sentence handler")


func _test_conversation_intents_choose_and_leave(game_root: Node) -> void:
	game_root.set_view_state("npc_up")
	await process_frame
	var doll: Area3D = null
	for actor in game_root._reality_scene_adapter.floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == "doll":
			doll = actor
	_assert_true(doll != null, "the floor should hold the guide doll")
	if doll == null:
		return
	game_root._reality_scene_adapter.player.position = doll.position + Vector3(0.0, 0.0, 1.4)
	game_root._refresh_nearby_reality_actor()
	_assert_true(game_root._try_reality_interaction(), "the doll should open its conversation")
	_assert_eq(game_root.game.conversation_phase, "choosing", "the conversation should offer choices")
	var choices: Array = game_root.game.get_typed_reality_choices()
	GameEventBus.raise(UiIntentsScript.CONVERSATION_CHOICE_PRESSED, {UiIntentsScript.KEY_CHOICE_ID: str(choices[0].get("id", ""))})
	_assert_eq(game_root.game.conversation_phase, "typing", "a choice intent should start the typed reply")
	GameEventBus.raise(UiIntentsScript.CONVERSATION_CONTINUE_PRESSED)
	_assert_eq(game_root.game.conversation_phase, "idle", "a continue intent outside a result should leave the conversation")
	_assert_eq(game_root.game.tower_floor, 2, "leaving before the reply was spoken should not move the floor")

	game_root.game.pollution = 60
	game_root._refresh_nearby_reality_actor()
	_assert_true(game_root._try_reality_interaction(), "the doll should open its conversation again")
	choices = game_root.game.get_typed_reality_choices()
	GameEventBus.raise(UiIntentsScript.CONVERSATION_CHOICE_PRESSED, {UiIntentsScript.KEY_CHOICE_ID: str(choices[0].get("id", ""))})
	var budget := 400
	while game_root.game.conversation_phase == "typing" and budget > 0:
		budget -= 1
		game_root._advance_typed_reality_character()
	_assert_eq(game_root.game.conversation_phase, "result", "the reply should be spoken out")
	while game_root.game.conversation_phase == "result":
		GameEventBus.raise(UiIntentsScript.CONVERSATION_CONTINUE_PRESSED)
		if game_root.game.conversation_phase == "choosing":
			choices = game_root.game.get_typed_reality_choices()
			GameEventBus.raise(UiIntentsScript.CONVERSATION_CHOICE_PRESSED, {UiIntentsScript.KEY_CHOICE_ID: str(choices[0].get("id", ""))})
			budget = 400
			while game_root.game.conversation_phase == "typing" and budget > 0:
				budget -= 1
				game_root._advance_typed_reality_character()
	await process_frame
	_assert_eq(game_root.game.conversation_phase, "idle", "the spoken conversation should end")
	_assert_eq(game_root.game.tower_floor, 3, "ending a spoken conversation at 60% pollution should move the floor")
	_assert_eq(game_root._reality_scene_adapter._built_floor, 3, "the host should rebuild the street for the new floor")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
