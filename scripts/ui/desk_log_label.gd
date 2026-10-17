class_name DeskLogLabel
extends Label
## The desk log. While in the tree it watches the feedback text model and shows it,
## translated through the bound UI theme.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.FEEDBACK_TEXT: _on_feedback_text,
})


func _enter_tree() -> void:
	_watch.start()


func _on_feedback_text(value: Variant) -> void:
	text = str(value)
	var theme := GameUiThemeScript.bound()
	if theme != null:
		theme.set_localized_property(self, "text")
