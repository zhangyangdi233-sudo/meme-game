extends "res://framework/flow/flow_state.gd"
## Ending screen. Declares only the ending; the host still shows and hides it. World hotkeys stay unloaded.

func _init(_host: Node) -> void:
	id = "ending"


func screen_set() -> PackedStringArray:
	return PackedStringArray(["ending"])
