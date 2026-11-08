class_name BasementDecor
extends RefCounted
## What the basement shows that changes from run to run but holds within one, drawn from the run's seed (#114): the
## vase or the book on the exit table each round, and how round three's chairs lie once its light is back. Pure, so one
## seed gives the same room after a save or a walk back.

const EXIT_TABLE_PROPS := ["vase", "book"]
const SCATTERED_CHAIR_COUNT := 9
## The open floor of the front room (x, z), clear of the stairs, the partition and the CRT's console.
const SCATTER_AREA := Rect2(-1.4, -2.2, 3.6, 5.0)


## What lies on the exit table in `round_number` of the run seeded `seed`.
static func exit_table_prop(seed: int, round_number: int) -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, round_number, "exit_table"])
	return EXIT_TABLE_PROPS[rng.randi_range(0, EXIT_TABLE_PROPS.size() - 1)]


## Round three's pile of chairs for the run seeded `seed`: each with its `position` on the floor, its `yaw` and `tilt`
## in radians (a tipped chair lies on its side) and which of the room's chair models it copies (`model`, an index).
static func scattered_chairs(seed: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "scattered_chairs"])
	var chairs: Array = []
	for index in SCATTERED_CHAIR_COUNT:
		chairs.append({
			"position": Vector3(
				rng.randf_range(SCATTER_AREA.position.x, SCATTER_AREA.end.x),
				0.0,
				rng.randf_range(SCATTER_AREA.position.y, SCATTER_AREA.end.y)
			),
			"yaw": rng.randf_range(-PI, PI),
			"tilt": PI * 0.5 if rng.randf() < 0.3 else 0.0,
			"model": rng.randi_range(0, 2),
		})
	return chairs
