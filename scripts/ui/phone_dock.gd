extends PanelContainer
## A single phone, kept at the right edge of the live world.
signal toggled
signal app_requested(app_id: String)
signal home_requested

const INK := Color("3F2937")
const PAPER := Color("FFF1C9")
const FACE_SIZE := Vector2(440, 790)
var screen: Control
var launcher: Control
var tab: Button
var app_buttons: Dictionary = {}
var _face: Control
var _slide: Tween
var _page_motion: Tween
var _open := false
var _available := false
var _revealed := false
var _viewport_size := Vector2.ZERO
var _scale_factor := 1.0
var _slide_fraction := 0.0
var _last_page := ""
var _map_unlock_progress := -1.0
var _map_slide_paused := false

class EdgeTab extends Button:
	var opened := false
	func _draw() -> void:
		var center := size * 0.5
		var spread := minf(5, size.x * 0.2)
		var direction := 1.0 if opened else -1.0
		draw_polyline(PackedVector2Array([center + Vector2(-spread * direction, -spread), center + Vector2(spread * direction, 0), center + Vector2(-spread * direction, spread)]), Color("FFF1C9"), minf(1.5, size.x * 0.15), true)

class Glass extends Control:
	func _draw() -> void:
		var dark := Color(0.24, 0.16, 0.20, 0.48)
		var glint := Color(1, 0.98, 0.9, 0.55)
		var paths := [PackedVector2Array([Vector2(425, 58), Vector2(410, 76), Vector2(415, 96), Vector2(389, 121), Vector2(383, 150)]), PackedVector2Array([Vector2(411, 76), Vector2(391, 80), Vector2(375, 99)]), PackedVector2Array([Vector2(415, 96), Vector2(426, 112)]), PackedVector2Array([Vector2(17, 657), Vector2(34, 638), Vector2(32, 620), Vector2(49, 606)]), PackedVector2Array([Vector2(34, 638), Vector2(53, 644)])]
		for points in paths:
			draw_polyline(points, dark, 1.0, true)
			var highlights := PackedVector2Array()
			for point in points:
				highlights.append(point + Vector2(1, 0))
			draw_polyline(highlights, glint, 0.7, true)

class PhoneFace extends Control:
	func _draw() -> void:
		var shell := StyleBoxFlat.new()
		shell.bg_color = Color("3F2937")
		shell.border_color = Color("AD9F9D")
		shell.set_border_width_all(1)
		shell.set_corner_radius_all(26)
		shell.shadow_color = Color(0, 0, 0, 0.38)
		shell.shadow_size = 9
		draw_style_box(shell, Rect2(Vector2.ZERO, Vector2(440, 790)))
		var glass := StyleBoxFlat.new()
		glass.bg_color = Color("FFF1C9")
		glass.set_corner_radius_all(17)
		draw_style_box(glass, Rect2(13, 13, 414, 764))
		# Broad, softly uneven notch and recessed speaker, from the reference.
		draw_colored_polygon(PackedVector2Array([Vector2(122, 10), Vector2(319, 10), Vector2(316, 28), Vector2(313, 37), Vector2(134, 37), Vector2(126, 32)]), Color("3F2937"))
		draw_circle(Vector2(172, 23), 4, Color("362530"))
		draw_style_box(_speaker(), Rect2(189, 18, 73, 7))
		draw_line(Vector2(439, 128), Vector2(439, 175), Color("76616D"), 3)
		draw_line(Vector2(1, 109), Vector2(1, 143), Color("76616D"), 2)
	func _speaker() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("362530")
		style.set_corner_radius_all(4)
		return style

func _ready() -> void:
	set_meta("phone_dock", true)
	add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	_face = PhoneFace.new()
	_face.name = "PhoneFace"
	_face.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_face)
	_face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen = Control.new()
	screen.name = "PhoneScreenContent"
	screen.position = Vector2(20, 58)
	screen.size = Vector2(400, 670)
	screen.clip_contents = true
	_face.add_child(screen)
	launcher = Control.new()
	launcher.name = "PhoneLauncherScreen"
	launcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.add_child(launcher)
	var status := Label.new()
	status.name = "PhoneSignal"
	status.text = "···"
	status.position = Vector2(10, 0)
	status.add_theme_color_override("font_color", INK)
	launcher.add_child(status)
	var app_ids := ["social", "notebook", "map"]
	var app_labels := ["瀑布流", "笔记本", "地图"]
	for i in app_ids.size():
		var app_id: String = app_ids[i]
		var button := Button.new()
		button.name = "PhoneAppIcon%s" % app_id.capitalize()
		button.position = Vector2(39 + i * 171, 87) if i < 2 else Vector2(126, 276)
		button.size = Vector2(148, 138)
		button.focus_mode = Control.FOCUS_NONE
		button.icon = load("res://assets/ui/phone_%s.svg" % app_id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.expand_icon = false
		button.text = app_labels[i]
		button.visible = app_id != "map"
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_color_override("font_color", INK)
		button.add_theme_color_override("font_disabled_color", Color("92877A"))
		button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.28))
		button.add_theme_color_override("icon_normal_color", Color.WHITE)
		for mode in ["normal", "disabled", "focus"]:
			button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
		var hover := StyleBoxFlat.new()
		hover.bg_color = Color(0.25, 0.16, 0.22, 0.07)
		hover.set_corner_radius_all(12)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", hover)
		button.pressed.connect(func(): app_requested.emit(app_id))
		launcher.add_child(button)
		app_buttons[app_id] = button
	var home := Button.new()
	home.name = "PhoneHomeButton"
	home.position = Vector2(166, 746)
	home.size = Vector2(108, 26)
	home.text = "—"
	home.focus_mode = Control.FOCUS_NONE
	home.add_theme_color_override("font_color", INK)
	for mode in ["normal", "hover", "pressed", "focus"]:
		home.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
	home.pressed.connect(func(): home_requested.emit())
	_face.add_child(home)
	var cracks := Glass.new()
	cracks.name = "PhoneScreenCracks"
	cracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Glass sits over every app/detail page, even when those windows raise their Z.
	# It stays inside the phone hierarchy and below global settings/confirmation UI.
	cracks.z_index = 100
	cracks.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_face.add_child(cracks)
	tab = EdgeTab.new()
	tab.name = "PhoneEdgeTab"
	tab.tooltip_text = "手机"
	tab.focus_mode = Control.FOCUS_NONE
	tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tab.add_theme_font_size_override("font_size", 25)
	tab.add_theme_color_override("font_color", PAPER)
	var tab_style := StyleBoxFlat.new()
	tab_style.bg_color = INK
	tab_style.border_color = Color("AD9F9D")
	tab_style.set_border_width_all(1)
	tab_style.set_content_margin_all(0)
	tab_style.corner_radius_top_left = 10
	tab_style.corner_radius_bottom_left = 10
	tab.add_theme_stylebox_override("normal", tab_style)
	var tab_hover := tab_style.duplicate() as StyleBoxFlat
	tab_hover.bg_color = Color("6B4B5A")
	tab.add_theme_stylebox_override("hover", tab_hover)
	tab.add_theme_stylebox_override("pressed", tab_hover)
	tab.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# A sibling keeps the handle at the screen edge while the body slides.
	get_parent().add_child.call_deferred(tab)
	tab.pressed.connect(func(): toggled.emit())
	tab.mouse_entered.connect(func(): _hover_tab(true))
	tab.mouse_exited.connect(func(): _hover_tab(false))
	resized.connect(_layout_face)
	_layout_face()

func configure(available: bool, expanded: bool, permissions: Dictionary, viewport_size: Vector2, unobstructed: bool = true) -> void:
	_available = available and unobstructed
	visible = _available
	if is_instance_valid(tab):
		tab.visible = _available
	for app_id in app_buttons:
		(app_buttons[app_id] as Button).disabled = not bool(permissions.get(app_id, false))
		if app_id == "map":
			(app_buttons[app_id] as Button).visible = permissions.has("map")
	var resized_view := viewport_size != _viewport_size
	_viewport_size = viewport_size
	_scale_factor = clampf(minf((viewport_size.y - minf(46, viewport_size.y * 0.15)) / FACE_SIZE.y, (viewport_size.x - minf(48, viewport_size.x * 0.3)) / FACE_SIZE.x), 0.001, 1.0)
	if expanded != _open or not _revealed:
		_open = expanded
		_revealed = true
		if _slide != null and _slide.is_valid():
			_slide.kill()
		_slide = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
		_map_slide_paused = false
		_slide.tween_method(_set_slide, _slide_fraction, 1.0 if _open else 0.0, 0.52)
	if resized_view:
		_layout_face()
	_update_tab()
	set_map_unlock_progress(_map_unlock_progress)


func set_map_unlock_progress(value: float) -> void:
	_map_unlock_progress = value
	if not app_buttons.has("map"):
		return
	var button := app_buttons.map as Button
	var fraction := clampf(value, 0.0, 1.0)
	button.add_theme_color_override("font_disabled_color", Color("92877A").lerp(INK, fraction))
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, lerpf(0.28, 1.0, fraction)))
	button.set_meta("unlock_brightness", fraction)
	if value >= 0:
		button.disabled = true


func set_map_unlock_paused(paused: bool) -> void:
	if _slide == null or not _slide.is_valid():
		return
	if paused and _slide.is_running():
		_slide.pause()
		_map_slide_paused = true
	elif not paused and _map_slide_paused:
		_slide.play()
		_map_slide_paused = false

func _set_slide(value: float) -> void:
	_slide_fraction = value
	_layout_face()

func _layout_face() -> void:
	if _face == null or _viewport_size == Vector2.ZERO:
		return
	# The panel stays a fixed virtual size so app typography doesn't jump.
	size = FACE_SIZE
	scale = Vector2.ONE * _scale_factor
	position = Vector2(lerpf(_viewport_size.x + 16, _viewport_size.x - FACE_SIZE.x * _scale_factor - minf(24, _viewport_size.x * 0.15), _slide_fraction), (_viewport_size.y - FACE_SIZE.y * _scale_factor) * 0.5)
	_update_tab()

func _update_tab() -> void:
	if not is_instance_valid(tab):
		return
	var tab_width := minf(24, _viewport_size.x * 0.15)
	var tab_height := minf(86, _viewport_size.y * 0.6)
	tab.custom_minimum_size = Vector2.ZERO
	tab.size = Vector2(tab_width, tab_height)
	tab.position = Vector2(_viewport_size.x - tab.size.x, clampf(_viewport_size.y * 0.54 - tab.size.y * 0.5, 0, maxf(0, _viewport_size.y - tab.size.y)))
	tab.z_index = 43
	tab.opened = _open
	tab.queue_redraw()

func _hover_tab(hovered: bool) -> void:
	if not is_instance_valid(tab):
		return
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(tab, "modulate", Color(1.18, 1.12, 1.08) if hovered else Color.WHITE, 0.18)

func show_page(page: String, windows: Dictionary) -> void:
	launcher.visible = page.is_empty()
	if page == _last_page:
		return
	_last_page = page
	if _page_motion != null and _page_motion.is_valid():
		_page_motion.kill()
	for id in windows:
		var window := windows[id] as Control
		if window.get_parent() != screen:
			continue
		window.visible = id == page
		window.modulate = Color.WHITE
		window.position = Vector2.ZERO
	if windows.has(page):
		var current := windows[page] as Control
		current.modulate.a = 0.0
		_page_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_page_motion.tween_property(current, "modulate:a", 1.0, 0.22)

func contains_edge(point: Vector2) -> bool:
	return _available and is_instance_valid(tab) and tab.get_global_rect().grow(12).has_point(point)
