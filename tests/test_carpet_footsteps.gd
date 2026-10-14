extends SceneTree

func _init() -> void:
	var script = load("res://scripts/world/carpet_footsteps.gd")
	if script == null:
		push_error("carpet footsteps component must exist")
		quit(1)
		return
	var foley = script.new()
	root.add_child(foley)
	foley.advance(Vector3.ZERO, true, true)
	foley.advance(Vector3(0.5, 0, 0), true, true)
	assert(foley.step_count == 0, "short motion should not play a full step")
	foley.advance(Vector3(1.0, 0, 0), true, true)
	assert(foley.step_count == 1, "walking a stride produces a step")
	foley.advance(Vector3(1.0, 0, 0), true, true)
	assert(foley.step_count == 1, "standing still stays silent")
	foley.advance(Vector3(2, 0, 0), true, false)
	assert(foley.step_count == 1, "airborne player stays silent")
	foley.advance(Vector3(3, 0, 0), false, true)
	assert(foley.step_count == 1, "pause, terminal and other floors stay silent")
	foley.advance(Vector3(30, 0, 0), true, true)
	assert(foley.step_count == 1, "scene teleport produces no step")
	foley.free()
	print("carpet footsteps passed")
	quit(0)
