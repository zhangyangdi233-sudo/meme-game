extends "res://framework/flow/flow_state.gd"
## Title screen. Enter installs the title; exit unloads it. World hotkeys stay unloaded.

var _host: Node


func _init(host: Node) -> void:
	id = "main_menu"
	_host = host


func enter() -> void:
	if _host != null:
		_host.install_title_screen()


func exit() -> void:
	if _host != null:
		_host.uninstall_title_screen()


func screen_set() -> PackedStringArray:
	return PackedStringArray(["title"])
