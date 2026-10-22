class_name GameEvents
extends RefCounted
## Names of game events on the game event bus, and the payload keys each one carries.
## A game event says that something happened once; any number of listeners may subscribe to it (ADR 0007).

## Payload keys.
const KEY_CUE := "cue"
const KEY_FLOOR := "floor"

## A short sound was asked for. Payload: {KEY_CUE: String}, one of the CUE_* names below.
const SFX_REQUESTED := "sfx_requested"

## The cover watcher stepped out into the player's view. Payload: {KEY_FLOOR: int}, the tower floor it watched from.
const COVER_WATCHER_APPEARED := "cover_watcher_appeared"
## The cover watcher finished withdrawing behind its cover. Payload: {KEY_FLOOR: int}.
const COVER_WATCHER_VANISHED := "cover_watcher_vanished"

## The pollution flashback director's timeline ended. Payload: {}.
const FLASHBACK_FINISHED := "flashback_finished"

## The knock at chapter one's white door played to its end. Payload: {}.
const OPENING_KNOCK_FINISHED := "opening_knock_finished"

## Sound cues carried by SFX_REQUESTED.
const CUE_PICKUP_PRESS := "pickup_press"
const CUE_PICKUP_LAND := "pickup_land"
const CUE_NOTEBOOK_HINGE := "notebook_hinge"
