extends SceneTree

const OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_doll_discovery.png"
const VIEW_SIZE := Vector2i(1672, 941)
const HEADLESS_CAPTURE_ERROR := "Screenshot capture requires a rendered display. Run this tool without --headless from a GUI session."


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if not _ensure_capture_supported():
		return
	var main := _new_game_scene()
	if main == null:
		quit(1)
		return
	var doll := _find_actor(main, "doll")
	if doll == null:
		push_error("Unable to find physical doll encounter")
		quit(1)
		return
	_frame_actor(main, doll, 2.8)
	for _frame in 36:
		await process_frame
	if not _save_viewport():
		return
	print("saved screenshot: %s" % OUTPUT_PATH)
	main.queue_free()
	await process_frame
	quit(0)


func _new_game_scene() -> Node:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene")
		return null
	var main := scene.instantiate()
	root.add_child(main)
	main._locale.set_locale("zh")
	main.new_game()
	main._skip_prologue()
	main.set_view_state("npc_up")
	main._phone_art_alpha = 0.0
	if main._phone_down_backdrop_image != null:
		main._phone_down_backdrop_image.visible = false
	return main


func _find_actor(main: Node, actor_type: String) -> Area3D:
	for actor in main._reality_scene_adapter.floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == actor_type:
			return actor
	return null


func _frame_actor(main: Node, actor: Area3D, distance: float) -> void:
	var open_side := Vector3(-actor.position.x, 0.0, 0.0)
	if open_side.length_squared() < 0.01:
		open_side = Vector3.RIGHT
	main._reality_scene_adapter.player.position = actor.position + open_side.normalized() * distance
	var direction: Vector3 = actor.position - main._reality_scene_adapter.player.position
	main._reality_scene_adapter.yaw = rad_to_deg(atan2(-direction.x, -direction.z))
	main._reality_scene_adapter.pitch = -20.0
	main._refresh_nearby_reality_actor()


func _save_viewport() -> bool:
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Unable to read root viewport texture")
		quit(1)
		return false
	var image := viewport_texture.get_image()
	if image == null or image.save_png(OUTPUT_PATH) != OK:
		push_error("Unable to save doll discovery screenshot")
		quit(1)
		return false
	return true


func _ensure_capture_supported() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
