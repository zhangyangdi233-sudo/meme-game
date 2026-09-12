extends SceneTree

const OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_doll_reward.png"
const VIEW_SIZE := Vector2i(1672, 941)
const HEADLESS_CAPTURE_ERROR := "Screenshot capture requires a rendered display. Run this tool without --headless from a GUI session."


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if not _ensure_capture_supported():
		return
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	main._locale.set_locale("zh")
	main.new_game()
	main._skip_prologue()
	main.set_view_state("npc_up")
	var doll := _find_actor(main, "doll")
	if doll == null:
		push_error("Unable to find physical doll encounter")
		quit(1)
		return
	main._reality_scene_adapter.player.position = _approach_position(main, doll, 1.45)
	main._refresh_nearby_reality_actor()
	if not main._try_reality_interaction():
		push_error("Unable to start doll dialogue")
		quit(1)
		return
	var choices: Array = main.game.get_typed_reality_choices()
	if choices.is_empty():
		push_error("Doll dialogue exposed no frame choices")
		quit(1)
		return
	main._on_reality_choice_selected(str(choices[0].get("id", "")))
	for _step in 320:
		if main.game.conversation_phase != "typing":
			break
		main._advance_typed_reality_character()
	if main._input_locked:
		main._narrative_director.finish_action_spend_animation()
	main.set_view_state("phone_down")
	main._on_app_pressed("notebook")
	for _frame in 30:
		await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Unable to read root viewport texture")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null or image.save_png(OUTPUT_PATH) != OK:
		push_error("Unable to save doll reward screenshot")
		quit(1)
		return
	print("saved screenshot: %s" % OUTPUT_PATH)
	main.queue_free()
	await process_frame
	quit(0)


func _find_actor(main: Node, actor_type: String) -> Area3D:
	for actor in main._reality_scene_adapter.floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == actor_type:
			return actor
	return null


func _approach_position(main: Node, actor: Area3D, distance: float) -> Vector3:
	var open_side := Vector3(-actor.position.x, 0.0, 0.0)
	if open_side.length_squared() < 0.01:
		open_side = Vector3.RIGHT
	return actor.position + open_side.normalized() * distance


func _ensure_capture_supported() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
