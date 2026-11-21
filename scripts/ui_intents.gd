class_name UiIntents
extends RefCounted
## Names of UI intents on the game event bus, and the payload keys each one carries.
## An intent without an answer carries an empty payload.

## Payload keys.
const KEY_LOCALE := "locale"
const KEY_APP_ID := "app_id"
const KEY_ALLOWED := "allowed"
const KEY_INDEX := "index"
const KEY_VALUE := "value"
const KEY_CHOICE_ID := "choice_id"
const KEY_CHANNEL := "channel"
const KEY_SCREEN := "screen"
const KEY_POST_INDEX := "post_index"
const KEY_POST_ID := "post_id"
const KEY_AUTHOR_ID := "author_id"
const KEY_META := "meta"
const KEY_DATA := "data"
const KEY_BEFORE_INDEX := "before_index"
const KEY_UNIT_INDEX := "unit_index"
const KEY_TILE_POSITIONS := "tile_positions"
const KEY_UNIT := "unit"

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

## Settings window. Payload: {KEY_VALUE: float} for the volume, {KEY_VALUE: bool} for a toggle, {} for a button.
const VOLUME_CHANGED := "volume_changed"
const AUTOPLAY_TOGGLED := "autoplay_toggled"
const VHS_TOGGLED := "vhs_toggled"
const TERMINAL_VHS_TOGGLED := "terminal_vhs_toggled"
const MANUAL_SAVE_PRESSED := "manual_save_pressed"
const RETURN_MAIN_MENU_PRESSED := "return_main_menu_pressed"
const EXIT_GAME_REQUESTED := "exit_game_requested"
const EXIT_CONFIRMED := "exit_confirmed"
const HISTORY_TOGGLE_REQUESTED := "history_toggle_requested"

## HUD settings button. Payload: {}.
const SETTINGS_PRESSED := "settings_pressed"

## A click on the shown opening narration line, and the ending screen. Payload: {} except the language choice,
## {KEY_CHOICE_ID: String}.
const OPENING_NARRATION_ADVANCED := "opening_narration_advanced"
const ENDING_LANGUAGE_SELECTED := "ending_language_selected"
const RESTART_REQUESTED := "restart_requested"

## The basement CRT terminal. Payload: {KEY_APP_ID: String} for an app tab, {} for the exit.
const TERMINAL_APP_SELECTED := "terminal_app_selected"
const TERMINAL_EXIT_REQUESTED := "terminal_exit_requested"

## The F9 chapter debug panel (debug builds only). Payload: {KEY_INDEX: int}, the basement round to jump to.
const CHAPTER_ROUND_JUMP_REQUESTED := "chapter_round_jump_requested"

## Social feed. Payload: {KEY_CHANNEL: String} for a channel tab, {KEY_SCREEN: String} for a page change,
## {KEY_POST_INDEX: int} for a card, {KEY_POST_ID: String} for a like, {KEY_AUTHOR_ID: String} for a follow,
## {KEY_META: Variant, KEY_POST_ID: String} for a pickup unit, {} for the rest.
const SOCIAL_CHANNEL_PRESSED := "social_channel_pressed"
const SOCIAL_SCREEN_REQUESTED := "social_screen_requested"
const SOCIAL_CARD_CLICKED := "social_card_clicked"
const SOCIAL_LIKE_PRESSED := "social_like_pressed"
const SOCIAL_FOLLOW_PRESSED := "social_follow_pressed"
const SOCIAL_PICKUP_UNIT_CLICKED := "social_pickup_unit_clicked"
const SOCIAL_CLOSE_REQUESTED := "social_close_requested"
const SOCIAL_DETAIL_CLOSE_REQUESTED := "social_detail_close_requested"

## Notebook: words above, the sentence and its post button below (#154). Payload: {KEY_TILE_POSITIONS: Dictionary}
## for the resting canvas tiles, {KEY_UNIT: String} for a tapped tile, {KEY_DATA: Dictionary} for a drop on the
## sentence, {KEY_DATA: Dictionary, KEY_BEFORE_INDEX: int} for a drop before a sentence word, {KEY_UNIT_INDEX: int}
## for a tapped sentence word, {} for the rest.
const NOTEBOOK_CRAFT_REQUESTED := "notebook_craft_requested"
const NOTEBOOK_CANVAS_POSITIONS_COMMITTED := "notebook_canvas_positions_committed"
const NOTEBOOK_SENTENCE_AREA_DROPPED := "notebook_sentence_area_dropped"
const NOTEBOOK_SENTENCE_TILE_DROPPED := "notebook_sentence_tile_dropped"
const NOTEBOOK_SENTENCE_TILE_TAPPED := "notebook_sentence_tile_tapped"
const NOTEBOOK_COMPOSER_BANK_TAPPED := "notebook_composer_bank_tapped"

## Reality conversation. Payload: {KEY_CHOICE_ID: String} for a choice, {} for the continue button.
const CONVERSATION_CHOICE_HOVERED := "conversation_choice_hovered"
const CONVERSATION_CHOICE_UNHOVERED := "conversation_choice_unhovered"
const CONVERSATION_CHOICE_PRESSED := "conversation_choice_pressed"
const CONVERSATION_CONTINUE_PRESSED := "conversation_continue_pressed"

