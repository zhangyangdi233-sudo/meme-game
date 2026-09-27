extends "res://framework/flow/flow_state.gd"
## Flashback, day transition, and action-spend. Declares that screen plus the play chrome still underneath it.

func _init(_host: Node) -> void:
	id = "narrative"


func screen_set() -> PackedStringArray:
	return PackedStringArray(["narrative", "play"])
