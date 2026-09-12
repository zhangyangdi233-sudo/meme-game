extends SceneTree

const SMALL_VIEW_SIZE := Vector2i(640, 720)

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("responsive layout tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	root.size = SMALL_VIEW_SIZE
	root.content_scale_size = SMALL_VIEW_SIZE
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load for responsive layout test")
	if scene == null:
		return
	var game_root := scene.instantiate()
	root.add_child(game_root)
	# 布局断言以源语言(中文)几何为准:显式固定 locale,隔离持久化偏好文件的污染
	# (外部工具/探针可能把偏好写成 en/ja,英文长字符串会让小窗布局溢出)。
	game_root._locale.set_locale("zh")
	if game_root.has_method("new_game"):
		game_root.new_game()
	game_root._render()
	await process_frame
	await process_frame

	var viewport_rect := Rect2(Vector2.ZERO, root.get_visible_rect().size)
	_assert_true(viewport_rect.size == Vector2(SMALL_VIEW_SIZE), "responsive test should run at the requested small viewport size")
	var hud := _find_node_by_name(game_root, "InternationalHUDRail") as PanelContainer
	var social_window := _find_node_by_name(game_root, "SocialAppWindow") as PanelContainer
	var social_bottom_nav := _find_node_by_name(game_root, "SocialBottomNav") as HBoxContainer
	var social_inline_close := _find_node_by_name(game_root, "SocialAppInlineCloseButton") as Button
	var view_toggle := _find_node_by_name(game_root, "PhoneViewToggleButton") as Button
	var meme_bank := _find_node_by_name(game_root, "MemeBankPopup") as Control
	var actions_label := _find_node_by_name(game_root, "HUDActionsLabel") as Label
	_assert_true(hud != null, "small view should keep the left HUD rail")
	_assert_true(social_window != null and social_window.visible, "small view should open the social phone")
	if hud != null and social_window != null:
		_assert_true(_inside_rect(social_window, viewport_rect), "small-view social phone should stay inside the viewport")
		_assert_true(social_window.get_global_rect().position.x >= hud.get_global_rect().end.x + 8.0, "small-view social phone should not cover the HUD rail")
	if social_bottom_nav != null:
		_assert_true(_inside_rect(social_bottom_nav, viewport_rect), "small-view social bottom nav should stay reachable")
	if social_inline_close != null:
		_assert_true(_inside_rect(social_inline_close, viewport_rect), "small-view social close button should stay reachable")
		_assert_true(social_inline_close.custom_minimum_size.x >= 44.0, "small-view social close target should meet mobile touch guidance")
	if view_toggle != null:
		_assert_true(_inside_rect(view_toggle, viewport_rect), "small-view put-phone button should stay reachable")
	_assert_true(meme_bank == null, "small view must not mount the retired meme ring")
	if game_root.has_method("_open_social_post"):
		game_root._open_social_post(0)
		await process_frame
		var detail_window := _find_node_by_name(game_root, "SocialDetailWindow") as PanelContainer
		var detail_close := _find_node_by_name(game_root, "SocialDetailWindowCloseButton") as Button
		_assert_true(detail_window != null and detail_window.visible, "small view should open the independent post detail companion")
		if detail_window != null:
			_assert_true(_inside_rect(detail_window, viewport_rect), "small-view detail companion should stay inside the viewport")
		if detail_close != null:
			detail_close.pressed.emit()
			_assert_true(detail_window != null and not detail_window.visible, "small-view detail close should return focus to the phone feed")
		social_inline_close = _find_node_by_name(game_root, "SocialAppInlineCloseButton") as Button

	if social_inline_close != null:
		social_inline_close.pressed.emit()
	await process_frame
	var phone_home := _find_node_by_name(game_root, "PhonePopup") as PanelContainer
	var phone_content := _find_node_by_name(game_root, "PhoneContent") as Control
	var phone_social_icon := _find_node_by_name(game_root, "PhoneAppIconSocial") as Button
	_assert_true(phone_home != null and phone_home.visible, "closing social on small view should reveal the phone home")
	if phone_home != null:
		_assert_true(_inside_rect(phone_home, viewport_rect), "small-view phone home should stay inside the viewport")
		if hud != null:
			_assert_true(phone_home.get_global_rect().position.x >= hud.get_global_rect().end.x + 8.0, "small-view phone home should not cover the HUD rail")
	_assert_true(phone_content != null and phone_content.visible, "small-view phone home should expose app icons")
	if phone_social_icon != null:
		_assert_true(_inside_rect(phone_social_icon, viewport_rect), "small-view phone app icons should stay reachable")
	if game_root.has_method("set_view_state"):
		game_root.set_view_state("npc_up")
	await process_frame
	var reality_subtitle := _find_node_by_name(game_root, "RealitySubtitlePanel") as PanelContainer
	var reality_choices := _find_node_by_name(game_root, "RealityResponseChoices") as HBoxContainer
	var phone_tab := _find_node_by_name(game_root, "PhoneTab") as Button
	_assert_true(phone_tab == null, "responsive layout should not restore the duplicate PHONE tab")
	_assert_true(reality_subtitle != null and not reality_subtitle.visible, "small-view walking mode should wait for an F interaction before showing subtitles")
	var reality_player := _find_node_by_name(game_root, "RealityPlayer") as CharacterBody3D
	var reality_doll := _find_node_by_name(game_root, "DollEncounter") as Area3D
	if reality_player != null and reality_doll != null:
		reality_player.position = reality_doll.position + Vector3(0.0, 0.0, 1.4)
		game_root._refresh_nearby_reality_actor()
		game_root._try_reality_interaction()
	await process_frame
	_assert_true(reality_subtitle != null and reality_subtitle.visible, "small-view F interaction should show the movie subtitle")
	_assert_true(reality_choices != null and reality_choices.visible and reality_choices.get_child_count() == 3, "small-view dialogue should fit all three response choices")
	if reality_subtitle != null:
		_assert_true(_inside_rect(reality_subtitle, viewport_rect), "small-view movie subtitle should stay inside the viewport")
	if reality_choices != null:
		_assert_true(_inside_rect(reality_choices, viewport_rect), "small-view response choices should stay inside the viewport")
	var doll_choices: Array = game_root.game.get_typed_reality_choices()
	_assert_true(not doll_choices.is_empty(), "small-view doll discovery should expose authored choices")
	var first_choice_id := str(doll_choices[0].get("id", "")) if not doll_choices.is_empty() else ""
	if not first_choice_id.is_empty():
		game_root._on_reality_choice_hovered(first_choice_id)
	var intent_preview := _find_node_by_name(game_root, "RealityIntentPreview") as RichTextLabel
	_assert_true(intent_preview != null and intent_preview.visible, "small-view hover should reveal the full intended sentence")
	if intent_preview != null:
		_assert_true(_inside_rect(intent_preview, viewport_rect), "small-view intent preview should stay inside the viewport")
		if reality_subtitle != null:
			_assert_true(not intent_preview.get_global_rect().intersects(reality_subtitle.get_global_rect()), "small-view intent preview should not cover the subtitle")
	if not first_choice_id.is_empty():
		game_root._on_reality_choice_selected(first_choice_id)
	await process_frame
	var typing_line := _find_node_by_name(game_root, "RealityTypingLine") as RichTextLabel
	var typing_progress := _find_node_by_name(game_root, "RealityTypingProgress") as Label
	_assert_true(typing_line != null and typing_line.visible, "small-view selected response should become the per-key typing line")
	_assert_true(typing_progress != null and typing_progress.visible, "small-view typing should expose concise progress")
	_assert_true(_find_node_by_name(game_root, "LanguagePuzzleFrame") == null, "small-view dialogue should not restore the retired Florence puzzle")
	for control in [typing_line, typing_progress, reality_subtitle]:
		if control != null and control.visible:
			_assert_true(_inside_rect(control, viewport_rect), "small-view reality control should stay inside the viewport: %s" % control.name)
	if hud != null and typing_line != null:
		_assert_true(typing_line.get_global_rect().position.x >= hud.get_global_rect().end.x + 8.0, "small-view typing line should keep clear of the HUD rail")
	_assert_true(_find_node_by_name(game_root, "Merchant") == null, "small view must not restore the removed merchant actor")
	_assert_true(_find_node_by_name(game_root, "RealityMerchantOffer") == null, "doll dialogue should use the shared result surface instead of a trade panel")
	_assert_true(_find_node_by_name(game_root, "RealityMerchantBuyButton") == null, "doll frames should never expose a purchase button")
	game_root.queue_free()


func _inside_rect(control: Control, viewport_rect: Rect2) -> bool:
	if control == null or not control.visible:
		return false
	var rect := control.get_global_rect()
	return rect.position.x >= viewport_rect.position.x and rect.position.y >= viewport_rect.position.y and rect.end.x <= viewport_rect.end.x and rect.end.y <= viewport_rect.end.y


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
