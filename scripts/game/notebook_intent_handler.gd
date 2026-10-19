class_name NotebookIntentHandler
extends IntentHandler
## Handles the notebook's intents: places words, posts the sentence, keeps the resting canvas positions, writes the
## feedback line, and returns what the host presents.

const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## A bank tap; the host flies the word to the sentence when it was placed.
const PLACE := "notebook_place"

const INTENTS: Array[String] = [
	UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED,
	UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED,
	UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE,
	UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED,
]

var _game: MemeGameState
var _material: LanguageMaterial
var _locale: BabelGameLocale
var _answer_panel := Callable()


## The host configures it again before each use, so a new run's state is never stale. `answer_panel` returns the
## publish page's answer area (or null) for a tile dropped off the canvas; it is only called for that drop.
func configure(game: MemeGameState, material: LanguageMaterial, locale: BabelGameLocale, answer_panel: Callable) -> void:
	_game = game
	_material = material
	_locale = locale
	_answer_panel = answer_panel


func handles(intent_name: String) -> bool:
	return intent_name in INTENTS


func handle(intent_name: String, payload: Dictionary) -> IntentResult:
	match intent_name:
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED:
			return IntentResultScript.present(IntentResultScript.SUBMIT, _material.submit())
		UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED:
			_game.set_char_canvas_positions(payload.get(UiIntentsScript.KEY_TILE_POSITIONS, {}), _locale.current_locale)
		UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE:
			var answer_panel: Control = _answer_panel.call() if _answer_panel.is_valid() else null
			_material.place_if_over_answer(str(payload.get(UiIntentsScript.KEY_UNIT, "")), payload.get(UiIntentsScript.KEY_RELEASE_GLOBAL, Vector2.ZERO), answer_panel)
		UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED:
			var unit := str(payload.get(UiIntentsScript.KEY_UNIT, ""))
			var place := IntentResultScript.present(PLACE)
			place.unit = unit
			place.value = _material.place_from_bank(unit)
			return place
	return IntentResultScript.present(IntentResultScript.NONE)

