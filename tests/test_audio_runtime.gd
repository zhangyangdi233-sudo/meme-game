extends SceneTree

const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const SCORE_METADATA_PATH := "res://assets/generated/audio/babel_liminal_score.json"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("audio runtime tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load for audio runtime test")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	await process_frame
	game_root.new_game()
	await process_frame

	var phone := game_root.get_node_or_null("PhoneRoadAmbience") as AudioStreamPlayer
	var reality := game_root.get_node_or_null("RealityRoomAmbience") as AudioStreamPlayer
	var pollution_music := game_root.get_node_or_null("PollutionMusicLayer") as AudioStreamPlayer
	var flashback := game_root.get_node_or_null("PollutionFlashbackAudio") as AudioStreamPlayer
	var action_tick := game_root.get_node_or_null("ActionTickAudio") as AudioStreamPlayer
	var cover_watcher_stinger := game_root.get_node_or_null("CoverWatcherStinger") as AudioStreamPlayer
	_assert_true(phone != null and phone.playing, "phone ambience should start when gameplay enters the tree")
	_assert_true(reality != null and reality.playing, "reality ambience should stay running underneath the mix")
	_assert_true(pollution_music != null and pollution_music.playing, "phase-aligned pollution music should run silently until needed")
	if phone != null and reality != null:
		_assert_true(phone.volume_db > reality.volume_db, "phone view should begin with the road layer in front")
		_assert_true(str(phone.get_meta("generated_audio_path", "")).contains("babel_phone_signal"), "phone view should use the new original signal score")
		_assert_true(str(reality.get_meta("generated_audio_path", "")).contains("babel_reality_liminal"), "reality view should use the new original liminal score")
	if pollution_music != null:
		_assert_true(str(pollution_music.get_meta("generated_audio_path", "")).contains("babel_pollution_rot"), "pollution should use its own original synchronized stem")
		_assert_near(pollution_music.volume_db, -60.0, 0.1, "low pollution should keep the corruption stem inaudible")
	_assert_true(cover_watcher_stinger != null, "the recurring cover watcher should own a dedicated one-shot player")
	if cover_watcher_stinger != null:
		var watcher_stream := cover_watcher_stinger.stream as AudioStreamWAV
		_assert_true(watcher_stream != null, "the watcher stinger should load as a generated WAV")
		if watcher_stream != null:
			_assert_true(watcher_stream.get_length() >= 2.0 and watcher_stream.get_length() <= 3.0, "the watcher stinger should end naturally within two to three seconds")
		_assert_true(not bool(cover_watcher_stinger.get_meta("looped", true)), "the watcher stinger must never loop")
	if phone != null and reality != null and pollution_music != null:
		var phone_stream := phone.stream as AudioStreamWAV
		var reality_stream := reality.stream as AudioStreamWAV
		var pollution_stream := pollution_music.stream as AudioStreamWAV
		_assert_true(phone_stream != null and reality_stream != null and pollution_stream != null, "all adaptive score stems should load as loopable WAV streams")
		if phone_stream != null and reality_stream != null and pollution_stream != null:
			_assert_eq(phone_stream.loop_end, reality_stream.loop_end, "phone and reality stems should share an exact loop frame count")
			_assert_eq(reality_stream.loop_end, pollution_stream.loop_end, "pollution should remain phase-aligned with the base score")
			_assert_true(phone_stream.loop_end == 2_116_800, "the original score should render an exact 96-second loop")
		_assert_true(absf(phone.get_playback_position() - reality.get_playback_position()) < 0.05, "phone and reality score stems should begin in sync")
		_assert_true(absf(reality.get_playback_position() - pollution_music.get_playback_position()) < 0.05, "pollution score stem should begin in sync with reality")
		var floor_paths: Dictionary = {}
		for floor_number in range(1, 5):
			game_root.game.tower_floor = floor_number
			game_root._sync_audio_state(true)
			var floor_path := str(phone.get_meta("generated_audio_path", ""))
			floor_paths[floor_path] = true
			_assert_eq(floor_path, game_root._audio_controller.phone_music_path_for_floor(floor_number), "each tower floor should select its authored phone score")
			_assert_eq(int(phone.get_meta("phone_music_floor", 0)), floor_number, "phone score metadata should follow the current floor")
			var floor_stream := phone.stream as AudioStreamWAV
			_assert_true(floor_stream != null and floor_stream.loop_end == 2_116_800, "every floor score should preserve the 96-second seamless loop contract")
		_assert_eq(floor_paths.size(), 4, "three formal floors and the hidden floor should use distinct phone music")
		game_root.game.tower_floor = 1
		game_root._sync_audio_state(true)
	_validate_score_metadata()

	game_root.game.pollution = 50
	game_root._sync_audio_state(true)
	if pollution_music != null:
		_assert_near(pollution_music.volume_db, float(PollutionStageScript.stage(50)["music_db"]), 0.1, "mid pollution should fade the corruption score into the mix")
	_assert_near(float(PollutionStageScript.stage(60)["music_db"]), -24.0, 0.1, "the 60 percent threshold should expose the pollution stem")
	_assert_near(float(PollutionStageScript.stage(100)["music_db"]), -3.0, 0.1, "maximum pollution should bring the corruption stem near the foreground")
	game_root.game.pollution = 0
	game_root._sync_audio_state(true)

	game_root.set_view_state("npc_up")
	await create_timer(0.65).timeout
	if phone != null and reality != null:
		_assert_true(reality.volume_db > phone.volume_db, "raising the camera should crossfade toward room ambience")
		_assert_near(reality.volume_db, -10.0, 0.2, "NPC speaking mix should reach its audible liminal-score target")

	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	var doll := game_root.get_node_or_null("RealityFloor/Actors/DollEncounter") as Area3D
	if player != null and doll != null:
		player.position = doll.position + Vector3(0.0, 0.0, 1.4)
		game_root._refresh_nearby_reality_actor()
		game_root._try_reality_interaction()
	var doll_choices: Array = game_root.game.get_typed_reality_choices()
	_assert_true(not doll_choices.is_empty(), "stitched doll conversation should expose choices for the intimate mix")
	if not doll_choices.is_empty():
		var first_choice_id := str(doll_choices[0].get("id", ""))
		game_root._on_reality_choice_selected(first_choice_id)
	await create_timer(0.65).timeout
	if reality != null:
		_assert_near(reality.volume_db, -7.0, 0.2, "player composing should make the room score more intimate")

	game_root._narrative_director.play_pollution_flashback()
	await process_frame
	_assert_true(flashback != null and flashback.playing, "pollution flashback should play its signal burst")
	if phone != null and reality != null:
		_assert_true(bool(phone.get_meta("flashback_ducked", false)), "flashback should duck the phone layer")
		_assert_true(bool(reality.get_meta("flashback_ducked", false)), "flashback should duck the reality layer")
	if pollution_music != null:
		_assert_true(bool(pollution_music.get_meta("flashback_ducked", false)), "flashback should duck the pollution music layer")
	game_root._narrative_director.finish_pollution_flashback()
	_assert_true(flashback != null and not flashback.playing, "finishing flashback should stop the signal burst")

	game_root._narrative_director.play_action_spend_animation(5, 4)
	await process_frame
	_assert_true(action_tick != null and action_tick.playing, "spending an action should play the short tick")
	game_root._narrative_director.finish_action_spend_animation()
	game_root._on_cover_watcher_appeared(1)
	await process_frame
	_assert_true(cover_watcher_stinger != null and cover_watcher_stinger.playing, "revealing the watcher should play its short horror cue")
	if cover_watcher_stinger != null:
		cover_watcher_stinger.stop()
	game_root.queue_free()
	await process_frame


func _validate_score_metadata() -> void:
	var metadata_text := FileAccess.get_file_as_string(SCORE_METADATA_PATH)
	_assert_true(not metadata_text.is_empty(), "score reproducibility metadata should be readable at runtime")
	if metadata_text.is_empty():
		return
	var parsed: Variant = JSON.parse_string(metadata_text)
	_assert_true(parsed is Dictionary, "score reproducibility metadata should contain valid JSON")
	if not parsed is Dictionary:
		return
	var metadata := parsed as Dictionary
	_assert_eq(int(metadata.get("format_version", 0)), 2, "score metadata should use the thematic-transform contract")
	_assert_near(float(metadata.get("duration_seconds", 0.0)), 96.0, 0.001, "score metadata should preserve the 96-second structure")
	_assert_eq(int(metadata.get("loop_end", 0)), 2_116_800, "score metadata should preserve the shared loop frame count")

	var creative_direction := metadata.get("creative_direction", {}) as Dictionary
	_assert_eq(str(creative_direction.get("reference_scope", "")), "High-level mood and production traits only", "reference use should be limited to high-level traits")
	var originality := metadata.get("originality", {}) as Dictionary
	_assert_true(not bool(originality.get("melody_transcribed", true)), "the score should not transcribe a reference melody")
	_assert_true(not bool(originality.get("samples_used", true)), "the score should not contain samples")
	_assert_true(not bool(originality.get("recordings_used", true)), "the score should not contain source recordings")
	_assert_true(not bool(originality.get("third_party_audio_used", true)), "the score should not contain third-party audio")

	var composition := metadata.get("composition", {}) as Dictionary
	var motif := composition.get("motif", {}) as Dictionary
	_assert_eq(str(motif.get("name", "")), "cold_window_five", "the score should publish its memorable five-note motif")
	_assert_eq(motif.get("intervals_semitones", []), [0.0, 3.0, 7.0, 2.0, 5.0], "the main motif should retain its original interval identity")
	_assert_eq(motif.get("onsets_beats", []), [0.0, 1.5, 2.25, 4.0, 6.5], "the main motif should retain its asymmetrical rhythm")
	var harmony := composition.get("harmony", {}) as Dictionary
	_assert_eq(int(harmony.get("field_bars", 0)), 4, "harmony variations should stay aligned to four-bar fields")
	_assert_eq((harmony.get("fields", []) as Array).size(), 8, "the loop should contain eight harmony fields")
	var transformations := composition.get("transformations", {}) as Dictionary
	var phone_transform := transformations.get("phone", {}) as Dictionary
	var pollution_transform := transformations.get("pollution", {}) as Dictionary
	_assert_eq(phone_transform.get("intervals_semitones", []), [0.0, 3.0, -5.0, 2.0, 5.0], "phone packets should octave-fold the shared motif")
	_assert_near(float(phone_transform.get("time_scale", 0.0)), 0.25, 0.001, "phone packets should compress the motif to quarter time")
	_assert_eq(pollution_transform.get("intervals_semitones", []), [0.0, -3.0, -7.0, -2.0, -5.0], "pollution should invert the shared motif")
	_assert_near(float(pollution_transform.get("time_scale", 0.0)), 0.65, 0.001, "pollution should distort the motif timing")

	var adaptive_mix := metadata.get("adaptive_mix", {}) as Dictionary
	_assert_true(bool(adaptive_mix.get("phase_aligned", false)), "metadata should retain the phase-aligned adaptive mix contract")
	_assert_true(bool(adaptive_mix.get("independent_stems", false)), "metadata should retain independent adaptive stems")
	var scenario_peaks := adaptive_mix.get("verified_scenario_peak_dbfs", {}) as Dictionary
	_assert_eq(scenario_peaks.size(), 6, "all runtime mix extremes should have offline peak checks")
	for scenario: String in scenario_peaks:
		_assert_true(float(scenario_peaks[scenario]) <= -1.0, "%s adaptive mix should retain master headroom" % scenario)
	var stems := metadata.get("stems", {}) as Dictionary
	for stem_name: String in ["reality", "phone", "pollution"]:
		var stem := stems.get(stem_name, {}) as Dictionary
		var filename := str(stem.get("file", ""))
		var audio_path := "res://assets/generated/audio/%s" % filename
		_assert_true(FileAccess.file_exists(audio_path), "%s stem file should exist" % stem_name)
		_assert_eq(FileAccess.get_sha256(audio_path), str(stem.get("sha256", "")), "%s stem should match deterministic metadata" % stem_name)
		_assert_eq(int(stem.get("frames", 0)), 2_116_800, "%s stem should preserve exact phase alignment" % stem_name)
		_assert_true(float(stem.get("peak_dbfs", 0.0)) <= -2.9, "%s stem should preserve master headroom" % stem_name)
		_assert_true(int(stem.get("seam_delta_pcm", 99_999)) <= 1_400, "%s stem should remain pop-free at the loop boundary" % stem_name)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.2f, got %.2f)" % [message, expected, actual])


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, expected, actual])
