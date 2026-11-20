extends SceneTree
## The basement carpet's footsteps (ported from the old version's numbers): the four real contacts load from their wav
## files at -20 dB; one contact per 1.95 m walking, shortening to 1.90 m at sprint speed; the samples cycle 1 to 4 with
## the pitch cycle; a contact in progress is never cut (the next is skipped); a jump over 1.5 m resets and stops audio.
## Through the Reality scene adapter: only in a basement round, the phone down, settings closed, outside the CRT
## terminal and a conversation, on the room's floor below y 0.3 (the stairs stay silent). Does not load the main scene.

const CarpetFootstepsScript = preload("res://scripts/world/carpet_footsteps.gd")
const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const ProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")

const STEP := 1.0 / 30.0
## 3 m/s: under the walking speed, so the stride is the walking one.
const WALK_FRAME := 0.1

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	await _run()
	if _failures.is_empty():
		print("carpet footsteps tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	for action_name in ["reality_forward", "reality_back", "reality_left", "reality_right", "reality_sprint"]:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)
	await _test_the_four_contacts_load_quietly()
	await _test_walking_makes_one_contact_per_stride()
	await _test_sprinting_shortens_the_stride()
	await _test_samples_and_pitch_cycle()
	await _test_a_playing_contact_is_never_cut()
	await _test_conditions_and_jumps_reset_and_silence()
	await _test_the_adapter_gates_the_footsteps()
	# Headless frames can end before the audio thread releases stopped playbacks.
	await create_timer(0.15).timeout
	await process_frame


func _foley() -> Node:
	var foley := CarpetFootstepsScript.new()
	root.add_child(foley)
	return foley


## Walks `meters` along x in 0.5 m frames at the walking speed and returns the new x.
func _walk(foley: Node, from_x: float, meters: float, enabled := true, grounded := true) -> float:
	var x := from_x
	var frames := int(round(meters / 0.5))
	for frame in frames:
		x += 0.5
		foley.advance(Vector3(x, 0.0, 0.0), enabled, grounded, 0.5 / 3.3)
	return x


func _test_the_four_contacts_load_quietly() -> void:
	var foley := _foley()
	_assert_eq(foley._steps.size(), 4, "all four carpet contacts should load")
	_assert_true(is_equal_approx(foley._audio.volume_db, -20.0), "the footsteps should sit at -20 dB")
	for clip: AudioStreamWAV in foley._steps:
		_assert_true(clip.get_length() <= 0.28, "one contact should end within 280 ms")
		_assert_eq(clip.loop_mode, AudioStreamWAV.LOOP_DISABLED, "a contact should never loop")
	_assert_true(FileAccess.file_exists("res://assets/audio/foley/LICENSE.md"), "the CC0 licence should ship with the recordings")
	foley.free()
	await process_frame


func _test_walking_makes_one_contact_per_stride() -> void:
	var foley := _foley()
	foley.advance(Vector3.ZERO, true, true, 0.1)
	_assert_eq(foley.step_count, 0, "the first frame only records the position")
	var x := _walk(foley, 0.0, 1.5)
	_assert_eq(foley.step_count, 0, "less than a stride should make no contact")
	x = _walk(foley, x, 0.5)
	_assert_eq(foley.step_count, 1, "walking 1.95 m should make one contact")
	_assert_true(foley.is_stepping(), "the contact should be playing")
	foley._audio.stop()
	x = _walk(foley, x, 1.5)
	_assert_eq(foley.step_count, 1, "the distance restarts after a contact (the remainder carries over)")
	foley.advance(Vector3(x, 0.0, 0.0), true, true, 0.1)
	_assert_eq(foley.step_count, 1, "standing still should make no contact")
	foley.free()
	await process_frame


func _test_sprinting_shortens_the_stride() -> void:
	var foley := _foley()
	foley.advance(Vector3.ZERO, true, true, 0.1)
	# 6.105 m/s: two frames of 0.96 m pass the 1.90 m sprint stride, short of the 1.95 m walking one.
	var delta: float = 0.96 / foley.sprint_speed
	foley.advance(Vector3(0.96, 0.0, 0.0), true, true, delta)
	foley.advance(Vector3(1.92, 0.0, 0.0), true, true, delta)
	_assert_eq(foley.step_count, 1, "sprinting should make a contact every 1.90 m")
	_assert_true(is_equal_approx(foley.stride_for_speed(foley.walk_speed), 1.95), "walking speed should use the 1.95 m stride")
	_assert_true(is_equal_approx(foley.stride_for_speed(foley.sprint_speed), 1.90), "sprint speed should use the 1.90 m stride")
	_assert_true(is_equal_approx(foley.stride_for_speed(0.0), 1.95), "a slower speed should keep the walking stride")
	foley.walk_speed = 2.0
	foley.sprint_speed = 4.0
	_assert_true(is_equal_approx(foley.stride_for_speed(3.0), 1.925), "the stride should lerp between the speeds this player has")
	foley.free()
	await process_frame


func _test_samples_and_pitch_cycle() -> void:
	var foley := _foley()
	foley.advance(Vector3.ZERO, true, true, 0.1)
	var x := 0.0
	var pitches := [0.97, 1.02, 0.99, 1.04]
	for contact in 5:
		foley._audio.stop()
		x = _walk(foley, x, 2.0)
		_assert_eq(foley._audio.stream, foley._steps[contact % 4], "contact %d should play sample %d" % [contact + 1, contact % 4 + 1])
		_assert_true(is_equal_approx(foley._audio.pitch_scale, pitches[contact % 4]), "contact %d should use pitch %s" % [contact + 1, str(pitches[contact % 4])])
	foley.free()
	await process_frame


func _test_a_playing_contact_is_never_cut() -> void:
	var foley := _foley()
	foley.advance(Vector3.ZERO, true, true, 0.1)
	var x := _walk(foley, 0.0, 2.0)
	_assert_eq(foley.step_count, 1, "sanity: the first contact plays")
	var stream = foley._audio.stream
	x = _walk(foley, x, 2.0)
	_assert_eq(foley.step_count, 1, "a stride reached while a contact plays should be skipped, not counted")
	_assert_true(foley._audio.stream == stream and foley._audio.playing, "the contact in progress should be left to finish")
	foley.free()
	await process_frame


func _test_conditions_and_jumps_reset_and_silence() -> void:
	var foley := _foley()
	foley.advance(Vector3.ZERO, true, true, 0.1)
	var x := _walk(foley, 0.0, 2.0)
	_assert_true(foley._audio.playing, "sanity: a contact plays")
	x = _walk(foley, x, 0.5, false, true)
	_assert_true(not foley._audio.playing, "a disabled frame should stop the audio")
	x = _walk(foley, x, 1.5, true, true)
	_assert_eq(foley.step_count, 1, "a disabled frame should reset the distance walked")
	x = _walk(foley, x, 0.5, true, true)
	_assert_eq(foley.step_count, 2, "walking a whole stride after the reset should step again")
	foley._audio.stop()
	x = _walk(foley, x, 2.0, true, false)
	_assert_eq(foley.step_count, 2, "an airborne player should make no contact")
	foley._audio.stop()
	x += 5.0
	foley.advance(Vector3(x, 0.0, 0.0), true, true, 0.1)
	_assert_eq(foley.step_count, 2, "a frame jump over 1.5 m is a teleport and makes no step")
	x = _walk(foley, x, 1.5)
	_assert_eq(foley.step_count, 2, "after a teleport the distance starts from zero")
	foley.reset()
	foley.advance(Vector3(100.0, 0.0, 0.0), true, true, 0.1)
	_assert_eq(foley.step_count, 2, "after reset the first frame only records the position")
	_assert_true(CarpetFootstepsScript.on_carpet(Vector3(0.0, 0.29, 0.0)) and not CarpetFootstepsScript.on_carpet(Vector3(0.0, 0.3, 0.0)), "the carpet ends at y 0.3, where the stairs begin")
	foley.free()
	await process_frame


## The adapter ticks the footsteps where the player and the stage kind already are.
func _test_the_adapter_gates_the_footsteps() -> void:
	var round_one := _deps(ProgressScript.jump_to_round(ProgressScript.initial(), 1))
	var adapter = await _adapter_with(round_one)
	var foley = adapter._footsteps
	_assert_true(is_equal_approx(foley.walk_speed, adapter.MOVE_SPEED) and is_equal_approx(foley.sprint_speed, adapter.MOVE_SPEED * adapter.SPRINT_MULTIPLIER), "the footsteps should use the player's real walk and sprint speeds")
	await _settle(adapter, round_one)
	_assert_true(adapter.player.position.y < 0.3 and adapter.player.is_on_floor(), "sanity: the player stands on the room's floor")
	var before: int = foley.step_count
	await _stroll(adapter, round_one, 26)
	_assert_true(foley.step_count > before, "walking the room's floor should step")

	before = foley.step_count
	var phone_up := round_one.duplicate()
	phone_up["view_state"] = "phone_down"
	await _stroll(adapter, phone_up, 26)
	_assert_eq(foley.step_count, before, "the phone raised should keep the room silent")

	adapter.set_paused(true)
	await _stroll(adapter, round_one, 26)
	_assert_eq(foley.step_count, before, "open settings (or a lost focus) should keep the room silent")
	adapter.set_paused(false)

	adapter._terminal_active = true
	await _stroll(adapter, round_one, 26)
	_assert_eq(foley.step_count, before, "the CRT terminal entered should keep the room silent")
	adapter._terminal_active = false

	adapter._interaction_active = true
	await _stroll(adapter, round_one, 26)
	_assert_eq(foley.step_count, before, "a conversation should keep the room silent")
	adapter._interaction_active = false

	adapter._exit_time = 0.0
	await _stroll(adapter, round_one, 26)
	_assert_eq(foley.step_count, before, "an exit transition should keep the room silent")
	adapter._exit_time = -1.0

	await _stroll(adapter, round_one, 26)
	_assert_true(foley.step_count > before, "the conditions lifted should let the room step again")

	# The wooden stairs: the same walk at their height stays silent.
	before = foley.step_count
	adapter.player.position = Vector3(-2.5, 1.5, 0.5)
	await _settle(adapter, round_one)
	_assert_true(adapter.player.position.y >= 0.3, "sanity: the player stands on the stairs")
	await _stroll(adapter, round_one, 8, Vector3(0.0, 0.0, -0.1), Vector3(-2.5, 1.5, 0.5))
	_assert_eq(foley.step_count, before, "the wooden stairs should stay silent")
	await _free(adapter)

	var opening := _deps(ProgressScript.initial())
	adapter = await _adapter_with(opening)
	foley = adapter._footsteps
	await _settle(adapter, opening)
	await _stroll(adapter, opening, 26)
	_assert_eq(foley.step_count, 0, "outside a basement round there should be no carpet")
	await _free(adapter)


func _adapter_with(deps: Dictionary):
	var host := Node3D.new()
	host.name = "FootstepsHost"
	root.add_child(host)
	var adapter = RealitySceneAdapterScript.new()
	adapter.attach_to(host)
	adapter.build_world_nodes()
	adapter.rebuild_floor(deps)
	await process_frame
	return adapter


func _free(adapter) -> void:
	adapter.get_parent().free()
	await process_frame


func _deps(progress: Dictionary) -> Dictionary:
	var round_number := ProgressScript.round_of(progress)
	var room := RoomContentScript.room(round_number)
	return {
		"day_progress": {"tower_floor": 1, "day": 1},
		"chapter_one_progress": progress,
		"view_state": "npc_up",
		"room_state": RoomRulesScript.world_state(room, {}, round_number, ProgressScript.started_events(progress), ProgressScript.ended_events(progress)),
		"room_events": room.get("events", []),
		"run_seed": 1701,
	}


## Puts a player at the room's floor (when it spawned on the landing) and lets it settle on the ground.
func _settle(adapter, deps: Dictionary) -> void:
	if adapter.player.position.y > 1.0 and adapter.player.position.y == adapter._chapter_stage.start_position().y:
		adapter.player.position = Vector3(-1.0, 0.05, 1.5)
	for frame in 6:
		await physics_frame
		adapter.update_player(STEP, deps)


## Moves the player `frames` frames by `per_frame` (3 m/s by default, along x) from `start`, ticking the adapter each
## frame. Every stroll starts from the same spot so none leaves the room's bounds.
func _stroll(adapter, deps: Dictionary, frames: int, per_frame := Vector3(WALK_FRAME, 0.0, 0.0), start := Vector3(-1.0, 0.05, 1.5)) -> void:
	adapter.player.position = start
	await physics_frame
	adapter.update_player(0.1 / 3.0, deps)
	for frame in frames:
		adapter.player.position += per_frame
		await physics_frame
		adapter.update_player(0.1 / 3.0, deps)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
