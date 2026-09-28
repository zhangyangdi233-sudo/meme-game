extends "res://framework/flow/flow_state.gd"
## Flashback, day transition, and action-spend. Enter installs that screen and the play chrome underneath it; exit removes both.

var _host: Node


func _init(host: Node) -> void:
	id = "narrative"
	_host = host


func enter() -> void:
	if _host != null:
		_host.install_narrative_screen()
		_host.install_play_screen()


func exit() -> void:
	if _host != null:
		_host.uninstall_play_screen()
		_host.uninstall_narrative_screen()


func screen_set() -> PackedStringArray:
	return PackedStringArray(["narrative", "play"])
