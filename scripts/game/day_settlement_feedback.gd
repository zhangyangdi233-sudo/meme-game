class_name DaySettlementFeedback
extends RefCounted
## Writes the desk line for a new day and drops the previous day's meme selection. It subscribes to the day's game
## events itself from the moment the host attaches it (ADR 0007): a settled day shows the latest event log line;
## a finished pollution flashback says it is already the next day. A day the flashback settles leaves its line to
## the flashback's finish. The host points it at each new run.

const GameEventsScript = preload("res://scripts/game_events.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")

const NEXT_DAY_LINE := "黑屏之后，已经是第二天。"

var _game: MemeGameState
var _bus: GameEventBus


func configure(game: MemeGameState) -> void:
	_game = game


func attach(bus: GameEventBus) -> void:
	detach()
	_bus = bus
	if _bus == null:
		return
	_bus.subscribe(GameEventsScript.DAY_SETTLED, _on_day_settled)
	_bus.subscribe(GameEventsScript.FLASHBACK_FINISHED, _on_flashback_finished)


func detach() -> void:
	if _bus != null:
		_bus.unsubscribe(GameEventsScript.DAY_SETTLED, _on_day_settled)
		_bus.unsubscribe(GameEventsScript.FLASHBACK_FINISHED, _on_flashback_finished)
	_bus = null


func _on_day_settled(payload: Dictionary) -> void:
	_clear_selected_meme()
	if bool(payload.get(GameEventsScript.KEY_FROM_FLASHBACK, false)):
		return
	var latest := _latest_log_line()
	if not latest.is_empty():
		GameModelsScript.write_feedback(latest)


func _on_flashback_finished(_payload: Dictionary) -> void:
	_clear_selected_meme()
	var latest := _latest_log_line()
	GameModelsScript.write_feedback(NEXT_DAY_LINE if latest.is_empty() else "%s\n%s" % [NEXT_DAY_LINE, latest])


func _clear_selected_meme() -> void:
	var model := GameModelsScript.value(PropertyKeysScript.SELECTED_MEME)
	if model != null:
		model.write("")


func _latest_log_line() -> String:
	if _game == null or _game.event_log.is_empty():
		return ""
	return str(_game.event_log[0])
