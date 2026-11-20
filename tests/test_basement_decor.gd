extends SceneTree
## #114: what the basement shows that changes from run to run comes from the run's seed: the exit table holds a vase
## or a book each round, and round three's chairs scatter the same way every time for one seed.
## The chairs are solid (planner, 2026-11-20): laid on a described floor, the pile keeps out of the furniture and
## leaves every place the round needs within walking reach.

const DecorScript = preload("res://scripts/game/basement_decor.gd")

var _failures: Array[String] = []


func _init() -> void:
	test_the_exit_table_holds_a_vase_or_a_book_by_the_seed()
	test_the_scattered_chairs_follow_the_seed()
	test_a_chair_across_a_corridor_shuts_it()
	test_a_pile_on_a_described_floor_leaves_it_walkable()
	test_a_place_the_room_keeps_out_of_reach_does_not_unsolid_the_pile()
	test_a_floor_nobody_can_cross_gets_a_pile_with_nothing_solid()
	if _failures.is_empty():
		print("basement decor tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_the_exit_table_holds_a_vase_or_a_book_by_the_seed() -> void:
	var seen := {}
	for seed in range(1, 40):
		for round_number in range(1, 6):
			var prop: String = DecorScript.exit_table_prop(seed, round_number)
			_assert_true(prop in DecorScript.EXIT_TABLE_PROPS, "the exit table should hold a vase or a book: %s" % prop)
			_assert_true(prop == DecorScript.exit_table_prop(seed, round_number), "one seed and round should always pick the same")
			seen[prop] = true
	_assert_true(seen.size() == DecorScript.EXIT_TABLE_PROPS.size(), "runs should see both the vase and the book")


func test_the_scattered_chairs_follow_the_seed() -> void:
	var first: Array = DecorScript.scattered_chairs(1701)
	_assert_true(first.size() == DecorScript.SCATTERED_CHAIR_COUNT, "the pile should have its chairs")
	_assert_true(first == DecorScript.scattered_chairs(1701), "one seed should scatter the chairs the same way")
	_assert_true(first != DecorScript.scattered_chairs(1702), "another seed should scatter them differently")
	for chair: Dictionary in first:
		var at: Vector3 = chair["position"]
		_assert_true(DecorScript.SCATTER_AREA.has_point(Vector2(at.x, at.z)), "a chair should lie in the open room: %s" % at)
		_assert_true(int(chair["model"]) >= 0, "a chair should reuse one of the room's chair models")


## A corridor 2.4 m wide between two walls, walked from one end to the other.
func _corridor() -> Dictionary:
	return {
		"area": Rect2(0.0, 0.0, 2.8, 6.0),
		"blocks": [Rect2(-0.2, 0.0, 0.4, 6.0), Rect2(2.6, 0.0, 0.4, 6.0)],
		"start": [[Vector2(1.4, 0.6), 0.4]],
		"reach": [[Vector2(1.4, 5.4), 0.4]],
	}


func test_a_chair_across_a_corridor_shuts_it() -> void:
	var standing := {"position": Vector3(2.2, 0.0, 3.0), "yaw": 0.0, "tilt": 0.0, "model": 0, "solid": true}
	_assert_true(DecorScript.leaves_walkable([standing], _corridor()), "a chair standing at one side should leave a way past")
	var lying := standing.duplicate()
	lying["position"] = Vector3(1.9, 0.0, 3.0)
	lying["tilt"] = PI * 0.5
	var footprint: Dictionary = DecorScript.chair_footprint(lying)
	_assert_true((footprint["middle"] as Vector2).is_equal_approx(Vector2(1.4, 3.0)), "a tipped chair should lie along its own -X from its feet: %s" % footprint["middle"])
	# Two chairs that leave 0.8 m by one wall: the player's 0.68 m would squeeze past, which is not a way through the pile.
	var near_wall := standing.duplicate()
	near_wall["position"] = Vector3(2.1, 0.0, 3.0)
	var beside := standing.duplicate()
	beside["position"] = Vector3(1.25, 0.0, 3.0)
	_assert_true(not DecorScript.leaves_walkable([near_wall, beside], _corridor()), "a gap only a little wider than the player should not count as a way past")
	_assert_true(not DecorScript.leaves_walkable([lying], _corridor()), "a chair lying across the corridor should shut it")
	lying["solid"] = false
	_assert_true(DecorScript.leaves_walkable([lying], _corridor()), "a chair that is not solid should shut nothing")


## The front room as the stage describes it: the walls, the partition with its opening at the east end, the stairs
## and the big table; the player comes from the foot of the stairs.
func _room() -> Dictionary:
	return {
		"area": Rect2(-3.2, -4.2, 6.4, 8.4),
		"blocks": [
			Rect2(-3.4, -4.4, 0.2, 8.8), Rect2(3.2, -4.4, 0.2, 8.8), Rect2(-3.4, -4.4, 6.8, 0.2), Rect2(-3.4, 4.2, 6.8, 0.2),
			Rect2(-3.19, -2.58, 4.84, 0.16), Rect2(-3.2, -2.6, 1.4, 5.34), Rect2(-1.62, -0.76, 0.88, 1.56),
		],
		"start": [[Vector2(-2.5, 3.4), 0.6]],
		"reach": [[Vector2(-2.85, -3.43), 0.9], [Vector2(1.3, 2.75), 0.7], [Vector2(-1.18, 0.02), 0.94], [Vector2(0.3, 1.5), 0.9]],
		"clear": [[Vector2(-1.4, 3.2), 0.5]],
	}


func test_a_pile_on_a_described_floor_leaves_it_walkable() -> void:
	var room := _room()
	var solid_piles := 0
	for seed in range(1, 41):
		var chairs: Array = DecorScript.scattered_chairs(seed, room)
		_assert_true(chairs.size() == DecorScript.SCATTERED_CHAIR_COUNT, "the pile should keep its chairs on a described floor")
		_assert_true(chairs == DecorScript.scattered_chairs(seed, room), "one seed should lay the same pile on the same floor")
		_assert_true(DecorScript.leaves_walkable(chairs, room), "seed %d's pile should leave the room walkable" % seed)
		if chairs.all(func(chair: Dictionary) -> bool: return bool(chair["solid"])):
			solid_piles += 1
		for chair: Dictionary in chairs:
			var at: Vector3 = chair["position"]
			_assert_true(DecorScript.SCATTER_AREA.has_point(Vector2(at.x, at.z)), "a chair should still lie in the open room: %s" % at)
			var footprint: Dictionary = DecorScript.chair_footprint(chair)
			var middle: Vector2 = footprint["middle"]
			var radius := (footprint["half"] as Vector2).length()
			for block: Rect2 in room["blocks"]:
				_assert_true(not block.grow(radius).has_point(middle), "seed %d's chair should keep its whole footprint out of the furniture: %s" % [seed, middle])
			_assert_true(middle.distance_to(room["clear"][0][0]) >= 0.5 + radius + DecorScript.WALKER_RADIUS, "seed %d's chair should keep away from the clear place: %s" % [seed, middle])
	_assert_true(solid_piles == 40, "every seed should find a solid pile in the open room: %d of 40" % solid_piles)


func test_a_place_the_room_keeps_out_of_reach_does_not_unsolid_the_pile() -> void:
	var room := _room()
	# A place inside the stairs' block: nobody gets there, chairs or not.
	(room["reach"] as Array).append([Vector2(-2.5, 0.0), 0.3])
	var chairs: Array = DecorScript.scattered_chairs(11, room)
	_assert_true(chairs.all(func(chair: Dictionary) -> bool: return bool(chair["solid"])), "a place the room itself keeps out of reach should not cost the pile its solid chairs")
	_assert_true(chairs == DecorScript.scattered_chairs(11, _room()), "the pile should be laid as if that place were not asked for")


func test_a_floor_nobody_can_cross_gets_a_pile_with_nothing_solid() -> void:
	var walled := _room()
	# A wall right across the room, between the stairs' foot and everything else.
	(walled["blocks"] as Array).append(Rect2(-3.4, 2.75, 6.8, 0.2))
	var chairs: Array = DecorScript.scattered_chairs(7, walled)
	_assert_true(chairs.size() == DecorScript.SCATTERED_CHAIR_COUNT, "the pile should still be laid")
	_assert_true(chairs.all(func(chair: Dictionary) -> bool: return not bool(chair["solid"])), "a pile that cannot leave the room walkable should have nothing solid")


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
