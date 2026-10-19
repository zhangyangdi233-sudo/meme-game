extends SceneTree

var failures: Array[String] = []
var checks := 0
const STATE_PATH := "res://scripts/tutorial/chapter_crt_tutorial_state.gd"
const FOCUS_PATH := "res://scripts/tutorial/chapter_crt_focus_controller.gd"

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(FileAccess.file_exists(STATE_PATH), "CRT onboarding needs its own persistent state, independent of the retired guide")
	_check(FileAccess.file_exists(FOCUS_PATH), "stair focus controller must own restoration and input")
	if failures.is_empty():
		var state: Script = load(STATE_PATH)
		var clean: Dictionary = state.normalize({})
		_check(clean.focus_line == 1 and not clean.focus_done and clean.lesson_phase == "post", "new save starts at the first narration and post")
		var dirty: Dictionary = state.normalize({"focus_line": 99, "lesson_phase": "bypass", "collected": ["门", "门", "unknown"], "locale": "zh"})
		_check(dirty.focus_line == 7 and dirty.lesson_phase == "post", "invalid saved stages are bounded safely")
		_check(dirty.collected == ["门"], "saved pickup evidence is unique and restricted to teaching units")
		var malformed: Dictionary = state.normalize({"focus_line": {}, "focus_fov": [], "focus_started": "true", "focus_done": {"true": true}})
		_check(malformed.focus_line == 1 and is_equal_approx(malformed.focus_fov, 58.0) and not malformed.focus_started and not malformed.focus_done, "malformed save fields cannot crash or claim completed narration")
		var pool: Script = load("res://scripts/narrative/pickup_char_pool.gd")
		var content: Script = load("res://scripts/tutorial/chapter_crt_tutorial_content.gd")
		_check(content.LINES.zh == ["这个对你来说不陌生", "你之前可喜欢盯着这个发呆了", "现在被你遗忘也是情有可原", "但是现在这个东西对你来说……", "很有意思……是吧", "去看看这个老家伙吧", "你现在只能依靠它咯！"], "all seven Chinese lines retain the user's exact text and order")
		for locale in ["zh", "en", "ja"]:
			for unit in state.teaching_units(locale):
				_check(pool.is_unit_seeded_in_post(state.POST_ID, unit, locale), "teaching unit %s is genuinely pickable in the existing %s post" % [unit, locale])
		await _focus_restoration()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("CRT onboarding tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)

func _focus_restoration() -> void:
	var director: Script = load("res://scripts/progression/basement_loop_director.gd")
	var progress: Dictionary = director.initial_progress(false)
	progress.phase = "basement"
	progress.narrator_completed = true
	progress.opening_line_number = 30
	progress.opening_knock_completed = true
	progress.transition_serial = 1
	progress.entrance_locked = true
	var world = load("res://scripts/world/chapter_world.gd").new()
	root.add_child(world)
	var loaded: bool = world.configure_stage(progress, {})
	_check(loaded, "real imported first basement loads: %s" % str(world.diagnostics))
	_check(world.get_crt_focus_visuals().size() > 15, "focus includes actual CRT shell, controls and screen")
	_check(not world.crossed_crt_focus_trigger(Vector3(0, 1.35, 0.4), Vector3(0, 1.35, 0.6)), "walking through room center cannot fire stair trigger")
	var player := CharacterBody3D.new()
	root.add_child(player)
	player.position = Vector3(-2.5, 1.45, 0.3)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = player.position + Vector3(0, 1.65, 0)
	camera.rotation.y = PI
	camera.current = true
	var ui := Control.new()
	root.add_child(ui)
	var focus = load(FOCUS_PATH).new()
	root.add_child(focus)
	focus.setup(world, camera, player, ui, func(): return progress, func(): pass, func(): return "zh")
	var original_pose := camera.global_transform
	var original_mask := camera.cull_mask
	var original_environment := camera.environment
	var light_states: Dictionary = {}
	var mesh_layers: Dictionary = {}
	for mesh in world.get_crt_focus_visuals():
		mesh_layers[mesh] = mesh.layers
	for light in world.find_children("*", "Light3D", true, false):
		if light.get_world_3d() == camera.get_world_3d():
			light_states[light] = light.visible
	focus.update(0.01)
	_check(not focus.is_active(), "standing above midpoint does not start narration")
	player.position = Vector3(-2.5, 1.32, 0.6)
	focus.update(0.01)
	var held := player.position
	_check(focus.is_active() and progress.crt_tutorial.focus_started, "real downward stair crossing starts exactly once")
	_check(camera.cull_mask == (1 << 17) and camera.environment.background_color == Color.BLACK, "instant isolated black view retains only CRT layer")
	for mesh in mesh_layers:
		_check(mesh.layers == mesh_layers[mesh], "focus must not change live CRT geometry layers (Godot 4.6 Forward+ light pairing)")
	var mirrors: Array[Node] = world.find_children("CRTFocusMirror*", "MeshInstance3D", true, false)
	_check(mirrors.size() == mesh_layers.size(), "isolated view contains a fixed-layer mirror of every CRT visual")
	for mirror in mirrors:
		_check(mirror.layers == camera.cull_mask, "teaching mirror has its final layer before entering the rendered world")
	var teaching_spot := world.find_child("CRTFirstVisitWhiteSpotlight", true, false) as SpotLight3D
	var teaching_beam := world.find_child("CRTFirstVisitWhiteLightBeam", true, false) as MeshInstance3D
	_check(teaching_spot != null and teaching_spot.layers == camera.cull_mask and teaching_spot.light_cull_mask == camera.cull_mask, "white spotlight itself survives the isolated camera mask")
	_check(teaching_beam == null, "isolated CRT focus has no visible overhead beam or mist geometry")
	_check(teaching_spot != null and teaching_spot.visible and teaching_spot.light_energy > 0.0, "invisible spotlight still makes the CRT cabinet readable against black")
	for light in light_states:
		_check(not light.visible, "all original lights are suppressed during focus")
	var paused_pose := camera.global_transform
	focus.update(3.0, true)
	_check(camera.global_transform.is_equal_approx(paused_pose), "pause freezes camera interpolation")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	focus.route_input(click)
	_check(progress.crt_tutorial.focus_line == 1, "paused click cannot advance narration")
	player.position += Vector3(0.2, -1.0, 0.2)
	player.velocity = Vector3(3, -5, 3)
	focus.update(1.0, false)
	focus.update(0.01)
	_check(player.position.is_equal_approx(held) and player.velocity == Vector3.ZERO, "cinematic preserves trigger feet and zeros residual motion")
	_check(camera.global_position.is_equal_approx(original_pose.origin), "focus rotates the real camera without moving player or camera origin")
	focus.route_input(click)
	_check(progress.crt_tutorial.focus_line == 2, "actual input event advances exactly one line")
	focus.cancel()
	await process_frame
	_check(world.find_children("CRTFocusMirror*", "MeshInstance3D", true, false).is_empty() and world.find_child("CRTFirstVisitWhiteSpotlight", true, false) == null, "cancel frees temporary CRT mirrors and spotlight instead of retaining hidden lights")
	_check(camera.global_transform.is_equal_approx(original_pose) and camera.environment == original_environment and camera.cull_mask == original_mask, "cancel restores full camera state")
	for light in light_states:
		_check(light.visible == light_states[light], "cancel restores each light's previous visibility")
	focus.update(1.0)
	focus.update(0.01)
	_check(focus.is_active() and progress.crt_tutorial.focus_line == 2, "unfinished saved narration resumes its line")
	for index in 6:
		focus.route_input(click)
	_check(progress.crt_tutorial.focus_done and camera.cull_mask == original_mask, "last line restores the room immediately and records completion")
	focus.update(1.0)
	_check(not focus.is_active() and camera.global_transform.is_equal_approx(original_pose), "smooth return ends at original view")
	player.position = Vector3(-2.5, 1.45, 0.3)
	focus.update(0.1)
	player.position = held
	focus.update(0.1)
	_check(not focus.is_active(), "crossing again after completion cannot replay")
	focus.free()
	ui.free()
	camera.free()
	player.free()
	world.free()
	await process_frame

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
