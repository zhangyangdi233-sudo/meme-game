extends "res://framework/flow/flow_state.gd"
## Title screen. Declares the title; the host still shows and hides it. World hotkeys stay unloaded.

func _init(_host: Node) -> void:
	id = "main_menu"


func screen_set() -> PackedStringArray:
	return PackedStringArray(["title"])
