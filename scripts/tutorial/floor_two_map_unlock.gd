extends Node
## The host owns camera/input/phone presentation. Only explicitly unpaused
## delta advances this sequence; cancellation never schedules a later reward.

signal reveal_started
signal brightness_changed(fraction: float)
signal finished

const SLIDE_SECONDS := 0.52
const GRAY_HOLD_SECONDS := 0.25
const BRIGHTEN_SECONDS := 0.85
const READY_HOLD_SECONDS := 0.68
const REVEAL_AT := SLIDE_SECONDS + GRAY_HOLD_SECONDS
const TOTAL_SECONDS := REVEAL_AT + BRIGHTEN_SECONDS + READY_HOLD_SECONDS

var _active := false
var _elapsed := 0.0
var _revealed := false
var _brightness := 0.0
var _generation := 0

func begin() -> void:
	if _active:
		return
	_generation += 1
	_elapsed = 0.0
	_revealed = false
	_brightness = 0.0
	_active = true
	brightness_changed.emit(0.0)

func update(delta: float, paused: bool = false) -> void:
	if not _active or paused or not is_finite(delta) or delta <= 0.0:
		return
	var generation := _generation
	_elapsed = minf(_elapsed + delta, TOTAL_SECONDS)
	if not _revealed and _elapsed >= REVEAL_AT:
		_revealed = true
		reveal_started.emit()
		if not _active or generation != _generation:
			return
	if _revealed:
		var linear := clampf((_elapsed - REVEAL_AT) / BRIGHTEN_SECONDS, 0.0, 1.0)
		var brightness := smoothstep(0.0, 1.0, linear)
		if not is_equal_approx(brightness, _brightness):
			_brightness = brightness
			brightness_changed.emit(brightness)
			if not _active or generation != _generation:
				return
	if _elapsed >= TOTAL_SECONDS:
		_active = false
		finished.emit()

func active() -> bool:
	return _active

func cancel() -> void:
	_generation += 1
	_active = false
	_elapsed = 0.0
	_revealed = false
	_brightness = 0.0

func _exit_tree() -> void:
	cancel()
