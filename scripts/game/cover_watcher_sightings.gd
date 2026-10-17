class_name CoverWatcherSightings
extends RefCounted
## Keeps the current run's record of cover watcher sightings. It subscribes to the watcher's game events itself
## from the moment the host attaches it (ADR 0007): an appearance marks its floor seen, so a rebuilt floor leaves the
## figure out; a withdrawal records its line in the event log. The host points it at each new run.

const GameEventsScript = preload("res://scripts/game_events.gd")

const VANISHED_LINE := "掩体后的人影缩了回去。它没有留下脸。"

var _game: MemeGameState
var _bus: GameEventBus


func configure(game: MemeGameState) -> void:
	_game = game


func attach(bus: GameEventBus) -> void:
	detach()
	_bus = bus
	if _bus == null:
		return
	_bus.subscribe(GameEventsScript.COVER_WATCHER_APPEARED, _on_appeared)
	_bus.subscribe(GameEventsScript.COVER_WATCHER_VANISHED, _on_vanished)


func detach() -> void:
	if _bus != null:
		_bus.unsubscribe(GameEventsScript.COVER_WATCHER_APPEARED, _on_appeared)
		_bus.unsubscribe(GameEventsScript.COVER_WATCHER_VANISHED, _on_vanished)
	_bus = null


func _on_appeared(payload: Dictionary) -> void:
	if _game != null and payload.has(GameEventsScript.KEY_FLOOR):
		_game.mark_cover_watcher_seen(int(payload[GameEventsScript.KEY_FLOOR]))


func _on_vanished(_payload: Dictionary) -> void:
	if _game != null:
		_game.record_event(VANISHED_LINE)
