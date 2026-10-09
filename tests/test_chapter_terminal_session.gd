extends SceneTree

const SESSION_PATH := "res://scripts/ui/chapter_terminal_session.gd"
const Video = preload("res://scripts/world/chapter_video_screen.gd")

class SyntheticHost:
	extends Node3D
	var _ui_root: Control
	var _app_windows: Dictionary = {}
	var _social_detail_window: Control
	var _pickup_flight_layer: Control
	var _phone_panel: Control
	var _phone_tab: Control
	var _phone_content: Control
	var _phone_down_backdrop_image: Control
	var _hand_phone_image: Control
	var _meme_bank_window: Control
	var _notebook_squash_tween: Tween
	var _social_detail_open := false
	var game := {"view_state": "npc_up", "shared_words": ["灯"]}
	var app_calls: Array[String] = []
	var end_calls := 0
	var end_session: Node
	func _on_chapter_terminal_app_pressed(app_id: String) -> void:
		app_calls.append(app_id)
	func _end_chapter_terminal() -> void:
		end_calls += 1
		if is_instance_valid(end_session):
			end_session.end()

class SyntheticWorld:
	extends Node3D
	var screen: MeshInstance3D
	var video: Node
	func get_screen_mesh() -> MeshInstance3D:
		return screen
	func get_video_screen() -> Node:
		return video

var failures: Array[String] = []
var checks := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(960, 720)
	_check(FileAccess.file_exists(SESSION_PATH), "temporary CRT app session must exist")
	if FileAccess.file_exists(SESSION_PATH):
		var script: Script = load(SESSION_PATH)
		await _test_session(script)
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter terminal session tests passed (%d checks; shared Control instances)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_session(script: Script) -> void:
	var fixture := _fixture()
	var host: SyntheticHost = fixture.host
	var world: SyntheticWorld = fixture.world
	var session = script.new()
	host.add_child(session)
	var original: Array[Dictionary] = []
	var moved: Array[Control] = []
	for app_id in ["social", "notebook", "babel"]:
		moved.append(host._app_windows[app_id])
	moved.append(host._social_detail_window)
	moved.append(host._pickup_flight_layer)
	for control in moved:
		original.append(_snapshot(control))
	var base_material: Material = world.screen.get_surface_override_material(0)
	var before_tween: Tween = host.create_tween()
	before_tween.tween_interval(100)
	host._notebook_squash_tween = before_tween
	_check(session.begin(host, world, false), "valid world starts CRT shared-app session")
	_check(session.is_active(), "session reports active after binding")
	var terminal: Node = session.get_terminal()
	var content: Control = terminal.get_content_root()
	_check(content.theme != host._ui_root.theme and content.theme.default_font_size == 36, "CRT uses its own enlarged 36px default font theme")
	_check(host._ui_root.theme.default_font_size == 18, "CRT theme sizing does not modify the original phone theme")
	var reading_probe := Label.new()
	reading_probe.text = "拾到的字\n组成句子"
	host._app_windows.notebook.add_child(reading_probe)
	var rich_probe := RichTextLabel.new()
	rich_probe.text = "拾到的字\n组成句子"
	host._app_windows.notebook.add_child(rich_probe)
	_check(reading_probe.get_theme_font_size("font_size") == 36 and rich_probe.get_theme_font_size("normal_font_size") == 36, "new plain and rich notebook text inherit the enlarged screen type")
	_check(reading_probe.get_theme_font("font").get_spacing(TextServer.SPACING_GLYPH) == 1, "CRT text keeps one pixel of additional character separation")
	_check(reading_probe.get_theme_constant("line_spacing") == 6 and rich_probe.get_theme_constant("line_separation") == 6, "plain and rich multiline text share readable six-pixel line gaps")
	_check(host._ui_root.theme.get_constant("line_spacing", "Label") == 2, "screen line spacing never mutates the phone theme")
	var terminal_title := content.find_child("TerminalTitle", true, false) as Label
	_check(terminal_title != null and bool(terminal_title.get_meta("on_dark", false)), "terminal title requests readable foreground under main UI theming")
	_check(terminal.get_parent() == session, "session owns the temporary terminal component")
	_check(terminal.get_display_viewport().size == Vector2i(1600, 1200), "app viewport keeps CRT 4:3 content resolution")
	_check(terminal.is_active() and not terminal.is_vhs_enabled(), "session applies input and VHS preferences")
	_check(not before_tween.is_valid(), "moving applications stops the notebook squash tween")
	for index in moved.size():
		_check(moved[index].get_instance_id() == original[index].instance_id and moved[index].get_parent() == content, "same app/detail/flight Control instance moves into screen viewport")
	_check(host.game.view_state == "npc_up" and host.game.shared_words == ["灯"], "session never copies game state or lowers the phone")
	_check(host._app_windows.social.visible and host._app_windows.notebook.visible and not host._app_windows.babel.visible, "default social view shows collection beside notebook")
	_check(not host._social_detail_window.visible, "closed social detail stays hidden")
	_check(_left(host._app_windows.social) and _right(host._app_windows.notebook), "collection and composition use bounded left/right columns")
	_check(host._pickup_flight_layer.visible and host._pickup_flight_layer.size == Vector2(1600, 1200), "existing pickup flights share the screen coordinate space")
	_check(not host._phone_panel.visible and not host._hand_phone_image.visible and not host._meme_bank_window.visible, "phone art and bank stay outside CRT content and hidden")
	_check(host._meme_bank_window.get_parent() == host._ui_root, "meme bank is hidden without migrating its window")
	await _test_delayed_minimum_size(host, session)

	# Simulate the original phone visibility/layout pass running after a click.
	host._app_windows.social.hide()
	host._app_windows.notebook.position = Vector2(-900, -800)
	host._app_windows.notebook.size = Vector2(50, 40)
	host._app_windows.babel.reparent(host._ui_root, false)
	host._phone_panel.show()
	host._meme_bank_window.show()
	host._social_detail_open = true
	session.refresh_layout()
	_check(host._app_windows.babel.get_parent() == content and not host._app_windows.babel.visible, "refresh repairs parent and unwanted app visibility")
	_check(_left(host._app_windows.social) and _right(host._app_windows.notebook), "refresh repairs legacy responsive window positions")
	_check(host._social_detail_window.visible and _left(host._social_detail_window), "social detail opens only over the social region")
	_check(not host._phone_panel.visible and not host._meme_bank_window.visible, "refresh suppresses legacy phone UI reappearance")

	var notebook_tab := content.find_child("TerminalAppNotebook", true, false) as Button
	var babel_tab := content.find_child("TerminalAppBabel", true, false) as Button
	var exit_button := content.find_child("TerminalExit", true, false) as Button
	_check(notebook_tab != null and babel_tab != null and exit_button != null, "three-app toolbar and explicit exit exist inside the screen")
	if notebook_tab != null:
		notebook_tab.pressed.emit()
		_check(host.app_calls == ["notebook"] and notebook_tab.button_pressed, "tab selects app and invokes host callback exactly once")
	if babel_tab != null:
		babel_tab.pressed.emit()
		_check(host.app_calls == ["notebook", "babel"], "Babel tab uses same host callback")
	_check(host._app_windows.babel.visible and not host._app_windows.social.visible and not host._app_windows.notebook.visible and not host._social_detail_window.visible, "Babel fills the terminal and hides social detail")
	_check(host._app_windows.babel.get_rect().end.x <= 1600 and host._app_windows.babel.size.x >= 1500, "Babel layout uses full bounded content width")
	session.select_app("missing_app")
	_check(host._app_windows.babel.visible, "unknown app selection cannot alter current session")
	session.select_app("social")
	_check(host._app_windows.social.visible and host._app_windows.notebook.visible, "select_app restores two-column workflow without invoking callbacks")
	_check(host.app_calls.size() == 2, "programmatic app selection never recurses into host callbacks")
	if exit_button != null:
		exit_button.pressed.emit()
		_check(host.end_calls == 1, "screen exit button delegates to host camera/input cleanup")

	await process_frame
	await process_frame
	var camera: Camera3D = fixture.camera
	var position := camera.unproject_position(world.screen.to_global(Vector3(0.1, 0.0, 0.0)))
	var motion := InputEventMouseMotion.new()
	motion.position = position
	_check(session.route_input(motion, camera), "session routes screen pointer to terminal component")
	_check(session.get_pointer_position().distance_to(Vector2(960, 600)) < 0.1, "pickup pointer uses mapped 1600x1200 UV coordinates")
	var active_material: Material = world.screen.get_surface_override_material(0)
	_check(active_material != base_material, "temporary display holds the screen material lease")
	session.end()
	_check(not session.is_active() and session.get_terminal() == null, "end clears active state and temporary component")
	_check(reading_probe.get_theme_font_size("font_size") == 18 and reading_probe.get_theme_constant("line_spacing") == 2, "same notebook text restores phone typography after the screen session ends")
	_check(not session.route_input(motion, camera), "ended session stops forwarding GUI input")
	_check(world.screen.get_surface_override_material(0) == base_material, "end restores original video/standby screen material")
	for index in moved.size():
		var after := _snapshot(moved[index])
		_check(after == original[index], "end restores original instance/parent/order/anchors/offsets/visibility/z/scale: %s\nBefore: %s\nAfter: %s" % [moved[index].name, original[index], after])
	_check(host._phone_panel.visible and host._hand_phone_image.visible and host._meme_bank_window.visible, "end restores pre-session phone visibility")
	_check(host.game.view_state == "npc_up", "end does not change world view state")
	session.end()
	_check(session.begin(host, world, true), "session can be reopened without duplicate controls")
	_check(session.get_terminal().is_vhs_enabled(), "reopen applies current VHS setting")
	host.end_session = session
	await process_frame
	await process_frame
	var live_exit := session.get_terminal().get_content_root().find_child("TerminalExit", true, false) as Button
	var exit_uv: Vector2 = live_exit.get_global_rect().get_center() / Vector2(1600, 1200)
	var exit_position := camera.unproject_position(world.screen.to_global(Vector3(exit_uv.x - 0.5, 0.5 - exit_uv.y, 0)))
	var exit_motion := InputEventMouseMotion.new()
	exit_motion.position = exit_position
	session.route_input(exit_motion, camera)
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = exit_position
		click.pressed = pressed
		session.route_input(click, camera)
	_check(not session.is_active() and host.end_calls == 2, "real CRT exit click can end session inside the routed button callback")
	_check(host._app_windows.social.get_parent() == host._ui_root and world.screen.get_surface_override_material(0) == base_material, "callback teardown restores UI before releasing screen lease")
	await process_frame
	_check(session.get_child_count() == 0, "deferred terminal cleanup leaves no viewport children behind")
	var invalid_world := SyntheticWorld.new()
	root.add_child(invalid_world)
	_check(not session.begin(host, invalid_world, true), "missing screen fails before any control moves")
	_check(not session.is_active() and host._app_windows.social.get_parent() == host._ui_root, "failed begin leaves all original controls intact")
	invalid_world.free()
	host.free()
	await process_frame


func _test_delayed_minimum_size(host: SyntheticHost, session: Node) -> void:
	var notebook: Control = host._app_windows.notebook
	var content := Control.new()
	content.custom_minimum_size = Vector2(100, 1189)
	notebook.add_child(content)
	for frame in 3:
		await process_frame
	_check(notebook.size.y > 1070, "asynchronous container minimum can temporarily enlarge the notebook")
	# A render-time refresh sees the temporary high minimum and clamps its
	# requested rectangle to that size before the next container sort settles.
	session.refresh_layout()
	content.custom_minimum_size.y = 271
	for frame in 3:
		await process_frame
	_check(is_equal_approx(notebook.size.y, 1070) and notebook.get_global_rect().end.y <= 1160, "notebook returns to its 1070 target after asynchronous minimum decreases")
	content.free()


func _fixture() -> Dictionary:
	var host := SyntheticHost.new()
	root.add_child(host)
	host._ui_root = Control.new()
	host._ui_root.theme = Theme.new()
	host._ui_root.theme.default_font_size = 18
	host._ui_root.theme.set_constant("line_spacing", "Label", 2)
	host._ui_root.size = Vector2(960, 720)
	host.add_child(host._ui_root)
	for app_id in ["social", "notebook", "babel"]:
		var control := PanelContainer.new()
		control.name = app_id.to_pascal_case()
		host._ui_root.add_child(control)
		control.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		control.position = Vector2(33, 44)
		control.size = Vector2(430, 500)
		control.z_index = 12 + host._app_windows.size()
		control.visible = app_id == "social"
		control.scale = Vector2(0.95, 1.0)
		host._app_windows[app_id] = control
	host._social_detail_window = _control(host._ui_root, "SocialDetail", false)
	host._pickup_flight_layer = _control(host._ui_root, "PickupFlights", true)
	host._pickup_flight_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host._phone_panel = _control(host._ui_root, "PhonePanel", true)
	host._phone_tab = _control(host._ui_root, "PhoneTab", false)
	host._phone_content = _control(host._phone_panel, "PhoneContent", true)
	host._phone_down_backdrop_image = _control(host._ui_root, "PhoneBackdrop", true)
	host._hand_phone_image = _control(host._ui_root, "PhoneHand", true)
	host._meme_bank_window = _control(host._ui_root, "MemeBank", true)
	var world := SyntheticWorld.new()
	host.add_child(world)
	world.screen = MeshInstance3D.new()
	world.screen.mesh = QuadMesh.new()
	world.add_child(world.screen)
	world.video = Video.new()
	world.add_child(world.video)
	world.video.bind_screen(world.screen)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 0, 1.5)
	camera.current = true
	return {"host": host, "world": world, "camera": camera}


func _control(parent: Node, node_name: String, showing: bool) -> Control:
	var control := Control.new()
	control.name = node_name
	parent.add_child(control)
	control.position = Vector2(24, 35)
	control.size = Vector2(470, 430)
	control.visible = showing
	return control


func _snapshot(control: Control) -> Dictionary:
	return {"instance_id": control.get_instance_id(), "parent": control.get_parent(), "index": control.get_index(), "anchors": [control.anchor_left, control.anchor_top, control.anchor_right, control.anchor_bottom], "offsets": [control.offset_left, control.offset_top, control.offset_right, control.offset_bottom], "position": control.position, "size": control.size, "visible": control.visible, "z": control.z_index, "scale": control.scale}


func _left(control: Control) -> bool:
	return control.visible and control.position.is_equal_approx(Vector2(16, 90)) and control.size.is_equal_approx(Vector2(776, 1070))


func _right(control: Control) -> bool:
	return control.visible and control.position.is_equal_approx(Vector2(808, 90)) and control.size.is_equal_approx(Vector2(776, 1070))


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
