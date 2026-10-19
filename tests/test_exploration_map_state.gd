extends SceneTree

const SCRIPT_PATH := "res://scripts/world/exploration_map_state.gd"
var failures: Array[String] = []
var checks := 0


func _init() -> void:
	if not FileAccess.file_exists(SCRIPT_PATH):
		_check(false, "exploration map provides persistent geometry-aware state")
	else:
		_test_exploration(load(SCRIPT_PATH))
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("exploration map state tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)


func _test_exploration(state_script: Script) -> void:
	var state = state_script.new()
	var large := _layout(["###", "#.#", "###"], 8.0, Vector2(-12, -12))
	state.configure(large)
	var snapshot: Dictionary = state.snapshot(Vector3.ZERO, 0.0)
	_check(snapshot.columns == 12 and snapshot.rows == 12, "8m layout cells expand to a 2m exploration grid")
	_check(snapshot.explored is PackedByteArray and snapshot.walkable is PackedByteArray, "phone receives compact typed masks")
	_check(snapshot.explored.size() == 144 and snapshot.walkable.count(1) == 16, "coarse road cells expand consistently to four-by-four walkable cells")
	_check(snapshot.explored.count(1) == 0 and snapshot.explored_ratio == 0.0, "snapshot alone cannot reveal the map")
	_check(snapshot.player_uv.is_equal_approx(Vector2(0.5, 0.5)), "negative world origins map to normalized phone coordinates")
	_check(not state.reveal_at(Vector3(-11, 0, -11)), "positions inside buildings cannot reveal neighboring roads")
	_check(state.reveal_at(Vector3.ZERO), "entering a valid location reveals its surroundings")
	_check(not state.reveal_at(Vector3.ZERO), "the same visit does not re-dirty permanent exploration")
	snapshot = state.snapshot(Vector3.ZERO, 1.25)
	_check(snapshot.active and is_equal_approx(snapshot.heading_radians, 1.25), "snapshot preserves active player heading in radians")
	_check(snapshot.explored_ratio > 0.0 and snapshot.explored_ratio <= 1.0, "exploration ratio measures bounded discovered walkable area")
	var copy: PackedByteArray = snapshot.explored
	copy.fill(0)
	_check(state.snapshot(Vector3.ZERO, 0.0).explored.count(1) > 0, "UI cannot erase model exploration through its snapshot")
	snapshot.walkable.fill(0)
	_check(state.snapshot(Vector3.ZERO, 0.0).walkable.count(1) == 16, "UI cannot mutate the authoritative walkable mask")
	_check(not state.snapshot(Vector3.ZERO, 0.0, false).active, "another floor can display stored exploration without current localization")
	_check(not state.snapshot(Vector3(500, 0, 500), 0.0).active, "outside positions do not claim a current position on this map")
	var extreme: Dictionary = state.snapshot(Vector3(1.0e30, 0, -1.0e30), NAN)
	_check(not extreme.active and extreme.player_uv == Vector2(1, 0) and extreme.heading_radians == 0.0, "extreme finite positions and invalid headings remain bounded")
	_check(not state.reveal_at(Vector3.INF) and not state.reveal_at(Vector3(NAN, 0, 0)), "non-finite world positions are safely rejected")
	var thin := _layout(["#######", "#.....#", "#.#...#", "#.....#", "#######"], 2.0)
	state.configure(thin)
	_check(state.reveal_at(Vector3(3, 0, 5)), "wall-occlusion fixture starts on a road")
	snapshot = state.snapshot(Vector3(3, 0, 5), 0.0)
	_check(_seen(snapshot, 1, 2), "player's current road cell is known")
	_check(_seen(snapshot, 2, 2), "the first wall surface within range becomes known")
	_check(not _seen(snapshot, 3, 2), "a road only four metres away stays hidden behind a wall")
	_check(not _seen(snapshot, 2, 1), "a diagonal ray cannot pass through a blocked corner")
	_check(_seen(snapshot, 1, 1), "unblocked nearby road remains visible")
	_check(not _seen(snapshot, 5, 2), "roads beyond the four-metre radius stay unknown")
	var fine_walls := _layout(["#######", "#.....#", "#.....#", "#.....#", "#######"], 2.0)
	fine_walls.blocking_rects = [Rect2(4, 2, 2, 6)]
	var wall_state = state_script.new()
	wall_state.configure(fine_walls)
	wall_state.reveal_at(Vector3(3, 0, 5))
	var wall_snapshot: Dictionary = wall_state.snapshot(Vector3(3, 0, 5), 0.0)
	_check(wall_snapshot.walkable[2 * 7 + 2] == 0, "sub-cell building walls override coarse road cells")
	_check(_seen(wall_snapshot, 2, 2) and not _seen(wall_snapshot, 3, 2), "fine wall faces become known without revealing the road behind")
	_check(not wall_state.reveal_at(Vector3(5, 0, 5)), "fine wall interiors cannot be used as exploration origins")
	# Both orientations deliberately straddle grid boundaries: no 2m cell center
	# lies inside a 24cm wall, but the wall must still be visible and occlude sight.
	var narrow_layout := _layout(["#######", "#.....#", "#.....#", "#.....#", "#######"], 2.0)
	narrow_layout.blocking_rects = [Rect2(3.88, 2, 0.24, 6)]
	var narrow_state = state_script.new()
	narrow_state.configure(narrow_layout)
	narrow_state.reveal_at(Vector3(3, 0, 5))
	var narrow_snapshot: Dictionary = narrow_state.snapshot(Vector3(3, 0, 5), 0.0)
	_check(narrow_snapshot.walkable[2 * 7 + 2] == 0, "vertical thin wall occupies one stable grid column")
	_check(_seen(narrow_snapshot, 2, 2) and not _seen(narrow_snapshot, 3, 2), "vertical thin wall reveals its surface but occludes the road behind")
	narrow_layout.blocking_rects = [Rect2(2, 3.88, 8, 0.24)]
	narrow_state.configure(narrow_layout)
	narrow_state.reveal_at(Vector3(5, 0, 3))
	narrow_snapshot = narrow_state.snapshot(Vector3(5, 0, 3), 0.0)
	_check(narrow_snapshot.walkable[2 * 7 + 2] == 0, "horizontal thin wall occupies one stable grid row")
	_check(_seen(narrow_snapshot, 2, 2) and not _seen(narrow_snapshot, 2, 3), "horizontal thin wall blocks map sight")
	var wall_save: Dictionary = wall_state.to_save_data()
	wall_state.configure(_layout(["#######", "#.....#", "#.....#", "#.....#", "#######"], 2.0), wall_save)
	_check(wall_state.snapshot(Vector3(3, 0, 5), 0.0).explored.count(1) == 0, "changing only fine walls invalidates an incompatible discovery mask")
	for invalid_rects in ["walls", ["invalid"], [Rect2(0, 0, -2, 2)], [Rect2(INF, 0, 2, 2)], [Rect2(-2, 0, 2, 2)]]:
		var invalid_wall_layout := fine_walls.duplicate(true)
		invalid_wall_layout.blocking_rects = invalid_rects
		wall_state.configure(invalid_wall_layout)
		_check(wall_state.snapshot(Vector3.ZERO, 0.0).columns == 0, "malformed fine-wall input leaves the map inert")
	var old_mask: PackedByteArray = snapshot.explored.duplicate()
	state.reveal_at(Vector3(9, 0, 5))
	var next_mask: PackedByteArray = state.snapshot(Vector3(9, 0, 5), 0.0).explored
	var monotonic := true
	for index in old_mask.size():
		if old_mask[index] == 1 and next_mask[index] != 1:
			monotonic = false
	_check(monotonic, "new visits never hide previously explored cells")
	var saved: Dictionary = state.to_save_data()
	var restored = state_script.new()
	restored.configure(thin, bytes_to_var(var_to_bytes(saved)))
	_check(restored.snapshot(Vector3(9, 0, 5), 0.0).explored == next_mask, "actual Variant save encoding restores the complete explored mask")
	var array_save := saved.duplicate(true)
	array_save.explored = Array(saved.explored)
	restored.configure(thin, JSON.parse_string(JSON.stringify(array_save)))
	_check(restored.snapshot(Vector3(9, 0, 5), 0.0).explored == next_mask, "JSON-style array saves also restore valid exploration")
	for key in ["resolution", "layout_fingerprint"]:
		var bad := saved.duplicate(true)
		bad[key] = 8.0 if key == "resolution" else "changed_layout"
		restored.configure(thin, bad)
		_check(restored.snapshot(Vector3(3, 0, 5), 0.0).explored.count(1) == 0, "changed %s cannot carry discovery into a different map" % key)
	for key in ["layout_id", "layout_version", "columns", "rows"]:
		var bad := saved.duplicate(true)
		bad[key] = "other" if key == "layout_id" else 999
		restored.configure(thin, bad)
		_check(restored.snapshot(Vector3(3, 0, 5), 0.0).explored.count(1) == 0, "incompatible saved %s cannot reveal a new layout" % key)
	for mask in [[1], "all", [0, 1, 255], null]:
		var bad := saved.duplicate(true)
		bad.explored = mask
		restored.configure(thin, bad)
		_check(restored.snapshot(Vector3(3, 0, 5), 0.0).explored.count(1) == 0, "malformed or wrong-sized masks safely reset")
	var invalid_byte := saved.duplicate(true)
	invalid_byte.explored[0] = 255
	restored.configure(thin, invalid_byte)
	_check(restored.snapshot(Vector3(3, 0, 5), 0.0).explored.count(1) == 0, "non-binary saved mask values do not silently become explored")
	var corridor := _layout(["##########", "..........", "##########"], 2.0)
	state.configure(corridor)
	state.reveal_at(Vector3(1, 0, 3))
	state.reveal_at(Vector3(19, 0, 3))
	snapshot = state.snapshot(Vector3(19, 0, 3), 0.0)
	_check(not _seen(snapshot, 5, 1), "teleporting does not reveal a line through unvisited middle cells")
	for cell_x in range(10):
		state.reveal_at(Vector3(cell_x * 2 + 1, 0, 3))
	_check(is_equal_approx(state.snapshot(Vector3(19, 0, 3), 0.0).explored_ratio, 1.0), "walking all road cells reaches full road exploration")
	state.configure(corridor)
	_check(state.snapshot(Vector3(1, 0, 3), 0.0).explored.count(1) == 0, "reconfiguration without a save resets old map exploration")
	for invalid_layout in [{}, {"bounds": Rect2(0, 0, 100000, 100000), "cell_size": 2.0, "grid_size": Vector2i(50000, 50000), "rows": ["."]}, {"bounds": "bad", "rows": []}, {"bounds": Rect2(0, 0, 2, 2), "cell_size": 1.0e100, "grid_size": Vector2i.ONE, "rows": ["."]}]:
		state.configure(invalid_layout)
		snapshot = state.snapshot(Vector3.ZERO, NAN)
		_check(snapshot.columns == 0 and snapshot.rows == 0 and snapshot.explored.is_empty() and not snapshot.active, "invalid or oversized layouts cannot allocate unbounded grids")
		_check(not state.reveal_at(Vector3.ZERO), "invalid layout remains inert")
	# Canonical full-size geometry has 52×52 cells even before the scene exists.
	var real_rows: Array[String] = []
	for row in range(13):
		real_rows.append("#...........#" if row > 0 and row < 12 else "#############")
	state.configure(_layout(real_rows, 8.0, Vector2(-52, -52)))
	snapshot = state.snapshot(Vector3.ZERO, 0.0)
	_check(snapshot.columns == 52 and snapshot.rows == 52, "production-sized 104m layout expands to the agreed phone snapshot dimensions")
	var actual_layout: Dictionary = load("res://scripts/world/floor_two_maze_layout.gd").data()
	state.configure(actual_layout)
	_check(state.reveal_at(actual_layout.spawn), "actual maze spawn is a valid exploration position")
	snapshot = state.snapshot(actual_layout.spawn, 0.0)
	_check(snapshot.active and snapshot.columns == 100 and snapshot.rows == 100, "expanded maze uses an active 100-by-100 phone map")
	for rect: Rect2 in actual_layout.blocking_rects:
		var wall_point := rect.get_center()
		var wall_cell: Vector2i = Vector2i((wall_point - actual_layout.bounds.position) / 2.0)
		_check(snapshot.walkable[wall_cell.y * snapshot.columns + wall_cell.x] == 0, "actual NPC gatehouse sidewalls are buildings on the phone map")
	for gatehouse_cell: Vector2i in actual_layout.gatehouse_cells:
		var gate_point: Vector3 = load("res://scripts/world/floor_two_maze_layout.gd").point_at_cell(gatehouse_cell)
		_check(state.snapshot(gate_point, 0.0).active, "thin-wall rasterization preserves the 2.8m NPC passage center")
	var perceived_layout := actual_layout.duplicate(true)
	perceived_layout.rows = actual_layout.normal_rows
	perceived_layout.blocking_rects = actual_layout.normal_blocking_rects
	var perceived = state_script.new()
	perceived.configure(perceived_layout)
	var perceived_snapshot: Dictionary = perceived.snapshot(actual_layout.spawn, 0.0)
	_check(perceived_snapshot.walkable != snapshot.walkable, "real ordinary and Xray maps have different rasterized geometry")
	for difference: Dictionary in actual_layout.xray_differences:
		var center: Vector2 = difference.rect.get_center()
		var cell := Vector2i(((center - actual_layout.bounds.position) / 2.0).floor())
		var index: int = cell.y * snapshot.columns + cell.x
		_check(snapshot.walkable[index] == int(not difference.solid), "true map represents permanent collision at each difference")
		_check(perceived_snapshot.walkable[index] == int(not difference.normal_visible), "ordinary map represents the visible facade without exposing invisible partitions")
	var exit_uv: Vector2 = (Vector2(actual_layout.exit_position.x, actual_layout.exit_position.z) - actual_layout.bounds.position) / 2.0
	_check(not _seen(snapshot, int(exit_uv.x), int(exit_uv.y)), "spawn discovery does not expose the actual distant exit")
	var primary: Array = actual_layout.primary_route
	for index in range(1, primary.size()):
		var start: Vector3 = primary[index - 1]
		var finish: Vector3 = primary[index]
		var steps := maxi(1, ceili(start.distance_to(finish) / 2.0))
		for step in range(1, steps + 1):
			state.reveal_at(start.lerp(finish, float(step) / steps))
	snapshot = state.snapshot(actual_layout.exit_position, PI)
	_check(snapshot.active and _seen(snapshot, int(exit_uv.x), int(exit_uv.y)), "walking the real route discovers and locates its exit")
	_check(snapshot.explored_ratio > 0.5 and snapshot.explored_ratio < 1.0, "the main route leaves unvisited side streets to explore")
	restored.configure(actual_layout, bytes_to_var(var_to_bytes(state.to_save_data())))
	_check(restored.snapshot(actual_layout.exit_position, PI).explored == snapshot.explored, "actual maze exploration survives persistence exactly")


func _layout(rows: Array, cell_size: float, origin: Vector2 = Vector2.ZERO) -> Dictionary:
	var size := Vector2i(str(rows[0]).length(), rows.size())
	return {"id": "test_floor_2", "version": 1, "floor": 2, "bounds": Rect2(origin, Vector2(size) * cell_size), "cell_size": cell_size, "grid_size": size, "rows": PackedStringArray(rows)}


func _seen(snapshot: Dictionary, x: int, y: int) -> bool:
	return snapshot.explored[y * snapshot.columns + x] == 1


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
