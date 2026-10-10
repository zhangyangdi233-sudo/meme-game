class_name SettingsHistoryPanel
extends Node
## Game-side settings + history windows: chrome, layout, history render/toggle, and intent signals.
## The open settings window watches volume, autoplay, and language; closing it stops.

const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

signal volume_changed(value: float)
signal vhs_toggled(value: bool)
signal autoplay_toggled(value: bool)
signal language_selected(locale_code: String)
signal manual_save_pressed
signal return_main_menu_pressed
signal exit_game_requested
signal exit_confirmed
signal history_toggle_requested
signal settings_open_changed(open: bool)

var _history_window: PanelContainer
var _history_content: VBoxContainer
var _history_open := false
var _settings_window: PanelContainer
var _settings_content: VBoxContainer
var _settings_camera_slot: VBoxContainer
var _settings_title_label: Label
var _settings_volume_label: Label
var _settings_save_button: Button
var _settings_autoplay_button: CheckButton
var _settings_history_button: Button
var _settings_exit_button: Button
var _settings_language_option: OptionButton
var _settings_save_status: Label
var _volume_slider: HSlider
var _vhs_toggle: CheckButton
var _settings_open := false
var _observing := false
var _exit_confirmation_overlay: Control
var _panel_factory: Callable
var _label_factory: Callable
var _soft_style_fn: Callable
var _theme_color_fn: Callable
var _ui_font_size_fn: Callable
var _register_draggable: Callable


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_settings_window(parent, deps)
	_build_history_window(parent)


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_soft_style_fn = deps.get("soft_style", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_ui_font_size_fn = deps.get("ui_font_size", Callable())
	_register_draggable = deps.get("register_draggable", Callable())


func is_open() -> bool:
	return _history_open


func is_settings_open() -> bool:
	return _settings_open


func set_settings_open(open: bool) -> void:
	if _settings_open == open:
		if _settings_window != null:
			_settings_window.visible = open
		return
	_settings_open = open
	if _settings_window != null:
		_settings_window.visible = open
		if open:
			_settings_window.move_to_front()
	if open:
		_start_observing()
	else:
		_stop_observing()
	settings_open_changed.emit(open)


func toggle_settings() -> void:
	set_settings_open(not _settings_open)


func close_settings() -> void:
	set_settings_open(false)


func get_history_window() -> Control:
	return _history_window


func get_settings_window() -> Control:
	return _settings_window


func get_camera_slot() -> Control:
	return _settings_camera_slot


func layout_settings(viewport_size: Vector2) -> void:
	if _settings_window == null:
		return
	var margin := 16.0
	var window_width := minf(430.0, maxf(320.0, viewport_size.x - margin * 2.0))
	var window_height := minf(868.0, maxf(420.0, viewport_size.y - margin * 2.0))
	var left := clampf(180.0, margin, maxf(margin, viewport_size.x - window_width - margin))
	var top := maxf(margin, (viewport_size.y - window_height) * 0.5)
	_settings_window.position = Vector2(left, top)
	_settings_window.size = Vector2(window_width, window_height)


func toggle(entries: Array) -> void:
	if _history_window == null:
		return
	_history_open = not _history_open
	_history_window.visible = _history_open
	if _history_open:
		refresh_history(entries)
		_history_window.move_to_front()


func close() -> void:
	_history_open = false
	if _history_window != null:
		_history_window.visible = false


func _exit_tree() -> void:
	_stop_observing()


func _start_observing() -> void:
	if _observing:
		return
	var watched := _watched_listeners()
	var models: Dictionary = {}
	for property_name in watched:
		var found := _property_model(property_name)
		if found == null:
			return
		models[property_name] = found
	for property_name in watched:
		(models[property_name] as PropertyModel).register(watched[property_name])
	_observing = true


func _stop_observing() -> void:
	if not _observing:
		return
	_observing = false
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	var watched := _watched_listeners()
	for property_name in watched:
		var found := _property_model(property_name)
		if found != null:
			found.unregister(watched[property_name])


func _watched_listeners() -> Dictionary:
	return {
		PropertyKeysScript.MASTER_VOLUME: _on_master_volume,
		PropertyKeysScript.AUTOPLAY_ENABLED: _on_autoplay,
		PropertyKeysScript.LOCALE: _on_locale,
	}


func _on_master_volume(value: Variant) -> void:
	if _volume_slider != null:
		_volume_slider.set_value_no_signal(float(value))


func _on_autoplay(value: Variant) -> void:
	if _settings_autoplay_button != null:
		_settings_autoplay_button.set_pressed_no_signal(bool(value))


func _on_locale(value: Variant) -> void:
	if _settings_language_option == null:
		return
	for index in _settings_language_option.item_count:
		if str(_settings_language_option.get_item_metadata(index)) == str(value):
			_settings_language_option.select(index)
			return


func _property_model(property_name: String) -> PropertyModel:
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		push_error("Settings cannot see the property service")
		return null
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)


func refresh_menu_labels(pollution: int) -> void:
	if _settings_title_label != null:
		_settings_title_label.text = _menu_display_label(pollution, "settings")
	if _settings_volume_label != null:
		_settings_volume_label.text = _menu_display_label(pollution, "volume")
	if _volume_slider != null:
		_volume_slider.editable = true
		_volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	if _settings_save_button != null:
		_settings_save_button.text = _menu_display_label(pollution, "save")
	if _settings_autoplay_button != null:
		_settings_autoplay_button.text = _menu_display_label(pollution, "autoplay")
	if _settings_history_button != null:
		_settings_history_button.text = _menu_display_label(pollution, "history")


func set_save_status(text: String) -> void:
	if _settings_save_status != null:
		_settings_save_status.text = text


func build_exit_confirmation_overlay(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid():
		return
	if _exit_confirmation_overlay != null and is_instance_valid(_exit_confirmation_overlay):
		_exit_confirmation_overlay.queue_free()
	_exit_confirmation_overlay = Control.new()
	_exit_confirmation_overlay.name = "ExitConfirmationOverlay"
	_exit_confirmation_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit_confirmation_overlay.visible = false
	_exit_confirmation_overlay.z_index = 220
	parent.add_child(_exit_confirmation_overlay)

	var blackout := ColorRect.new()
	blackout.name = "ExitConfirmationBackdrop"
	blackout.color = Color(_theme_color_fn.call("ink"), 0.88)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit_confirmation_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_exit_confirmation_overlay.add_child(center)
	var panel := _panel_factory.call() as PanelContainer
	panel.name = "ExitConfirmationPanel"
	panel.custom_minimum_size = Vector2(520, 230)
	panel.add_theme_stylebox_override("panel", _soft_style_fn.call(_theme_color_fn.call("surface"), _theme_color_fn.call("accent")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 24)
	panel.add_child(box)
	var message := _label_factory.call("真的要抛弃我吗？", 25, _theme_color_fn.call("ink")) as Label
	message.name = "ExitConfirmationMessage"
	message.set_meta("skip_localization", true)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var return_button := Button.new()
	return_button.name = "ExitConfirmationReturnButton"
	return_button.text = "返回"
	return_button.set_meta("skip_localization", true)
	return_button.custom_minimum_size = Vector2(180, 54)
	return_button.pressed.connect(cancel_quit)
	actions.add_child(return_button)
	var confirm_button := Button.new()
	confirm_button.name = "ExitConfirmationConfirmButton"
	confirm_button.text = "仍然退出"
	confirm_button.set_meta("skip_localization", true)
	confirm_button.custom_minimum_size = Vector2(180, 54)
	confirm_button.pressed.connect(_on_exit_confirm_pressed)
	actions.add_child(confirm_button)


func request_quit() -> void:
	if _exit_confirmation_overlay != null:
		_exit_confirmation_overlay.visible = true
		_exit_confirmation_overlay.move_to_front()


func cancel_quit() -> void:
	if _exit_confirmation_overlay != null:
		_exit_confirmation_overlay.visible = false


func refresh_history(entries: Array) -> void:
	if _history_content == null:
		return
	for child in _history_content.get_children():
		child.queue_free()
	if entries.is_empty():
		var empty := _label_factory.call("还没有能被记住的话。", 17, _theme_color_fn.call("ink")) as Label
		empty.name = "HistoryEmptyState"
		_history_content.add_child(empty)
		return
	for index in entries.size():
		var entry: Dictionary = entries[index]
		var line := RichTextLabel.new()
		line.name = "HistoryEntry%d" % index
		line.bbcode_enabled = true
		line.fit_content = true
		line.scroll_active = false
		line.custom_minimum_size = Vector2(500, 70)
		line.add_theme_font_size_override("normal_font_size", _ui_font_size_fn.call(17))
		line.add_theme_color_override("default_color", _theme_color_fn.call("ink"))
		var speaker := str(entry.get("currentSpeaker", entry.get("originalSpeaker", "")))
		var display_text := str(entry.get("displayText", entry.get("originalText", "")))
		line.text = "[b]%s[/b]\n%s" % [_escape_history_bbcode(speaker), _history_markup_to_bbcode(display_text)]
		_history_content.add_child(line)


func _build_settings_window(parent: Control, deps: Dictionary) -> void:
	if _settings_window != null:
		return
	_settings_window = _panel_factory.call() as PanelContainer
	_settings_window.name = "SettingsWindow"
	_settings_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_settings_window.offset_left = 180
	_settings_window.offset_top = 16
	_settings_window.offset_right = 610
	_settings_window.offset_bottom = 884
	_settings_window.z_index = 30
	_settings_window.visible = false
	parent.add_child(_settings_window)
	layout_settings(parent.size)

	var settings_shell := Control.new()
	settings_shell.name = "SettingsShell"
	settings_shell.set_anchors_preset(Control.PRESET_FULL_RECT)
	_settings_window.add_child(settings_shell)

	var title_bar := HBoxContainer.new()
	title_bar.name = "SettingsTitleBar"
	title_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_bar.offset_bottom = 56
	title_bar.add_theme_constant_override("separation", 8)
	settings_shell.add_child(title_bar)
	_register_draggable.call(_settings_window, "settings", title_bar)

	_settings_title_label = _label_factory.call("设置", 24, _theme_color_fn.call("accent")) as Label
	_settings_title_label.name = "SettingsWindowHandle"
	_settings_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_settings_title_label)
	_register_draggable.call(_settings_window, "settings", _settings_title_label)
	var close_button := Button.new()
	close_button.name = "SettingsCloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(close_settings)
	title_bar.add_child(close_button)

	var settings_scroll := ScrollContainer.new()
	settings_scroll.name = "SettingsScroll"
	settings_scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_scroll.offset_top = 66
	settings_scroll.offset_bottom = -108
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_shell.add_child(settings_scroll)

	_settings_content = VBoxContainer.new()
	_settings_content.name = "SettingsContent"
	_settings_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings_content.add_theme_constant_override("separation", 8)
	settings_scroll.add_child(_settings_content)

	_settings_volume_label = _label_factory.call("音量", 17, _theme_color_fn.call("ink")) as Label
	_settings_volume_label.name = "SettingsVolumeLabel"
	_settings_volume_label.set_meta("functional_label_only", true)
	_settings_content.add_child(_settings_volume_label)
	_volume_slider = HSlider.new()
	_volume_slider.name = "SettingsVolumeSlider"
	_volume_slider.set_meta("must_remain_functional", true)
	_volume_slider.min_value = 0
	_volume_slider.max_value = 100
	_volume_slider.step = 1
	_volume_slider.editable = true
	_volume_slider.mouse_filter = Control.MOUSE_FILTER_STOP
	_volume_slider.focus_mode = Control.FOCUS_ALL
	_volume_slider.custom_minimum_size = Vector2(260, 44)
	_volume_slider.value_changed.connect(_on_volume_slider_changed)
	_settings_content.add_child(_volume_slider)

	_vhs_toggle = CheckButton.new()
	_vhs_toggle.name = "SettingsVHSToggle"
	_vhs_toggle.text = "开启 VHS 质感"
	_vhs_toggle.button_pressed = bool(deps.get("vhs_enabled", true))
	_vhs_toggle.custom_minimum_size.y = 48
	_vhs_toggle.toggled.connect(_on_vhs_toggle_changed)
	_settings_content.add_child(_vhs_toggle)

	_settings_camera_slot = VBoxContainer.new()
	_settings_camera_slot.name = "SettingsCameraSlot"
	_settings_camera_slot.add_theme_constant_override("separation", 8)
	_settings_content.add_child(_settings_camera_slot)

	var language_label := _label_factory.call("语言", 17, _theme_color_fn.call("ink")) as Label
	_settings_content.add_child(language_label)
	_settings_language_option = OptionButton.new()
	_settings_language_option.name = "SettingsLanguageOption"
	_settings_language_option.set_meta("skip_localization", true)
	_settings_language_option.custom_minimum_size = Vector2(300, 50)
	var locales: Array = deps.get("locales", [])
	for item in locales:
		var locale_item: Dictionary = item
		var locale_code := str(locale_item.get("code", ""))
		_settings_language_option.add_item(str(locale_item.get("name", locale_code)))
		_settings_language_option.set_item_metadata(_settings_language_option.item_count - 1, locale_code)
	_settings_language_option.item_selected.connect(_on_language_item_selected)
	_settings_content.add_child(_settings_language_option)

	_settings_save_button = Button.new()
	_settings_save_button.name = "SettingsManualSaveButton"
	_settings_save_button.text = "保存"
	_settings_save_button.set_meta("skip_localization", true)
	_settings_save_button.custom_minimum_size.y = 50
	_settings_save_button.pressed.connect(_on_save_button_pressed)
	_settings_content.add_child(_settings_save_button)
	_settings_save_status = _label_factory.call("", 14, _theme_color_fn.call("accent")) as Label
	_settings_save_status.name = "SettingsSaveStatus"
	_settings_content.add_child(_settings_save_status)

	_settings_autoplay_button = CheckButton.new()
	_settings_autoplay_button.name = "SettingsAutoplayButton"
	_settings_autoplay_button.text = "自动播放"
	_settings_autoplay_button.set_meta("skip_localization", true)
	_settings_autoplay_button.custom_minimum_size.y = 50
	_settings_autoplay_button.toggled.connect(_on_autoplay_toggle_changed)
	_settings_content.add_child(_settings_autoplay_button)

	_settings_history_button = Button.new()
	_settings_history_button.name = "SettingsHistoryButton"
	_settings_history_button.text = "历史记录"
	_settings_history_button.set_meta("skip_localization", true)
	_settings_history_button.custom_minimum_size.y = 50
	_settings_history_button.pressed.connect(_on_history_button_pressed)
	_settings_content.add_child(_settings_history_button)

	var return_main_button := Button.new()
	return_main_button.name = "SettingsReturnMainButton"
	return_main_button.text = "退回主画面"
	return_main_button.custom_minimum_size.y = 50
	return_main_button.pressed.connect(_on_return_main_button_pressed)
	_settings_content.add_child(return_main_button)

	var system_footer := VBoxContainer.new()
	system_footer.name = "SettingsSystemFooter"
	system_footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	system_footer.offset_top = -100
	system_footer.add_theme_constant_override("separation", 6)
	settings_shell.add_child(system_footer)
	var system_rule := HSeparator.new()
	system_rule.name = "SettingsSystemDivider"
	system_footer.add_child(system_rule)
	var system_label := _label_factory.call("系统", 14, _theme_color_fn.call("accent")) as Label
	system_label.name = "SettingsSystemLabel"
	system_footer.add_child(system_label)
	_settings_exit_button = Button.new()
	_settings_exit_button.name = "SettingsExitGameButton"
	_settings_exit_button.text = "退出游戏"
	_settings_exit_button.set_meta("skip_localization", true)
	_settings_exit_button.set_meta("reliable_system_command", true)
	_settings_exit_button.custom_minimum_size.y = 52
	_settings_exit_button.pressed.connect(_on_exit_button_pressed)
	system_footer.add_child(_settings_exit_button)


func _build_history_window(parent: Control) -> void:
	if _history_window != null:
		return
	_history_window = _panel_factory.call() as PanelContainer
	_history_window.name = "HistoryWindow"
	_history_window.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_history_window.offset_left = 570
	_history_window.offset_top = 110
	_history_window.offset_right = 1160
	_history_window.offset_bottom = 760
	_history_window.z_index = 32
	_history_window.visible = false
	parent.add_child(_history_window)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 10)
	_history_window.add_child(outer)
	var title_bar := HBoxContainer.new()
	title_bar.name = "HistoryTitleBar"
	title_bar.custom_minimum_size.y = 54
	outer.add_child(title_bar)
	_register_draggable.call(_history_window, "history", title_bar)
	var title := _label_factory.call("历史记录", 23, _theme_color_fn.call("accent")) as Label
	title.name = "HistoryWindowHandle"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.set_meta("skip_localization", true)
	title_bar.add_child(title)
	_register_draggable.call(_history_window, "history", title)
	var close_button := Button.new()
	close_button.name = "HistoryCloseButton"
	close_button.text = "X"
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(_on_history_close_pressed)
	title_bar.add_child(close_button)

	var scroll := ScrollContainer.new()
	scroll.name = "HistoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	_history_content = VBoxContainer.new()
	_history_content.name = "HistoryContent"
	_history_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_content.add_theme_constant_override("separation", 10)
	scroll.add_child(_history_content)


func _on_volume_slider_changed(value: float) -> void:
	volume_changed.emit(value)


func _on_vhs_toggle_changed(value: bool) -> void:
	vhs_toggled.emit(value)


func _on_autoplay_toggle_changed(value: bool) -> void:
	autoplay_toggled.emit(value)


func _on_language_item_selected(index: int) -> void:
	if _settings_language_option == null or index < 0 or index >= _settings_language_option.item_count:
		return
	language_selected.emit(str(_settings_language_option.get_item_metadata(index)))


func _on_save_button_pressed() -> void:
	manual_save_pressed.emit()


func _on_return_main_button_pressed() -> void:
	return_main_menu_pressed.emit()


func _on_exit_button_pressed() -> void:
	exit_game_requested.emit()


func _on_history_button_pressed() -> void:
	history_toggle_requested.emit()


func _on_history_close_pressed() -> void:
	close()


func _on_exit_confirm_pressed() -> void:
	exit_confirmed.emit()


func _menu_display_label(pollution: int, kind: String) -> String:
	var menu_tier := int(PollutionStageScript.stage(pollution).get("menu_tier", 0))
	if menu_tier == 0:
		return {"save": "保存", "autoplay": "自动播放", "history": "历史记录", "settings": "设置", "volume": "音量"}.get(kind, kind)
	if menu_tier == 1:
		return {
			"save": "留住这一段",
			"autoplay": "让我替你继续说",
			"history": "他们说你说过",
			"settings": "调整记录方式",
			"volume": "外面的声音",
		}.get(kind, kind)
	return {
		"save": "留住这■■",
		"autoplay": "让我替你继续■■",
		"history": "他们说你■■过",
		"settings": "调整你能接受的部分",
		"volume": "它离你有多近",
	}.get(kind, kind)


func _escape_history_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _history_markup_to_bbcode(value: String) -> String:
	var escaped := _escape_history_bbcode(value)
	return escaped.replace("{del}", "[s]").replace("{/del}", "[/s]").replace("{ins}", "[u]").replace("{/ins}", "[/u]")
