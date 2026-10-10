extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load for social layout verification")
	if scene == null:
		_finish()
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	game_root._locale.set_locale("ja")
	game_root.new_game()
	game_root._skip_prologue()
	game_root.game.set_active_app("social")
	game_root._set_social_screen("home")
	for _frame in 8:
		await process_frame

	var masonry := _find_node_by_name(game_root, "SocialFeedMasonry") as HBoxContainer
	var column_0 := _find_node_by_name(game_root, "SocialMasonryColumn0") as VBoxContainer
	var column_1 := _find_node_by_name(game_root, "SocialMasonryColumn1") as VBoxContainer
	_assert_true(masonry != null and column_0 != null and column_1 != null, "Japanese feed should use two independent masonry columns")
	if column_0 != null and column_1 != null:
		_assert_near(column_0.size.x, column_1.size.x, 0.5, "masonry columns must receive identical rendered width")
		_assert_column_continuity(column_0)
		_assert_column_continuity(column_1)
	var cards: Array[PanelContainer] = []
	_collect_social_cards(game_root, cards)
	_assert_true(cards.size() >= 4, "Japanese feed should lay out enough cards to compare both columns")
	if cards.size() >= 2:
		var expected_width := cards[0].size.x
		_assert_true(expected_width >= 150.0, "social cards should remain comfortably readable")
		var has_staggered_height := false
		for card in cards:
			_assert_near(card.size.x, expected_width, 0.5, "left and right Japanese cards must have identical rendered width")
			if absf(card.size.y - cards[0].size.y) > 1.0:
				has_staggered_height = true
		_assert_true(has_staggered_height, "equal card width should not force every masonry card to the same height")
		var first_clip := _find_node_by_name(cards[0], "SocialPostClip0") as Control
		_assert_true(first_clip != null and first_clip.clip_contents, "localized content should be isolated from column width calculation")
		var first_poster := _find_node_by_name(cards[0], "SocialPostTexture0") as TextureRect
		_assert_true(first_poster != null, "first social card should expose a poster click target")
		if first_poster != null:
			var click_point := first_poster.get_global_rect().get_center()
			var press := InputEventMouseButton.new()
			press.position = click_point
			press.global_position = click_point
			press.button_index = MOUSE_BUTTON_LEFT
			press.button_mask = MOUSE_BUTTON_MASK_LEFT
			press.pressed = true
			game_root.get_viewport().push_input(press, true)
			await process_frame
			var release := InputEventMouseButton.new()
			release.position = click_point
			release.global_position = click_point
			release.button_index = MOUSE_BUTTON_LEFT
			release.pressed = false
			game_root.get_viewport().push_input(release, true)
			await process_frame
			_assert_true(game_root._social_detail_open, "clicking a poster in the rendered feed should open its detail page")
			_assert_true(_find_node_by_name(game_root, "SocialPostDetailPage") != null, "poster click should render the social detail page")

	game_root.queue_free()
	await process_frame
	_finish()


func _assert_column_continuity(column: VBoxContainer) -> void:
	var column_cards: Array[Control] = []
	for child in column.get_children():
		if child is Control and bool(child.get_meta("social_card", false)):
			column_cards.append(child as Control)
	_assert_true(column_cards.size() >= 2, "%s should contain enough cards to demonstrate independent stacking" % column.name)
	for index in range(1, column_cards.size()):
		var previous := column_cards[index - 1]
		var current := column_cards[index]
		var gap := current.position.y - (previous.position.y + previous.size.y)
		_assert_near(gap, 10.0, 0.75, "%s cards should stack continuously without row-height holes" % column.name)


func _collect_social_cards(node: Node, result: Array[PanelContainer]) -> void:
	if node is PanelContainer and str(node.name).begins_with("SocialPostCard"):
		result.append(node as PanelContainer)
	for child in node.get_children():
		_collect_social_cards(child, result)


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_near(actual: float, expected: float, tolerance: float, message: String) -> void:
	if absf(actual - expected) > tolerance:
		_failures.append("%s (expected %.2f +/- %.2f, got %.2f)" % [message, expected, tolerance, actual])


func _finish() -> void:
	if _failures.is_empty():
		print("social feed layout tests passed")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
