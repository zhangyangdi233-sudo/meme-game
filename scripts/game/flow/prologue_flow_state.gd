extends "res://framework/flow/flow_state.gd"
## Opening transmission. Enter installs the opening; exit unloads it. Play chrome stays declared underneath.

var _host: Node


func _init(host: Node) -> void:
	id = "prologue"
	_host = host


func enter() -> void:
	if _host != null:
		_host.install_prologue_screen()


func exit() -> void:
	if _host != null:
		_host.uninstall_prologue_screen()


func screen_set() -> PackedStringArray:
	return PackedStringArray(["prologue", "play"])
