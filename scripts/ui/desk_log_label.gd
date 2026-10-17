class_name DeskLogLabel
extends Label
## The desk log. While in the tree it watches the feedback text model and shows it.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")

## Takes this label and translates its text in place. The host passes the UI theme's localizer.
var localize: Callable = Callable()

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.FEEDBACK_TEXT: _on_feedback_text,
})


func _enter_tree() -> void:
	_watch.start()


func _on_feedback_text(value: Variant) -> void:
	text = str(value)
	if localize.is_valid():
		localize.call(self)
