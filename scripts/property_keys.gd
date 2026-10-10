class_name PropertyKeys
extends RefCounted
## Model names and the save list each name belongs to.

const POLLUTION := "pollution"
const HAS_SAVE := "has_save"
const MONEY := "money"
const ACTIONS_REMAINING := "actions_remaining"
const AUTOPLAY_ENABLED := "autoplay_enabled"
const LOCALE := "locale"
const MASTER_VOLUME := "master_volume"
const ENDING_LANGUAGE_CHOICE := "ending_language_choice"
const PHONE_OPEN := "phone_open"
const ACTIVE_APP := "active_app"
const ACTIVE_APP_WINDOW := "active_app_window"

const RUN: Array[String] = [POLLUTION, MONEY, ACTIONS_REMAINING, AUTOPLAY_ENABLED, ENDING_LANGUAGE_CHOICE, PHONE_OPEN, ACTIVE_APP, ACTIVE_APP_WINDOW]
const PREFERENCES: Array[String] = [LOCALE, MASTER_VOLUME]
const UNSAVED: Array[String] = [HAS_SAVE]
