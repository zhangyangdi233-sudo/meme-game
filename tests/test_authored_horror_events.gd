extends SceneTree

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")

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
		print("authored horror event tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	var floor_root := RealityFloorGeneratorScript.new()
	root.add_child(floor_root)
	var floor_two_day_one := _composed(2, 1)
	floor_root.rebuild(
		2,
		TEST_PALETTE,
		{},
		1,
		false,
		floor_two_day_one.get("items", []),
		floor_two_day_one.get("people", []),
		floor_two_day_one.get("display_names", {}),
		floor_two_day_one.get("events", [])
	)
	_assert_eq(int(floor_root.get_meta("authored_event_count", -1)), 2, "floor two should instantiate its two scheduled events")
	_assert_true(not bool(floor_root.get_meta("authored_event_randomized", true)), "authored events should not depend on random timers")
	_assert_eq(str(floor_root.get_meta("authored_event_trigger_mode", "")), "movement_then_observation_then_look_away", "event metadata should expose the slow-burn trigger grammar")
	_assert_eq(int(floor_root.get_meta("jump_scare_trigger_count", -1)), 0, "authored events must not add jump-scare trigger volumes")
	var event_nodes: Array[Node] = []
	_collect_nodes_with_meta(floor_root, "authored_horror_event", event_nodes)
	var scheduled_event_nodes: Array[Node] = []
	var cover_watcher_nodes: Array[Node] = []
	for event_node in event_nodes:
		if event_node.has_meta("event_kind"):
			scheduled_event_nodes.append(event_node)
		if bool(event_node.get_meta("cover_watcher_event", false)):
			cover_watcher_nodes.append(event_node)
	_assert_eq(scheduled_event_nodes.size(), 2, "scheduled event metadata should match the instantiated daily event roots")
	_assert_eq(cover_watcher_nodes.size(), 1, "the once-per-floor cover watcher should be tracked as a separate authored event")
	_assert_eq(event_nodes.size(), scheduled_event_nodes.size() + cover_watcher_nodes.size(), "all authored horror roots should be classified without hidden duplicates")
	for event_node in event_nodes:
		_assert_true(not (event_node is Area3D), "authored slow-burn events should never be collision trigger areas")
		_assert_true(bool(event_node.get_meta("non_jumpscare", false)), "every authored event should explicitly declare the non-jumpscare rule")

	var start := floor_root.start_position()
	var moved := start + Vector3(5.0, 0.0, 0.0)
	var light_event := _find_node_by_name(floor_root, "LightMemoryEvent") as Node3D
	var memory_light := _find_node_by_name(floor_root, "MemoryLightSource") as OmniLight3D
	_assert_true(light_event != null and memory_light != null, "light-memory schedule should build a recognizable hanging light")
	var base_energy := memory_light.light_energy if memory_light != null else 0.0
	floor_root.update_authored_events(0.10, moved, Vector3(0.0, 0.0, -1.0))
	var light_state: Dictionary = floor_root.get_authored_event_state("light_memory")
	_assert_true(bool(light_state.get("triggered", false)), "walking away from the spawn should trigger the light memory")
	if memory_light != null:
		_assert_true(memory_light.light_energy < base_energy * 0.2, "the first authored light beat should drop sharply without randomness")
	floor_root.update_authored_events(1.0, moved, Vector3(0.0, 0.0, -1.0))
	light_state = floor_root.get_authored_event_state("light_memory")
	_assert_true(bool(light_state.get("settled", false)), "the light sequence should settle instead of flickering forever")
	if light_event != null:
		_assert_eq(str(light_event.get_meta("event_phase", "")), "afterimage", "settled light should retain a dim afterimage phase")

	moved = start + Vector3(8.0, 0.0, 0.0)
	var sign_event := _find_node_by_name(floor_root, "DeadSignEvent") as Node3D
	var sign_label := _find_node_by_name(floor_root, "DeadSignLabel") as Label3D
	_assert_true(sign_event != null and sign_label != null, "dead-sign schedule should build an EXIT sign")
	if sign_event != null:
		var toward_sign := (sign_event.global_position + Vector3.UP * 2.1 - moved).normalized()
		floor_root.update_authored_events(0.1, moved, toward_sign)
		var sign_state: Dictionary = floor_root.get_authored_event_state("dead_sign")
		_assert_true(bool(sign_state.get("observed", false)), "the sign should remember that the player noticed it")
		floor_root.update_authored_events(0.1, moved, -toward_sign)
		sign_state = floor_root.get_authored_event_state("dead_sign")
		_assert_true(bool(sign_state.get("failed", false)), "the sign should lose a letter only after the player looks away")
		if sign_label != null:
			_assert_eq(sign_label.text, "EX_T", "the failed EXIT sign should retain a restrained one-letter absence")

	var resident := floor_root.get_interactable_actors()[0]
	var street := floor_root.get_node_or_null("RealityWorldEnvironment")
	var watcher := _find_node_by_name(floor_root, "CoverWatcherEvent")
	var prerequisite := _find_node_by_name(floor_root, "PrerequisiteItemFloor2")
	floor_root.configure_authored_events(2, TEST_PALETTE, _composed(2, 2).get("events", []))
	_assert_true(resident == floor_root.get_interactable_actors()[0], "a day change should leave the resident in place")
	_assert_true(prerequisite != null and prerequisite == _find_node_by_name(floor_root, "PrerequisiteItemFloor2"), "a day change should leave the prerequisite item in place")
	_assert_true(street != null and street == floor_root.get_node_or_null("RealityWorldEnvironment"), "a day change should leave the street in place")
	_assert_true(watcher != null and watcher == _find_node_by_name(floor_root, "CoverWatcherEvent"), "a day change should leave the cover watcher in place")
	_assert_eq(floor_root.get_meta("authored_event_kinds", PackedStringArray()), PackedStringArray(["light_memory"]), "floor two day two should retain only the finite light event")
	_assert_eq(int(floor_root.get_meta("authored_event_count", -1)), 1, "a single-event day should instantiate exactly one event root")
	_assert_true(_find_node_by_name(floor_root, "DeadSignEvent") == null, "an unscheduled sign should not remain in the scene tree")

	var floor_three_day_one := _composed(3, 1)
	floor_root.rebuild(
		3,
		TEST_PALETTE,
		{},
		1,
		false,
		floor_three_day_one.get("items", []),
		floor_three_day_one.get("people", []),
		floor_three_day_one.get("display_names", {}),
		floor_three_day_one.get("events", [])
	)
	_assert_eq(floor_root.get_meta("authored_event_kinds", PackedStringArray()), PackedStringArray(["dead_sign"]), "floor three day one should use only the sign event")
	_assert_eq(int(floor_root.get_meta("authored_event_count", -1)), 1, "floor three day one should remain deliberately sparse")
	_assert_true(_find_node_by_name(floor_root, "LightMemoryEvent") == null, "rebuilding the floor should remove events that are no longer scheduled")

	floor_root.configure_authored_events(4, TEST_PALETTE, _composed(3, 4).get("events", []))
	var mirage_event := _find_node_by_name(floor_root, "DistantMirageEvent") as Node3D
	var mirage_sprite := _find_node_by_name(floor_root, "MiragePrimary") as Sprite3D
	_assert_true(mirage_event != null and mirage_sprite != null, "the rare sighting should use an image billboard instead of block-model geometry")
	_assert_true(mirage_event != null and not (mirage_event is Area3D), "the image mirage must not create a collision trigger")
	if mirage_event != null:
		start = floor_root.start_position()
		moved = start + Vector3(9.0, 0.0, 0.0)
		floor_root.update_authored_events(0.1, moved, Vector3(0.0, 0.0, -1.0))
		var mirage_state: Dictionary = floor_root.get_authored_event_state("distant_mirage")
		_assert_true(mirage_event.visible and bool(mirage_state.get("triggered", false)), "walking into the district should reveal the distant mirage")
		floor_root.update_authored_events(0.1, mirage_event.global_position + Vector3(0.0, 0.0, 5.5), Vector3(0.0, 0.0, -1.0))
		mirage_state = floor_root.get_authored_event_state("distant_mirage")
		_assert_true(not mirage_event.visible and bool(mirage_state.get("dissolved", false)), "approaching the image should dissolve it without a jump scare")

	floor_root.queue_free()
	await process_frame


func _composed(floor_number: int, day_number: int) -> Dictionary:
	return FloorComposerScript.compose({"day_progress": {"tower_floor": floor_number, "day": day_number}})


func _collect_nodes_with_meta(node: Node, meta_name: String, output: Array[Node]) -> void:
	if node.has_meta(meta_name):
		output.append(node)
	for child in node.get_children():
		_collect_nodes_with_meta(child, meta_name, output)


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _assert_eq(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])


func _assert_true(value: bool, message: String) -> void:
	if not value:
		_failures.append(message)
