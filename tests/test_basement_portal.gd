extends SceneTree
## The portal itself (`BasementPortal`, planner's design of 2026-10-31): the frame as tangents of the eye that looks
## through it, looking and fixing, who has walked into a fixed frame (never the fixing player where they stand, and from
## nearer on when a wall stands close), the mapping that puts the fixing player at the other world's start, and the flat
## print of a portal that is used up.

const ROOM := AABB(Vector3(-3.2, -0.3, -4.2), Vector3(6.4, 6.0, 8.4))
const FOV := 58.0
const ASPECT := 16.0 / 9.0
const FRAME := Rect2(0.30, 0.22, 0.40, 0.52)
const START := Vector3(0.0, 0.04, 11.5)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_main")


func _main() -> void:
	test_a_frame_is_measured_in_the_eyes_tangents()
	await _test_looking_shows_the_window_and_looking_away_takes_it_back()
	await _test_a_fixed_portal_stays_until_another_is_fixed()
	await _test_a_fixed_frame_holds_who_walks_into_it()
	await _test_the_fixing_players_own_body_is_not_walked_in()
	await _test_a_frame_held_up_to_a_wall_is_walked_into_at_the_wall()
	await _test_the_fixing_player_stands_at_the_other_worlds_start()
	await _test_a_used_up_portal_is_a_print_nobody_walks_into()
	if _failures.is_empty():
		print("basement portal tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func test_a_frame_is_measured_in_the_eyes_tangents() -> void:
	var half_height := tan(deg_to_rad(FOV) * 0.5)
	var whole: Rect2 = BasementPortal.frame_tangents(Rect2(0.0, 0.0, 1.0, 1.0), FOV, ASPECT)
	_assert_near(whole.position.x, -half_height * ASPECT, "the screen's left edge")
	_assert_near(whole.end.x, half_height * ASPECT, "the screen's right edge")
	_assert_near(whole.position.y, -half_height, "the screen's bottom edge")
	_assert_near(whole.end.y, half_height, "the screen's top edge")
	var upper_left: Rect2 = BasementPortal.frame_tangents(Rect2(0.0, 0.0, 0.5, 0.5), FOV, ASPECT)
	_assert_near(upper_left.end.x, 0.0, "a frame ending at the screen's middle should end at the eye's axis")
	_assert_near(upper_left.position.y, 0.0, "the screen's upper half should be the tangents above the axis")
	_assert_near(upper_left.end.y, half_height, "the screen's top should stay the top")


func _test_looking_shows_the_window_and_looking_away_takes_it_back() -> void:
	var portal := await _portal()
	var window := portal.get_node("PortalWindow") as MeshInstance3D
	var other := portal.get_node("PortalWorld") as SubViewport
	var material := window.material_override as ShaderMaterial
	_assert_true(not window.visible and portal.state() == BasementPortal.STATE_NONE, "a portal nobody looks through should show nothing")
	_assert_eq(other.render_target_update_mode, SubViewport.UPDATE_DISABLED, "the other world should not be drawn while nobody looks")
	portal.look_through(_eye(), _tangents(), 0.4)
	_assert_eq(portal.state(), BasementPortal.STATE_PREVIEW, "looking through the frame should show the other world in it")
	_assert_true(window.visible, "the window should show while the X-ray looks")
	_assert_eq(other.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "the other world should be drawn while it is looked at")
	_assert_near(float(material.get_shader_parameter("progress")), 0.4, "the sticker should be pasted as far as the frame was held")
	_assert_near(float(material.get_shader_parameter("frame_near")), BasementPortal.NEAR, "the other world should begin a step ahead of the eye")
	_assert_eq(material.render_priority, RenderingServer.MATERIAL_RENDER_PRIORITY_MAX, "the window should be drawn after the room's glass")
	_assert_true(not portal.holds(_ahead(1.6)), "a frame that is only looked through holds nobody")
	portal.look_through(_eye(), _tangents(), 0.5, 0.0, 0.4)
	_assert_near(float(material.get_shader_parameter("frame_near")), 0.4, "a look at something close should begin the other world nearer")
	portal.look_away()
	_assert_true(not window.visible and portal.state() == BasementPortal.STATE_NONE, "looking away before the frame is fixed should leave nothing")
	await _free(portal)


func _test_a_fixed_portal_stays_until_another_is_fixed() -> void:
	var portal := await _portal()
	var window := portal.get_node("PortalWindow") as MeshInstance3D
	portal.fix(_eye(), _tangents())
	portal.look_away()
	_assert_true(portal.is_fixed() and window.visible, "a fixed frame should stay when the X-ray looks away")
	# A new look (the camera found the hands again, X was tapped) shows nothing new and takes nothing away.
	var elsewhere := Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0.5, 1.56, 2.0))
	portal.look_through(elsewhere, _tangents(), 0.3)
	_assert_true(portal.is_fixed() and portal.holds(_ahead(1.6)), "a new look should leave the fixed portal where it is")
	portal.look_away()
	_assert_true(portal.is_fixed(), "that look ending should leave the fixed portal as well")
	portal.fix(elsewhere, _tangents())
	_assert_true(portal.is_fixed() and not portal.holds(_ahead(1.6)), "a newly fixed frame should stand in place of the old one")
	_assert_true(portal.holds(Vector3(0.5 - 1.6, 0.0, 2.0)), "the new frame should hold who walks into it the way it looks")
	await _free(portal)


func _test_a_fixed_frame_holds_who_walks_into_it() -> void:
	var portal := await _portal()
	portal.fix(_eye(), _tangents())
	_assert_true(not portal.holds(_ahead(0.0)), "the player who fixed the frame stands in front of it")
	_assert_true(not portal.holds(_ahead(BasementPortal.NEAR - 0.05)), "the other world begins a step ahead of the fixing eye")
	_assert_true(portal.holds(_ahead(1.6)), "a player who walks ahead into the frame should be in the other world")
	_assert_true(portal.holds(_ahead(3.5)), "the frame goes on as far as the eye saw")
	_assert_true(not portal.holds(_ahead(-1.0)), "behind the fixing eye there is no portal")
	_assert_true(not portal.holds(_ahead(1.6) + Vector3(2.5, 0.0, 0.0)), "beside the frame there is no portal")
	portal.clear()
	_assert_true(not portal.is_fixed() and not portal.holds(_ahead(1.6)), "a portal taken away holds nobody")
	await _free(portal)


func _test_the_fixing_players_own_body_is_not_walked_in() -> void:
	var portal := await _portal()
	# Looking steeply down through a frame low on the screen: it holds the player's own legs.
	var feet := Vector3(0.5, 0.0, 2.0)
	var down := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-68.0)), feet + Vector3(0.0, 1.56, 0.0))
	var low: Rect2 = BasementPortal.frame_tangents(Rect2(0.2, 0.5, 0.6, 0.48), FOV, ASPECT)
	portal.fix(down, low, false, FRAME, feet)
	_assert_true(not portal.holds(feet), "the player who fixed a frame at their own feet should not be taken where they stand")
	_assert_true(not portal.holds(feet + Vector3(0.0, 0.0, -0.1)), "a shuffle should not take them either")
	_assert_true(portal.holds(feet + Vector3(0.0, 0.0, -0.4)), "a step into the frame should")
	await _free(portal)


func _test_a_frame_held_up_to_a_wall_is_walked_into_at_the_wall() -> void:
	var portal := await _portal()
	# A wall 0.6 m ahead: the host says the other world begins just short of it, and a body counts once it is as near
	# the wall as a body gets.
	portal.fix(_eye(), _tangents(), false, FRAME, _ahead(0.0), 0.48, 0.2)
	var material := (portal.get_node("PortalWindow") as MeshInstance3D).material_override as ShaderMaterial
	_assert_near(float(material.get_shader_parameter("frame_near")), 0.48, "the other world should begin just short of the wall")
	_assert_true(not portal.holds(_ahead(0.0)), "the player should not be taken before they walk at the wall")
	_assert_true(portal.holds(_ahead(0.25)), "walking at the wall should take the player through")
	await _free(portal)


func _test_the_fixing_player_stands_at_the_other_worlds_start() -> void:
	var portal := await _portal()
	# A player on a stair 1.2 m up, looking along +X in the room and a little down.
	var feet := Vector3(-0.5, 1.2, 1.0)
	var eye := Transform3D(Basis.looking_at(Vector3(1.0, -0.2, 0.0), Vector3.UP), feet + Vector3(0.0, 1.56, 0.0))
	portal.fix(eye, _tangents(), false, FRAME, feet)
	var to_other: Transform3D = portal.to_other()
	_assert_true((to_other * feet).is_equal_approx(START), "the fixing player's feet should be the other world's start, whatever floor they stand on: %s" % str(to_other * feet))
	_assert_true((to_other.basis * Vector3.RIGHT).is_equal_approx(Vector3.FORWARD), "the way the eye looked should be the way to the other world's door: %s" % str(to_other.basis * Vector3.RIGHT))
	_assert_true((to_other * (feet + Vector3(1.5, 0.0, 0.0))).is_equal_approx(START + Vector3(0.0, 0.0, -1.5)), "a player 1.5 m into the frame should stand 1.5 m toward the door")
	_assert_true((to_other * eye.origin).is_equal_approx(START + Vector3(0.0, 1.56, 0.0)), "the fixing eye should be at eye height over the other world's ground")
	await _free(portal)


func _test_a_used_up_portal_is_a_print_nobody_walks_into() -> void:
	var portal := await _portal()
	portal.look_through(_eye(), _tangents(), 0.9)
	portal.fix(_eye(), _tangents(), true, FRAME)
	_assert_true(portal.is_fixed() and portal.is_flat(), "a used-up portal should still fix, as a print")
	_assert_true(not portal.holds(_ahead(1.6)), "nobody walks into a print")
	portal.fix(_eye(), _tangents())
	_assert_true(not portal.is_flat() and portal.holds(_ahead(1.6)), "a portal fixed anew should be a way through again")
	await _free(portal)


func _portal() -> BasementPortal:
	var portal := BasementPortal.new()
	root.add_child(portal)
	_assert_true(portal.build(ROOM, Transform3D(Basis.IDENTITY, START)), "the portal should build its window and its other world")
	await process_frame
	return portal


func _free(portal: BasementPortal) -> void:
	portal.queue_free()
	await process_frame


## An eye at standing height looking along -Z, level.
func _eye() -> Transform3D:
	return Transform3D(Basis.IDENTITY, Vector3(0.5, 1.56, 2.0))


func _tangents() -> Rect2:
	return BasementPortal.frame_tangents(FRAME, FOV, ASPECT)


## The floor point `distance` ahead of `_eye()`.
func _ahead(distance: float) -> Vector3:
	return Vector3(0.5, 0.0, 2.0 - distance)


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])


func _assert_near(actual: float, expected: float, message: String) -> void:
	if absf(actual - expected) > 0.0005:
		_failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])
