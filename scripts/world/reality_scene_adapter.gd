extends Node
class_name RealitySceneAdapter
## 3D reality floor, player locomotion, and proximity interaction for the main scene adapter.
## Crosses the host seam with nearby / interaction outcomes and pose. Host sends snapshot intents.

const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const FloorComposerScript = preload("res://scripts/world/floor_composer.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")

const MOVE_SPEED := 3.3
const SPRINT_MULTIPLIER := 1.85
const ACCELERATION := 14.0
const INTERACTION_DISTANCE := 2.25
const FALL_RECOVERY_Y := -3.0
const SAFE_INSET := 1.2

signal nearby_targets_changed()
signal cover_watcher_appeared(floor_number: int)
signal cover_watcher_vanished(floor_number: int)

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
	floor.cover_watcher_appeared.connect(_on_cover_watcher_appeared)
	floor.cover_watcher_vanished.connect(_on_cover_watcher_vanished)
	_host.add_child(floor)


func reset_session_state() -> void:
	_built_floor = 0
	_built_day = 0
	if floor != null:
		yaw = floor.start_yaw_degrees()
	pitch = 0.0
	clear_nearby_targets()
	active_actor = null


func clear_nearby_targets() -> void:
	nearby_actor = null
	nearby_item = null


func rebuild_floor(deps: Dictionary) -> void:
	if floor == null:
		return
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
	var cast: Dictionary = FloorComposerScript.compose(progress)
	var prerequisite_item: Dictionary = deps.get("prerequisite_item", {})
	floor.rebuild(
		tower_floor,
		deps.get("palette", {}),
		actor_textures,
		day_number,
		bool(deps.get("cover_watcher_seen", false)),
		prerequisite_item,
		cast,
	)
	floor.set_playtest_assist_enabled(bool(deps.get("playtest_assist_enabled", false)))
	sync_world_state(deps)
	floor.sync_collected_items(_string_ids(deps.get("collected_world_item_ids", [])))
	_built_floor = tower_floor
	_built_day = day_number
	clear_nearby_targets()
	clear_active_actor()
	if player != null:
		_last_safe_position = floor.start_position()
		player.position = _last_safe_position
		player.velocity = Vector3.ZERO
	yaw = 0.0
	pitch = 0.0


func ensure_floor_current(deps: Dictionary) -> void:
	if floor == null:
		return
	var progress: Dictionary = deps.get("day_progress", {})
	var tower_floor := int(progress.get("tower_floor", 1))
	var day_number := int(progress.get("day", 1))
	if _built_floor != tower_floor:
		rebuild_floor(deps)
	elif _built_day != day_number:
		floor.configure_authored_events(day_number, deps.get("palette", {}))
		_built_day = day_number


static func room_count_for_floor(floor_number: int) -> int:
	return RealityFloorGeneratorScript.room_count_for_floor(floor_number)


static func npc_count_for_floor(floor_number: int) -> int:
	return FloorComposerScript.npc_count_for_floor(floor_number)


func update_player(delta: float, deps: Dictionary) -> void:
	if player == null:
		return
	if _should_recover_player():
		_recover_player()
		return
	var can_walk: bool = (
		str(deps.get("view_state", "")) == "npc_up"
		and not bool(deps.get("interaction_active", false))
	)
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
	player.move_and_slide()
	if _should_recover_player():
		_recover_player()
	elif player.is_on_floor() and floor != null and floor.contains_playable_position(player.position, SAFE_INSET):
		_last_safe_position = player.position


func apply_look_delta(relative_motion: Vector2, sensitivity: float) -> void:
	yaw = wrapf(yaw - relative_motion.x * sensitivity, -180.0, 180.0)
	pitch = clampf(pitch - relative_motion.y * sensitivity, -68.0, 72.0)


func refresh_nearby_actor(deps: Dictionary) -> void:
	var previous_actor := nearby_actor
	var previous_item := nearby_item
	if (
		str(deps.get("view_state", "")) != "npc_up"
		or bool(deps.get("interaction_active", false))
		or floor == null
		or player == null
	):
		clear_nearby_targets()
		if previous_actor != null or previous_item != null:
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


func nearby_outcome() -> Dictionary:
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


func active_actor_outcome() -> Dictionary:
	if active_actor == null or not is_instance_valid(active_actor):
		return {
			"kind": "none",
			"action": "none",
		}
	var actor_data := _actor_data(active_actor)
	actor_data["kind"] = "actor"
	return actor_data


func pose() -> Dictionary:
	return {
		"player_position": player.position if player != null else Vector3.ZERO,
		"yaw": yaw,
		"pitch": pitch,
		"has_player": player != null,
	}


func restore_world_pose(world_data: Dictionary) -> void:
	if world_data.is_empty() or player == null or floor == null:
		return
	var saved_position: Variant = world_data.get("player_position", Vector3.ZERO)
	if saved_position is Vector3:
		_last_safe_position = floor.clamp_to_playable_position(saved_position, SAFE_INSET)
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
	if floor == null or player == null:
		return
	floor.update_authored_events(delta, player.global_position, camera_forward)


func _should_recover_player() -> bool:
	if player == null or floor == null:
		return false
	if player.position.y < FALL_RECOVERY_Y:
		return true
	return not floor.contains_playable_position(player.position, -2.0)


func _recover_player() -> void:
	if player == null or floor == null:
		return
	var recovery_position := _last_safe_position
	if not floor.contains_playable_position(recovery_position, SAFE_INSET):
		recovery_position = floor.start_position()
	recovery_position = floor.clamp_to_playable_position(recovery_position, SAFE_INSET)
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
	if floor == null:
		return null
	for actor in floor.get_interactable_actors():
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


func _on_cover_watcher_appeared(floor_number: int) -> void:
	cover_watcher_appeared.emit(floor_number)


func _on_cover_watcher_vanished(floor_number: int) -> void:
	cover_watcher_vanished.emit(floor_number)
