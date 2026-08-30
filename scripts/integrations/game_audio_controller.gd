extends Node
class_name GameAudioController
## Adaptive score mix, floor phone music, and cover-watcher stinger for the main scene adapter.

const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")

const PHONE_AMBIENCE_PATHS := {
	1: "res://assets/generated/audio/babel_phone_signal_floor_1.wav",
	2: "res://assets/generated/audio/babel_phone_signal.wav",
	3: "res://assets/generated/audio/babel_phone_signal_floor_3.wav",
	4: "res://assets/generated/audio/babel_phone_signal_floor_4.wav",
}
const REALITY_AMBIENCE_PATH := "res://assets/generated/audio/babel_reality_liminal.wav"
const POLLUTION_AMBIENCE_PATH := "res://assets/generated/audio/babel_pollution_rot.wav"
const FLASHBACK_AUDIO_PATH := "res://assets/generated/audio/pollution_flashback.wav"
const ACTION_TICK_AUDIO_PATH := "res://assets/generated/audio/action_tick.wav"
const PICKUP_PRESS_AUDIO_PATH := "res://assets/generated/audio/pickup_press.wav"
const PICKUP_LAND_AUDIO_PATH := "res://assets/generated/audio/pickup_land.wav"
const NOTEBOOK_HINGE_AUDIO_PATH := "res://assets/generated/audio/notebook_hinge.wav"
const COVER_WATCHER_STINGER_PATH := "res://assets/generated/audio/cover_watcher_stinger.wav"

var phone_ambience: AudioStreamPlayer
var reality_ambience: AudioStreamPlayer
var pollution_ambience: AudioStreamPlayer
var flashback_audio: AudioStreamPlayer
var pickup_press_audio: AudioStreamPlayer
var pickup_land_audio: AudioStreamPlayer
var notebook_hinge_audio: AudioStreamPlayer
var action_tick_audio: AudioStreamPlayer
var cover_watcher_stinger: AudioStreamPlayer

var _host: Node
var _audio_tween: Tween


func attach_to(host: Node) -> void:
	_host = host
	name = "GameAudioController"
	host.add_child(self)


func reset_session() -> void:
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	_audio_tween = null


func build_players(deps: Dictionary) -> void:
	var initial_floor := 1
	var game: Variant = deps.get("game")
	if game != null:
		initial_floor = clampi(int(game.tower_floor), 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	phone_ambience = _make_audio_player("PhoneRoadAmbience", phone_music_path_for_floor(initial_floor), true, -60.0)
	phone_ambience.set_meta("phone_music_floor", initial_floor)
	reality_ambience = _make_audio_player("RealityRoomAmbience", REALITY_AMBIENCE_PATH, true, -60.0)
	pollution_ambience = _make_audio_player("PollutionMusicLayer", POLLUTION_AMBIENCE_PATH, true, -60.0)
	flashback_audio = _make_audio_player("PollutionFlashbackAudio", FLASHBACK_AUDIO_PATH, false, -8.0)
	pickup_press_audio = _make_audio_player("PickupPressAudio", PICKUP_PRESS_AUDIO_PATH, false, -16.0)
	pickup_land_audio = _make_audio_player("PickupLandAudio", PICKUP_LAND_AUDIO_PATH, false, -11.0)
	notebook_hinge_audio = _make_audio_player("NotebookHingeAudio", NOTEBOOK_HINGE_AUDIO_PATH, false, -14.0)
	action_tick_audio = _make_audio_player("ActionTickAudio", ACTION_TICK_AUDIO_PATH, false, -15.0)
	cover_watcher_stinger = _make_audio_player("CoverWatcherStinger", COVER_WATCHER_STINGER_PATH, false, -9.0)
	sync_state(deps, true)


func on_cover_watcher_appeared(_floor_number: int) -> void:
	if cover_watcher_stinger != null and cover_watcher_stinger.stream != null and _host != null and _host.is_inside_tree():
		cover_watcher_stinger.stop()
		cover_watcher_stinger.play()


func phone_music_path_for_floor(floor_number: int) -> String:
	var safe_floor := clampi(floor_number, 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	return str(PHONE_AMBIENCE_PATHS.get(safe_floor, PHONE_AMBIENCE_PATHS[1]))


func ensure_phone_music_for_floor(floor_number: int) -> void:
	if phone_ambience == null:
		return
	var safe_floor := clampi(floor_number, 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	var target_path := phone_music_path_for_floor(safe_floor)
	if str(phone_ambience.get_meta("generated_audio_path", "")) == target_path:
		phone_ambience.set_meta("phone_music_floor", safe_floor)
		return
	var phase := 0.0
	if reality_ambience != null and reality_ambience.playing:
		phase = reality_ambience.get_playback_position()
	elif phone_ambience.playing:
		phase = phone_ambience.get_playback_position()
	var was_playing := phone_ambience.playing
	phone_ambience.stop()
	phone_ambience.stream = _load_generated_wav(target_path, true)
	phone_ambience.set_meta("generated_audio_path", target_path)
	phone_ambience.set_meta("phone_music_floor", safe_floor)
	if _host != null and _host.is_inside_tree() and was_playing and phone_ambience.stream != null:
		phone_ambience.play(phase)


func sync_state(deps: Dictionary, immediate: bool = false) -> void:
	if phone_ambience == null or reality_ambience == null or pollution_ambience == null:
		return
	var game_started := bool(deps.get("game_started", false))
	var game: Variant = deps.get("game")
	if not game_started or game == null:
		for player in [phone_ambience, reality_ambience, pollution_ambience]:
			player.set_meta("target_volume_db", -60.0)
		if _host != null and _host.is_inside_tree():
			for player in [phone_ambience, reality_ambience, pollution_ambience]:
				player.stop()
			if flashback_audio != null:
				flashback_audio.stop()
			if cover_watcher_stinger != null:
				cover_watcher_stinger.stop()
		return
	var day_progress: Dictionary = deps.get("day_progress", {})
	ensure_phone_music_for_floor(int(day_progress.get("tower_floor", 1)))
	var phone_shell: Dictionary = deps.get("phone_shell", {})
	var in_phone: bool = str(phone_shell.get("view_state", "")) == "phone_down"
	var phone_target: float = -8.0 if in_phone else -42.0
	var reality_interaction_active := bool(deps.get("reality_interaction_active", false))
	var conversation: Dictionary = deps.get("reality_conversation", {})
	var intimate_typing: bool = reality_interaction_active and str(conversation.get("phase", "")) == "typing"
	var reality_target: float = -26.0 if in_phone else (-7.0 if intimate_typing else -10.0)
	var pollution_stage: Dictionary = deps.get("pollution_stage", {})
	var pollution_target := float(pollution_stage.get("music_db", -60.0))
	phone_ambience.set_meta("target_volume_db", phone_target)
	reality_ambience.set_meta("target_volume_db", reality_target)
	pollution_ambience.set_meta("target_volume_db", pollution_target)
	for player in [phone_ambience, reality_ambience, pollution_ambience]:
		player.set_meta("flashback_ducked", false)
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	_audio_tween = null
	if immediate:
		phone_ambience.volume_db = phone_target
		reality_ambience.volume_db = reality_target
		pollution_ambience.volume_db = pollution_target
	if _host == null or not _host.is_inside_tree():
		return
	for player in [phone_ambience, reality_ambience, pollution_ambience]:
		if not player.playing:
			player.play()
	if immediate:
		return
	_audio_tween = _host.create_tween().set_parallel(true)
	_audio_tween.tween_property(phone_ambience, "volume_db", phone_target, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_audio_tween.tween_property(reality_ambience, "volume_db", reality_target, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_audio_tween.tween_property(pollution_ambience, "volume_db", pollution_target, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func duck_ambience_for_flashback() -> void:
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	_audio_tween = null
	for player in [phone_ambience, reality_ambience, pollution_ambience]:
		if player != null:
			player.set_meta("flashback_ducked", true)
	if _host == null or not _host.is_inside_tree():
		for player in [phone_ambience, reality_ambience, pollution_ambience]:
			if player != null:
				player.volume_db = -44.0
		return
	_audio_tween = _host.create_tween().set_parallel(true)
	for player in [phone_ambience, reality_ambience, pollution_ambience]:
		if player != null:
			# 分镜要求:底噪在冻结帧内先保持(约 0.28s),再于 100ms 内死掉,画面随后才切黑。
			_audio_tween.tween_property(player, "volume_db", -44.0, 0.10).set_delay(0.28).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _make_audio_player(node_name: String, path: String, looped: bool, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = _load_generated_wav(path, looped)
	player.volume_db = volume_db
	player.set_meta("generated_audio_path", path)
	player.set_meta("looped", looped)
	if _host != null:
		_host.add_child(player)
	return player


func _load_generated_wav(path: String, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.load_from_file(path)
	if stream == null:
		return null
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var channel_count := 2 if stream.stereo else 1
		var bytes_per_sample := 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
		stream.loop_end = int(stream.data.size() / maxi(1, channel_count * bytes_per_sample))
	return stream
