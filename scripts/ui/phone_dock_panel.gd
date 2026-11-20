class_name PhoneDockPanel
extends Node
## The found phone: one phone docked at the right edge of the live world, as the old version had it (the owner asked
## for the old phone back over the first-generation launcher, which hid the world behind a street picture). The room
## stays visible and lit behind it. A narrow tab sticks out of the right edge; a click on it or Tab slides the phone in
## and back out. Its home shows the social feed, the notebook and the map; an app opens inside the phone's screen, one
## at a time, and the home bar goes back to the home.
## While shown it watches whether the phone is up, which app is in front, which apps are unlocked and the pollution, and
## updates itself. Its tab, icons, home bar and the notebook's close raise UI intents; the host writes the models.
## The host mounts the phone's social feed into `get_screen()` and hands its windows over with `add_page` /
## `add_overlay`; the notebook's window is built here, because inside the phone it is only a page.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## The phone keeps one virtual size and scales as a whole, so the apps' type never jumps between window sizes.
const FACE_SIZE := Vector2(440, 790)
## Where the apps show on the glass, below the notch and above the home bar.
const SCREEN_RECT := Rect2(20, 58, 400, 670)
const HOME_RECT := Rect2(166, 746, 108, 26)
## Where a picked-up word lands while the notebook is not in front: the home bar, the way back to it.
const HOME_POINT := Vector2(220, 755)
## The home's icons, laid out as on the old phone: two side by side, the map below them.
const APPS: Array[Dictionary] = [
	{"id": "social", "label": "瀑布流", "position": Vector2(39, 87)},
	{"id": "notebook", "label": "笔记本", "position": Vector2(210, 87)},
	{"id": "map", "label": "地图", "position": Vector2(126, 276)},
]
const ICON_SIZE := Vector2(148, 138)
const ICON_PATH := "res://assets/ui/phone_%s.svg"
const NOTEBOOK_TITLE := "笔记本 App"
## How long the phone takes to slide in from the right edge or back out, and how long an app takes to fade in.
const SLIDE_SECONDS := 0.52
const PAGE_FADE_SECONDS := 0.22
## The edge tab: at most this narrow and this tall, a little below the middle of the right edge.
const TAB_MAX_SIZE := Vector2(24, 86)
const TAB_HEIGHT_RATIO := 0.54
## Gaps the phone keeps from the window's edges: past the right edge when away, before the tab when up.
const AWAY_GAP := 16.0
const EDGE_GAP := 24.0
const VERTICAL_GAP := 46.0
const HORIZONTAL_GAP := 48.0
## The phone's body is hardware, not UI: its plum shell, bezel, speaker and buttons keep their color. Pollution tints
## the glass and what shows on it through the palette.
const SHELL := Color("3F2937")
const SHELL_EDGE := Color("AD9F9D")
const SHELL_DEEP := Color("362530")
const SHELL_BUTTON := Color("76616D")
const TAB_HOVER := Color("6B4B5A")
## A locked icon's picture stays faint; its name takes the palette's pending color.
const ICON_LOCKED_ALPHA := 0.28
## No page has been laid out yet: the first sync always lays the screen out.
## A plain marker no app id can equal: a NUL character here made the engine print a Unicode parsing error at every load.
const NO_PAGE := "<no page>"


## The narrow handle on the right edge. It draws its whole look itself, so the global theme walk's button styles
## never show on it; the chevron points the way the phone will move.
class EdgeTab extends Button:
	var opened := false
	var paper := Color("FFF1C9")

	func _draw() -> void:
		var body := StyleBoxFlat.new()
		body.bg_color = SHELL if get_draw_mode() == DRAW_NORMAL else TAB_HOVER
		body.border_color = SHELL_EDGE
		body.set_border_width_all(1)
		body.corner_radius_top_left = 10
		body.corner_radius_bottom_left = 10
		draw_style_box(body, Rect2(Vector2.ZERO, size))
		var center := size * 0.5
		var spread := minf(5.0, size.x * 0.2)
		var direction := 1.0 if opened else -1.0
		draw_polyline(
			PackedVector2Array([
				center + Vector2(-spread * direction, -spread),
				center + Vector2(spread * direction, 0.0),
				center + Vector2(-spread * direction, spread),
			]),
			paper,
			minf(1.5, size.x * 0.15),
			true
		)


## The shell, the glass, the notch with its camera and speaker, and the side buttons.
class PhoneFace extends Control:
	var glass := Color("FFF1C9")

	func _draw() -> void:
		var shell := StyleBoxFlat.new()
		shell.bg_color = SHELL
		shell.border_color = SHELL_EDGE
		shell.set_border_width_all(1)
		shell.set_corner_radius_all(26)
		shell.shadow_color = Color(0, 0, 0, 0.38)
		shell.shadow_size = 9
		draw_style_box(shell, Rect2(Vector2.ZERO, FACE_SIZE))
		var glass_style := StyleBoxFlat.new()
		glass_style.bg_color = glass
		glass_style.set_corner_radius_all(17)
		draw_style_box(glass_style, Rect2(13, 13, 414, 764))
		# A broad, softly uneven notch and a recessed speaker, as on the old phone.
		draw_colored_polygon(
			PackedVector2Array([Vector2(122, 10), Vector2(319, 10), Vector2(316, 28), Vector2(313, 37), Vector2(134, 37), Vector2(126, 32)]),
			SHELL
		)
		draw_circle(Vector2(172, 23), 4, SHELL_DEEP)
		var speaker := StyleBoxFlat.new()
		speaker.bg_color = SHELL_DEEP
		speaker.set_corner_radius_all(4)
		draw_style_box(speaker, Rect2(189, 18, 73, 7))
		draw_line(Vector2(439, 128), Vector2(439, 175), SHELL_BUTTON, 3)
		draw_line(Vector2(1, 109), Vector2(1, 143), SHELL_BUTTON, 2)


## Two cracks in the glass, over every page the phone shows.
class GlassCracks extends Control:
	func _draw() -> void:
		var dark := Color(0.24, 0.16, 0.20, 0.48)
		var glint := Color(1, 0.98, 0.9, 0.55)
		var paths := [
			PackedVector2Array([Vector2(425, 58), Vector2(410, 76), Vector2(415, 96), Vector2(389, 121), Vector2(383, 150)]),
			PackedVector2Array([Vector2(411, 76), Vector2(391, 80), Vector2(375, 99)]),
			PackedVector2Array([Vector2(415, 96), Vector2(426, 112)]),
			PackedVector2Array([Vector2(17, 657), Vector2(34, 638), Vector2(32, 620), Vector2(49, 606)]),
			PackedVector2Array([Vector2(34, 638), Vector2(53, 644)]),
		]
		for points: PackedVector2Array in paths:
			draw_polyline(points, dark, 1.0, true)
			var highlights := PackedVector2Array()
			for point in points:
				highlights.append(point + Vector2(1, 0))
			draw_polyline(highlights, glint, 0.7, true)


var _body: Control
var _face: PhoneFace
var _screen: Control
var _launcher: Control
var _signal: Label
var _home: Button
var _cracks: GlassCracks
var _tab: EdgeTab
var _icons: Dictionary = {}
## App id to the page that shows it inside the screen.
var _pages: Dictionary = {}
var _notebook_window: PanelContainer
var _notebook_title: Label
var _notebook_body: VBoxContainer
var _shown := false
var _open := false
var _front := ""
var _page := NO_PAGE
var _unlocked: Array = []
var _viewport_size := Vector2.ZERO
var _scale_factor := 1.0
## How far the phone has slid in: 0 rests past the right edge, 1 is up.
var _slide_fraction := 0.0
var _slide: Tween
var _page_motion: Tween
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.VIEW_STATE: _on_view_state,
	PropertyKeysScript.ACTIVE_APP_WINDOW: _on_active_app_window,
	PropertyKeysScript.UNLOCKED_APPS: _on_unlocked_apps,
	PropertyKeysScript.POLLUTION: _on_pollution,
})


## Builds the phone and its edge tab under `parent` (the play UI root), hidden until shown.
func mount(parent: Control) -> void:
	if _body != null and is_instance_valid(_body):
		return
	_body = Control.new()
	_body.name = "PhonePopup"
	_body.set_meta("phone_dock", true)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.z_index = 40
	_body.size = FACE_SIZE
	_body.visible = false
	parent.add_child(_body)

	_face = PhoneFace.new()
	_face.name = "PhoneFace"
	# The phone takes the clicks that land on it, so none reaches the room behind.
	_face.mouse_filter = Control.MOUSE_FILTER_STOP
	_face.size = FACE_SIZE
	_body.add_child(_face)

	_screen = Control.new()
	_screen.name = "PhoneScreenContent"
	_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.position = SCREEN_RECT.position
	_screen.size = SCREEN_RECT.size
	_screen.clip_contents = true
	_face.add_child(_screen)

	_launcher = Control.new()
	_launcher.name = "PhoneLauncherScreen"
	_launcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_launcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(_launcher)
	_signal = _theme().label("···", 18, _theme().theme_color("ink"))
	_signal.name = "PhoneSignal"
	_signal.position = Vector2(10, 0)
	_launcher.add_child(_signal)
	for app in APPS:
		_launcher.add_child(_build_icon(str(app["id"]), str(app["label"]), app["position"] as Vector2))

	_build_notebook_window()

	_home = Button.new()
	_home.name = "PhoneHomeButton"
	_home.text = "—"
	_home.position = HOME_RECT.position
	_home.size = HOME_RECT.size
	_home.focus_mode = Control.FOCUS_NONE
	_home.set_meta("flat_phone_button", true)
	_home.pressed.connect(_on_home_pressed)
	_face.add_child(_home)

	_cracks = GlassCracks.new()
	_cracks.name = "PhoneScreenCracks"
	_cracks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The glass lies over every page, even one that raises its own z; it stays inside the phone, below settings.
	_cracks.z_index = 100
	_cracks.size = FACE_SIZE
	_face.add_child(_cracks)

	_tab = EdgeTab.new()
	_tab.name = "PhoneEdgeTab"
	_tab.tooltip_text = "手机"
	_tab.focus_mode = Control.FOCUS_NONE
	_tab.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	# The walk paints a flat button for this meta; the tab covers it with its own drawing.
	_tab.set_meta("hud_icon", true)
	_tab.z_index = 43
	_tab.visible = false
	# A sibling of the phone, so the handle stays at the screen edge while the body slides.
	parent.add_child(_tab)
	_tab.pressed.connect(_on_tab_pressed)
	_tab.mouse_entered.connect(_hover_tab.bind(true))
	_tab.mouse_exited.connect(_hover_tab.bind(false))
	_paint()


## The play chrome decides whether the phone may appear at all (owned, not locked, nothing in front of it). While it
## may, the models decide the rest.
func set_shown(shown: bool) -> void:
	_shown = shown
	if _body == null or not is_instance_valid(_body):
		return
	_body.visible = shown
	_tab.visible = shown
	if shown:
		relayout()
		_watch.start()
	else:
		_watch.stop()


func is_shown() -> bool:
	return _shown


## Whether the phone is up (or on its way up).
func is_open() -> bool:
	return _open


## How far the phone has slid in: 0 away past the right edge, 1 up.
func slide_fraction() -> float:
	return _slide_fraction


## The app in front inside the screen, empty on the home.
func current_page() -> String:
	return "" if _page == NO_PAGE else _page


func get_body() -> Control:
	return _body


func get_tab() -> Button:
	return _tab


func get_screen() -> Control:
	return _screen


func get_launcher() -> Control:
	return _launcher


func get_home_button() -> Button:
	return _home


func get_app_icon(app_id: String) -> Button:
	return _icons.get(app_id) as Button


func get_app_window(app_id: String) -> Control:
	return _pages.get(app_id) as Control


func get_app_title(app_id: String) -> Label:
	return _notebook_title if app_id == "notebook" else null


func get_app_body(app_id: String) -> VBoxContainer:
	return _notebook_body if app_id == "notebook" else null


## Where a word flies while the notebook is not in front: the phone's home bar.
func home_point() -> Vector2:
	if _body == null or not is_instance_valid(_body):
		return Vector2.ZERO
	return _body.get_global_transform() * HOME_POINT


## Hands an app's page to the phone: it fills the screen and shows only while that app is in front.
func add_page(app_id: String, page: Control) -> void:
	if page == null:
		return
	# Inside the phone its own body is the shell; a second black phone frame around the page would double it.
	page.remove_meta("phone_shell")
	_fill_screen(page)
	_pages[app_id] = page
	page.visible = false
	_page = NO_PAGE
	_show_page()


## A window that lies over a page when its app opens it (the open social post); its app decides when it shows.
func add_overlay(overlay: Control) -> void:
	if overlay != null:
		_fill_screen(overlay)


## Lays the phone out again for the window size, for example after the window was resized.
func relayout(viewport_size: Vector2 = Vector2.ZERO) -> void:
	if _body == null or not is_instance_valid(_body):
		return
	if viewport_size == Vector2.ZERO:
		if not _body.is_inside_tree():
			return
		viewport_size = _body.get_viewport_rect().size
	_viewport_size = viewport_size
	_scale_factor = clampf(
		minf(
			(viewport_size.y - minf(VERTICAL_GAP, viewport_size.y * 0.15)) / FACE_SIZE.y,
			(viewport_size.x - minf(HORIZONTAL_GAP, viewport_size.x * 0.3)) / FACE_SIZE.x
		),
		0.001,
		1.0
	)
	_layout()


func _build_icon(app_id: String, label: String, at: Vector2) -> Button:
	var button := Button.new()
	button.name = "PhoneAppIcon%s" % app_id.capitalize()
	button.position = at
	button.size = ICON_SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.icon = _load_icon(app_id)
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	button.expand_icon = false
	button.text = label
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_font_size_override("font_size", _theme().ui_font_size(18))
	button.add_theme_color_override("icon_normal_color", Color.WHITE)
	button.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, ICON_LOCKED_ALPHA))
	# The walk paints it as a flat phone button: no face of its own, only the shared hover wash. A locked icon has no
	# face either (the walk leaves the disabled and focus looks alone).
	button.set_meta("flat_phone_button", true)
	for mode in ["disabled", "focus"]:
		button.add_theme_stylebox_override(mode, StyleBoxEmpty.new())
	button.disabled = true
	button.pressed.connect(_on_app_icon_pressed.bind(app_id))
	_icons[app_id] = button
	return button


## The icon from the project's import, or straight from the SVG when the project was not imported yet.
func _load_icon(app_id: String) -> Texture2D:
	var path := ICON_PATH % app_id
	if FileAccess.file_exists("%s.import" % path) and ResourceLoader.exists(path):
		var imported := load(path) as Texture2D
		if imported != null:
			return imported
	if not FileAccess.file_exists(path):
		return null
	var image := Image.new()
	if image.load_svg_from_buffer(FileAccess.get_file_as_bytes(path)) != OK:
		return null
	return ImageTexture.create_from_image(image)


## Inside the phone the notebook is a page with a title bar and a close, as on the old phone.
func _build_notebook_window() -> void:
	_notebook_window = _theme().panel() as PanelContainer
	_notebook_window.name = "NotebookAppWindow"
	_notebook_window.clip_contents = true
	_screen.add_child(_notebook_window)
	var app_box := VBoxContainer.new()
	app_box.add_theme_constant_override("separation", 8)
	_notebook_window.add_child(app_box)
	var title_bar := HBoxContainer.new()
	title_bar.name = "NotebookAppWindowTitleBar"
	title_bar.custom_minimum_size.y = 56
	title_bar.add_theme_constant_override("separation", 8)
	app_box.add_child(title_bar)
	_notebook_title = _theme().label(NOTEBOOK_TITLE, 21, _theme().theme_color("accent"))
	_notebook_title.name = "NotebookAppWindowHandle"
	_notebook_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_bar.add_child(_notebook_title)
	var close_button := Button.new()
	close_button.name = "NotebookAppWindowCloseButton"
	close_button.text = "X"
	close_button.set_meta("window_close_button", true)
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_on_notebook_close_pressed)
	title_bar.add_child(close_button)
	_notebook_body = VBoxContainer.new()
	_notebook_body.name = "NotebookAppBody"
	_notebook_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_notebook_body.add_theme_constant_override("separation", 8)
	app_box.add_child(_notebook_body)
	add_page("notebook", _notebook_window)


func _fill_screen(control: Control) -> void:
	if control.get_parent() != _screen:
		push_warning("%s is not on the phone's screen" % control.name)
	control.custom_minimum_size = Vector2.ZERO
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _layout() -> void:
	if _body == null or _viewport_size == Vector2.ZERO:
		return
	_body.size = FACE_SIZE
	_body.scale = Vector2.ONE * _scale_factor
	var away_x := _viewport_size.x + AWAY_GAP
	var up_x := _viewport_size.x - FACE_SIZE.x * _scale_factor - minf(EDGE_GAP, _viewport_size.x * 0.15)
	_body.position = Vector2(
		lerpf(away_x, up_x, _slide_fraction),
		(_viewport_size.y - FACE_SIZE.y * _scale_factor) * 0.5
	)
	var tab_size := Vector2(minf(TAB_MAX_SIZE.x, _viewport_size.x * 0.15), minf(TAB_MAX_SIZE.y, _viewport_size.y * 0.6))
	_tab.custom_minimum_size = Vector2.ZERO
	_tab.size = tab_size
	_tab.position = Vector2(
		_viewport_size.x - tab_size.x,
		clampf(_viewport_size.y * TAB_HEIGHT_RATIO - tab_size.y * 0.5, 0.0, maxf(0.0, _viewport_size.y - tab_size.y))
	)
	_tab.opened = _open
	_tab.queue_redraw()


func _set_slide(value: float) -> void:
	_slide_fraction = value
	_layout()


## The phone eases in or out from wherever it is, so a quick second press turns it around without a jump.
func _slide_to(target: float) -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
	if is_equal_approx(_slide_fraction, target) or not is_inside_tree():
		_set_slide(target)
		return
	_slide = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_slide.tween_method(_set_slide, _slide_fraction, target, SLIDE_SECONDS)


## The app in front fades in over the home; with the phone away or no app in front, the home shows.
func _show_page() -> void:
	if _launcher == null:
		return
	var page := _front if _open and _pages.has(_front) else ""
	_launcher.visible = page.is_empty()
	if page == _page:
		return
	_page = page
	if _page_motion != null and _page_motion.is_valid():
		_page_motion.kill()
	_page_motion = null
	for app_id in _pages:
		var window := _pages[app_id] as Control
		if window == null or not is_instance_valid(window):
			continue
		window.visible = app_id == page
		window.modulate = Color.WHITE
	if page.is_empty() or not is_inside_tree():
		return
	var current := _pages[page] as Control
	current.modulate.a = 0.0
	_page_motion = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_page_motion.tween_property(current, "modulate:a", 1.0, PAGE_FADE_SECONDS)


## Glass, chevron and locked names follow the active palette.
func _paint() -> void:
	# The host may show the chrome before it binds the theme; the next walk paints it.
	if not ServiceRegistryScript.has(ServiceKeysScript.UI_THEME):
		return
	var theme := _theme()
	if theme == null or _face == null:
		return
	_face.glass = theme.theme_color("surface")
	_face.queue_redraw()
	_tab.paper = theme.theme_color("surface")
	_tab.queue_redraw()
	for app_id in _icons:
		(_icons[app_id] as Button).add_theme_color_override("font_disabled_color", theme.theme_color("pending"))


func _on_view_state(value: Variant) -> void:
	_open = str(value) == "phone_down"
	_slide_to(1.0 if _open else 0.0)
	_layout()
	_show_page()


func _on_active_app_window(value: Variant) -> void:
	_front = str(value)
	_show_page()


## A locked app's icon is disabled; the map is never in the phone's apps during the demo, so it stays locked.
func _on_unlocked_apps(value: Variant) -> void:
	_unlocked = (value as Array).duplicate() if value is Array else []
	for app_id in _icons:
		var icon := _icons[app_id] as Button
		var locked := not _unlocked.has(app_id)
		icon.disabled = locked
		icon.tooltip_text = "尚未解锁" if locked else ""


func _on_pollution(_value: Variant) -> void:
	_paint()


func _hover_tab(hovered: bool) -> void:
	if _tab == null or not _tab.is_inside_tree():
		return
	var tween := _tab.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_tab, "modulate", Color(1.18, 1.12, 1.08) if hovered else Color.WHITE, 0.18)


func _on_tab_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.PHONE_TOGGLE_REQUESTED)


func _on_home_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.PHONE_HOME_REQUESTED)


func _on_app_icon_pressed(app_id: String) -> void:
	if not _unlocked.has(app_id):
		return
	GameEventBus.raise(UiIntentsScript.APP_ICON_PRESSED, {UiIntentsScript.KEY_APP_ID: app_id})


func _on_notebook_close_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.APP_WINDOW_CLOSE_REQUESTED, {UiIntentsScript.KEY_APP_ID: "notebook"})


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
