extends "res://framework/flow/flow_state.gd"
## Opening transmission. Declares the opening and the play chrome under it. The host still applies that set.

func _init(_host: Node) -> void:
	id = "prologue"


func screen_set() -> PackedStringArray:
	return PackedStringArray(["prologue", "play"])
