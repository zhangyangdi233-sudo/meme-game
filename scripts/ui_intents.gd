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
const KEY_TAB_ID := "tab_id"
const KEY_TILE_POSITIONS := "tile_positions"
const KEY_UNIT := "unit"
const KEY_RELEASE_GLOBAL := "release_global"
const KEY_SLOT_ID := "slot_id"

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
const MANUAL_SAVE_PRESSED := "manual_save_pressed"
const RETURN_MAIN_MENU_PRESSED := "return_main_menu_pressed"
const EXIT_GAME_REQUESTED := "exit_game_requested"
const EXIT_CONFIRMED := "exit_confirmed"
const HISTORY_TOGGLE_REQUESTED := "history_toggle_requested"

## HUD settings button. Payload: {}.
const SETTINGS_PRESSED := "settings_pressed"

## Prologue end and ending screen. Payload: {} except the language choice, {KEY_CHOICE_ID: String}.
const PROLOGUE_FINISHED := "prologue_finished"
const ENDING_LANGUAGE_SELECTED := "ending_language_selected"
const RESTART_REQUESTED := "restart_requested"

## Social feed. Payload: {KEY_CHANNEL: String} for a channel tab, {KEY_SCREEN: String} for a page change,
## {KEY_POST_INDEX: int} for a card, {KEY_POST_ID: String} for a like, {KEY_AUTHOR_ID: String} for a follow,
## {KEY_META: Variant, KEY_POST_ID: String} for a pickup unit, {KEY_DATA: Dictionary} for a drop on the sentence area,
## {KEY_DATA: Dictionary, KEY_BEFORE_INDEX: int} for a drop before a tile, {KEY_UNIT_INDEX: int} for a placed tile, {} for the rest.
const SOCIAL_CHANNEL_PRESSED := "social_channel_pressed"
const SOCIAL_SCREEN_REQUESTED := "social_screen_requested"
const SOCIAL_CARD_CLICKED := "social_card_clicked"
const SOCIAL_LIKE_PRESSED := "social_like_pressed"
const SOCIAL_FOLLOW_PRESSED := "social_follow_pressed"
const SOCIAL_PICKUP_UNIT_CLICKED := "social_pickup_unit_clicked"
const SOCIAL_COMPOSER_AREA_DROPPED := "social_composer_area_dropped"
const SOCIAL_COMPOSER_TILE_DROPPED := "social_composer_tile_dropped"
const SOCIAL_COMPOSER_ANSWER_TAPPED := "social_composer_answer_tapped"
const SOCIAL_CLOSE_REQUESTED := "social_close_requested"
const SOCIAL_DETAIL_CLOSE_REQUESTED := "social_detail_close_requested"
const SOCIAL_PUBLISH_CONFIRM_REQUESTED := "social_publish_confirm_requested"
const SOCIAL_COMPOSER_SUBMIT_REQUESTED := "social_composer_submit_requested"

## Notebook. Payload: {KEY_TAB_ID: String} for a tab change, {KEY_TILE_POSITIONS: Dictionary} for the resting canvas tiles,
## {KEY_UNIT: String, KEY_RELEASE_GLOBAL: Vector2} for a tile dropped off the canvas, {KEY_UNIT: String} for a tapped tile,
## {KEY_DATA: Dictionary, KEY_SLOT_ID: String} for a meme dropped on a fusion slot, {KEY_SLOT_ID: String} for a pressed slot, {} for the rest.
const NOTEBOOK_CRAFT_REQUESTED := "notebook_craft_requested"
const NOTEBOOK_FUSION_REQUESTED := "notebook_fusion_requested"
const NOTEBOOK_TAB_CHANGED := "notebook_tab_changed"
const NOTEBOOK_CANVAS_POSITIONS_COMMITTED := "notebook_canvas_positions_committed"
const NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE := "notebook_canvas_tile_dropped_outside"
const NOTEBOOK_COMPOSER_BANK_TAPPED := "notebook_composer_bank_tapped"
const NOTEBOOK_FUSION_MEME_DROPPED := "notebook_fusion_meme_dropped"
const NOTEBOOK_FUSION_SLOT_PRESSED := "notebook_fusion_slot_pressed"
