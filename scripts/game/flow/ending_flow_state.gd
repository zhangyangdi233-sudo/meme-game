extends "res://framework/flow/flow_state.gd"
## Ending screen. Enter installs it; exit unloads it. World hotkeys stay unloaded.

var _host: Node


func _init(host: Node) -> void:
	id = "ending"
	_host = host


func enter() -> void:
	if _host != null:
		_host.install_ending_screen()


func exit() -> void:
	if _host != null:
		_host.uninstall_ending_screen()


func screen_set() -> PackedStringArray:
	return PackedStringArray(["ending"])
