class_name UiIntents
extends RefCounted
## Names of UI intents on the game event bus, and the payload keys each one carries.
## An intent without an answer carries an empty payload.

## Payload keys.
const KEY_LOCALE := "locale"
const KEY_APP_ID := "app_id"
const KEY_ALLOWED := "allowed"
const KEY_INDEX := "index"

## Main menu. Payload: {}.
const START_GAME := "start_game"
const CONTINUE_GAME := "continue_game"
const EXIT_GAME := "exit_game"
const LANGUAGE_PICKER := "language_picker"

## Language picker choice. Payload: {KEY_LOCALE: String}.
const LANGUAGE_SELECTED := "language_selected"

## Phone launcher. Payload: {KEY_APP_ID: String} for an icon or a window close, {} for the phone close.
const APP_ICON_PRESSED := "app_icon_pressed"
const PHONE_CLOSE_REQUESTED := "phone_close_requested"
const APP_WINDOW_CLOSE_REQUESTED := "app_window_close_requested"

## Camera consent. Payload: {KEY_ALLOWED: bool} for the answer, {KEY_INDEX: int} for the chosen source.
const CAMERA_CONSENT_RESOLVED := "camera_consent_resolved"
const CAMERA_SOURCE_SELECTED := "camera_source_selected"

## Phone-camera connection overlay. Payload: {}.
const PHONE_CAMERA_RETRY := "phone_camera_retry"
const PHONE_CAMERA_CONTINUE := "phone_camera_continue"
const PHONE_CAMERA_DISABLE := "phone_camera_disable"
