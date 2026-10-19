extends SceneTree
## Interactive preview entry only. The normal main scene and save are unchanged.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.title = "Aphasia · 第二层预览"
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://floor_two_preview.dat"
	main._locale.preferences_path = "user://floor_two_preview.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	current_scene = main
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	state.set_view_state("npc_up")
	# Begin with the genuine title -> phone -> gray-to-lit map introduction.
	main._begin_game_session(state, {}, false)
	for frame in 4:
		await process_frame
	main._save_progress()
	print("FLOOR_TWO_PREVIEW_READY floor=%d map_unlocked=%s position=%s" % [main.game.tower_floor, main.game.is_phone_app_unlocked("map"), main._reality_player.position])
