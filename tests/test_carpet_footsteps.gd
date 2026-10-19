extends SceneTree

var failures := 0
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var script = load("res://scripts/world/carpet_footsteps.gd")
	if script == null:
		push_error("carpet footsteps component must exist")
		quit(1)
		return
	var foley = script.new()
	root.add_child(foley)
	_check(foley._steps.size() == 4, "all four actual PCM carpet clips must load")
	_check(is_equal_approx(foley._audio.volume_db, -20.0), "fix material timbre rather than hiding it with lower volume")
	for clip in foley._steps:
		_check(clip.get_length() <= 0.28, "one recorded foot contact should finish within 280 ms")
		_check(clip.loop_mode == AudioStreamWAV.LOOP_DISABLED, "foot contacts must never loop")
	foley.advance(Vector3.ZERO, true, true)
	foley.advance(Vector3(0.5, 0, 0), true, true)
	_check(foley.step_count == 0, "short motion should not play a full step")
	foley.advance(Vector3(1.0, 0, 0), true, true)
	_check(foley.step_count == 0, "a partial natural walking stride creates no contact")
	foley.advance(Vector3(2.0, 0, 0), true, true)
	_check(foley.step_count == 1, "walking a stride produces a step")
	_check(foley._audio.playing, "the real AudioStreamPlayer starts the clip")
	var playing_stream = foley._audio.stream
	foley.advance(Vector3(3.0, 0, 0), true, true)
	foley.advance(Vector3(4.0, 0, 0), true, true)
	_check(foley.step_count == 1 and foley._audio.stream == playing_stream, "rapid displacement must not restart or replace an unfinished contact")
	await create_timer(0.55).timeout
	_check(not foley._audio.playing, "a one-shot completes without a second impact or looping")
	foley.advance(Vector3(5.0, 0, 0), true, true)
	foley.advance(Vector3(6.0, 0, 0), true, true)
	_check(foley.step_count == 2, "movement after completion can play the next variation")
	foley.advance(Vector3(6.0, 0, 0), true, true)
	_check(foley.step_count == 2, "standing still creates no contact")
	foley.advance(Vector3(7.0, 0, 0), true, false)
	_check(foley.step_count == 2 and not foley._audio.playing, "airborne player stops foot audio")
	foley.advance(Vector3(8.0, 0, 0), false, true)
	_check(foley.step_count == 2, "pause, terminal and other floors stay silent")
	foley.advance(Vector3(30, 0, 0), true, true)
	_check(foley.step_count == 2, "scene teleport produces no step")
	_check(foley.has_method("_stride_for_speed"), "walk and run should use speed-dependent contact timing")
	if foley.has_method("_stride_for_speed"):
		var walking_interval: float = foley._stride_for_speed(3.3) / 3.3
		var running_interval: float = foley._stride_for_speed(6.105) / 6.105
		_check(walking_interval >= 0.54 and walking_interval <= 0.65, "walking should match the real recording's natural approximately 0.59 second contact interval")
		_check(running_interval >= 0.28 and running_interval < walking_interval, "running should be quicker without a machine-gun rhythm")
		for clip in foley._steps:
			_check(clip.get_length() / 0.97 + 0.02 < running_interval, "even the lowest playback pitch must finish before the next running contact")
	foley.free()
	await process_frame
	print("carpet footsteps: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)
