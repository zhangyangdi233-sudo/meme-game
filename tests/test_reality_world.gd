extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("reality world tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var vhs_source := FileAccess.get_file_as_string("res://shaders/vhs_screen.gdshader")
	_assert_true(vhs_source.contains("black_ink_guard"), "VHS post-processing should preserve fully opaque black face scribbles")
	var scribble_source := FileAccess.get_file_as_string("res://shaders/npc_face_scribble_overlay.gdshader")
	_assert_true(scribble_source.contains("ALBEDO = ink_color.rgb") and scribble_source.contains("ALPHA = opaque_ink"), "face scribble shader should output only black marker pixels and transparent background")
	_assert_true(scribble_source.contains("texture(character_texture, UV).a"), "face scribble overlay should read the character only for alpha alignment")
	_assert_true(not scribble_source.contains("mix(base") and not scribble_source.contains("body_tint"), "face scribble overlay must never darken or recolor the source portrait")
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "reality world test should load the main scene")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("zh")
	game_root.new_game()
	for _line_index in 7:
		game_root._advance_prologue()
	await process_frame

	var player := game_root.get_node_or_null("RealityPlayer") as CharacterBody3D
	var floor_root := game_root.get_node_or_null("RealityFloor") as Node3D
	var camera := game_root.get_node_or_null("Camera3D") as Camera3D
	var top_bar := _find_node_by_name(game_root, "CinematicTopBar") as ColorRect
	var bottom_bar := _find_node_by_name(game_root, "CinematicBottomBar") as ColorRect
	var hud_rail := _find_node_by_name(game_root, "InternationalHUDRail") as PanelContainer
	var social_window := _find_node_by_name(game_root, "SocialAppWindow") as PanelContainer
	_assert_true(player != null, "reality view should expose a CharacterBody3D player")
	_assert_true(floor_root != null, "reality view should expose a generated floor root")
	_assert_true(camera != null, "reality view should retain the shared 3D camera")
	if camera != null:
		var camera_attributes := camera.attributes as CameraAttributesPractical
		_assert_true(camera_attributes != null, "reality camera should use practical fixed-focus attributes")
		if camera_attributes != null:
			_assert_true(camera_attributes.dof_blur_far_enabled, "fixed focus should blur the distant world")
			_assert_true(not camera_attributes.dof_blur_near_enabled, "fixed focus should keep nearby actors and props clear")
			_assert_near(camera_attributes.dof_blur_far_distance, 18.0, 0.01, "far blur should begin beyond the interaction range")
			_assert_near(camera_attributes.dof_blur_far_transition, 12.0, 0.01, "far focus should soften gradually instead of popping")
			_assert_near(camera_attributes.dof_blur_amount, 0.08, 0.001, "far blur should obscure silhouettes without erasing navigation")
		_assert_eq(str(camera.get_meta("fixed_focus_profile", "")), "near_clear_far_soft", "camera should expose its fixed-focus art direction")
		_assert_near(camera.fov, 58.0, 0.01, "the shared first-person camera should start at the fixed authored FOV")
		game_root._reality_interaction_active = true
		game_root._animate_world(0.5)
		_assert_near(camera.fov, 58.0, 0.01, "starting an NPC interaction must not alter the fixed focal length")
		game_root._reality_interaction_active = false
	_assert_true(top_bar != null and bottom_bar != null, "gameplay should expose fixed cinematic bars")
	if top_bar != null and bottom_bar != null:
		_assert_true(not top_bar.visible and not bottom_bar.visible, "phone view should not be squeezed by the reality-only cinematic bars")
		_assert_eq(float(top_bar.get_meta("target_aspect_ratio", 0.0)), 2.35, "cinematic bars should target the selected 2.35 aspect ratio")
	if social_window != null and top_bar != null:
		_assert_true(social_window.z_index > top_bar.z_index, "phone app windows should render above the cinematic bars")

	_assert_eq(game_root._room_count_for_floor(1), 4, "floor one should begin with four rooms")
	_assert_eq(game_root._room_count_for_floor(2), 6, "floor two should add two rooms")
	_assert_eq(game_root._room_count_for_floor(3), 9, "floor three should add three rooms")
	_assert_eq(game_root._room_count_for_floor(4), 11, "hidden floor four should retain the final authored expansion")
	for floor_number in range(2, 5):
		var growth: int = game_root._room_count_for_floor(floor_number) - game_root._room_count_for_floor(floor_number - 1)
		_assert_true(growth == 2 or growth == 3, "each ascent should add two or three rooms")
	var expected_npc_counts := [4, 3, 2, 0]
	for floor_index in expected_npc_counts.size():
		var floor_number := floor_index + 1
		_assert_eq(game_root._npc_count_for_floor(floor_number), expected_npc_counts[floor_index], "ordinary NPC population should follow the reduced floor sequence")
		if floor_index > 0:
			_assert_true(expected_npc_counts[floor_index] < expected_npc_counts[floor_index - 1], "ordinary NPC population should strictly decrease on every ascent")
	_assert_eq(int(floor_root.get_meta("room_count", 0)), 4, "generated first floor should match the room formula")
	_assert_eq(int(floor_root.get_meta("ordinary_npc_count", 0)), 4, "first floor should contain four ordinary NPCs")
	_assert_eq(str(floor_root.get_meta("district_style", "")), "sunlit_brick_street", "first floor should use the sunlit brick-road reference grammar")
	var map_width := float(floor_root.get_meta("map_width", 0.0))
	var map_length := float(floor_root.get_meta("map_length", 0.0))
	_assert_true(_find_node_by_name(floor_root, "BrickWall") != null and _find_node_by_name(floor_root, "Crosswalk00") != null, "sunlit district should include tall brick edge walls and a zebra crossing")
	var first_brick_wall := _find_node_by_name(floor_root, "BrickWall") as Node3D
	if first_brick_wall != null:
		_assert_true(absf(first_brick_wall.position.x) >= map_width * 0.5 - 1.0, "sunlit brick walls should follow the outer terrain edge")
	var first_reference_portal := _find_node_by_name(floor_root, "ReferencePortal") as MeshInstance3D
	_assert_true(first_reference_portal != null and str(first_reference_portal.get_meta("reference_texture", "")).contains("sunlit_brick_street"), "sunlit district should extend its geometry with the supplied reference image")
	if first_reference_portal != null and first_reference_portal.mesh is QuadMesh:
		_assert_true((first_reference_portal.mesh as QuadMesh).size.x >= 12.0, "sunlit reference continuation should fill the road horizon rather than appear as a small poster")
	_assert_eq(int(floor_root.get_meta("useful_item_count", 0)), 1, "each normal floor should reserve one physical hidden-route prerequisite")
	var hidden_prerequisite := _find_node_by_name(floor_root, "PrerequisiteItemFloor1") as Area3D
	_assert_true(hidden_prerequisite != null and not hidden_prerequisite.visible, "the prerequisite should exist in reachable geometry but remain hidden before its NPC clue")
	if hidden_prerequisite != null:
		_assert_true(not hidden_prerequisite.monitoring and not hidden_prerequisite.monitorable, "an unrevealed prerequisite must not intercept interaction")
		_assert_eq(str(hidden_prerequisite.get_meta("item_effect", "")), "prerequisite", "physical route proof should not carry an obsolete stat bonus")
	_assert_eq(str(floor_root.get_meta("layout_mode", "")), "shared_street", "reality floor should be one shared open street instead of isolated NPC boxes")
	_assert_true(map_width >= 32.0 and map_length >= 230.0, "first floor should be five times longer than the original forty-six-metre street")
	_assert_eq(float(floor_root.get_meta("world_length_scale", 0.0)), 5.0, "generated floors should expose the requested five-times world scale")
	var street_ground := _find_node_by_name(floor_root, "StreetGround") as StaticBody3D
	_assert_true(street_ground != null, "shared street should use one continuous collision ground")
	var crossroad_ground := _find_node_by_name(floor_root, "CrossroadGround") as StaticBody3D
	_assert_true(crossroad_ground != null and bool(crossroad_ground.get_meta("crossroad_extension", false)), "the horizontal branch should have its own continuous collision ground")
	var crossroad := _find_node_by_name(floor_root, "CrossRoad") as Node3D
	_assert_true(crossroad != null and bool(crossroad.get_meta("crossroad_surface", false)), "first corridor district should add a real horizontal road across its center")
	var crossroad_span := float(floor_root.get_meta("crossroad_total_span", 0.0))
	_assert_true(crossroad_span >= map_width + 80.0, "the first crossroad should extend into substantial left and right branches")
	_assert_eq(str(floor_root.get_meta("crossroad_layout", "")), "continuous_four_way", "the crossroad should be a continuous four-way layout")
	var edge_walls: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "terrain_edge_wall", edge_walls)
	_assert_eq(edge_walls.size(), 4, "the two long terrain edges should each use two wall segments around the central intersection")
	var crossroad_opening := float(floor_root.get_meta("crossroad_opening_span", 0.0))
	var wall_lengths := {"west": 0.0, "east": 0.0}
	for edge_wall in edge_walls:
		var wall_length := float(edge_wall.get_meta("edge_length", 0.0))
		var edge_side := str(edge_wall.get_meta("edge_side", ""))
		wall_lengths[edge_side] = float(wall_lengths.get(edge_side, 0.0)) + wall_length
		_assert_true(absf(edge_wall.position.z) - wall_length * 0.5 >= crossroad_opening * 0.5 - 0.01, "terrain edge walls should stop before the open center of the crossroad")
	_assert_true(is_equal_approx(float(wall_lengths["west"]), map_length - crossroad_opening) and is_equal_approx(float(wall_lengths["east"]), map_length - crossroad_opening), "each side wall should cover the full map edge except the road opening")
	var boundary_walls: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "terrain_boundary_wall", boundary_walls)
	_assert_eq(boundary_walls.size(), 12, "trunk, branch sides, and all four ends should form one continuous visible boundary")
	_assert_eq(int(floor_root.get_meta("crossroad_branch_wall_count", 0)), 6, "left and right branches should each have two side walls and one end wall")
	_assert_true(_find_node_by_name(floor_root, "CrossroadEndWallWest") != null and _find_node_by_name(floor_root, "CrossroadEndWallEast") != null, "both horizontal branches should terminate in real walls")
	_assert_true(_find_node_by_name(floor_root, "StreetEndWallNorth") != null and _find_node_by_name(floor_root, "StreetEndWallSouth") != null, "the long street should close its north and south ends")
	_assert_eq(str(floor_root.get_meta("dreamcore_overlay", "")), "regular_grid_with_controlled_anomalies", "first-floor additions should use controlled dreamcore repetition")
	_assert_eq(int(floor_root.get_meta("dreamcore_light_slot_count", 0)), 18, "both branches should repeat nine threshold light bays")
	_assert_true(int(floor_root.get_meta("dreamcore_false_door_count", 0)) >= 6, "repeated false doors should introduce sparse architectural wrongness")
	_assert_true(_find_node_by_name(floor_root, "DreamcoreThresholdRhythm") != null, "dreamcore atmosphere should be represented by original procedural geometry")
	_assert_eq(int(floor_root.get_meta("air_wall_count", 0)), 12, "the cross-shaped map perimeter should expose twelve joined air-wall segments")
	var air_walls := _find_node_by_name(floor_root, "AirWalls") as Node3D
	_assert_true(air_walls != null and air_walls.get_child_count() == 12, "air-wall container should follow every edge of the cross-shaped floor")
	if air_walls != null:
		for wall in air_walls.get_children():
			_assert_true(wall is StaticBody3D and bool(wall.get_meta("air_wall", false)), "each perimeter edge should be an invisible static air wall")
	if player != null:
		var half_width := map_width * 0.5
		var half_length := map_length * 0.5
		_assert_true(absf(player.position.x) <= half_width - 5.0, "player spawn should have generous horizontal clearance")
		_assert_true(absf(player.position.z) <= half_length - 5.0, "player spawn should have generous longitudinal clearance")
	var branch_position := Vector3(crossroad_span * 0.5 - 2.0, 0.08, 0.0)
	_assert_true(bool(floor_root.call("contains_playable_position", branch_position)), "the player should be allowed to walk down the new right branch")
	var outside_corner := Vector3(crossroad_span * 0.5 - 2.0, 0.08, 24.0)
	_assert_true(not bool(floor_root.call("contains_playable_position", outside_corner)), "the empty diagonal beyond the cross shape should remain outside the map")
	var clamped_corner: Vector3 = floor_root.call("clamp_to_playable_position", outside_corner)
	_assert_true(bool(floor_root.call("contains_playable_position", clamped_corner)), "clamping should choose the nearest valid arm or trunk instead of a bounding rectangle")

	var doll := _find_actor(floor_root, "doll")
	var ordinary_npcs := _count_actors(floor_root, "npc")
	var doctors := _count_actors(floor_root, "doctor")
	_assert_true(doll != null, "each normal floor should contain one discoverable stitched doll")
	_assert_true(_find_actor(floor_root, "merchant") == null, "removed merchant actor must not return")
	_assert_eq(ordinary_npcs + doctors, 4, "first floor should preserve its four-character population")
	_assert_eq(doctors, 0, "the retired doctor actor must not spawn")
	var npc_z_positions: Array[float] = []
	_collect_actor_z_positions(floor_root, "npc", npc_z_positions)
	_collect_actor_z_positions(floor_root, "doctor", npc_z_positions)
	npc_z_positions.sort()
	for index in range(1, npc_z_positions.size()):
		_assert_true(npc_z_positions[index] - npc_z_positions[index - 1] >= 25.0, "ordinary NPCs should be spaced across the five-times-long street")
	if doll != null:
		var doll_billboard := doll.get_node_or_null("Billboard") as Sprite3D
		_assert_true(doll_billboard != null and doll_billboard.texture != null, "doll should use the player's stitched guide artwork")
		if doll_billboard != null:
			_assert_eq(doll_billboard.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "the physical doll should always face the camera")
		_assert_true(doll.get_node_or_null("FaceScribbleOverlay") == null, "the guide doll artwork should never receive the NPC face veil")
		_assert_true(bool(doll.get_meta("guide_character", false)), "the world doll should retain its guide role")
	var sample_npc := _find_actor(floor_root, "npc")
	if sample_npc != null:
		var sample_npc_billboard := sample_npc.get_node_or_null("Billboard") as Sprite3D
		_assert_actor_face_veil(sample_npc, sample_npc_billboard, "ordinary NPC")
	var npc_texture_ids: Dictionary = {}
	_collect_actor_texture_ids(floor_root, "npc", npc_texture_ids)
	_assert_eq(npc_texture_ids.size(), 3, "ordinary NPCs should rotate through all three protagonist-style character artworks")

	for action_name in ["reality_forward", "reality_back", "reality_left", "reality_right", "reality_sprint", "reality_interact"]:
		_assert_true(InputMap.has_action(action_name), "reality movement should register input action %s" % action_name)
	_assert_true(_action_has_key("reality_forward", KEY_W) and _action_has_key("reality_forward", KEY_UP), "forward movement should accept W and Up")
	_assert_true(_action_has_key("reality_back", KEY_S) and _action_has_key("reality_back", KEY_DOWN), "back movement should accept S and Down")
	_assert_true(_action_has_key("reality_left", KEY_A) and _action_has_key("reality_left", KEY_LEFT), "left movement should accept A and Left")
	_assert_true(_action_has_key("reality_right", KEY_D) and _action_has_key("reality_right", KEY_RIGHT), "right movement should accept D and Right")
	_assert_true(_action_has_key("reality_sprint", KEY_SHIFT), "accelerated walking should use Shift")
	_assert_true(_action_has_key("reality_interact", KEY_F), "world interaction should use F")

	game_root.set_view_state("npc_up")
	if top_bar != null and bottom_bar != null:
		_assert_true(top_bar.visible and bottom_bar.visible, "putting the phone down should restore both cinematic bars")
		_assert_true(top_bar.size.y > 24.0 and bottom_bar.size.y > 24.0, "reality walking should retain a visible movie frame")
		_assert_true(top_bar.size.y <= game_root.get_viewport().get_visible_rect().size.y * 0.121, "responsive cinematic bars should never consume more than twelve percent per edge")
		if hud_rail != null:
			var hud_rect := hud_rail.get_global_rect()
			var viewport_height := game_root.get_viewport().get_visible_rect().size.y
			_assert_true(hud_rect.position.y >= top_bar.get_global_rect().end.y + 6.0, "left HUD should begin inside the cinematic picture instead of crossing the top matte")
			_assert_true(hud_rect.end.y <= bottom_bar.get_global_rect().position.y - 6.0, "left HUD should end inside the cinematic picture instead of crossing the bottom matte")
			_assert_true(absf(hud_rect.get_center().y - viewport_height * 0.5) <= 1.0, "left HUD should stay vertically centered on the picture")
	_assert_true(bool(game_root._reality_mouse_look_enabled), "putting the phone down should immediately enable free mouse look")
	var yaw_before_mouse := float(game_root._reality_yaw)
	var mouse_turn := InputEventMouseMotion.new()
	mouse_turn.relative = Vector2(96.0, 0.0)
	game_root._unhandled_input(mouse_turn)
	_assert_true(not is_equal_approx(float(game_root._reality_yaw), yaw_before_mouse), "horizontal mouse movement should rotate the first-person view")
	var yaw_before_touch := float(game_root._reality_yaw)
	var pitch_before_touch := float(game_root._reality_pitch)
	var actions_before_touch := int(game_root.game.actions_remaining)
	var touch_start := InputEventScreenTouch.new()
	touch_start.index = 3
	touch_start.position = Vector2(760.0, 430.0)
	touch_start.pressed = true
	game_root._input(touch_start)
	var touch_turn := InputEventScreenDrag.new()
	touch_turn.index = 3
	touch_turn.position = Vector2(688.0, 468.0)
	touch_turn.screen_relative = Vector2(-72.0, 38.0)
	game_root._input(touch_turn)
	_assert_true(not is_equal_approx(float(game_root._reality_yaw), yaw_before_touch), "horizontal touchscreen drag should rotate the first-person view")
	_assert_true(not is_equal_approx(float(game_root._reality_pitch), pitch_before_touch), "vertical touchscreen drag should tilt the first-person view")
	_assert_eq(game_root.game.actions_remaining, actions_before_touch, "touchscreen free look should not spend an action")
	var yaw_after_primary_touch := float(game_root._reality_yaw)
	var second_touch_turn := InputEventScreenDrag.new()
	second_touch_turn.index = 4
	second_touch_turn.position = Vector2(500.0, 300.0)
	second_touch_turn.screen_relative = Vector2(120.0, 0.0)
	game_root._input(second_touch_turn)
	_assert_true(is_equal_approx(float(game_root._reality_yaw), yaw_after_primary_touch), "a second finger should not steal the active one-finger camera gesture")
	var touch_end := InputEventScreenTouch.new()
	touch_end.index = 3
	touch_end.position = touch_turn.position
	touch_end.pressed = false
	game_root._input(touch_end)
	_assert_eq(int(game_root._reality_touch_look_index), -1, "lifting the active finger should finish the camera gesture")
	game_root._reality_yaw = 0.0
	var trackpad_left := InputEventPanGesture.new()
	# macOS pan deltas report content movement, opposite to finger movement.
	trackpad_left.delta = Vector2(2.0, 0.0)
	game_root._input(trackpad_left)
	_assert_true(float(game_root._reality_yaw) > 0.0, "two-finger trackpad movement to the left should turn the camera left")
	_assert_true(absf(float(game_root._reality_yaw)) <= 4.0, "trackpad look should use the reduced sensitivity")
	game_root._reality_yaw = 0.0
	var trackpad_right := InputEventPanGesture.new()
	trackpad_right.delta = Vector2(-2.0, 0.0)
	game_root._input(trackpad_right)
	_assert_true(float(game_root._reality_yaw) < 0.0, "two-finger trackpad movement to the right should turn the camera right")
	game_root._reality_pitch = 0.0
	var trackpad_up := InputEventPanGesture.new()
	trackpad_up.delta = Vector2(0.0, 2.0)
	game_root._input(trackpad_up)
	_assert_true(float(game_root._reality_pitch) > 0.0, "two-finger trackpad movement upward should tilt the camera upward")
	game_root._reality_pitch = 0.0
	var trackpad_down := InputEventPanGesture.new()
	trackpad_down.delta = Vector2(0.0, -2.0)
	game_root._input(trackpad_down)
	_assert_true(float(game_root._reality_pitch) < 0.0, "two-finger trackpad movement downward should tilt the camera downward")
	_assert_eq(game_root.game.actions_remaining, actions_before_touch, "trackpad free look should not spend an action")
	game_root.set_view_state("phone_down")
	var yaw_while_phone_is_up := float(game_root._reality_yaw)
	game_root._input(touch_start)
	game_root._input(touch_turn)
	_assert_true(is_equal_approx(float(game_root._reality_yaw), yaw_while_phone_is_up), "touchscreen drag should not turn the world while the phone interface is active")
	game_root._input(trackpad_left)
	_assert_true(is_equal_approx(float(game_root._reality_yaw), yaw_while_phone_is_up), "trackpad pan should keep scrolling available instead of turning the world while the phone is active")
	var pitch_while_phone_is_up := float(game_root._reality_pitch)
	game_root._input(trackpad_up)
	_assert_true(is_equal_approx(float(game_root._reality_pitch), pitch_while_phone_is_up), "vertical trackpad pan should remain available to phone UI while the phone is active")
	game_root.set_view_state("npc_up")
	game_root._reality_yaw = 0.0
	game_root._reality_pitch = 0.0
	if player != null:
		var walk_start := player.position
		Input.action_press("reality_forward")
		for frame in 24:
			await physics_frame
		Input.action_release("reality_forward")
		var walk_distance := walk_start.distance_to(player.position)
		_assert_true(walk_distance > 0.25, "holding W should move the first-person body forward through the floor")
		player.position = walk_start
		player.velocity = Vector3.ZERO
		Input.action_press("reality_forward")
		Input.action_press("reality_sprint")
		for frame in 24:
			await physics_frame
		Input.action_release("reality_sprint")
		Input.action_release("reality_forward")
		var sprint_distance := walk_start.distance_to(player.position)
		_assert_true(sprint_distance > walk_distance * 1.35, "holding Shift while walking should cover substantially more distance")
		game_root._reality_yaw = 0.0
		player.position = Vector3(0.0, 0.08, map_length * 0.5 - 1.2)
		player.velocity = Vector3.ZERO
		Input.action_press("reality_back")
		for frame in 72:
			await physics_frame
		Input.action_release("reality_back")
		_assert_true(player.position.z < map_length * 0.5, "the south air wall should physically stop sustained backward movement")
		_assert_true(player.position.y > -0.5, "walking against the map edge should keep the player on the continuous ground")
		player.position = Vector3(0.0, -8.0, 0.0)
		player.velocity = Vector3(0.0, -12.0, 0.0)
		game_root._update_reality_player(0.016)
		_assert_true(player.position.y >= 0.0, "falling below the street should recover the player onto a safe spawn")
	if player != null and doll != null:
		player.position = doll.position + Vector3(0.0, 0.0, 1.4)
		game_root._refresh_nearby_reality_actor()
		_assert_true(game_root._nearby_reality_actor == doll, "approaching the stitched doll should select it as the nearby actor")
		_assert_true(game_root._try_reality_interaction(), "F interaction path should open the nearby actor")
		_assert_true(game_root._reality_interaction_active, "world interaction should enter the dialogue state")
		_assert_true(game_root._active_reality_actor == doll, "world interaction should remember the discovered doll")
		var leave_button := _find_node_by_name(game_root, "RealityConversationContinue") as Button
		var actions_before_leave := int(game_root.game.actions_remaining)
		_assert_true(leave_button != null and leave_button.visible and leave_button.text == "离开", "doll and NPC conversations should expose an immediate Leave button")
		if leave_button != null:
			leave_button.pressed.emit()
		_assert_true(not game_root._reality_interaction_active, "Leave should close a conversation before the player speaks")
		_assert_eq(game_root.game.actions_remaining, actions_before_leave, "leaving without speaking should not spend an action")
		game_root._refresh_nearby_reality_actor()
		_assert_true(game_root._try_reality_interaction(), "the same actor should remain available after leaving")
		var yaw_during_dialogue := float(game_root._reality_yaw)
		game_root._unhandled_input(touch_turn)
		_assert_true(is_equal_approx(float(game_root._reality_yaw), yaw_during_dialogue), "touchscreen drag should not turn the camera during a reality conversation")
		var choice_id := str(game_root.game.get_typed_reality_choices()[0].get("id", ""))
		game_root._on_reality_choice_selected(choice_id)
		var arbitrary_key := InputEventKey.new()
		arbitrary_key.keycode = KEY_SPACE
		arbitrary_key.pressed = true
		game_root._unhandled_input(arbitrary_key)
		_assert_eq(game_root.game.conversation_reveal_index, 1, "an arbitrary physical key should reveal exactly one spoken character")
		_assert_eq(game_root.game.actions_remaining, 5, "partial typed speech should remain action-free")
		game_root._exit_reality_interaction()
		_assert_true(not game_root._reality_interaction_active, "leaving dialogue should return to free walking")

	game_root.game.tower_floor = 2
	game_root._ensure_reality_floor_current()
	floor_root = game_root.get_node_or_null("RealityFloor") as Node3D
	await physics_frame
	_assert_eq(int(floor_root.get_meta("room_count", 0)), 6, "second floor should retain its six gameplay rooms")
	_assert_eq(int(floor_root.get_meta("logical_room_count", 0)), 6, "second floor should expose all six rooms as logical gameplay anchors")
	_assert_eq(int(floor_root.get_meta("ordinary_npc_count", 0)), 3, "second floor should reduce ordinary NPCs to three")
	_assert_eq(_count_actors(floor_root, "npc") + _count_actors(floor_root, "doctor"), 3, "second-floor actor population should match its metadata")
	_assert_eq(_count_actors(floor_root, "doctor"), 0, "second floor should contain exactly one doctor — retired")
	_assert_eq(str(floor_root.get_meta("district_style", "")), "night_white_blocks", "second floor should use the night white-block district")
	_assert_eq(str(floor_root.get_meta("layout_mode", "")), "irregular_disc", "second floor should replace the linear street with one broad irregular clearing")
	_assert_eq(str(floor_root.get_meta("terrain_profile", "")), "undulating_irregular_disc", "second floor should identify its filled rolling-disc terrain")
	_assert_eq(str(floor_root.get_meta("atmosphere_mode", "")), "slow_burn_suspense", "suspense atmosphere should begin on the second floor")
	_assert_eq(str(floor_root.get_meta("lighting_profile", "")), "near_black_disc", "second floor should advertise its deliberately near-black clearing profile")
	_assert_true(float(floor_root.get_meta("fog_density", 0.0)) >= 0.018, "second-floor fog should remain visibly denser than first-floor daylight haze")
	_assert_true(float(floor_root.get_meta("ambient_light_energy", 1.0)) <= 0.15, "second-floor ambient light should stay dark while preserving terrain silhouettes")
	_assert_true(float(floor_root.get_meta("key_light_energy", 1.0)) <= 0.31, "second-floor key light should preserve the near-black ring silhouette")
	_assert_eq(str(floor_root.get_meta("suspense_color_temperature", "")), "cold_green", "second-floor global light should use a cold green temperature against warm lamps")
	_assert_true(_find_node_by_name(floor_root, "SuspenseLight00") != null, "second floor should retain sparse clearing lights")
	_assert_eq(int(floor_root.get_meta("suspense_light_count", 0)), 7, "second-floor clearing should scatter seven readable light pools across its area")
	_assert_true(_find_node_by_name(floor_root, "SuspenseOcclusion") != null, "second floor should add procedural sightline occlusion")
	_assert_true(int(floor_root.get_meta("suspense_occluder_count", 0)) >= 5, "slow-burn atmosphere should repeat several non-blocking sightline screens")
	_assert_true(int(floor_root.get_meta("controlled_repeat_count", 0)) > int(floor_root.get_meta("suspense_occluder_count", 0)), "architectural repetition should include one restrained spatial anomaly")
	_assert_eq(int(floor_root.get_meta("jump_scare_trigger_count", -1)), 0, "suspense geometry should not add jump-scare trigger areas")
	_assert_true(float(floor_root.get_meta("minimum_clear_path_width", 0.0)) >= 5.6, "occluders should preserve a generous continuous walking lane")
	_assert_true(float(floor_root.get_meta("map_width", 0.0)) >= 245.0 and float(floor_root.get_meta("map_length", 0.0)) >= 255.0, "second-floor clearing diameter should be comparable to the full first-floor journey")
	_assert_true(int(floor_root.get_meta("disc_angular_segment_count", 0)) >= 96, "second-floor clearing should use enough boundary segments for an irregular circular silhouette")
	_assert_true(int(floor_root.get_meta("disc_radial_segment_count", 0)) >= 24, "second-floor clearing should tessellate its filled interior densely enough to shape walkable mounds")
	_assert_true(float(floor_root.get_meta("disc_radius_x", 0.0)) >= 110.0 and float(floor_root.get_meta("disc_radius_z", 0.0)) >= 115.0, "second-floor clearing should expose its large unequal radii")
	_assert_true(float(floor_root.get_meta("disc_height_variation", 0.0)) >= 4.0, "second-floor procedural surface should include player-visible hill elevation changes")
	_assert_eq(int(floor_root.get_meta("disc_mound_count", 0)), 13, "second-floor terrain should distribute a field of small authored hill mounds")
	var disc_ground := _find_node_by_name(floor_root, "IrregularDiscGround") as StaticBody3D
	var disc_surface: MeshInstance3D = null
	_assert_true(disc_ground != null and bool(disc_ground.get_meta("irregular_disc", false)), "second floor should build one metadata-tagged filled procedural ground body")
	if disc_ground != null:
		disc_surface = disc_ground.get_node_or_null("DiscSurface") as MeshInstance3D
		var disc_collision := disc_ground.get_node_or_null("Collision") as CollisionShape3D
		_assert_true(disc_surface != null and disc_surface.mesh is ArrayMesh, "disc terrain should be generated as an original low-poly ArrayMesh")
		if disc_surface != null:
			var disc_material := disc_surface.material_override as StandardMaterial3D
			_assert_true(disc_material != null and disc_material.cull_mode == BaseMaterial3D.CULL_DISABLED, "second-floor terrain should remain visible from the playable side even when procedural winding flips")
			var height_profile := _mesh_height_profile(disc_surface)
			_assert_true(float(height_profile.get("range", 0.0)) >= 4.0, "actual terrain vertices should span at least four metres vertically")
			for quadrant_peak in height_profile.get("quadrant_peaks", []):
				_assert_true(float(quadrant_peak) >= 1.2, "each map quadrant should contain a clearly raised hill crest")
		_assert_true(disc_collision != null and disc_collision.shape is ConcavePolygonShape3D, "disc elevation should be backed by matching trimesh collision")
	var logical_rooms: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "logical_room", logical_rooms)
	_assert_eq(logical_rooms.size(), 6, "the broad second-floor clearing should retain six gameplay houses")
	var physical_houses: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "physical_house", physical_houses)
	_assert_eq(physical_houses.size(), int(floor_root.get_meta("physical_house_count", -1)), "physical-house metadata should match generated second-floor buildings")
	_assert_eq(physical_houses.size(), 9, "nine houses should populate the broad map while remaining sparse and disconnected")
	var scenery_houses: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "scenery_only", scenery_houses)
	_assert_eq(scenery_houses.size(), 3, "three extra scenery houses should add density without adding gameplay rewards")
	var house_min_x := INF
	var house_max_x := -INF
	var house_min_y := INF
	var house_max_y := -INF
	var house_min_z := INF
	var house_max_z := -INF
	for house in physical_houses:
		house_min_x = minf(house_min_x, house.global_position.x)
		house_max_x = maxf(house_max_x, house.global_position.x)
		house_min_y = minf(house_min_y, house.global_position.y)
		house_max_y = maxf(house_max_y, house.global_position.y)
		house_min_z = minf(house_min_z, house.global_position.z)
		house_max_z = maxf(house_max_z, house.global_position.z)
	_assert_true(house_max_x - house_min_x >= 100.0 and house_max_z - house_min_z >= 100.0, "second-floor houses should scatter across both axes instead of forming two straight rows")
	_assert_true(house_max_y - house_min_y >= 1.4, "scattered houses should visibly sit at different elevations across the hill field")
	var measured_house_area := 0.0
	for house in physical_houses:
		var house_mesh := house.get_node_or_null("Mesh") as MeshInstance3D
		if house_mesh != null and house_mesh.mesh is BoxMesh:
			var house_size := (house_mesh.mesh as BoxMesh).size
			measured_house_area += house_size.x * house_size.z
	var measured_disc_area := _projected_mesh_area(disc_surface)
	var measured_coverage := measured_house_area / maxf(1.0, measured_disc_area)
	_assert_true(measured_disc_area > 35000.0, "the filled irregular disc should expose a broad independently measured planar area")
	_assert_true(measured_coverage > 0.0 and measured_coverage <= 0.01, "nine houses should still occupy less than one percent of the broad clearing (got %.5f)" % measured_coverage)
	_assert_near(float(floor_root.get_meta("night_house_coverage_ratio", -1.0)), measured_coverage, 0.0001, "coverage metadata should derive from actual house footprints and disc geometry")
	_assert_eq(str(floor_root.get_meta("night_house_coverage_method", "")), "procedural_footprints_over_boundary_polygon", "coverage metadata should name its geometry-based calculation")
	var floor_two_spawn: Vector3 = floor_root.call("start_position")
	_assert_true(bool(floor_root.call("contains_playable_position", floor_two_spawn)), "second-floor spawn should remain inside the playable clearing")
	_assert_near(float(floor_root.call("start_yaw_degrees")), 0.0, 0.01, "second-floor spawn should face inward across the scattered settlement")
	_assert_true(bool(floor_root.call("contains_playable_position", Vector3.ZERO)), "the irregular clearing should fill its center with walkable terrain")
	var far_outside := Vector3(float(floor_root.get_meta("map_width", 0.0)), 0.08, float(floor_root.get_meta("map_length", 0.0)))
	_assert_true(not bool(floor_root.call("contains_playable_position", far_outside)), "positions beyond the irregular circular edge should remain outside the map")
	var clamped_outside: Vector3 = floor_root.call("clamp_to_playable_position", far_outside)
	_assert_true(bool(floor_root.call("contains_playable_position", clamped_outside, 1.2)), "clamping should move an exterior point onto the irregular circular boundary")
	_assert_true(not _vertical_ground_collision(floor_root, floor_two_spawn, player).is_empty(), "second-floor spawn should stand above the undulating disc collision")
	_assert_true(not _vertical_ground_collision(floor_root, Vector3.ZERO, player).is_empty(), "second-floor center should be backed by real filled terrain collision")
	_assert_dreamcore_objects(floor_root, "second floor")
	var floor_two_fog_density := float(floor_root.get_meta("fog_density", 0.0))
	var floor_two_ambient_energy := float(floor_root.get_meta("ambient_light_energy", 0.0))

	game_root.game.tower_floor = 3
	game_root._ensure_reality_floor_current()
	floor_root = game_root.get_node_or_null("RealityFloor") as Node3D
	await physics_frame
	_assert_eq(str(floor_root.get_meta("district_style", "")), "overgrown_gallery", "third floor should use the overgrown white-gallery district")
	_assert_eq(int(floor_root.get_meta("ordinary_npc_count", 0)), 2, "third floor should reduce ordinary NPCs to two")
	_assert_eq(_count_actors(floor_root, "npc") + _count_actors(floor_root, "doctor"), 2, "third-floor actor population should match its metadata while reusing one slot for the doctor")
	_assert_eq(_count_actors(floor_root, "doctor"), 0, "third floor should contain exactly one doctor — retired")
	_assert_eq(str(floor_root.get_meta("layout_mode", "")), "skylit_overgrown_gallery", "third floor should expose its meadow-and-skylight layout")
	_assert_eq(str(floor_root.get_meta("terrain_profile", "")), "full_map_meadow_gallery", "third floor should identify its full-map meadow terrain")
	_assert_true(_find_node_by_name(floor_root, "GalleryRoof") != null and _find_node_by_name(floor_root, "GalleryCeilingSpan") != null and _find_node_by_name(floor_root, "FullMapGrass") != null, "overgrown district should combine a skylit white colonnade with one full-map grass field")
	_assert_true(bool(floor_root.get_meta("gallery_continuous", false)), "third-floor gallery architecture should be one elongated continuum")
	_assert_true(float(floor_root.get_meta("gallery_span_ratio", 0.0)) >= 0.95, "gallery roofs and outer walls should span nearly the full street")
	_assert_true(float(floor_root.get_meta("gallery_column_spacing", 99.0)) <= 7.2, "third-floor columns should maintain a continuous rhythm without long empty breaks")
	_assert_true(int(floor_root.get_meta("gallery_column_count", 0)) >= 90, "third-floor colonnade should repeat along the full elongated building")
	var gallery_roof := _find_node_by_name(floor_root, "GalleryRoof") as Node3D
	if gallery_roof != null:
		_assert_true(bool(gallery_roof.get_meta("continuous_gallery", false)), "gallery roof should identify itself as a continuous structure")
		_assert_true(float(gallery_roof.get_meta("span_length", 0.0)) >= float(floor_root.get_meta("map_length", 0.0)) - 14.1, "gallery roof should replace short disconnected roof pieces with one long span")
	var gallery_ceiling := _find_node_by_name(floor_root, "GalleryCeilingSpan") as Node3D
	_assert_true(gallery_ceiling != null and bool(gallery_ceiling.get_meta("skylit_ceiling", false)), "third-floor central ceiling should explicitly identify its skylit construction")
	_assert_true(int(floor_root.get_meta("skylight_opening_count", 0)) >= 4, "third-floor ceiling should retain several substantial skylight openings")
	_assert_true(float(floor_root.get_meta("skylight_open_ratio", 0.0)) >= 0.12, "skylights should remove a meaningful share of the central roof span")
	var skylight_openings: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "skylight_opening", skylight_openings)
	_assert_eq(skylight_openings.size(), int(floor_root.get_meta("skylight_opening_count", -1)), "skylight metadata should match explicit open ceiling markers")
	var skylight_roof_segments: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "skylight_roof_segment", skylight_roof_segments)
	_assert_eq(skylight_roof_segments.size(), skylight_openings.size() + 1, "central roof geometry should be split around every skylight instead of covering the openings")
	var gallery_columns: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "gallery_column", gallery_columns)
	_assert_eq(gallery_columns.size(), int(floor_root.get_meta("gallery_column_count", 0)), "gallery column metadata should match the generated collision columns")
	var first_gallery_column := _find_node_by_name(floor_root, "GalleryColumnW00") as Node3D
	if first_gallery_column != null:
		_assert_true(absf(first_gallery_column.position.x) - 0.26 >= 2.8, "gallery column collisions should preserve the declared 5.6-metre central lane")
	_assert_eq(str(floor_root.get_meta("atmosphere_mode", "")), "slow_burn_suspense", "third floor should keep the suspense atmosphere under the colonnade")
	_assert_eq(str(floor_root.get_meta("lighting_profile", "")), "natural_skylight", "third floor should switch from horror darkness to natural skylight")
	_assert_eq(str(floor_root.get_meta("suspense_color_temperature", "")), "natural_daylight", "third-floor global illumination should use a natural daylight temperature")
	_assert_true(float(floor_root.get_meta("ambient_light_energy", 0.0)) >= 0.65, "third floor should be substantially brighter and more natural than floor two")
	_assert_true(float(floor_root.get_meta("ambient_light_energy", 0.0)) > floor_two_ambient_energy * 4.5, "third-floor ambient light should clearly separate itself from the near-black ring")
	_assert_true(float(floor_root.get_meta("key_light_energy", 0.0)) >= 1.1, "third-floor key light should read as strong daylight through the skylights")
	_assert_true(float(floor_root.get_meta("fog_density", 1.0)) < floor_two_fog_density * 0.5, "third-floor daylight should use cleaner air than the dark ring")
	_assert_eq(int(floor_root.get_meta("jump_scare_trigger_count", -1)), 0, "third-floor suspense should rely on space and repetition instead of jump-scare areas")
	_assert_true(_centerline_collision(floor_root, player).is_empty(), "third-floor continuous colonnade should keep its centerline walkable")
	var grass_field := _find_node_by_name(floor_root, "FullMapGrass") as MultiMeshInstance3D
	_assert_true(grass_field != null and grass_field.multimesh != null, "third-floor vegetation should render through a single MultiMeshInstance3D")
	if grass_field != null and grass_field.multimesh != null:
		_assert_eq(grass_field.multimesh.instance_count, int(floor_root.get_meta("grass_instance_count", -1)), "grass instance metadata should match the MultiMesh allocation")
		_assert_true(grass_field.multimesh.instance_count >= 50000, "full-map meadow should contain enough deterministic tufts to read as continuous ground cover")
		_assert_true(grass_field.multimesh.mesh is ArrayMesh, "MultiMesh grass should retain the custom tapered low-poly blade mesh")
		var grass_aabb := grass_field.multimesh.custom_aabb
		_assert_true(grass_aabb.size.x >= float(floor_root.get_meta("map_width", 0.0)) and grass_aabb.size.z >= float(floor_root.get_meta("map_length", 0.0)), "grass culling bounds should span the complete third-floor ground")
		var grass_material := grass_field.material_override as StandardMaterial3D
		_assert_true(grass_material != null and grass_material.cull_mode == BaseMaterial3D.CULL_DISABLED, "grass blades should remain visible from either side")
	_assert_true(float(floor_root.get_meta("grass_density_spacing", 99.0)) <= 0.45, "third-floor grass spacing should be dense enough to cover the entire map")
	_assert_true(float(floor_root.get_meta("grass_blade_height", 99.0)) <= 0.38, "third-floor grass should use a low meadow profile instead of sparse tall spikes")
	_assert_eq(str(floor_root.get_meta("grass_render_mode", "")), "multimesh", "third-floor grass should advertise its batched rendering mode")
	_assert_eq(str(floor_root.get_meta("grass_coverage", "")), "full_map", "third-floor grass metadata should explicitly cover the full map")
	_assert_eq(float(floor_root.get_meta("grass_coverage_ratio", 0.0)), 1.0, "third-floor grass coverage ratio should span the complete playable footprint")
	var grass_bounds := floor_root.get_meta("grass_bounds", Vector2.ZERO) as Vector2
	_assert_true(is_equal_approx(grass_bounds.x, float(floor_root.get_meta("map_width", 0.0))) and is_equal_approx(grass_bounds.y, float(floor_root.get_meta("map_length", 0.0))), "grass MultiMesh bounds metadata should match the generated map dimensions")
	_assert_true(_find_node_by_name(floor_root, "GrassPatch00") == null, "third floor should replace per-patch blade nodes with one batched field")
	_assert_dreamcore_objects(floor_root, "third floor")
	var gallery_reference_portal := _find_node_by_name(floor_root, "ReferencePortal") as MeshInstance3D
	_assert_true(gallery_reference_portal != null and str(gallery_reference_portal.get_meta("reference_texture", "")).contains("overgrown_gallery"), "gallery district should use the supplied reference as a distant spatial continuation")

	var floor_three_fog_density := float(floor_root.get_meta("fog_density", 0.0))
	game_root.game.tower_floor = 4
	game_root._ensure_reality_floor_current()
	floor_root = game_root.get_node_or_null("RealityFloor") as Node3D
	await physics_frame
	_assert_eq(int(floor_root.get_meta("ordinary_npc_count", 0)), 0, "hidden floor four should remove ordinary social contact")
	_assert_eq(_count_actors(floor_root, "npc"), 0, "hidden-floor actor population should match its metadata")
	_assert_true(_find_actor(floor_root, "doll") == null, "hidden floor should not repeat a normal-floor frame reward")
	_assert_true(_find_actor(floor_root, "merchant") == null, "hidden floor must remain free of the removed merchant")
	_assert_eq(str(floor_root.get_meta("atmosphere_mode", "")), "slow_burn_suspense", "returning district geometry should retain the darker post-floor-two treatment")
	_assert_true(float(floor_root.get_meta("fog_density", 0.0)) > floor_three_fog_density, "fourth-floor fog should continue the floor-by-floor progression")
	_assert_true(int(floor_root.get_meta("suspense_occluder_count", 0)) >= 5, "fourth floor should retain the non-blocking occlusion rhythm")
	_assert_eq(int(floor_root.get_meta("jump_scare_trigger_count", -1)), 0, "fourth-floor suspense should remain free of jump-scare triggers")
	_assert_true(_centerline_collision(floor_root, player).is_empty(), "fourth-floor suspense screens should not block the long street")

	game_root.queue_free()
	await process_frame


func _assert_dreamcore_objects(floor_root: Node3D, floor_label: String) -> void:
	var objects: Array[Node3D] = []
	_collect_nodes_with_meta(floor_root, "dreamcore_object", objects)
	_assert_eq(objects.size(), int(floor_root.get_meta("dreamcore_object_count", -1)), "%s dreamcore object metadata should match generated instances" % floor_label)
	_assert_true(int(floor_root.get_meta("dreamcore_object_type_count", 0)) >= 9, "%s should contain a varied set of recognizable liminal object categories" % floor_label)
	_assert_true(objects.size() >= 18, "%s should distribute recognizable liminal props across the map rather than cluster a token sample" % floor_label)
	_assert_eq(int(floor_root.get_meta("dreamcore_non_pickup_count", -1)), objects.size(), "%s should mark every dreamcore object as non-pickup" % floor_label)
	var object_types := {}
	for artifact in objects:
		object_types[str(artifact.get_meta("dreamcore_type", ""))] = true
		_assert_true(bool(artifact.get_meta("procedural_low_poly", false)), "%s dreamcore objects should identify their procedural low-poly construction" % floor_label)
		_assert_true(bool(artifact.get_meta("original_geometry", false)), "%s dreamcore objects should use original generated geometry" % floor_label)
		_assert_true(bool(artifact.get_meta("non_pickup", false)) and not bool(artifact.get_meta("interactable", true)), "%s dreamcore objects should be explicitly decorative and non-pickup" % floor_label)
		_assert_true(not (artifact is Area3D) and not bool(artifact.get_meta("useful_item", false)), "%s dreamcore objects should never enter the pickup Area3D path" % floor_label)
	var expected_types := ["false_window", "water_cooler", "crt_cart", "payphone", "folding_chair", "vending_machine", "fluorescent_troffer", "supply_crates", "pipe_manifold"]
	for expected_type in expected_types:
		_assert_true(object_types.has(expected_type), "%s should include the recognizable %s prop" % [floor_label, expected_type])
	var silhouette_parts := ["FalseWindowGlass", "WaterCoolerJug", "CRTTelevisionScreen", "PayphoneHandset", "FoldingChairSeat", "VendingMachineBody", "FluorescentTube00", "SupplyCrateLeft", "PipeValveWheel00"]
	for part_name in silhouette_parts:
		_assert_true(_find_node_by_name(floor_root, part_name) != null, "%s should preserve the defining silhouette part %s" % [floor_label, part_name])


func _assert_actor_face_veil(actor: Area3D, billboard: Sprite3D, actor_label: String) -> void:
	_assert_true(billboard != null, "%s should expose its untouched character billboard" % actor_label)
	if billboard == null:
		return
	_assert_eq(str(actor.get_meta("portrait_pose", "")), "front_eye_level", "%s should use the front-facing eye-level portrait composition" % actor_label)
	_assert_true(bool(billboard.get_meta("front_eye_level", false)), "%s billboard should declare its eye-level staging" % actor_label)
	var portrait_world_height := float(actor.get_meta("portrait_world_height", 0.0))
	var camera_eye_height := float(actor.get_meta("camera_eye_height", 0.0))
	var face_center_world_y := float(actor.get_meta("face_center_world_y", 99.0))
	_assert_near(portrait_world_height, 1.90, 0.01, "%s should share one compact cartoon portrait height" % actor_label)
	var bottom_padding := float(actor.get_meta("portrait_bottom_padding", 0.0))
	_assert_near(billboard.position.y - portrait_world_height * 0.5 + bottom_padding, 0.0, 0.01, "%s opaque shoes should meet the ground instead of floating" % actor_label)
	_assert_near(face_center_world_y, camera_eye_height, 0.08, "%s blank face should remain level with the first-person camera" % actor_label)
	_assert_eq(billboard.billboard, BaseMaterial3D.BILLBOARD_FIXED_Y, "%s character should face camera horizontally without lifting its feet" % actor_label)
	_assert_true(not billboard.shaded, "%s character colors should remain unlit and floor-independent" % actor_label)
	_assert_eq(billboard.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s character layer should avoid colored mipmap bleed at long distance" % actor_label)
	_assert_eq(billboard.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "%s character layer should not inherit floor lighting through shadows" % actor_label)
	_assert_true(billboard.material_override == null, "%s original character image should not receive a darkening or face-effect material" % actor_label)
	_assert_eq(billboard.modulate, Color.WHITE, "%s original character colors should remain unchanged" % actor_label)
	var overlay := actor.get_node_or_null("FaceScribbleOverlay") as Sprite3D
	_assert_true(overlay != null and overlay != billboard, "%s should place handwriting in a separate Sprite3D overlay" % actor_label)
	if overlay == null:
		return
	_assert_true(bool(overlay.get_meta("separate_face_effect", false)), "%s handwriting node should identify itself as a separate effect layer" % actor_label)
	_assert_true(overlay.texture == billboard.texture, "%s overlay should share the original canvas only for exact face alignment" % actor_label)
	_assert_eq(overlay.position, billboard.position, "%s overlay should remain registered over the original portrait" % actor_label)
	_assert_eq(overlay.scale, billboard.scale, "%s overlay should preserve the original portrait proportions" % actor_label)
	_assert_eq(overlay.billboard, BaseMaterial3D.BILLBOARD_FIXED_Y, "%s handwriting should share the grounded horizontal portrait orientation" % actor_label)
	_assert_true(not overlay.shaded, "%s handwriting should remain opaque black under every floor light" % actor_label)
	_assert_eq(overlay.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, "%s handwriting layer should retain a stable silhouette at long distance" % actor_label)
	_assert_true(overlay.render_priority > billboard.render_priority, "%s handwriting should render after and above the character layer" % actor_label)
	var material := overlay.material_override as ShaderMaterial
	_assert_true(material != null and material.shader != null, "%s separate handwriting layer should use an animated shader" % actor_label)
	_assert_true(bool(actor.get_meta("face_veil", false)), "%s should declare its identity-obscuring veil" % actor_label)
	_assert_eq(str(actor.get_meta("face_veil_style", "")), "separate_animated_marker_overlay", "%s veil should be a separate animated handwriting overlay" % actor_label)
	_assert_true(bool(actor.get_meta("face_effect_separate_layer", false)), "%s face effect should never be baked into the character material" % actor_label)
	_assert_true(bool(actor.get_meta("base_character_texture_preserved", false)), "%s should preserve the unmodified source character image" % actor_label)
	_assert_true(not bool(actor.get_meta("face_identity_readable", true)), "%s face should remain deliberately unreadable" % actor_label)
	if material != null and material.shader != null:
		_assert_eq(material.shader.resource_path, "res://shaders/npc_face_scribble_overlay.gdshader", "%s should use the standalone handwriting overlay shader" % actor_label)
		_assert_eq(float(material.get_shader_parameter("ink_opacity")), 1.0, "%s marker pixels should be fully opaque rather than multiply-darkening the face" % actor_label)
		var brush_width := float(material.get_shader_parameter("brush_width_px"))
		_assert_true(brush_width >= 40.0 and brush_width <= 60.0, "%s marker strokes should remain within the requested 40-60 px range" % actor_label)
		var scribble_atlas := material.get_shader_parameter("scribble_atlas") as Texture2D
		_assert_true(scribble_atlas != null and scribble_atlas.resource_path == "res://assets/generated/effects/face_scribble_atlas.png", "%s veil should use the four-frame hand-drawn marker atlas" % actor_label)
		var character_texture := material.get_shader_parameter("character_texture") as Texture2D
		_assert_true(character_texture == billboard.texture, "%s overlay shader should use the portrait only as an alpha alignment mask" % actor_label)
		var ink_color := material.get_shader_parameter("ink_color") as Color
		_assert_true(maxf(ink_color.r, maxf(ink_color.g, ink_color.b)) < 0.08, "%s overlay should output near-black ink" % actor_label)
		var face_center := material.get_shader_parameter("face_center") as Vector2
		var face_size := material.get_shader_parameter("face_size") as Vector2
		_assert_true(face_center.y >= 0.15 and face_center.y <= 0.20, "%s handwriting should stay centered on the illustrated face" % actor_label)
		_assert_true(face_size.x <= 0.18 and face_size.y <= 0.10, "%s handwriting should cover the face without becoming a head-to-chest rectangle" % actor_label)


func _vertical_ground_collision(floor_root: Node3D, point: Vector3, player: CharacterBody3D) -> Dictionary:
	if floor_root == null or floor_root.get_world_3d() == null:
		return {"missing_world": true}
	var from := floor_root.to_global(point + Vector3(0.0, 4.0, 0.0))
	var to := floor_root.to_global(point + Vector3(0.0, -5.0, 0.0))
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	if player != null:
		query.exclude = [player.get_rid()]
	return floor_root.get_world_3d().direct_space_state.intersect_ray(query)


func _projected_mesh_area(mesh_instance: MeshInstance3D) -> float:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return 0.0
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices := PackedInt32Array()
	var raw_indices: Variant = arrays[Mesh.ARRAY_INDEX]
	if raw_indices is PackedInt32Array:
		indices = raw_indices
	var area := 0.0
	if indices.is_empty():
		for vertex_index in range(0, vertices.size() - 2, 3):
			area += _projected_triangle_area(vertices[vertex_index], vertices[vertex_index + 1], vertices[vertex_index + 2])
	else:
		for index_offset in range(0, indices.size() - 2, 3):
			area += _projected_triangle_area(vertices[indices[index_offset]], vertices[indices[index_offset + 1]], vertices[indices[index_offset + 2]])
	return area


func _mesh_height_profile(mesh_instance: MeshInstance3D) -> Dictionary:
	if mesh_instance == null or mesh_instance.mesh == null or mesh_instance.mesh.get_surface_count() == 0:
		return {"range": 0.0, "quadrant_peaks": []}
	var arrays := mesh_instance.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var min_height := INF
	var max_height := -INF
	var quadrant_peaks := [-INF, -INF, -INF, -INF]
	for vertex in vertices:
		min_height = minf(min_height, vertex.y)
		max_height = maxf(max_height, vertex.y)
		var quadrant := (1 if vertex.x >= 0.0 else 0) + (2 if vertex.z >= 0.0 else 0)
		quadrant_peaks[quadrant] = maxf(float(quadrant_peaks[quadrant]), vertex.y)
	return {
		"range": max_height - min_height,
		"quadrant_peaks": quadrant_peaks,
	}


func _projected_triangle_area(a: Vector3, b: Vector3, c: Vector3) -> float:
	return absf((b.x - a.x) * (c.z - a.z) - (b.z - a.z) * (c.x - a.x)) * 0.5


func _centerline_collision(floor_root: Node3D, player: CharacterBody3D) -> Dictionary:
	if floor_root == null or floor_root.get_world_3d() == null:
		return {"missing_world": true}
	var half_length := float(floor_root.get_meta("map_length", 0.0)) * 0.5
	var from := floor_root.to_global(Vector3(0.0, 1.1, -half_length + 10.0))
	var to := floor_root.to_global(Vector3(0.0, 1.1, half_length - 10.0))
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collision_mask = 1
	query.collide_with_areas = false
	if player != null:
		query.exclude = [player.get_rid()]
	return floor_root.get_world_3d().direct_space_state.intersect_ray(query)


func _action_has_key(action_name: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and (event.physical_keycode == keycode or event.keycode == keycode):
			return true
	return false


func _find_actor(node: Node, actor_type: String) -> Area3D:
	if node is Area3D and str(node.get_meta("actor_type", "")) == actor_type:
		return node as Area3D
	for child in node.get_children():
		var found := _find_actor(child, actor_type)
		if found != null:
			return found
	return null


func _collect_actor_z_positions(node: Node, actor_type: String, result: Array[float]) -> void:
	if node is Area3D and str(node.get_meta("actor_type", "")) == actor_type:
		result.append((node as Area3D).position.z)
	for child in node.get_children():
		_collect_actor_z_positions(child, actor_type, result)


func _collect_actor_texture_ids(node: Node, actor_type: String, result: Dictionary) -> void:
	if node is Area3D and str(node.get_meta("actor_type", "")) == actor_type:
		var billboard := node.get_node_or_null("Billboard") as Sprite3D
		if billboard != null and billboard.texture != null:
			result[billboard.texture.get_instance_id()] = true
	for child in node.get_children():
		_collect_actor_texture_ids(child, actor_type, result)


func _count_actors(node: Node, actor_type: String) -> int:
	var count := 1 if node is Area3D and str(node.get_meta("actor_type", "")) == actor_type else 0
	for child in node.get_children():
		count += _count_actors(child, actor_type)
	return count


func _find_useful_item(node: Node) -> Area3D:
	if node is Area3D and bool(node.get_meta("useful_item", false)):
		return node as Area3D
	for child in node.get_children():
		var found := _find_useful_item(child)
		if found != null:
			return found
	return null


func _find_item_by_id(node: Node, item_id: String) -> Area3D:
	if node is Area3D and str(node.get_meta("item_id", "")) == item_id:
		return node as Area3D
	for child in node.get_children():
		var found := _find_item_by_id(child, item_id)
		if found != null:
			return found
	return null


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _collect_nodes_with_meta(node: Node, meta_name: StringName, result: Array[Node3D]) -> void:
	if node is Node3D and bool(node.get_meta(meta_name, false)):
		result.append(node as Node3D)
	for child in node.get_children():
		_collect_nodes_with_meta(child, meta_name, result)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.4f +/- %.4f, got %.4f)" % [message, expected, tolerance, actual])
