extends SceneTree

const OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_npc_character_view.png"
const MOTION_OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_npc_character_view_phase_b.png"
const VIEW_SIZE := Vector2i(1672, 941)
const HEADLESS_CAPTURE_ERROR := "NPC character capture requires a rendered display. Run this tool without --headless."


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
	main._skip_chapter_one()
	main.set_view_state("npc_up")
	main._phone_art_alpha = 0.0
	if main._phone_down_backdrop_image != null:
		main._phone_down_backdrop_image.visible = false
	main.game.pollution = 34
	main.game.pollution_flashback_seen = true
	var player := main.get_node_or_null("RealityPlayer") as CharacterBody3D
	var npc := main.get_node_or_null("RealityFloor/Actors/NPC1") as Area3D
	if npc == null:
		npc = main.get_node_or_null("RealityFloor/Actors/NPC0") as Area3D
	if player == null or npc == null:
		push_error("Unable to locate an ordinary reality NPC")
		quit(1)
		return
	player.position = npc.position + Vector3(0.0, 0.0, 1.75)
	main._refresh_nearby_reality_actor()
	main._try_reality_interaction()
	for frame in 18:
		await process_frame
	var viewport_texture := root.get_texture()
	if viewport_texture == null:
		push_error("Unable to read root viewport texture")
		quit(1)
		return
	var image := viewport_texture.get_image()
	if image == null:
		push_error("Unable to read root viewport image")
		quit(1)
		return
	var error := image.save_png(OUTPUT_PATH)
	if error != OK:
		push_error("Unable to save screenshot: %s" % error)
		quit(1)
		return
	print("saved screenshot: %s" % OUTPUT_PATH)
	for frame in 8:
		await process_frame
	var motion_image := root.get_texture().get_image()
	var motion_error := motion_image.save_png(MOTION_OUTPUT_PATH)
	if motion_error != OK:
		push_error("Unable to save motion screenshot: %s" % motion_error)
		quit(1)
		return
	print("saved motion screenshot: %s" % MOTION_OUTPUT_PATH)
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _ensure_capture_supported() -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
