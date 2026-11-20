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
	game_root._skip_chapter_one()
	await process_frame

	# The left HUD rail is retired (old version): it is still built, but it and its reveal strip stay hidden in
	# play and the edge drawer never opens.
	var rail := _find_node_by_name(game_root, "InternationalHUDRail") as PanelContainer
	var reveal_zone := _find_node_by_name(game_root, "HUDRevealZone") as Control
	_assert_true(rail != null, "gameplay should still build the retired HUD rail")
	_assert_true(reveal_zone != null, "gameplay should still build its reveal zone")

	if rail != null and reveal_zone != null:
		_assert_true(not rail.is_visible_in_tree(), "the retired HUD rail should stay hidden in play")
		_assert_true(not reveal_zone.is_visible_in_tree(), "the retired rail's reveal strip should stay hidden in play")
		_assert_true(not game_root._is_hud_drawer_expanded(), "the HUD drawer should stay collapsed")
		reveal_zone.mouse_entered.emit()
		_assert_true(not game_root._is_hud_drawer_expanded(), "hovering the left edge should not reveal the retired rail")
		var touch := InputEventScreenTouch.new()
		touch.pressed = true
		touch.position = reveal_zone.get_global_rect().get_center()
		reveal_zone.gui_input.emit(touch)
		_assert_true(not game_root._is_hud_drawer_expanded(), "tapping the left edge should not reveal the retired rail")
		game_root._update_visibility()
		_assert_true(not rail.is_visible_in_tree(), "a visibility pass should keep the retired rail hidden")

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
