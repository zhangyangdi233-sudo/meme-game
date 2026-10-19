class_name IntentResult
extends RefCounted
## What one routed intent asks the host to present. The handler has already changed the state and written its
## feedback line; the host only presents (ADR 0007: the host stays the only listener).
## The kinds here are shared by every domain; a domain's own kinds live on its handler.

const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")

## Nothing to present: the open screens watch the models the handler wrote.
const NONE := ""
## A free sentence submit; the host presents its outcome when it was posted.
const SUBMIT := "submit"

var presentation := NONE
var outcome: ActionOutcomeScript
## The word a pickup or a placement flies.
var unit := ""
## The one value the presentation needs, such as whether a word was placed or the new VHS setting.
var value: Variant


static func present(presentation_name: String, action_outcome: ActionOutcomeScript = null) -> IntentResult:
	var result := IntentResult.new()
	result.presentation = presentation_name
	result.outcome = action_outcome
	return result
