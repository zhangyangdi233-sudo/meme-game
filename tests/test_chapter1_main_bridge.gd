extends SceneTree

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	root.add_child(main)
	main._save_path = "user://test_chapter1_bridge.dat"
	if not main.has_method("start_chapter1_game"):
		failures.append("main scene must expose the chapter route used by the New Game button")
	else:
		main.start_chapter1_game()
		await process_frame
		_check(main.game.chapter1_progress.phase == "opening", "new chapter starts at locked opening")
		_check(not main.game.chapter1_progress.narrator_completed, "starting scene does not complete narration")
		_check(not main.game.chapter1_progress.opening_knock_completed, "starting scene waits for the opening knock")
		_check(not main._prologue_overlay.visible, "old story overlay is absent from new opening")
		_check(main.game.view_state == "npc_up", "new opening is first person")
		_check(main._chapter_dev_panel == null or not main._chapter_dev_panel.visible, "ordinary launch has no implicit developer controls")
		main._skip_prologue()
		_check(not main.game.chapter1_progress.opening_knock_completed, "legacy skip helper cannot release new gate")
		var denied: Dictionary = main.notify_chapter1("opening_door_opened")
		_check(not denied.accepted, "main event bridge cannot skip the knock")
		var ready: Dictionary = main.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
		_check(ready.accepted and main.game.chapter1_progress.phase == "opening", "completed knock waits for F without teleporting")
		_check(main._chapter_world_ready, "production opening GLB and contract bind successfully")
		if main._chapter_world_ready:
			var opening_route: String = main._chapter_route_key()
			main._save_progress()
			# An event already queued by the old host must not affect a continued
			# session, even when both saves use the same deterministic round token.
			main._reality_floor.event_requested.emit("opening_door_opened", {})
			_check(main.continue_game(), "new chapter uses existing save file envelope")
			await process_frame
			_check(main._chapter_route_key() == opening_route and main.game.chapter1_progress.opening_knock_completed, "continue restores completed knock without accepting the old host callback")
			_check(not main._reality_floor.get_door("opening").is_passable(), "continue after a knock still waits for F")
			_check(not main._reality_floor.get_node("OpeningDoorKnock").playing, "continue after a completed knock does not replay it")
			var canvas_before: int = main._canvas.get_instance_id()
			main.notify_chapter1("opening_door_opened")
			_check(main.game.chapter1_progress.phase == "basement", "current host may enter basement")
			_check(main._canvas.get_instance_id() == canvas_before, "stage transition preserves shared UI")
			_check(not main._hud_panel.visible and not main._hud_reveal_zone.visible, "chapter world hides legacy HUD and yellow edge")
			_check(not main._view_toggle_button.visible and not main._cinematic_top_bar.visible and not main._cinematic_bottom_bar.visible, "chapter world hides phone button and letterbox")
			var settings_key := InputEventKey.new()
			settings_key.keycode = KEY_ESCAPE
			settings_key.pressed = true
			main._unhandled_input(settings_key)
			_check(main._settings_window.visible and main._hud_panel.visible, "settings and save remain accessible with Esc")
			main._close_settings_window()
			main._render_status()
			_check(not main._playtest_assist_panel.visible, "partial status render cannot expose legacy test hints")
			for visit in range(5):
				var token: int = main.game.chapter1_progress.transition_serial
				main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
				main.notify_chapter1("npc_help_completed", {"round_token": token, "task_id": "basement_help_%02d" % (visit + 1), "npc_id": "basement_npc_%02d" % (visit + 1)})
				main.notify_chapter1("basement_tunnel_entered", {"round_token": token})
				main.notify_chapter1("basement_exit_requested", {"round_token": token})
			var chapter_day: int = main.game.day
			_check(main.game.actions_remaining == 5, "five tutorial visits preserve the normal daily budget")
			main.notify_chapter1("crossroads_gate_requested")
			_check(main.game.tower_floor == 2 and main.game.day == chapter_day and main.game.actions_remaining == 5, "tower handoff preserves the same day and five normal actions")
			_check(not main.game.needs_day_settlement, "tutorial practice creates no unpaid day settlement")
			_check(main._hud_panel.visible and main._hud_reveal_zone.visible, "legacy UI returns at tower handoff")
			main._chapter_dev_enabled = true
			main.start_chapter1_game()
			_check(main._chapter_dev_panel.visible, "explicit development launch displays labelled controls")
			var panel_key := InputEventKey.new()
			panel_key.keycode = KEY_F9
			panel_key.pressed = true
			main._unhandled_input(panel_key)
			_check(not main._chapter_dev_panel.visible, "F9 hides development controls")
			main._unhandled_input(panel_key)
			_check(main._chapter_dev_panel.visible and not main.game.chapter1_progress.opening_knock_completed, "F9 restores panel without completing the knock")
			_check(not main._reality_mouse_look_enabled, "F9 showing developer controls makes their buttons accessible with the mouse")
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter1 main bridge tests passed")
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
