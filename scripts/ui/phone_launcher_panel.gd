class_name PhoneLauncherPanel
extends Node
## Game-side phone launcher shell: popup chrome, app grid, and babel/notebook app windows.
## While shown, it watches whether the phone is open and which app is in front, and updates itself.

signal app_icon_pressed(app_id: String)
signal phone_close_requested
signal app_window_close_requested(app_id: String)

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

const LAUNCHER_APPS := [
	{"id": "babel", "label": "塔\n楼层档案"},
	{"id": "social", "label": "帖\n信号瀑布"},
	{"id": "notebook", "label": "本\n语言工坊"},
]

const BABEL_WINDOW_LAYOUT := {
	"title": "巴别塔 App",
	"node_name": "BabelAppWindow",
	"left": -1032.0,
	"top": 96.0,
	"right": -592.0,
	"bottom": 676.0,
}
const NOTEBOOK_WINDOW_LAYOUT := {
	"title": "笔记本 App",
	"node_name": "NotebookAppWindow",
	"left": -968.0,
	"top": 152.0,
	"right": -528.0,
	"bottom": 732.0,
}

var _phone_panel: PanelContainer
var _phone_content: Control
var _phone_title: Label
var _app_windows: Dictionary = {}
var _app_titles: Dictionary = {}
var _app_bodies: Dictionary = {}

var _panel_factory: Callable
var _label_factory: Callable
var _theme_color_fn: Callable
var _load_texture_fn: Callable
var _register_draggable: Callable
var _viewport_size_fn: Callable
var _hud_safe_left_fn: Callable
var _phone_popup_hud_safe_left_fn: Callable
var _notebook_window_left_fn: Callable
var _launcher_wallpaper_path := ""
var _no_signal_icon_path := ""
var _ui_parent: Control
var _shown := false
var _observing := false
var _phone_open := true


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_ui_parent = parent
	var keep_shown := _shown
	_stop_observing()
	_build_phone_popup(parent)
	_build_app_window("babel", BABEL_WINDOW_LAYOUT)
	_build_app_window("notebook", NOTEBOOK_WINDOW_LAYOUT)
	if keep_shown:
		set_shown(true)


## The play chrome decides whether the phone may appear at all. While it may, the models decide the rest.
func set_shown(shown: bool) -> void:
	_shown = shown
	if shown:
		_start_observing()
		_apply_phone_open()
	else:
		_stop_observing()
		_set_popup_visible(false)


func _exit_tree() -> void:
	_stop_observing()


func get_phone_panel() -> PanelContainer:
	return _phone_panel


func get_phone_content() -> Control:
	return _phone_content


func get_app_window(app_id: String) -> Control:
	return _app_windows.get(app_id) as Control


func get_app_title(app_id: String) -> Label:
	return _app_titles.get(app_id) as Label


func get_app_body(app_id: String) -> VBoxContainer:
	return _app_bodies.get(app_id) as VBoxContainer


func move_phone_to_front() -> void:
	if _phone_panel != null and is_instance_valid(_phone_panel):
		_phone_panel.move_to_front()


## Lays the popup out again for the current open state, for example after the window was resized.
func relayout() -> void:
	layout_popup(_phone_open)


func layout_popup(expanded: bool) -> void:
	if _phone_panel == null or not is_instance_valid(_phone_panel):
		return
	if not _viewport_size_fn.is_valid():
		return
	var viewport_size: Vector2 = _viewport_size_fn.call()
	_phone_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	if expanded:
		var safe_left := 176.0
		if _phone_popup_hud_safe_left_fn.is_valid():
			safe_left = float(_phone_popup_hud_safe_left_fn.call())
		elif _hud_safe_left_fn.is_valid():
			safe_left = maxf(safe_left, float(_hud_safe_left_fn.call()))
		var max_height := minf(824.0, viewport_size.y - 32.0)
		var max_width := minf(480.0, viewport_size.x - safe_left - 28.0)
		var phone_width := maxf(286.0, minf(max_width, max_height / 1.72))
		var phone_height := phone_width * 1.72
		_phone_panel.offset_right = -24
		_phone_panel.offset_bottom = -18
		if viewport_size.x < 720.0:
			_phone_panel.offset_right = -8
			_phone_panel.offset_bottom = -8
		_phone_panel.offset_left = _phone_panel.offset_right - phone_width
		_phone_panel.offset_top = _phone_panel.offset_bottom - phone_height
	else:
		_phone_panel.offset_top = -306
		_phone_panel.offset_left = -112
		_phone_panel.offset_right = -12
		_phone_panel.offset_bottom = -94


func layout_app_window(app_id: String) -> void:
	var window := get_app_window(app_id)
	if window == null:
		return
	var layout: Dictionary = BABEL_WINDOW_LAYOUT if app_id == "babel" else NOTEBOOK_WINDOW_LAYOUT
	_apply_app_window_layout(
		window,
		app_id,
		float(layout.get("left", 0.0)),
		float(layout.get("top", 0.0)),
		float(layout.get("right", 0.0)),
		float(layout.get("bottom", 0.0))
	)


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_load_texture_fn = deps.get("load_texture", Callable())
	_register_draggable = deps.get("register_draggable", Callable())
	_viewport_size_fn = deps.get("viewport_size", Callable())
	_hud_safe_left_fn = deps.get("hud_safe_left", Callable())
	_phone_popup_hud_safe_left_fn = deps.get("phone_popup_hud_safe_left", Callable())
	_notebook_window_left_fn = deps.get("notebook_window_left", Callable())
	_launcher_wallpaper_path = str(deps.get("launcher_wallpaper_path", ""))
	_no_signal_icon_path = str(deps.get("no_signal_icon_path", ""))


func _build_phone_popup(parent: Control) -> void:
	if _phone_panel != null and is_instance_valid(_phone_panel):
		return
	if parent == null or not _panel_factory.is_valid() or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return

	_phone_panel = _panel_factory.call() as PanelContainer
	_phone_panel.name = "PhonePopup"
	_phone_panel.set_meta("phone_shell", true)
	_phone_panel.clip_contents = true
	_phone_panel.z_index = 20
	parent.add_child(_phone_panel)
	layout_popup(true)

	var phone_shell := VBoxContainer.new()
	phone_shell.name = "PhoneShell"
	phone_shell.add_theme_constant_override("separation", 0)
	_phone_panel.add_child(phone_shell)

	_phone_content = VBoxContainer.new()
	_phone_content.name = "PhoneContent"
	_phone_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_phone_content as VBoxContainer).add_theme_constant_override("separation", 8)
	phone_shell.add_child(_phone_content)

	var phone_header := HBoxContainer.new()
	phone_header.name = "PhoneWindowHeader"
	phone_header.custom_minimum_size.y = 60
	phone_header.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_header.add_theme_constant_override("separation", 8)
	_phone_content.add_child(phone_header)

	_phone_title = _label_factory.call("BABEL / PHONE", 18, _theme_color_fn.call("accent")) as Label
	_phone_title.name = "PhoneWindowHandle"
	_phone_title.set_meta("on_dark", true)
	_phone_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_phone_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_header.add_child(_phone_title)
	var phone_signal_icon := TextureRect.new()
	phone_signal_icon.name = "PhoneHomeNoSignalIcon"
	if _load_texture_fn.is_valid():
		phone_signal_icon.texture = _load_texture_fn.call(_no_signal_icon_path) as Texture2D
	phone_signal_icon.custom_minimum_size = Vector2(22, 22)
	phone_signal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	phone_signal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	phone_signal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_header.add_child(phone_signal_icon)
	var phone_signal := _label_factory.call("无信号", 13, _theme_color_fn.call("accent")) as Label
	phone_signal.set_meta("on_dark", true)
	phone_signal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_header.add_child(phone_signal)
	var phone_close := Button.new()
	phone_close.name = "PhoneHomeCloseButton"
	phone_close.text = "X"
	phone_close.set_meta("dark_window_close_button", true)
	phone_close.custom_minimum_size = Vector2(56, 56)
	phone_close.pressed.connect(_on_phone_close_pressed)
	phone_header.add_child(phone_close)
	if _register_draggable.is_valid():
		_register_draggable.call(_phone_panel, "phone", phone_header)
		_register_draggable.call(_phone_panel, "phone", _phone_title)

	var phone_screen := _panel_factory.call() as PanelContainer
	phone_screen.name = "PhoneScreenPanel"
	phone_screen.set_meta("phone_surface", true)
	phone_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phone_content.add_child(phone_screen)
	var launcher_wallpaper := TextureRect.new()
	launcher_wallpaper.name = "PhoneLauncherWallpaper"
	if _load_texture_fn.is_valid():
		launcher_wallpaper.texture = _load_texture_fn.call(_launcher_wallpaper_path) as Texture2D
	launcher_wallpaper.set_meta("asset_path", _launcher_wallpaper_path)
	launcher_wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	launcher_wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	launcher_wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	launcher_wallpaper.modulate = Color(1.0, 1.0, 1.0, 0.78)
	phone_screen.add_child(launcher_wallpaper)
	var launcher_tint := ColorRect.new()
	launcher_tint.name = "PhoneLauncherTint"
	launcher_tint.color = Color(_theme_color_fn.call("ink"), 0.42)
	launcher_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_screen.add_child(launcher_tint)
	var screen_box := VBoxContainer.new()
	screen_box.name = "PhoneLauncherScreen"
	screen_box.add_theme_constant_override("separation", 14)
	phone_screen.add_child(screen_box)
	var launcher_eyebrow := _label_factory.call("NO SIGNAL  /  APP LAUNCHER", 12, _theme_color_fn.call("muted")) as Label
	launcher_eyebrow.name = "PhoneLauncherEyebrow"
	launcher_eyebrow.set_meta("on_dark", true)
	screen_box.add_child(launcher_eyebrow)
	var launcher_title := _label_factory.call("选择一个窗口", 25, _theme_color_fn.call("surface")) as Label
	launcher_title.name = "PhoneLauncherTitle"
	launcher_title.set_meta("on_dark", true)
	screen_box.add_child(launcher_title)
	var launcher_rule := ColorRect.new()
	launcher_rule.name = "PhoneLauncherRule"
	launcher_rule.color = _theme_color_fn.call("muted")
	launcher_rule.custom_minimum_size.y = 4
	screen_box.add_child(launcher_rule)
	var app_grid := GridContainer.new()
	app_grid.name = "PhoneAppGrid"
	app_grid.columns = 2
	app_grid.add_theme_constant_override("h_separation", 10)
	app_grid.add_theme_constant_override("v_separation", 10)
	screen_box.add_child(app_grid)
	for app in LAUNCHER_APPS:
		var button := Button.new()
		button.name = "PhoneAppIcon%s" % str(app["id"]).capitalize()
		button.text = str(app["label"])
		button.set_meta("phone_app_icon", true)
		button.custom_minimum_size = Vector2(156, 126)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_app_icon_pressed.bind(str(app["id"])))
		app_grid.add_child(button)
	var launcher_note := _label_factory.call("每个 App 会在手机旁打开独立窗口。", 13, _theme_color_fn.call("surface")) as Label
	launcher_note.name = "PhoneLauncherNote"
	launcher_note.set_meta("on_dark", true)
	launcher_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_box.add_child(launcher_note)
	var launcher_spacer := Control.new()
	launcher_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_box.add_child(launcher_spacer)
	var launcher_indicator_wrap := CenterContainer.new()
	launcher_indicator_wrap.name = "PhoneLauncherIndicatorWrap"
	launcher_indicator_wrap.custom_minimum_size.y = 14
	screen_box.add_child(launcher_indicator_wrap)
	var launcher_indicator := ColorRect.new()
	launcher_indicator.name = "PhoneLauncherIndicator"
	launcher_indicator.color = _theme_color_fn.call("ink")
	launcher_indicator.custom_minimum_size = Vector2(88, 4)
	launcher_indicator_wrap.add_child(launcher_indicator)


func _build_app_window(app_id: String, layout: Dictionary) -> void:
	if _app_windows.has(app_id) and is_instance_valid(_app_windows[app_id]):
		return
	if not _panel_factory.is_valid() or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return

	var node_name := str(layout.get("node_name", "%sAppWindow" % app_id.capitalize()))
	var title := str(layout.get("title", app_id))
	var left := float(layout.get("left", 0.0))
	var top := float(layout.get("top", 0.0))
	var right := float(layout.get("right", 0.0))
	var bottom := float(layout.get("bottom", 0.0))

	var window := _panel_factory.call() as PanelContainer
	window.name = node_name
	window.clip_contents = true
	window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_apply_app_window_layout(window, app_id, left, top, right, bottom)
	window.z_index = 10
	if _ui_parent == null:
		return
	_ui_parent.add_child(window)

	var app_box := VBoxContainer.new()
	app_box.add_theme_constant_override("separation", 8)
	window.add_child(app_box)

	var title_label := _label_factory.call(title, 21, _theme_color_fn.call("accent")) as Label
	title_label.name = "%sHandle" % node_name
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.name = "%sCloseButton" % node_name
	close_button.text = "X"
	close_button.set_meta("window_close_button", true)
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(_on_app_window_close_pressed.bind(app_id))
	var title_bar := HBoxContainer.new()
	title_bar.name = "%sTitleBar" % node_name
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.custom_minimum_size.y = 56
	title_bar.add_theme_constant_override("separation", 8)
	app_box.add_child(title_bar)
	title_bar.add_child(title_label)
	if _register_draggable.is_valid():
		_register_draggable.call(window, "app:%s" % app_id, title_bar)
		_register_draggable.call(window, "app:%s" % app_id, title_label)
	title_bar.add_child(close_button)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	if app_id == "notebook":
		body.name = "NotebookAppBody"
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_box.add_child(body)
	else:
		var app_scroll := ScrollContainer.new()
		app_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_box.add_child(app_scroll)
		app_scroll.add_child(body)

	_app_windows[app_id] = window
	_app_titles[app_id] = title_label
	_app_bodies[app_id] = body


func _apply_app_window_layout(window: Control, app_id: String, left: float, top: float, right: float, bottom: float) -> void:
	if not _viewport_size_fn.is_valid():
		return
	var viewport_size: Vector2 = _viewport_size_fn.call()
	if viewport_size.x >= 900.0:
		if app_id == "notebook":
			window.set_anchors_preset(Control.PRESET_TOP_LEFT)
			var notebook_left := 44.0
			if _notebook_window_left_fn.is_valid():
				notebook_left = float(_notebook_window_left_fn.call())
			window.offset_left = notebook_left
			window.offset_top = 46.0
			window.offset_right = notebook_left + minf(610.0, viewport_size.x * 0.42)
			window.offset_bottom = minf(782.0, viewport_size.y - 34.0)
			return
		window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		window.offset_left = left
		window.offset_top = top
		window.offset_right = right
		window.offset_bottom = bottom
		return
	window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var safe_left := 12.0
	if _hud_safe_left_fn.is_valid():
		safe_left = maxf(safe_left, float(_hud_safe_left_fn.call()))
	var right_margin := 12.0
	var available_width := maxf(220.0, viewport_size.x - safe_left - right_margin)
	var original_width := right - left
	var target_width := minf(original_width, available_width)
	var top_margin := clampf(top, 12.0, 72.0)
	window.offset_right = -right_margin
	window.offset_left = window.offset_right - target_width
	window.offset_top = top_margin
	window.offset_bottom = viewport_size.y - 8.0


func _start_observing() -> void:
	if _observing:
		return
	var open := _property_model(PropertyKeysScript.PHONE_OPEN)
	var window := _property_model(PropertyKeysScript.ACTIVE_APP_WINDOW)
	if open == null or window == null:
		return
	_observing = true
	open.register(_on_phone_open)
	window.register(_on_active_app_window)


func _stop_observing() -> void:
	if not _observing:
		return
	_observing = false
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	var open := _property_model(PropertyKeysScript.PHONE_OPEN)
	var window := _property_model(PropertyKeysScript.ACTIVE_APP_WINDOW)
	if open != null:
		open.unregister(_on_phone_open)
	if window != null:
		window.unregister(_on_active_app_window)


func _on_phone_open(value: Variant) -> void:
	_phone_open = bool(value)
	layout_popup(_phone_open)
	_apply_phone_open()


func _on_active_app_window(value: Variant) -> void:
	var window := get_app_window(str(value))
	if window != null and is_instance_valid(window):
		window.move_to_front()


func _apply_phone_open() -> void:
	_set_popup_visible(_shown and _phone_open)


func _set_popup_visible(popup_visible: bool) -> void:
	if _phone_panel != null and is_instance_valid(_phone_panel):
		_phone_panel.visible = popup_visible
	if _phone_content != null and is_instance_valid(_phone_content):
		_phone_content.visible = popup_visible


func _property_model(property_name: String) -> PropertyModel:
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		push_error("Phone launcher cannot see the property service")
		return null
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)


func _on_app_icon_pressed(app_id: String) -> void:
	app_icon_pressed.emit(app_id)


func _on_phone_close_pressed() -> void:
	phone_close_requested.emit()


func _on_app_window_close_pressed(app_id: String) -> void:
	app_window_close_requested.emit(app_id)
