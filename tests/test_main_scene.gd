extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	root.size = Vector2i(1600, 900)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	_assert_true(scene != null, "main scene should load")
	if scene == null:
		_finish()
		return

	var game_root := scene.instantiate()
	root.add_child(game_root)
	await process_frame
	game_root._locale.set_locale("zh")
	_test_main_menu(game_root)

	game_root.new_game()
	game_root._skip_prologue()
	await process_frame
	_test_scene_contract(game_root)
	_test_compact_hud_and_settings(game_root)
	_test_phone_apps(game_root)
	_test_social_feed(game_root)
	_test_physical_doll_entry(game_root)
	_test_language_and_playtest_contract(game_root)

	game_root.queue_free()
	await process_frame
	_finish()


func _test_main_menu(game_root: Node) -> void:
	var main_menu := _find_node_by_name(game_root, "MainMenuLayer") as Control
	var start_button := _find_node_by_name(game_root, "MainMenuStartButton") as Button
	var exit_button := _find_node_by_name(game_root, "MainMenuExitButton") as Button
	_assert_true(main_menu != null and main_menu.visible, "launch should expose the main menu")
	_assert_true(start_button != null, "main menu should expose start")
	_assert_true(exit_button != null, "main menu should retain a direct system exit")


func _test_scene_contract(game_root: Node) -> void:
	_assert_true(game_root is Node3D, "gameplay root should remain Node3D")
	_assert_true(game_root.get_node_or_null("Camera3D") is Camera3D, "gameplay should retain its 3D camera")
	_assert_true(game_root.get_node_or_null("CanvasLayer") is CanvasLayer, "2D interaction UI should remain on a CanvasLayer")
	_assert_true(game_root.get_node_or_null("RealityFloor") is Node3D, "the physical floor should exist")
	_assert_true(game_root.has_method("set_view_state"), "camera should support phone-down and NPC-up views")
	_assert_true(game_root.has_method("_play_pollution_flashback"), "the 60-percent flashback entry should remain wired")
	_assert_true(game_root.has_method("_finish_pollution_flashback"), "the flashback should expose a deterministic completion path")
	_assert_true(_find_node_by_name(game_root, "PollutionFlashbackOverlay") is Control, "the flashback overlay should be present")
	_assert_true(game_root.get_node_or_null("Road") == null, "retired road tiles must not be built each run")
	_assert_true(game_root.get_node_or_null("PhoneRig") == null, "retired PhoneRig must not be built each run")
	_assert_true(game_root.get_node_or_null("NPC") == null, "retired NPC plane must not be built each run")
	_assert_true(_find_node_by_name(game_root, "MemeBankPopup") == null, "retired meme ring popup must not hang into the adapter")
	_assert_true(_find_node_by_name(game_root, "DollCompanionBody") == null, "retired 3D companion body must not exist")
	_assert_true(_find_node_by_name(game_root, "DollGuideOverlay") is Control, "the DollGuide window must remain")
	var backdrop := _find_node_by_name(game_root, "PhoneDownBackdropImage") as TextureRect
	_assert_true(backdrop != null, "phone-down backdrop should remain")
	if backdrop != null:
		game_root.set_view_state("phone_down")
		for _settle_index in 8:
			game_root._animate_world(0.5)
		var settled_position := backdrop.position
		game_root._animate_world(0.8)
		_assert_true(backdrop.position != settled_position, "phone-down backdrop should keep walking sway after fade-in without road tiles")

	for asset_path in [
		"res://assets/generated/characters/guide_doll.png",
		"res://assets/generated/characters/protagonist_operator.png",
		"res://assets/generated/characters/npc_late_arrival.png",
		"res://assets/generated/characters/npc_echo_tenant.png",
		"res://assets/generated/characters/npc_archive_witness.png",
		"res://assets/generated/world/phone_down_backdrop.png",
		"res://assets/generated/social/poster_sheet.png",
		"res://assets/generated/audio/pollution_flashback.wav",
	]:
		_assert_true(FileAccess.file_exists(asset_path), "required runtime asset should exist: %s" % asset_path)

	var main_source := FileAccess.get_file_as_string("res://scripts/babel_meme_game.gd")
	for removed_runtime_identifier in [
		"PhoneAppIconShop",
		"ShopAppWindow",
		"func _render_shop_app",
		"func _on_buy_meme_frame_pressed",
		"merchant_frame_vendor.png",
		"func _should_show_meme_bank",
		"func _should_peek_meme_bank",
		"func _ensure_meme_bank_panel",
		"func _update_doll_companion",
		"func _on_confirm_craft_pressed",
		"func _on_token_pressed",
		"func _on_note_token_pressed",
		"func _on_slot_token_dropped",
		"func _on_slot_pressed",
		"func _on_dialogue_blank_pressed",
		"func _on_dialogue_meme_dropped",
		"func _craft_preview_text",
		"func _slot_text",
		"func _on_meme_pressed",
		"func _on_meme_ring_selection_changed",
		'_phone_rig.name = "PhoneRig"',
		'npc_body.name = "NPCPlane"',
		'tile.name = "RoadTile%d"',
	]:
		_assert_true(not main_source.contains(removed_runtime_identifier), "removed adapter corpse should stay absent: %s" % removed_runtime_identifier)


func _test_compact_hud_and_settings(game_root: Node) -> void:
	var rail := _find_node_by_name(game_root, "InternationalHUDRail") as Control
	var reveal_zone := _find_node_by_name(game_root, "HUDRevealZone") as Control
	_assert_true(rail != null and reveal_zone != null, "gameplay should expose the hidden left HUD drawer")
	_assert_true(_find_node_by_name(game_root, "HUDPollutionIcon") is Button, "HUD should expose pollution")
	_assert_true(_find_node_by_name(game_root, "HUDMoneyIcon") is Button, "HUD should expose funds")
	_assert_true(_find_node_by_name(game_root, "HUDSettingsIcon") is Button, "HUD should expose settings")
	_assert_true(_find_node_by_name(game_root, "HUDDayIcon") == null, "day should not remain a global metric")
	_assert_true(_find_node_by_name(game_root, "HUDHeatValue") == null, "heat should not return as a progression metric")
	_assert_true(_find_node_by_name(game_root, "HUDClarityValue") == null, "clarity should not return as a progression metric")
	if rail != null:
		_assert_true(not game_root._is_hud_drawer_expanded(), "left HUD should begin collapsed")
		_assert_true(rail.get_global_rect().end.x <= 1.0, "collapsed HUD should sit outside the viewport")

	var settings := _find_node_by_name(game_root, "SettingsWindow") as Control
	var settings_exit := _find_node_by_name(game_root, "SettingsExitGameButton") as Button
	var volume_slider := _find_node_by_name(game_root, "SettingsVolumeSlider") as HSlider
	_assert_true(settings != null and settings_exit != null and settings.is_ancestor_of(settings_exit), "exit should live inside settings")
	_assert_true(_find_node_by_name(rail, "ExitGameButton") == null, "HUD drawer should not expose a separate exit command")
	_assert_true(settings_exit != null and settings_exit.text == "退出游戏", "exit label should remain exact")
	_assert_true(volume_slider != null and volume_slider.editable, "volume must always remain adjustable")

	game_root._request_quit_game()
	var exit_overlay := _find_node_by_name(game_root, "ExitConfirmationOverlay") as Control
	var exit_message := _find_node_by_name(game_root, "ExitConfirmationMessage") as Label
	var exit_confirm := _find_node_by_name(game_root, "ExitConfirmationConfirmButton") as Button
	_assert_true(exit_overlay != null and exit_overlay.visible, "first exit request should show one confirmation")
	_assert_true(exit_message != null and exit_message.text == "真的要抛弃我吗？", "exit confirmation should use the requested sentence")
	_assert_true(exit_confirm != null and exit_confirm.text == "仍然退出", "final exit command should remain uncorrupted")
	game_root._cancel_quit_game()


func _test_phone_apps(game_root: Node) -> void:
	_assert_true(_find_node_by_name(game_root, "PhoneAppIconBabel") is Button, "phone should expose the tower archive")
	_assert_true(_find_node_by_name(game_root, "PhoneAppIconSocial") is Button, "phone should expose social media")
	_assert_true(_find_node_by_name(game_root, "PhoneAppIconNotebook") is Button, "phone should expose the notebook")
	_assert_true(_find_node_by_name(game_root, "PhoneAppIconShop") == null, "phone should not expose the removed shop")
	_assert_true(_find_node_by_name(game_root, "BabelAppWindow") is Control, "tower app should own a separate window")
	_assert_true(_find_node_by_name(game_root, "SocialAppWindow") is Control, "social app should own a separate window")
	_assert_true(_find_node_by_name(game_root, "NotebookAppWindow") is Control, "notebook app should own a separate window")
	_assert_true(_find_node_by_name(game_root, "ShopAppWindow") == null, "removed shop window should not be constructed")
	_assert_true(_find_node_by_name(game_root, "NotebookSentenceHeader") is Control, "notebook should explain complete sentence composition")
	_assert_true(_find_node_by_name(game_root, "NotebookWordCanvas") != null, "notebook should expose the free word canvas")
	game_root.game.set_active_app("babel")
	game_root._render()
	_assert_true(_find_node_by_name(game_root, "BabelFloorHeading") is Label, "tower app should show the floor heading")
	_assert_true(_find_node_by_name(game_root, "BabelFloorDangerLabel") is Label, "tower app should show the danger card line")
	_assert_true(_find_node_by_name(game_root, "BabelFloorHintLabel") is Label, "tower app should show the hint card line")
	_assert_true(_find_node_by_name(game_root, "NotebookSentenceSlotSubject") == null, "the retired subject/verb/object slots must not come back")
	_assert_true(_find_node_by_name(game_root, "NotebookTokenFlow") == null, "the retired long-token word bank must not come back")
	game_root._set_social_screen("publish")
	game_root._render()
	_assert_true(_find_node_by_name(game_root, "ComposerAnswerPanel") != null, "the publish page should host the sentence area")
	_assert_true(_find_node_by_name(game_root, "SocialPublishPostButton") is Button, "the publish page should expose one post command")
	_assert_true(_find_node_by_name(game_root, "SocialPublishUnitCounter") != null, "the publish page should show a unit counter")
	game_root._set_social_screen("home")


func _test_social_feed(game_root: Node) -> void:
	game_root.set_view_state("phone_down")
	game_root._on_app_pressed("social")
	var social_window := _find_node_by_name(game_root, "SocialAppWindow") as Control
	var feed := _find_node_by_name(game_root, "SocialFeedMasonry") as HBoxContainer
	var column_left := _find_node_by_name(game_root, "SocialMasonryColumn0") as VBoxContainer
	var column_right := _find_node_by_name(game_root, "SocialMasonryColumn1") as VBoxContainer
	_assert_true(social_window != null and social_window.visible, "social app should open in phone view")
	_assert_true(_find_node_by_name(game_root, "SocialSearchBar") == null, "social home should not restore the removed search bar")
	_assert_true(_find_node_by_name(game_root, "SocialRefreshButton") == null, "social home should scroll instead of refreshing")
	_assert_true(feed != null and column_left != null and column_right != null, "social home should render a two-column feed")
	if column_left != null and column_right != null:
		_assert_true(absf(column_left.size.x - column_right.size.x) <= 1.0, "masonry columns should use equal widths")
	_assert_true(_find_node_by_name(game_root, "SocialPostCard0") is Control, "feed should contain image-led cards")
	_assert_true(_find_node_by_name(game_root, "SocialPostTexture0") is TextureRect, "feed cards should render generated poster art")
	game_root._open_social_post(0)
	_assert_true(_find_node_by_name(game_root, "SocialPostDetailPage") is VBoxContainer, "opening a feed card should reveal its detail page")


func _test_physical_doll_entry(game_root: Node) -> void:
	game_root.set_view_state("npc_up")
	var doll := _find_actor_by_type(game_root, "doll")
	var merchant := _find_actor_by_type(game_root, "merchant")
	_assert_true(doll != null, "each ordinary floor should contain a physical stitched doll")
	_assert_true(merchant == null, "physical world should not recreate the merchant")
	if doll == null:
		return
	var billboard := doll.get_node_or_null("Billboard") as Sprite3D
	_assert_true(billboard != null and billboard.texture != null, "doll should use the user-authored guide image")
	_assert_true(bool(doll.get_meta("guide_character", false)), "doll actor should carry the permanent guide role")
	game_root._reality_player.position = doll.position + Vector3(0.0, 0.0, 1.35)
	game_root._refresh_nearby_reality_actor()
	_assert_true(game_root._try_reality_interaction(), "approaching the doll should start its authored encounter")
	_assert_eq(game_root.game.conversation_actor_type, "doll", "doll should use its own conversation type")
	_assert_eq(game_root.game.get_typed_reality_choices().size(), 3, "doll encounter should offer three authored intentions")
	game_root._exit_reality_interaction()


func _test_language_and_playtest_contract(game_root: Node) -> void:
	# 医生复述机制已退役:世界里不再生成医生,拼句面板也不该再被触发。
	var doctor := _find_actor_by_type(game_root, "doctor")
	_assert_true(doctor == null, "the retired doctor actor must not spawn any more")
	var assist_panel := _find_node_by_name(game_root, "PlaytestAssistPanel") as Control
	var assist_label := _find_node_by_name(game_root, "PlaytestAssistLabel") as Label
	_assert_true(assist_panel != null and assist_label != null, "debug builds should expose the explicit playtest route panel")
	if assist_label != null:
		_assert_true(assist_label.text.contains("测试提示"), "playtest panel should state the current tutorial action plainly")
	var guide := _find_actor_by_type(game_root, "doll")
	var key_npc := _find_actor_by_type(game_root, "key_npc")
	_assert_true(guide != null and guide.get_node_or_null("PlaytestMarker") is Label3D, "guide should have a debug-only world marker")
	_assert_true(key_npc != null and key_npc.get_node_or_null("PlaytestMarker") is Label3D, "key NPC should have a debug-only world marker")
	if guide != null:
		var marker := guide.get_node_or_null("PlaytestMarker") as Label3D
		_assert_true(marker != null and marker.font_size <= 16, "playtest labels should remain compact enough to reveal the world and actor")


func _find_actor_by_type(game_root: Node, actor_type: String) -> Area3D:
	if game_root._reality_floor == null:
		return null
	for actor in game_root._reality_floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == actor_type:
			return actor
	return null


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node == null:
		return null
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


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _finish() -> void:
	if _failures.is_empty():
		print("main scene tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)
