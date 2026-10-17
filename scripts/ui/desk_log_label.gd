class_name DeskLogLabel
extends Label
## The desk log. While in the tree it watches the feedback text model and shows it,
## translated through the bound UI theme.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.FEEDBACK_TEXT: _on_feedback_text,
})


func _enter_tree() -> void:
	_watch.start()


func _on_feedback_text(value: Variant) -> void:
	text = str(value)
	if ServiceRegistryScript.has(ServiceKeysScript.UI_THEME):
		(ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme).set_localized_property(self, "text")
