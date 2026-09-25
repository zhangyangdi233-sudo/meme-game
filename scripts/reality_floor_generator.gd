extends Node3D

class_name RealityFloorGenerator

signal cover_watcher_appeared(floor_number: int)
signal cover_watcher_vanished(floor_number: int)

const NPC_FACE_SCRIBBLE_OVERLAY_SHADER := preload("res://shaders/npc_face_scribble_overlay.gdshader")
const NPC_FACE_SCRIBBLE_ATLAS := preload("res://assets/generated/effects/face_scribble_atlas.png")
const DISTANT_MIRAGE_TEXTURE_PATH := "res://assets/generated/world/events/distant_mirage.png"
const COVER_WATCHER_TEXTURE_PATH := "res://assets/generated/world/events/distant_mirage.png"
const COVER_WATCHER_APPEAR_DELAY := 0.72
const COVER_WATCHER_APPROACH_DISTANCE := 6.4
const COVER_WATCHER_RETREAT_DURATION := 0.72
const COVER_WATCHER_SOURCE_CROP := Rect2(300.0, 150.0, 424.0, 1220.0)
const COVER_WATCHER_PIXEL_SIZE := 0.00155
const ACTOR_PORTRAIT_WORLD_HEIGHT := 1.90
const ACTOR_CAMERA_EYE_HEIGHT := 1.56
const DOLL_PORTRAIT_WORLD_HEIGHT := 0.96

const BASE_ROOM_COUNT := 4
const WORLD_LENGTH_SCALE := 5.0
const LOT_SPACING := 9.4 * WORLD_LENGTH_SCALE
const LOT_WIDTH := 7.4
const LOT_DEPTH := 6.8
const STREET_WIDTH := 14.0
const SUNLIT_CROSSROAD_OPENING := STREET_WIDTH + 2.0
const SUNLIT_CROSSROAD_ARM_LENGTH := 43.2
const SUNLIT_DREAMCORE_BAY := 4.8
const SUNLIT_EDGE_WALL_HEIGHT := 5.9
const SUNLIT_EDGE_WALL_THICKNESS := 0.68
const MIN_MAP_WIDTH := 34.0
const MIN_MAP_LENGTH := 46.0 * WORLD_LENGTH_SCALE
const MAP_END_MARGIN := 12.0 * WORLD_LENGTH_SCALE
const WALL_HEIGHT := 3.4
const AIR_WALL_HEIGHT := 6.0
const AIR_WALL_THICKNESS := 0.5
const ORDINARY_NPC_COUNTS := [4, 3, 2, 0]
const NIGHT_TERRACE_END_MARGIN := 8.0
const NIGHT_TERRACE_GAP := 1.2
const NIGHT_FACADE_BAY := 7.6
const FLOOR_TWO_DISC_SEGMENTS := 96
const FLOOR_TWO_DISC_RADIAL_SEGMENTS := 24
const FLOOR_TWO_DISC_RADIUS_X := 112.0
const FLOOR_TWO_DISC_RADIUS_Z := 118.0
const FLOOR_TWO_DISC_IRREGULARITY := 10.0
const FLOOR_TWO_DISC_MAP_MARGIN := 4.0
const FLOOR_TWO_DISC_AIR_WALL_SEGMENTS := 32
const FLOOR_TWO_PHYSICAL_HOUSE_COUNT := 9
const FLOOR_TWO_HILL_MOUNDS := [
	# x, z, radius, height. Wide smooth domes remain comfortably walkable.
	Vector4(-72.0, -62.0, 24.0, 2.4),
	Vector4(-30.0, -72.0, 23.0, 2.8),
	Vector4(18.0, -68.0, 25.0, 2.6),
	Vector4(65.0, -54.0, 24.0, 3.0),
	Vector4(-76.0, -20.0, 25.0, 3.0),
	Vector4(-28.0, -24.0, 29.0, 3.5),
	Vector4(25.0, -18.0, 25.0, 2.8),
	Vector4(72.0, -2.0, 23.0, 2.5),
	Vector4(-66.0, 34.0, 24.0, 2.6),
	Vector4(-18.0, 44.0, 29.0, 3.3),
	Vector4(34.0, 48.0, 26.0, 2.9),
	Vector4(72.0, 56.0, 22.0, 2.4),
	Vector4(8.0, 78.0, 21.0, 2.2),
]
const GALLERY_END_MARGIN := 7.0
const GALLERY_COLUMN_TARGET_SPACING := 7.2
const GALLERY_COLUMN_X := 3.2
const GALLERY_SKYLIGHT_COUNT := 4
const GALLERY_SKYLIGHT_LENGTH := 12.0
const FULL_MAP_GRASS_SPACING := 0.44
const FULL_MAP_GRASS_BLADE_HEIGHT := 0.32
const FULL_MAP_GRASS_BLADE_WIDTH := 0.24
const SUSPENSE_CLEAR_PATH_WIDTH := 5.6
const DISTANT_MIRAGE_DAYS := [4, 9]
const AUTHORED_EVENT_TABLE := {
	2: [
		["light_memory", "dead_sign"],
		["light_memory"],
		["dead_sign"],
	],
	3: [
		["dead_sign"],
		["light_memory", "dead_sign"],
		["light_memory"],
	],
	4: [
		["light_memory"],
		["dead_sign"],
		["light_memory", "dead_sign"],
	],
}
const DISTRICT_STYLES := ["sunlit_brick_street", "night_white_blocks", "overgrown_gallery"]
const DISTRICT_REFERENCE_TEXTURES := {
	"sunlit_brick_street": "res://assets/generated/world/reference_districts/sunlit_brick_street.png",
	"night_white_blocks": "res://assets/generated/world/reference_districts/night_white_blocks.png",
	"overgrown_gallery": "res://assets/generated/world/reference_districts/overgrown_gallery.png",
}
const MOOD_TEXTURE_PATHS := [
	"res://assets/generated/1/IMG_4485.PNG",
	"res://assets/generated/1/IMG_4744.PNG",
	"res://assets/generated/1/IMG_4750.PNG",
	"res://assets/generated/1/IMG_4835.PNG",
	"res://assets/generated/1/IMG_4834.PNG",
	"res://assets/generated/1/IMG_4711.PNG",
	"res://assets/generated/1/IMG_4461.PNG",
	"res://assets/generated/1/IMG_4460.PNG",
]

var built_floor: int = 0
var room_count: int = 0
var ordinary_npc_count: int = 0
var useful_item_count: int = 0
var map_width: float = MIN_MAP_WIDTH
var map_length: float = MIN_MAP_LENGTH
var district_style := DISTRICT_STYLES[0]
var _actors: Array[Area3D] = []
var _items: Array[Area3D] = []
var _environment: WorldEnvironment
var _authored_event_root: Node3D
var _authored_event_nodes: Dictionary = {}
var _authored_event_states: Dictionary = {}
var _authored_event_origin := Vector3.ZERO
var _authored_event_day := 1
var _cover_watcher_root: Node3D
var _cover_watcher_sprite: Sprite3D
var _cover_watcher_state: Dictionary = {}
var _playtest_assist_enabled := false


static func room_count_for_floor(floor_number: int) -> int:
	var normalized := maxi(1, floor_number) - 1
	return BASE_ROOM_COUNT + normalized * 2 + int(normalized / 2)


static func npc_count_for_floor(floor_number: int) -> int:
	var floor_index := clampi(maxi(1, floor_number), 1, ORDINARY_NPC_COUNTS.size()) - 1
	return int(ORDINARY_NPC_COUNTS[floor_index])


static func district_style_for_floor(floor_number: int) -> String:
	return DISTRICT_STYLES[posmod(maxi(1, floor_number) - 1, DISTRICT_STYLES.size())]


static func authored_event_kinds_for_floor_day(floor_number: int, day_number: int) -> PackedStringArray:
	var floor_schedules: Array = AUTHORED_EVENT_TABLE.get(clampi(floor_number, 1, 4), [])
	if floor_schedules.is_empty():
		return PackedStringArray()
	var normalized_day := maxi(1, day_number)
	var selected_schedule: Array = floor_schedules[posmod(normalized_day - 1, floor_schedules.size())]
	var event_kinds := PackedStringArray(selected_schedule)
	if floor_number >= 2 and normalized_day in DISTANT_MIRAGE_DAYS:
		event_kinds.append("distant_mirage")
	return event_kinds


func rebuild(
	floor_number: int,
	palette: Dictionary,
	actor_textures: Dictionary,
	day_number: int = 1,
	cover_watcher_seen: bool = false,
	items: Array = [],
	people: Array = [],
	display_names: Dictionary = {}
) -> void:
	_clear_floor()
	built_floor = clampi(floor_number, 1, 4)
	district_style = district_style_for_floor(built_floor)
	room_count = room_count_for_floor(built_floor)
	ordinary_npc_count = _count_kind(people, "npc")
	useful_item_count = 0
	var lot_rows := int(ceil(float(room_count) / 2.0))
	if built_floor == 2:
		map_width = (FLOOR_TWO_DISC_RADIUS_X + FLOOR_TWO_DISC_IRREGULARITY + FLOOR_TWO_DISC_MAP_MARGIN) * 2.0
		map_length = (FLOOR_TWO_DISC_RADIUS_Z + FLOOR_TWO_DISC_IRREGULARITY + FLOOR_TWO_DISC_MAP_MARGIN) * 2.0
	else:
		map_width = MIN_MAP_WIDTH + float(built_floor - 1) * 1.5
		map_length = maxf(MIN_MAP_LENGTH, float(lot_rows) * LOT_SPACING + MAP_END_MARGIN * 2.0)
	set_meta("built_floor", built_floor)
	set_meta("room_count", room_count)
	set_meta("logical_room_count", room_count)
	set_meta("ordinary_npc_count", ordinary_npc_count)
	set_meta("doll_encounter_count", 0)
	set_meta("layout_mode", "irregular_disc" if built_floor == 2 else ("skylit_overgrown_gallery" if built_floor == 3 else "shared_street"))
	set_meta("map_width", map_width)
	set_meta("map_length", map_length)
	set_meta("world_length_scale", WORLD_LENGTH_SCALE)
	set_meta("air_wall_count", 12 if district_style == "sunlit_brick_street" else (FLOOR_TWO_DISC_AIR_WALL_SEGMENTS if built_floor == 2 else 4))
	set_meta("district_style", district_style)
	set_meta("npc_population_rule", "strictly_descending")
	set_meta("atmosphere_mode", "open_daylight" if built_floor == 1 else "slow_burn_suspense")
	set_meta("suspense_occluder_count", 0)
	set_meta("suspense_light_count", 0)
	set_meta("controlled_repeat_count", 0)
	set_meta("jump_scare_trigger_count", 0)
	set_meta("minimum_clear_path_width", STREET_WIDTH)
	set_meta("suspense_occlusion_rule", "none")
	set_meta("night_house_segment_count", 0)
	set_meta("night_house_coverage_ratio", 0.0)
	set_meta("night_house_footprint_area", 0.0)
	set_meta("night_disc_planar_area", 0.0)
	set_meta("night_house_coverage_method", "none")
	set_meta("night_house_max_gap", 0.0)
	set_meta("night_facade_bay_count", 0)
	set_meta("gallery_continuous", false)
	set_meta("gallery_span", 0.0)
	set_meta("gallery_span_ratio", 0.0)
	set_meta("gallery_column_count", 0)
	set_meta("gallery_column_spacing", 0.0)
	set_meta("gallery_repeat_anomaly_count", 0)
	set_meta("terrain_profile", "flat_shared_street")
	set_meta("disc_angular_segment_count", 0)
	set_meta("disc_radial_segment_count", 0)
	set_meta("disc_radius_x", 0.0)
	set_meta("disc_radius_z", 0.0)
	set_meta("disc_height_variation", 0.0)
	set_meta("disc_mound_count", 0)
	set_meta("physical_house_count", 0)
	set_meta("physical_house_ratio", 0.0)
	set_meta("grass_render_mode", "none")
	set_meta("grass_coverage", "none")
	set_meta("grass_instance_count", 0)
	set_meta("grass_coverage_ratio", 0.0)
	set_meta("grass_bounds", Vector2.ZERO)
	set_meta("skylight_opening_count", 0)
	set_meta("skylight_open_ratio", 0.0)
	set_meta("dreamcore_object_type_count", 0)
	set_meta("dreamcore_object_count", 0)
	set_meta("dreamcore_object_types", PackedStringArray())
	set_meta("dreamcore_non_pickup_count", 0)
	set_meta("authored_event_count", 0)
	set_meta("authored_event_kinds", PackedStringArray())
	set_meta("authored_event_day", maxi(1, day_number))
	set_meta("authored_event_trigger_mode", "movement_then_observation_then_look_away")
	set_meta("authored_event_randomized", false)
	set_meta("cover_watcher_event_count", 0)
	set_meta("cover_watcher_trigger_mode", "brief_wait_then_retreat_on_approach")
	set_meta("cover_watcher_once_per_floor", true)
	set_meta("lighting_profile", "open_daylight" if built_floor == 1 else "slow_burn_suspense")

	_build_environment(palette)
	_build_architecture(palette)
	_build_prerequisite_items(items, display_names, palette)
	_build_actors(actor_textures, people, display_names)
	_refresh_playtest_markers()
	configure_authored_events(day_number, palette)
	_build_cover_watcher_event(palette, cover_watcher_seen)
	set_meta("useful_item_count", useful_item_count)


func get_interactable_actors() -> Array[Area3D]:
	var live_actors: Array[Area3D] = []
	for actor in _actors:
		if is_instance_valid(actor):
			live_actors.append(actor)
	return live_actors


func get_interactable_items() -> Array[Area3D]:
	var live_items: Array[Area3D] = []
	for item in _items:
		if is_instance_valid(item) and item.visible and not bool(item.get_meta("collected", false)):
			live_items.append(item)
	return live_items


func sync_collected_items(collected_ids: Array[String]) -> void:
	for item in _items:
		if not is_instance_valid(item):
			continue
		var collected := str(item.get_meta("item_id", "")) in collected_ids
		item.set_meta("collected", collected)
		item.visible = not collected
		item.monitoring = not collected
		item.monitorable = not collected


func sync_prerequisite_items(revealed_ids: Array[String], collected_ids: Array[String]) -> void:
	for item in _items:
		if not is_instance_valid(item) or not bool(item.get_meta("prerequisite_item", false)):
			continue
		var item_id := str(item.get_meta("item_id", ""))
		var revealed := item_id in revealed_ids
		var collected := item_id in collected_ids
		item.set_meta("revealed", revealed)
		item.set_meta("collected", collected)
		item.visible = revealed and not collected
		item.monitoring = revealed and not collected
		item.monitorable = revealed and not collected
	_refresh_playtest_markers()


func set_playtest_assist_enabled(value: bool) -> void:
	_playtest_assist_enabled = value
	_refresh_playtest_markers()


func _refresh_playtest_markers() -> void:
	for actor in _actors:
		if not is_instance_valid(actor):
			continue
		var actor_type := str(actor.get_meta("actor_type", "npc"))
		var marker_text := ""
		match actor_type:
			"doll":
				marker_text = "TEST  教程引导"
			"key_npc":
				marker_text = "TEST  隐藏路线关键 NPC"
		var existing_actor_marker := actor.get_node_or_null("PlaytestMarker") as Label3D
		if marker_text.is_empty() or not _playtest_assist_enabled:
			if existing_actor_marker != null:
				existing_actor_marker.visible = false
			continue
		if existing_actor_marker == null:
			existing_actor_marker = _make_playtest_marker(marker_text, 2.55 if actor_type != "doll" else 1.35)
			actor.add_child(existing_actor_marker)
		existing_actor_marker.text = marker_text
		existing_actor_marker.visible = true

	for item in _items:
		if not is_instance_valid(item) or not bool(item.get_meta("prerequisite_item", false)):
			continue
		var existing_item_marker := item.get_node_or_null("PlaytestMarker") as Label3D
		if not _playtest_assist_enabled:
			if existing_item_marker != null:
				existing_item_marker.visible = false
			continue
		if existing_item_marker == null:
			existing_item_marker = _make_playtest_marker("TEST  前置物：%s" % str(item.get_meta("display_name", "未登记物")), 1.75)
			item.add_child(existing_item_marker)
		existing_item_marker.visible = bool(item.get_meta("revealed", false)) and not bool(item.get_meta("collected", false))


func _make_playtest_marker(marker_text: String, height: float) -> Label3D:
	var marker := Label3D.new()
	marker.name = "PlaytestMarker"
	marker.text = marker_text
	marker.position = Vector3(0.0, height, 0.0)
	marker.font_size = 14
	marker.pixel_size = 0.0024
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.fixed_size = true
	marker.modulate = Color("D8FF66")
	marker.outline_modulate = Color("050705")
	marker.outline_size = 3
	marker.no_depth_test = true
	marker.render_priority = 20
	return marker


func sync_claimed_dolls(claimed_ids: Array[String]) -> void:
	for actor in _actors:
		if not is_instance_valid(actor) or str(actor.get_meta("actor_type", "")) != "doll":
			continue
		var doll_id := str(actor.get_meta("actor_id", ""))
		var claimed := doll_id in claimed_ids
		actor.set_meta("claimed", claimed)
		var sprite := actor.get_node_or_null("Billboard") as Sprite3D
		if sprite != null:
			sprite.modulate = Color(0.82, 0.90, 0.82, 1.0) if claimed else Color.WHITE


func configure_authored_events(day_number: int, palette: Dictionary) -> void:
	if _authored_event_root != null and is_instance_valid(_authored_event_root):
		remove_child(_authored_event_root)
		_authored_event_root.free()
	_authored_event_nodes.clear()
	_authored_event_states.clear()
	_authored_event_day = maxi(1, day_number)
	_authored_event_origin = start_position()
	_authored_event_root = Node3D.new()
	_authored_event_root.name = "AuthoredHorrorEvents"
	_authored_event_root.set_meta("authored_event_collection", true)
	_authored_event_root.set_meta("non_jumpscare", true)
	add_child(_authored_event_root)
	var event_kinds := authored_event_kinds_for_floor_day(built_floor, _authored_event_day)
	for event_kind in event_kinds:
		match str(event_kind):
			"light_memory":
				_build_light_memory_event(palette)
			"dead_sign":
				_build_dead_sign_event(palette)
			"distant_mirage":
				_build_distant_mirage_event()
	set_meta("authored_event_count", event_kinds.size())
	set_meta("authored_event_kinds", event_kinds)
	set_meta("authored_event_day", _authored_event_day)
	set_meta("authored_event_day_slot", posmod(_authored_event_day - 1, 3))
	set_meta("authored_event_trigger_mode", "movement_then_observation_then_look_away")
	set_meta("authored_event_randomized", false)


func update_authored_events(delta: float, player_position: Vector3, camera_forward: Vector3) -> void:
	if _authored_event_nodes.is_empty() and _cover_watcher_sprite == null:
		return
	var horizontal_travel := Vector2(player_position.x - _authored_event_origin.x, player_position.z - _authored_event_origin.z).length()
	var safe_forward := camera_forward.normalized() if camera_forward.length_squared() > 0.0001 else Vector3(0.0, 0.0, -1.0)
	for event_kind in _authored_event_nodes.keys():
		match str(event_kind):
			"light_memory":
				_update_light_memory_event(delta, horizontal_travel)
			"dead_sign":
				_update_dead_sign_event(horizontal_travel, player_position, safe_forward)
			"distant_mirage":
				_update_distant_mirage_event(delta, horizontal_travel, player_position)
	_update_cover_watcher_event(delta, player_position, safe_forward)


func get_authored_event_state(event_kind: String) -> Dictionary:
	return (_authored_event_states.get(event_kind, {}) as Dictionary).duplicate(true)


func get_cover_watcher_state() -> Dictionary:
	return _cover_watcher_state.duplicate(true)


func _cover_watcher_position() -> Vector3:
	var origin := start_position()
	var lateral_sign := -1.0 if built_floor in [2, 4] else 1.0
	var target := origin + Vector3(lateral_sign * (4.1 + float(built_floor % 2) * 0.7), 0.08, -15.0 - float(built_floor % 3))
	if built_floor == 2:
		return _clamp_to_floor_two_disc(target, 4.5)
	return clamp_to_playable_position(target, 4.0)


func _build_cover_watcher_event(palette: Dictionary, already_seen: bool) -> void:
	_cover_watcher_root = null
	_cover_watcher_sprite = null
	_cover_watcher_state = {
		"enabled": not already_seen,
		"triggered": false,
		"retreating": false,
		"vanished": already_seen,
		"elapsed": 0.0,
		"retreat_elapsed": 0.0,
	}
	if already_seen:
		return
	var event_root := Node3D.new()
	event_root.name = "CoverWatcherEvent"
	event_root.position = _cover_watcher_position()
	event_root.set_meta("cover_watcher_event", true)
	event_root.set_meta("authored_horror_event", true)
	event_root.set_meta("non_jumpscare", true)
	event_root.set_meta("half_body_peek", true)
	event_root.set_meta("retreat_on_approach", true)
	event_root.set_meta("once_per_floor", true)
	event_root.set_meta("event_phase", "hidden_behind_cover")
	add_child(event_root)
	var cover_role := "brick_dark" if built_floor == 1 else ("white_wall" if built_floor in [2, 3] else "concrete")
	var cover := _add_box(event_root, "WatcherCover", Vector3(1.72, 3.16, 0.72), Vector3(0.0, 1.50, 0.0), cover_role, palette, true)
	cover.set_meta("cover_watcher_occluder", true)
	cover.set_meta("remains_after_watcher", true)
	var cap := _add_box(event_root, "WatcherCoverCap", Vector3(1.92, 0.16, 0.86), Vector3(0.0, 3.04, 0.0), cover_role, palette, false)
	cap.set_meta("cover_watcher_occluder", true)
	var sprite := Sprite3D.new()
	sprite.name = "CoverWatcherSprite"
	var watcher_source := load(COVER_WATCHER_TEXTURE_PATH) as Texture2D
	var watcher_crop := AtlasTexture.new()
	watcher_crop.atlas = watcher_source
	watcher_crop.region = COVER_WATCHER_SOURCE_CROP
	sprite.texture = watcher_crop
	var peek_sign := -1.0 if event_root.position.x >= _authored_event_origin.x else 1.0
	var peek_x := peek_sign * 0.86
	sprite.position = Vector3(peek_x, 1.03, -0.42)
	sprite.pixel_size = COVER_WATCHER_PIXEL_SIZE
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.double_sided = true
	sprite.shaded = false
	sprite.transparent = true
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = Color(0.76, 0.86, 0.58, 0.92)
	sprite.render_priority = 3
	sprite.visible = false
	sprite.set_meta("faceless_watcher", true)
	sprite.set_meta("camera_facing_layer", true)
	sprite.set_meta("side_peek_fraction", 0.50)
	sprite.set_meta("transparent_canvas_cropped", true)
	sprite.set_meta("source_crop", COVER_WATCHER_SOURCE_CROP)
	sprite.set_meta("base_peek_position", sprite.position)
	event_root.add_child(sprite)
	_cover_watcher_root = event_root
	_cover_watcher_sprite = sprite
	_cover_watcher_state["peek_x"] = peek_x
	_cover_watcher_state["hidden_x"] = 0.0
	_cover_watcher_state["approach_distance"] = COVER_WATCHER_APPROACH_DISTANCE
	set_meta("cover_watcher_event_count", 1)


func _update_cover_watcher_event(delta: float, player_position: Vector3, camera_forward: Vector3) -> void:
	if _cover_watcher_root == null or _cover_watcher_sprite == null or bool(_cover_watcher_state.get("vanished", false)):
		return
	var elapsed := float(_cover_watcher_state.get("elapsed", 0.0)) + delta
	_cover_watcher_state["elapsed"] = elapsed
	var planar_forward := Vector3(camera_forward.x, 0.0, camera_forward.z).normalized()
	var to_watcher := _cover_watcher_root.global_position - player_position
	to_watcher.y = 0.0
	var view_dot := planar_forward.dot(to_watcher.normalized()) if planar_forward.length_squared() > 0.0001 and to_watcher.length_squared() > 0.0001 else -1.0
	_cover_watcher_state["view_dot"] = view_dot
	if not bool(_cover_watcher_state.get("triggered", false)):
		if elapsed < COVER_WATCHER_APPEAR_DELAY or view_dot < 0.62:
			return
		_cover_watcher_state["triggered"] = true
		_cover_watcher_state["observed_in_view"] = true
		_cover_watcher_sprite.visible = true
		_cover_watcher_root.set_meta("event_phase", "watching_from_cover")
		cover_watcher_appeared.emit(built_floor)
	var distance := player_position.distance_to(_cover_watcher_root.global_position)
	if not bool(_cover_watcher_state.get("retreating", false)) and distance <= COVER_WATCHER_APPROACH_DISTANCE:
		_cover_watcher_state["retreating"] = true
		_cover_watcher_root.set_meta("event_phase", "retreating_behind_cover")
	if not bool(_cover_watcher_state.get("retreating", false)):
		var base_position: Vector3 = _cover_watcher_sprite.get_meta("base_peek_position", _cover_watcher_sprite.position)
		_cover_watcher_sprite.position = base_position + Vector3(sin(elapsed * 2.7) * 0.012, sin(elapsed * 1.6) * 0.006, 0.0)
		return
	var retreat_elapsed := float(_cover_watcher_state.get("retreat_elapsed", 0.0)) + delta
	_cover_watcher_state["retreat_elapsed"] = retreat_elapsed
	var retreat_ratio := clampf(retreat_elapsed / COVER_WATCHER_RETREAT_DURATION, 0.0, 1.0)
	var eased_ratio := 1.0 - pow(1.0 - retreat_ratio, 5.0)
	_cover_watcher_sprite.position.x = lerpf(float(_cover_watcher_state.get("peek_x", 0.86)), float(_cover_watcher_state.get("hidden_x", 0.0)), eased_ratio)
	var tint := _cover_watcher_sprite.modulate
	tint.a = 0.92 * (1.0 - smoothstep(0.76, 1.0, retreat_ratio))
	_cover_watcher_sprite.modulate = tint
	if retreat_ratio >= 1.0:
		_cover_watcher_sprite.visible = false
		_cover_watcher_state["vanished"] = true
		_cover_watcher_root.set_meta("event_phase", "gone_behind_cover")
		cover_watcher_vanished.emit(built_floor)


func _authored_event_position(event_kind: String) -> Vector3:
	var event_index := ["light_memory", "dead_sign", "distant_mirage"].find(event_kind)
	if built_floor == 2:
		var angles := [PI * 0.5 - 0.11, PI * 0.5 + 0.18, PI * 0.5 - 0.28]
		var radii := [0.65, 0.55, 0.39]
		var disc_position := _floor_two_disc_point(float(angles[event_index]), float(radii[event_index]))
		disc_position.y += 0.08
		return disc_position
	var lateral_positions := [0.0, 4.2, -2.8]
	var forward_distances := [18.0, 29.0, 43.0]
	return Vector3(float(lateral_positions[event_index]), 0.08, _authored_event_origin.z - float(forward_distances[event_index]))


func _orient_event_toward_origin(event_root: Node3D) -> void:
	if built_floor != 2:
		return
	var target := Vector3(_authored_event_origin.x, event_root.position.y, _authored_event_origin.z)
	var direction := target - event_root.position
	if direction.length_squared() < 0.01:
		return
	# Authored events are oriented while their parent floor may still be outside the tree.
	# Their visual front is +Z, so a local yaw avoids querying an invalid global transform.
	event_root.rotation.y = atan2(direction.x, direction.z)


func _register_authored_event(event_kind: String, event_root: Node3D, state: Dictionary) -> void:
	event_root.set_meta("authored_horror_event", true)
	event_root.set_meta("event_kind", event_kind)
	event_root.set_meta("event_day", _authored_event_day)
	event_root.set_meta("non_jumpscare", true)
	event_root.set_meta("deterministic", true)
	_authored_event_nodes[event_kind] = event_root
	_authored_event_states[event_kind] = state


func _build_light_memory_event(palette: Dictionary) -> void:
	var event_root := Node3D.new()
	event_root.name = "LightMemoryEvent"
	event_root.position = _authored_event_position("light_memory")
	_authored_event_root.add_child(event_root)
	_orient_event_toward_origin(event_root)
	_add_box(event_root, "MemoryLightHousing", Vector3(1.68, 0.14, 0.72), Vector3(0.0, 3.02, 0.0), "fixture_metal", palette, false)
	for tube_index in 4:
		_add_box(event_root, "MemoryLightTube%02d" % tube_index, Vector3(1.42, 0.07, 0.09), Vector3(0.0, 2.94, -0.25 + float(tube_index) * 0.17), "fluorescent", palette, false)
	for wire_side in [-1.0, 1.0]:
		var wire := _add_box(event_root, "MemoryLightWire%s" % ("L" if wire_side < 0.0 else "R"), Vector3(0.035, 1.04, 0.035), Vector3(wire_side * 0.56, 3.58, 0.0), "rubber_black", palette, false)
		wire.rotation.z = wire_side * 0.10
	var light := OmniLight3D.new()
	light.name = "MemoryLightSource"
	light.position = Vector3(0.0, 2.72, 0.0)
	light.light_color = Color("D9FFB5") if built_floor >= 3 else Color("91B99A")
	light.light_energy = 1.35 if built_floor == 3 else 0.72
	light.omni_range = 12.0
	light.shadow_enabled = false
	event_root.add_child(light)
	_register_authored_event("light_memory", event_root, {
		"triggered": false,
		"settled": false,
		"elapsed": 0.0,
		"base_energy": light.light_energy,
	})


func _build_dead_sign_event(palette: Dictionary) -> void:
	var event_root := Node3D.new()
	event_root.name = "DeadSignEvent"
	event_root.position = _authored_event_position("dead_sign")
	_authored_event_root.add_child(event_root)
	_orient_event_toward_origin(event_root)
	_add_box(event_root, "DeadSignPostL", Vector3(0.09, 2.12, 0.09), Vector3(-0.72, 1.06, 0.0), "fixture_metal", palette, false)
	_add_box(event_root, "DeadSignPostR", Vector3(0.09, 2.12, 0.09), Vector3(0.72, 1.06, 0.0), "fixture_metal", palette, false)
	_add_box(event_root, "DeadSignHousing", Vector3(1.72, 0.72, 0.16), Vector3(0.0, 2.26, 0.0), "rubber_black", palette, false)
	var label := Label3D.new()
	label.name = "DeadSignLabel"
	label.text = "EXIT"
	label.position = Vector3(0.0, 2.26, 0.10)
	label.font_size = 96
	label.pixel_size = 0.0046
	label.modulate = _role_color("fluorescent", palette)
	label.outline_modulate = Color("071009")
	label.outline_size = 12
	label.no_depth_test = true
	event_root.add_child(label)
	var light := OmniLight3D.new()
	light.name = "DeadSignGlow"
	light.position = Vector3(0.0, 2.18, 0.28)
	light.light_color = _role_color("fluorescent", palette)
	light.light_energy = 0.42
	light.omni_range = 4.0
	light.shadow_enabled = false
	event_root.add_child(light)
	_register_authored_event("dead_sign", event_root, {
		"triggered": false,
		"observed": false,
		"failed": false,
	})


func _build_distant_mirage_event() -> void:
	var event_root := Node3D.new()
	event_root.name = "DistantMirageEvent"
	event_root.position = _authored_event_position("distant_mirage")
	_authored_event_root.add_child(event_root)
	_orient_event_toward_origin(event_root)
	var layer_names := ["MirageEchoLeft", "MiragePrimary", "MirageEchoRight"]
	var layer_offsets := [-0.055, 0.0, 0.055]
	var layer_alphas := [0.10, 0.40, 0.08]
	var mirage_texture := load(DISTANT_MIRAGE_TEXTURE_PATH) as Texture2D
	for layer_index in layer_names.size():
		var sprite := Sprite3D.new()
		sprite.name = str(layer_names[layer_index])
		sprite.texture = mirage_texture
		sprite.position = Vector3(float(layer_offsets[layer_index]), 1.18, float(layer_index - 1) * 0.004)
		sprite.pixel_size = 0.00155
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.double_sided = true
		sprite.shaded = false
		sprite.transparent = true
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		sprite.modulate = Color(0.82, 0.92, 0.64, float(layer_alphas[layer_index]))
		sprite.render_priority = layer_index
		sprite.set_meta("mirage_base_position", sprite.position)
		sprite.set_meta("mirage_base_alpha", float(layer_alphas[layer_index]))
		sprite.set_meta("mirage_phase", float(layer_index) * 1.9)
		event_root.add_child(sprite)
	event_root.visible = false
	_register_authored_event("distant_mirage", event_root, {
		"triggered": false,
		"dissolved": false,
		"elapsed": 0.0,
	})


func _update_light_memory_event(delta: float, horizontal_travel: float) -> void:
	var event_root := _authored_event_nodes.get("light_memory") as Node3D
	if event_root == null:
		return
	var light := event_root.get_node_or_null("MemoryLightSource") as OmniLight3D
	if light == null:
		return
	var state := _authored_event_states.get("light_memory", {}) as Dictionary
	if not bool(state.get("triggered", false)) and horizontal_travel >= 4.5:
		state["triggered"] = true
		event_root.set_meta("event_phase", "flickering")
	if not bool(state.get("triggered", false)) or bool(state.get("settled", false)):
		_authored_event_states["light_memory"] = state
		return
	var elapsed := float(state.get("elapsed", 0.0)) + delta
	state["elapsed"] = elapsed
	var multiplier := 1.0
	if elapsed < 0.14:
		multiplier = 0.08
	elif elapsed < 0.28:
		multiplier = 0.92
	elif elapsed < 0.43:
		multiplier = 0.04
	elif elapsed < 0.62:
		multiplier = 0.68
	elif elapsed < 0.82:
		multiplier = 0.12
	else:
		multiplier = 0.24
		state["settled"] = true
		event_root.set_meta("event_phase", "afterimage")
	light.light_energy = float(state.get("base_energy", 0.72)) * multiplier
	_authored_event_states["light_memory"] = state


func _update_dead_sign_event(horizontal_travel: float, player_position: Vector3, camera_forward: Vector3) -> void:
	var event_root := _authored_event_nodes.get("dead_sign") as Node3D
	if event_root == null:
		return
	var state := _authored_event_states.get("dead_sign", {}) as Dictionary
	if not bool(state.get("triggered", false)) and horizontal_travel >= 7.0:
		state["triggered"] = true
		event_root.set_meta("event_phase", "waiting_for_notice")
	if not bool(state.get("triggered", false)) or bool(state.get("failed", false)):
		_authored_event_states["dead_sign"] = state
		return
	var to_sign := event_root.global_position + Vector3.UP * 2.1 - player_position
	var view_dot := camera_forward.dot(to_sign.normalized()) if to_sign.length_squared() > 0.0001 else -1.0
	if view_dot >= 0.68:
		state["observed"] = true
		event_root.set_meta("event_phase", "noticed")
	elif bool(state.get("observed", false)) and view_dot <= 0.08:
		var label := event_root.get_node_or_null("DeadSignLabel") as Label3D
		if label != null:
			label.text = "EX_T"
		var glow := event_root.get_node_or_null("DeadSignGlow") as OmniLight3D
		if glow != null:
			glow.light_energy = 0.05
		state["failed"] = true
		event_root.set_meta("event_phase", "letter_missing")
	_authored_event_states["dead_sign"] = state


func _update_distant_mirage_event(delta: float, horizontal_travel: float, player_position: Vector3) -> void:
	var event_root := _authored_event_nodes.get("distant_mirage") as Node3D
	if event_root == null:
		return
	var state := _authored_event_states.get("distant_mirage", {}) as Dictionary
	if not bool(state.get("triggered", false)) and horizontal_travel >= 8.0:
		state["triggered"] = true
		event_root.visible = true
		event_root.set_meta("event_phase", "mirage_visible")
	if not bool(state.get("triggered", false)) or bool(state.get("dissolved", false)):
		_authored_event_states["distant_mirage"] = state
		return
	var elapsed := float(state.get("elapsed", 0.0)) + delta
	state["elapsed"] = elapsed
	var distance := player_position.distance_to(event_root.global_position)
	var approach_alpha := clampf((distance - 7.0) / 18.0, 0.0, 1.0)
	var time_alpha := 1.0 - smoothstep(9.5, 13.0, elapsed)
	var shimmer := 0.90 + sin(elapsed * 5.7) * 0.10
	for child in event_root.get_children():
		if not child is Sprite3D:
			continue
		var sprite := child as Sprite3D
		var base_position: Vector3 = sprite.get_meta("mirage_base_position", sprite.position)
		var phase := float(sprite.get_meta("mirage_phase", 0.0))
		sprite.position = base_position + Vector3(sin(elapsed * 7.3 + phase) * 0.018, sin(elapsed * 2.1 + phase) * 0.009, 0.0)
		var tint := sprite.modulate
		tint.a = float(sprite.get_meta("mirage_base_alpha", 0.2)) * approach_alpha * time_alpha * shimmer
		sprite.modulate = tint
	if distance <= 7.0 or elapsed >= 13.0:
		event_root.visible = false
		state["dissolved"] = true
		event_root.set_meta("event_phase", "dissolved")
	_authored_event_states["distant_mirage"] = state


func start_position() -> Vector3:
	if built_floor == 2:
		var disc_spawn := _floor_two_disc_point(PI * 0.5, 0.82)
		disc_spawn.y += 0.08
		return disc_spawn
	return Vector3(0.0, 0.08, map_length * 0.5 - 9.0)


func start_yaw_degrees() -> float:
	return 0.0


func contains_playable_position(position: Vector3, inset: float = 0.0) -> bool:
	if built_floor == 2:
		return _floor_two_disc_contains(position, inset)
	var half_width := maxf(0.5, map_width * 0.5 - inset)
	var half_length := maxf(0.5, map_length * 0.5 - inset)
	var inside_trunk := absf(position.x) <= half_width and absf(position.z) <= half_length
	if district_style != "sunlit_brick_street":
		return inside_trunk
	var branch_half_span := maxf(0.5, _sunlit_crossroad_span() * 0.5 - inset)
	var branch_half_width := maxf(0.5, SUNLIT_CROSSROAD_OPENING * 0.5 - inset)
	return inside_trunk or (absf(position.x) <= branch_half_span and absf(position.z) <= branch_half_width)


func clamp_to_playable_position(position: Vector3, inset: float = 1.2) -> Vector3:
	if built_floor == 2:
		return _clamp_to_floor_two_disc(position, inset)
	var half_width := maxf(0.5, map_width * 0.5 - inset)
	var half_length := maxf(0.5, map_length * 0.5 - inset)
	var trunk_candidate := Vector3(
		clampf(position.x, -half_width, half_width),
		maxf(0.08, position.y),
		clampf(position.z, -half_length, half_length)
	)
	if district_style != "sunlit_brick_street":
		return trunk_candidate
	var branch_half_span := maxf(0.5, _sunlit_crossroad_span() * 0.5 - inset)
	var branch_half_width := maxf(0.5, SUNLIT_CROSSROAD_OPENING * 0.5 - inset)
	var branch_candidate := Vector3(
		clampf(position.x, -branch_half_span, branch_half_span),
		maxf(0.08, position.y),
		clampf(position.z, -branch_half_width, branch_half_width)
	)
	var trunk_distance := Vector2(position.x - trunk_candidate.x, position.z - trunk_candidate.z).length_squared()
	var branch_distance := Vector2(position.x - branch_candidate.x, position.z - branch_candidate.z).length_squared()
	return branch_candidate if branch_distance < trunk_distance else trunk_candidate


func _sunlit_crossroad_span() -> float:
	return map_width + SUNLIT_CROSSROAD_ARM_LENGTH * 2.0


func _floor_two_disc_irregularity(angle: float) -> float:
	return sin(angle * 3.0) * 5.8 + sin(angle * 7.0 + 1.2) * 2.7 + cos(angle * 11.0 - 0.4) * 1.5


func _floor_two_disc_height(x: float, z: float, radial_ratio: float) -> float:
	var height := -0.62
	height += sin(x * 0.045 + cos(z * 0.026)) * 0.24
	height += cos(z * 0.041 - x * 0.018) * 0.18
	height += sin((x + z) * 0.022 + radial_ratio * 3.0) * 0.12
	for mound_data in FLOOR_TWO_HILL_MOUNDS:
		var mound: Vector4 = mound_data
		var distance := Vector2(x - mound.x, z - mound.y).length()
		var inward := clampf(1.0 - distance / mound.z, 0.0, 1.0)
		var smooth_dome := inward * inward * (3.0 - 2.0 * inward)
		height += smooth_dome * mound.w
	return height


func _floor_two_disc_point(angle: float, radial_ratio: float = 1.0) -> Vector3:
	var safe_ratio := clampf(radial_ratio, 0.0, 1.0)
	var cosine := cos(angle)
	var sine := sin(angle)
	var ellipse_radius := 1.0 / sqrt(
		(cosine * cosine) / (FLOOR_TWO_DISC_RADIUS_X * FLOOR_TWO_DISC_RADIUS_X)
		+ (sine * sine) / (FLOOR_TWO_DISC_RADIUS_Z * FLOOR_TWO_DISC_RADIUS_Z)
	)
	var boundary_radius := ellipse_radius + _floor_two_disc_irregularity(angle)
	var x := cosine * boundary_radius * safe_ratio
	var z := sine * boundary_radius * safe_ratio
	return Vector3(x, _floor_two_disc_height(x, z, safe_ratio), z)


func _floor_two_disc_angle(position: Vector3) -> float:
	if is_zero_approx(position.x) and is_zero_approx(position.z):
		return 0.0
	return atan2(position.z, position.x)


func _floor_two_disc_boundary_distance(angle: float) -> float:
	var boundary := _floor_two_disc_point(angle, 1.0)
	return Vector2(boundary.x, boundary.z).length()


func _floor_two_disc_planar_area() -> float:
	var doubled_area := 0.0
	for segment_index in FLOOR_TWO_DISC_SEGMENTS:
		var point_a := _floor_two_disc_point(TAU * float(segment_index) / float(FLOOR_TWO_DISC_SEGMENTS), 1.0)
		var point_b := _floor_two_disc_point(TAU * float(segment_index + 1) / float(FLOOR_TWO_DISC_SEGMENTS), 1.0)
		doubled_area += point_a.x * point_b.z - point_b.x * point_a.z
	return absf(doubled_area) * 0.5


func _floor_two_disc_contains(position: Vector3, inset: float) -> bool:
	var angle := _floor_two_disc_angle(position)
	var allowed_radius := maxf(1.0, _floor_two_disc_boundary_distance(angle) - inset)
	return Vector2(position.x, position.z).length() <= allowed_radius


func _clamp_to_floor_two_disc(position: Vector3, inset: float) -> Vector3:
	var flat_position := Vector2(position.x, position.z)
	var angle := _floor_two_disc_angle(position)
	# Leave a tiny interior margin so containment remains stable after float math.
	var allowed_radius := maxf(1.0, _floor_two_disc_boundary_distance(angle) - inset - 0.05)
	if flat_position.length() > allowed_radius:
		flat_position = flat_position.normalized() * allowed_radius
	var radial_ratio := clampf(flat_position.length() / maxf(1.0, _floor_two_disc_boundary_distance(angle)), 0.0, 1.0)
	var ground_height := _floor_two_disc_height(flat_position.x, flat_position.y, radial_ratio)
	return Vector3(flat_position.x, maxf(position.y, ground_height + 0.08), flat_position.y)


func apply_palette(palette: Dictionary) -> void:
	if _environment != null and _environment.environment != null:
		var environment := _environment.environment
		environment.background_color = _style_background_color(palette)
		environment.ambient_light_color = _style_ambient_color(palette)
		environment.fog_light_color = _style_fog_color(palette)
	for mesh_node in find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := mesh_node as MeshInstance3D
		if mesh_instance == null or not mesh_instance.has_meta("theme_role"):
			continue
		var material := mesh_instance.material_override as StandardMaterial3D
		if material != null:
			material.albedo_color = _role_color(str(mesh_instance.get_meta("theme_role")), palette)
	for actor in get_interactable_actors():
		var sprite := actor.get_node_or_null("Billboard") as Sprite3D
		if sprite == null:
			continue
		# Character art remains untouched; palette changes belong to the world and UI.
		sprite.modulate = Color.WHITE


func _clear_floor() -> void:
	_actors.clear()
	_items.clear()
	_environment = null
	_authored_event_root = null
	_authored_event_nodes.clear()
	_authored_event_states.clear()
	_authored_event_origin = Vector3.ZERO
	_authored_event_day = 1
	_cover_watcher_root = null
	_cover_watcher_sprite = null
	_cover_watcher_state.clear()
	for child in get_children():
		remove_child(child)
		child.free()


func _build_environment(palette: Dictionary) -> void:
	_environment = WorldEnvironment.new()
	_environment.name = "RealityWorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = _style_background_color(palette)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = _style_ambient_color(palette)
	if built_floor == 1:
		environment.ambient_light_energy = 0.78
	elif built_floor == 2:
		environment.ambient_light_energy = 0.14
	elif built_floor == 3:
		environment.ambient_light_energy = 0.68
	elif district_style == "night_white_blocks":
		environment.ambient_light_energy = 0.17
	elif district_style == "overgrown_gallery":
		environment.ambient_light_energy = 0.20
	else:
		environment.ambient_light_energy = 0.29
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.fog_enabled = true
	environment.fog_light_color = _style_fog_color(palette)
	if built_floor == 1:
		environment.fog_light_energy = 0.52
		environment.fog_density = 0.0062
		environment.fog_height = 1.1
		environment.fog_height_density = 0.16
	elif built_floor == 2:
		environment.fog_light_energy = 0.17
		environment.fog_density = 0.0185
		environment.fog_height = 0.52
		environment.fog_height_density = 0.34
	elif built_floor == 3:
		environment.fog_light_energy = 0.64
		environment.fog_density = 0.008
		environment.fog_height = 1.35
		environment.fog_height_density = 0.11
	else:
		environment.fog_light_energy = 0.16 if district_style == "overgrown_gallery" else maxf(0.16, 0.27 - float(built_floor - 2) * 0.025)
		environment.fog_density = 0.018 + float(built_floor - 2) * 0.0035
		environment.fog_height = 0.72
		environment.fog_height_density = 0.27 + float(built_floor - 2) * 0.025
	_environment.environment = environment
	add_child(_environment)
	set_meta("fog_density", environment.fog_density)
	set_meta("fog_height_density", environment.fog_height_density)
	set_meta("ambient_light_energy", environment.ambient_light_energy)
	set_meta("suspense_color_temperature", "daylight" if built_floor == 1 else ("cold_green" if built_floor == 2 else ("natural_daylight" if built_floor == 3 else "cold_blue")))
	set_meta("lighting_profile", "open_daylight" if built_floor == 1 else ("near_black_disc" if built_floor == 2 else ("natural_skylight" if built_floor == 3 else "slow_burn_suspense")))

	var key_light := DirectionalLight3D.new()
	key_light.name = "RealityKeyLight"
	key_light.rotation_degrees = Vector3(-48.0, -34.0, 0.0)
	if built_floor == 1:
		key_light.light_color = Color("FFF3D3")
		key_light.light_energy = 1.32
	elif built_floor == 2:
		key_light.light_color = Color("78918C")
		key_light.light_energy = 0.30
	elif built_floor == 3:
		key_light.light_color = Color("FFF4CB")
		key_light.light_energy = 1.18
	else:
		var cold_key_colors := [Color("AFC7BE"), Color("C2CEC0"), Color("A9BBC4"), Color("96ACB6")]
		var cold_key_energy := [0.34, 0.28, 0.36, 0.24]
		key_light.light_color = cold_key_colors[built_floor - 2]
		key_light.light_energy = cold_key_energy[built_floor - 2]
	key_light.shadow_enabled = true
	add_child(key_light)
	set_meta("key_light_color", key_light.light_color)
	set_meta("key_light_energy", key_light.light_energy)


func _build_architecture(palette: Dictionary) -> void:
	var architecture := Node3D.new()
	architecture.name = "Architecture"
	add_child(architecture)
	if built_floor == 2:
		_build_floor_two_disc_ground(architecture, palette)
	else:
		var ground_role := "grass_ground" if built_floor == 3 else ("grass" if district_style == "night_white_blocks" else ("gallery_floor" if district_style == "overgrown_gallery" else "sunlit_paving"))
		var street_ground := _add_box(
			architecture,
			"StreetGround",
			Vector3(map_width, 0.20, map_length),
			Vector3(0.0, -0.10, 0.0),
			ground_role,
			palette,
			true
		)
		street_ground.set_meta("continuous_ground", true)
	if district_style == "sunlit_brick_street" and built_floor != 2:
		var branch_ground := _add_box(
			architecture,
			"CrossroadGround",
			Vector3(_sunlit_crossroad_span(), 0.20, SUNLIT_CROSSROAD_OPENING),
			Vector3(0.0, -0.10, 0.0),
			"sunlit_paving",
			palette,
			true
		)
		branch_ground.set_meta("continuous_ground", true)
		branch_ground.set_meta("crossroad_extension", true)
	match district_style:
		"night_white_blocks" when built_floor == 2:
			_build_floor_two_scattered_district(architecture, palette)
		"night_white_blocks":
			_build_night_white_blocks(architecture, palette)
		"overgrown_gallery":
			_build_overgrown_gallery(architecture, palette)
		_:
			_build_sunlit_brick_street(architecture, palette)
	if built_floor == 2 or built_floor == 3:
		_build_dreamcore_artifacts(architecture, palette)
	if built_floor >= 2:
		_build_suspense_layer(architecture, palette)

	_build_air_walls(architecture)


func _build_floor_two_disc_ground(parent: Node3D, palette: Dictionary) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var min_height := INF
	var max_height := -INF
	for radial_index in FLOOR_TWO_DISC_RADIAL_SEGMENTS:
		var inner_ratio := float(radial_index) / float(FLOOR_TWO_DISC_RADIAL_SEGMENTS)
		var outer_ratio := float(radial_index + 1) / float(FLOOR_TWO_DISC_RADIAL_SEGMENTS)
		for segment_index in FLOOR_TWO_DISC_SEGMENTS:
			var angle_a := TAU * float(segment_index) / float(FLOOR_TWO_DISC_SEGMENTS)
			var angle_b := TAU * float(segment_index + 1) / float(FLOOR_TWO_DISC_SEGMENTS)
			var outer_a := _floor_two_disc_point(angle_a, outer_ratio)
			var outer_b := _floor_two_disc_point(angle_b, outer_ratio)
			for point in [outer_a, outer_b]:
				min_height = minf(min_height, point.y)
				max_height = maxf(max_height, point.y)
			if radial_index == 0:
				var center := _floor_two_disc_point(0.0, 0.0)
				_add_disc_surface_triangle(surface_tool, center, outer_b, outer_a)
				continue
			var inner_a := _floor_two_disc_point(angle_a, inner_ratio)
			var inner_b := _floor_two_disc_point(angle_b, inner_ratio)
			_add_disc_surface_triangle(surface_tool, inner_a, outer_b, outer_a)
			_add_disc_surface_triangle(surface_tool, inner_a, inner_b, outer_b)
	surface_tool.generate_normals()
	var disc_mesh := surface_tool.commit() as ArrayMesh
	var ground := StaticBody3D.new()
	ground.name = "IrregularDiscGround"
	ground.collision_layer = 1
	ground.collision_mask = 1
	ground.set_meta("continuous_ground", true)
	ground.set_meta("irregular_disc", true)
	ground.set_meta("procedural_terrain", true)
	parent.add_child(ground)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DiscSurface"
	mesh_instance.mesh = disc_mesh
	mesh_instance.set_meta("theme_role", "night_path")
	mesh_instance.material_override = _material("night_path", palette, false)
	ground.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var disc_shape := disc_mesh.create_trimesh_shape() as ConcavePolygonShape3D
	disc_shape.backface_collision = true
	collision.shape = disc_shape
	ground.add_child(collision)
	set_meta("terrain_profile", "undulating_irregular_disc")
	set_meta("disc_angular_segment_count", FLOOR_TWO_DISC_SEGMENTS)
	set_meta("disc_radial_segment_count", FLOOR_TWO_DISC_RADIAL_SEGMENTS)
	set_meta("disc_radius_x", FLOOR_TWO_DISC_RADIUS_X)
	set_meta("disc_radius_z", FLOOR_TWO_DISC_RADIUS_Z)
	set_meta("disc_height_variation", max_height - min_height)
	set_meta("disc_mound_count", FLOOR_TWO_HILL_MOUNDS.size())


func _add_disc_surface_triangle(surface_tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	for point in [a, b, c]:
		surface_tool.set_uv(Vector2(point.x, point.z) * 0.04)
		surface_tool.add_vertex(point)


func _build_floor_two_scattered_district(parent: Node3D, palette: Dictionary) -> void:
	var house_angles := [0.20, 0.91, 1.55, 2.20, 2.84, 3.55, 4.17, 4.92, 5.66]
	var house_radii := [0.60, 0.46, 0.61, 0.52, 0.68, 0.43, 0.65, 0.54, 0.70]
	var physical_house_count := FLOOR_TWO_PHYSICAL_HOUSE_COUNT
	var house_footprint_area := 0.0
	for house_index in physical_house_count:
		var angle := float(house_angles[house_index % house_angles.size()])
		var radial_ratio := float(house_radii[house_index % house_radii.size()])
		var room := _new_room(parent, house_index) if house_index < room_count else _new_floor_two_scenery_anchor(parent, house_index)
		room.position = _floor_two_disc_point(angle, radial_ratio)
		room.rotation.y = -angle + PI * 0.5 + sin(float(house_index) * 1.7) * 0.28
		room.set_meta("scattered_disc_room", true)
		room.set_meta("disc_angle", angle)
		room.set_meta("disc_radius_ratio", radial_ratio)
		house_footprint_area += _build_floor_two_sparse_house(room, house_index, palette)
		if house_index < room_count:
			_place_room_reward(room, house_index, Vector3(0.0, 0.0, 4.2), palette)
	set_meta("physical_house_count", physical_house_count)
	set_meta("physical_house_ratio", float(physical_house_count) / float(room_count))
	set_meta("night_house_segment_count", physical_house_count)
	var disc_planar_area := _floor_two_disc_planar_area()
	set_meta("night_house_footprint_area", house_footprint_area)
	set_meta("night_disc_planar_area", disc_planar_area)
	set_meta("night_house_coverage_ratio", house_footprint_area / maxf(1.0, disc_planar_area))
	set_meta("night_house_coverage_method", "procedural_footprints_over_boundary_polygon")
	set_meta("night_house_max_gap", 42.0)


func _new_floor_two_scenery_anchor(parent: Node3D, house_index: int) -> Node3D:
	var anchor := Node3D.new()
	anchor.name = "SceneryHouseAnchor%02d" % house_index
	anchor.set_meta("house_index", house_index)
	anchor.set_meta("scenery_only", true)
	anchor.set_meta("district_style", district_style)
	parent.add_child(anchor)
	return anchor


func _build_floor_two_sparse_house(room: Node3D, room_index: int, palette: Dictionary) -> float:
	var height := 3.5 + float(room_index % 2) * 0.8
	var width := 4.4 + float(room_index % 3) * 0.6
	var depth := 5.0 + float((room_index + 1) % 3) * 0.7
	var house := _add_box(room, "ScatteredHouse%02d" % room_index, Vector3(width, height, depth), Vector3(0.0, height * 0.5, 0.0), "white_wall", palette, true)
	house.set_meta("physical_house", true)
	house.set_meta("logical_room_index", room_index)
	_add_box(room, "HouseRoof", Vector3(width + 0.42, 0.22, depth + 0.42), Vector3(0.0, height + 0.11, 0.0), "wall_dark", palette, false)
	_add_box(room, "HouseDoor", Vector3(1.05, 2.05, 0.08), Vector3(0.0, 1.025, depth * 0.5 + 0.045), "window", palette, false)
	for window_index in 2:
		_add_box(room, "HouseWindow%d" % window_index, Vector3(0.72, 0.72, 0.07), Vector3(-1.15 + float(window_index) * 2.3, 2.65, depth * 0.5 + 0.05), "lamp_light", palette, false)
	return width * depth


func _build_sunlit_brick_street(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "MainRoad", Vector3(STREET_WIDTH, 0.025, map_length - 1.0), Vector3(0.0, 0.008, 0.0), "road", palette, false)
	var crossroad_span := _sunlit_crossroad_span()
	var crossroad := _add_box(parent, "CrossRoad", Vector3(crossroad_span - 1.0, 0.032, STREET_WIDTH), Vector3(0.0, 0.064, 0.0), "road", palette, false)
	crossroad.set_meta("crossroad_surface", true)
	crossroad.set_meta("crossroad_width", STREET_WIDTH)
	crossroad.set_meta("crossroad_span", crossroad_span)
	set_meta("crossroad_opening_span", SUNLIT_CROSSROAD_OPENING)
	set_meta("crossroad_arm_length", SUNLIT_CROSSROAD_ARM_LENGTH)
	set_meta("crossroad_total_span", crossroad_span)
	set_meta("crossroad_layout", "continuous_four_way")
	set_meta("dreamcore_overlay", "regular_grid_with_controlled_anomalies")
	var sidewalk_width := 3.15
	var edge_segment_length := (map_length - SUNLIT_CROSSROAD_OPENING) * 0.5
	for side in [-1.0, 1.0]:
		_add_box(parent, "Sidewalk%s" % ("West" if side < 0.0 else "East"), Vector3(sidewalk_width, 0.055, map_length - 1.0), Vector3(side * (STREET_WIDTH * 0.5 + sidewalk_width * 0.5), 0.018, 0.0), "sunlit_paving", palette, false)
		for direction in [-1.0, 1.0]:
			var curb_suffix := "%s%s" % ["West" if side < 0.0 else "East", "North" if direction < 0.0 else "South"]
			var center_z: float = direction * (SUNLIT_CROSSROAD_OPENING * 0.5 + edge_segment_length * 0.5)
			_add_box(parent, "Curb%s" % curb_suffix, Vector3(0.16, 0.10, edge_segment_length), Vector3(side * (STREET_WIDTH * 0.5 + 0.08), 0.048, center_z), "accent", palette, false)
	for side in [-1.0, 1.0]:
		_add_box(
			parent,
			"CrossroadSidewalk%s" % ("North" if side < 0.0 else "South"),
			Vector3(crossroad_span - 1.0, 0.055, 1.0),
			Vector3(0.0, 0.018, side * (STREET_WIDTH * 0.5 + 0.5)),
			"sunlit_paving",
			palette,
			false
		)
	_build_sunlit_edge_walls(parent, palette)
	_build_sunlit_branch_boundaries(parent, palette)
	_build_sunlit_dreamcore_rhythm(parent, palette)
	_build_road_markings(parent, palette)
	_build_crossroad_markings(parent, palette)
	for stripe_index in 5:
		_add_box(parent, "Crosswalk%02d" % stripe_index, Vector3(1.25, 0.024, 4.2), Vector3(-3.0 + float(stripe_index) * 1.5, 0.032, map_length * 0.5 - 6.4), "crosswalk", palette, false)
	var lot_rows := int(ceil(float(room_count) / 2.0))
	for room_index in room_count:
		var row := int(room_index / 2)
		var side := -1.0 if room_index % 2 == 0 else 1.0
		var center_z := (float(lot_rows - 1) * LOT_SPACING * 0.5) - float(row) * LOT_SPACING
		_build_sunlit_brick_room(parent, room_index, row, side, center_z, palette)
	_build_reference_portal(parent, str(DISTRICT_REFERENCE_TEXTURES[district_style]), palette)


func _build_sunlit_brick_room(parent: Node3D, room_index: int, row: int, side: float, center_z: float, palette: Dictionary) -> void:
	var room := _new_room(parent, room_index)
	var edge_wall_x := side * (map_width * 0.5 - SUNLIT_EDGE_WALL_THICKNESS)
	_add_box(room, "SidewalkInset", Vector3(3.1, 0.08, LOT_WIDTH + 1.2), Vector3(side * (STREET_WIDTH * 0.5 + 1.55), 0.045, center_z), "sunlit_paving", palette, false)
	if row % 2 == 1:
		_add_box(room, "BrickTurn", Vector3(3.35, 4.6, 0.52), Vector3(side * (STREET_WIDTH * 0.5 + 1.75), 2.3, center_z + LOT_WIDTH * 0.53), "brick_dark", palette, true)
	if row % 2 == 0:
		_build_street_lamp(room, Vector3(side * (STREET_WIDTH * 0.5 - 0.65), 0.0, center_z - 2.6), palette, true)
	if room_index % 4 == 1:
		_build_mood_panel(room, room_index, Vector3(edge_wall_x - side * 0.40, 2.15, center_z), side, palette)
	_place_room_reward(room, room_index, Vector3(side * (STREET_WIDTH * 0.5 + 1.45), 0.0, center_z), palette)


func _build_sunlit_edge_walls(parent: Node3D, palette: Dictionary) -> void:
	var segment_length := (map_length - SUNLIT_CROSSROAD_OPENING) * 0.5
	var edge_x := map_width * 0.5 - SUNLIT_EDGE_WALL_THICKNESS * 0.5
	for side in [-1.0, 1.0]:
		var side_name := "west" if side < 0.0 else "east"
		for direction in [-1.0, 1.0]:
			var section_name := "North" if direction < 0.0 else "South"
			var node_name := "BrickWall" if side < 0.0 and direction < 0.0 else "TerrainEdgeWall%s%s" % [side_name.capitalize(), section_name]
			var center_z: float = direction * (SUNLIT_CROSSROAD_OPENING * 0.5 + segment_length * 0.5)
			var wall := _add_box(
				parent,
				node_name,
				Vector3(SUNLIT_EDGE_WALL_THICKNESS, SUNLIT_EDGE_WALL_HEIGHT, segment_length),
				Vector3(side * edge_x, SUNLIT_EDGE_WALL_HEIGHT * 0.5, center_z),
				"brick",
				palette,
				true
			)
			wall.set_meta("terrain_edge_wall", true)
			wall.set_meta("terrain_boundary_wall", true)
			wall.set_meta("edge_side", side_name)
			wall.set_meta("edge_section", section_name.to_lower())
			wall.set_meta("edge_length", segment_length)
			wall.set_meta("intersection_clearance", SUNLIT_CROSSROAD_OPENING)
			_add_box(
				parent,
				"TerrainEdgeCap%s%s" % [side_name.capitalize(), section_name],
				Vector3(SUNLIT_EDGE_WALL_THICKNESS + 0.14, 0.16, segment_length),
				Vector3(side * edge_x, SUNLIT_EDGE_WALL_HEIGHT + 0.08, center_z),
				"brick_light",
				palette,
				false
			)


func _build_sunlit_branch_boundaries(parent: Node3D, palette: Dictionary) -> void:
	var arm_center_offset := map_width * 0.5 + SUNLIT_CROSSROAD_ARM_LENGTH * 0.5
	var branch_edge_z := SUNLIT_CROSSROAD_OPENING * 0.5 - SUNLIT_EDGE_WALL_THICKNESS * 0.5
	var crossroad_half_span := _sunlit_crossroad_span() * 0.5
	var boundary_count := 4
	var branch_wall_count := 0
	for direction in [-1.0, 1.0]:
		var direction_name := "West" if direction < 0.0 else "East"
		for side in [-1.0, 1.0]:
			var side_name := "North" if side < 0.0 else "South"
			var wall := _add_box(
				parent,
				"CrossroadBoundary%s%s" % [direction_name, side_name],
				Vector3(SUNLIT_CROSSROAD_ARM_LENGTH, SUNLIT_EDGE_WALL_HEIGHT, SUNLIT_EDGE_WALL_THICKNESS),
				Vector3(direction * arm_center_offset, SUNLIT_EDGE_WALL_HEIGHT * 0.5, side * branch_edge_z),
				"brick",
				palette,
				true
			)
			wall.set_meta("terrain_boundary_wall", true)
			wall.set_meta("crossroad_branch_wall", true)
			wall.set_meta("branch_direction", direction_name.to_lower())
			wall.set_meta("branch_side", side_name.to_lower())
			wall.set_meta("edge_length", SUNLIT_CROSSROAD_ARM_LENGTH)
			branch_wall_count += 1
			boundary_count += 1
			_add_box(
				parent,
				"CrossroadBoundaryCap%s%s" % [direction_name, side_name],
				Vector3(SUNLIT_CROSSROAD_ARM_LENGTH, 0.14, SUNLIT_EDGE_WALL_THICKNESS + 0.14),
				Vector3(direction * arm_center_offset, SUNLIT_EDGE_WALL_HEIGHT + 0.07, side * branch_edge_z),
				"brick_light",
				palette,
				false
			)
		var branch_end := _add_box(
			parent,
			"CrossroadEndWall%s" % direction_name,
			Vector3(SUNLIT_EDGE_WALL_THICKNESS, SUNLIT_EDGE_WALL_HEIGHT, SUNLIT_CROSSROAD_OPENING),
			Vector3(direction * crossroad_half_span, SUNLIT_EDGE_WALL_HEIGHT * 0.5, 0.0),
			"brick_dark",
			palette,
			true
		)
		branch_end.set_meta("terrain_boundary_wall", true)
		branch_end.set_meta("crossroad_branch_wall", true)
		branch_end.set_meta("branch_end", direction_name.to_lower())
		branch_wall_count += 1
		boundary_count += 1
	for direction in [-1.0, 1.0]:
		var end_name := "North" if direction < 0.0 else "South"
		var trunk_end := _add_box(
			parent,
			"StreetEndWall%s" % end_name,
			Vector3(map_width, SUNLIT_EDGE_WALL_HEIGHT, SUNLIT_EDGE_WALL_THICKNESS),
			Vector3(0.0, SUNLIT_EDGE_WALL_HEIGHT * 0.5, direction * map_length * 0.5),
			"brick_dark",
			palette,
			true
		)
		trunk_end.set_meta("terrain_boundary_wall", true)
		trunk_end.set_meta("street_end", end_name.to_lower())
		boundary_count += 1
	set_meta("terrain_boundary_wall_count", boundary_count)
	set_meta("crossroad_branch_wall_count", branch_wall_count)


func _build_sunlit_dreamcore_rhythm(parent: Node3D, palette: Dictionary) -> void:
	var rhythm := Node3D.new()
	rhythm.name = "DreamcoreThresholdRhythm"
	rhythm.set_meta("dreamcore_overlay", true)
	rhythm.set_meta("design_rule", "eighty_percent_grid_twenty_percent_anomaly")
	parent.add_child(rhythm)
	var light_slot_count := 0
	var false_door_count := 0
	for direction in [-1.0, 1.0]:
		var direction_name := "West" if direction < 0.0 else "East"
		for bay_index in 9:
			var x: float = direction * (map_width * 0.5 + SUNLIT_DREAMCORE_BAY * (float(bay_index) + 0.5))
			var anomaly_offset := 0.42 if direction > 0.0 and bay_index == 5 else 0.0
			_add_box(
				rhythm,
				"ThresholdBeam%s%02d" % [direction_name, bay_index],
				Vector3(0.16, 0.18, SUNLIT_CROSSROAD_OPENING - 1.0),
				Vector3(x + anomaly_offset, 4.72, 0.0),
				"brick_light",
				palette,
				false
			)
			_add_box(
				rhythm,
				"CeilingLightSlot%s%02d" % [direction_name, bay_index],
				Vector3(1.72, 0.08, 0.34),
				Vector3(x + anomaly_offset, 4.58, 0.0),
				"crosswalk",
				palette,
				false
			)
			light_slot_count += 1
			if bay_index % 2 == 0:
				var light := OmniLight3D.new()
				light.name = "ThresholdLight%s%02d" % [direction_name, bay_index]
				light.position = Vector3(x + anomaly_offset, 4.22, 0.0)
				light.light_color = Color("FFF1C9")
				light.light_energy = 0.36
				light.omni_range = 7.4
				light.shadow_enabled = false
				rhythm.add_child(light)
			if bay_index % 3 == 1:
				var door_side := -1.0 if posmod(bay_index + int(direction > 0.0), 2) == 0 else 1.0
				var door_height := 1.42 if direction > 0.0 and bay_index == 7 else 2.62
				var false_door := _add_box(
					rhythm,
					"FalseDoor%s%02d" % [direction_name, bay_index],
					Vector3(1.55, door_height, 0.09),
					Vector3(x, door_height * 0.5, door_side * (SUNLIT_CROSSROAD_OPENING * 0.5 - SUNLIT_EDGE_WALL_THICKNESS - 0.06)),
					"wall_dark",
					palette,
					false
				)
				false_door.set_meta("false_door", true)
				false_door.set_meta("controlled_anomaly", door_height < 2.0)
				false_door_count += 1
	set_meta("dreamcore_light_slot_count", light_slot_count)
	set_meta("dreamcore_false_door_count", false_door_count)


func _build_crossroad_markings(parent: Node3D, palette: Dictionary) -> void:
	var crossroad_span := _sunlit_crossroad_span()
	var dash_count := int(floor((crossroad_span - 4.0) / SUNLIT_DREAMCORE_BAY))
	for dash_index in dash_count:
		var x := -crossroad_span * 0.5 + 3.0 + float(dash_index) * SUNLIT_DREAMCORE_BAY
		if absf(x) < 2.0:
			continue
		_add_box(parent, "CrossroadStripe%02d" % dash_index, Vector3(2.1, 0.018, 0.14), Vector3(x, 0.088, 0.0), "accent", palette, false)


func _build_night_white_blocks(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "NightWalk", Vector3(4.8, 0.035, map_length - 1.2), Vector3(-2.35, 0.018, 0.0), "night_path", palette, false)
	var lot_rows := int(ceil(float(room_count) / 2.0))
	var terrace_span := map_length - NIGHT_TERRACE_END_MARGIN * 2.0
	var segment_pitch := terrace_span / float(lot_rows)
	var segment_length := segment_pitch - NIGHT_TERRACE_GAP
	var facade_bay_count := 0
	for room_index in room_count:
		var row := int(room_index / 2)
		var side := -1.0 if room_index % 2 == 0 else 1.0
		var center_z := (float(lot_rows - 1) * segment_pitch * 0.5) - float(row) * segment_pitch
		facade_bay_count += _build_night_house(parent, room_index, row, side, center_z, segment_length, palette)
	set_meta("night_house_segment_count", room_count)
	set_meta("night_house_coverage_ratio", segment_length / segment_pitch)
	set_meta("night_house_max_gap", NIGHT_TERRACE_GAP)
	set_meta("night_facade_bay_count", facade_bay_count)
	_build_reference_portal(parent, str(DISTRICT_REFERENCE_TEXTURES[district_style]), palette)


func _build_night_house(parent: Node3D, room_index: int, row: int, side: float, center_z: float, segment_length: float, palette: Dictionary) -> int:
	var room := _new_room(parent, room_index)
	var height := 4.5 + float((room_index + built_floor) % 3) * 0.8
	var depth := 5.4
	var center_x := side * (4.35 + depth * 0.5)
	var house := _add_box(room, "WhiteHouse", Vector3(depth, height, segment_length), Vector3(center_x, height * 0.5, center_z), "white_wall", palette, true)
	house.set_meta("continuous_house_segment", true)
	house.set_meta("segment_length", segment_length)
	_add_box(room, "TerraceParapet", Vector3(depth + 0.18, 0.22, segment_length), Vector3(center_x, height + 0.11, center_z), "white_wall", palette, false)
	var face_x := center_x - side * (depth * 0.5 + 0.025)
	var module_count := maxi(4, int(floor(segment_length / NIGHT_FACADE_BAY)))
	var module_spacing := segment_length / float(module_count)
	var anomaly_bay := posmod(room_index * 3 + built_floor, module_count)
	for module_index in module_count:
		var module_z := center_z - segment_length * 0.5 + module_spacing * (float(module_index) + 0.5)
		if module_index > 0:
			_add_box(
				room,
				"FacadeJoint%02d" % module_index,
				Vector3(0.075, height - 0.34, 0.09),
				Vector3(face_x - side * 0.04, height * 0.5, module_z - module_spacing * 0.5),
				"window",
				palette,
				false
			)
		for storey_index in 2:
			var controlled_anomaly := module_index == anomaly_bay and storey_index == 1
			var window_height := 0.48 if controlled_anomaly else 0.82
			var window_y := 1.38 + float(storey_index) * 1.72 + (0.18 if controlled_anomaly else 0.0)
			var window := _add_box(
				room,
				"Window%02d_%d" % [module_index, storey_index],
				Vector3(0.065, window_height, 0.84),
				Vector3(face_x - side * 0.045, window_y, module_z),
				"window",
				palette,
				false
			)
			if controlled_anomaly:
				window.set_meta("controlled_repeat_anomaly", true)
		if module_index % 4 == 1:
			var repeated_door := _add_box(
				room,
				"RepeatedDoor%02d" % module_index,
				Vector3(0.07, 2.18, 1.08),
				Vector3(face_x - side * 0.055, 1.09, module_z + module_spacing * 0.22),
				"window",
				palette,
				false
			)
			repeated_door.set_meta("architectural_repeat", true)
	if row % 2 == 0:
		_build_street_lamp(room, Vector3(side * 3.55, 0.0, center_z - minf(2.2, segment_length * 0.18)), palette, false)
	if room_index % 4 == 2:
		_build_mood_panel(room, room_index, Vector3(face_x - side * 0.04, 2.4, center_z + 1.4), side, palette)
	_place_room_reward(room, room_index, Vector3(side * 3.65, 0.0, center_z), palette)
	return module_count


func _build_overgrown_gallery(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "GalleryWalk", Vector3(6.2, 0.05, map_length - 1.0), Vector3(0.0, 0.025, 0.0), "gallery_floor", palette, false)
	_build_full_map_grass(parent, palette)
	var gallery_span := _build_gallery_continuum(parent, palette)
	var lot_rows := int(ceil(float(room_count) / 2.0))
	var bay_pitch := gallery_span / float(lot_rows)
	for room_index in room_count:
		var row := int(room_index / 2)
		var side := -1.0 if room_index % 2 == 0 else 1.0
		var center_z := (float(lot_rows - 1) * bay_pitch * 0.5) - float(row) * bay_pitch
		_build_gallery_bay(parent, room_index, row, side, center_z, palette)
	_build_reference_portal(parent, str(DISTRICT_REFERENCE_TEXTURES[district_style]), palette)


func _build_gallery_continuum(parent: Node3D, palette: Dictionary) -> float:
	var gallery_span := map_length - GALLERY_END_MARGIN * 2.0
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		var roof_name := "GalleryRoof" if side < 0.0 else "GalleryRoofEast"
		var roof := _add_box(parent, roof_name, Vector3(5.1, 0.28, gallery_span), Vector3(side * 5.15, 3.55, 0.0), "white_wall", palette, true)
		roof.set_meta("continuous_gallery", true)
		roof.set_meta("span_length", gallery_span)
		var outer_wall := _add_box(parent, "OuterWall%s" % side_name, Vector3(0.34, 3.55, gallery_span), Vector3(side * 7.7, 1.78, 0.0), "white_wall", palette, true)
		outer_wall.set_meta("continuous_gallery", true)
		outer_wall.set_meta("span_length", gallery_span)
	_build_skylit_gallery_ceiling(parent, gallery_span, palette)

	var column_run := gallery_span - 2.0
	var interval_count := maxi(1, int(ceil(column_run / GALLERY_COLUMN_TARGET_SPACING)))
	var column_spacing := column_run / float(interval_count)
	var column_count := 0
	var anomaly_index := int(floor(float(interval_count) * 0.62))
	for column_index in range(interval_count + 1):
		var column_z := -column_run * 0.5 + float(column_index) * column_spacing
		for side in [-1.0, 1.0]:
			var side_name := "W" if side < 0.0 else "E"
			var column := _add_box(parent, "GalleryColumn%s%02d" % [side_name, column_index], Vector3(0.52, 3.55, 0.52), Vector3(side * GALLERY_COLUMN_X, 1.78, column_z), "white_wall", palette, true)
			column.set_meta("gallery_column", true)
			column_count += 1
		if column_index == anomaly_index:
			var echo_column := _add_box(parent, "GalleryEchoColumn", Vector3(0.52, 3.55, 0.52), Vector3(GALLERY_COLUMN_X, 1.78, column_z + 0.72), "white_wall", palette, true)
			echo_column.set_meta("gallery_column", true)
			echo_column.set_meta("controlled_repeat_anomaly", true)
			column_count += 1
	set_meta("gallery_continuous", true)
	set_meta("gallery_span", gallery_span)
	set_meta("gallery_span_ratio", gallery_span / map_length)
	set_meta("gallery_column_count", column_count)
	set_meta("gallery_column_spacing", column_spacing)
	set_meta("gallery_repeat_anomaly_count", 1)
	return gallery_span


func _build_gallery_bay(parent: Node3D, room_index: int, row: int, side: float, center_z: float, palette: Dictionary) -> void:
	var room := _new_room(parent, room_index)
	if row % 2 == 1:
		_build_mood_panel(room, room_index, Vector3(side * 7.5, 2.0, center_z), side, palette)
	_place_room_reward(room, room_index, Vector3(side * 2.15, 0.0, center_z), palette)


func _build_skylit_gallery_ceiling(parent: Node3D, gallery_span: float, palette: Dictionary) -> void:
	var ceiling := Node3D.new()
	ceiling.name = "GalleryCeilingSpan"
	ceiling.set_meta("skylit_ceiling", true)
	ceiling.set_meta("span_length", gallery_span)
	parent.add_child(ceiling)
	var total_open_length := float(GALLERY_SKYLIGHT_COUNT) * GALLERY_SKYLIGHT_LENGTH
	var solid_segment_length := (gallery_span - total_open_length) / float(GALLERY_SKYLIGHT_COUNT + 1)
	var cursor := -gallery_span * 0.5
	for segment_index in range(GALLERY_SKYLIGHT_COUNT + 1):
		var segment_center := cursor + solid_segment_length * 0.5
		var segment := _add_box(
			ceiling,
			"GalleryCeilingSegment%02d" % segment_index,
			Vector3(5.4, 0.24, solid_segment_length),
			Vector3(0.0, 3.55, segment_center),
			"white_wall",
			palette,
			true
		)
		segment.set_meta("skylight_roof_segment", true)
		cursor += solid_segment_length
		if segment_index >= GALLERY_SKYLIGHT_COUNT:
			continue
		var opening := Node3D.new()
		opening.name = "SkylightOpening%02d" % segment_index
		opening.position = Vector3(0.0, 3.55, cursor + GALLERY_SKYLIGHT_LENGTH * 0.5)
		opening.set_meta("skylight_opening", true)
		opening.set_meta("opening_size", Vector2(5.4, GALLERY_SKYLIGHT_LENGTH))
		ceiling.add_child(opening)
		cursor += GALLERY_SKYLIGHT_LENGTH
	set_meta("skylight_opening_count", GALLERY_SKYLIGHT_COUNT)
	set_meta("skylight_open_ratio", total_open_length / gallery_span)


func _build_full_map_grass(parent: Node3D, palette: Dictionary) -> void:
	var columns := maxi(1, int(ceil(map_width / FULL_MAP_GRASS_SPACING)))
	var rows := maxi(1, int(ceil(map_length / FULL_MAP_GRASS_SPACING)))
	var instance_count := columns * rows
	var grass_field := MultiMeshInstance3D.new()
	grass_field.name = "FullMapGrass"
	grass_field.set_meta("procedural_grass", true)
	grass_field.set_meta("full_map_coverage", true)
	grass_field.set_meta("non_interactable", true)
	grass_field.extra_cull_margin = 4.0
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = _grass_blade_mesh(FULL_MAP_GRASS_BLADE_WIDTH, FULL_MAP_GRASS_BLADE_HEIGHT, 0.035)
	multimesh.instance_count = instance_count
	# Explicitly cover every tuft. Without a full-field AABB, distant batches can
	# disappear even though their instance transforms span the whole gallery.
	multimesh.custom_aabb = AABB(
		Vector3(-map_width * 0.5 - 0.5, -0.08, -map_length * 0.5 - 0.5),
		Vector3(map_width + 1.0, FULL_MAP_GRASS_BLADE_HEIGHT + 0.42, map_length + 1.0)
	)
	var instance_index := 0
	for row_index in rows:
		for column_index in columns:
			var phase := float(row_index * 37 + column_index * 61)
			var x := -map_width * 0.5 + (float(column_index) + 0.5) * map_width / float(columns)
			var z := -map_length * 0.5 + (float(row_index) + 0.5) * map_length / float(rows)
			x += sin(phase * 0.73) * 0.34
			z += cos(phase * 0.51) * 0.34
			var height_scale := 0.72 + float(posmod(row_index * 5 + column_index * 3, 9)) * 0.055
			var width_scale := 0.78 + float(posmod(row_index * 2 + column_index * 7, 7)) * 0.045
			var yaw := phase * 0.19
			var basis := Basis(Vector3.UP, yaw).scaled(Vector3(width_scale, height_scale, width_scale))
			var transform := Transform3D(basis, Vector3(x, FULL_MAP_GRASS_BLADE_HEIGHT * 0.5 * height_scale, z))
			multimesh.set_instance_transform(instance_index, transform)
			var brightness := 0.80 + float(posmod(row_index + column_index * 2, 6)) * 0.035
			multimesh.set_instance_color(instance_index, Color(brightness, 0.92 + (brightness - 0.8) * 0.25, 0.72, 1.0))
			instance_index += 1
	grass_field.multimesh = multimesh
	var grass_material := _material("grass", palette, false)
	grass_material.vertex_color_use_as_albedo = true
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.roughness = 0.94
	grass_field.material_override = grass_material
	parent.add_child(grass_field)
	set_meta("terrain_profile", "full_map_meadow_gallery")
	set_meta("grass_render_mode", "multimesh")
	set_meta("grass_coverage", "full_map")
	set_meta("grass_instance_count", instance_count)
	set_meta("grass_coverage_ratio", 1.0)
	set_meta("grass_bounds", Vector2(map_width, map_length))
	set_meta("grass_density_spacing", FULL_MAP_GRASS_SPACING)
	set_meta("grass_blade_height", FULL_MAP_GRASS_BLADE_HEIGHT)
	set_meta("grass_blade_width", FULL_MAP_GRASS_BLADE_WIDTH)
	set_meta("grass_custom_aabb", multimesh.custom_aabb)


func _build_dreamcore_artifacts(parent: Node3D, palette: Dictionary) -> void:
	var artifacts := Node3D.new()
	artifacts.name = "DreamcoreArtifacts"
	artifacts.set_meta("procedural_collection", true)
	parent.add_child(artifacts)
	var artifact_types := PackedStringArray([
		"false_window",
		"water_cooler",
		"crt_cart",
		"payphone",
		"folding_chair",
		"vending_machine",
		"fluorescent_troffer",
		"supply_crates",
		"pipe_manifold",
	])
	var artifact_count := 18
	for artifact_index in artifact_count:
		var artifact_type := artifact_types[artifact_index % artifact_types.size()]
		var artifact := Node3D.new()
		artifact.name = "%s%02d" % [artifact_type.to_pascal_case(), artifact_index]
		artifact.set_meta("dreamcore_object", true)
		artifact.set_meta("dreamcore_type", artifact_type)
		artifact.set_meta("procedural_low_poly", true)
		artifact.set_meta("original_geometry", true)
		artifact.set_meta("non_pickup", true)
		artifact.set_meta("interactable", false)
		artifact.set_meta("pickup_kind", "none")
		var artifact_scale := 0.82 + float(posmod(artifact_index * 5, 4)) * 0.11
		artifact.scale = Vector3.ONE * artifact_scale
		if built_floor == 2:
			var angle := 0.18 + TAU * float(artifact_index) / float(artifact_count) + sin(float(artifact_index) * 2.3) * 0.12
			var radial_ratio := 0.24 + float(posmod(artifact_index * 5, 7)) * 0.075
			artifact.position = _floor_two_disc_point(angle, radial_ratio)
			artifact.position.y += 0.06
			artifact.rotation.y = -angle + sin(float(artifact_index)) * 0.35
		else:
			var lane_side := -1.0 if artifact_index % 2 == 0 else 1.0
			var progress := float(artifact_index + 1) / float(artifact_count + 1)
			artifact.position = Vector3(lane_side * (5.2 + float(artifact_index % 3) * 0.65), 0.10, lerpf(-map_length * 0.38, map_length * 0.38, progress))
			artifact.rotation.y = PI if lane_side > 0.0 else 0.0
		artifacts.add_child(artifact)
		match artifact_type:
			"false_window":
				_build_false_window(artifact, palette)
			"water_cooler":
				_build_water_cooler(artifact, palette)
			"crt_cart":
				_build_crt_cart(artifact, palette)
			"payphone":
				_build_payphone(artifact, palette)
			"folding_chair":
				_build_folding_chair(artifact, palette)
			"vending_machine":
				_build_vending_machine(artifact, palette)
			"fluorescent_troffer":
				_build_fluorescent_troffer(artifact, palette)
			"supply_crates":
				_build_supply_crates(artifact, palette)
			_:
				_build_pipe_manifold(artifact, palette)
	set_meta("dreamcore_object_type_count", artifact_types.size())
	set_meta("dreamcore_object_count", artifact_count)
	set_meta("dreamcore_object_types", artifact_types)
	set_meta("dreamcore_non_pickup_count", artifact_count)


func _build_false_window(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "FalseWindowGlass", Vector3(1.62, 2.10, 0.08), Vector3(0.0, 1.90, 0.02), "window", palette, false)
	for x in [-0.90, 0.90]:
		_add_box(parent, "FalseWindowJamb%s" % ("L" if x < 0.0 else "R"), Vector3(0.16, 2.55, 0.18), Vector3(x, 1.90, 0.08), "fixture_metal", palette, false)
	for y in [0.62, 3.18]:
		_add_box(parent, "FalseWindowRail%02d" % int(y * 10.0), Vector3(1.96, 0.16, 0.18), Vector3(0.0, y, 0.08), "fixture_metal", palette, false)
	_add_box(parent, "FalseWindowMullion", Vector3(0.09, 2.35, 0.12), Vector3(0.0, 1.90, 0.15), "fixture_metal", palette, false)
	_add_box(parent, "FalseWindowTransom", Vector3(1.72, 0.09, 0.12), Vector3(0.0, 1.88, 0.15), "fixture_metal", palette, false)
	_add_box(parent, "FalseWindowSill", Vector3(2.22, 0.18, 0.52), Vector3(0.0, 0.54, 0.18), "backrooms_beige", palette, false)
	for step_index in 3:
		_add_box(
			parent,
			"WindowStep%02d" % step_index,
			Vector3(2.05 - float(step_index) * 0.14, 0.14, 0.54),
			Vector3(0.0, 0.07 + float(step_index) * 0.15, 1.38 - float(step_index) * 0.48),
			"backrooms_beige",
			palette,
			false
		)


func _build_water_cooler(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "WaterCoolerCabinet", Vector3(0.72, 1.18, 0.62), Vector3(0.0, 0.59, 0.0), "backrooms_beige", palette, false)
	_add_box(parent, "WaterCoolerRecess", Vector3(0.46, 0.32, 0.07), Vector3(0.0, 0.82, 0.35), "rubber_black", palette, false)
	_add_box(parent, "WaterCoolerDripTray", Vector3(0.42, 0.08, 0.24), Vector3(0.0, 0.60, 0.39), "fixture_metal", palette, false)
	for tap_index in 2:
		var x := -0.13 if tap_index == 0 else 0.13
		var role := "cooler_blue" if tap_index == 0 else "indicator_red"
		_add_box(parent, "WaterCoolerTap%02d" % tap_index, Vector3(0.11, 0.16, 0.14), Vector3(x, 0.92, 0.42), role, palette, false)
	var jug := _add_low_poly_cylinder(parent, "WaterCoolerJug", 0.27, 0.34, 0.72, 12, "cooler_blue", palette)
	jug.position = Vector3(0.0, 1.54, 0.0)
	var neck := _add_low_poly_cylinder(parent, "WaterCoolerJugNeck", 0.14, 0.20, 0.20, 10, "cooler_blue", palette)
	neck.position = Vector3(0.0, 1.12, 0.0)
	var cap := _add_low_poly_cylinder(parent, "WaterCoolerCap", 0.15, 0.15, 0.08, 10, "rubber_black", palette)
	cap.position = Vector3(0.0, 1.06, 0.0)
	for cup_index in 4:
		var cup := _add_low_poly_cylinder(parent, "WaterCup%02d" % cup_index, 0.08, 0.10, 0.13, 8, "fluorescent", palette)
		cup.position = Vector3(0.46, 0.74 + float(cup_index) * 0.10, 0.02)


func _build_crt_cart(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "CRTCartUpperShelf", Vector3(1.48, 0.10, 0.92), Vector3(0.0, 0.95, 0.0), "cart_metal", palette, false)
	_add_box(parent, "CRTCartLowerShelf", Vector3(1.40, 0.10, 0.82), Vector3(0.0, 0.37, 0.0), "cart_metal", palette, false)
	for x in [-0.58, 0.58]:
		for z in [-0.32, 0.32]:
			_add_box(parent, "CRTCartPost%s%s" % ["L" if x < 0.0 else "R", "B" if z < 0.0 else "F"], Vector3(0.07, 0.86, 0.07), Vector3(x, 0.52, z), "fixture_metal", palette, false)
			var wheel := _add_low_poly_cylinder(parent, "CRTCartWheel%s%s" % ["L" if x < 0.0 else "R", "B" if z < 0.0 else "F"], 0.13, 0.13, 0.08, 10, "rubber_black", palette)
			wheel.position = Vector3(x, 0.10, z)
			wheel.rotation.z = PI * 0.5
	_add_box(parent, "CRTTelevisionBody", Vector3(1.32, 0.92, 0.92), Vector3(0.0, 1.48, 0.0), "backrooms_beige", palette, false)
	_add_box(parent, "CRTTelevisionBezel", Vector3(1.12, 0.72, 0.08), Vector3(-0.05, 1.50, 0.49), "rubber_black", palette, false)
	_add_box(parent, "CRTTelevisionScreen", Vector3(0.88, 0.58, 0.06), Vector3(-0.11, 1.52, 0.55), "screen_glow", palette, false)
	for knob_index in 2:
		var knob := _add_low_poly_cylinder(parent, "CRTKnob%02d" % knob_index, 0.07, 0.07, 0.07, 10, "fixture_metal", palette)
		knob.position = Vector3(0.50, 1.60 - float(knob_index) * 0.23, 0.56)
		knob.rotation.x = PI * 0.5
	for antenna_side in [-1.0, 1.0]:
		var antenna := _add_box(parent, "CRTAntenna%s" % ("L" if antenna_side < 0.0 else "R"), Vector3(0.04, 0.72, 0.04), Vector3(antenna_side * 0.22, 2.24, 0.0), "fixture_metal", palette, false)
		antenna.rotation.z = antenna_side * 0.34


func _build_payphone(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "PayphonePedestal", Vector3(0.96, 1.62, 0.58), Vector3(0.0, 0.81, 0.0), "backrooms_beige", palette, false)
	_add_box(parent, "PayphoneHousing", Vector3(0.88, 1.12, 0.34), Vector3(0.0, 1.48, 0.25), "fixture_metal", palette, false)
	_add_box(parent, "PayphoneInstructionPlate", Vector3(0.42, 0.20, 0.05), Vector3(0.15, 1.86, 0.45), "fluorescent", palette, false)
	_add_box(parent, "PayphoneCoinSlot", Vector3(0.18, 0.06, 0.05), Vector3(0.22, 1.69, 0.46), "rubber_black", palette, false)
	for keypad_row in 4:
		for keypad_column in 3:
			_add_box(
				parent,
				"PayphoneKey%02d" % (keypad_row * 3 + keypad_column),
				Vector3(0.10, 0.09, 0.05),
				Vector3(0.05 + float(keypad_column) * 0.13, 1.48 - float(keypad_row) * 0.12, 0.47),
				"rubber_black",
				palette,
				false
			)
	_add_box(parent, "PayphoneReturnHatch", Vector3(0.38, 0.16, 0.06), Vector3(0.16, 0.95, 0.46), "rubber_black", palette, false)
	_add_box(parent, "PayphoneHandset", Vector3(0.18, 0.72, 0.18), Vector3(-0.40, 1.50, 0.50), "indicator_red", palette, false)
	_add_box(parent, "PayphoneHandsetTop", Vector3(0.30, 0.20, 0.22), Vector3(-0.40, 1.84, 0.50), "indicator_red", palette, false)
	_add_box(parent, "PayphoneHandsetBottom", Vector3(0.30, 0.20, 0.22), Vector3(-0.40, 1.16, 0.50), "indicator_red", palette, false)
	for cord_index in 6:
		var cord := _add_box(parent, "PayphoneCord%02d" % cord_index, Vector3(0.05, 0.28, 0.05), Vector3(-0.45 + sin(float(cord_index) * 1.7) * 0.10, 0.97 - float(cord_index) * 0.18, 0.42), "rubber_black", palette, false)
		cord.rotation.z = sin(float(cord_index) * 1.7) * 0.45


func _build_folding_chair(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "FoldingChairSeat", Vector3(1.05, 0.13, 0.86), Vector3(0.0, 0.92, 0.0), "chair_vinyl", palette, false)
	_add_box(parent, "FoldingChairBack", Vector3(1.05, 0.62, 0.12), Vector3(0.0, 1.58, -0.32), "chair_vinyl", palette, false)
	for x in [-0.44, 0.44]:
		for z in [-0.29, 0.29]:
			var leg := _add_box(parent, "FoldingChairLeg%s%s" % ["L" if x < 0.0 else "R", "B" if z < 0.0 else "F"], Vector3(0.07, 1.18, 0.07), Vector3(x, 0.50, z), "chair_metal", palette, false)
			leg.rotation.x = 0.22 if z < 0.0 else -0.22
		var back_post := _add_box(parent, "FoldingChairBackPost%s" % ("L" if x < 0.0 else "R"), Vector3(0.07, 1.52, 0.07), Vector3(x, 1.04, -0.34), "chair_metal", palette, false)
		back_post.rotation.x = -0.08
	for side in [-1.0, 1.0]:
		var brace := _add_box(parent, "FoldingChairBrace%s" % ("L" if side < 0.0 else "R"), Vector3(0.06, 1.04, 0.06), Vector3(side * 0.46, 0.53, 0.0), "chair_metal", palette, false)
		brace.rotation.x = side * 0.58


func _build_vending_machine(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "VendingMachineBody", Vector3(1.34, 2.32, 0.82), Vector3(0.0, 1.16, 0.0), "machine_green", palette, false)
	_add_box(parent, "VendingDisplay", Vector3(0.84, 1.34, 0.06), Vector3(-0.18, 1.48, 0.44), "window", palette, false)
	for row in 3:
		for column in 3:
			var role: String = str(["indicator_red", "cooler_blue", "fluorescent"][posmod(row + column, 3)])
			_add_box(parent, "VendingCan%02d" % (row * 3 + column), Vector3(0.16, 0.28, 0.10), Vector3(-0.48 + float(column) * 0.30, 1.83 - float(row) * 0.39, 0.49), role, palette, false)
	_add_box(parent, "VendingControlPanel", Vector3(0.24, 0.92, 0.06), Vector3(0.48, 1.48, 0.45), "backrooms_beige", palette, false)
	for button_index in 4:
		_add_box(parent, "VendingButton%02d" % button_index, Vector3(0.10, 0.10, 0.05), Vector3(0.48, 1.76 - float(button_index) * 0.19, 0.50), "rubber_black", palette, false)
	_add_box(parent, "VendingCoinSlot", Vector3(0.10, 0.20, 0.05), Vector3(0.48, 0.98, 0.50), "fixture_metal", palette, false)
	_add_box(parent, "VendingPickupHatch", Vector3(0.74, 0.30, 0.08), Vector3(-0.12, 0.32, 0.46), "rubber_black", palette, false)


func _build_fluorescent_troffer(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "FluorescentTrofferBack", Vector3(1.62, 0.86, 0.10), Vector3(0.0, 1.62, 0.0), "fixture_metal", palette, false)
	for x in [-0.78, 0.78]:
		_add_box(parent, "TrofferFrameV%s" % ("L" if x < 0.0 else "R"), Vector3(0.08, 0.94, 0.16), Vector3(x, 1.62, 0.08), "backrooms_beige", palette, false)
	for y in [1.19, 2.05]:
		_add_box(parent, "TrofferFrameH%02d" % int(y * 10.0), Vector3(1.62, 0.08, 0.16), Vector3(0.0, y, 0.08), "backrooms_beige", palette, false)
	for tube_index in 4:
		_add_box(parent, "FluorescentTube%02d" % tube_index, Vector3(1.38, 0.09, 0.09), Vector3(0.0, 1.33 + float(tube_index) * 0.19, 0.13), "fluorescent", palette, false)
	for wire_side in [-1.0, 1.0]:
		var wire := _add_box(parent, "TrofferWire%s" % ("L" if wire_side < 0.0 else "R"), Vector3(0.035, 1.02, 0.035), Vector3(wire_side * 0.52, 2.55, 0.0), "rubber_black", palette, false)
		wire.rotation.z = wire_side * 0.12


func _build_supply_crates(parent: Node3D, palette: Dictionary) -> void:
	for pallet_index in 4:
		_add_box(parent, "SupplyPalletSlat%02d" % pallet_index, Vector3(2.18, 0.12, 0.26), Vector3(0.0, 0.10, -0.56 + float(pallet_index) * 0.38), "crate_wood", palette, false)
	_build_crate_unit(parent, "SupplyCrateLeft", Vector3(-0.52, 0.72, 0.0), 0.0, palette)
	_build_crate_unit(parent, "SupplyCrateRight", Vector3(0.54, 0.72, 0.05), -0.08, palette)
	_build_crate_unit(parent, "SupplyCrateTop", Vector3(0.02, 1.74, 0.02), 0.06, palette)


func _build_crate_unit(parent: Node3D, node_name: String, position: Vector3, yaw: float, palette: Dictionary) -> void:
	var crate := Node3D.new()
	crate.name = node_name
	crate.position = position
	crate.rotation.y = yaw
	parent.add_child(crate)
	_add_box(crate, "CrateCore", Vector3(0.94, 0.94, 0.88), Vector3.ZERO, "crate_wood", palette, false)
	for rail_y in [-0.39, 0.39]:
		_add_box(crate, "CrateRailH%s" % ("B" if rail_y < 0.0 else "T"), Vector3(1.02, 0.10, 0.10), Vector3(0.0, rail_y, 0.49), "crate_dark", palette, false)
	for rail_x in [-0.43, 0.43]:
		_add_box(crate, "CrateRailV%s" % ("L" if rail_x < 0.0 else "R"), Vector3(0.10, 0.92, 0.10), Vector3(rail_x, 0.0, 0.49), "crate_dark", palette, false)
	for diagonal in [-1.0, 1.0]:
		var brace := _add_box(crate, "CrateBrace%s" % ("L" if diagonal < 0.0 else "R"), Vector3(1.08, 0.09, 0.08), Vector3(0.0, 0.0, 0.55), "crate_dark", palette, false)
		brace.rotation.z = diagonal * 0.70


func _build_pipe_manifold(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "PipeManifoldBackboard", Vector3(2.35, 2.45, 0.12), Vector3(0.0, 1.25, -0.16), "backrooms_beige", palette, false)
	for pipe_index in 3:
		var x := -0.72 + float(pipe_index) * 0.72
		var pipe := _add_low_poly_cylinder(parent, "ManifoldPipeV%02d" % pipe_index, 0.10, 0.10, 2.20, 10, "pipe_metal", palette)
		pipe.position = Vector3(x, 1.25, 0.02)
	var cross_pipe := _add_low_poly_cylinder(parent, "ManifoldPipeCross", 0.12, 0.12, 1.82, 10, "pipe_metal", palette)
	cross_pipe.position = Vector3(0.0, 1.42, 0.03)
	cross_pipe.rotation.z = PI * 0.5
	for valve_index in 2:
		_build_valve_wheel(parent, "PipeValveWheel%02d" % valve_index, Vector3(-0.36 + float(valve_index) * 0.72, 1.42, 0.24), 0.28, palette)
	var gauge := _add_low_poly_cylinder(parent, "PipePressureGauge", 0.28, 0.28, 0.10, 14, "fluorescent", palette)
	gauge.position = Vector3(0.72, 2.05, 0.16)
	gauge.rotation.x = PI * 0.5
	var gauge_needle := _add_box(parent, "PipeGaugeNeedle", Vector3(0.04, 0.22, 0.05), Vector3(0.72, 2.08, 0.23), "indicator_red", palette, false)
	gauge_needle.rotation.z = -0.55
	_add_box(parent, "PipeDrainTray", Vector3(2.45, 0.16, 0.78), Vector3(0.0, 0.08, 0.05), "fixture_metal", palette, false)


func _build_valve_wheel(parent: Node3D, node_name: String, center: Vector3, radius: float, palette: Dictionary) -> void:
	var wheel := Node3D.new()
	wheel.name = node_name
	wheel.position = center
	parent.add_child(wheel)
	for segment_index in 8:
		var angle := TAU * float(segment_index) / 8.0
		var segment := _add_box(wheel, "ValveRim%02d" % segment_index, Vector3(0.25, 0.055, 0.07), Vector3(cos(angle) * radius, sin(angle) * radius, 0.0), "indicator_red", palette, false)
		segment.rotation.z = angle + PI * 0.5
	var hub := _add_low_poly_cylinder(wheel, "ValveHub", 0.09, 0.09, 0.10, 10, "indicator_red", palette)
	hub.rotation.x = PI * 0.5
	for spoke_index in 4:
		var spoke := _add_box(wheel, "ValveSpoke%02d" % spoke_index, Vector3(radius * 1.65, 0.045, 0.05), Vector3.ZERO, "indicator_red", palette, false)
		spoke.rotation.z = PI * 0.25 * float(spoke_index)


func _add_low_poly_cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, radial_segments: int, role: String, palette: Dictionary) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	mesh.rings = 1
	mesh_instance.mesh = mesh
	mesh_instance.set_meta("theme_role", role)
	mesh_instance.material_override = _material(role, palette, true)
	parent.add_child(mesh_instance)
	return mesh_instance


func _build_suspense_layer(parent: Node3D, palette: Dictionary) -> void:
	if built_floor == 2:
		_build_floor_two_disc_suspense(parent, palette)
		return
	var suspense := Node3D.new()
	suspense.name = "SuspenseOcclusion"
	suspense.set_meta("slow_burn_suspense", true)
	parent.add_child(suspense)
	var occluder_count := clampi(int(round(map_length / 42.0)), 5, 10)
	var usable_span := map_length - 44.0
	var threshold_spacing := usable_span / float(occluder_count + 1)
	var screen_width := 1.5
	var screen_center_x := SUSPENSE_CLEAR_PATH_WIDTH * 0.5 + screen_width * 0.5
	var screen_role := "white_wall" if district_style == "overgrown_gallery" else "wall_dark"
	for threshold_index in occluder_count:
		var side := -1.0 if threshold_index % 2 == 0 else 1.0
		var threshold_z := -usable_span * 0.5 + threshold_spacing * float(threshold_index + 1)
		if district_style == "sunlit_brick_street" and absf(threshold_z) < 12.0:
			threshold_z += -14.0 if threshold_z < 0.0 else 14.0
		var controlled_anomaly := threshold_index == int(floor(float(occluder_count) * 0.67))
		var screen_height := 2.25 if controlled_anomaly else 3.05
		var screen := _add_box(
			suspense,
			"SightlineScreen%02d" % threshold_index,
			Vector3(screen_width, screen_height, 0.34),
			Vector3(side * screen_center_x, screen_height * 0.5, threshold_z + (1.15 if controlled_anomaly else 0.0)),
			screen_role,
			palette,
			true
		)
		screen.set_meta("suspense_occluder", true)
		screen.set_meta("clear_path_width", SUSPENSE_CLEAR_PATH_WIDTH)
		screen.set_meta("controlled_repeat_anomaly", controlled_anomaly)
		var lintel := _add_box(
			suspense,
			"RepeatedLintel%02d" % threshold_index,
			Vector3(SUSPENSE_CLEAR_PATH_WIDTH + 0.24, 0.18, 0.34),
			Vector3(0.0, 3.18, threshold_z),
			"wall_dark" if controlled_anomaly else screen_role,
			palette,
			false
		)
		lintel.set_meta("architectural_repeat", true)
		lintel.set_meta("controlled_repeat_anomaly", controlled_anomaly)

	var light_count := clampi(int(ceil(float(occluder_count) * 0.5)), 3, 5)
	for light_index in light_count:
		var progress := float(light_index + 1) / float(light_count + 1)
		var light_z := lerpf(-usable_span * 0.5, usable_span * 0.5, progress)
		var warm_exception := light_index == light_count - 2
		var light_x := -1.9 if light_index % 2 == 0 else 1.9
		_add_box(
			suspense,
			"SuspenseFixture%02d" % light_index,
			Vector3(0.82, 0.12, 0.28),
			Vector3(light_x, 3.12, light_z),
			"lamp_light",
			palette,
			false
		)
		var pool := OmniLight3D.new()
		pool.name = "SuspenseLight%02d" % light_index
		pool.position = Vector3(light_x, 2.78, light_z)
		pool.light_color = Color("D0A572") if warm_exception else Color("9DB9B4")
		pool.light_energy = 0.42 if warm_exception else 0.58
		pool.omni_range = 12.5
		pool.shadow_enabled = light_index % 2 == 0
		pool.set_meta("temperature_exception", warm_exception)
		suspense.add_child(pool)
	set_meta("suspense_occluder_count", occluder_count)
	set_meta("suspense_light_count", light_count)
	set_meta("controlled_repeat_count", occluder_count * 2 + 1)
	set_meta("jump_scare_trigger_count", 0)
	set_meta("minimum_clear_path_width", SUSPENSE_CLEAR_PATH_WIDTH)
	set_meta("suspense_occlusion_rule", "alternating_side_screens")


func _build_floor_two_disc_suspense(parent: Node3D, palette: Dictionary) -> void:
	var suspense := Node3D.new()
	suspense.name = "SuspenseOcclusion"
	suspense.set_meta("slow_burn_suspense", true)
	suspense.set_meta("scattered_across_disc", true)
	parent.add_child(suspense)
	var occluder_count := 7
	for threshold_index in occluder_count:
		var angle := 0.42 + TAU * float(threshold_index) / float(occluder_count) + sin(float(threshold_index) * 1.9) * 0.18
		var radial_ratio := 0.34 + float(posmod(threshold_index * 3, 5)) * 0.095
		var controlled_anomaly := threshold_index == 4
		var screen_height := 2.2 if controlled_anomaly else 3.0
		var screen_position := _floor_two_disc_point(angle, radial_ratio)
		screen_position.y += screen_height * 0.5
		var screen := _add_box(
			suspense,
			"SightlineScreen%02d" % threshold_index,
			Vector3(1.5, screen_height, 0.34),
			screen_position,
			"wall_dark",
			palette,
			true
		)
		screen.rotation.y = -angle + PI * 0.5
		screen.set_meta("suspense_occluder", true)
		screen.set_meta("clear_path_width", SUSPENSE_CLEAR_PATH_WIDTH)
		screen.set_meta("controlled_repeat_anomaly", controlled_anomaly)
		var lintel_position := _floor_two_disc_point(angle, radial_ratio)
		lintel_position.y += 3.15
		var lintel := _add_box(
			suspense,
			"RepeatedLintel%02d" % threshold_index,
			Vector3(SUSPENSE_CLEAR_PATH_WIDTH + 0.24, 0.18, 0.34),
			lintel_position,
			"dream_cyan" if controlled_anomaly else "wall_dark",
			palette,
			false
		)
		lintel.rotation.y = -angle + PI * 0.5
		lintel.set_meta("architectural_repeat", true)
		lintel.set_meta("controlled_repeat_anomaly", controlled_anomaly)

	var light_count := 7
	for light_index in light_count:
		var angle := PI * 0.5 + TAU * float(light_index) / float(light_count)
		var radial_ratio := 0.82 if light_index == 0 else 0.32 + float(posmod(light_index * 4, 6)) * 0.09
		var light_position := _floor_two_disc_point(angle, radial_ratio)
		light_position.y += 2.9
		_add_box(suspense, "SuspenseFixture%02d" % light_index, Vector3(0.72, 0.12, 0.28), light_position, "lamp_light", palette, false)
		var pool := OmniLight3D.new()
		pool.name = "SuspenseLight%02d" % light_index
		pool.position = light_position
		pool.light_color = Color("B07B55") if light_index == 1 else Color("668783")
		pool.light_energy = 1.25 if light_index == 1 else 1.65
		pool.omni_range = 22.0
		pool.shadow_enabled = light_index == 0
		pool.set_meta("temperature_exception", light_index == 1)
		suspense.add_child(pool)
	set_meta("suspense_occluder_count", occluder_count)
	set_meta("suspense_light_count", light_count)
	set_meta("controlled_repeat_count", occluder_count * 2 + 1)
	set_meta("jump_scare_trigger_count", 0)
	set_meta("minimum_clear_path_width", SUSPENSE_CLEAR_PATH_WIDTH)
	set_meta("suspense_occlusion_rule", "scattered_disc_thresholds")


func _new_room(parent: Node3D, room_index: int) -> Node3D:
	var room := Node3D.new()
	room.name = "Room%02d" % room_index
	room.set_meta("room_index", room_index)
	room.set_meta("street_lot", true)
	room.set_meta("logical_room", true)
	room.set_meta("district_style", district_style)
	parent.add_child(room)
	return room


func _place_room_reward(room: Node3D, room_index: int, position: Vector3, palette: Dictionary) -> void:
	if (room_index + built_floor) % 4 == 0:
		_add_box(room, "EmptyPlinth", Vector3(0.72, 0.42, 0.72), position + Vector3(0.0, 0.21, 0.0), "wall_dark", palette, false)


func _build_street_lamp(parent: Node3D, position: Vector3, palette: Dictionary, daylight: bool) -> void:
	var lamp := Node3D.new()
	lamp.name = "StreetLamp"
	lamp.position = position
	parent.add_child(lamp)
	_add_box(lamp, "Pole", Vector3(0.12, 4.6, 0.12), Vector3(0.0, 2.3, 0.0), "lamp", palette, false)
	_add_box(lamp, "Head", Vector3(0.58, 0.18, 0.30), Vector3(0.0, 4.54, -0.12), "lamp_light", palette, false)
	if not daylight:
		var light := OmniLight3D.new()
		light.name = "WarmPool"
		light.position = Vector3(0.0, 4.2, 0.0)
		light.light_color = Color("FFB54A")
		light.light_energy = 2.4
		light.omni_range = 7.5
		light.shadow_enabled = false
		lamp.add_child(light)


func _build_mood_panel(parent: Node3D, room_index: int, position: Vector3, side: float, _palette: Dictionary) -> void:
	var texture_path: String = str(MOOD_TEXTURE_PATHS[posmod(room_index + built_floor * 2, MOOD_TEXTURE_PATHS.size())])
	var texture := _load_runtime_texture(texture_path)
	if texture == null:
		return
	var panel := MeshInstance3D.new()
	panel.name = "MemoryPanel%02d" % room_index
	var quad := QuadMesh.new()
	quad.size = Vector2(2.35, 2.35)
	panel.mesh = quad
	panel.position = position
	panel.rotation_degrees.y = -90.0 * side
	panel.set_meta("mood_texture", texture_path)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission_texture = material.albedo_texture
	material.emission_energy_multiplier = 0.45
	panel.material_override = material
	parent.add_child(panel)


func _grass_blade_mesh(width: float, height: float, tip_offset: float) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	for blade_index in 4:
		var angle := PI * 0.25 * float(blade_index)
		var right := Vector3(cos(angle), 0.0, sin(angle)) * width * 0.5
		var offset := Vector3(cos(angle + PI * 0.5), 0.0, sin(angle + PI * 0.5)) * (0.055 + float(blade_index % 2) * 0.035)
		vertices.append(offset - right + Vector3(0.0, -height * 0.5, 0.0))
		vertices.append(offset + right + Vector3(0.0, -height * 0.5, 0.0))
		vertices.append(offset + Vector3(cos(angle) * tip_offset, height * 0.5, sin(angle) * tip_offset))
		uvs.append_array(PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(0.5, 0.0)]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_reference_portal(parent: Node3D, texture_path: String, _palette: Dictionary) -> void:
	var texture := _load_runtime_texture(texture_path)
	if texture == null:
		return
	var aspect := float(texture.get_width()) / maxf(1.0, float(texture.get_height()))
	var portal_width := 12.8
	if district_style == "night_white_blocks":
		portal_width = 10.8
	elif district_style == "overgrown_gallery":
		portal_width = 8.2
	portal_width = minf(portal_width, map_width - 5.0)
	var portal_height := minf(16.0, portal_width / aspect)
	var portal := MeshInstance3D.new()
	portal.name = "ReferencePortal"
	var quad := QuadMesh.new()
	quad.size = Vector2(portal_width, portal_height)
	portal.mesh = quad
	portal.position = Vector3(0.0, portal_height * 0.5, -map_length * 0.5 + 0.32)
	portal.set_meta("reference_texture", texture_path)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.emission_enabled = true
	material.emission_texture = texture
	material.emission_energy_multiplier = 0.28
	portal.material_override = material
	parent.add_child(portal)


func _load_runtime_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		var resource := load(path) as Texture2D
		if resource != null:
			return resource
	var image := Image.load_from_file(ProjectSettings.globalize_path(path))
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


func _build_road_markings(parent: Node3D, palette: Dictionary) -> void:
	var stripe_count := int(floor(map_length / 4.8))
	for stripe_index in stripe_count:
		var z := -map_length * 0.5 + 2.8 + float(stripe_index) * 4.8
		_add_box(parent, "SignalStripe%02d" % stripe_index, Vector3(0.14, 0.018, 2.1), Vector3(0.0, 0.028, z), "accent", palette, false)
	for side in [-1.0, 1.0]:
		for marker_index in 3:
			var z := -6.0 + float(marker_index) * 6.0
			_add_box(
				parent,
				"PlazaMark%s%d" % ["W" if side < 0.0 else "E", marker_index],
				Vector3(1.8, 0.018, 0.10),
				Vector3(side * 5.4, 0.029, z),
				"accent",
				palette,
				false
			)


func _build_street_lot(parent: Node3D, room_index: int, center: Vector3, side: float, palette: Dictionary) -> void:
	var room := Node3D.new()
	room.name = "Room%02d" % room_index
	room.set_meta("room_index", room_index)
	room.set_meta("street_lot", true)
	parent.add_child(room)

	var facade_height := WALL_HEIGHT + float((room_index + built_floor) % 3) * 0.55
	_add_box(room, "LotPad", Vector3(LOT_DEPTH, 0.045, LOT_WIDTH), center + Vector3(0.0, 0.025, 0.0), "lot_floor", palette, false)
	_add_box(
		room,
		"BackFacade",
		Vector3(0.34, facade_height, LOT_WIDTH),
		center + Vector3(side * LOT_DEPTH * 0.5, facade_height * 0.5, 0.0),
		"wall_dark" if room_index % 2 == 0 else "wall",
		palette,
		true
	)
	_add_box(
		room,
		"Canopy",
		Vector3(LOT_DEPTH * 0.72, 0.14, LOT_WIDTH * 0.68),
		center + Vector3(side * 0.70, 2.55 + float(room_index % 2) * 0.22, 0.0),
		"ceiling",
		palette,
		true
	)
	for edge in [-1.0, 1.0]:
		_add_box(
			room,
			"Frame%s" % ("North" if edge < 0.0 else "South"),
			Vector3(0.28, 2.55, 0.28),
			center + Vector3(-side * (LOT_DEPTH * 0.5 - 0.72), 1.275, edge * (LOT_WIDTH * 0.34)),
			"accent",
			palette,
			true
		)

	if (room_index + built_floor) % 4 == 0:
		_add_box(room, "EmptyPlinth", Vector3(0.72, 0.42, 0.72), center + Vector3(-side * 1.25, 0.21, 0.14), "wall_dark", palette, false)


func _build_air_walls(parent: Node3D) -> void:
	var walls := Node3D.new()
	walls.name = "AirWalls"
	parent.add_child(walls)
	if built_floor == 2:
		_build_floor_two_disc_air_walls(walls)
		return
	if district_style == "sunlit_brick_street":
		_build_sunlit_air_walls(walls)
		return
	_add_air_wall(walls, "WestAirWall", Vector3(AIR_WALL_THICKNESS, AIR_WALL_HEIGHT, map_length + AIR_WALL_THICKNESS * 2.0), Vector3(-map_width * 0.5, AIR_WALL_HEIGHT * 0.5, 0.0))
	_add_air_wall(walls, "EastAirWall", Vector3(AIR_WALL_THICKNESS, AIR_WALL_HEIGHT, map_length + AIR_WALL_THICKNESS * 2.0), Vector3(map_width * 0.5, AIR_WALL_HEIGHT * 0.5, 0.0))
	_add_air_wall(walls, "NorthAirWall", Vector3(map_width, AIR_WALL_HEIGHT, AIR_WALL_THICKNESS), Vector3(0.0, AIR_WALL_HEIGHT * 0.5, -map_length * 0.5))
	_add_air_wall(walls, "SouthAirWall", Vector3(map_width, AIR_WALL_HEIGHT, AIR_WALL_THICKNESS), Vector3(0.0, AIR_WALL_HEIGHT * 0.5, map_length * 0.5))


func _build_floor_two_disc_air_walls(walls: Node3D) -> void:
	for segment_index in FLOOR_TWO_DISC_AIR_WALL_SEGMENTS:
		var angle_a := TAU * float(segment_index) / float(FLOOR_TWO_DISC_AIR_WALL_SEGMENTS)
		var angle_b := TAU * float(segment_index + 1) / float(FLOOR_TWO_DISC_AIR_WALL_SEGMENTS)
		var point_a := _floor_two_disc_point(angle_a, 1.0)
		var point_b := _floor_two_disc_point(angle_b, 1.0)
		var flat_delta := Vector2(point_b.x - point_a.x, point_b.z - point_a.z)
		var center := (point_a + point_b) * 0.5
		center.y = maxf(point_a.y, point_b.y) + AIR_WALL_HEIGHT * 0.5
		var wall := _add_air_wall(
			walls,
			"DiscAirWall%02d" % segment_index,
			Vector3(flat_delta.length() + 0.5, AIR_WALL_HEIGHT, AIR_WALL_THICKNESS),
			center
		)
		wall.rotation.y = -atan2(flat_delta.y, flat_delta.x)


func _build_sunlit_air_walls(walls: Node3D) -> void:
	var trunk_segment_length := (map_length - SUNLIT_CROSSROAD_OPENING) * 0.5
	for side in [-1.0, 1.0]:
		var side_name := "West" if side < 0.0 else "East"
		for direction in [-1.0, 1.0]:
			var section_name := "North" if direction < 0.0 else "South"
			var center_z: float = direction * (SUNLIT_CROSSROAD_OPENING * 0.5 + trunk_segment_length * 0.5)
			_add_air_wall(
				walls,
				"%s%sAirWall" % [side_name, section_name],
				Vector3(AIR_WALL_THICKNESS, AIR_WALL_HEIGHT, trunk_segment_length),
				Vector3(side * map_width * 0.5, AIR_WALL_HEIGHT * 0.5, center_z)
			)
	for direction in [-1.0, 1.0]:
		var end_name := "North" if direction < 0.0 else "South"
		_add_air_wall(
			walls,
			"%sAirWall" % end_name,
			Vector3(map_width, AIR_WALL_HEIGHT, AIR_WALL_THICKNESS),
			Vector3(0.0, AIR_WALL_HEIGHT * 0.5, direction * map_length * 0.5)
		)
	var arm_center_offset := map_width * 0.5 + SUNLIT_CROSSROAD_ARM_LENGTH * 0.5
	for direction in [-1.0, 1.0]:
		var direction_name := "West" if direction < 0.0 else "East"
		for side in [-1.0, 1.0]:
			var side_name := "North" if side < 0.0 else "South"
			_add_air_wall(
				walls,
				"%sBranch%sAirWall" % [direction_name, side_name],
				Vector3(SUNLIT_CROSSROAD_ARM_LENGTH, AIR_WALL_HEIGHT, AIR_WALL_THICKNESS),
				Vector3(direction * arm_center_offset, AIR_WALL_HEIGHT * 0.5, side * SUNLIT_CROSSROAD_OPENING * 0.5)
			)
		_add_air_wall(
			walls,
			"%sBranchEndAirWall" % direction_name,
			Vector3(AIR_WALL_THICKNESS, AIR_WALL_HEIGHT, SUNLIT_CROSSROAD_OPENING),
			Vector3(direction * _sunlit_crossroad_span() * 0.5, AIR_WALL_HEIGHT * 0.5, 0.0)
		)


func _add_air_wall(parent: Node3D, node_name: String, size: Vector3, position: Vector3) -> StaticBody3D:
	var wall := StaticBody3D.new()
	wall.name = node_name
	wall.position = position
	wall.collision_layer = 1
	wall.collision_mask = 1
	wall.set_meta("air_wall", true)
	parent.add_child(wall)
	var collision := CollisionShape3D.new()
	collision.name = "Collision"
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	return wall


func _prerequisite_item_position_for_floor() -> Vector3:
	match built_floor:
		1:
			var lot_rows := int(ceil(float(room_count) / 2.0))
			var first_row_z := float(lot_rows - 1) * LOT_SPACING * 0.5
			return clamp_to_playable_position(Vector3(STREET_WIDTH * 0.5 - 1.05, 0.08, first_row_z - 2.6), 2.0)
		2:
			var house_front := _floor_two_disc_point(3.55, 0.50)
			house_front.y += 0.10
			return _clamp_to_floor_two_disc(house_front, 3.0)
		3:
			var false_window_z := lerpf(-map_length * 0.38, map_length * 0.38, 1.0 / 19.0)
			return clamp_to_playable_position(Vector3(-4.15, 0.10, false_window_z + 0.35), 2.0)
		_:
			return clamp_to_playable_position(start_position() + Vector3(0.0, 0.0, -18.0), 2.0)


func _build_prerequisite_items(items: Array, display_names: Dictionary, palette: Dictionary) -> void:
	for item_data in items:
		if not item_data is Dictionary:
			continue
		var entry: Dictionary = item_data
		if str(entry.get("kind", "")) != "prerequisite":
			continue
		var item_id := str(entry.get("id", "")).strip_edges()
		if item_id.is_empty() or built_floor > 3:
			continue
		_build_prerequisite_item(item_id, str(display_names.get(item_id, "未登记物")), palette)


func _build_prerequisite_item(item_id: String, display_name: String, palette: Dictionary) -> void:
	useful_item_count += 1
	var item := Area3D.new()
	item.name = "PrerequisiteItemFloor%d" % built_floor
	item.position = _prerequisite_item_position_for_floor()
	item.collision_layer = 2
	item.collision_mask = 0
	item.visible = false
	item.monitoring = false
	item.monitorable = false
	item.set_meta("prerequisite_item", true)
	item.set_meta("revealed", false)
	item.set_meta("collected", false)
	item.set_meta("item_id", item_id)
	item.set_meta("display_name", display_name)
	item.set_meta("item_effect", "prerequisite")
	item.set_meta("item_value", built_floor)
	item.set_meta("item_description", "这不是奖励。它只是证明你来过这里。")
	item.set_meta("reachable_spawn", true)
	item.set_meta("spawn_floor", built_floor)
	add_child(item)
	_items.append(item)

	var halo := MeshInstance3D.new()
	halo.name = "SearchHalo"
	var halo_mesh := CylinderMesh.new()
	halo_mesh.top_radius = 0.48
	halo_mesh.bottom_radius = 0.48
	halo_mesh.height = 0.025
	halo_mesh.radial_segments = 24
	halo.mesh = halo_mesh
	halo.position.y = 0.055
	halo.set_meta("theme_role", "item")
	halo.material_override = _material("item", palette, true)
	item.add_child(halo)

	match built_floor:
		1:
			_build_nameplate_prerequisite(item, palette)
		2:
			_build_cassette_prerequisite(item, palette)
		3:
			_build_page_prerequisite(item, palette)

	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := SphereShape3D.new()
	shape.radius = 0.72
	collision.shape = shape
	collision.position.y = 0.62
	item.add_child(collision)

	var glow := OmniLight3D.new()
	glow.name = "SearchGlow"
	glow.position.y = 0.72
	glow.light_color = _role_color("item", palette)
	glow.light_energy = 0.52
	glow.omni_range = 2.4
	glow.shadow_enabled = false
	item.add_child(glow)


func _build_nameplate_prerequisite(parent: Node3D, palette: Dictionary) -> void:
	var plate := _add_box(parent, "OldNameplate", Vector3(0.72, 0.34, 0.055), Vector3(0.0, 0.72, 0.0), "surface", palette, false)
	plate.rotation.x = deg_to_rad(-8.0)
	for line_index in 2:
		_add_box(parent, "NameStroke%d" % line_index, Vector3(0.46 - float(line_index) * 0.12, 0.035, 0.025), Vector3(-0.04, 0.77 - float(line_index) * 0.11, -0.04), "ink", palette, false)
	var pin := MeshInstance3D.new()
	pin.name = "BentPin"
	var pin_mesh := CylinderMesh.new()
	pin_mesh.top_radius = 0.035
	pin_mesh.bottom_radius = 0.035
	pin_mesh.height = 0.42
	pin_mesh.radial_segments = 8
	pin.mesh = pin_mesh
	pin.position = Vector3(-0.32, 0.90, 0.0)
	pin.rotation.z = deg_to_rad(-24.0)
	pin.material_override = _material("fixture_metal", palette, false)
	parent.add_child(pin)


func _build_cassette_prerequisite(parent: Node3D, palette: Dictionary) -> void:
	_add_box(parent, "CassetteBody", Vector3(0.78, 0.48, 0.14), Vector3(0.0, 0.66, 0.0), "wall_dark", palette, false)
	_add_box(parent, "CassetteLabel", Vector3(0.60, 0.20, 0.025), Vector3(0.0, 0.72, -0.085), "surface", palette, false)
	for spool_index in 2:
		var spool := MeshInstance3D.new()
		spool.name = "TapeSpool%d" % spool_index
		var spool_mesh := CylinderMesh.new()
		spool_mesh.top_radius = 0.10
		spool_mesh.bottom_radius = 0.10
		spool_mesh.height = 0.035
		spool_mesh.radial_segments = 16
		spool.mesh = spool_mesh
		spool.position = Vector3(-0.19 + float(spool_index) * 0.38, 0.72, -0.11)
		spool.rotation.x = PI * 0.5
		spool.material_override = _material("item", palette, true)
		parent.add_child(spool)


func _build_page_prerequisite(parent: Node3D, palette: Dictionary) -> void:
	var page := _add_box(parent, "MissingSubjectPage", Vector3(0.56, 0.74, 0.035), Vector3(0.0, 0.72, 0.0), "surface", palette, false)
	page.rotation.z = deg_to_rad(7.0)
	for line_index in 5:
		var line_width := 0.34 if line_index != 0 else 0.18
		_add_box(parent, "PageLine%d" % line_index, Vector3(line_width, 0.025, 0.018), Vector3(-0.04, 0.94 - float(line_index) * 0.11, -0.03), "ink", palette, false)


func _build_actors(actor_textures: Dictionary, people: Array, display_names: Dictionary) -> void:
	var actors := Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	var spawn := start_position()
	var key_npc_texture := actor_textures.get("key_npc") as Texture2D
	var npc_textures: Array = actor_textures.get("npcs", [])
	var fallback_texture := key_npc_texture
	if not npc_textures.is_empty() and npc_textures[0] is Texture2D:
		fallback_texture = npc_textures[0]
	var doll_texture := actor_textures.get("doll") as Texture2D
	var pedestrian_index := 0
	for person_data in people:
		if not person_data is Dictionary:
			continue
		var person: Dictionary = person_data
		var person_id := str(person.get("id", ""))
		var kind := str(person.get("kind", ""))
		var label := str(display_names.get(person_id, ""))
		match kind:
			"key_npc":
				var key_npc_position := Vector3(-3.4, 0.0, spawn.z - 8.0)
				if built_floor == 2:
					key_npc_position = _floor_two_disc_point(PI * 0.5 + 0.12, 0.72)
				if label.is_empty():
					label = "关键住户"
				var key_npc := _make_actor("KeyNPC", "key_npc", label, key_npc_position, key_npc_texture if key_npc_texture != null else fallback_texture, built_floor - 1)
				key_npc.set_meta("actor_id", person_id)
				actors.add_child(key_npc)
				_actors.append(key_npc)
			"doll":
				if doll_texture == null or person_id.is_empty():
					continue
				var doll := _make_doll_actor(person_id, label, _doll_position_for_floor(spawn), doll_texture)
				actors.add_child(doll)
				_actors.append(doll)
				set_meta("doll_encounter_count", 1)
			"npc":
				var actor_position := _pedestrian_position(pedestrian_index, ordinary_npc_count)
				var npc_texture: Texture2D = fallback_texture
				if not npc_textures.is_empty() and npc_textures[pedestrian_index % npc_textures.size()] is Texture2D:
					npc_texture = npc_textures[pedestrian_index % npc_textures.size()]
				var actor := _make_actor("NPC%d" % pedestrian_index, "npc", label, actor_position, npc_texture, pedestrian_index % 3)
				actor.set_meta("actor_id", person_id)
				actor.set_meta("language_bridge_actor", false)
				actors.add_child(actor)
				_actors.append(actor)
				pedestrian_index += 1


func _pedestrian_position(index: int, pedestrian_count: int) -> Vector3:
	var street_south := map_length * 0.5 - 12.5
	var street_north := -map_length * 0.5 + 8.0
	var lateral_positions := [3.4, -3.0, 1.6, -3.3, 0.5]
	if built_floor == 2:
		var disc_angle := 0.72 + TAU * float(index + 1) / float(pedestrian_count + 2) + sin(float(index) * 1.7) * 0.16
		var disc_radius := 0.30 + float(posmod(index * 3, 4)) * 0.14
		return _floor_two_disc_point(disc_angle, disc_radius)
	var progress := float(index + 1) / float(pedestrian_count + 1)
	return Vector3(
		float(lateral_positions[index % lateral_positions.size()]),
		0.0,
		lerpf(street_south, street_north, progress)
	)


func _count_kind(people: Array, kind: String) -> int:
	var count := 0
	for person_data in people:
		if person_data is Dictionary and str((person_data as Dictionary).get("kind", "")) == kind:
			count += 1
	return count


func _doll_position_for_floor(spawn: Vector3) -> Vector3:
	match built_floor:
		1:
			return clamp_to_playable_position(spawn + Vector3(5.2, 0.0, -17.0), 3.0)
		2:
			return _floor_two_disc_point(5.34, 0.46)
		3:
			return clamp_to_playable_position(spawn + Vector3(-4.8, 0.0, -24.0), 3.0)
	return spawn


func _make_doll_actor(doll_id: String, display_name: String, doll_position: Vector3, doll_texture: Texture2D) -> Area3D:
	var doll := Area3D.new()
	doll.name = "DollEncounter"
	doll.position = doll_position
	doll.collision_layer = 2
	doll.collision_mask = 0
	doll.set_meta("actor_id", doll_id)
	doll.set_meta("actor_type", "doll")
	doll.set_meta("display_name", display_name if not display_name.is_empty() else "缝线布偶")
	doll.set_meta("doll_id", doll_id)
	doll.set_meta("guide_character", true)
	doll.set_meta("discovery_style", "partially_hidden_near_existing_cover")
	doll.set_meta("world_hint", "")
	doll.set_meta("claimed", false)
	doll.set_meta("face_veil", false)
	doll.set_meta("camera_facing_layer", true)
	doll.set_meta("portrait_world_height", DOLL_PORTRAIT_WORLD_HEIGHT)

	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var shape := CapsuleShape3D.new()
	shape.radius = 0.48
	shape.height = 1.12
	collision.shape = shape
	collision.position.y = 0.54
	doll.add_child(collision)

	var sprite := Sprite3D.new()
	sprite.name = "Billboard"
	sprite.texture = doll_texture
	var source_height := float(doll_texture.get_height())
	sprite.pixel_size = DOLL_PORTRAIT_WORLD_HEIGHT / maxf(1.0, source_height)
	sprite.position.y = DOLL_PORTRAIT_WORLD_HEIGHT * 0.5
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = 2
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.set_meta("camera_facing_layer", true)
	sprite.set_meta("user_authored_guide_asset", true)
	doll.add_child(sprite)
	return doll


func _make_actor(node_name: String, actor_type: String, display_name: String, position: Vector3, npc_texture: Texture2D, tint_index: int) -> Area3D:
	var actor := Area3D.new()
	var face_center := Vector2(0.5, 0.18)
	actor.name = node_name
	actor.position = position
	actor.collision_layer = 2
	actor.collision_mask = 0
	actor.set_meta("actor_id", "%s_%d_%s" % [actor_type, built_floor, node_name.to_lower()])
	actor.set_meta("actor_type", actor_type)
	actor.set_meta("display_name", display_name)
	actor.set_meta("tint_index", tint_index)
	actor.set_meta("face_veil", true)
	actor.set_meta("face_veil_style", "separate_animated_marker_overlay")
	actor.set_meta("face_veil_mode", tint_index % 3)
	actor.set_meta("face_identity_readable", false)
	actor.set_meta("face_effect_separate_layer", true)
	actor.set_meta("base_character_texture_preserved", true)
	actor.set_meta("portrait_pose", "front_eye_level")
	actor.set_meta("portrait_world_height", ACTOR_PORTRAIT_WORLD_HEIGHT)
	actor.set_meta("camera_eye_height", ACTOR_CAMERA_EYE_HEIGHT)
	actor.set_meta("face_center_world_y", ACTOR_PORTRAIT_WORLD_HEIGHT * (1.0 - face_center.y))
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.58
	capsule.height = 2.0
	collision.shape = capsule
	collision.position.y = 1.0
	actor.add_child(collision)

	var sprite := Sprite3D.new()
	sprite.name = "Billboard"
	sprite.texture = npc_texture
	var source_height := float(npc_texture.get_height()) if npc_texture != null else 1536.0
	sprite.pixel_size = ACTOR_PORTRAIT_WORLD_HEIGHT / maxf(1.0, source_height)
	sprite.position.y = ACTOR_PORTRAIT_WORLD_HEIGHT * 0.5
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.shaded = false
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.render_priority = 0
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	sprite.modulate = Color.WHITE
	sprite.set_meta("camera_facing_layer", true)
	sprite.set_meta("floor_independent_color", true)
	sprite.set_meta("front_eye_level", true)
	actor.add_child(sprite)

	var scribble_overlay := Sprite3D.new()
	scribble_overlay.name = "FaceScribbleOverlay"
	scribble_overlay.texture = npc_texture
	scribble_overlay.pixel_size = sprite.pixel_size
	scribble_overlay.position = sprite.position
	scribble_overlay.scale = sprite.scale
	scribble_overlay.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	scribble_overlay.shaded = false
	scribble_overlay.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	scribble_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scribble_overlay.render_priority = 8
	scribble_overlay.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	scribble_overlay.double_sided = true
	scribble_overlay.modulate = Color.WHITE
	scribble_overlay.set_meta("separate_face_effect", true)
	scribble_overlay.set_meta("camera_facing_layer", true)
	scribble_overlay.set_meta("always_above_character_layer", true)
	var scribble_material := ShaderMaterial.new()
	scribble_material.shader = NPC_FACE_SCRIBBLE_OVERLAY_SHADER
	scribble_material.render_priority = 8
	scribble_material.set_shader_parameter("character_texture", npc_texture)
	scribble_material.set_shader_parameter("scribble_atlas", NPC_FACE_SCRIBBLE_ATLAS)
	scribble_material.set_shader_parameter("ink_color", Color("020202"))
	scribble_material.set_shader_parameter("ink_opacity", 1.0)
	scribble_material.set_shader_parameter("brush_width_px", 56.0)
	scribble_material.set_shader_parameter("face_center", face_center)
	scribble_material.set_shader_parameter("face_size", Vector2(0.16, 0.09))
	scribble_material.set_shader_parameter("variation", float(tint_index % 3))
	scribble_material.set_shader_parameter("seed", float(built_floor * 17 + tint_index * 7))
	scribble_overlay.material_override = scribble_material
	actor.add_child(scribble_overlay)
	return actor


func _add_box(parent: Node3D, node_name: String, size: Vector3, position: Vector3, role: String, palette: Dictionary, with_collision: bool) -> Node3D:
	var holder: Node3D
	if with_collision:
		holder = StaticBody3D.new()
	else:
		holder = Node3D.new()
	holder.name = node_name
	holder.position = position
	parent.add_child(holder)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.set_meta("theme_role", role)
	mesh_instance.material_override = _material(role, palette, false)
	holder.add_child(mesh_instance)
	if with_collision:
		var collision := CollisionShape3D.new()
		collision.name = "Collision"
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		holder.add_child(collision)
	return holder


func _material(role: String, palette: Dictionary, emission: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = _role_color(role, palette)
	material.roughness = 0.94
	material.metallic = 0.0
	if role in ["fixture_metal", "cart_metal", "chair_metal", "pipe_metal"]:
		material.roughness = 0.58
		material.metallic = 0.54
	if role == "grass":
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if role == "night_path" and built_floor == 2:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		material.emission_enabled = true
		material.emission = Color("28453A")
		material.emission_energy_multiplier = 0.78
	if emission or role in ["lamp_light", "screen_glow", "fluorescent"]:
		material.emission_enabled = true
		material.emission = _role_color(role, palette)
		material.emission_energy_multiplier = 1.18 if role in ["screen_glow", "fluorescent"] else 1.6
	return material


func _role_color(role: String, palette: Dictionary) -> Color:
	match role:
		"brick":
			return Color("D7B77F").lerp(_color(palette, "surface"), 0.12)
		"brick_light":
			return Color("E8CEA0").lerp(_color(palette, "surface"), 0.10)
		"brick_dark":
			return Color("8F7655").lerp(_color(palette, "accent"), 0.08)
		"white_wall":
			return Color("F0F2E9") if district_style == "night_white_blocks" else (Color("DCE4D2") if built_floor == 3 else Color("9DA99C"))
		"window":
			return Color("0B0D0B").lerp(_color(palette, "ink"), 0.35)
		"grass":
			return (Color("17321D") if district_style == "night_white_blocks" else (Color("5F8D3E") if built_floor == 3 else Color("4F7134"))).lerp(_color(palette, "accent"), 0.12)
		"grass_ground":
			return Color("527D42").lerp(_color(palette, "accent"), 0.10)
		"gallery_floor":
			return (Color("819978") if built_floor == 3 else Color("68756B")).lerp(_color(palette, "accent"), 0.08)
		"sunlit_paving":
			return Color("D7C8A8").lerp(_color(palette, "surface"), 0.16)
		"night_path":
			return Color("151613").lerp(_color(palette, "ink"), 0.42)
		"crosswalk":
			return Color("F3E8CD").lerp(_color(palette, "surface"), 0.24)
		"lamp":
			return Color("22241F").lerp(_color(palette, "ink"), 0.35)
		"lamp_light":
			return Color("FFBE58") if district_style == "night_white_blocks" else Color("E4D6A0")
		"ground":
			return _color(palette, "ink").lightened(0.055)
		"road":
			return _color(palette, "accent").darkened(0.54)
		"sidewalk":
			return _color(palette, "bg").darkened(0.36)
		"lot_floor":
			return _color(palette, "accent").darkened(0.30)
		"floor":
			return _color(palette, "accent").darkened(0.38)
		"floor_alt":
			return _color(palette, "accent").darkened(0.24)
		"wall":
			return _color(palette, "bg").darkened(0.38)
		"wall_dark":
			return _color(palette, "ink").lightened(0.035)
		"ceiling":
			return _color(palette, "surface").darkened(0.58)
		"accent":
			return _color(palette, "accent").darkened(0.10)
		"item":
			return _color(palette, "flash_text")
		"backrooms_beige":
			return Color("CBBE8E") if built_floor == 2 else Color("E0D6A7")
		"fixture_metal":
			return Color("69746D") if built_floor == 2 else Color("9AA79A")
		"cart_metal":
			return Color("4F5A54") if built_floor == 2 else Color("7D8D80")
		"chair_metal":
			return Color("758079") if built_floor == 2 else Color("A8B6A9")
		"chair_vinyl":
			return Color("485C50") if built_floor == 2 else Color("6E8B72")
		"pipe_metal":
			return Color("60736B") if built_floor == 2 else Color("8CA392")
		"machine_green":
			return Color("3B5A48") if built_floor == 2 else Color("688E69")
		"cooler_blue":
			return Color("538A8C") if built_floor == 2 else Color("8FC9C1")
		"indicator_red":
			return Color("8F4050") if built_floor == 2 else Color("C86A76")
		"screen_glow":
			return Color("6E9A7D") if built_floor == 2 else Color("B5DBAA")
		"fluorescent":
			return Color("D7E7AF") if built_floor == 2 else Color("F0F3CB")
		"crate_wood":
			return Color("725B3F") if built_floor == 2 else Color("A68B5C")
		"crate_dark":
			return Color("3E3529") if built_floor == 2 else Color("65563B")
		"rubber_black":
			return Color("111614")
		"dream_pink":
			return Color("F3A7BD") if built_floor == 3 else Color("B75A82")
		"dream_cyan":
			return Color("A8E1D3") if built_floor == 3 else Color("4C918D")
		"dream_ivory":
			return Color("FFF0BF") if built_floor == 3 else Color("A99775")
		_:
			return _color(palette, "muted")


func _style_background_color(palette: Dictionary) -> Color:
	if built_floor == 2:
		return Color("030607").lerp(_color(palette, "ink"), 0.08)
	if built_floor == 3:
		return Color("82B9B0").lerp(_color(palette, "surface"), 0.10)
	if built_floor >= 2:
		match district_style:
			"night_white_blocks":
				return Color("0B1112").lerp(_color(palette, "ink"), 0.14)
			"overgrown_gallery":
				return Color("202923").lerp(_color(palette, "ink"), 0.14)
			_:
				return Color("263A42").lerp(_color(palette, "ink"), 0.12)
	match district_style:
		"sunlit_brick_street":
			return Color("1479B8").lerp(_color(palette, "accent"), 0.10)
		"night_white_blocks":
			return Color("10090B").lerp(_color(palette, "ink"), 0.22)
		"overgrown_gallery":
			return Color("D4DDD0").lerp(_color(palette, "muted"), 0.18)
		_:
			return _color(palette, "ink")


func _style_ambient_color(palette: Dictionary) -> Color:
	if built_floor == 2:
		return Color("55716B").lerp(_color(palette, "muted"), 0.08)
	if built_floor == 3:
		return Color("E1EBCF").lerp(_color(palette, "surface"), 0.12)
	if built_floor >= 2:
		match district_style:
			"night_white_blocks":
				return Color("89A096").lerp(_color(palette, "muted"), 0.12)
			"overgrown_gallery":
				return Color("7A8A7D").lerp(_color(palette, "muted"), 0.10)
			_:
				return Color("9FB4BC").lerp(_color(palette, "muted"), 0.12)
	match district_style:
		"night_white_blocks":
			return Color("AEB8A2").lerp(_color(palette, "muted"), 0.18)
		"overgrown_gallery":
			return Color("F3F2DD").lerp(_color(palette, "surface"), 0.24)
		_:
			return Color("FFE4B8").lerp(_color(palette, "surface"), 0.18)


func _style_fog_color(palette: Dictionary) -> Color:
	if built_floor == 2:
		return Color("111A19").lerp(_color(palette, "ink"), 0.10)
	if built_floor == 3:
		return Color("B5D4B4").lerp(_color(palette, "surface"), 0.10)
	if built_floor >= 2:
		match district_style:
			"night_white_blocks":
				return Color("202B2A").lerp(_color(palette, "accent"), 0.06)
			"overgrown_gallery":
				return Color("39463D").lerp(_color(palette, "accent"), 0.08)
			_:
				return Color("607780").lerp(_color(palette, "accent"), 0.08)
	match district_style:
		"night_white_blocks":
			return Color("23181A").lerp(_color(palette, "accent"), 0.10)
		"overgrown_gallery":
			return Color("C9D6C0").lerp(_color(palette, "muted"), 0.20)
		_:
			return Color("7DB5C2").lerp(_color(palette, "accent"), 0.12)


func _color(palette: Dictionary, key: String) -> Color:
	return Color(str(palette.get(key, "FFF1C9")))
