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

const RUN: Array[String] = [POLLUTION, MONEY, ACTIONS_REMAINING, AUTOPLAY_ENABLED, ENDING_LANGUAGE_CHOICE]
const PREFERENCES: Array[String] = [LOCALE, MASTER_VOLUME]
const UNSAVED: Array[String] = [HAS_SAVE]
