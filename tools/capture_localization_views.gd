extends SceneTree

const LANGUAGE_OUTPUT := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_language_selection.png"
const ENGLISH_SOCIAL_OUTPUT := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_social_english.png"
const JAPANESE_SOCIAL_OUTPUT := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_social_japanese.png"
const JAPANESE_DETAIL_OUTPUT := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_social_japanese_detail.png"
const OLDWEB_ARCHIVE_OUTPUT := "/Users/zhang/Documents/游戏/babel-meme-game/tools/current_oldweb_archive.png"
const VIEW_SIZE := Vector2i(1672, 941)
const HEADLESS_CAPTURE_ERROR := "Screenshot capture requires a rendered display. Run this tool without --headless from a GUI session."


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if DisplayServer.get_name().to_lower() == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	for frame in 8:
		await process_frame
	if not _save_view(LANGUAGE_OUTPUT):
		return

	main._on_language_selected("en")
	main.new_game()
	main._skip_prologue()
	main.game.set_active_app("social")
	main._set_social_screen("home")
	for frame in 12:
		await process_frame
	if not _save_view(ENGLISH_SOCIAL_OUTPUT):
		return

	main._on_language_selected("ja")
	for frame in 8:
		await process_frame
	if not _save_view(JAPANESE_SOCIAL_OUTPUT):
		return

	main._open_social_post(0)
	for frame in 8:
		await process_frame
	if not _save_view(JAPANESE_DETAIL_OUTPUT):
		return

	main._close_social_detail_window()
	main._set_social_screen("archive")
	main._on_oldweb_page_pressed("source")
	for frame in 8:
		await process_frame
	if not _save_view(OLDWEB_ARCHIVE_OUTPUT):
		return
	print("saved localization screenshots")
	quit(0)


func _save_view(path: String) -> bool:
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Unable to read root viewport image")
		quit(1)
		return false
	var error := image.save_png(path)
	if error != OK:
		push_error("Unable to save screenshot: %s" % error)
		quit(1)
		return false
	return true
