class_name GameEvents
extends RefCounted
## Names of game events on the game event bus, and the payload keys each one carries.
## A game event says that something happened once; any number of listeners may subscribe to it (ADR 0007).

## Payload keys.
const KEY_CUE := "cue"
const KEY_FLOOR := "floor"
const KEY_DAY := "day"
const KEY_FROM_FLASHBACK := "from_flashback"

## A short sound was asked for. Payload: {KEY_CUE: String}, one of the CUE_* names below.
const SFX_REQUESTED := "sfx_requested"

## The cover watcher stepped out into the player's view. Payload: {KEY_FLOOR: int}, the tower floor it watched from.
const COVER_WATCHER_APPEARED := "cover_watcher_appeared"
## The cover watcher finished withdrawing behind its cover. Payload: {KEY_FLOOR: int}.
const COVER_WATCHER_VANISHED := "cover_watcher_vanished"

## The state settled the day. Raised once per settlement. Payload: {KEY_DAY: int, the new day;
## KEY_FROM_FLASHBACK: bool, true when the pollution flashback's finish settled it}.
const DAY_SETTLED := "day_settled"
## The pollution flashback director's timeline ended, whether its finish settles the day or a day transition already had.
## Payload: {}.
const FLASHBACK_FINISHED := "flashback_finished"

## Sound cues carried by SFX_REQUESTED.
const CUE_PICKUP_PRESS := "pickup_press"
const CUE_PICKUP_LAND := "pickup_land"
const CUE_NOTEBOOK_HINGE := "notebook_hinge"
