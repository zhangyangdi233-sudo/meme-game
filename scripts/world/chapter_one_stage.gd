class_name ChapterOneStage
extends Node3D
## Chapter one's stage behind the Reality scene adapter: the opening (black water, a white door 29.5 m ahead and
## the knock behind it) or one basement round (a room with the CRT terminal, the round's NPC and an exit), each from
## its imported model. The models bring their own walls and ground colliders; this stage adds the spawn, the playable
## bounds, the light, the doors and their colliders, the NPC and the CRT's glass.
## The adapter drives it; the knock finishing and the player walking out through the basement's open exit are raised
## as game events for the state to record.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const CrtScreenScript = preload("res://scripts/world/crt_screen.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")

const OPENING_MODEL_PATH := "res://assets/chapter1/Opening_WhiteDoor_v2.glb"
const BASEMENT_MODEL_PATH := "res://assets/chapter1/Basement_Loop_v2.glb"
const KNOCK_PATH := "res://assets/audio/sfx/opening_door_knock.ogg"
## How far ahead of the player the white door stands when the opening starts.
const OPENING_WALK_DISTANCE := 29.5
## The opening model's door: its hinge pivot and the closed leaf's center on the ground, in model space.
const OPENING_DOOR_PIVOT := "OpeningDoorPivot"
const OPENING_DOOR_LIGHT_PLANE := "OpeningDoor_LightPlane"
const OPENING_DOOR_CENTER := Vector3(0.0, 0.0, -18.0)
const OPENING_DOOR_OPEN_DEGREES := 90.0
## The opening model's 80 m ground, less a margin.
const OPENING_BOUNDS := AABB(Vector3(-39.5, -0.3, -51.5), Vector3(79.0, 4.0, 79.0))
## The basement model's room and stairwell (Blender (x, y, z) -> Godot (x, z, -y)); the spawn is on the stair landing.
const BASEMENT_BOUNDS := AABB(Vector3(-3.2, -0.3, -4.2), Vector3(6.4, 6.0, 8.4))
const BASEMENT_SPAWN := Vector3(-2.5, 2.72, -1.85)
const BASEMENT_SPAWN_YAW := 180.0
const BASEMENT_LIGHTS := {
	"BasementMainLight": {"position": Vector3(0.3, 2.5, 1.5), "energy": 0.85, "range": 6.8},
	"BasementRearLight": {"position": Vector3(0.0, 2.5, -3.4), "energy": 0.62, "range": 4.5},
}
const BASEMENT_LIGHT_COLOR := Color(1.0, 0.82, 0.62)
## The basement model's CRT glass: the mesh whose name ends with this.
const CRT_SCREEN_NODE := "*Screen_Video"
## The CRT's reach point (where the player stands to use it): this far out from its glass, on the floor.
const CRT_REACH_OFFSET := 0.9
## The basement model's two doors: the entry at the top of the stairs (open when a round starts, shut once the player
## goes down) and the exit behind the NPC (open once the round is delivered). Both swing out, away from the room.
const ENTRY_DOOR_PIVOT := "EntryDoorPivot"
const EXIT_DOOR_PIVOT := "ExitDoorPivot"
## A door leaf's size and its center from its hinge pivot, in Godot space.
const DOOR_LEAF_SIZE := Vector3(0.055, 2.2, 1.06)
const DOOR_LEAF_CENTER := Vector3(0.0, 1.1, -0.53)
const BASEMENT_DOOR_OPEN_DEGREES := 90.0
const BASEMENT_DOOR_SECONDS := 1.2
## The entry shuts once the player is past this depth down the stairs (the model's EntrySealTrigger).
const ENTRY_SEAL_Z := -1.22
## The exit's doorway on the floor, and how far past the wall the player has walked out.
const EXIT_DOORWAY := Vector3(-3.2, 0.0, -3.43)
const EXIT_DOORWAY_HALF_WIDTH := 0.53
const EXIT_WALKED_OUT_X := -3.45
## The round's NPC stands at the model's NPC anchor, behind the partition, facing the room.
const BASEMENT_NPC_POSITION := Vector3(0.0, 0.02, -3.7)
const BASEMENT_NPC_HEIGHT := 1.75

var phase := ""
var _model: Node3D
var _bounds := AABB()
var _spawn := Vector3.ZERO
var _spawn_yaw := 0.0
var _door_pivot: Node3D
var _crt_screen: CrtScreen
var _knock: AudioStreamPlayer3D
var _knock_started := false
var _knock_reported := false
var _paused := false
var _round := 0
var _npc: Area3D
var _entry_door: Node3D
var _exit_door: Node3D
## Door open ratios (0 shut, 1 open) and where each is swinging to.
var _entry_ratio := 1.0
var _entry_target := 1.0
var _exit_ratio := 0.0
var _exit_target := 0.0
var _exit_reported := false


## Builds the stage for one chapter phase (`ChapterOneProgress.PHASE_OPENING` or `PHASE_BASEMENT`); a basement is
## built for its round, with that round's NPC shown by `npc_texture`.
func build(stage_phase: String, round_number: int = 0, npc_texture: Texture2D = null) -> bool:
	phase = stage_phase
	_round = round_number
	if phase == ChapterOneProgressScript.PHASE_OPENING:
		return _build_opening()
	if phase == ChapterOneProgressScript.PHASE_BASEMENT:
		return _build_basement(npc_texture)
	push_error("ChapterOneStage has no stage for phase '%s'" % phase)
	return false


func start_position() -> Vector3:
	return _spawn


func start_yaw_degrees() -> float:
	return _spawn_yaw


func has_door() -> bool:
	return _door_pivot != null


## The basement CRT's glass, or null when this stage has none.
func crt_screen() -> CrtScreen:
	return _crt_screen


## Where the player stands to use the CRT, on the floor in front of its glass; zero when there is no CRT.
func crt_reach_position() -> Vector3:
	if _crt_screen == null:
		return Vector3.ZERO
	var reach := _crt_screen.center() + _crt_screen.forward() * CRT_REACH_OFFSET
	reach.y = 0.0
	return reach


## The white door's center on the ground.
func door_position() -> Vector3:
	return OPENING_DOOR_CENTER


## The basement round's NPC, or none outside the basement.
func interactable_actors() -> Array[Area3D]:
	var actors: Array[Area3D] = []
	if _npc != null:
		actors.append(_npc)
	return actors


## Where the basement exit's doorway meets the floor; zero when there is no exit.
func exit_position() -> Vector3:
	return EXIT_DOORWAY if _exit_door != null else Vector3.ZERO


## Follows the player through a basement round: going down the stairs shuts the entry behind them, and walking out
## through the open exit is reported once.
func track_player(position: Vector3) -> void:
	if _entry_door != null and position.z > ENTRY_SEAL_Z:
		_entry_target = 0.0
	if _exit_door == null or _exit_reported or _exit_ratio < 0.5:
		return
	if position.x < EXIT_WALKED_OUT_X and absf(position.z - EXIT_DOORWAY.z) <= EXIT_DOORWAY_HALF_WIDTH:
		_exit_reported = true
		GameEventBusScript.raise_event(GameEventsScript.BASEMENT_EXIT_CROSSED)


func contains_playable_position(position: Vector3, inset: float = 0.0) -> bool:
	var box := _bounds.grow(-inset)
	return (
		position.x >= box.position.x and position.x <= box.end.x
		and position.z >= box.position.z and position.z <= box.end.z
		and position.y >= box.position.y and position.y <= box.end.y
	)


func clamp_to_playable_position(position: Vector3, inset: float = 0.0) -> Vector3:
	var box := _bounds.grow(-inset)
	return Vector3(
		clampf(position.x, box.position.x, box.end.x),
		clampf(position.y, box.position.y, box.end.y),
		clampf(position.z, box.position.z, box.end.z)
	)


## Starts the knock once its line is reached; a knock already heard, or already started in this stage, is not replayed.
func sync_progress(progress: Dictionary) -> void:
	if _exit_door != null and ChapterOneProgressScript.exit_open(progress):
		_exit_target = 1.0
	if _knock == null or _paused or _knock_started:
		return
	if not ChapterOneProgressScript.knock_due(progress):
		return
	_knock_started = true
	if _knock.stream == null:
		# Without the recording the knock counts as heard, so the door can still open.
		push_error("The opening knock recording did not load: %s" % KNOCK_PATH)
		_on_knock_finished()
		return
	_knock.play()


## Opening settings holds the knock where it is.
func set_paused(paused: bool) -> void:
	_paused = paused
	if _knock != null:
		_knock.stream_paused = paused


## Swings the white door open: 0 is closed, 1 fully open away from the player. Its glow plane hides once it moves.
func set_door_open_ratio(ratio: float) -> void:
	if _door_pivot == null:
		return
	_door_pivot.rotation_degrees.y = OPENING_DOOR_OPEN_DEGREES * clampf(ratio, 0.0, 1.0)
	var light_plane := _model.find_child(OPENING_DOOR_LIGHT_PLANE, true, false) as Node3D
	if light_plane != null:
		light_plane.visible = ratio <= 0.0


func _build_opening() -> bool:
	if not _instance_model(OPENING_MODEL_PATH, "OpeningWorld"):
		return false
	_door_pivot = _model.find_child(OPENING_DOOR_PIVOT, true, false) as Node3D
	if _door_pivot == null:
		push_error("The opening model has no %s" % OPENING_DOOR_PIVOT)
		return false
	_bounds = OPENING_BOUNDS
	_spawn = OPENING_DOOR_CENTER + Vector3(0.0, 0.04, OPENING_WALK_DISTANCE)
	_spawn_yaw = 0.0
	_knock = AudioStreamPlayer3D.new()
	_knock.name = "OpeningKnock"
	_knock.stream = load(KNOCK_PATH) as AudioStream
	_knock.unit_size = 18.0
	_knock.volume_db = -3.0
	_knock.position = OPENING_DOOR_CENTER + Vector3(0.0, 1.1, 0.0)
	_knock.finished.connect(_on_knock_finished)
	add_child(_knock)
	_build_environment(Color.BLACK, 0.0)
	return true


## Swings the basement doors toward where they are going; open settings holds them.
func _process(delta: float) -> void:
	if _paused:
		return
	var step := maxf(delta, 0.0) / BASEMENT_DOOR_SECONDS
	if _entry_door != null and _entry_ratio != _entry_target:
		_entry_ratio = move_toward(_entry_ratio, _entry_target, step)
		_swing(_entry_door, _entry_ratio)
	if _exit_door != null and _exit_ratio != _exit_target:
		_exit_ratio = move_toward(_exit_ratio, _exit_target, step)
		_swing(_exit_door, _exit_ratio)


func _build_basement(npc_texture: Texture2D) -> bool:
	if not _instance_model(BASEMENT_MODEL_PATH, "BasementRoom"):
		return false
	_entry_door = _bind_basement_door(ENTRY_DOOR_PIVOT)
	_exit_door = _bind_basement_door(EXIT_DOOR_PIVOT)
	_swing(_entry_door, _entry_ratio)
	_swing(_exit_door, _exit_ratio)
	_build_npc(npc_texture)
	_bounds = BASEMENT_BOUNDS
	_spawn = BASEMENT_SPAWN
	_spawn_yaw = BASEMENT_SPAWN_YAW
	for light_name in BASEMENT_LIGHTS:
		var spec: Dictionary = BASEMENT_LIGHTS[light_name]
		var light := OmniLight3D.new()
		light.name = light_name
		light.light_color = BASEMENT_LIGHT_COLOR
		light.light_energy = float(spec["energy"])
		light.omni_range = float(spec["range"])
		light.shadow_enabled = true
		light.position = spec["position"]
		add_child(light)
	_build_environment(BASEMENT_LIGHT_COLOR.darkened(0.7), 0.35)
	var glass := _model.find_child(CRT_SCREEN_NODE, true, false) as MeshInstance3D
	var screen := CrtScreenScript.new()
	if screen.bind(glass):
		_crt_screen = screen
	else:
		push_error("The basement model has no CRT glass (%s)" % CRT_SCREEN_NODE)
	return true


## Gives a door leaf the collider the model leaves out, so it swings with the door and holds the doorway shut.
func _bind_basement_door(pivot_name: String) -> Node3D:
	var pivot := _model.find_child(pivot_name, true, false) as Node3D
	if pivot == null:
		push_error("The basement model has no %s" % pivot_name)
		return null
	var body := StaticBody3D.new()
	body.name = "LeafCollider"
	body.position = DOOR_LEAF_CENTER
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = DOOR_LEAF_SIZE
	shape.shape = box
	body.add_child(shape)
	pivot.add_child(body)
	return pivot


func _swing(door: Node3D, ratio: float) -> void:
	if door != null:
		door.rotation_degrees.y = BASEMENT_DOOR_OPEN_DEGREES * clampf(ratio, 0.0, 1.0)


func _build_npc(npc_texture: Texture2D) -> void:
	var route: Dictionary = LanguageCorruptionContentScript.get_basement_route(_round)
	if route.is_empty():
		push_error("Basement round %d has no NPC" % _round)
		return
	_npc = Area3D.new()
	_npc.name = "BasementNPC"
	_npc.position = BASEMENT_NPC_POSITION
	_npc.collision_layer = 2
	_npc.collision_mask = 0
	_npc.set_meta("actor_id", "basement_npc_%d" % _round)
	_npc.set_meta("actor_type", "basement_npc")
	_npc.set_meta("display_name", str(route.get("actor_label", "")))
	var collision := CollisionShape3D.new()
	collision.name = "InteractionShape"
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.5
	capsule.height = BASEMENT_NPC_HEIGHT
	collision.shape = capsule
	collision.position.y = BASEMENT_NPC_HEIGHT * 0.5
	_npc.add_child(collision)
	var sprite := Sprite3D.new()
	sprite.name = "Billboard"
	sprite.texture = npc_texture
	if npc_texture != null:
		sprite.pixel_size = BASEMENT_NPC_HEIGHT / maxf(1.0, float(npc_texture.get_height()))
	sprite.position.y = BASEMENT_NPC_HEIGHT * 0.5
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.double_sided = true
	_npc.add_child(sprite)
	add_child(_npc)


func _instance_model(path: String, node_name: String) -> bool:
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("Chapter one model did not load: %s" % path)
		return false
	_model = scene.instantiate() as Node3D
	if _model == null:
		push_error("Chapter one model has no Node3D root: %s" % path)
		return false
	_model.name = node_name
	add_child(_model)
	return true


func _build_environment(ambient: Color, ambient_energy: float) -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "ChapterOneEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = UiPalette.VOID
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = ambient
	environment.ambient_light_energy = ambient_energy
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment.environment = environment
	add_child(world_environment)


func _on_knock_finished() -> void:
	if _knock_reported:
		return
	_knock_reported = true
	GameEventBusScript.raise_event(GameEventsScript.OPENING_KNOCK_FINISHED)
