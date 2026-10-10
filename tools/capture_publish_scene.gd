extends SceneTree

const OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_publish_view.png"
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
	if main.has_method("new_game"):
		main.new_game()
		main._skip_prologue()
	main.game.completed_memes = [{
		"id": "capture-contract",
		"title": "复合「哈塔」",
		"text": "哈塔",
		"tags": ["哈吉米", "巴别塔"],
		"rarity": 2,
		"pollution_bias": 10,
		"fusion_level": 1,
		"fused_from": ["capture-ha", "capture-tower"],
	}]
	main.game.place_meme_in_blank("blank_1", "capture-contract")
	if main._social_feed_panel != null:
		main._social_feed_panel.show_screen("publish")
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
