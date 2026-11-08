class_name ScreenManager
extends Node
## Opens and hides one game screen. The host creates one; this is not an autoload.
## The screen script and the stable layer host are fixed at init. open() only receives what changes each time the screen is shown.


var _bus: GameEventBus
var _screen_script: Script
var _layer_host: Node
var _layer_name := ""
var _screen: Control


func _init(bus: GameEventBus, screen_script: Script, layer_host: Node) -> void:
	_bus = bus
	_screen_script = screen_script
	_layer_host = layer_host
	_layer_name = str(_constant(screen_script, "LAYER_NAME"))


func open(context: Dictionary = {}) -> Control:
	var layer := _resolve_layer(_layer_host, _layer_name)
	if layer == null:
		push_error("ScreenManager missing UI layer %s" % _layer_name)
		return null
	var created := false
	var screen := _live()
	if screen == null:
		screen = _instantiate()
		if screen == null:
			return null
		_screen = screen
		created = true
	_place(screen, layer)
	if created and screen is UIBase:
		(screen as UIBase).bind_intents(_bus)
	screen.visible = true
	if screen is UIBase:
		(screen as UIBase).present(context)
	return screen


func close() -> void:
	var screen := _live()
	if screen == null:
		return
	if screen is UIBase:
		(screen as UIBase).dismiss()
	screen.visible = false
	_keep(screen)


func retain() -> void:
	var screen := _live()
	if screen == null:
		return
	_keep(screen)


func _instantiate() -> Control:
	var scene_path := str(_constant(_screen_script, "SCENE_PATH"))
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_error("ScreenManager could not load %s" % scene_path)
		return null
	return packed.instantiate() as Control


func _keep(screen: Control) -> void:
	_place(screen, self)


func _place(screen: Node, parent: Node) -> void:
	if screen.get_parent() == parent:
		return
	if screen.is_inside_tree() and parent.is_inside_tree():
		screen.reparent(parent)
		return
	var current := screen.get_parent()
	if current != null:
		current.remove_child(screen)
	parent.add_child(screen)


func _live() -> Control:
	if not is_instance_valid(_screen):
		_screen = null
		return null
	return _screen


func _resolve_layer(layer_host: Node, layer_name: String) -> Control:
	if layer_host == null or layer_name.is_empty():
		return null
	if layer_host is Control and str(layer_host.name) == layer_name:
		return layer_host as Control
	var found := layer_host.find_child(layer_name, true, false)
	return found as Control


func _constant(screen_script: Script, key: String) -> Variant:
	if screen_script == null:
		return null
	return screen_script.get_script_constant_map().get(key, null)
