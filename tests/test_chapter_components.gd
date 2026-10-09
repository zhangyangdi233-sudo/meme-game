extends SceneTree

const DOOR_PATH := "res://scripts/world/chapter_door.gd"
const SCREEN_PATH := "res://scripts/world/chapter_video_screen.gd"

var _failures: Array[String] = []
var _checks: int = 0
var _door_script: Script
var _screen_script: Script


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_assert_true(FileAccess.file_exists(DOOR_PATH), "chapter door component must exist")
	_assert_true(FileAccess.file_exists(SCREEN_PATH), "chapter video screen component must exist")
	if FileAccess.file_exists(DOOR_PATH):
		_door_script = load(DOOR_PATH) as Script
		_assert_true(_door_script != null and _door_script.can_instantiate(), "chapter door script must compile")
	if FileAccess.file_exists(SCREEN_PATH):
		_screen_script = load(SCREEN_PATH) as Script
		_assert_true(_screen_script != null and _screen_script.can_instantiate(), "chapter screen script must compile")
	if _door_script != null and _door_script.can_instantiate():
		await _test_locked_door_does_not_open_with_time()
		await _test_opening_keeps_blocker_until_complete()
		await _test_seal_cancels_pending_open_permanently()
		await _test_zero_duration_supports_initial_open_entry()
		await _test_freeing_door_cancels_motion()
		await _test_never_tree_door_free_restores_external_blocker()
		await _test_door_exit_then_free_is_idempotent()
		await _test_unbound_door_denies_open()
	if _screen_script != null and _screen_script.can_instantiate():
		await _test_screen_defaults_and_material_isolation()
		await _test_screen_stop_and_tree_exit_are_safe_without_stream()
		await _test_screen_rebind_preserves_original_materials()
		await _test_never_tree_screen_free_restores_external_material()
		await _test_screen_lifecycle_signals_with_synthetic_completion()
		await _test_screen_standby_color_and_power_lifecycle()
	await process_frame
	if _failures.is_empty():
		print("chapter component tests passed (%d checks; synthetic nodes, no video playback claim)" % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_locked_door_does_not_open_with_time() -> void:
	var fixture := _new_door(0.06)
	var door: Node3D = fixture.door
	var pivot: Node3D = fixture.pivot
	var blocker: CollisionShape3D = fixture.blocker
	_assert_true(not door.request_open(), "new door must deny opening until explicitly unlocked")
	await create_timer(0.1).timeout
	_assert_true(not door.is_passable(), "elapsed time must never unlock a door")
	_assert_true(not blocker.disabled, "locked door must keep a real collision blocker")
	_assert_near(pivot.rotation.y, 0.25, "denied request must not turn the leaf")
	fixture.host.free()


func _test_opening_keeps_blocker_until_complete() -> void:
	var fixture := _new_door(0.2)
	var door: Node3D = fixture.door
	var pivot: Node3D = fixture.pivot
	var blocker: CollisionShape3D = fixture.blocker
	var opened_count := [0]
	door.opened.connect(func() -> void: opened_count[0] += 1)
	door.set_locked(false)
	_assert_true(door.request_open(), "unlocked bound door should accept opening")
	_assert_true(not door.request_open(), "repeated request during opening should be ignored")
	_assert_true(not door.is_passable() and not blocker.disabled, "opening must start with blocker active")
	await create_timer(0.06).timeout
	_assert_true(not door.is_passable() and not blocker.disabled, "moving leaf must not disable the independent blocker")
	_assert_true(pivot.rotation.y > 0.25, "leaf should visibly rotate while doorway stays blocked")
	await create_timer(0.2).timeout
	_assert_true(door.is_passable() and blocker.disabled, "only completed opening should allow passage")
	_assert_near(pivot.rotation.y, 0.25 + PI * 0.5, "open rotation should be relative to authored closed angle")
	_assert_true(opened_count[0] == 1, "completed opening should emit opened exactly once")
	_assert_true(not door.request_open(), "already open door should ignore duplicate opening requests")
	fixture.host.free()


func _test_seal_cancels_pending_open_permanently() -> void:
	var fixture := _new_door(0.2)
	var door: Node3D = fixture.door
	var pivot: Node3D = fixture.pivot
	var blocker: CollisionShape3D = fixture.blocker
	var opened_count := [0]
	var closed_count := [0]
	door.opened.connect(func() -> void: opened_count[0] += 1)
	door.closed.connect(func() -> void: closed_count[0] += 1)
	door.set_locked(false)
	door.request_open()
	await create_timer(0.06).timeout
	door.close_and_lock()
	_assert_true(not door.is_passable() and not blocker.disabled, "sealing during opening must block passage immediately")
	door.set_locked(false)
	_assert_true(not door.request_open(), "ordinary unlock cannot reopen a permanently sealed entry")
	await create_timer(0.3).timeout
	_assert_near(pivot.rotation.y, 0.25, "sealed door must return to authored closed rotation")
	_assert_true(not blocker.disabled and not door.is_passable(), "cancelled open callback must never remove seal")
	_assert_true(opened_count[0] == 0 and closed_count[0] == 1, "cancelled opening emits no opened signal and closes once")
	door.close_and_lock()
	await create_timer(0.25).timeout
	_assert_true(closed_count[0] == 1, "repeated sealing should be idempotent")
	door.bind(pivot, blocker, 90.0, 0.0)
	door.set_locked(false)
	_assert_true(not door.request_open(), "rebinding must not erase a permanent seal")
	fixture.host.free()
	var next_fixture := _new_door(0.0)
	next_fixture.door.set_locked(false)
	_assert_true(next_fixture.door.request_open(), "new loop may create a fresh openable entry instance")
	next_fixture.host.free()


func _test_zero_duration_supports_initial_open_entry() -> void:
	var fixture := _new_door(0.0)
	var door: Node3D = fixture.door
	var blocker: CollisionShape3D = fixture.blocker
	door.set_locked(false)
	_assert_true(door.request_open(), "zero duration opening should be supported for initial entry setup")
	_assert_true(door.is_passable() and blocker.disabled, "zero duration opening should finish synchronously")
	door.close_and_lock()
	_assert_true(not door.is_passable() and not blocker.disabled, "sealing an already open entry must restore collision")
	_assert_near(fixture.pivot.rotation.y, 0.25, "zero duration sealing should close synchronously")
	fixture.host.free()


func _test_freeing_door_cancels_motion() -> void:
	var fixture := _new_door(0.2)
	fixture.door.set_locked(false)
	fixture.door.request_open()
	await create_timer(0.06).timeout
	fixture.door.free()
	var stopped_angle: float = fixture.pivot.rotation.y
	await create_timer(0.3).timeout
	_assert_near(fixture.pivot.rotation.y, stopped_angle, "freeing the component must stop its tween on separately owned geometry")
	_assert_true(not fixture.blocker.disabled, "freed pending component must never unblock surviving doorway")
	fixture.host.free()


func _test_never_tree_door_free_restores_external_blocker() -> void:
	var fixture := _new_door(0.0, false)
	_assert_true(not fixture.door.is_inside_tree(), "the regression fixture must never attach its door component")
	fixture.door.set_locked(false)
	_assert_true(fixture.door.request_open() and fixture.blocker.disabled, "zero-duration setup can open an off-tree bound door")
	fixture.door.free()
	_assert_true(not fixture.blocker.disabled, "freeing a never-tree component must restore its independently owned blocker")
	fixture.host.free()


func _test_door_exit_then_free_is_idempotent() -> void:
	var fixture := _new_door(0.0)
	fixture.door.set_locked(false)
	fixture.door.request_open()
	fixture.host.remove_child(fixture.door)
	_assert_true(not fixture.blocker.disabled, "tree exit must immediately restore the external blocker")
	fixture.door.free()
	_assert_true(not fixture.blocker.disabled, "predelete after tree exit must leave the restored blocker intact")
	fixture.host.free()


func _test_unbound_door_denies_open() -> void:
	var door: Node3D = _door_script.new()
	root.add_child(door)
	door.set_locked(false)
	_assert_true(not door.request_open(), "unbound door must safely deny opening")
	_assert_true(not door.is_passable(), "unbound door is never passable")
	door.close_and_lock()
	door.free()


func _test_screen_defaults_and_material_isolation() -> void:
	var shared_mesh := QuadMesh.new()
	var original_material := StandardMaterial3D.new()
	shared_mesh.material = original_material
	var first := _new_screen(shared_mesh)
	var second := _new_screen(shared_mesh)
	var material_a := first.mesh.get_surface_override_material(0) as StandardMaterial3D
	var material_b := second.mesh.get_surface_override_material(0) as StandardMaterial3D
	_assert_true(material_a != null and material_b != null, "screens should bind a 3D material to the selected surface")
	_assert_true(material_a != material_b, "each screen must own a separate material even on shared mesh resources")
	_assert_true(shared_mesh.material == original_material, "binding must not mutate a shared mesh material")
	var viewport: SubViewport = first.screen.find_child("*", true, false) as SubViewport
	var players: Array[Node] = first.screen.find_children("*", "VideoStreamPlayer", true, false)
	_assert_true(viewport != null and players.size() == 1, "screen should own a SubViewport containing one VideoStreamPlayer")
	if viewport != null and not players.is_empty():
		var player := players[0] as VideoStreamPlayer
		_assert_true(player.get_parent() == viewport, "video must draw through the screen's SubViewport")
		_assert_true(player.stream == null and not player.autoplay and not player.is_playing(), "screen must start without resource or autoplay")
		_assert_true(not first.screen.play(), "playing an empty screen must safely return false")
		_assert_true(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "idle screen should not render an unused viewport every frame")
	if material_a != null:
		_assert_true(material_a.resource_local_to_scene, "screen material must be local to its instance")
		_assert_true(material_a.albedo_texture == null, "standby must detach viewport texture so black or stale frames cannot multiply its color")
		_assert_true(material_a.albedo_texture_force_srgb, "viewport video material must force sRGB as Godot documents")
		_assert_true(material_a.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "screen pixels must not depend on scene lighting")
		_assert_true(material_a.albedo_color.g > 0.5 and material_a.albedo_color.g > material_a.albedo_color.r and material_a.albedo_color.g > material_a.albedo_color.b, "empty powered video screen must show green phosphor standby")
	first.host.free()
	second.host.free()


func _test_screen_stop_and_tree_exit_are_safe_without_stream() -> void:
	var fixture := _new_screen(QuadMesh.new())
	var screen: Node3D = fixture.screen
	screen.set_stream(null)
	screen.stop()
	screen.stop()
	_assert_true(not screen.play(), "null stream should remain safe after repeated stop")
	var player := screen.find_children("*", "VideoStreamPlayer", true, false)[0] as VideoStreamPlayer
	var viewport := player.get_parent() as SubViewport
	player.paused = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	fixture.host.remove_child(screen)
	_assert_true(not player.is_playing() and not player.paused, "leaving the tree must reset video playback state")
	_assert_true(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "leaving the tree must stop viewport updates")
	_assert_true(not screen.play(), "off-tree screen must not start playback")
	screen.free()
	fixture.host.free()


func _test_screen_rebind_preserves_original_materials() -> void:
	var fixture := _new_screen(QuadMesh.new())
	var first_mesh: MeshInstance3D = fixture.mesh
	var second_mesh := MeshInstance3D.new()
	second_mesh.mesh = QuadMesh.new()
	var authored_override := StandardMaterial3D.new()
	second_mesh.set_surface_override_material(0, authored_override)
	fixture.host.add_child(second_mesh)
	fixture.screen.bind_screen(second_mesh)
	_assert_true(first_mesh.get_surface_override_material(0) == null, "rebinding should restore the previous screen's original override")
	fixture.screen.free()
	_assert_true(second_mesh.get_surface_override_material(0) == authored_override, "freeing component should restore independently owned mesh material")
	fixture.host.free()


func _test_never_tree_screen_free_restores_external_material() -> void:
	var fixture := _new_screen(QuadMesh.new(), false)
	var screen: Node3D = fixture.screen
	_assert_true(not screen.is_inside_tree(), "the regression fixture must never attach its screen component")
	var authored := StandardMaterial3D.new()
	screen.bind_screen(null)
	fixture.mesh.set_surface_override_material(0, authored)
	screen.bind_screen(fixture.mesh)
	var video_material: WeakRef = weakref(fixture.mesh.get_surface_override_material(0))
	_assert_true(video_material.get_ref() != authored, "binding should temporarily replace the authored override")
	screen.free()
	_assert_true(fixture.mesh.get_surface_override_material(0) == authored, "freeing a never-tree screen must restore its separately owned mesh material")
	_assert_true(video_material.get_ref() == null, "a freed screen must not leave its viewport material retained by external geometry")
	fixture.host.free()


func _test_screen_lifecycle_signals_with_synthetic_completion() -> void:
	var fixture := _new_screen(QuadMesh.new())
	var screen: Node3D = fixture.screen
	var has_lifecycle := screen.has_signal("playback_finished") and screen.has_signal("playback_failed") and screen.has_signal("playback_stopped")
	_assert_true(has_lifecycle, "video screens must expose completed, failed and stopped lifecycle events")
	if not has_lifecycle:
		fixture.host.free()
		return
	var finished := [0]
	var stopped := [0]
	var failures: Array[String] = []
	screen.connect("playback_finished", func() -> void: finished[0] += 1)
	screen.connect("playback_stopped", func() -> void: stopped[0] += 1)
	screen.connect("playback_failed", func(reason: String) -> void: failures.append(reason))
	_assert_true(not screen.play(), "a null stream remains a safe unsuccessful playback request")
	_assert_true(failures == ["no_stream"], "null playback supplies a stable failure reason without an engine error")
	_assert_true(stopped[0] == 0 and finished[0] == 0, "failed startup must not report a stop or natural completion")
	var player := screen.find_children("*", "VideoStreamPlayer", true, false)[0] as VideoStreamPlayer
	var viewport := player.get_parent() as SubViewport
	var material := fixture.mesh.get_surface_override_material(0) as StandardMaterial3D
	# Simulate the visible/rendering state and engine callback only. This does not
	# load or decode video, and is not evidence that a supplied media file plays.
	player.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	material.albedo_color = Color.WHITE
	material.albedo_texture = viewport.get_texture()
	player.finished.emit()
	_assert_true(finished[0] == 1 and stopped[0] == 0, "the engine finished callback emits completion without a manual-stop event")
	_assert_true(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not player.visible, "natural completion must stop viewport rendering and hide the ended player")
	_assert_true(material.albedo_color.g > material.albedo_color.r and material.albedo_color.g > material.albedo_color.b, "natural completion returns the powered screen to green standby")
	_assert_true(material.albedo_texture == null, "natural completion must clear the previous video frame from standby")
	player.finished.emit()
	screen.stop()
	_assert_true(finished[0] == 1 and stopped[0] == 0, "duplicate terminal callbacks and idle stop must not emit extra lifecycle events")
	player.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	material.albedo_color = Color.WHITE
	material.albedo_texture = viewport.get_texture()
	screen.stop()
	screen.stop()
	_assert_true(stopped[0] == 1 and finished[0] == 1, "explicit stop emits once for active display and is then idempotent")
	_assert_true(material.albedo_texture == null and material.albedo_color.g > material.albedo_color.r, "explicit stop restores green standby without a video texture")
	player.visible = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	fixture.host.remove_child(screen)
	_assert_true(stopped[0] == 2 and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "tree exit stops an active display exactly once")
	var replacement := StandardMaterial3D.new()
	fixture.mesh.set_surface_override_material(0, replacement)
	screen.free()
	_assert_true(stopped[0] == 2, "predelete after tree exit must not emit another playback stop")
	_assert_true(fixture.mesh.get_surface_override_material(0) == replacement, "repeated cleanup must preserve a later external material replacement")
	fixture.host.free()


func _test_screen_standby_color_and_power_lifecycle() -> void:
	var fixture := _new_screen(QuadMesh.new())
	var screen: Node3D = fixture.screen
	var has_power_api := screen.has_method("set_standby_color") and screen.has_method("power_off") and screen.has_method("power_on") and screen.has_method("is_powered_on") and screen.has_signal("power_changed")
	_assert_true(has_power_api, "screen exposes configurable standby and explicit observable power state")
	if not has_power_api:
		fixture.host.free()
		return
	var power_events: Array[bool] = []
	var stopped := [0]
	screen.connect("power_changed", func(powered_on: bool) -> void: power_events.append(powered_on))
	screen.connect("playback_stopped", func() -> void: stopped[0] += 1)
	var player := screen.find_children("*", "VideoStreamPlayer", true, false)[0] as VideoStreamPlayer
	var viewport := player.get_parent() as SubViewport
	var material := fixture.mesh.get_surface_override_material(0) as StandardMaterial3D
	_assert_true(screen.is_powered_on(), "new screen starts powered on in standby")
	screen.power_on()
	_assert_true(power_events.is_empty(), "power_on is idempotent on an already powered screen")
	var standby := Color(0.12, 0.8, 0.3)
	screen.set_standby_color(standby)
	_assert_true(material.albedo_color == standby and material.albedo_texture == null, "changing standby color immediately updates an idle screen")
	player.visible = true
	material.albedo_color = Color.WHITE
	material.albedo_texture = viewport.get_texture()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var next_standby := Color(0.08, 0.65, 0.22)
	screen.set_standby_color(next_standby)
	_assert_true(material.albedo_color == Color.WHITE and material.albedo_texture is ViewportTexture, "changing standby color must not tint or interrupt an active video display")
	screen.power_off()
	screen.power_off()
	_assert_true(not screen.is_powered_on() and power_events == [false], "power_off changes state and emits exactly once")
	_assert_true(stopped[0] == 1 and not player.visible and viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "power_off stops an active display exactly once")
	_assert_true(material.albedo_color == Color.BLACK and material.albedo_texture == null, "powered-off screen is black without a retained video frame")
	screen.set_standby_color(standby)
	screen.stop()
	player.finished.emit()
	_assert_true(material.albedo_color == Color.BLACK and not screen.is_powered_on(), "stop, late finish, and standby configuration cannot power up a switched-off screen")
	_assert_true(not screen.play(), "no-stream play request still fails safely while powered off")
	_assert_true(not screen.is_powered_on() and power_events == [false], "failed play must not power on the screen or local light")
	screen.power_on()
	screen.power_on()
	_assert_true(screen.is_powered_on() and power_events == [false, true], "power_on restores power exactly once")
	_assert_true(material.albedo_color == standby and material.albedo_texture == null and not player.visible, "power_on restores configured standby without autoplay")
	_assert_true(viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED, "standby never needs continuous viewport rendering")
	fixture.host.free()


func _new_door(duration: float, attach_component: bool = true) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var pivot := Node3D.new()
	pivot.rotation.y = 0.25
	host.add_child(pivot)
	var body := StaticBody3D.new()
	host.add_child(body)
	var blocker := CollisionShape3D.new()
	blocker.shape = BoxShape3D.new()
	body.add_child(blocker)
	var door: Node3D = _door_script.new()
	if attach_component:
		host.add_child(door)
	door.bind(pivot, blocker, 90.0, duration)
	return {"host": host, "door": door, "pivot": pivot, "blocker": blocker}


func _new_screen(mesh_resource: Mesh, attach_component: bool = true) -> Dictionary:
	var host := Node3D.new()
	root.add_child(host)
	var mesh := MeshInstance3D.new()
	mesh.mesh = mesh_resource
	host.add_child(mesh)
	var screen: Node3D = _screen_script.new()
	if attach_component:
		host.add_child(screen)
	screen.bind_screen(mesh)
	return {"host": host, "screen": screen, "mesh": mesh}


func _assert_true(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)


func _assert_near(actual: float, expected: float, message: String) -> void:
	_assert_true(absf(actual - expected) < 0.001, "%s (expected %.3f, got %.3f)" % [message, expected, actual])
