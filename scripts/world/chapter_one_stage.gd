class_name ChapterOneStage
extends Node3D
## Chapter one's stage behind the Reality scene adapter: the opening (black water, a white door 29.5 m ahead and
## the knock behind it) or the basement (an empty room for now), each from its imported model. The models bring
## their own walls and ground colliders; this stage adds the spawn, the playable bounds, the light and the door.
## The adapter drives it; the knock finishing is raised as a game event for the state to record.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")

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

var phase := ""
var _model: Node3D
var _bounds := AABB()
var _spawn := Vector3.ZERO
var _spawn_yaw := 0.0
var _door_pivot: Node3D
var _knock: AudioStreamPlayer3D
var _knock_started := false
var _knock_reported := false
var _paused := false


## Builds the stage for one chapter phase (`ChapterOneProgress.PHASE_OPENING` or `PHASE_BASEMENT`).
func build(stage_phase: String) -> bool:
	phase = stage_phase
	if phase == ChapterOneProgressScript.PHASE_OPENING:
		return _build_opening()
	if phase == ChapterOneProgressScript.PHASE_BASEMENT:
		return _build_basement()
	push_error("ChapterOneStage has no stage for phase '%s'" % phase)
	return false


func start_position() -> Vector3:
	return _spawn


func start_yaw_degrees() -> float:
	return _spawn_yaw


func has_door() -> bool:
	return _door_pivot != null


## The white door's center on the ground.
func door_position() -> Vector3:
	return OPENING_DOOR_CENTER


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


func _build_basement() -> bool:
	if not _instance_model(BASEMENT_MODEL_PATH, "BasementRoom"):
		return false
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
	return true


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
