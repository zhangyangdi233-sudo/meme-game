class_name SettingsIntentHandler
extends IntentHandler
## Handles the settings window's intents: writes the volume, autoplay and settings-open models and the exit prompt,
## and returns what the host presents. Saving, the VHS overlay, the history window, the main menu and quitting stay
## the host's to present: they touch files, host nodes and the session flow.
## The settings language option reuses LANGUAGE_SELECTED, which the host still routes by session.

const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## The VHS setting changed to `value`; the host keeps it for the preferences and shows or hides the overlay.
const VHS_TOGGLED := "settings_vhs_toggled"
## The host saves the progress and the preferences and writes the save status.
const SAVE_REQUESTED := "settings_save_requested"
## The host returns to the main menu.
const MAIN_MENU_REQUESTED := "settings_main_menu_requested"
## The host shows the quit confirmation.
const QUIT_PROMPTED := "settings_quit_prompted"
## The host quits.
const QUIT_CONFIRMED := "settings_quit_confirmed"
## The host toggles the history window.
const HISTORY_TOGGLED := "settings_history_toggled"

const INTENTS: Array[String] = [
	UiIntentsScript.VOLUME_CHANGED,
	UiIntentsScript.AUTOPLAY_TOGGLED,
	UiIntentsScript.VHS_TOGGLED,
	UiIntentsScript.MANUAL_SAVE_PRESSED,
	UiIntentsScript.RETURN_MAIN_MENU_PRESSED,
	UiIntentsScript.EXIT_GAME_REQUESTED,
	UiIntentsScript.EXIT_CONFIRMED,
	UiIntentsScript.HISTORY_TOGGLE_REQUESTED,
	UiIntentsScript.SETTINGS_PRESSED,
]

var _game: MemeGameState


## The host configures it again before each use, so a new run's state is never stale.
func configure(game: MemeGameState) -> void:
	_game = game


func handles(intent_name: String) -> bool:
	return intent_name in INTENTS


func handle(intent_name: String, payload: Dictionary) -> IntentResult:
	match intent_name:
		UiIntentsScript.VOLUME_CHANGED:
			GameModelsScript.value(PropertyKeysScript.MASTER_VOLUME).write(float(payload.get(UiIntentsScript.KEY_VALUE, 0.0)))
		UiIntentsScript.AUTOPLAY_TOGGLED:
			_game.set_autoplay_enabled(bool(payload.get(UiIntentsScript.KEY_VALUE, false)))
		UiIntentsScript.SETTINGS_PRESSED:
			var settings_open := GameModelsScript.value(PropertyKeysScript.SETTINGS_OPEN)
			settings_open.write(not bool(settings_open.read()))
		UiIntentsScript.VHS_TOGGLED:
			var vhs := IntentResultScript.present(VHS_TOGGLED)
			vhs.value = bool(payload.get(UiIntentsScript.KEY_VALUE, false))
			return vhs
		UiIntentsScript.MANUAL_SAVE_PRESSED:
			return IntentResultScript.present(SAVE_REQUESTED)
		UiIntentsScript.RETURN_MAIN_MENU_PRESSED:
			return IntentResultScript.present(MAIN_MENU_REQUESTED)
		UiIntentsScript.EXIT_GAME_REQUESTED:
			_game.mark_exit_prompt_seen()
			return IntentResultScript.present(QUIT_PROMPTED)
		UiIntentsScript.EXIT_CONFIRMED:
			return IntentResultScript.present(QUIT_CONFIRMED)
		UiIntentsScript.HISTORY_TOGGLE_REQUESTED:
			return IntentResultScript.present(HISTORY_TOGGLED)
	return IntentResultScript.present(IntentResultScript.NONE)
