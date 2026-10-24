extends Node
class_name RealitySceneAdapter
## 3D reality floor, player locomotion, and proximity interaction for the main scene adapter.
## Crosses the host seam with nearby / interaction outcomes and pose. Host sends snapshot intents.
## Chapter one's opening and basement are a chapter stage built here instead of a tower floor; the tower street is
## built when the deps carry no chapter progress or a tower one. The basement's CRT is a `terminal` outcome: entering
## it pushes the view in to its glass (`view_position` on the look pose) and leaving gives the look back.

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const FloorComposerScript = preload("res://scripts/game/floor_composer.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")
const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const ChapterOneStageScript = preload("res://scripts/world/chapter_one_stage.gd")

const MOVE_SPEED := 3.3
const SPRINT_MULTIPLIER := 1.85
const ACCELERATION := 14.0
const INTERACTION_DISTANCE := 2.25
const FALL_RECOVERY_Y := -3.0
const SAFE_INSET := 1.2
## Chapter rooms are small; the opening's bounds already sit inside its ground.
const CHAPTER_SAFE_INSET := 0.35
## Opening the white door: it swings for the first seconds while the player is walked through, then the stage changes.
const DOOR_SWING_SECONDS := 1.6
const DOOR_TRANSITION_SECONDS := 2.4
## Where the walk through the white door ends, past the door center.
const DOOR_WALK_THROUGH := Vector3(0.0, 0.0, -0.8)
## How far from the CRT's reach point the player may stand for it to answer.
const TERMINAL_REACH_RADIUS := 0.9
## The pushed-in view fills this share of the main camera's height with the CRT's glass.
const TERMINAL_VIEW_FILL := 0.72
const TERMINAL_VIEW_FOV := 58.0

signal nearby_targets_changed()

var player: CharacterBody3D
var floor: RealityFloorGenerator
var yaw := 0.0
var pitch := 0.0
var nearby_actor: Area3D
var nearby_item: Area3D
var active_actor: Area3D

var _built_floor := 0
var _built_day := 0
var _last_safe_position := Vector3.ZERO
var _host: Node3D
var _interaction_active := false
var _gaze_before_interaction: Dictionary = {}
var _chapter_stage: ChapterOneStage
## The chapter phase the stage was built for; empty while the tower street is built.
var _built_stage := ""
## The basement round the stage was built for; zero outside the basement.
var _built_round := 0
var _nearby_door := false
var _nearby_terminal := false
var _terminal_active := false
## Seconds into opening the white door, or a negative value when no door is opening.
var _door_time := -1.0
var _door_from := Vector3.ZERO
var _paused := false


func attach_to(host: Node3D) -> void:
	_host = host
	name = "RealitySceneAdapterHost"
	host.add_child(self)



func build_world_nodes() -> void:
	if _host == null:
		return
	player = CharacterBody3D.new()
	player.name = "RealityPlayer"
	player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	player.collision_layer = 1
	player.collision_mask = 1
	_host.add_child(player)
	var player_collision := CollisionShape3D.new()
	player_collision.name = "PlayerCollision"
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.34
	player_capsule.height = 1.72
	player_collision.shape = player_capsule
	player_collision.position.y = 0.88
	player.add_child(player_collision)

	floor = RealityFloorGeneratorScript.new()
	floor.name = "RealityFloor"
	_host.add_child(floor)


func reset_session_state() -> void:
	_built_floor = 0
	_built_day = 0
	_built_stage = ""
	_door_time = -1.0
	if floor != null:
		yaw = floor.start_yaw_degrees()
	pitch = 0.0
	clear_nearby_targets()
	_drop_interaction(false)


func clear_nearby_targets() -> void:
	nearby_actor = null
	nearby_item = null
	_nearby_door = false
	_nearby_terminal = false


func rebuild_floor(deps: Dictionary) -> void:
	if floor == null:
		return
	var stage_phase := _chapter_stage_phase(deps)
	if not stage_phase.is_empty():
		_build_chapter_stage(stage_phase, deps)
		return
	if _chapter_stage != null:
		_clear_chapter_stage()
		floor.visible = _street_shown()
	var progress: Dictionary = deps.get("day_progress", {})
	var tower_floor := clampi(int(progress.get("tower_floor", 1)), 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	var day_number := int(progress.get("day", 1))
	var load_texture: Callable = deps.get("load_texture", Callable())
	var npc_character_paths: Array = deps.get("npc_character_paths", [])
	var npc_textures: Array[Texture2D] = []
	for texture_path in npc_character_paths:
		var texture := _load_texture(load_texture, str(texture_path))
		if texture != null:
			npc_textures.append(texture)
	var key_npc_texture: Texture2D = null
	if not npc_textures.is_empty():
		key_npc_texture = npc_textures[posmod(tower_floor - 1, npc_textures.size())]
	var actor_textures := {
		"key_npc": key_npc_texture,
		"npcs": npc_textures,
		"doll": _load_texture(load_texture, str(deps.get("guide_doll_path", ""))),
	}
	var composed: Dictionary = FloorComposerScript.compose(deps)
	floor.rebuild(
		tower_floor,
		deps.get("palette", {}),
		actor_textures,
		day_number,
		bool(deps.get("cover_watcher_seen", false)),
		composed.get("items", []),
		composed.get("people", []),
		composed.get("display_names", {}),
		composed.get("events", []),
		composed.get("layout", {}),
	)
	sync_world_state(deps)
	floor.sync_collected_items(_string_ids(deps.get("collected_world_item_ids", [])))
	_built_floor = tower_floor
	_built_day = day_number
	clear_nearby_targets()
	_drop_interaction(false)
	if player != null:
		_last_safe_position = floor.start_position()
		player.position = _last_safe_position
		player.velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0


func ensure_floor_current(deps: Dictionary) -> void:
	if floor == null:
		return
	# The opening stays built while its door opens; the next stage follows once the walk through has ended.
	if _door_time >= 0.0:
		return
	var stage_phase := _chapter_stage_phase(deps)
	# Each basement round is built afresh: walking out of one starts the next at the top of the stairs.
	if stage_phase != _built_stage or ChapterOneProgressScript.round_of(_chapter_progress(deps)) != _built_round:
		rebuild_floor(deps)
	if not stage_phase.is_empty():
		if _chapter_stage != null:
			_chapter_stage.sync_progress(_chapter_progress(deps))
		return
	var progress: Dictionary = deps.get("day_progress", {})
	var tower_floor := int(progress.get("tower_floor", 1))
	var day_number := int(progress.get("day", 1))
	if _built_floor != tower_floor:
		rebuild_floor(deps)
	elif _built_day != day_number:
		var composed: Dictionary = FloorComposerScript.compose(deps)
		floor.configure_authored_events(day_number, deps.get("palette", {}), composed.get("events", []))
		_built_day = day_number


static func room_count_for_floor(floor_number: int) -> int:
	var composed: Dictionary = FloorComposerScript.compose({
		"day_progress": {"tower_floor": floor_number},
	})
	var layout: Dictionary = composed.get("layout", {})
	return int(layout.get("room_count", 0))


static func npc_count_for_floor(floor_number: int) -> int:
	var composed: Dictionary = FloorComposerScript.compose({
		"day_progress": {"tower_floor": floor_number},
	})
	var people: Array = composed.get("people", [])
	var count := 0
	for person in people:
		if person is Dictionary and str((person as Dictionary).get("kind", "")) == "npc":
			count += 1
	return count


func update_player(delta: float, deps: Dictionary) -> void:
	if player == null:
		return
	if _door_time >= 0.0:
		_advance_door_opening(delta)
		return
	if _should_recover_player():
		_recover_player()
		return
	var can_walk: bool = str(deps.get("view_state", "")) == "npc_up" and not _interaction_active and not _terminal_active
	var input_vector := Vector2.ZERO
	if can_walk:
		input_vector = Input.get_vector("reality_left", "reality_right", "reality_forward", "reality_back")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := Basis(Vector3.UP, deg_to_rad(yaw)) * local_direction
	if world_direction.length_squared() > 0.001:
		world_direction = world_direction.normalized()
	var speed_multiplier := SPRINT_MULTIPLIER if can_walk and Input.is_action_pressed("reality_sprint") else 1.0
	var target_velocity := world_direction * MOVE_SPEED * speed_multiplier
	var acceleration := ACCELERATION * speed_multiplier
	player.velocity.x = move_toward(player.velocity.x, target_velocity.x, acceleration * delta)
	player.velocity.z = move_toward(player.velocity.z, target_velocity.z, acceleration * delta)
	if not player.is_on_floor():
		player.velocity.y -= 18.0 * delta
	else:
		player.velocity.y = 0.0
	player.rotation.y = deg_to_rad(yaw)
	if player.is_inside_tree() and player.get_world_3d() != null:
		player.move_and_slide()
	if _should_recover_player():
		_recover_player()
	elif player.is_on_floor() and _contains_playable(player.position, _safe_inset()):
		_last_safe_position = player.position
	if _chapter_stage != null:
		_chapter_stage.track_player(player.position)


## Opening settings holds the knock and a door that is opening.
func set_paused(paused: bool) -> void:
	_paused = paused
	if _chapter_stage != null:
		_chapter_stage.set_paused(paused)


## Where the player stands to use the basement CRT; zero when no stage has one.
func chapter_terminal_position() -> Vector3:
	if _chapter_stage == null:
		return Vector3.ZERO
	return _chapter_stage.crt_reach_position()


## Where a world-space ray meets the CRT's glass, as a 0..1 UV from the top left; (-1, -1) when it does not.
func terminal_screen_uv(origin: Vector3, direction: Vector3) -> Vector2:
	var screen := _crt_screen()
	if screen == null:
		return CrtScreen.MISS
	return screen.uv_at(origin, direction)


## Shows the terminal's display on the CRT's glass, with or without its own VHS look.
func show_terminal_display(texture: Texture2D, vhs_enabled: bool) -> void:
	var screen := _crt_screen()
	if screen != null:
		screen.show_display(texture, vhs_enabled)


func _crt_screen() -> CrtScreen:
	if _chapter_stage == null or not is_instance_valid(_chapter_stage):
		return null
	return _chapter_stage.crt_screen()


## The white door's center on the ground; zero when no stage has a door.
func chapter_door_position() -> Vector3:
	if _chapter_stage == null or not _chapter_stage.has_door():
		return Vector3.ZERO
	return _chapter_stage.door_position()


## Where the basement round's NPC stands; zero when no stage has one.
func chapter_npc_position() -> Vector3:
	if _chapter_stage == null or _chapter_stage.interactable_actors().is_empty():
		return Vector3.ZERO
	return _chapter_stage.interactable_actors()[0].global_position


## Where the basement exit's doorway meets the floor; zero when no stage has one.
func chapter_exit_position() -> Vector3:
	if _chapter_stage == null:
		return Vector3.ZERO
	return _chapter_stage.exit_position()


## Whether a position is inside the chapter stage's playable bounds; false while the tower street is built.
func chapter_contains(position: Vector3) -> bool:
	return _chapter_stage != null and _chapter_stage.contains_playable_position(position)


func apply_look_delta(relative_motion: Vector2, sensitivity: float) -> void:
	yaw = wrapf(yaw - relative_motion.x * sensitivity, -180.0, 180.0)
	pitch = clampf(pitch - relative_motion.y * sensitivity, -68.0, 72.0)


func refresh_nearby_actor(deps: Dictionary) -> void:
	var previous_actor := nearby_actor
	var previous_item := nearby_item
	var previous_door := _nearby_door
	var previous_terminal := _nearby_terminal
	if (
		str(deps.get("view_state", "")) != "npc_up"
		or _interaction_active
		or _terminal_active
		or _door_time >= 0.0
		or floor == null
		or player == null
	):
		clear_nearby_targets()
		if previous_actor != null or previous_item != null or previous_door or previous_terminal:
			nearby_targets_changed.emit()
		return
	if _chapter_stage != null:
		_nearby_door = _door_in_reach(deps)
		_nearby_terminal = _terminal_in_reach()
		nearby_actor = _nearest_actor(_chapter_stage.interactable_actors())
		if previous_door != _nearby_door or previous_terminal != _nearby_terminal or previous_actor != nearby_actor:
			nearby_targets_changed.emit()
		return
	var nearest: Area3D = null
	var nearest_kind := ""
	var nearest_distance := INTERACTION_DISTANCE
	for actor in floor.get_interactable_actors():
		var offset: Vector3 = actor.position - player.position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= nearest_distance:
			nearest = actor
			nearest_kind = "actor"
			nearest_distance = distance
	for item in floor.get_interactable_items():
		var item_offset: Vector3 = item.position - player.position
		item_offset.y = 0.0
		var item_distance: float = item_offset.length()
		if item_distance <= nearest_distance:
			nearest = item
			nearest_kind = "item"
			nearest_distance = item_distance
	nearby_actor = nearest if nearest_kind == "actor" else null
	nearby_item = nearest if nearest_kind == "item" else null
	if previous_actor != nearby_actor or previous_item != nearby_item:
		nearby_targets_changed.emit()


func _nearest_actor(actors: Array[Area3D]) -> Area3D:
	var nearest: Area3D = null
	var nearest_distance := INTERACTION_DISTANCE
	for actor in actors:
		var offset: Vector3 = actor.global_position - player.global_position
		offset.y = 0.0
		if offset.length() <= nearest_distance:
			nearest = actor
			nearest_distance = offset.length()
	return nearest


func nearby_outcome() -> Dictionary:
	if _nearby_door:
		return {
			"kind": "door",
			"action": "open_door",
		}
	if _nearby_terminal:
		return {
			"kind": "terminal",
			"action": "enter_terminal",
		}
	if nearby_item != null:
		return {
			"kind": "item",
			"action": "collect",
			"item_data": _item_data(nearby_item),
		}
	if nearby_actor != null:
		var actor_data := _actor_data(nearby_actor)
		actor_data["kind"] = "actor"
		actor_data["action"] = "converse"
		return actor_data
	return {
		"kind": "none",
		"action": "none",
	}


func probe_interaction(deps: Dictionary) -> Dictionary:
	refresh_nearby_actor(deps)
	var nearby := nearby_outcome()
	if str(nearby.get("action", "none")) == "converse":
		var locale_translate: Callable = deps.get("locale_translate", Callable())
		var actor_label := str(nearby.get("actor_label", "对方"))
		if locale_translate.is_valid():
			actor_label = str(locale_translate.call(actor_label))
		nearby["actor_label"] = actor_label
	return nearby


func interaction_outcome() -> Dictionary:
	if _door_time >= 0.0:
		return {
			"kind": "door",
			"action": "open_door",
			"interaction_active": true,
			"progress": clampf(_door_time / DOOR_TRANSITION_SECONDS, 0.0, 1.0),
		}
	if _terminal_active:
		return {
			"kind": "terminal",
			"action": "enter_terminal",
			"interaction_active": true,
		}
	if not _interaction_active:
		return {
			"kind": "none",
			"action": "none",
			"interaction_active": false,
		}
	var actor_data := active_actor_outcome()
	actor_data["interaction_active"] = true
	if str(actor_data.get("action", "none")) == "none":
		actor_data["action"] = "converse"
	return actor_data


func apply_interaction(intent: Dictionary) -> Dictionary:
	var action := str(intent.get("action", "none"))
	# Once the white door is opening nothing turns it back.
	if _door_time >= 0.0:
		return interaction_outcome()
	if action == "open_door":
		if _nearby_door and player != null:
			_nearby_door = false
			_door_time = 0.0
			_door_from = player.position
			player.velocity = Vector3.ZERO
			nearby_targets_changed.emit()
		return interaction_outcome()
	if action == "enter_terminal":
		if _nearby_terminal and player != null and _crt_screen() != null:
			_gaze_before_interaction = {"yaw": yaw, "pitch": pitch}
			_face_terminal()
			_nearby_terminal = false
			_terminal_active = true
			player.velocity = Vector3.ZERO
			nearby_targets_changed.emit()
		return interaction_outcome()
	if action == "end":
		return _drop_interaction(true)
	if action == "collect":
		apply_item_collected(str(intent.get("item_id", "")))
		var collected := nearby_outcome()
		collected["interaction_active"] = _interaction_active
		return collected
	if action == "converse":
		if not bool(intent.get("accepted", false)):
			return _drop_interaction(true)
		var actor_id := str(intent.get("actor_id", "")).strip_edges()
		if actor_id.is_empty() or _find_actor(actor_id) == null:
			return _drop_interaction(true)
		if not _interaction_active:
			_gaze_before_interaction = {"yaw": yaw, "pitch": pitch}
		face_actor(actor_id)
		remember_actor(actor_id)
		_interaction_active = true
		return interaction_outcome()
	return interaction_outcome()


func _drop_interaction(restore_gaze: bool) -> Dictionary:
	if restore_gaze and not _gaze_before_interaction.is_empty():
		yaw = float(_gaze_before_interaction.get("yaw", yaw))
		pitch = float(_gaze_before_interaction.get("pitch", pitch))
	_gaze_before_interaction = {}
	clear_active_actor()
	_interaction_active = false
	_terminal_active = false
	return {
		"kind": "none",
		"action": "end",
		"interaction_active": false,
	}


func apply_item_collected(item_id: String) -> void:
	var item := _find_item(item_id)
	if item == null:
		return
	item.set_meta("collected", true)
	item.visible = false
	item.monitoring = false
	item.monitorable = false
	nearby_item = null


func face_actor(actor_id: String) -> void:
	if player == null:
		return
	var actor := _find_actor(actor_id)
	if actor == null:
		return
	var actor_type := str(actor.get_meta("actor_type", "npc"))
	var actor_direction: Vector3 = actor.position - player.position
	if actor_direction.length_squared() > 0.001:
		yaw = rad_to_deg(atan2(-actor_direction.x, -actor_direction.z))
		pitch = -30.0 if actor_type == "doll" else -2.0


func remember_actor(actor_id: String) -> void:
	active_actor = _find_actor(actor_id)


func clear_active_actor() -> void:
	active_actor = null


func sync_world_state(deps: Dictionary) -> void:
	if floor == null:
		return
	floor.sync_prerequisite_items(
		_string_ids(deps.get("revealed_prerequisite_item_ids", [])),
		_string_ids(deps.get("collected_prerequisite_item_ids", []))
	)
	floor.sync_claimed_dolls(_string_ids(deps.get("claimed_doll_ids", [])))


func sync_ultimate_task_props(deps: Dictionary) -> void:
	if floor == null or not is_instance_valid(floor):
		return
	var progress: Dictionary = deps.get("day_progress", {})
	var tower_floor := int(progress.get("tower_floor", 1))
	if tower_floor == 3:
		var floor3_complete := bool(deps.get("floor3_task_complete", false))
		var sealed_door := _ensure_task_prop_body("FloorThreeSealedDoor", Vector3(2.6, 3.2, 0.34), Vector3(0.0, 1.6, -7.0), deps)
		var open_frame := _ensure_task_prop_mesh("FloorThreeDoorOpenFrame", Vector3(2.8, 3.4, 0.08), Vector3(0.0, 1.7, -7.0), true, deps)
		if sealed_door != null:
			sealed_door.visible = not floor3_complete
			var door_shape := sealed_door.get_node_or_null("DoorCollision") as CollisionShape3D
			if door_shape != null:
				# An opened door no longer blocks passage.
				door_shape.disabled = floor3_complete
		if open_frame != null:
			open_frame.visible = floor3_complete
	elif tower_floor == 4:
		var floor4_complete := bool(deps.get("floor4_task_complete", false))
		var exit_frame := _ensure_task_prop_mesh("FloorFourExitFrame", Vector3(2.8, 3.4, 0.08), Vector3(0.0, 1.7, -6.0), true, deps)
		if exit_frame != null:
			exit_frame.visible = floor4_complete


func _ensure_task_prop_body(node_name: String, body_size: Vector3, body_position: Vector3, deps: Dictionary) -> StaticBody3D:
	var existing := floor.get_node_or_null(node_name) as StaticBody3D
	if existing != null:
		return existing
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = body_position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DoorMesh"
	var box := BoxMesh.new()
	box.size = body_size
	var material := StandardMaterial3D.new()
	material.albedo_color = UiPaletteScript.color(deps.get("palette", {}), "ink")
	box.material = material
	mesh_instance.mesh = box
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "DoorCollision"
	var shape := BoxShape3D.new()
	shape.size = body_size
	collision.shape = shape
	body.add_child(collision)
	floor.add_child(body)
	return body


func _ensure_task_prop_mesh(node_name: String, mesh_size: Vector3, mesh_position: Vector3, emissive: bool, deps: Dictionary) -> MeshInstance3D:
	var existing := floor.get_node_or_null(node_name) as MeshInstance3D
	if existing != null:
		return existing
	var prop := MeshInstance3D.new()
	prop.name = node_name
	var box := BoxMesh.new()
	box.size = mesh_size
	var palette: Dictionary = deps.get("palette", {})
	var material := StandardMaterial3D.new()
	if emissive:
		var flash := UiPaletteScript.color(palette, "flash_text")
		material.albedo_color = flash
		material.emission_enabled = true
		material.emission = flash
		material.emission_energy_multiplier = 1.4
	else:
		material.albedo_color = UiPaletteScript.color(palette, "ink")
	box.material = material
	prop.mesh = box
	prop.position = mesh_position
	floor.add_child(prop)
	return prop


func active_actor_outcome() -> Dictionary:
	if active_actor == null or not is_instance_valid(active_actor):
		return {
			"kind": "none",
			"action": "none",
		}
	var actor_data := _actor_data(active_actor)
	actor_data["kind"] = "actor"
	return actor_data


func _chapter_progress(deps: Dictionary) -> Dictionary:
	if not deps.has("chapter_one_progress"):
		return ChapterOneProgressScript.tower()
	return ChapterOneProgressScript.normalize(deps.get("chapter_one_progress"))


## The chapter phase the deps ask a stage for, or empty for the tower street.
func _chapter_stage_phase(deps: Dictionary) -> String:
	var stage_phase := ChapterOneProgressScript.phase_of(_chapter_progress(deps))
	return "" if stage_phase == ChapterOneProgressScript.PHASE_TOWER else stage_phase


func _build_chapter_stage(stage_phase: String, deps: Dictionary) -> void:
	_clear_chapter_stage()
	floor.visible = false
	var round_number := ChapterOneProgressScript.round_of(_chapter_progress(deps))
	_chapter_stage = ChapterOneStageScript.new()
	_chapter_stage.name = "ChapterOneStage"
	_host.add_child(_chapter_stage)
	_chapter_stage.build(stage_phase, round_number, _basement_npc_texture(deps, round_number))
	_chapter_stage.set_paused(_paused)
	_chapter_stage.visible = _street_shown()
	_built_stage = stage_phase
	_built_round = round_number
	clear_nearby_targets()
	_drop_interaction(false)
	_door_time = -1.0
	if player != null:
		_last_safe_position = _chapter_stage.start_position()
		player.position = _last_safe_position
		player.velocity = Vector3.ZERO
	yaw = _chapter_stage.start_yaw_degrees()
	pitch = 0.0


func _clear_chapter_stage() -> void:
	if _chapter_stage != null and is_instance_valid(_chapter_stage):
		_chapter_stage.get_parent().remove_child(_chapter_stage)
		_chapter_stage.queue_free()
	_chapter_stage = null
	_built_stage = ""
	_built_round = 0


## The round's NPC is drawn with the street's NPC portraits, one after another.
func _basement_npc_texture(deps: Dictionary, round_number: int) -> Texture2D:
	var paths: Array = deps.get("npc_character_paths", [])
	if round_number <= 0 or paths.is_empty():
		return null
	return _load_texture(deps.get("load_texture", Callable()), str(paths[(round_number - 1) % paths.size()]))


func _terminal_in_reach() -> bool:
	if _crt_screen() == null:
		return false
	var offset: Vector3 = _chapter_stage.crt_reach_position() - player.position
	offset.y = 0.0
	return offset.length() <= TERMINAL_REACH_RADIUS


## Turns the look to the CRT's glass from the pushed-in view.
func _face_terminal() -> void:
	var direction := _crt_screen().center() - _terminal_view_position()
	yaw = rad_to_deg(atan2(-direction.x, -direction.z))
	pitch = rad_to_deg(asin(clampf(direction.normalized().y, -1.0, 1.0)))


func _terminal_view_position() -> Vector3:
	return _crt_screen().view_position(TERMINAL_VIEW_FOV, TERMINAL_VIEW_FILL)


func _door_in_reach(deps: Dictionary) -> bool:
	if not _chapter_stage.has_door() or not ChapterOneProgressScript.door_ready(_chapter_progress(deps)):
		return false
	var offset: Vector3 = _chapter_stage.door_position() - player.position
	offset.y = 0.0
	return offset.length() <= INTERACTION_DISTANCE


## Swings the door and walks the player through it; when the walk ends the next ensure builds the next stage.
func _advance_door_opening(delta: float) -> void:
	if _paused:
		return
	_door_time += maxf(delta, 0.0)
	_chapter_stage.set_door_open_ratio(smoothstep(0.0, DOOR_SWING_SECONDS, _door_time))
	var through: Vector3 = _chapter_stage.door_position() + DOOR_WALK_THROUGH
	through.y = _door_from.y
	var walk := smoothstep(0.0, DOOR_TRANSITION_SECONDS, _door_time)
	player.position = _door_from.lerp(through, walk)
	player.velocity = Vector3.ZERO
	yaw = rad_to_deg(lerp_angle(deg_to_rad(yaw), 0.0, walk))
	pitch = lerpf(pitch, 0.0, walk)
	if _door_time >= DOOR_TRANSITION_SECONDS:
		_door_time = -1.0


## The host hides the street and the player together while the phone is down.
func _street_shown() -> bool:
	return player == null or player.visible


func _safe_inset() -> float:
	return CHAPTER_SAFE_INSET if _chapter_stage != null else SAFE_INSET


func _contains_playable(position: Vector3, inset: float) -> bool:
	if _chapter_stage != null:
		return _chapter_stage.contains_playable_position(position, inset)
	return floor != null and floor.contains_playable_position(position, inset)


func _clamp_playable(position: Vector3, inset: float) -> Vector3:
	if _chapter_stage != null:
		return _chapter_stage.clamp_to_playable_position(position, inset)
	return floor.clamp_to_playable_position(position, inset)


func _start_position() -> Vector3:
	if _chapter_stage != null:
		return _chapter_stage.start_position()
	return floor.start_position()


func apply_palette(palette: Dictionary) -> void:
	if floor != null and is_instance_valid(floor):
		floor.apply_palette(palette)


func set_street_shown(shown: bool) -> void:
	if floor != null and is_instance_valid(floor):
		floor.visible = shown and _chapter_stage == null
	if _chapter_stage != null and is_instance_valid(_chapter_stage):
		_chapter_stage.visible = shown
	if player != null and is_instance_valid(player):
		player.visible = shown


func pose() -> Dictionary:
	var look_pose := {
		"player_position": player.position if player != null else Vector3.ZERO,
		"yaw": yaw,
		"pitch": pitch,
		"has_player": player != null,
	}
	if _terminal_active and _crt_screen() != null:
		look_pose["view_position"] = _terminal_view_position()
	return look_pose


func restore_world_pose(world_data: Dictionary) -> void:
	if world_data.is_empty() or player == null or floor == null:
		return
	var saved_position: Variant = world_data.get("player_position", Vector3.ZERO)
	# A save made while the white door opened is already past the opening; its pose belongs to the old stage.
	if _chapter_stage != null and saved_position is Vector3 and not _chapter_stage.contains_playable_position(saved_position):
		return
	if saved_position is Vector3:
		_last_safe_position = _clamp_playable(saved_position, _safe_inset())
		player.position = _last_safe_position
		player.velocity = Vector3.ZERO
	yaw = wrapf(float(world_data.get("yaw", 0.0)), -180.0, 180.0)
	pitch = clampf(float(world_data.get("pitch", 0.0)), -68.0, 72.0)


func world_save_pose() -> Dictionary:
	var look_pose := pose()
	return {
		"player_position": look_pose.get("player_position", Vector3.ZERO),
		"yaw": look_pose.get("yaw", 0.0),
		"pitch": look_pose.get("pitch", 0.0),
	}


func update_authored_events(delta: float, camera_forward: Vector3) -> void:
	if floor == null or player == null or _chapter_stage != null:
		return
	floor.update_authored_events(delta, player.global_position, camera_forward)


func _should_recover_player() -> bool:
	if player == null or floor == null:
		return false
	if player.position.y < FALL_RECOVERY_Y:
		return true
	return not _contains_playable(player.position, -2.0)


func _recover_player() -> void:
	if player == null or floor == null:
		return
	var recovery_position := _last_safe_position
	if not _contains_playable(recovery_position, _safe_inset()):
		recovery_position = _start_position()
	recovery_position = _clamp_playable(recovery_position, _safe_inset())
	# The street's ground is flat; a chapter stage keeps the height it was safe at (the basement landing is raised).
	if _chapter_stage == null:
		recovery_position.y = 0.08
	player.position = recovery_position
	player.velocity = Vector3.ZERO


func _item_data(item: Area3D) -> Dictionary:
	return {
		"id": str(item.get_meta("item_id", "")),
		"label": str(item.get_meta("display_name", "街区遗物")),
		"effect": str(item.get_meta("item_effect", "")),
		"value": item.get_meta("item_value", 0),
		"description": str(item.get_meta("item_description", "")),
	}


func _actor_data(actor: Area3D) -> Dictionary:
	return {
		"actor_id": str(actor.get_meta("actor_id", "actor")),
		"actor_type": str(actor.get_meta("actor_type", "npc")),
		"actor_label": str(actor.get_meta("display_name", "对方")),
	}


func _string_ids(value: Variant) -> Array[String]:
	var ids: Array[String] = []
	if value is Array:
		for item in value:
			ids.append(str(item))
	return ids


func _load_texture(load_texture: Callable, texture_path: String) -> Texture2D:
	if not load_texture.is_valid() or texture_path.is_empty():
		return null
	return load_texture.call(texture_path) as Texture2D


func _find_actor(actor_id: String) -> Area3D:
	if actor_id.is_empty():
		return null
	if nearby_actor != null and str(nearby_actor.get_meta("actor_id", "")) == actor_id:
		return nearby_actor
	if active_actor != null and is_instance_valid(active_actor) and str(active_actor.get_meta("actor_id", "")) == actor_id:
		return active_actor
	var actors: Array[Area3D] = []
	if _chapter_stage != null:
		actors = _chapter_stage.interactable_actors()
	elif floor != null:
		actors = floor.get_interactable_actors()
	for actor in actors:
		if str(actor.get_meta("actor_id", "")) == actor_id:
			return actor
	return null


func _find_item(item_id: String) -> Area3D:
	if item_id.is_empty():
		return null
	if nearby_item != null and str(nearby_item.get_meta("item_id", "")) == item_id:
		return nearby_item
	if floor == null:
		return null
	for item in floor.get_interactable_items():
		if str(item.get_meta("item_id", "")) == item_id:
			return item
	return null
