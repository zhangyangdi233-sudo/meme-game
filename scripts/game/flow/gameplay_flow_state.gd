extends "res://framework/flow/flow_state.gd"
## In-run world. Declares the play chrome; the host still applies it. Enter installs the world hotkey pack; exit removes it.

var _host: Node


func _init(host: Node) -> void:
	id = "gameplay"
	_host = host


func enter() -> void:
	if _host != null:
		_host.install_world_hotkeys()


func exit() -> void:
	if _host != null:
		_host.uninstall_world_hotkeys()


func handle_input(event: InputEvent) -> void:
	if _host != null:
		_host.handle_gameplay_unhandled_input(event)


func screen_set() -> PackedStringArray:
	return PackedStringArray(["play"])
