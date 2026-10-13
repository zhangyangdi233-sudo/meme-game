extends Node
## Approved 03 narration samples follow the current line without owning its UI
## or progression. Stopping discards the rest of the line; there is no backlog.

signal blip_played(character: String, sample_index: int)

const SAMPLE_PATHS := [
	"res://assets/audio/dialogue/03_muted_narrator/blip_01.wav",
	"res://assets/audio/dialogue/03_muted_narrator/blip_02.wav",
	"res://assets/audio/dialogue/03_muted_narrator/blip_03.wav",
	"res://assets/audio/dialogue/03_muted_narrator/blip_04.wav",
	"res://assets/audio/dialogue/03_muted_narrator/blip_05.wav",
	"res://assets/audio/dialogue/03_muted_narrator/blip_06.wav",
]
const CHARACTER_INTERVAL := 0.130
const INTERVAL_VARIATIONS := [1.0, 0.95, 1.03, 1.08, 0.98]
const SILENT_PUNCTUATION := "，。！？、；：,.!?;:…‥—–-\"'“”‘’「」『』（）()[]【】〈〉《》<>・·/\\_|=+~～"

var _samples: Array[AudioStreamWAV] = []
var _player: AudioStreamPlayer
var _text := ""
var _cursor := 0
var _delay := 0.0
var _paused := false
var _active := false


func _ready() -> void:
	name = "ChapterNarrationBlips"
	_player = AudioStreamPlayer.new()
	_player.name = "NarrationVoice03"
	_player.bus = "Master"
	_player.max_polyphony = 1
	add_child(_player)
	for path: String in SAMPLE_PATHS:
		var sample := load(path) as AudioStreamWAV
		if sample == null:
			push_warning("Narration sample could not be loaded: " + path)
			continue
		sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_samples.append(sample)
	set_process(false)


func play_line(text: String) -> void:
	stop()
	if _paused or text.is_empty() or _samples.size() != SAMPLE_PATHS.size():
		return
	_text = text
	_active = true
	set_process(true)
	tick(0.0)


func stop() -> void:
	_active = false
	_text = ""
	_cursor = 0
	_delay = 0.0
	set_process(false)
	if is_instance_valid(_player):
		_player.stop()


func set_paused(value: bool) -> void:
	_paused = value
	if value:
		stop()


func is_speaking() -> bool:
	return _active or (is_instance_valid(_player) and _player.playing)


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if not _active or _paused:
		return
	_delay -= maxf(0.0, delta)
	if _delay > 0.0:
		return
	# One audible event per tick. A stalled frame never catches up old sounds.
	while _cursor < _text.length():
		var index := _cursor
		var character := _text.substr(_cursor, 1)
		_cursor += 1
		if character.strip_edges().is_empty() or SILENT_PUNCTUATION.contains(character):
			var pause := _punctuation_pause(character)
			if pause > 0.0:
				_delay = pause
				return
			continue
		var sample_index := (character.unicode_at(0) + index * 5) % _samples.size()
		_player.stop()
		_player.stream = _samples[sample_index]
		# Match the audition's narrator gain and keep the approved sample pitch.
		var gain := (0.88 + 0.12 * pow(sin(index * 1.31), 2.0)) * 0.87
		_player.volume_db = linear_to_db(gain)
		_player.pitch_scale = 1.0
		_player.play()
		_delay = CHARACTER_INTERVAL * float(INTERVAL_VARIATIONS[index % INTERVAL_VARIATIONS.size()])
		blip_played.emit(character, sample_index)
		return
	_active = false
	_text = ""
	set_process(false)


func _punctuation_pause(character: String) -> float:
	if "，、,；;：:".contains(character):
		return 0.24
	if "。.".contains(character):
		return 0.42
	if "？?".contains(character):
		return 0.43
	if "！!".contains(character):
		return 0.38
	if "…‥—–".contains(character):
		return 0.40
	return 0.0


func _exit_tree() -> void:
	stop()
