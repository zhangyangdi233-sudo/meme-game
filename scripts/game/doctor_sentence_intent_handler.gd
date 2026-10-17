class_name DoctorSentenceIntentHandler
extends IntentHandler
## Handles the doctor sentence composer's intents: keeps the selected token model, places tokens in the doctor's
## slots, speaks the sentence, writes the feedback line, and returns what the host presents.

const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## The doctor's slots or the selected token changed; the host refreshes the reality HUD.
const COMPOSER_CHANGED := "doctor_composer_changed"
## The sentence was confirmed; the host shows the outcome's feedback and settles it, or refreshes the reality HUD
## when it was refused.
const CONFIRMED := "doctor_sentence_confirmed"

const INTENTS: Array[String] = [
	UiIntentsScript.COMPOSER_TOKEN_PRESSED,
	UiIntentsScript.COMPOSER_TOKEN_DROPPED,
	UiIntentsScript.COMPOSER_SLOT_PRESSED,
	UiIntentsScript.COMPOSER_CONFIRM_PRESSED,
]

const PLACED_LINE := "词已经进入医生句槽。"
const REFUSED_LINE := "这个词不能放在句子的这个位置。"

var _game: MemeGameState


## The host configures it again before each use, so a new run's state is never stale.
func configure(game: MemeGameState) -> void:
	_game = game


func handles(intent_name: String) -> bool:
	return intent_name in INTENTS


func handle(intent_name: String, payload: Dictionary) -> IntentResult:
	match intent_name:
		UiIntentsScript.COMPOSER_TOKEN_PRESSED:
			_selected_token().write(str(payload.get(UiIntentsScript.KEY_TOKEN_ID, "")))
			_write_feedback("选中了一个带到医生面前的词。")
		UiIntentsScript.COMPOSER_TOKEN_DROPPED:
			var data: Dictionary = payload.get(UiIntentsScript.KEY_DATA, {})
			var token_id := str(data.get("id", ""))
			if token_id.is_empty():
				return IntentResultScript.present(IntentResultScript.NONE)
			_selected_token().write(token_id)
			_place(str(payload.get(UiIntentsScript.KEY_SLOT_ID, "")), token_id)
		UiIntentsScript.COMPOSER_SLOT_PRESSED:
			var selected := str(_selected_token().read())
			if selected.is_empty():
				_write_feedback("先选择一个词。")
			else:
				_place(str(payload.get(UiIntentsScript.KEY_SLOT_ID, "")), selected)
		UiIntentsScript.COMPOSER_CONFIRM_PRESSED:
			var outcome: ActionOutcomeScript = _game.confirm_doctor_sentence()
			if outcome.succeeded:
				_selected_token().write("")
			return IntentResultScript.present(CONFIRMED, outcome)
		_:
			return IntentResultScript.present(IntentResultScript.NONE)
	return IntentResultScript.present(COMPOSER_CHANGED)


func _place(slot_id: String, token_id: String) -> void:
	_write_feedback(PLACED_LINE if _game.place_language_token(slot_id, token_id, "doctor") else REFUSED_LINE)


func _selected_token() -> ValuePropertyModel:
	return GameModelsScript.value(PropertyKeysScript.SELECTED_LANGUAGE_TOKEN)
