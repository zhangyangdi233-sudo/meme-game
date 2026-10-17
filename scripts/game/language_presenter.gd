class_name LanguagePresenter
extends RefCounted
## Plays what a Language material result looks like: the pickup press sound,
## the notebook coming home, and glyph flights. Rules and feedback text stay in LanguageMaterial.

const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")

## The host owns the notebook window, so it moves it home when this fires.
signal notebook_home_requested

var _flight_layer: FlyToTargetLayer
var _press_sound: AudioStreamPlayer
var _notebook_target: Callable = Callable()
var _composer_target: Callable = Callable()
var _hold_color := Color(0.96, 0.98, 0.9)
var _place_color := Color(0.96, 0.98, 0.9)


## Target getters are polled every frame by the flight layer, so the glyph follows a moving window.
func configure(
	flight_layer: FlyToTargetLayer,
	press_sound: AudioStreamPlayer,
	notebook_target: Callable,
	composer_target: Callable,
	hold_color: Color,
	place_color: Color,
) -> void:
	_flight_layer = flight_layer
	_press_sound = press_sound
	_notebook_target = notebook_target
	_composer_target = composer_target
	_hold_color = hold_color
	_place_color = place_color


func present_pickup(outcome: ActionOutcomeScript, unit: String, origin: Vector2) -> void:
	if not outcome.succeeded:
		return
	play_ui_sound(_press_sound)
	notebook_home_requested.emit()
	if _flight_layer != null and is_instance_valid(_flight_layer):
		_flight_layer.play_hold_flight(unit, origin, _notebook_target, _hold_color)


func present_place(placed: bool, unit: String, origin: Vector2) -> void:
	if not placed:
		return
	if _flight_layer != null and is_instance_valid(_flight_layer):
		_flight_layer.play_place_flight(unit, origin, _composer_target, _place_color)


## 短促 UI 音效:重复触发时从头播放,不叠加成噪音。
static func play_ui_sound(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player) or player.stream == null or not player.is_inside_tree():
		return
	player.stop()
	player.play()
