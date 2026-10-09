extends SceneTree

const TERMINAL_PATH := "res://scripts/world/chapter_terminal.gd"
const VIDEO := preload("res://scripts/world/chapter_video_screen.gd")

class SyntheticPlayback:
	extends VideoStreamPlayback
	var playing := false
	var paused := false
	var frame: Texture2D = ImageTexture.create_from_image(Image.create(4, 3, false, Image.FORMAT_RGB8))
	func _play() -> void:
		playing = true
	func _stop() -> void:
		playing = false
	func _is_playing() -> bool:
		return playing
	func _set_paused(value: bool) -> void:
		paused = value
	func _is_paused() -> bool:
		return paused
	func _get_texture() -> Texture2D:
		return frame
	func _get_length() -> float:
		return 1.0
	func _get_playback_position() -> float:
		return 0.0
	func _get_channels() -> int:
		return 0
	func _get_mix_rate() -> int:
		return 44100
	func _update(_delta: float) -> void:
		pass
	func _set_audio_track(_track: int) -> void:
		pass
	func _seek(_time: float) -> void:
		pass

class SyntheticStream:
	extends VideoStream
	func _instantiate_playback() -> VideoStreamPlayback:
		return SyntheticPlayback.new()

var failures: Array[String] = []
var checks := 0
var terminal_script: Script


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	root.size = Vector2i(960, 720)
	_check(FileAccess.file_exists(TERMINAL_PATH), "CRT terminal component must exist")
	var video := VIDEO.new()
	_check(video.has_method("attach_display") and video.has_method("detach_display"), "video exposes an owner-checked external display lease")
	video.free()
	if FileAccess.file_exists(TERMINAL_PATH):
		terminal_script = load(TERMINAL_PATH)
		await _test_real_gui_input_on_rotated_mesh()
		_test_surface_ownership()
		await _test_video_display_lease()
		_test_video_lease_replacement()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter terminal tests passed (%d checks; real Control input, synthetic screen geometry)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_real_gui_input_on_rotated_mesh() -> void:
	var fixture := _fixture()
	var terminal: Node = fixture.terminal
	var screen: MeshInstance3D = fixture.screen
	var camera: Camera3D = fixture.camera
	_check(terminal.bind_screen(screen), "valid textured surface accepts terminal binding")
	var viewport: SubViewport = terminal.get_display_viewport()
	var content: Control = terminal.get_content_root()
	_check(viewport.size == Vector2i(1600, 1200) and viewport.disable_3d, "CRT owns a 4:3 1600x1200 GUI-only viewport")
	_check(content.get_parent() == viewport and content.size == Vector2(1600, 1200) and terminal.get_texture() == viewport.get_texture(), "actual application controls have a full-size viewport-owned content root")
	_check(not terminal.is_active(), "binding a screen never starts consuming gameplay input")
	_check(terminal.get_screen_center().distance_to(_world_at_uv(screen, Vector2(0.5, 0.5))) < 0.001, "screen center comes from authored surface triangles")
	_check(terminal.get_screen_forward().dot(fixture.normal) > 0.999, "focus direction follows actual rotated geometry, not the mesh node's local Z axis")
	var material := screen.get_surface_override_material(0) as ShaderMaterial
	_check(material != null and material.get_shader_parameter("content_texture") == viewport.get_texture(), "only the CRT surface samples its own viewport")
	_check(terminal.is_vhs_enabled() and material.get_shader_parameter("vhs_enabled"), "local CRT VHS starts enabled")
	terminal.set_vhs_enabled(false)
	_check(not terminal.is_vhs_enabled() and not material.get_shader_parameter("vhs_enabled"), "VHS can be fully disabled on this screen")
	var shader_source := FileAccess.get_file_as_string("res://shaders/chapter_crt.gdshader")
	_check(not shader_source.contains("hint_screen_texture") and not shader_source.contains("SCREEN_UV"), "CRT shader never reads the full-screen framebuffer")
	var pressed := [0]
	var click_positions: Array[Vector2] = []
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(300, 200)
	button.text = "Actual app action"
	button.pressed.connect(func(): pressed[0] += 1)
	_check(terminal.has_method("get_pointer_position"), "terminal exposes its mapped pointer for in-app word pickup feedback")
	if terminal.has_method("get_pointer_position"):
		button.pressed.connect(func(): click_positions.append(terminal.get_pointer_position()))
	content.add_child(button)
	var entry := LineEdit.new()
	entry.position = Vector2(600, 100)
	entry.size = Vector2(500, 100)
	content.add_child(entry)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(100, 450)
	scroll.size = Vector2(600, 600)
	content.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.custom_minimum_size = Vector2(500, 2200)
	scroll.add_child(rows)
	for index in 30:
		var row := Label.new()
		row.text = "Original app row %d" % index
		row.custom_minimum_size.y = 70
		rows.add_child(row)
	await process_frame
	await process_frame
	var button_pos := camera.unproject_position(_world_at_uv(screen, Vector2(0.15, 0.15)))
	_check(not terminal.route_input(_mouse(button_pos, true), camera), "inactive terminal cannot consume a real mouse press")
	terminal.set_active(true)
	_check(terminal.route_input(_motion(button_pos), camera), "screen ray maps mouse motion to real GUI coordinates")
	_check(terminal.route_input(_mouse(button_pos, true), camera), "screen ray maps mouse press into the CRT viewport")
	var release_pos := camera.unproject_position(_world_at_uv(screen, Vector2(0.18, 0.16)))
	terminal.route_input(_mouse(release_pos, false), camera)
	_check(pressed[0] == 1, "triangle UV mapping activates the actual Button signal")
	if terminal.has_method("get_pointer_position"):
		_check(click_positions.size() == 1 and click_positions[0].distance_to(Vector2(288, 192)) < 0.01, "mapped pointer is already current inside the real app's pressed signal")
	var input_pos := camera.unproject_position(_world_at_uv(screen, Vector2(0.525, 0.125)))
	terminal.route_input(_motion(input_pos), camera)
	terminal.route_input(_mouse(input_pos, true), camera)
	terminal.route_input(_mouse(input_pos, false), camera)
	var letter := InputEventKey.new()
	letter.pressed = true
	letter.keycode = KEY_Q
	letter.unicode = 113
	_check(terminal.route_input(letter, camera), "active terminal forwards keyboard input to its focused Control")
	_check(entry.text == "q", "real LineEdit receives typed characters through SubViewport input")
	var scroll_pos := camera.unproject_position(_world_at_uv(screen, Vector2(0.25, 0.6)))
	terminal.route_input(_motion(scroll_pos), camera)
	terminal.route_input(_mouse(scroll_pos, true, MOUSE_BUTTON_WHEEL_DOWN), camera)
	await process_frame
	_check(scroll.scroll_vertical > 0, "wheel over authored screen scrolls the actual app ScrollContainer")
	terminal.route_input(_motion(button_pos), camera)
	terminal.route_input(_mouse(button_pos, true), camera)
	var offscreen := camera.unproject_position(_world_at_uv(screen, Vector2(1.5, 1.5)))
	_check(terminal.route_input(_motion(offscreen), camera), "captured drag motion is delivered after leaving the mesh")
	_check(terminal.route_input(_mouse(offscreen, false), camera), "drag release outside the screen reaches the originally pressed Control")
	_check(not button.button_pressed and pressed[0] == 1, "releasing outside clears pressed state without clicking the button")
	_check(not terminal.route_input(_mouse(offscreen, true), camera), "uncaptured clicks outside the real surface remain gameplay input")
	terminal.route_input(_motion(button_pos), camera)
	terminal.route_input(_mouse(button_pos, true), camera)
	terminal.set_active(false)
	_check(not button.button_pressed and pressed[0] == 1, "deactivation cancels held GUI presses without activating controls")
	_check(not terminal.route_input(letter, camera) and entry.text == "q", "deactivated terminal cannot continue typing")
	fixture.host.free()
	await process_frame


func _test_surface_ownership() -> void:
	var first := _fixture()
	var second := _fixture()
	var authored := StandardMaterial3D.new()
	first.screen.set_surface_override_material(0, authored)
	first.terminal.bind_screen(first.screen)
	second.terminal.bind_screen(second.screen)
	var a: ShaderMaterial = first.screen.get_surface_override_material(0)
	var b: ShaderMaterial = second.screen.get_surface_override_material(0)
	_check(a != b, "two CRT terminals never share mutable display materials")
	first.terminal.set_vhs_enabled(false)
	_check(b.get_shader_parameter("vhs_enabled"), "one terminal VHS toggle cannot change another screen")
	_check(not first.terminal.bind_screen(first.screen, 5), "invalid surface binding fails safely")
	first.terminal.free()
	_check(first.screen.get_surface_override_material(0) == authored, "freeing a terminal restores its authored screen override")
	var replacement := StandardMaterial3D.new()
	second.screen.set_surface_override_material(0, replacement)
	second.terminal.free()
	_check(second.screen.get_surface_override_material(0) == replacement, "terminal cleanup preserves a later external material replacement")
	first.host.free()
	second.host.free()


func _test_video_display_lease() -> void:
	var fixture := _fixture()
	var video := VIDEO.new()
	fixture.host.add_child(video)
	video.bind_screen(fixture.screen)
	var standby: Material = fixture.screen.get_surface_override_material(0)
	_check(fixture.terminal.bind_screen(fixture.screen, 0, video), "terminal can borrow an already owned video screen")
	var terminal_material: Material = fixture.screen.get_surface_override_material(0)
	_check(terminal_material != standby, "borrowed screen displays the terminal material")
	video.stop()
	_check(fixture.screen.get_surface_override_material(0) == terminal_material, "video standby updates cannot steal the borrowed display")
	_check(not video.play() and fixture.screen.get_surface_override_material(0) == terminal_material, "missing-stream failure preserves the borrowed terminal display")
	video.set_stream(SyntheticStream.new())
	_check(video.play(), "synthetic stream supplies an accepted playback request without claiming media decoding")
	var playback_material := fixture.screen.get_surface_override_material(0) as ShaderMaterial
	_check(playback_material != null and playback_material != terminal_material, "accepted playback selects a separate screen-local CRT video effect material")
	_check(video.has_method("get_playback_texture"), "controller exposes only its own playback texture for local CRT effects")
	if playback_material != null and video.has_method("get_playback_texture"):
		_check(playback_material.get_shader_parameter("content_texture") == video.get_playback_texture(), "video CRT effect samples video viewport, never the GUI or fullscreen texture")
		fixture.terminal.set_vhs_enabled(false)
		_check(not playback_material.get_shader_parameter("vhs_enabled") and not (terminal_material as ShaderMaterial).get_shader_parameter("vhs_enabled"), "one CRT switch disables local VHS in both terminal and playback modes")
		fixture.terminal.set_vhs_enabled(true)
		_check(playback_material.get_shader_parameter("vhs_enabled"), "local video VHS can be restored independently of media playback")
	fixture.terminal.set_active(true)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_Q
	_check(not fixture.terminal.route_input(key, fixture.camera), "playing video cannot send invisible keyboard input into the terminal")
	video.stop()
	_check(fixture.screen.get_surface_override_material(0) == terminal_material, "stopping video restores the attached terminal display")
	video.play()
	var player := video.find_child("VideoPlayer", true, false) as VideoStreamPlayer
	player.finished.emit()
	_check(fixture.screen.get_surface_override_material(0) == terminal_material, "natural completion restores the terminal instead of green standby")
	var button := Button.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(300, 200)
	fixture.terminal.get_content_root().add_child(button)
	await process_frame
	var button_pos: Vector2 = fixture.camera.unproject_position(_world_at_uv(fixture.screen, Vector2(0.15, 0.15)))
	fixture.terminal.route_input(_motion(button_pos), fixture.camera)
	fixture.terminal.route_input(_mouse(button_pos, true), fixture.camera)
	_check(button.button_pressed, "lease-transition regression begins with a real held GUI press")
	video.power_off()
	_check(not video.is_powered_on() and fixture.screen.get_surface_override_material(0) == standby and (standby as StandardMaterial3D).albedo_color == Color.BLACK, "power-off arbitrates the entire screen to black")
	_check(not fixture.terminal.route_input(key, fixture.camera), "powered-off screen cannot receive hidden terminal input")
	fixture.terminal.route_input(_mouse(button_pos, false), fixture.camera)
	_check(not button.button_pressed, "losing the visible display cancels held GUI state even when release arrives while powered off")
	video.power_on()
	_check(fixture.screen.get_surface_override_material(0) == terminal_material and not player.is_playing(), "power-on restores the terminal without autoplay")
	video.power_off()
	_check(video.play() and video.is_powered_on() and fixture.screen.get_surface_override_material(0) == playback_material, "accepted play powers on directly into visible CRT-processed video")
	video.stop()
	var stranger := Node.new()
	video.detach_display(stranger)
	_check(fixture.screen.get_surface_override_material(0) == terminal_material, "only the display owner can detach a lease")
	_check(not video.attach_display(stranger, StandardMaterial3D.new()), "a competing display cannot replace an active owner")
	stranger.free()
	fixture.terminal.free()
	_check(fixture.screen.get_surface_override_material(0) == standby, "terminal release restores the still-valid video-owned material")
	var next: Node = terminal_script.new()
	fixture.host.add_child(next)
	next.bind_screen(fixture.screen, 0, video)
	video.free()
	_check(fixture.screen.get_surface_override_material(0) == null, "video exiting during a lease restores the authored material immediately")
	next.free()
	_check(fixture.screen.get_surface_override_material(0) == null, "terminal exiting after video cannot resurrect the freed video's viewport material")
	fixture.host.free()


func _fixture() -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var screen := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	var basis := Basis.from_euler(Vector3(0.3, -0.55, 0.2))
	var vertices := PackedVector3Array()
	for vertex in [Vector3(-2, 1.5, 0), Vector3(2, 1.5, 0), Vector3(-2, -1.5, 0), Vector3(2, -1.5, 0)]:
		vertices.append(basis * vertex + Vector3(0.3, 0.2, 0.1))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 2, 1, 1, 2, 3])
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	screen.mesh = mesh
	host.add_child(screen)
	screen.rotation_degrees = Vector3(5, 15, 8)
	screen.scale = Vector3(1.2, 0.85, 1.1)
	var normal := screen.global_transform.basis.inverse().transposed() * (basis * Vector3.BACK)
	normal = normal.normalized()
	var camera := Camera3D.new()
	host.add_child(camera)
	var center := _world_at_uv(screen, Vector2(0.5, 0.5))
	camera.position = center + normal * 6.0
	camera.look_at(center, Vector3.UP)
	var terminal: Node = terminal_script.new()
	host.add_child(terminal)
	return {"host": host, "screen": screen, "camera": camera, "terminal": terminal, "normal": normal}


func _test_video_lease_replacement() -> void:
	var fixture := _fixture()
	var video := VIDEO.new()
	fixture.host.add_child(video)
	video.bind_screen(fixture.screen)
	var owner := Node.new()
	var first := StandardMaterial3D.new()
	var replacement := StandardMaterial3D.new()
	_check(video.attach_display(owner, first), "controller accepts a display lease without optional playback effect")
	_check(video.attach_display(owner, replacement) and fixture.screen.get_surface_override_material(0) == replacement, "the same owner can update its display without losing controller ownership")
	var external := StandardMaterial3D.new()
	fixture.screen.set_surface_override_material(0, external)
	video.detach_display(owner)
	_check(fixture.screen.get_surface_override_material(0) == external, "detaching cannot overwrite a material installed by an external owner")
	video.free()
	_check(fixture.screen.get_surface_override_material(0) == external, "freeing video after an external replacement cannot overwrite that replacement")
	owner.free()
	fixture.host.free()


func _world_at_uv(screen: MeshInstance3D, uv: Vector2) -> Vector3:
	var vertices: PackedVector3Array = screen.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	return screen.to_global(vertices[0] + (vertices[1] - vertices[0]) * uv.x + (vertices[2] - vertices[0]) * uv.y)


func _mouse(position: Vector2, pressed: bool, button: MouseButton = MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.pressed = pressed
	event.button_index = button
	return event


func _motion(position: Vector2) -> InputEventMouseMotion:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	return event


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
