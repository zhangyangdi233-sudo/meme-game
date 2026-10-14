extends SceneTree

var failures: Array[String] = []

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "res://artifacts/test_ui_revision_regressions.dat"
	main._locale.preferences_path = "res://artifacts/test_ui_revision_regressions.cfg"
	root.add_child(main)
	main.new_game()
	main._skip_prologue()
	main._locale.set_locale("zh")
	main._render()
	await process_frame
	_check(not main._pickup_bbcode("门在这里").contains("[font_size="), "pickable and ordinary text must share the same inherited font size")
	_check(not main._hud_panel.visible and not main._hud_reveal_zone.visible, "retired resource HUD must not reappear in phone view")
	main._playtest_assist_enabled = true
	main._render_playtest_assist()
	_check(not main._playtest_assist_label.text.contains("污染") and not main._playtest_assist_label.text.contains("隐藏层"), "debug assist cannot expose hidden pollution or the hidden-floor route")
	_check(not main._app_windows.has("babel"), "retired tower app must not create a window")
	_check(main._settings_window.find_child("SettingsAutoplayButton", true, false) == null, "settings must not show autoplay")
	_check(main._settings_window.find_child("SettingsHistoryButton", true, false) == null, "settings must not show history")
	main._social_screen = "publish"
	main.game.set_active_app("social")
	main._render()
	_check(main._ui_root.find_child("SocialPublishOutcomePanel", true, false) == null, "posting must not display retired funds or pollution")
	for locale in ["en", "ja", "zh", "en"]:
		main._locale.set_locale(locale)
		main._render()
		for pair in [["SettingsVHSToggle", "全局画面 VHS"], ["SettingsCRTVHSToggle", "开启 CRT 屏幕 VHS 质感"], ["SettingsExitGameButton", "退出游戏"], ["SettingsManualSaveButton", "保存"], ["ExitConfirmationMessage", "真的要抛弃我吗？"], ["ExitConfirmationReturnButton", "返回"], ["ExitConfirmationConfirmButton", "仍然退出"]]:
			var control = main._ui_root.find_child(pair[0], true, false)
			_check(control.text == main._locale.translate(pair[1]), "%s correctly localizes %s after repeated switching" % [locale, pair[0]])
			if locale == "en":
				_check(control.text != pair[1], "%s has an actual translation for %s" % [locale, pair[0]])
	main.set_view_state("npc_up")
	main._set_reality_mouse_look(true)
	main.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not main._reality_mouse_look_enabled, "Win or Alt-Tab focus loss releases the captured mouse")
	main._set_reality_mouse_look(true)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "background rendering cannot capture the cursor again")
	main.notification(MainLoop.NOTIFICATION_APPLICATION_FOCUS_IN)
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "returning to the game waits for a deliberate click")
	var floor_before: int = main.game.tower_floor
	main._play_floor_arrival(2)
	_check(main._day_transition_day_label.get_theme_font("font") is SystemFont, "floor arrival uses a sans-serif display face")
	_check(main._day_transition_overlay.visible and not main._input_locked, "floor title appears without blocking exploration")
	_check(main._day_transition_overlay.get_node("DayTransitionBlack").color.a < 0.3, "arrival title preserves the visible next room")
	main._finish_day_transition()
	_check(main.game.tower_floor == floor_before, "finishing a title cannot spend an action or advance progression")
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(200, 200)
	root.add_child(scroll)
	var feed := Control.new()
	feed.custom_minimum_size = Vector2(200, 1600)
	scroll.add_child(feed)
	await process_frame
	await process_frame
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	main._on_social_feed_scroll_gui_input(wheel, scroll)
	_check(scroll.scroll_vertical >= 96, "one mouse wheel notch moves the feed by a useful reading distance")
	scroll.free()
	main._set_reality_mouse_look(false)
	main.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("UI revision regression tests passed")
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
