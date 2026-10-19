extends SceneTree
## A fresh second-floor teaching session. The launcher supplies an isolated profile.

func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.title = "Aphasia · 第二章测试 · X-ray 迷宫"
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://chapter_two_preview.dat"
	main._locale.preferences_path = "user://chapter_two_preview.cfg"
	root.add_child(main)
	current_scene = main
	# Reuse this test profile's language and camera choice; never change real saves.
	main._resolve_camera_consent(main._camera_enabled)
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	state.set_view_state("npc_up")
	main._begin_game_session(state, {}, false)
	for frame in 4:
		await process_frame
	main._set_reality_mouse_look(true)
	print("CHAPTER_TWO_READY floor=%d map_locked=%s locale=%s" % [main.game.tower_floor, not main.game.is_phone_app_unlocked("map"), main._locale.current_locale])
