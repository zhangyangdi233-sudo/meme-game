extends SceneTree

const OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_day_transition.png"
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
	main.new_game()
	main._skip_prologue()
	main.game.actions_remaining = 0
	main.game.needs_day_settlement = true
	main.game.day_ended_reason = "capture-transition"
	main._narrative_director.play_day_transition()
	if main._narrative_director.day_transition_tween != null and main._narrative_director.day_transition_tween.is_valid():
		main._narrative_director.day_transition_tween.kill()
	main._narrative_director.day_transition_tween = null
	main._narrative_director.day_transition_overlay.modulate = Color.WHITE
	main._narrative_director.day_transition_rule.scale = Vector2.ONE
	main._narrative_director.day_transition_day_label.scale = Vector2.ONE
	main._narrative_director.commit_day_transition_settlement()
	for frame in 8:
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
	quit(0)


func _ensure_capture_supported() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
