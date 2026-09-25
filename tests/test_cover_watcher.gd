extends SceneTree

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")

const TEST_PALETTE := {
	"bg": "B7D957",
	"surface": "FFF1C9",
	"text": "10140F",
	"ink": "10140F",
	"accent": "365B2D",
	"muted": "DDEB8A",
	"danger_stripe": "365B2D",
	"flash_text": "9CFF24",
}

var _failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_async")


func _run_async() -> void:
	await _run()
	if _failures.is_empty():
		print("cover watcher tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	for floor_number in range(1, 6):
		floor_root.rebuild(floor_number, TEST_PALETTE, {}, 1, false, [], [], {}, _unseen_watcher_events())
		var event_root := _find_node_by_name(floor_root, "CoverWatcherEvent") as Node3D
		var sprite := _find_node_by_name(floor_root, "CoverWatcherSprite") as Sprite3D
		var cover := _find_node_by_name(floor_root, "WatcherCover") as StaticBody3D
		_assert_true(event_root != null and sprite != null and cover != null, "every floor should build one watcher behind physical cover")
		_assert_eq(int(floor_root.get_meta("cover_watcher_event_count", -1)), 1, "every unseen floor should contain exactly one cover watcher")
		if event_root != null:
			_assert_true(not (event_root is Area3D), "the watcher should not use a collision jump-scare volume")
			_assert_true(bool(event_root.get_meta("half_body_peek", false)), "watcher metadata should expose the half-body peek composition")
			var distance_from_spawn := event_root.global_position.distance_to(floor_root.start_position())
			_assert_true(distance_from_spawn >= 10.0 and distance_from_spawn <= 24.0, "the watcher should remain nearby without spawning in the player's face")
		if sprite != null:
			_assert_true(not sprite.visible, "the watcher should begin fully hidden behind its cover")
			_assert_eq(sprite.billboard, BaseMaterial3D.BILLBOARD_ENABLED, "the watcher image should always face the camera")
			_assert_true(not sprite.shaded, "floor lighting must not recolor the watcher image")
			_assert_true(sprite.texture is AtlasTexture, "the watcher should crop transparent source padding before composing the side peek")
			_assert_true(bool(sprite.get_meta("transparent_canvas_cropped", false)), "the watcher should expose its cropped-canvas contract")
			if sprite.texture is AtlasTexture:
				var crop := sprite.texture as AtlasTexture
				_assert_eq(crop.region, Rect2(300.0, 150.0, 424.0, 1220.0), "the watcher crop should retain the complete figure without the wide empty canvas")
				_assert_true(crop.atlas != null and crop.region.size.x < float(crop.atlas.get_width()) * 0.5, "cropping should remove enough empty width for a readable half-body peek")
				var collision := cover.get_node_or_null("Collision") as CollisionShape3D
				if collision != null and collision.shape is BoxShape3D:
					var cover_half_width := (collision.shape as BoxShape3D).size.x * 0.5
					var sprite_world_width := crop.region.size.x * sprite.pixel_size
					var visible_width := maxf(0.0, absf(sprite.position.x) + sprite_world_width * 0.5 - cover_half_width)
					var visible_fraction := visible_width / maxf(0.001, sprite_world_width)
					_assert_true(visible_fraction >= 0.40 and visible_fraction <= 0.60, "cover geometry should occlude roughly half of the cropped watcher (got %.3f)" % visible_fraction)

	var appeared_floors: Array[int] = []
	var vanished_floors: Array[int] = []
	floor_root.cover_watcher_appeared.connect(func(floor_number: int) -> void: appeared_floors.append(floor_number))
	floor_root.cover_watcher_vanished.connect(func(floor_number: int) -> void: vanished_floors.append(floor_number))
	floor_root.rebuild(3, TEST_PALETTE, {}, 1, false, [], [], {}, _unseen_watcher_events())
	var event_root := _find_node_by_name(floor_root, "CoverWatcherEvent") as Node3D
	var sprite := _find_node_by_name(floor_root, "CoverWatcherSprite") as Sprite3D
	var spawn := floor_root.start_position()
	var toward_watcher := (event_root.global_position - spawn).normalized() if event_root != null else Vector3(0.0, 0.0, -1.0)
	var fast_position := spawn + Vector3(1.0, 0.0, 0.0)
	var fast_toward_watcher := (event_root.global_position - fast_position).normalized() if event_root != null else toward_watcher
	floor_root.update_authored_events(0.10, fast_position, fast_toward_watcher)
	_assert_true(sprite != null and not sprite.visible, "moving beyond the old travel shortcut must not bypass the authored appearance delay")
	_assert_true(appeared_floors.is_empty(), "the appearance signal must remain silent during a fast move inside the delay window")
	floor_root.update_authored_events(0.25, spawn, toward_watcher)
	_assert_true(sprite != null and not sprite.visible, "the first short pause should preserve the empty cover")
	floor_root.update_authored_events(0.40, spawn, -toward_watcher)
	_assert_true(sprite != null and not sprite.visible, "elapsed time alone must not consume the sighting while the player looks away")
	floor_root.update_authored_events(0.01, spawn, toward_watcher)
	var watcher_state := floor_root.get_cover_watcher_state()
	_assert_true(sprite != null and sprite.visible and bool(watcher_state.get("triggered", false)), "the watcher should quietly reveal itself once delay and actual observation both hold")
	_assert_true(bool(watcher_state.get("observed_in_view", false)), "the appearance signal should certify that the watcher entered the player's view")
	_assert_eq(appeared_floors, [3], "the appearance signal should fire once for the current floor")
	if event_root != null and sprite != null:
		var initial_x := absf(sprite.position.x)
		var near_position := event_root.global_position + Vector3(0.0, 0.0, 5.7)
		floor_root.update_authored_events(0.08, near_position, Vector3(0.0, 0.0, -1.0))
		watcher_state = floor_root.get_cover_watcher_state()
		_assert_true(bool(watcher_state.get("retreating", false)), "approaching the watcher should begin its retreat behind cover")
		floor_root.update_authored_events(0.36, near_position, Vector3(0.0, 0.0, -1.0))
		_assert_true(absf(sprite.position.x) < initial_x, "the retreat should move the separate image layer behind the cover")
		floor_root.update_authored_events(0.40, near_position, Vector3(0.0, 0.0, -1.0))
		watcher_state = floor_root.get_cover_watcher_state()
		_assert_true(not sprite.visible and bool(watcher_state.get("vanished", false)), "the watcher should disappear after completing the retreat")
		_assert_eq(vanished_floors, [3], "the disappearance signal should fire exactly once")
		floor_root.update_authored_events(1.0, near_position, Vector3(0.0, 0.0, -1.0))
		_assert_eq(appeared_floors.size(), 1, "a vanished watcher must not reappear on the same floor")

	floor_root.rebuild(3, TEST_PALETTE, {}, 2, false)
	_assert_true(_find_node_by_name(floor_root, "CoverWatcherEvent") == null, "a floor with no cover watcher entry should not place the figure")
	_assert_eq(int(floor_root.get_meta("cover_watcher_event_count", -1)), 0, "suppressed watcher state should be visible to scene tests")
	floor_root.rebuild(3, TEST_PALETTE, {}, 1, false, [], [], {}, _unseen_watcher_events())
	event_root = _find_node_by_name(floor_root, "CoverWatcherEvent") as Node3D
	sprite = _find_node_by_name(floor_root, "CoverWatcherSprite") as Sprite3D
	spawn = floor_root.start_position()
	toward_watcher = (event_root.global_position - spawn).normalized() if event_root != null else Vector3(0.0, 0.0, -1.0)
	floor_root.update_authored_events(0.80, spawn, toward_watcher)
	var watcher_before_day := floor_root.get_cover_watcher_state()
	var replayed_floors: Array[int] = []
	floor_root.cover_watcher_appeared.connect(func(floor_number: int) -> void: replayed_floors.append(floor_number))
	floor_root.configure_authored_events(2, TEST_PALETTE, [
		{"id": "light_memory", "kind": "light_memory"},
		{"id": "cover_watcher", "kind": "cover_watcher"},
	])
	_assert_true(event_root != null and event_root == _find_node_by_name(floor_root, "CoverWatcherEvent"), "a day change should leave the cover watcher in place")
	_assert_true(sprite != null and sprite.visible, "a day change should not hide a watcher that has already appeared")
	_assert_eq(floor_root.get_cover_watcher_state().get("triggered", false), watcher_before_day.get("triggered", false), "a day change should not replay the cover watcher")
	_assert_true(replayed_floors.is_empty(), "a day change should not emit cover watcher appearance again")
	floor_root.configure_authored_events(3, TEST_PALETTE, [{"id": "dead_sign", "kind": "dead_sign"}])
	_assert_true(event_root == _find_node_by_name(floor_root, "CoverWatcherEvent"), "dropping the entry from a day list should not tear the watcher down")

	var game := MemeGameStateScript.new()
	game.new_run()
	_assert_true(game.mark_cover_watcher_seen(2), "the first sighting should be recorded")
	_assert_true(not game.mark_cover_watcher_seen(2), "the same floor should not record a second sighting")
	_assert_true(game.has_seen_cover_watcher(2) and not game.has_seen_cover_watcher(3), "watcher persistence should remain floor-specific")
	var restored := MemeGameStateScript.new()
	_assert_true(restored.load_save_data(game.to_save_data()), "watcher floor history should survive save restoration")
	_assert_eq(restored.cover_watcher_seen_floors, [2], "save restoration should preserve one unique watcher floor")

	floor_root.queue_free()
	await process_frame


func _unseen_watcher_events() -> Array:
	return [{"id": "cover_watcher", "kind": "cover_watcher"}]


func _find_node_by_name(node: Node, target_name: String) -> Node:
	if node.name == target_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, target_name)
		if found != null:
			return found
	return null


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
