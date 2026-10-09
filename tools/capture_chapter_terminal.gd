extends SceneTree
## Real-renderer evidence for the actual CRT/session/phone UI. Run only after the
## main bridge is ready, with a hidden OS process and an isolated APPDATA profile.

const OUTPUT := "D:/aphasia/outputs/basement_integration_audit"
const State := preload("res://scripts/meme_game_state.gd")
const APP_IDS := ["social", "notebook", "babel"]

class CaptureReceiver:
	extends RefCounted
	var camera_source := "computer"
	func start(_launch_sidecar: bool = true) -> bool:
		return true
	func stop() -> void:
		pass
	func poll() -> void:
		pass
	func get_status() -> String:
		return "等待手部进入画面"

var viewport: SubViewport
var main
var captures: Array[Dictionary] = []
var checks: Array[Dictionary] = []
var failures: Array[String] = []
var report: Dictionary = {}
var frozen_controls: Array[Dictionary] = []
var frozen_tweens: Array[Tween] = []


func _init() -> void:
	root.visible = false
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("CRT capture requires a real renderer; headless cannot verify pixels")
		quit(2)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._hand_tracking_receiver = CaptureReceiver.new()
	main._save_path = OUTPUT.path_join("capture_terminal_save.dat")
	viewport.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	main._vhs_enabled = false
	if not main.has_method("_begin_chapter_terminal") or not main.has_method("_on_crt_vhs_toggled"):
		_check(false, "main CRT integration must be ready before this capture is run")
		await _finish()
		return
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.notify_chapter1("entrance_threshold_crossed", {"round_token": state.chapter1_progress.transition_serial})
	state.view_state = "npc_up"
	state.active_app_window = ""
	main._begin_game_session(state, {}, false)
	main._set_reality_mouse_look(false)
	_check(main._chapter_world_ready, "actual imported basement binds successfully")
	if not main._chapter_world_ready:
		await _finish()
		return
	main.set_view_state("phone_down")
	await _settle(20)
	report.phone_before = _phone_permissions()
	_check(_permissions_match(report.phone_before, []), "all three phone apps are locked before first NPC delivery")
	await _capture("chapter1_terminal_01_phone_locked.png")
	main.set_view_state("npc_up")
	if not await _interact("chapter1_terminal"):
		await _finish()
		return
	_check(main._chapter_terminal_active(), "real nearby F key opens the physical CRT session")
	if not main._chapter_terminal_active():
		await _finish()
		return
	var session: Node = main._chapter_terminal_session
	var terminal: Node = session.get_terminal()
	var screen: MeshInstance3D = main._reality_floor.get_screen_mesh()
	report.screen_mesh = str(screen.name)
	report.gui_size = str(terminal.get_display_viewport().size)
	_check(main._app_windows.social.get_parent() == terminal.get_content_root() and main._app_windows.notebook.get_parent() == terminal.get_content_root(), "existing social and notebook Controls are inside the real CRT viewport")
	_check(main.game.chapter1_progress.unlocked_app_ids.is_empty(), "CRT access itself does not unlock phone apps")
	await _click_terminal_control("TerminalAppNotebook")
	await _click_terminal_control("TerminalAppSocial")
	_check(main._app_windows.social.is_visible_in_tree() and main._app_windows.notebook.is_visible_in_tree(), "actual on-screen toolbar keeps collection and notebook visible together")
	var toggle := main.find_child("SettingsCRTVHSToggle", true, false) as CheckButton
	_check(toggle != null, "real settings expose the local CRT VHS switch")
	if toggle == null:
		await _finish()
		return
	toggle.toggled.emit(true)
	await _settle(30)
	# Freeze camera, app processing, tweens and shader TIME for a deterministic
	# material-only comparison. Input dispatch and GPU rendering remain active.
	main._set_reality_mouse_look(false)
	main.set_process(false)
	main.set_physics_process(false)
	_freeze_processing(terminal.get_content_root())
	for tween in get_processed_tweens():
		if tween.is_running():
			frozen_tweens.append(tween)
			tween.pause()
	if RenderingServer.has_method("set_shader_time_scale"):
		RenderingServer.call("set_shader_time_scale", 0.0)
	var region := _projected_bounds(screen)
	report.screen_region = str(region)
	report.camera_transform = str(main._camera.global_transform)
	var vhs_on := await _capture("chapter1_terminal_02_apps_vhs_on.png")
	_check(terminal.is_vhs_enabled(), "actual settings signal enables CRT-only VHS")
	toggle.toggled.emit(false)
	var vhs_off := await _capture("chapter1_terminal_03_apps_vhs_off.png")
	_check(not terminal.is_vhs_enabled() and not main._vhs_enabled, "CRT switch disables its shader without enabling full-screen VHS")
	report.vhs_difference = _screen_difference(vhs_on, vhs_off, region)
	_check(int(report.vhs_difference.inside_changed_samples) > 40, "VHS switch visibly changes pixels on the authored CRT")
	_check(int(report.vhs_difference.outside_changed_samples) <= 20, "VHS switch leaves sampled world pixels unchanged outside a 14 px screen-edge exclusion")
	_restore_processing()
	# The card, notebook tile and submit button all use actual screen ray input.
	# For text links, prefer a real hover/click; a clearly recorded meta_clicked
	# fallback is allowed when the engine cannot identify a hover target.
	await _click_terminal_control("SocialPostPoster0")
	_check(main._social_detail_open and main._social_detail_post_index == 0, "UV click on the first original post opens its real detail")
	var picked_unit := await _pick_detail_word()
	_check(not picked_unit.is_empty() and main.game.is_social_char_collected(picked_unit, "zh"), "original detail text pickup reaches the shared notebook vocabulary")
	if is_instance_valid(main._pickup_flight_layer):
		main._pickup_flight_layer.finish_all_immediately()
	await _settle(4)
	await _click_terminal_control("TerminalAppNotebook")
	_check(main._social_screen == "publish", "notebook toolbar opens the original sentence preview beside the word canvas")
	await _tap_notebook_word(picked_unit)
	_check(picked_unit in main.game.get_free_sentence_units(), "real notebook word-tile UV tap places the collected word in the sentence")
	if is_instance_valid(main._pickup_flight_layer):
		main._pickup_flight_layer.finish_all_immediately()
	await _settle(4)
	var craft := terminal.get_content_root().find_child("NotebookCraftButton", true, false) as Button
	var publish := terminal.get_content_root().find_child("SocialPublishButton", true, false) as Button
	_check(craft != null and craft.is_visible_in_tree() and not craft.disabled, "original notebook submit button is visible and enabled for the composed sentence")
	_check(craft != null and Rect2(Vector2.ZERO, Vector2(1600, 1200)).encloses(craft.get_global_rect()), "notebook submission button lies completely within the actual CRT's clickable pixels")
	_check(publish != null and publish.is_visible_in_tree(), "original publishing action is visible beside the notebook")
	report.composition = {"picked_unit": picked_unit, "draft_before_submission": main.game.get_free_sentence_units().duplicate(), "social_page": main._social_screen, "craft_font_size": craft.get_theme_font_size("font_size") if craft != null else 0, "craft_rect": str(craft.get_global_rect()) if craft != null else "", "publish_font_size": publish.get_theme_font_size("font_size") if publish != null else 0, "publish_rect": str(publish.get_global_rect()) if publish != null else ""}
	_check(int(report.composition.craft_font_size) >= 27 and int(report.composition.publish_font_size) >= 27, "both real submission controls use the enlarged CRT type size")
	await _capture("chapter1_terminal_05_sentence_preview.png")
	var records_before: int = main.game.sentence_records.size()
	await _click_terminal_control("NotebookCraftButton")
	_check(main.game.sentence_records.size() == records_before + 1 and main.game.has_current_chapter_submission(), "real CRT notebook submit click creates a current-task sentence record")
	report.composition.submitted_by_uv_click = main.game.sentence_records.size() == records_before + 1
	_check(main.game.has_current_chapter_submission(), "original app handlers produce a submission for the current NPC task")
	await _click_terminal_control("TerminalExit")
	_check(not main._chapter_terminal_active(), "UV-projected Exit button returns control to the world")
	_check(main._app_windows.social.get_parent() == main._ui_root and main._app_windows.notebook.get_parent() == main._ui_root, "exiting returns the same real app windows to the main UI tree")
	if not await _interact("chapter1_npc"):
		await _finish()
		return
	var submit := main.find_child("ChapterTaskSubmitButton", true, false) as Button
	_check(submit != null and not submit.disabled, "matching NPC's delivery button accepts the current expression")
	if submit != null and not submit.disabled:
		submit.pressed.emit()
	await _settle(3)
	var dismiss := main.find_child("ChapterTaskDismissButton", true, false) as Button
	if dismiss != null and dismiss.is_visible_in_tree():
		dismiss.pressed.emit()
	main.set_view_state("phone_down")
	await _settle(12)
	var close_social := main.find_child("SocialAppInlineCloseButton", true, false) as Button
	if close_social != null and close_social.is_visible_in_tree():
		close_social.pressed.emit()
		await _settle(3)
	report.phone_after = _phone_permissions()
	_check(_permissions_match(report.phone_after, ["social"]), "first NPC delivery unlocks only the phone social app")
	await _capture("chapter1_terminal_04_phone_social_unlocked.png")
	await _finish()


func _interact(actor_type: String) -> bool:
	main.set_view_state("npc_up")
	main._set_reality_mouse_look(false)
	var selected: Area3D
	for actor in main._reality_floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == actor_type:
			selected = actor
			break
	_check(selected != null, "authored world contains interaction actor %s" % actor_type)
	if selected == null:
		return false
	main._reality_player.global_position = selected.global_position + Vector3(0, 0.05, 0.35)
	main._reality_player.velocity = Vector3.ZERO
	main._reality_last_safe_position = main._reality_player.position
	main._refresh_nearby_reality_actor()
	_check(main._nearby_reality_actor == selected, "normal proximity selection reaches %s" % actor_type)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_F
	key.physical_keycode = KEY_F
	main._unhandled_input(key)
	await _settle(8)
	var accepted: bool = main._chapter_terminal_active() if actor_type == "chapter1_terminal" else false
	if actor_type == "chapter1_npc":
		var task_panel := main.find_child("ChapterTaskPanel", true, false) as Control
		accepted = task_panel != null and task_panel.is_visible_in_tree()
	_check(accepted, "real F key dispatch activates %s" % actor_type)
	return accepted


func _click_terminal_control(node_name: String) -> void:
	if not main._chapter_terminal_active():
		_check(false, "cannot route %s without an active CRT" % node_name)
		return
	var session: Node = main._chapter_terminal_session
	var terminal: Node = session.get_terminal()
	var control := terminal.get_content_root().find_child(node_name, true, false) as Control
	_check(control != null and control.is_visible_in_tree(), "%s is a real visible CRT Control" % node_name)
	if control == null:
		return
	var pixel := control.get_global_rect().get_center()
	await _click_terminal_pixel(pixel, node_name)


func _click_terminal_pixel(pixel: Vector2, description: String) -> void:
	var session: Node = main._chapter_terminal_session
	var uv := pixel / Vector2(1600, 1200)
	var world := _world_from_uv(main._reality_floor.get_screen_mesh(), uv)
	_check(world != Vector3.INF, "%s UV lies on authored screen triangles" % description)
	if world == Vector3.INF:
		return
	var position: Vector2 = main._camera.unproject_position(world)
	var motion := InputEventMouseMotion.new()
	motion.position = position
	var moved: bool = session.route_input(motion, main._camera)
	var down := InputEventMouseButton.new()
	down.position = position
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	var pressed: bool = session.route_input(down, main._camera)
	var up := down.duplicate() as InputEventMouseButton
	up.pressed = false
	var released: bool = session.route_input(up, main._camera)
	_check(moved and pressed and released, "%s receives real camera-ray mouse motion/press/release" % description)
	await _settle(3)


func _pick_detail_word() -> String:
	var content: Control = main._chapter_terminal_session.get_terminal().get_content_root()
	var rich := content.find_child("SocialPickupLineText", true, false) as RichTextLabel
	_check(rich != null and rich.is_visible_in_tree(), "first post contains an actual pickable RichTextLabel")
	if rich == null:
		return ""
	var ancestor := rich.get_parent()
	while ancestor != null and ancestor != content:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(rich)
			break
		ancestor = ancestor.get_parent()
	await _settle(3)
	var hovered := [""]
	rich.meta_hover_started.connect(func(meta): hovered[0] = str(meta))
	rich.meta_hover_ended.connect(func(_meta): hovered[0] = "")
	var bounds := rich.get_global_rect().intersection(Rect2(Vector2.ZERO, Vector2(1600, 1200)))
	ancestor = rich.get_parent()
	while ancestor is Control:
		if ancestor.clip_contents:
			bounds = bounds.intersection(ancestor.get_global_rect())
		ancestor = ancestor.get_parent()
	for y in range(int(bounds.position.y) + 5, int(bounds.end.y), 8):
		for x in range(int(bounds.position.x) + 5, int(bounds.end.x), 8):
			var pixel := Vector2(x, y)
			var world := _world_from_uv(main._reality_floor.get_screen_mesh(), pixel / Vector2(1600, 1200))
			if world == Vector3.INF:
				continue
			var motion := InputEventMouseMotion.new()
			motion.position = main._camera.unproject_position(world)
			main._chapter_terminal_session.route_input(motion, main._camera)
			if not hovered[0].is_empty():
				var unit: String = hovered[0]
				report.text_pickup = {"mode": "actual RichTextLabel hover and UV mouse click", "unit": unit, "pixel": str(pixel), "normal_font_size": rich.get_theme_font_size("normal_font_size")}
				await _click_terminal_pixel(pixel, "SocialPickupLineText link")
				return unit
	var matcher := RegEx.new()
	matcher.compile("\\[url=([^\\]]+)\\]")
	var found := matcher.search(rich.text)
	if found != null:
		var unit := found.get_string(1)
		report.text_pickup = {"mode": "existing RichTextLabel meta_clicked signal fallback; not a pointer-click claim", "unit": unit, "normal_font_size": rich.get_theme_font_size("normal_font_size")}
		rich.meta_clicked.emit(unit)
		await _settle(3)
		return unit
	_check(false, "first post pickup text exposes at least one valid word link")
	return ""


func _tap_notebook_word(unit: String) -> void:
	var content: Control = main._chapter_terminal_session.get_terminal().get_content_root()
	var canvas := content.find_child("NotebookWordCanvas", true, false) as Control
	_check(canvas != null and canvas.is_visible_in_tree(), "original notebook word canvas is visible inside CRT")
	if canvas == null:
		return
	var body: RigidBody2D
	for candidate in canvas.find_children("*", "RigidBody2D", true, false):
		if str(candidate.get_meta("word_unit", "")) == unit:
			body = candidate
			break
	_check(body != null, "collected unit has its real notebook physics word tile")
	if body != null:
		var pixel := body.global_position
		_check(canvas.get_global_rect().has_point(pixel), "word tile is inside the visible notebook canvas")
		await _click_terminal_pixel(pixel, "Notebook word tile %s" % unit)


func _world_from_uv(mesh: MeshInstance3D, uv: Vector2) -> Vector3:
	var arrays := mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var coords: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if indices.is_empty():
		for index in vertices.size():
			indices.append(index)
	for offset in range(0, indices.size() - 2, 3):
		var a := indices[offset]
		var b := indices[offset + 1]
		var c := indices[offset + 2]
		var edge_b := coords[b] - coords[a]
		var edge_c := coords[c] - coords[a]
		var determinant := edge_b.cross(edge_c)
		if absf(determinant) < 0.000001:
			continue
		var delta := uv - coords[a]
		var u := delta.cross(edge_c) / determinant
		var v := edge_b.cross(delta) / determinant
		if u >= -0.00001 and v >= -0.00001 and u + v <= 1.00001:
			return mesh.to_global(vertices[a] * (1.0 - u - v) + vertices[b] * u + vertices[c] * v)
	return Vector3.INF


func _phone_permissions() -> Dictionary:
	var result := {}
	for app in APP_IDS:
		var button := main.find_child("PhoneAppIcon%s" % app.capitalize(), true, false) as Button
		result[app] = {"unlocked": main.game.is_phone_app_unlocked(app), "button_exists": button != null, "disabled": button.disabled if button != null else false, "visible": button.is_visible_in_tree() if button != null else false}
	return result


func _permissions_match(data: Dictionary, expected: Array) -> bool:
	for app in APP_IDS:
		if not data[app].button_exists or not data[app].visible or data[app].unlocked != (app in expected) or data[app].disabled == (app in expected):
			return false
	return true


func _freeze_processing(node: Node) -> void:
	frozen_controls.append({"node": node, "process": node.is_processing(), "physics": node.is_physics_processing()})
	node.set_process(false)
	node.set_physics_process(false)
	for child in node.get_children():
		_freeze_processing(child)


func _restore_processing() -> void:
	for saved in frozen_controls:
		if is_instance_valid(saved.node):
			saved.node.set_process(saved.process)
			saved.node.set_physics_process(saved.physics)
	frozen_controls.clear()
	for tween in frozen_tweens:
		if is_instance_valid(tween) and tween.is_valid():
			tween.play()
	frozen_tweens.clear()
	main.set_process(true)
	main.set_physics_process(true)
	if RenderingServer.has_method("set_shader_time_scale"):
		RenderingServer.call("set_shader_time_scale", 1.0)


func _projected_bounds(mesh: MeshInstance3D) -> Rect2:
	var vertices: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var region := Rect2(main._camera.unproject_position(mesh.to_global(vertices[0])), Vector2.ZERO)
	for vertex in vertices:
		region = region.expand(main._camera.unproject_position(mesh.to_global(vertex)))
	return region


func _screen_difference(a: Image, b: Image, region: Rect2) -> Dictionary:
	var inside_changed := 0
	var outside_changed := 0
	var inside_samples := 0
	var outside_samples := 0
	for y in range(0, a.get_height(), 3):
		for x in range(0, a.get_width(), 3):
			var position := Vector2(x, y)
			var inside := region.grow(-8).has_point(position)
			var outside := not region.grow(14).has_point(position)
			if not inside and not outside:
				continue
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var changed := maxf(absf(ca.r - cb.r), maxf(absf(ca.g - cb.g), absf(ca.b - cb.b))) > 0.025
			if inside:
				inside_samples += 1
				inside_changed += int(changed)
			else:
				outside_samples += 1
				outside_changed += int(changed)
	return {"inside_changed_samples": inside_changed, "inside_samples": inside_samples, "outside_changed_samples": outside_changed, "outside_samples": outside_samples, "rgb_difference_threshold": 0.025, "outside_edge_exclusion_px": 14, "inside_edge_exclusion_px": 8}


func _settle(frames: int) -> void:
	for frame in frames:
		await process_frame
		RenderingServer.force_draw()


func _capture(filename: String) -> Image:
	await _settle(18)
	var picture := viewport.get_texture().get_image()
	var error := picture.save_png(OUTPUT.path_join(filename))
	captures.append({"file": filename, "error": error})
	_check(error == OK, "PNG saved: %s" % filename)
	print("CRT_CAPTURE: ", filename, " error=", error)
	return picture


func _check(condition: bool, message: String) -> void:
	checks.append({"pass": condition, "description": message})
	if not condition:
		failures.append(message)


func _finish() -> void:
	report.merge({"renderer": RenderingServer.get_video_adapter_name(), "captures": captures, "checks": checks, "failures": failures, "scope": "Actual authored CRT, original app Controls, nearby F path, UV-projected toolbar/post/notebook-word/submit/Exit and NPC delivery button. Text pickup route is recorded separately. Fifth screenshot is taken before sentence submission. Fake webcam receiver; no physical camera or video decoding test. Exit cleanup diagnostics remain in process stderr."})
	var output := FileAccess.open(OUTPUT.path_join("chapter1_terminal_capture_results.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	output.close()
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	if is_instance_valid(viewport):
		viewport.queue_free()
	await process_frame
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter CRT render captures passed (%d checks)" % checks.size())
	quit(0 if failures.is_empty() else 1)
