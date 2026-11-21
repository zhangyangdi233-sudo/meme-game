class_name NotebookIntentHandler
extends IntentHandler
## Handles the notebook's intents: places, reorders and takes back words in the sentence, posts it, keeps the resting
## canvas positions, writes the feedback line, and returns what the host presents. The notebook is where the sentence
## is composed and posted (#154).

const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## A bank tap; the host flies the word to the sentence when it was placed.
const PLACE := "notebook_place"

const INTENTS: Array[String] = [
	UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED,
	UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED,
	UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED,
	UiIntentsScript.NOTEBOOK_SENTENCE_AREA_DROPPED,
	UiIntentsScript.NOTEBOOK_SENTENCE_TILE_DROPPED,
	UiIntentsScript.NOTEBOOK_SENTENCE_TILE_TAPPED,
]

var _game: MemeGameState
var _material: LanguageMaterial
var _locale: BabelGameLocale


## The host configures it again before each use, so a new run's state is never stale.
func configure(game: MemeGameState, material: LanguageMaterial, locale: BabelGameLocale) -> void:
	_game = game
	_material = material
	_locale = locale


func handles(intent_name: String) -> bool:
	return intent_name in INTENTS


func handle(intent_name: String, payload: Dictionary) -> IntentResult:
	match intent_name:
		UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED:
			return IntentResultScript.present(IntentResultScript.SUBMIT, _material.submit())
		UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED:
			_game.set_char_canvas_positions(payload.get(UiIntentsScript.KEY_TILE_POSITIONS, {}), _locale.current_locale)
		UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED:
			var unit := str(payload.get(UiIntentsScript.KEY_UNIT, ""))
			var place := IntentResultScript.present(PLACE)
			place.unit = unit
			place.value = _material.place_from_bank(unit)
			return place
		UiIntentsScript.NOTEBOOK_SENTENCE_AREA_DROPPED:
			_material.drop_on_area(payload.get(UiIntentsScript.KEY_DATA, {}))
		UiIntentsScript.NOTEBOOK_SENTENCE_TILE_DROPPED:
			_material.drop_before(payload.get(UiIntentsScript.KEY_DATA, {}), int(payload.get(UiIntentsScript.KEY_BEFORE_INDEX, 0)))
		UiIntentsScript.NOTEBOOK_SENTENCE_TILE_TAPPED:
			_material.remove_at(int(payload.get(UiIntentsScript.KEY_UNIT_INDEX, -1)))
	return IntentResultScript.present(IntentResultScript.NONE)
