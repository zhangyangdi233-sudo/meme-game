class_name ScreenManager
extends Node
## Opens and hides game screens. The host creates one; this is not an autoload.
## Opening a screen never closes another. Closing only hides, and the next open reuses the instance.


var _bus: GameEventBus
var _screens: Dictionary = {}


func _init(bus: GameEventBus) -> void:
	_bus = bus


func open(screen_script: Script, layer_host: Node, context: Dictionary = {}) -> Control:
	var layer_name := str(_constant(screen_script, "LAYER_NAME"))
	var layer := _resolve_layer(layer_host, layer_name)
	if layer == null:
		push_error("ScreenManager missing UI layer %s" % layer_name)
		return null
	var created := false
	var screen := _live(screen_script)
	if screen == null:
		screen = _instantiate(screen_script)
		if screen == null:
			return null
		_screens[screen_script] = screen
		created = true
	_place(screen, layer)
	if created and screen is UIBase:
		(screen as UIBase).bind_intents(_bus)
	screen.visible = true
	if screen is UIBase:
		(screen as UIBase).present(context)
	return screen


func close(screen_script: Script) -> void:
	var screen := _live(screen_script)
	if screen == null:
		return
	screen.visible = false
	_keep(screen)


func retain() -> void:
	for key in _screens.keys():
		var screen := _live(key)
		if screen == null:
			continue
		_keep(screen)


func _instantiate(screen_script: Script) -> Control:
	var scene_path := str(_constant(screen_script, "SCENE_PATH"))
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


func _live(screen_script: Variant) -> Control:
	if not screen_script is Script or not _screens.has(screen_script):
		return null
	var screen: Variant = _screens[screen_script]
	if not is_instance_valid(screen) or not screen is Control:
		_screens.erase(screen_script)
		return null
	return screen as Control


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
