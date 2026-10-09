extends SceneTree

const OUTPUT_DIR := "D:/aphasia/outputs/basement_integration_audit"
var main
var failures: Array[String] = []
var evidence: Array = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	main = load("res://scenes/babel_meme_game.tscn").instantiate()
	main._save_path = OUTPUT_DIR.path_join("walk_test_save.dat")
	root.add_child(main)
	main.start_chapter1_game()
	main._set_reality_mouse_look(false)
	if not main._chapter_world_ready:
		failures.append("Opening asset binding failed")
		await _finish()
		return
	var opening_spawn: Vector3 = main._reality_player.position
	var arrival := _anchor("DoorArrival")
	_check(absf(opening_spawn.distance_to(Vector3(arrival.x, opening_spawn.y, arrival.z)) - 17.35) < 1.0, "opening retains 18 m door composition")
	_check(not main.game.chapter1_progress.opening_knock_completed, "opening starts before its knock completes")
	_check(not main._try_reality_interaction(), "early F cannot request the door transition")
	var wait_started := Time.get_ticks_msec()
	# Exercise actual exploration time and the audio finished callback. Do not
	# advance the timer manually or synthesize a trusted completion event.
	while not main.game.chapter1_progress.opening_knock_completed and Time.get_ticks_msec() - wait_started < 30000:
		await physics_frame
	_check(main.game.chapter1_progress.opening_knock_completed, "ten-second wait and real knock playback complete")
	evidence.append({"step": "wait for opening knock", "ms": Time.get_ticks_msec() - wait_started, "completed": main.game.chapter1_progress.opening_knock_completed})
	if not main.game.chapter1_progress.opening_knock_completed:
		await _finish()
		return
	_check(main.game.chapter1_progress.phase == "opening" and not main._reality_floor.get_door("opening").is_passable(), "finished knock still waits for nearby F")
	await _walk_to(Vector3(arrival.x, 0.02, arrival.z + 1.2), "approach opening after knock")
	main._refresh_nearby_reality_actor()
	_check(main._nearby_reality_actor != null and str(main._nearby_reality_actor.get_meta("actor_type", "")) == "chapter1_opening", "approaching the door selects its F action")
	var interact_key := InputEventKey.new()
	interact_key.keycode = KEY_F
	interact_key.physical_keycode = KEY_F
	interact_key.pressed = true
	main._unhandled_input(interact_key)
	var transition_started := Time.get_ticks_msec()
	while main.game.chapter1_progress.phase == "opening" and Time.get_ticks_msec() - transition_started < 8000:
		await physics_frame
	_check(main.game.chapter1_progress.phase == "basement", "nearby F and its cinematic enter the basement without crossing the door")
	while main._input_locked and Time.get_ticks_msec() - transition_started < 10000:
		await physics_frame
	evidence.append({"step": "opening F cinematic", "ms": Time.get_ticks_msec() - transition_started, "phase": main.game.chapter1_progress.phase})
	await _frames(3)
	for visit in range(5):
		print("physical walk: basement visit %d" % (visit + 1))
		var failures_before := failures.size()
		if main.game.chapter1_progress.phase != "basement" or not main._chapter_world_ready:
			failures.append("Basement visit %d failed to load" % (visit + 1))
			break
		_check(int(main.game.chapter1_progress.round_index) == visit, "correct visit %d" % (visit + 1))
		var top := _anchor("EntrySpawn")
		_check(main._reality_player.position.distance_to(top) < 0.25, "visit starts at actual stairs anchor")
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/chapter1/asset_contract.json"))
		var stairs: Dictionary = contract.stairs
		var room: Dictionary = contract.room
		var stair_x := (float(stairs.x_min) + float(stairs.x_max)) * 0.5
		var front_z := -float(room.y_min) - 0.70
		var right_x := float(room.x_max) - 0.65
		var npc := _anchor("NPCAnchor")
		# Route follows the authored staircase and the right-hand passage. All
		# waypoints derive from the delivered contract or imported marker nodes.
		await _walk_to(Vector3(stair_x, 0.02, -float(stairs.bottom_y) + 0.45), "visit %d stairs" % (visit + 1))
		_check(main.game.chapter1_progress.entrance_locked, "entry sealed after first stair")
		await _verify_reload("visit %d sealed stairs" % (visit + 1))
		await _walk_to(Vector3(stair_x, 0.02, front_z), "front of stairs")
		await _walk_to(Vector3(0.0, 0.02, front_z), "front TV zone")
		await _walk_to(Vector3(right_x, 0.02, front_z - 0.85), "turn along TV")
		await _walk_to(Vector3(right_x, 0.02, npc.z), "right passage")
		await _walk_to(Vector3(npc.x + 1.0, 0.02, npc.z), "approach current NPC")
		var token := int(main.game.chapter1_progress.transition_serial)
		var premature: Dictionary = main.notify_chapter1("basement_exit_requested", {"round_token": token})
		_check(not premature.accepted, "exit denies incomplete help")
		var task_id := "basement_help_%02d" % (visit + 1)
		var npc_id := "basement_npc_%02d" % (visit + 1)
		var completed: Dictionary = main.notify_chapter1("npc_help_completed", {"round_token": token, "task_id": task_id, "npc_id": npc_id})
		_check(completed.accepted, "explicit development task completion accepted")
		await _verify_reload("visit %d completed help" % (visit + 1))
		var exit := _anchor("ExitThreshold")
		await _walk_to(Vector3(exit.x + 1.05, 0.02, exit.z), "approach basement exit")
		main._refresh_nearby_reality_actor()
		main._try_reality_interaction()
		await _frames(45)
		var world_id: int = main._reality_floor.get_instance_id()
		var tunnel := main._reality_floor.find_child("BasementExitTunnel", true, false) as Node3D
		_check(tunnel != null, "visit %d provides a physical exit tunnel" % (visit + 1))
		if tunnel == null:
			await _finish()
			return
		await _walk_to(tunnel.to_global(Vector3(0, 0.02, -0.6)), "visit %d crosses old exit without transfer" % (visit + 1))
		_check(main._reality_floor.get_instance_id() == world_id and int(main.game.chapter1_progress.transition_serial) == token and int(main.game.chapter1_progress.round_index) == visit, "the old exit preserves the same world and visit")
		_check(not main.game.chapter1_progress.exit_tunnel_entered, "the old exit does not seal before the whole body clears the hinge")
		await _walk_to(tunnel.to_global(Vector3(0, 0.02, -6.0)), "visit %d walks to tunnel midpoint" % (visit + 1))
		_check(main._reality_floor.get_instance_id() == world_id and int(main.game.chapter1_progress.transition_serial) == token and main.game.chapter1_progress.exit_tunnel_entered, "walking the tunnel marks progress without rebuilding or advancing")
		_check(not main._reality_floor.get_door("exit").is_passable(), "the cleared basement exit seals behind the player")
		await _verify_reload("visit %d tunnel midpoint" % (visit + 1))
		tunnel = main._reality_floor.find_child("BasementExitTunnel", true, false) as Node3D
		_check(main.game.chapter1_progress.exit_tunnel_entered and not main._reality_floor.get_door("tunnel").is_passable(), "reloaded tunnel retains its checkpoint and a closed white door")
		var actors: Array = main._reality_floor.get_interactable_actors()
		_check(actors.size() == 1 and str(actors[0].get_meta("actor_type", "")) == "chapter1_tunnel_door", "tunnel exposes only the distant white-door interaction")
		await _walk_to(tunnel.interaction_position(), "visit %d approaches white door" % (visit + 1))
		_check(int(main.game.chapter1_progress.transition_serial) == token, "walking the full tunnel cannot advance before F")
		main._refresh_nearby_reality_actor()
		_check(main._nearby_reality_actor != null and str(main._nearby_reality_actor.get_meta("actor_type", "")) == "chapter1_tunnel_door", "nearby F selects the white door")
		var white_key := InputEventKey.new()
		white_key.keycode = KEY_F
		white_key.physical_keycode = KEY_F
		white_key.pressed = true
		main._unhandled_input(white_key)
		var white_started := Time.get_ticks_msec()
		await _frames(3)
		_check(main._input_locked and int(main.game.chapter1_progress.transition_serial) == token, "F begins the white-door animation while retaining the current visit")
		while int(main.game.chapter1_progress.transition_serial) == token and Time.get_ticks_msec() - white_started < 8000:
			await physics_frame
		var expected := "crossroads" if visit == 4 else "basement"
		_check(main.game.chapter1_progress.phase == expected and int(main.game.chapter1_progress.transition_serial) == token + 1, "visit %d white-door transfer advances exactly once" % (visit + 1))
		while main._input_locked and Time.get_ticks_msec() - white_started < 10000:
			await physics_frame
		_check(not main._input_locked, "white-door fade-in releases movement")
		evidence.append({"step": "visit %d white-door F transfer" % (visit + 1), "ms": Time.get_ticks_msec() - white_started, "phase": main.game.chapter1_progress.phase, "token": main.game.chapter1_progress.transition_serial})
		print("physical walk: white door %d -> %s; token %d; visit failures %d" % [visit + 1, main.game.chapter1_progress.phase, main.game.chapter1_progress.transition_serial, failures.size() - failures_before])
		if failures.size() > failures_before:
			await _finish()
			return
		await _frames(3)
	_check(main.game.chapter1_progress.phase == "crossroads", "fifth tunnel white door reaches crossroads")
	_check(main.game.chapter1_progress.unlocked_app_ids == ["social", "notebook", "babel"], "development 1/3/5 reward mapping preserves all three app permissions")
	_check(main.game.chapter1_progress.gate_item_ids.is_empty(), "the route does not recreate obsolete gate-item rewards")
	_check(main.game.collected_prerequisite_item_ids.is_empty(), "old hidden-ending items untouched")
	if main.game.chapter1_progress.phase == "crossroads":
		await _verify_reload("crossroads with all app permissions")
		_check(main._reality_floor.find_child("CrossRoad", true, false) != null, "existing crossroads geometry present")
		var gate: Area3D = null
		for actor in main._reality_floor.get_interactable_actors():
			if str(actor.get_meta("actor_type", "")) == "chapter1_gate":
				gate = actor
				break
		if gate != null:
			await _walk_to(gate.global_position + Vector3(0, 0, 1.2), "crossroads far gate")
			main._refresh_nearby_reality_actor()
			main._try_reality_interaction()
			await _frames(45)
			await _walk_to(gate.global_position + Vector3(0, 0, -2.0), "enter next layer", "tower")
		else:
			failures.append("Crossroads gate interaction missing")
	_check(main.game.chapter1_progress.phase == "tower" and main.game.tower_floor == 2, "chapter gate joins existing next layer")
	await _finish()


func _anchor(node_name: String) -> Vector3:
	var marker := main._reality_floor.find_child(node_name, true, false) as Node3D
	if marker == null:
		failures.append("Missing actual anchor " + node_name)
		return main._reality_player.position
	return marker.global_position


func _walk_to(target: Vector3, label: String, expected_phase: String = "", prior_token: int = -1) -> bool:
	var started := Time.get_ticks_msec()
	var position_before: Vector3 = main._reality_player.position
	var previous: Vector3 = position_before
	var stalled := 0
	for frame in 5000:
		var phase: String = main.game.chapter1_progress.phase
		if not expected_phase.is_empty() and phase == expected_phase and (prior_token < 0 or int(main.game.chapter1_progress.transition_serial) != prior_token):
			Input.action_release("reality_forward")
			evidence.append({"step": label, "transition": phase, "ms": Time.get_ticks_msec() - started})
			return true
		var offset: Vector3 = target - main._reality_player.position
		offset.y = 0.0
		if offset.length() < 0.12:
			Input.action_release("reality_forward")
			if not expected_phase.is_empty():
				await _frames(3)
				if main.game.chapter1_progress.phase != expected_phase or (prior_token >= 0 and int(main.game.chapter1_progress.transition_serial) == prior_token):
					failures.append("Reached target without required transition: " + label)
					return false
			evidence.append({"step": label, "position": str(main._reality_player.position), "ms": Time.get_ticks_msec() - started})
			return true
		main._reality_yaw = rad_to_deg(atan2(-offset.x, -offset.z))
		Input.action_press("reality_forward")
		await physics_frame
		if main._reality_player.position.distance_to(previous) < 0.002:
			stalled += 1
		else:
			stalled = 0
		previous = main._reality_player.position
		if stalled > 90:
			break
	Input.action_release("reality_forward")
	var failure := "Walk blocked: %s at %s targeting %s" % [label, str(main._reality_player.position), str(target)]
	failures.append(failure)
	print(failure)
	return false


func _frames(count: int) -> void:
	for frame in count:
		await physics_frame


func _verify_reload(label: String) -> void:
	var position_before: Vector3 = main._reality_player.position
	var progress_before: Dictionary = main.game.chapter1_progress.duplicate(true)
	_check(main._save_progress(), label + " save writes")
	_check(main.continue_game(), label + " continue loads")
	main._set_reality_mouse_look(false)
	await _frames(2)
	_check(main.game.chapter1_progress == progress_before, label + " restores exact progress")
	_check(main._reality_player.position.distance_to(position_before) < 0.15, label + " restores physical location")
	evidence.append({"step": "save and continue: " + label, "position": str(main._reality_player.position)})


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		print("CHECK FAILED: " + message)


func _finish() -> void:
	Input.action_release("reality_forward")
	var file := FileAccess.open(OUTPUT_DIR.path_join("chapter1_walk_results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed": failures.is_empty(), "failures": failures, "steps": evidence}, "\t"))
	file.close()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("chapter1 physical walk passed")
	if is_instance_valid(main):
		main.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
