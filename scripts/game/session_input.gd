class_name SessionInput
extends RefCounted
## Derives which overlay currently owns player input from adapter flags.
## Narrative overlays still set `_input_locked`; this module does not store a mode.

enum Owner {
	PROLOGUE,
	NARRATIVE_LOCK,
	MAIN_MENU,
	GAMEPLAY,
}


static func owner_from(prologue_visible: bool, input_locked: bool, game_started: bool) -> Owner:
	if prologue_visible:
		return Owner.PROLOGUE
	if input_locked:
		return Owner.NARRATIVE_LOCK
	if not game_started:
		return Owner.MAIN_MENU
	return Owner.GAMEPLAY


static func blocks_world_pointer(owner: Owner) -> bool:
	return owner == Owner.PROLOGUE or owner == Owner.NARRATIVE_LOCK


static func blocks_unhandled_gameplay(owner: Owner) -> bool:
	return owner != Owner.GAMEPLAY
