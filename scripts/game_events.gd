class_name GameEvents
extends RefCounted
## Names of game events on the game event bus, and the payload keys each one carries.
## A game event says that something happened once; any number of listeners may subscribe to it (ADR 0007).

## Payload keys.
const KEY_CUE := "cue"

## A short sound was asked for. Payload: {KEY_CUE: String}, one of the CUE_* names below.
const SFX_REQUESTED := "sfx_requested"

## Sound cues carried by SFX_REQUESTED.
const CUE_PICKUP_PRESS := "pickup_press"
const CUE_PICKUP_LAND := "pickup_land"
const CUE_NOTEBOOK_HINGE := "notebook_hinge"
