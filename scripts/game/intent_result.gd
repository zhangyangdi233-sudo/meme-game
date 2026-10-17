class_name IntentResult
extends RefCounted
## What one routed intent asks the host to present. The handler has already changed the state and written its
## feedback line; the host only presents (ADR 0007: the host stays the only listener).

const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")

## Nothing to present: the open screens watch the models the handler wrote.
const NONE := ""
## The social panel already repainted its page; the host re-themes the phone shell.
const SOCIAL_PAGE_CHANGED := "social_page_changed"
## The social window closed; the host shuts the open post and refreshes the phone shell.
const SOCIAL_WINDOW_CLOSED := "social_window_closed"
## A spending action; the host shows its feedback and settles it.
const ACTION := "action"
## A word pickup; the host flies the word and settles when it spent the day's first action.
const PICKUP := "pickup"
## A free sentence submit; the host settles it when it was posted.
const SUBMIT := "submit"

var presentation := NONE
var outcome: ActionOutcomeScript
## The word a pickup flies to the notebook.
var picked_unit := ""


static func present(presentation_name: String, action_outcome: ActionOutcomeScript = null) -> IntentResult:
	var result := IntentResult.new()
	result.presentation = presentation_name
	result.outcome = action_outcome
	return result
