extends Node
## The narrator's voice: one short blip per spoken character of a line, the approved "03 muted narrator" samples.
## Ported from the old version's chapter_narration_blips.gd with its timing unchanged: the owner compared the demo with
## the old version and missed the voice. It is independent of any UI: a panel hands it a line with `speak`, and
## `stop` or `set_paused` silences the rest of it; there is no backlog, so nothing is ever caught up.
## The samples load at runtime from the wav files, so nothing depends on an import pass.

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
## Silent characters: spaces are checked apart. Of these, only the ones `_punctuation_pause` knows pause the voice.
const SILENT_PUNCTUATION := "，。！？、；：,.!?;:…‥—–-\"'“”‘’「」『』（）()[]【】〈〉《》<>・·/\\_|=+~～"
## The old mix's narrator gain.
const GAIN_SCALE := 0.87

var _samples: Array[AudioStreamWAV] = []
var _player: AudioStreamPlayer
var _text := ""
var _cursor := 0
var _delay := 0.0
var _paused := false
var _active := false


func _ready() -> void:
	name = "NarrationBlips"
	_player = AudioStreamPlayer.new()
	_player.name = "NarrationVoice03"
	_player.bus = "Master"
	# One voice at a time: a new blip replaces the last, never layers on it.
	_player.max_polyphony = 1
	add_child(_player)
	for path: String in SAMPLE_PATHS:
		var sample := AudioStreamWAV.load_from_file(path)
		if sample == null:
			push_warning("Narration sample could not be loaded: " + path)
			continue
		sample.loop_mode = AudioStreamWAV.LOOP_DISABLED
		_samples.append(sample)
	set_process(false)


## Starts speaking `text` from its first character, replacing whatever was being spoken. Silent while paused.
func speak(text: String) -> void:
	stop()
	if _paused or text.is_empty() or _samples.size() != SAMPLE_PATHS.size():
		return
	_text = text
	_active = true
	set_process(true)
	tick(0.0)


## Drops the rest of the line.
func stop() -> void:
	_active = false
	_text = ""
	_cursor = 0
	_delay = 0.0
	set_process(false)
	if is_instance_valid(_player):
		_player.stop()


## Pausing stops the line in progress and silences new ones until unpaused; the unspoken rest is never resumed.
func set_paused(paused: bool) -> void:
	_paused = paused
	if paused:
		stop()


func is_speaking() -> bool:
	return _active or (is_instance_valid(_player) and _player.playing)


func _process(delta: float) -> void:
	tick(delta)


## Advances the line by `delta` seconds; public so a test can drive the schedule without the clock.
func tick(delta: float) -> void:
	if not _active or _paused:
		return
	_delay -= maxf(0.0, delta)
	if _delay > 0.0:
		return
	# One audible event per tick: a stalled frame never catches up old sounds.
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
		_player.volume_db = linear_to_db(_gain_for(index))
		_player.pitch_scale = 1.0
		_player.play()
		_delay = CHARACTER_INTERVAL * float(INTERVAL_VARIATIONS[index % INTERVAL_VARIATIONS.size()])
		blip_played.emit(character, sample_index)
		return
	_active = false
	_text = ""
	set_process(false)


static func _gain_for(index: int) -> float:
	return (0.88 + 0.12 * pow(sin(index * 1.31), 2.0)) * GAIN_SCALE


static func _punctuation_pause(character: String) -> float:
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
