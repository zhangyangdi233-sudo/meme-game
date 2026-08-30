extends SceneTree

const EdgeDrawerScript = preload("res://framework/ui/edge_drawer.gd")

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _test_edge_drawer_unit()
	await _test_edge_drawer_integration()
	if _failures.is_empty():
		print("HUD drawer tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _test_edge_drawer_unit() -> void:
	_assert_true(EdgeDrawerScript != null, "edge drawer script should exist")
	if EdgeDrawerScript == null:
		return
	var drawer = EdgeDrawerScript.new()
	root.add_child(drawer)
	var panel := PanelContainer.new()
	panel.size = Vector2(158.0, 400.0)
	panel.position = Vector2(-158.0, 40.0)
	root.add_child(panel)
	var reveal_zone := Control.new()
	reveal_zone.size = Vector2(44.0, 400.0)
	root.add_child(reveal_zone)
	drawer.configure(158.0, 0.26, 0.18, 0.22)
	drawer.attach(panel, reveal_zone)
	_assert_true(not drawer.is_expanded(), "drawer should start collapsed")
	drawer.set_expanded(true, false)
	_assert_true(drawer.is_expanded(), "drawer should track expanded state")
	_assert_true(is_equal_approx(panel.position.x, 0.0), "expanded drawer should sit on the left edge")
	drawer.set_expanded(false, false)
	_assert_true(is_equal_approx(panel.position.x, -158.0), "collapsed drawer should hide off-screen")
	drawer.set_expanded(true, false)
	drawer.tick(0.1)
	_assert_true(drawer.is_expanded(), "auto-close should wait for the configured delay")
	drawer.tick(0.25)
	_assert_true(not drawer.is_expanded(), "auto-close should collapse after the delay elapses")
	drawer.reset_runtime_state()
	_assert_true(not drawer.is_expanded(), "runtime reset should leave the drawer collapsed")
	panel.queue_free()
	reveal_zone.queue_free()
	drawer.queue_free()
	await process_frame


func _test_edge_drawer_integration() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "HUD drawer test should load the main scene")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root.new_game()
	game_root._skip_prologue()
	await process_frame

	var rail := _find_node_by_name(game_root, "InternationalHUDRail") as PanelContainer
	var reveal_zone := _find_node_by_name(game_root, "HUDRevealZone") as Control
	var reveal_indicator := _find_node_by_name(game_root, "HUDRevealIndicator") as ColorRect
	_assert_true(rail != null, "gameplay should keep the international HUD rail")
	_assert_true(reveal_zone != null, "collapsed HUD should expose a left-edge reveal zone")
	_assert_true(reveal_indicator != null, "the invisible hit zone should have a narrow visible edge cue")
	_assert_true(game_root.has_method("_set_hud_drawer_expanded"), "HUD drawer should expose one state transition method")
	_assert_true(game_root.has_method("_is_hud_drawer_expanded"), "HUD drawer state should be observable without reading animation internals")

	if rail != null and reveal_zone != null:
		_assert_true(not game_root._is_hud_drawer_expanded(), "HUD rail should start collapsed")
		_assert_true(rail.get_global_rect().end.x <= 1.0, "collapsed HUD rail should sit fully outside the left edge")
		_assert_true(reveal_zone.visible and reveal_zone.get_global_rect().size.x >= 44.0, "left-edge reveal target should remain touch friendly")
		_assert_true(bool(reveal_zone.get_meta("hover_reveals", false)), "desktop hover should reveal the drawer")
		_assert_true(bool(reveal_zone.get_meta("touch_reveals", false)), "touch should have a non-hover fallback")

		game_root._set_hud_drawer_expanded(true, false)
		_assert_true(game_root._is_hud_drawer_expanded(), "explicit expansion should update drawer state")
		_assert_true(rail.get_global_rect().position.x >= -1.0, "expanded HUD should slide in from the left")
		_assert_true(rail.get_global_rect().end.x >= 150.0, "expanded HUD should restore the full icon rail")

		game_root._set_hud_drawer_expanded(false, false)
		reveal_zone.mouse_entered.emit()
		_assert_true(game_root._is_hud_drawer_expanded(), "hovering the left-edge target should reveal the HUD")

		reveal_zone.visible = false
		rail.mouse_exited.emit()
		game_root._update_hud_drawer_auto_close(1.0)
		_assert_true(not game_root._is_hud_drawer_expanded(), "leaving both the rail and edge target should collapse the HUD after its delay")
		reveal_zone.visible = true

		game_root._set_hud_drawer_expanded(false, false)
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = reveal_zone.get_global_rect().get_center()
		reveal_zone.gui_input.emit(touch)
		_assert_true(game_root._is_hud_drawer_expanded(), "tapping the edge target should reveal the HUD")

		var outside_touch := InputEventScreenTouch.new()
		outside_touch.pressed = true
		outside_touch.position = Vector2(900.0, 450.0)
		_assert_true(game_root._handle_hud_drawer_global_input(outside_touch), "a touch outside the pinned drawer should be consumed")
		_assert_true(not game_root._is_hud_drawer_expanded(), "touching outside should collapse the pinned drawer")

	game_root.queue_free()
	await process_frame


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
