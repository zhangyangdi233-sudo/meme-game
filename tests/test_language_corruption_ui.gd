extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main game scene should load")
	if scene != null:
		var root := scene.instantiate()
		get_root().add_child(root)
		await process_frame
		root._locale.set_locale("zh")
		root.new_game()
		_assert_true(_find_node_by_name(root, "HUDPollutionIcon") is Button, "the in-game HUD should expose pollution")
		_assert_true(_find_node_by_name(root, "HUDDayIcon") == null, "day must not remain a visible progress metric")
		_assert_true(_find_node_by_name(root, "HUDMoneyIcon") is Button, "the compact HUD should expose usable funds")
		var hud_rail := _find_node_by_name(root, "InternationalHUDRail") as Control
		var settings_window := _find_node_by_name(root, "SettingsWindow") as Control
		var exit_button := _find_node_by_name(root, "SettingsExitGameButton") as Button
		_assert_true(hud_rail != null and _find_node_by_name(hud_rail, "ExitGameButton") == null, "退出游戏 should not remain in the HUD drawer")
		_assert_true(exit_button != null and settings_window != null and settings_window.is_ancestor_of(exit_button), "退出游戏 should remain available inside settings")
		if exit_button != null:
			_assert_eq(exit_button.text, "退出游戏", "the exit command must never be corrupted")
		_assert_true(root.has_method("_request_quit_game"), "exit should use the one-time in-game confirmation flow")
		if root.has_method("_request_quit_game"):
			root._request_quit_game()
			var confirmation := _find_node_by_name(root, "DialogLayer") as Control
			_assert_true(confirmation != null and confirmation.visible, "the first exit request should show the authored plea in the dialog")
			var message := _find_node_by_name(confirmation, "DialogMessage") as Label
			var return_button := _find_node_by_name(confirmation, "DialogButton0") as Button
			var confirm_button := _find_node_by_name(confirmation, "DialogButton1") as Button
			_assert_true(message != null and message.text == "真的要抛弃我吗？", "the exit plea should use the exact required sentence")
			_assert_true(return_button != null and return_button.text == "返回", "the safe return command should remain exact")
			_assert_true(confirm_button != null and confirm_button.text == "仍然退出", "the final exit command should remain exact")
			if return_button != null:
				return_button.pressed.emit()
		var settings_title := _find_node_by_name(root, "SettingsWindowHandle") as Label
		var save_button := _find_node_by_name(root, "SettingsManualSaveButton") as Button
		var autoplay_button := _find_node_by_name(root, "SettingsAutoplayButton") as CheckButton
		var history_button := _find_node_by_name(root, "SettingsHistoryButton") as Button
		var volume_label := _find_node_by_name(root, "SettingsVolumeLabel") as Label
		var volume_slider := _find_node_by_name(root, "SettingsVolumeSlider") as HSlider
		_assert_true(settings_title != null and settings_title.text == "设置", "clean menu should expose 设置")
		_assert_true(save_button != null and save_button.text == "保存", "clean menu should expose 保存")
		_assert_true(autoplay_button != null and autoplay_button.text == "自动播放", "clean menu should expose 自动播放")
		_assert_true(history_button != null and history_button.text == "历史记录", "clean menu should expose 历史记录")
		_assert_true(root.has_method("_toggle_history_window"), "history should be a view-only in-game window")
		if root.has_method("_toggle_history_window"):
			root.game.record_history_line({
				"lineId": "ui_history_test",
				"originalSpeaker": "玩偶",
				"currentSpeaker": "医生",
				"originalText": "回家。",
				"displayText": "{del}回家{/del}{ins}恢复{/ins}。",
				"revisionStage": 2,
				"revisionMarkup": "replace",
			})
			root._toggle_history_window()
			var history_window := _find_node_by_name(root, "HistoryWindow") as Control
			var history_entry := _find_node_by_name(root, "HistoryEntry0") as RichTextLabel
			_assert_true(history_window != null and history_window.visible, "opening history should show the read-only window")
			_assert_true(history_entry != null and history_entry.text.contains("恢复"), "history should render the authored replacement text")
		root.game.pollution = 60
		root._render_status()
		_assert_true(save_button != null and save_button.text != "保存", "menu label display may become polluted at 60%")
		_assert_true(save_button == null or not save_button.disabled, "menu pollution must not disable saving")
		_assert_true(history_button == null or not history_button.disabled, "menu pollution must not disable history")
		_assert_true(volume_label != null and volume_label.text != "音量", "high pollution may rename the volume label")
		_assert_true(volume_slider != null and volume_slider.editable, "menu pollution must never disable volume adjustment")
		root.free()
	if _failures.is_empty():
		print("language corruption UI tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _find_node_by_name(root: Node, wanted_name: String) -> Node:
	if root == null:
		return null
	if root.name == wanted_name:
		return root
	for child in root.get_children():
		var found := _find_node_by_name(child, wanted_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
