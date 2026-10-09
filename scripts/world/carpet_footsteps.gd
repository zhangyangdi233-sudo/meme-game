class_name CarpetFootsteps
extends Node
## Distance-driven foley. Camera tweening, falling, pauses and teleports are silent.

const STRIDE_METERS := 0.86
const MAX_FRAME_DISTANCE := 1.5
var step_count := 0
var _last_position := Vector3.ZERO
var _has_position := false
var _distance := 0.0
var _audio: AudioStreamPlayer
var _steps: Array[AudioStreamWAV] = []

func _ready() -> void:
	_audio = AudioStreamPlayer.new()
	_audio.name = "CarpetStepAudio"
	# A thick pile absorbs the heel click; footsteps sit beneath the room tone.
	_audio.volume_db = -20.0
	add_child(_audio)
	for index in range(1, 5):
		var stream := AudioStreamWAV.load_from_file("res://assets/audio/foley/carpet_step_%02d.wav" % index)
		if stream != null: _steps.append(stream)

func _physics_process(_delta: float) -> void:
	var host := get_parent()
	if host == null or not "game" in host:
		return
	var player = host.get("_reality_player")
	if not is_instance_valid(player):
		_has_position = false
		return
	var state = host.get("game")
	var enabled: bool = state.chapter1_progress.get("phase", "") == "basement" and state.view_state == "npc_up"
	enabled = enabled and not bool(host.get("_settings_open")) and not bool(host.get("_input_locked"))
	enabled = enabled and not bool(host.call("_chapter_terminal_active")) and not bool(host.call("_chapter_task_active"))
	# The wooden stair flight is above the carpeted room floor.
	enabled = enabled and player.position.y < 0.3
	advance(player.position, enabled, player.is_on_floor())

func advance(position: Vector3, enabled: bool, grounded: bool) -> void:
	if not _has_position:
		_last_position = position
		_has_position = true
		return
	var motion := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not enabled or not grounded or motion > MAX_FRAME_DISTANCE:
		_distance = 0.0
		if _audio != null: _audio.stop()
		return
	_distance += motion
	if _distance < STRIDE_METERS:
		return
	_distance = fmod(_distance, STRIDE_METERS)
	step_count += 1
	if _audio != null and not _steps.is_empty():
		_audio.stream = _steps[(step_count - 1) % _steps.size()]
		_audio.pitch_scale = [0.97, 1.02, 0.99, 1.04][(step_count - 1) % 4]
		_audio.play()
