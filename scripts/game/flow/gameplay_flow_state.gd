extends "res://framework/flow/flow_state.gd"
## In-run world. Enter installs the play screen and the world hotkey pack; exit removes both.

var _host: Node


func _init(host: Node) -> void:
	id = "gameplay"
	_host = host


func enter() -> void:
	if _host != null:
		_host.install_play_screen()
		_host.install_world_hotkeys()


func exit() -> void:
	if _host != null:
		_host.uninstall_world_hotkeys()
		_host.uninstall_play_screen()


func handle_input(event: InputEvent) -> void:
	if _host != null:
		_host.handle_gameplay_unhandled_input(event)


func screen_set() -> PackedStringArray:
	return PackedStringArray(["play"])
