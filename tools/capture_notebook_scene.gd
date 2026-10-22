extends SceneTree

const OUTPUT_PATH := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_notebook_view.png"
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
		main._skip_chapter_one()
	main.game.owned_meme_frames = 1
	main.game.notebook_tokens = [{
		"id": "capture-glyph",
		"text": "塔",
		"source_post_id": "capture-post",
		"tags": ["巴别塔"],
		"rarity": 2,
		"picked_day": 1,
	}]
	main.game.draft_slots = {"glyph": "capture-glyph"}
	main.game.completed_memes = [{
		"id": "capture-ha",
		"title": "梗字「哈」",
		"text": "哈",
		"tags": ["哈吉米"],
		"rarity": 1,
		"pollution_bias": 1,
		"fusion_level": 0,
	}, {
		"id": "capture-tower",
		"title": "梗字「塔」",
		"text": "塔",
		"tags": ["巴别塔"],
		"rarity": 2,
		"pollution_bias": 2,
		"fusion_level": 0,
	}]
	if main.has_method("_on_app_pressed"):
		main._on_app_pressed("notebook")
	for frame in 5:
		await process_frame
	var notebook_scroll := main.find_child("NotebookCraftScroll", true, false) as ScrollContainer
	if notebook_scroll != null:
		notebook_scroll.scroll_vertical = 10000
	for frame in 12:
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
	main.queue_free()
	await process_frame
	quit(0)


func _ensure_capture_supported() -> bool:
	var display_name := DisplayServer.get_name().to_lower()
	if display_name == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
