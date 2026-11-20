extends Node
## Footsteps on the basement's carpet, driven by the distance walked. Ported from the old version's
## carpet_footsteps.gd with its numbers unchanged: the owner missed them in the demo. The Reality scene adapter owns and
## ticks it, because the player body and the stage kind live there; this node only knows a position and whether the
## conditions hold. Camera tweening, falling, pauses and teleports are silent.
## The four contacts are real CC0 recordings (`assets/audio/foley/LICENSE.md`), loaded at runtime from the wav files.

## Distance between individual foot contacts (not a full left/right gait cycle), walking and at sprint speed.
const STRIDE_METERS := 1.95
const RUN_STRIDE_METERS := 1.90
## A frame that moves further than this is a teleport or a correction, not a step.
const MAX_FRAME_DISTANCE := 1.5
## The wooden stair flight stands above the carpeted room floor (the stage's floor is at y 0): silent from here up.
const CARPET_CEILING_Y := 0.3
## A thick pile absorbs the heel click; the steps sit beneath the room tone.
const VOLUME_DB := -20.0
const PITCH_CYCLE := [0.97, 1.02, 0.99, 1.04]
const STEP_PATHS := [
	"res://assets/audio/foley/carpet_step_01.wav",
	"res://assets/audio/foley/carpet_step_02.wav",
	"res://assets/audio/foley/carpet_step_03.wav",
	"res://assets/audio/foley/carpet_step_04.wav",
]

## The player's walking and sprinting speeds (m/s), set by the adapter that moves the player so the stride follows
## the speeds the player really has.
var walk_speed := 3.3
var sprint_speed := 6.105
var step_count := 0
var _last_position := Vector3.ZERO
var _has_position := false
var _distance := 0.0
var _audio: AudioStreamPlayer
var _steps: Array[AudioStreamWAV] = []


func _ready() -> void:
	name = "CarpetFootsteps"
	_audio = AudioStreamPlayer.new()
	_audio.name = "CarpetStepAudio"
	_audio.volume_db = VOLUME_DB
	add_child(_audio)
	for path: String in STEP_PATHS:
		var stream := AudioStreamWAV.load_from_file(path)
		if stream == null:
			push_warning("Carpet step could not be loaded: " + path)
			continue
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_steps.append(stream)


## Whether a position and the world around it let the carpet sound: in the room, not on the stairs.
static func on_carpet(position: Vector3) -> bool:
	return position.y < CARPET_CEILING_Y


## Forgets the last position and the distance walked, and silences the contact in progress.
func reset() -> void:
	_has_position = false
	_distance = 0.0
	if _audio != null:
		_audio.stop()


## One frame. `enabled` is every world condition (a basement round, the phone down, settings closed, outside the
## terminal and any conversation, no transition); `grounded` is the player on the floor.
func advance(position: Vector3, enabled: bool, grounded: bool, delta: float = 0.0) -> void:
	if not _has_position:
		_last_position = position
		_has_position = true
		return
	var motion := Vector2(position.x - _last_position.x, position.z - _last_position.z).length()
	_last_position = position
	if not enabled or not grounded or motion > MAX_FRAME_DISTANCE:
		_distance = 0.0
		if _audio != null:
			_audio.stop()
		return
	_distance += motion
	var speed := motion / delta if delta > 0.0 else walk_speed
	var stride := stride_for_speed(speed)
	if _distance < stride:
		return
	_distance = fmod(_distance, stride)
	# Never cut a contact into another attack when a frame or correction advances unusually far: skip the next one.
	if _audio != null and _audio.playing:
		return
	step_count += 1
	if _audio != null and not _steps.is_empty():
		_audio.stream = _steps[(step_count - 1) % _steps.size()]
		_audio.pitch_scale = PITCH_CYCLE[(step_count - 1) % PITCH_CYCLE.size()]
		_audio.play()


## The distance between contacts at a speed: the walking stride, shortening to the sprint's at sprint speed.
func stride_for_speed(speed: float) -> float:
	return lerpf(STRIDE_METERS, RUN_STRIDE_METERS, clampf((speed - walk_speed) / (sprint_speed - walk_speed), 0.0, 1.0))


func is_stepping() -> bool:
	return _audio != null and _audio.playing
