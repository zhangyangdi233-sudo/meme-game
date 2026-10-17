extends SceneTree
## Day settlement feedback: it subscribes to the day's game events itself, writes the desk line for the new day and
## drops the previous day's meme selection. Does not load the main scene.

const BootScript = preload("res://scripts/game/property_boot.gd")
const DaySettlementFeedbackScript = preload("res://scripts/game/day_settlement_feedback.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")

const DAY_LINE := "黑屏之后，已经是第二天。"
const LOG_LINE := "第二天的第一行记录。"

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_settled_day_writes_the_latest_log_line()
	_test_settled_day_clears_the_selected_meme()
	_test_settled_day_with_an_empty_log_keeps_the_line()
	_test_flashback_settled_day_writes_the_next_day_line()
	_test_finish_heard_before_the_flashback_settles_ends_on_the_new_day()
	_test_finished_flashback_writes_the_next_day_line()
	_test_finished_flashback_with_an_empty_log_writes_only_the_day_line()
	_test_detached_feedback_hears_nothing()
	_test_configure_points_at_the_current_run()
	RegistryScript.clear()
	if _failures.is_empty():
		print("day settlement feedback tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	var bus: GameEventBus = GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	var game := MemeGameStateScript.new()
	game.new_run()
	var feedback = DaySettlementFeedbackScript.new()
	feedback.configure(game)
	feedback.attach(bus)
	GameModelsScript.write_feedback("昨天的回馈")
	GameModelsScript.value(PropertyKeysScript.SELECTED_MEME).write("meme-yesterday")
	return {"bus": bus, "game": game, "feedback": feedback}


func _settled(from_flashback: bool) -> void:
	GameEventBusScript.raise_event(GameEventsScript.DAY_SETTLED, {
		GameEventsScript.KEY_DAY: 2,
		GameEventsScript.KEY_FROM_FLASHBACK: from_flashback,
	})


func _flashback_finished() -> void:
	GameEventBusScript.raise_event(GameEventsScript.FLASHBACK_FINISHED)


func _feedback() -> String:
	return str(GameModelsScript.value(PropertyKeysScript.FEEDBACK_TEXT).read())


func _selected_meme() -> String:
	return str(GameModelsScript.value(PropertyKeysScript.SELECTED_MEME).read())


func _test_settled_day_writes_the_latest_log_line() -> void:
	var mounted := _mount()
	(mounted["game"] as MemeGameState).record_event(LOG_LINE)
	_settled(false)
	_assert_eq(_feedback(), LOG_LINE, "a settled day should show the latest event log line")


func _test_settled_day_clears_the_selected_meme() -> void:
	var mounted := _mount()
	_settled(false)
	_assert_eq(_selected_meme(), "", "a settled day should drop the previous day's meme selection")
	mounted.clear()


func _test_settled_day_with_an_empty_log_keeps_the_line() -> void:
	var mounted := _mount()
	(mounted["game"] as MemeGameState).event_log = []
	_settled(false)
	_assert_eq(_feedback(), "昨天的回馈", "a settled day with nothing logged should leave the desk line alone")


func _test_flashback_settled_day_writes_the_next_day_line() -> void:
	var mounted := _mount()
	(mounted["game"] as MemeGameState).record_event(LOG_LINE)
	_settled(true)
	_assert_eq(_feedback(), "%s
%s" % [DAY_LINE, LOG_LINE], "a day the flashback settles should say it is already the next day")
	_assert_eq(_selected_meme(), "", "a day the flashback settles should still drop the meme selection")


## The feedback may hear the flashback finish before whoever settles the day in answer to it.
func _test_finish_heard_before_the_flashback_settles_ends_on_the_new_day() -> void:
	var mounted := _mount()
	var game := mounted["game"] as MemeGameState
	game.record_event("昨天的最后一行。")
	_flashback_finished()
	game.record_event(LOG_LINE)
	_settled(true)
	_assert_eq(_feedback(), "%s
%s" % [DAY_LINE, LOG_LINE], "the desk line should end on the new day's latest log line")


func _test_finished_flashback_writes_the_next_day_line() -> void:
	var mounted := _mount()
	(mounted["game"] as MemeGameState).record_event(LOG_LINE)
	_flashback_finished()
	_assert_eq(_feedback(), "%s\n%s" % [DAY_LINE, LOG_LINE], "a finished flashback should say it is already the next day above the latest log line")
	_assert_eq(_selected_meme(), "", "a finished flashback should drop the meme selection")


func _test_finished_flashback_with_an_empty_log_writes_only_the_day_line() -> void:
	var mounted := _mount()
	(mounted["game"] as MemeGameState).event_log = []
	_flashback_finished()
	_assert_eq(_feedback(), DAY_LINE, "a finished flashback with nothing logged should show only the next-day line")


func _test_detached_feedback_hears_nothing() -> void:
	var mounted := _mount()
	(mounted["game"] as MemeGameState).record_event(LOG_LINE)
	mounted["feedback"].detach()
	_settled(false)
	_flashback_finished()
	_assert_eq(_feedback(), "昨天的回馈", "detached feedback should not write the desk line")
	_assert_eq(_selected_meme(), "meme-yesterday", "detached feedback should not clear the selection")


func _test_configure_points_at_the_current_run() -> void:
	var mounted := _mount()
	var second := MemeGameStateScript.new()
	second.new_run()
	second.record_event("另一局的记录。")
	mounted["feedback"].configure(second)
	_settled(false)
	_assert_eq(_feedback(), "另一局的记录。", "the line should come from the run the feedback was last pointed at")


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
