class_name LanguagePresenter
extends RefCounted
## Plays what a Language material result looks like: the pickup press sound cue,
## the notebook coming home, and glyph flights. Rules and feedback text stay in LanguageMaterial.
## The sound is a game event; whoever plays sounds subscribes to it.

const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")

## The host owns the notebook window, so it moves it home when this fires.
signal notebook_home_requested

var _flight_layer: FlyToTargetLayer
var _notebook_target: Callable = Callable()
var _composer_target: Callable = Callable()
var _hold_color: Color
var _place_color: Color


## Target getters are polled every frame by the flight layer, so the glyph follows a moving window.
func configure(
	flight_layer: FlyToTargetLayer,
	notebook_target: Callable,
	composer_target: Callable,
	hold_color: Color,
	place_color: Color,
) -> void:
	_flight_layer = flight_layer
	_notebook_target = notebook_target
	_composer_target = composer_target
	_hold_color = hold_color
	_place_color = place_color


func present_pickup(outcome: ActionOutcomeScript, unit: String, origin: Vector2) -> void:
	if not outcome.succeeded:
		return
	GameEventBusScript.raise_event(GameEventsScript.SFX_REQUESTED, {GameEventsScript.KEY_CUE: GameEventsScript.CUE_PICKUP_PRESS})
	notebook_home_requested.emit()
	if _flight_layer != null and is_instance_valid(_flight_layer):
		_flight_layer.play_hold_flight(unit, origin, _notebook_target, _hold_color)


func present_place(placed: bool, unit: String, origin: Vector2) -> void:
	if not placed:
		return
	if _flight_layer != null and is_instance_valid(_flight_layer):
		_flight_layer.play_place_flight(unit, origin, _composer_target, _place_color)

