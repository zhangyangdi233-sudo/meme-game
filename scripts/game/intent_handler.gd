@abstract
class_name IntentHandler
extends RefCounted
## One domain's UI intents. The host stays the only listener: it asks its handlers in turn, hands the intent to the
## one that claims it, and presents the returned result (ADR 0007). A handler subscribes to nothing and never reaches
## into host nodes; it changes the state, writes its feedback line, and names what the host presents.

const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const IntentResultScript = preload("res://scripts/game/intent_result.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")

@abstract func handles(intent_name: String) -> bool

@abstract func handle(intent_name: String, payload: Dictionary) -> IntentResult


func _write_feedback(text: String) -> void:
	GameModelsScript.write_feedback(text)


## A spending action. On success its meme becomes the selection before the host shows the feedback and settles.
func _action(outcome: ActionOutcomeScript) -> IntentResult:
	if outcome.succeeded:
		GameModelsScript.value(PropertyKeysScript.SELECTED_MEME).write(outcome.selected_meme_id)
	return IntentResultScript.present(IntentResultScript.ACTION, outcome)
