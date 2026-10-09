@tool
@abstract
class_name UIBase
extends PaletteSceneRoot
## Root of a fixed layout scene.
## Subclasses declare SCENE_PATH, LAYER_NAME, and BUTTON_INTENTS.
## Button wiring lives here; subclasses do not connect buttons themselves.


var _intents_bound := false


func bind_intents(bus: GameEventBus) -> void:
	if _intents_bound or bus == null:
		return
	_intents_bound = true
	var intents: Dictionary = get_script().get_script_constant_map().get("BUTTON_INTENTS", {})
	for button_name in intents.keys():
		var button := get_node_or_null(NodePath("%%%s" % str(button_name))) as Button
		if button == null:
			push_error("UIBase missing button %s" % str(button_name))
			continue
		button.pressed.connect(_raise_intent.bind(bus, str(intents[button_name])))


func _raise_intent(bus: GameEventBus, intent_name: String) -> void:
	bus.emit_intent(intent_name)


@abstract
func present(_context: Dictionary) -> void


func dismiss() -> void:
	pass
