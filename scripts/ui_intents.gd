class_name UiIntents
extends RefCounted
## Names of UI intents on the game event bus, and the payload keys each one carries.
## An intent without an answer carries an empty payload.

## Payload keys.
const KEY_LOCALE := "locale"

## Main menu. Payload: {}.
const START_GAME := "start_game"
const CONTINUE_GAME := "continue_game"
const EXIT_GAME := "exit_game"
const LANGUAGE_PICKER := "language_picker"

## Language picker choice. Payload: {KEY_LOCALE: String}.
const LANGUAGE_SELECTED := "language_selected"
