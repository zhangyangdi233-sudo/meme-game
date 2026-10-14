extends "res://tools/capture_chapter1.gd"


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Profiling requires a real renderer")
		quit(2)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = OUTPUT.path_join("profile_chapter1_save.dat")
	viewport.add_child(main)
	var samples: Array = []
	var load_start := Time.get_ticks_usec()
	main.start_chapter1_game()
	samples.append(await _measure("opening", Time.get_ticks_usec() - load_start))
	load_start = Time.get_ticks_usec()
	main._begin_game_session(_fixture(0), {}, false)
	samples.append(await _measure("basement", Time.get_ticks_usec() - load_start))
	var file := FileAccess.open(OUTPUT.path_join("chapter1_performance_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({
		"renderer": RenderingServer.get_video_adapter_name(),
		"resolution": "1600x900",
		"method": "Hidden real Forward+ viewport, 3 s warm-up + 10 s monotonic frame samples per stage. RenderingServer.force_draw() each frame ensures hidden viewport is rendered; timings include its synchronization overhead and are not a visible-window benchmark.",
		"samples": samples,
	}, "\t"))
	file.close()
	main.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame
	print("chapter1 steady render profiling complete")
	quit(0)


func _measure(stage: String, load_usec: int) -> Dictionary:
	main._set_reality_mouse_look(false)
	if stage == "basement":
		var tv: Vector3 = main._reality_floor.anchor_world_position("TVAnchor")
		_look_from(Vector3(0, 0.03, 2), tv + Vector3(0, 0.30, 0))
	var warm_start := Time.get_ticks_usec()
	while Time.get_ticks_usec() - warm_start < 3000000:
		await process_frame
		RenderingServer.force_draw()
	var frames: Array[float] = []
	var cpu: Array[float] = []
	var start := Time.get_ticks_usec()
	var previous := start
	while Time.get_ticks_usec() - start < 10000000:
		await process_frame
		RenderingServer.force_draw()
		var now := Time.get_ticks_usec()
		frames.append(float(now - previous) / 1000.0)
		cpu.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		previous = now
	var elapsed := float(Time.get_ticks_usec() - start) / 1000000.0
	frames.sort()
	cpu.sort()
	var screenshot := "chapter1_profile_%s.png" % stage
	viewport.get_texture().get_image().save_png(OUTPUT.path_join(screenshot))
	var sample := {
		"stage": stage, "load_ms": float(load_usec) / 1000.0,
		"duration_seconds": elapsed, "frames": frames.size(),
		"mean_fps": float(frames.size()) / elapsed,
		"frame_ms_p50": _percentile(frames, 0.50),
		"frame_ms_p95": _percentile(frames, 0.95),
		"frame_ms_p99": _percentile(frames, 0.99),
		"frame_ms_max": frames.back(),
		"engine_cpu_ms_p50": _percentile(cpu, 0.50),
		"screenshot": screenshot,
	}
	print("PROFILE ", JSON.stringify(sample))
	return sample


func _percentile(values: Array[float], quantile: float) -> float:
	return values[clampi(int(ceil(float(values.size()) * quantile)) - 1, 0, values.size() - 1)]
