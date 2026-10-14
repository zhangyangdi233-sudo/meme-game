extends Node
## Temporarily hosts the existing app Controls on the authored CRT. Game state,
## app instances and their signals remain owned by the main scene.

const TERMINAL = preload("res://scripts/world/chapter_terminal.gd")
const APP_IDS := ["social", "notebook"]
const APP_LABELS := {"social": "信号瀑布", "notebook": "笔记本"}
const DISPLAY_SIZE := Vector2(1600, 1200)
const HIDDEN_FIELDS := ["_phone_panel", "_phone_tab", "_phone_content", "_phone_down_backdrop_image", "_hand_phone_image", "_meme_bank_window"]

var _host: Node
var _world: Node
var _terminal: Node3D
var _content: Control
var _active := false
var _selected_app := "social"
var _saved_controls: Array[Dictionary] = []
var _hidden_controls: Array[Dictionary] = []
var _tab_buttons: Dictionary = {}
var _input_depth := 0
var _retired_terminals: Array[Node] = []
var _camera_tween: Tween
var _camera_original := Transform3D.IDENTITY
var _camera_original_fov := 58.0
var _camera_saved := false
var _camera_returning := false


func _process(_delta: float) -> void:
	if _active:
		# Container minimum sizes settle after the host's render pass. Reapply
		# bounded app rectangles once they shrink so action bars remain on-screen.
		refresh_layout()


func begin(host: Node, world: Node, vhs_enabled: bool) -> bool:
	if not is_instance_valid(host) or not is_instance_valid(world) or not world.has_method("get_screen_mesh") or not world.has_method("get_video_screen"):
		return false
	if _active and _host == host and _world == world:
		_terminal.set_vhs_enabled(vhs_enabled)
		refresh_layout()
		return true
	end()
	var ui_root := host.get("_ui_root") as Control
	var controls := _collect_controls(host)
	var screen := world.get_screen_mesh() as MeshInstance3D
	if ui_root == null or controls.size() != 4 or screen == null:
		return false
	_terminal = TERMINAL.new()
	_terminal.name = "ChapterTerminal"
	add_child(_terminal)
	if not _terminal.bind_screen(screen, 0, world.get_video_screen()):
		remove_child(_terminal)
		_terminal.queue_free()
		_terminal = null
		return false
	_host = host
	_world = world
	_content = _terminal.get_content_root()
	_content.theme = ui_root.theme.duplicate(true) as Theme if ui_root.theme != null else Theme.new()
	_content.theme.default_font_size = 36
	var reading_font := FontVariation.new()
	reading_font.base_font = _content.theme.default_font if _content.theme.default_font != null else ThemeDB.fallback_font
	reading_font.spacing_glyph = 1
	_content.theme.default_font = reading_font
	_content.theme.set_constant("line_spacing", "Label", 6)
	_content.theme.set_constant("line_separation", "RichTextLabel", 6)
	_content.clip_contents = true
	for control in controls:
		_saved_controls.append(_snapshot(control))
	for field in HIDDEN_FIELDS:
		var control := host.get(field) as Control
		if is_instance_valid(control):
			_hidden_controls.append({"node": control, "visible": control.visible})
	_stop_notebook_squash()
	_build_shell()
	_selected_app = "social"
	_active = true
	_terminal.set_vhs_enabled(vhs_enabled)
	_terminal.set_active(true)
	refresh_layout()
	return true


func end() -> void:
	_stop_camera_motion()
	if _saved_controls.is_empty() and _terminal == null:
		return
	_active = false
	if is_instance_valid(_terminal):
		_terminal.set_active(false)
	_stop_notebook_squash()
	if is_instance_valid(_host):
		var flights := _host.get("_pickup_flight_layer") as Control
		if is_instance_valid(flights) and flights.has_method("finish_all_immediately"):
			flights.finish_all_immediately()
	# Restore the original Controls before releasing the viewport that hosts them.
	for saved in _saved_controls:
		var control: Control = saved.node
		var parent: Node = saved.parent
		if not is_instance_valid(control) or not is_instance_valid(parent):
			continue
		if control.get_parent() != parent:
			control.reparent(parent, false)
		_restore_layout(control, saved)
	var ordered := _saved_controls.duplicate()
	ordered.sort_custom(func(left: Dictionary, right: Dictionary): return int(left.index) < int(right.index))
	for saved in ordered:
		var control: Control = saved.node
		var parent: Node = saved.parent
		if is_instance_valid(control) and is_instance_valid(parent) and control.get_parent() == parent:
			parent.move_child(control, mini(int(saved.index), parent.get_child_count() - 1))
	for saved in _hidden_controls:
		if is_instance_valid(saved.node):
			saved.node.visible = saved.visible
	_saved_controls.clear()
	_hidden_controls.clear()
	_tab_buttons.clear()
	_content = null
	if is_instance_valid(_terminal):
		_retired_terminals.append(_terminal)
	_terminal = null
	_host = null
	_world = null
	_flush_retired_terminals()


func is_active() -> bool:
	return _active


func is_camera_moving() -> bool:
	return _camera_tween != null and _camera_tween.is_valid()


func animate_camera_to_screen(camera: Camera3D) -> void:
	if not is_instance_valid(camera) or not is_instance_valid(_world):
		return
	_stop_camera_motion()
	_camera_original = camera.global_transform
	_camera_original_fov = camera.fov
	_camera_saved = true
	_camera_returning = false
	var destination: Vector3 = _world.terminal_camera_position()
	var direction: Vector3 = _world.terminal_camera_target() - destination
	var pose := Transform3D(Basis.looking_at(direction, Vector3.UP), destination)
	_tween_camera(camera, pose, 58.0, 0.8)


func animate_camera_back(camera: Camera3D, callback: Callable) -> bool:
	if _camera_returning or not _camera_saved or not is_instance_valid(camera):
		return false
	_stop_camera_motion()
	_camera_returning = true
	if is_instance_valid(_terminal):
		_terminal.set_active(false)
	_tween_camera(camera, _camera_original, _camera_original_fov, 0.65)
	_camera_tween.tween_callback(callback)
	return true


func set_camera_paused(paused: bool) -> void:
	if is_camera_moving():
		if paused:
			_camera_tween.pause()
		else:
			_camera_tween.play()


func _tween_camera(camera: Camera3D, destination: Transform3D, fov: float, duration: float) -> void:
	var start := camera.global_transform
	var start_fov := camera.fov
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_method(func(weight: float):
		if is_instance_valid(camera):
			camera.global_transform = start.interpolate_with(destination, weight)
			camera.fov = lerpf(start_fov, fov, weight)
	, 0.0, 1.0, duration)


func _stop_camera_motion() -> void:
	if is_camera_moving():
		_camera_tween.kill()
	_camera_tween = null


func select_app(app_id: String) -> void:
	if not _active or app_id not in APP_IDS:
		return
	_selected_app = app_id
	refresh_layout()


func refresh_layout() -> void:
	if not _active or not is_instance_valid(_host) or not is_instance_valid(_content):
		return
	for saved in _saved_controls:
		var control: Control = saved.node
		if is_instance_valid(control) and control.get_parent() != _content:
			control.reparent(_content, false)
	var apps: Dictionary = _host.get("_app_windows")
	_place(apps.social, Rect2(16, 90, 776, 1070), true, 10)
	_place(apps.notebook, Rect2(808, 90, 776, 1070), true, 10)
	var detail_open := _selected_app == "social" and bool(_host.get("_social_detail_open"))
	_place(_host.get("_social_detail_window"), Rect2(16, 90, 776, 1070), detail_open, 20)
	_place(_host.get("_pickup_flight_layer"), Rect2(Vector2.ZERO, DISPLAY_SIZE), true, 100)
	for saved in _hidden_controls:
		if is_instance_valid(saved.node):
			saved.node.hide()
	for app_id in _tab_buttons:
		_tab_buttons[app_id].set_pressed_no_signal(app_id == _selected_app)


func route_input(event: InputEvent, camera: Camera3D) -> bool:
	if not _active or not is_instance_valid(_terminal) or is_camera_moving() or _camera_returning:
		return false
	_input_depth += 1
	var handled: bool = _terminal.route_input(event, camera)
	_input_depth -= 1
	_flush_retired_terminals()
	return handled


func _flush_retired_terminals() -> void:
	# A screen Button may end the session synchronously from push_input(). Its
	# viewport must stay in the tree until that input dispatch has returned.
	if _input_depth > 0:
		return
	for terminal in _retired_terminals:
		if is_instance_valid(terminal):
			remove_child(terminal)
			terminal.queue_free()
	_retired_terminals.clear()


func get_terminal() -> Node:
	return _terminal


func get_pointer_position() -> Vector2:
	return _terminal.get_pointer_position() if is_instance_valid(_terminal) else Vector2.ZERO


func _collect_controls(host: Node) -> Array[Control]:
	var result: Array[Control] = []
	var apps: Variant = host.get("_app_windows")
	if not apps is Dictionary:
		return result
	for app_id in APP_IDS:
		var control := apps.get(app_id) as Control
		if not is_instance_valid(control) or control.get_parent() == null:
			return []
		result.append(control)
	for field in ["_social_detail_window", "_pickup_flight_layer"]:
		var control := host.get(field) as Control
		if not is_instance_valid(control) or control.get_parent() == null:
			return []
		result.append(control)
	return result


func _snapshot(control: Control) -> Dictionary:
	return {
		"node": control, "parent": control.get_parent(), "index": control.get_index(),
		"anchors": [control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom],
		"offsets": [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom],
		"position": control.position, "size": control.size,
		"visible": control.visible, "z_index": control.z_index,
		"scale": control.scale, "rotation": control.rotation, "pivot_offset": control.pivot_offset,
		"clip_contents": control.clip_contents, "minimum_size": control.custom_minimum_size,
		"grow_horizontal": control.grow_horizontal, "grow_vertical": control.grow_vertical,
	}


func _restore_layout(control: Control, saved: Dictionary) -> void:
	control.custom_minimum_size = saved.minimum_size
	control.grow_horizontal = saved.grow_horizontal
	control.grow_vertical = saved.grow_vertical
	for side in 4:
		control.set_anchor(side, saved.anchors[side], false, true)
	for side in 4:
		control.set_offset(side, saved.offsets[side])
	control.scale = saved.scale
	control.rotation = saved.rotation
	control.pivot_offset = saved.pivot_offset
	control.clip_contents = saved.clip_contents
	control.z_index = saved.z_index
	control.visible = saved.visible


func _place(control: Control, rect: Rect2, showing: bool, z_index: int) -> void:
	control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	control.grow_horizontal = Control.GROW_DIRECTION_END
	control.grow_vertical = Control.GROW_DIRECTION_END
	control.custom_minimum_size = Vector2.ZERO
	control.position = rect.position
	control.size = rect.size
	control.scale = Vector2.ONE
	control.rotation = 0.0
	control.pivot_offset = Vector2.ZERO
	control.clip_contents = true
	control.z_index = z_index
	control.visible = showing


func _build_shell() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "TerminalBackdrop"
	backdrop.color = Color("101812")
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.size = DISPLAY_SIZE
	backdrop.z_index = -10
	_content.add_child(backdrop)
	var toolbar := HBoxContainer.new()
	toolbar.name = "TerminalToolbar"
	toolbar.position = Vector2(16, 16)
	toolbar.size = Vector2(1568, 58)
	toolbar.z_index = 110
	toolbar.add_theme_constant_override("separation", 16)
	_content.add_child(toolbar)
	var title := Label.new()
	title.name = "TerminalTitle"
	title.text = "CRT 教学端（开发）"
	title.set_meta("on_dark", true)
	title.custom_minimum_size.x = 370
	title.add_theme_font_size_override("font_size", 28)
	toolbar.add_child(title)
	for app_id in APP_IDS:
		var button := Button.new()
		button.name = "TerminalApp%s" % app_id.to_pascal_case()
		button.text = APP_LABELS[app_id]
		button.toggle_mode = true
		button.custom_minimum_size.x = 225
		button.add_theme_font_size_override("font_size", 26)
		button.pressed.connect(_on_app_pressed.bind(app_id))
		toolbar.add_child(button)
		_tab_buttons[app_id] = button
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toolbar.add_child(spacer)
	var exit_button := Button.new()
	exit_button.name = "TerminalExit"
	exit_button.text = "退出屏幕"
	exit_button.custom_minimum_size.x = 190
	exit_button.add_theme_font_size_override("font_size", 26)
	exit_button.pressed.connect(_on_exit_pressed)
	toolbar.add_child(exit_button)


func _on_app_pressed(app_id: String) -> void:
	select_app(app_id)
	if is_instance_valid(_host) and _host.has_method("_on_chapter_terminal_app_pressed"):
		_host._on_chapter_terminal_app_pressed(app_id)


func _on_exit_pressed() -> void:
	if is_instance_valid(_host) and _host.has_method("_end_chapter_terminal"):
		_host._end_chapter_terminal()
	else:
		end()


func _stop_notebook_squash() -> void:
	if not is_instance_valid(_host):
		return
	var tween := _host.get("_notebook_squash_tween") as Tween
	if is_instance_valid(tween) and tween.is_valid():
		tween.kill()
	_host.set("_notebook_squash_tween", null)


func _exit_tree() -> void:
	end()
