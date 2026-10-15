extends SceneTree

# Run through tools/verify_mouse_capture_window.py --godot <executable>. Unlike the
# headless input suite, this checks a native Window and its Win32 clipping rect.
# All key/click/motion events stay inside this test's Viewport; no OS input is
# injected into the desktop or an existing game instance.
const DEFAULT_OUTPUT := "res://artifacts/mouse-capture-window-20261016"
var checks := 0
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var main: Node
var peer: Window
var python := ""
var output_directory := ""

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	python = OS.get_environment("APHASIA_MOUSE_PROBE_PYTHON")
	output_directory = OS.get_environment("APHASIA_MOUSE_CAPTURE_OUTPUT")
	if output_directory.is_empty():
		output_directory = DEFAULT_OUTPUT
	if DisplayServer.get_name() != "Windows" or python.is_empty():
		push_error("Native mouse capture test requires Windows display and tools/verify_mouse_capture_window.py; headless is not a valid substitute.")
		quit(2)
		return
	root.title = "Aphasia mouse capture regression (temporary)"
	root.gui_embed_subwindows = false
	root.size = Vector2i(960, 640)
	root.position = Vector2i(100, 100)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = "user://mouse_capture_window.dat"
	main._locale.preferences_path = "user://mouse_capture_window.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	var state = load("res://scripts/meme_game_state.gd").new()
	state.new_run()
	state.chapter1_progress = {}
	state.tower_floor = 2
	state.set_view_state("npc_up")
	main._begin_game_session(state, {}, false)
	if not await _focus(root):
		_check(false, "temporary game window can receive real OS focus")
		await _finish()
		return
	_click_world()
	await _settle()
	_check(not root.is_embedded(), "test uses a native independent window")
	_check_mode("world startup", Input.MOUSE_MODE_CAPTURED, true)
	for mode_source in ["Input", "DisplayServer"]:
		var idle_yaw: float = main._reality_yaw
		if mode_source == "Input":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		# No key, motion, click, setter, or manual sync occurs during this wait.
		await process_frame
		await process_frame
		_check_mode(mode_source + " idle drift repaired without input", Input.MOUSE_MODE_CAPTURED, true)
		_check(is_equal_approx(main._reality_yaw, idle_yaw), mode_source + " idle capture repair does not move the camera")
		main._set_reality_mouse_look(true)
		# Deliberately desynchronize the real OS mode from the still-enabled
		# gameplay look intent. The unlocked motion must be discarded, and the
		# next process frame must repair capture without requiring a click.
		if mode_source == "Input":
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			DisplayServer.mouse_set_mode(DisplayServer.MOUSE_MODE_VISIBLE)
		var yaw_before: float = main._reality_yaw
		var stray_motion := InputEventMouseMotion.new()
		stray_motion.position = Vector2(root.size) * 0.5
		stray_motion.global_position = stray_motion.position
		stray_motion.relative = Vector2(67, 0)
		root.push_input(stray_motion, true)
		_check(is_equal_approx(main._reality_yaw, yaw_before), mode_source + " drift: unlocked relative motion cannot rotate camera")
		await process_frame
		await process_frame
		_check_mode(mode_source + " drift repaired by next process frame", Input.MOUSE_MODE_CAPTURED, true)
		# Reestablish the fixture even on RED so later failures stay independent.
		main._set_reality_mouse_look(true)
	for delta in [Vector2(10000, 0), Vector2(-10000, 0), Vector2(0, 10000), Vector2(0, -10000)]:
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(root.size) + delta
		motion.global_position = motion.position
		motion.relative = delta
		root.push_input(motion, true)
		await _settle()
		_check_mode("large boundary motion %s" % delta, Input.MOUSE_MODE_CAPTURED, true)
	_key(KEY_TAB)
	await _settle()
	_check(main.game.view_state == "phone_down", "Tab opens the real phone")
	_check_mode("phone open", Input.MOUSE_MODE_VISIBLE, false)
	main._set_reality_mouse_look(true)
	await _settle()
	_check(not main._reality_mouse_look_enabled, "phone rejects stale world capture request")
	_check_mode("phone rejects capture request", Input.MOUSE_MODE_VISIBLE, false)
	main._set_reality_mouse_look(false)
	_key(KEY_ESCAPE)
	await _settle()
	_check(main._settings_open, "Escape opens settings over phone")
	_check_mode("phone settings open", Input.MOUSE_MODE_VISIBLE, false)
	_key(KEY_ESCAPE)
	await _settle()
	_check(not main._settings_open and main.game.view_state == "phone_down", "settings close returns to the phone")
	_check_mode("phone settings closed", Input.MOUSE_MODE_VISIBLE, false)
	_key(KEY_TAB)
	await _settle()
	_check(main.game.view_state == "npc_up", "Tab closes the real phone")
	_check_mode("phone closed", Input.MOUSE_MODE_CAPTURED, true)
	_key(KEY_ESCAPE)
	await _settle()
	_check(main._settings_open, "Escape opens world settings")
	_check_mode("world settings open", Input.MOUSE_MODE_VISIBLE, false)
	main._set_reality_mouse_look(true)
	await _settle()
	_check(not main._reality_mouse_look_enabled, "settings rejects stale world capture request")
	_check_mode("settings rejects capture request", Input.MOUSE_MODE_VISIBLE, false)
	main._set_reality_mouse_look(false)
	_key(KEY_ESCAPE)
	await _settle()
	_check_mode("world settings closed", Input.MOUSE_MODE_CAPTURED, true)
	main._exit_confirmation_overlay.show()
	main._set_reality_mouse_look(false)
	main._set_reality_mouse_look(true)
	await _settle()
	_check(not main._reality_mouse_look_enabled, "modal rejects stale world capture request")
	_check_mode("modal rejects capture request", Input.MOUSE_MODE_VISIBLE, false)
	main._set_reality_mouse_look(false)
	# A delayed settings-close callback must honor a newer foreground modal.
	main._close_settings_window()
	await _settle()
	_check(main._exit_confirmation_overlay.is_visible_in_tree(), "restore callback leaves newer modal present")
	_check(not main._reality_mouse_look_enabled, "restore callback cannot capture through newer modal")
	_check_mode("modal survives settings restore callback", Input.MOUSE_MODE_VISIBLE, false)
	main._exit_confirmation_overlay.hide()
	main._set_reality_mouse_look(true)
	await _settle()
	# A second native window owned only by this test generates genuine window
	# focus-out/in notifications. It does not focus any user-owned application.
	peer = Window.new()
	peer.hide()
	peer.title = "Aphasia temporary focus target"
	peer.force_native = true
	peer.transient = false
	peer.size = Vector2i(320, 160)
	peer.position = Vector2i(1080, 100)
	root.add_child(peer)
	peer.show()
	_check(await _focus(peer), "temporary native peer receives OS focus")
	_check(not root.has_focus() and not main._application_focused, "main receives actual window focus-out")
	_check_mode("window focus lost", Input.MOUSE_MODE_VISIBLE, false)
	main._set_reality_mouse_look(true)
	main._sync_reality_mouse_capture()
	await _settle()
	_check(peer.has_focus() and not root.has_focus(), "capture request and sync cannot steal focus from native peer")
	_check(not main._reality_mouse_look_enabled, "unfocused capture request leaves look disabled")
	_check_mode("unfocused capture request rejected", Input.MOUSE_MODE_VISIBLE, false)
	_check(await _focus(root), "native main window receives OS focus again")
	_check(main._application_focused, "main receives actual window focus-in")
	_check_mode("window focus restored before click", Input.MOUSE_MODE_VISIBLE, false)
	_click_world()
	await _settle()
	_check_mode("world click after focus restore", Input.MOUSE_MODE_CAPTURED, true)
	# Programmatic window resize/move also changes the OS client boundaries.
	root.position += Vector2i(24, 20)
	root.size = Vector2i(840, 600)
	await _settle()
	_check_mode("window moved and resized", Input.MOUSE_MODE_CAPTURED, true)
	# Returning while a UI is open must not unexpectedly capture the pointer.
	_key(KEY_TAB)
	await _settle()
	_check(await _focus(peer), "peer can take focus while phone is open")
	_check(await _focus(root), "phone window regains focus")
	_check_mode("phone focus restored", Input.MOUSE_MODE_VISIBLE, false)
	_key(KEY_ESCAPE)
	await _settle()
	_check(await _focus(peer), "peer can take focus while settings are open")
	_check(await _focus(root), "settings window regains focus")
	_check_mode("settings focus restored", Input.MOUSE_MODE_VISIBLE, false)
	await _finish()

func _focus(window: Window) -> bool:
	window.grab_focus()
	for frame in 150:
		await process_frame
		if window.has_focus():
			await _settle()
			return window.has_focus()
	return false

func _settle() -> void:
	for frame in 8:
		await process_frame

func _check_mode(stage: String, expected: int, captured: bool) -> void:
	_check(Input.mouse_mode == expected, stage + ": actual Input.mouse_mode matches")
	_check(DisplayServer.mouse_get_mode() == expected, stage + ": native DisplayServer mode matches")
	var handle := DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE, root.get_window_id())
	var output := []
	var code := OS.execute(python, [ProjectSettings.globalize_path("res://tools/native_mouse_capture_probe.py"), str(handle), str(OS.get_process_id())], output, true, false)
	var parsed: Variant = JSON.parse_string("".join(output)) if code == 0 else null
	_check(parsed is Dictionary, stage + ": Win32 read-only probe succeeds")
	if not parsed is Dictionary:
		return
	var native: Dictionary = parsed
	native["stage"] = stage
	native["input_mode"] = Input.mouse_mode
	native["display_mode"] = DisplayServer.mouse_get_mode()
	native["root_focused"] = root.has_focus()
	native["window_position"] = [root.position.x, root.position.y]
	native["window_size"] = [root.size.x, root.size.y]
	var display_position := DisplayServer.window_get_position(root.get_window_id())
	var display_size := DisplayServer.window_get_size(root.get_window_id())
	var display_mouse := DisplayServer.mouse_get_position()
	native["display_window_position"] = [display_position.x, display_position.y]
	native["display_window_size"] = [display_size.x, display_size.y]
	native["display_mouse_position"] = [display_mouse.x, display_mouse.y]
	samples.append(native)
	_check(bool(native.get("owned_window", false)), stage + ": probe targets this test process only")
	_check(bool(native.get("clip_matches_client", false)) == captured, stage + ": OS ClipCursor boundaries match capture state")
	if captured:
		_check(root.has_focus() and bool(native.get("foreground", false)), stage + ": captured test window is really foreground")
		_check(bool(native.get("cursor_in_client", false)), stage + ": system cursor stays within real client bounds")
		_check(int(native.get("capture_window", 0)) == handle, stage + ": Win32 capture belongs to the test window")
	else:
		_check(bool(native.get("clip_matches_desktop", false)), stage + ": released OS pointer can use the complete desktop")
		_check(int(native.get("capture_window", 0)) == 0, stage + ": released GUI thread owns no Win32 capture")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func _click_world() -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(root.size) * 0.5
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	event.button_mask = 0
	root.push_input(event, true)

func _finish() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(peer):
		peer.free()
	if is_instance_valid(main):
		main._set_reality_mouse_look(false)
		main.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_directory))
	var file := FileAccess.open(output_directory.path_join("native-samples.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "samples": samples}, "\t"))
	file.close()
	await process_frame
	for failure in failures:
		push_error(failure)
	print("native mouse capture %s: %d checks, %d failures" % ["passed" if failures.is_empty() else "FAILED", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
