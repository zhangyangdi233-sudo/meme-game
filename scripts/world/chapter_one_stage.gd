class_name ChapterOneStage
extends Node3D
## Chapter one's stage behind the Reality scene adapter: the opening (black water, a white door 29.5 m ahead and
## the knock behind it), the passage between levels (the same water and door, no knock, walked into) or one basement
## round (a room with the CRT terminal, the round's NPC when its room has one, and the seven things a rule can make the
## way out: the exit door, the stairs, the TV, the tables, the chairs, the clock and the lamps), each from its imported
## model. The models bring their own walls and ground colliders; this stage adds the spawn, the playable
## bounds, the light, the doors and their colliders, the NPC, the CRT's glass and a small table where the phone lies
## until the player owns it.
## A basement's lamps, hum and room objects (its clocks, the scattered chairs, the sunken screens) follow the round's room
## state, and the round's one-shot events play here (#114): the stage starts each on its trigger once its delay has
## passed on a clock the adapter holds while the world is held, plays its cue, and the wall switch ends the ones it can.
## The run's seed decides what lies on the exit table and how round three's chairs scatter.
## The adapter drives it; the knock finishing, the player walking out through the basement's open exit, the player
## walking into the passage's light and a room event starting are raised as game events for the state to record.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const CrtScreenScript = preload("res://scripts/world/crt_screen.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const BasementDecorScript = preload("res://scripts/game/basement_decor.gd")

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
## How near the door's center the player has walked into its light in the passage.
const PASSAGE_ENTER_DISTANCE := 1.2
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
const BASEMENT_AMBIENT_ENERGY := 0.35
## The lamp a room can light above the exit, just inside the wall over its doorway.
const EXIT_LAMP_POSITION := Vector3(-3.13, 2.38, -3.43)
const EXIT_LAMP_SIZE := Vector3(0.06, 0.1, 0.4)
const EXIT_LAMP_COLOR := Color(0.25, 1.0, 0.45)
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
## The small table against the east wall, between the stairs and the CRT: its center on the floor and its size. The
## model has none, so it is built from boxes.
const TABLE_POSITION := Vector3(2.55, 0.0, 0.6)
const TABLE_SIZE := Vector3(0.5, 0.72, 0.5)
const TABLE_COLOR := Color(0.24, 0.15, 0.09)
## The phone lying on the table: a dark slab with a faintly lit screen.
const PHONE_SIZE := Vector3(0.075, 0.012, 0.155)
const PHONE_COLOR := Color(0.05, 0.05, 0.06)
const PHONE_SCREEN_GLOW := Color(0.32, 0.42, 0.5)
## The wall clock on the east wall, facing the room. The model has none, so it is built from primitives.
const CLOCK_POSITION := Vector3(3.17, 1.95, -1.6)
const CLOCK_RADIUS := 0.17
const CLOCK_FACE_COLOR := Color(0.86, 0.82, 0.7)
const CLOCK_RIM_COLOR := Color(0.18, 0.12, 0.08)
## Where on the floor the player stands to use each exit object, and the point the view pushes in to (#144). Model
## props are found by node name; every one of a kind counts (any chair, any table, any lamp).
const EXIT_PROP_NODES := {
	"table": ["Prop_ChildTable", "Prop_RearSideTable"],
	"chair": ["Prop_Windsor_A", "Prop_Windsor_B", "Prop_TealChair"],
	"light": ["Main_OpalGlobe", "Rear_OpalGlobe"],
}
## How high above a prop's floor point the view pushes in to; a lamp is pushed in to where it hangs.
const EXIT_PROP_FOCUS_HEIGHT := {"table": 0.6, "chair": 0.55, "light": 0.0}
const EXIT_DOOR_REACH := Vector3(-2.85, 0.0, -3.43)
const EXIT_DOOR_FOCUS := Vector3(-4.2, 1.2, -3.43)
## The model's own lamps and their glass globes: what the room's `lights` and `brightness` switch and scale, with the
## stage's lights. The CRT's green light is apart: an outage leaves it on.
const MODEL_LAMP_LIGHTS := ["Main_PointLight", "Rear_PointLight"]
const MODEL_LAMP_GLOBES := ["Main_OpalGlobe", "Rear_OpalGlobe"]
const MODEL_CRT_LIGHT := "CRT_Green_PointLight"
const DARK_GLOBE_COLOR := Color(0.2, 0.22, 0.18)
## How much of the ambient light an outage leaves, so the CRT's green still finds the room.
const DARK_AMBIENT_SHARE := 0.12
## The wall switch by the foot of the stairs, and where the player stands to press it.
const SWITCH_NODE := "Prop_LightSwitch"
const SWITCH_REACH_OFFSET := Vector3(0.6, 0.0, 0.0)
## The room's middle, where round five's screens turn (#114): within this far of it on the floor.
const ROOM_CENTER := Vector3(0.0, 0.0, 0.0)
const ROOM_CENTER_RADIUS := 0.65
const ROOM_FLOOR_HEIGHT := 0.8
## A whisper flickers the lamps off on these beats (11 a second).
const FLICKER_BEATS := 11.0
## Round five's screens: black first, then red.
const SIGNAL_BLACK_SECONDS := 2.0
const SIGNAL_RED := Color(1.0, 0.0, 0.0)
const NO_SIGNAL := Color(0.0, 0.0, 0.0, 0.0)
const WHISPER_PATH := "res://assets/audio/dialogue/basement_whisper_8s.wav"
const STATIC_PATH := "res://assets/audio/sfx/tv_static_diarchangeli.ogg"
## The lamps' hum, made here: a mains buzz, as loud as the room's `hum` times this.
const HUM_GAIN := 0.3
const HUM_RATE := 22050
## Round four's wall of clocks, near the CRT on the wall behind it: columns and rows from its lower left, facing the room.
const CLOCK_WALL_ORIGIN := Vector3(-1.0, 1.45, 4.16)
const CLOCK_WALL_STEP := Vector2(0.48, 0.45)
const CLOCK_WALL_SIZE := Vector2i(6, 3)
const CLOCK_WALL_RADIUS := 0.17
## How far in front of a clock the player stands to use it.
const CLOCK_REACH := 0.6
## Round five's sunken screens: where each stands, its yaw and its tilt (radians), in the model's space; four sit in
## the walls. Clear of the room's middle, the stairs and the way to the exit.
const SUNKEN_CRTS := [
	[Vector3(2.40, -0.18, 2.80), -2.65, -0.08],
	[Vector3(2.55, -0.20, 1.75), -1.55, 0.06],
	[Vector3(2.05, -0.24, -1.15), -0.90, -0.05],
	[Vector3(-0.75, -0.19, 2.80), 2.65, 0.04],
	[Vector3(-1.13, -0.23, 0.65), 1.20, -0.08],
	[Vector3(0.75, -0.22, 1.65), 2.75, 0.08],
	[Vector3(2.40, -0.18, -3.20), -1.25, 0.05],
	[Vector3(-0.95, -0.20, -3.75), 0.45, -0.04],
	[Vector3(3.18, 0.72, 2.20), -PI / 2.0, 0.0],
	[Vector3(3.18, 1.48, -0.55), -PI / 2.0, 0.0],
	[Vector3(-0.55, 1.30, 4.18), PI, 0.0],
	[Vector3(1.90, 0.82, -4.18), 0.0, 0.0],
]
const SUNKEN_CRT_STANDBY := Color(0.22, 0.41, 0.27)
## The exit table at the rear and what the seed lays on it.
const EXIT_TABLE_TOP := Vector3(-1.64, 0.74, -3.9)
## The stairs, from the foot to the landing: any step counts. Each place stands at the height of the floor or step
## under it, so the floor beneath the landing is not the stairs.
const EXIT_STAIRS := [
	{"reach": Vector3(-2.5, 0.0, 2.9), "focus": Vector3(-2.5, 1.2, 1.2)},
	{"reach": Vector3(-2.5, 1.45, 0.5), "focus": Vector3(-2.5, 2.6, -0.8)},
	{"reach": Vector3(-2.5, 2.62, -1.9), "focus": Vector3(-2.5, 3.6, -2.3)},
]

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
var _passage_reported := false
var _phone: MeshInstance3D
var _environment: Environment
var _room_state: Dictionary = {}
## Room object names (`RoomContent.OBJECTS`) to what shows them.
var _room_objects: Dictionary = {}
## Exit object names (`RoomContent.EXIT_OBJECTS`) to their points: `reach` on the floor and `focus` to push in to.
## The clocks and the chairs are read from what the room shows instead.
var _exit_points: Dictionary = {}
## The lamps: each light with the energy it has at brightness 1, and the globes the outage darkens.
var _lamps: Array[Dictionary] = []
var _globes: Array[MeshInstance3D] = []
var _dark_globe: StandardMaterial3D
var _crt_light: Light3D
var _hum: AudioStreamPlayer
var _whisper: AudioStreamPlayer
var _static: AudioStreamPlayer
var _switch: Node3D
## The model's chairs, which round three's scattered pile replaces once its light is back.
var _chairs: Array[Node3D] = []
## What only the X-ray shows, and whether it looks now.
var _xray_nodes: Array[Node3D] = []
var _xray_looking := false
## Round five's sunken screens' glass, their red lights and the colour every screen shows now (none: their own).
var _sunken_glass: Array[StandardMaterial3D] = []
var _red_lights: Array[OmniLight3D] = []
var _screen_color := NO_SIGNAL
## The round's one-shot events (room data), the ids started (saved or here) and ended by the switch, how long each
## event's trigger has held, and how long each timed event started here has played.
var _events: Array = []
var _started_ids: Array = []
var _ended_ids: Array = []
var _trigger_waits: Dictionary = {}
var _playing: Dictionary = {}
var _entry_sealed := false
var _at_center := false
## What the playing cues do to the room right now.
var _cue_lamps_on := true
var _cue_crt_light_on := true
var _cue_hum_on := true
## The room's sounds are held (the world held, or settings open): nothing starts or stops them until they go on.
var _sounds_held := false


## Builds the stage for one chapter phase (`ChapterOneProgress.PHASE_OPENING`, `PHASE_PASSAGE` or `PHASE_BASEMENT`); a basement is
## built for its round, with that round's NPC shown by `npc_texture` unless `npc_stands` is false, and the phone on the
## table while nobody owns it.
func build(stage_phase: String, round_number: int = 0, npc_texture: Texture2D = null, phone_on_table: bool = false, npc_stands: bool = true) -> bool:
	phase = stage_phase
	_round = round_number
	if phase == ChapterOneProgressScript.PHASE_OPENING:
		return _build_opening()
	if phase == ChapterOneProgressScript.PHASE_PASSAGE:
		return _build_door_world()
	if phase == ChapterOneProgressScript.PHASE_BASEMENT:
		return _build_basement(npc_texture, phone_on_table, npc_stands)
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


## Where the phone lies on the table; zero when no phone is there.
func phone_position() -> Vector3:
	return _phone.position if _phone != null else Vector3.ZERO


## The player picked the phone up: it leaves the table.
func take_phone() -> void:
	if _phone == null:
		return
	_phone.get_parent().remove_child(_phone)
	_phone.queue_free()
	_phone = null


## Where the basement exit's doorway meets the floor; zero when there is no exit.
func exit_position() -> Vector3:
	return EXIT_DOORWAY if _exit_door != null else Vector3.ZERO


## Every place of an exit object (`RoomContent.EXIT_OBJECTS`) in this room: `reach`, where the player stands on the
## floor to use it, and `focus`, where the view pushes in to when leaving by it. Empty for an object the room lacks.
func exit_points(object_name: String) -> Array:
	if phase == ChapterOneProgressScript.PHASE_BASEMENT and object_name == "clock":
		return _clock_points()
	if phase == ChapterOneProgressScript.PHASE_BASEMENT and object_name == "chair" and _pile_shown():
		return _pile_points()
	return (_exit_points.get(object_name, []) as Array).duplicate(true)


## Follows the player: going down the basement's stairs shuts the entry behind them, and walking out through its open
## exit or into the passage's light is reported once.
func track_player(position: Vector3) -> void:
	if phase == ChapterOneProgressScript.PHASE_PASSAGE and not _passage_reported:
		if Vector2(position.x - OPENING_DOOR_CENTER.x, position.z - OPENING_DOOR_CENTER.z).length() <= PASSAGE_ENTER_DISTANCE:
			_passage_reported = true
			GameEventBusScript.raise_event(GameEventsScript.PASSAGE_DOOR_ENTERED)
	if _entry_door != null and position.z > ENTRY_SEAL_Z:
		_entry_target = 0.0
		_entry_sealed = true
	_at_center = (
		phase == ChapterOneProgressScript.PHASE_BASEMENT
		and position.y < ROOM_FLOOR_HEIGHT
		and Vector2(position.x - ROOM_CENTER.x, position.z - ROOM_CENTER.z).length() <= ROOM_CENTER_RADIUS
	)
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
	# The exit door is locked until the door is one of the round's exits (the rule, or the NPC's help).
	if _exit_door != null and ChapterOneProgressScript.door_open(progress):
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


## Shows the room as its data, its events and the rules in force say: the lamps follow its `lights` and `brightness`,
## the hum its `hum`, its objects come and go. Round three's pile of chairs stands in for the room's own chairs.
func apply_room_state(state: Dictionary) -> void:
	# A basement whose model did not load has no lights to follow.
	if phase != ChapterOneProgressScript.PHASE_BASEMENT or _environment == null or state == _room_state:
		return
	_room_state = state
	var objects: Dictionary = state.get("objects", {})
	for object_name in _room_objects:
		(_room_objects[object_name] as Node3D).visible = bool(objects.get(object_name, false))
	for chair in _chairs:
		chair.visible = not _pile_shown()
	_refresh_room()


## The run's seed lays what changes from run to run (`BasementDecor`): the vase or the book on the exit table, and the
## chairs of round three's pile. Called once the basement is built.
func decorate(seed: int) -> void:
	if phase != ChapterOneProgressScript.PHASE_BASEMENT or _model == null:
		return
	var on_table := BasementDecorScript.exit_table_prop(seed, _round)
	(get_node("ExitTableVase") as Node3D).visible = on_table == "vase"
	(get_node("ExitTableBook") as Node3D).visible = on_table == "book"
	var pile := _room_objects["scattered_chairs"] as Node3D
	for chair in pile.get_children():
		pile.remove_child(chair)
		chair.queue_free()
	if _chairs.is_empty():
		return
	for spec: Dictionary in BasementDecorScript.scattered_chairs(seed):
		var chair := _chairs[int(spec["model"]) % _chairs.size()].duplicate() as Node3D
		chair.name = "ScatteredChair%d" % pile.get_child_count()
		chair.visible = true
		var tilt := float(spec["tilt"])
		var lift := Vector3(0.0, 0.22, 0.0) if tilt != 0.0 else Vector3.ZERO
		chair.transform = Transform3D(Basis(Vector3.UP, float(spec["yaw"])) * Basis(Vector3.BACK, tilt), (spec["position"] as Vector3) + lift)
		pile.add_child(chair)
	for model_chair in _chairs:
		model_chair.visible = not _pile_shown()


## The round's one-shot events as its room lists them, with the ids the state already saved as started and as ended by
## the switch. A saved start is never played; a saved end stops the event if it plays here.
func set_room_events(events: Array, started: Array, ended: Array) -> void:
	_events = events
	var changed := false
	for event_id: Variant in started:
		if event_id not in _started_ids:
			_started_ids.append(event_id)
			changed = true
	for event_id: Variant in ended:
		if event_id not in _ended_ids:
			_ended_ids.append(event_id)
			_playing.erase(event_id)
			changed = true
	if changed:
		_refresh_cues()


## Moves the events' clock on by `delta`: an event whose trigger holds starts once its delay has passed, is reported
## (`ROOM_EVENT_STARTED`) and plays its cue; a timed one stops after its duration. A `held` world (the phone up, the
## CRT, a transition) and open settings stop the clock and the sounds where they are.
func advance_events(delta: float, held: bool) -> void:
	_hold_sounds(held or _paused)
	if _sounds_held or phase != ChapterOneProgressScript.PHASE_BASEMENT:
		return
	var step := maxf(delta, 0.0)
	var was_playing := not _playing.is_empty()
	for event_id: Variant in _playing:
		_playing[event_id] = float(_playing[event_id]) + step
	for event: Variant in _events:
		if not event is Dictionary or event.get("id") in _started_ids:
			continue
		# The delay counts while the trigger holds without a break: walking off the room's middle starts it over.
		if not _trigger_holds(str(event.get("trigger", ""))):
			_trigger_waits.erase(event.get("id"))
			continue
		var waited := float(_trigger_waits.get(event["id"], 0.0)) + step
		_trigger_waits[event["id"]] = waited
		if waited >= float(event.get("delay", 0.0)):
			_start_event(event, waited - float(event.get("delay", 0.0)))
	for event: Variant in _events:
		if event is Dictionary and _playing.has(event.get("id")) and float(_playing[event["id"]]) >= float(event.get("duration", 0.0)):
			_playing.erase(event["id"])
	if was_playing or not _playing.is_empty():
		_refresh_cues()


## The ids of the events going on that the wall switch can end: a timed one playing here, or one that lasts until the
## switch. Empty when pressing the switch would do nothing.
func switch_targets() -> Array:
	var targets: Array = []
	for event: Variant in _events:
		if not event is Dictionary or not _switch_ends(event) or event.get("id") in _ended_ids:
			continue
		if _playing.has(event["id"]) or (event["id"] in _started_ids and not event.has("duration")):
			targets.append(event["id"])
	return targets


## Where the player stands to press the wall switch; zero when the stage has none.
func switch_reach_position() -> Vector3:
	if _switch == null:
		return Vector3.ZERO
	var at := _model.transform * _switch.position + SWITCH_REACH_OFFSET
	return Vector3(at.x, 0.0, at.z)


## The player pressed the wall switch: the events it can end stop here. Answers their ids for the state to record.
func press_switch() -> Array:
	var ended := switch_targets()
	for event_id: Variant in ended:
		_playing.erase(event_id)
		_ended_ids.append(event_id)
	_refresh_cues()
	return ended


## The X-ray looks (X held, or the hands' frame): what only it shows appears, where the room shows it.
func set_xray_looking(looking: bool) -> void:
	_xray_looking = looking
	for node in _xray_nodes:
		node.visible = looking


## The colour every screen of the room shows over its own picture now; fully transparent when none does.
func screen_color() -> Color:
	return _screen_color


## Opening settings holds the knock where it is.
func set_paused(paused: bool) -> void:
	_paused = paused
	if _knock != null:
		_knock.stream_paused = paused
	_hold_sounds(paused)


## Swings the white door open: 0 is closed, 1 fully open away from the player. Its glow plane hides once it moves.
## The passage's door stays shut and full of light: the player walks into it.
func set_door_open_ratio(ratio: float) -> void:
	if _door_pivot == null or phase == ChapterOneProgressScript.PHASE_PASSAGE:
		return
	_door_pivot.rotation_degrees.y = OPENING_DOOR_OPEN_DEGREES * clampf(ratio, 0.0, 1.0)
	var light_plane := _model.find_child(OPENING_DOOR_LIGHT_PLANE, true, false) as Node3D
	if light_plane != null:
		light_plane.visible = ratio <= 0.0


func _build_opening() -> bool:
	if not _build_door_world():
		return false
	_knock = AudioStreamPlayer3D.new()
	_knock.name = "OpeningKnock"
	_knock.stream = load(KNOCK_PATH) as AudioStream
	_knock.unit_size = 18.0
	_knock.volume_db = -3.0
	_knock.position = OPENING_DOOR_CENTER + Vector3(0.0, 1.1, 0.0)
	_knock.finished.connect(_on_knock_finished)
	add_child(_knock)
	return true


## The black water and the white door, shared by the opening and the passage.
func _build_door_world() -> bool:
	if not _instance_model(OPENING_MODEL_PATH, "OpeningWorld"):
		return false
	_door_pivot = _model.find_child(OPENING_DOOR_PIVOT, true, false) as Node3D
	if _door_pivot == null:
		push_error("The opening model has no %s" % OPENING_DOOR_PIVOT)
		return false
	_bounds = OPENING_BOUNDS
	_spawn = OPENING_DOOR_CENTER + Vector3(0.0, 0.04, OPENING_WALK_DISTANCE)
	_spawn_yaw = 0.0
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


func _build_basement(npc_texture: Texture2D, phone_on_table: bool, npc_stands: bool) -> bool:
	if not _instance_model(BASEMENT_MODEL_PATH, "BasementRoom"):
		return false
	_entry_door = _bind_basement_door(ENTRY_DOOR_PIVOT)
	_exit_door = _bind_basement_door(EXIT_DOOR_PIVOT)
	_swing(_entry_door, _entry_ratio)
	_swing(_exit_door, _exit_ratio)
	if npc_stands:
		_build_npc(npc_texture)
	_build_table(phone_on_table)
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
	_build_environment(BASEMENT_LIGHT_COLOR.darkened(0.7), BASEMENT_AMBIENT_ENERGY)
	_build_exit_lamp()
	var glass := _model.find_child(CRT_SCREEN_NODE, true, false) as MeshInstance3D
	var screen := CrtScreenScript.new()
	if screen.bind(glass):
		_crt_screen = screen
	else:
		push_error("The basement model has no CRT glass (%s)" % CRT_SCREEN_NODE)
	_build_clock()
	_bind_lamps()
	_build_sounds()
	_build_clock_wall()
	_build_half_clock()
	_build_sunken_crts()
	_build_exit_table_props()
	_switch = _model.find_child(SWITCH_NODE, true, false) as Node3D
	var pile := Node3D.new()
	pile.name = "ScatteredChairs"
	pile.visible = false
	add_child(pile)
	_room_objects["scattered_chairs"] = pile
	_collect_exit_points()
	_refresh_room()
	return true


## The stage's lights and the model's own lamps, with their globes; the CRT's green light is kept apart.
func _bind_lamps() -> void:
	for light_name in BASEMENT_LIGHTS:
		_lamps.append({"light": get_node(light_name), "energy": float(BASEMENT_LIGHTS[light_name]["energy"])})
	for light_name: String in MODEL_LAMP_LIGHTS:
		var light := _model.find_child(light_name, true, false) as Light3D
		if light != null:
			_lamps.append({"light": light, "energy": light.light_energy})
	for globe_name: String in MODEL_LAMP_GLOBES:
		var globe := _model.find_child(globe_name, true, false) as MeshInstance3D
		if globe != null:
			_globes.append(globe)
	_dark_globe = _flat_material(DARK_GLOBE_COLOR)
	_crt_light = _model.find_child(MODEL_CRT_LIGHT, true, false) as Light3D


func _build_sounds() -> void:
	_hum = AudioStreamPlayer.new()
	_hum.name = "BasementHum"
	_hum.stream = _hum_stream()
	add_child(_hum)
	_whisper = AudioStreamPlayer.new()
	_whisper.name = "BasementWhisper"
	_whisper.stream = load(WHISPER_PATH) as AudioStream
	_whisper.volume_db = -11.0
	add_child(_whisper)
	_static = AudioStreamPlayer.new()
	_static.name = "ScreenStatic"
	_static.stream = load(STATIC_PATH) as AudioStream
	_static.volume_db = -16.0
	add_child(_static)


## One second of mains buzz that loops: 60 Hz and its first overtones.
func _hum_stream() -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(HUM_RATE * 2)
	for index in HUM_RATE:
		var t := float(index) / HUM_RATE
		var sample := 0.5 * sin(TAU * 60.0 * t) + 0.3 * sin(TAU * 120.0 * t) + 0.12 * sin(TAU * 180.0 * t)
		data.encode_s16(index * 2, int(clampf(sample, -1.0, 1.0) * 32000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = HUM_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = HUM_RATE
	return stream


## Round four's wall of clocks near the CRT; each clock faces the room and counts as the clock.
func _build_clock_wall() -> void:
	var wall := Node3D.new()
	wall.name = "ClockWall"
	wall.visible = false
	add_child(wall)
	for row in CLOCK_WALL_SIZE.y:
		for column in CLOCK_WALL_SIZE.x:
			var clock := _wall_clock(CLOCK_WALL_RADIUS, float(row * 7 + column) * 0.42, false)
			clock.name = "WallClock%d" % (row * CLOCK_WALL_SIZE.x + column)
			clock.position = CLOCK_WALL_ORIGIN + Vector3(column * CLOCK_WALL_STEP.x, row * CLOCK_WALL_STEP.y, 0.0)
			clock.rotation_degrees.y = 180.0
			clock.set_meta("reach", Vector3(clock.position.x, 0.0, clock.position.z - CLOCK_REACH))
			wall.add_child(clock)
	_room_objects["clock_wall"] = wall


## Round five's half clock where the single clock hangs: its right half broken off, the numbers that half held written
## on the wall where only the X-ray shows them.
func _build_half_clock() -> void:
	var clock := _wall_clock(CLOCK_RADIUS * 1.6, -0.72, true)
	clock.name = "HalfClock"
	clock.position = CLOCK_POSITION
	clock.rotation_degrees.y = -90.0
	clock.visible = false
	add_child(clock)
	_room_objects["half_clock"] = clock


## A clock facing its local +Z, built from primitives: a rim, a face, the twelve numbers and two hands. A `broken`
## clock keeps only its left half; numbers one to five are then ink on the wall that only the X-ray shows.
func _wall_clock(radius: float, hand_turn: float, broken: bool) -> Node3D:
	var clock := Node3D.new()
	var rim_material := _flat_material(CLOCK_RIM_COLOR)
	var face_material := _flat_material(CLOCK_FACE_COLOR)
	if broken:
		face_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		rim_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		clock.add_child(_half_disc("Rim", radius * 1.08, 0.0, rim_material))
		clock.add_child(_half_disc("Face", radius, 0.012, face_material))
	else:
		for part: Array in [["Rim", radius * 1.08, 0.05, rim_material, 0.0], ["Face", radius, 0.01, face_material, 0.026]]:
			var disc := MeshInstance3D.new()
			disc.name = str(part[0])
			var mesh := CylinderMesh.new()
			mesh.top_radius = float(part[1])
			mesh.bottom_radius = float(part[1])
			mesh.height = float(part[2])
			disc.mesh = mesh
			disc.rotation_degrees.x = 90.0
			disc.position.z = float(part[4])
			disc.material_override = part[3]
			clock.add_child(disc)
	for number in range(1, 13):
		var angle := float(number) * TAU / 12.0
		var numeral := Label3D.new()
		numeral.text = str(number)
		numeral.font_size = 40
		numeral.pixel_size = radius * 0.0045
		numeral.outline_size = 0
		numeral.modulate = CLOCK_RIM_COLOR
		numeral.position = Vector3(sin(angle), cos(angle), 0.0) * radius * 0.78 + Vector3(0.0, 0.0, 0.035)
		if broken and number <= 5:
			numeral.name = "XRayNumeral%d" % number
			numeral.modulate = Color(0.55, 1.0, 0.6)
			numeral.shaded = false
			numeral.visible = _xray_looking
			_xray_nodes.append(numeral)
		else:
			numeral.name = "Numeral%d" % number
			numeral.shaded = true
		clock.add_child(numeral)
	for hand: Array in [[0.62, hand_turn], [0.42, hand_turn * 2.3 + 1.1]]:
		var pivot := Node3D.new()
		pivot.position.z = 0.04
		pivot.rotation.z = float(hand[1])
		var needle := MeshInstance3D.new()
		var needle_mesh := BoxMesh.new()
		needle_mesh.size = Vector3(radius * 0.06, radius * float(hand[0]), 0.004)
		needle.mesh = needle_mesh
		needle.position.y = radius * float(hand[0]) * 0.5
		needle.material_override = rim_material
		pivot.add_child(needle)
		clock.add_child(pivot)
	return clock


## A half disc facing +Z: the left half of a clock's round.
func _half_disc(node_name: String, radius: float, depth: float, material: Material) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 24:
		var from := PI * float(index) / 24.0
		var to := PI * float(index + 1) / 24.0
		surface.set_normal(Vector3.BACK)
		surface.add_vertex(Vector3(0.0, 0.0, depth))
		surface.add_vertex(Vector3(-sin(from) * radius, cos(from) * radius, depth))
		surface.add_vertex(Vector3(-sin(to) * radius, cos(to) * radius, depth))
	var disc := MeshInstance3D.new()
	disc.name = node_name
	disc.mesh = surface.commit()
	disc.material_override = material
	return disc


## Round five's twelve screens sunk in the floor and walls: a cabinet, glass glowing the CRT's standby green, and a red
## light that only the red screens turn on.
func _build_sunken_crts() -> void:
	var sunk := Node3D.new()
	sunk.name = "SunkenCrts"
	sunk.visible = false
	add_child(sunk)
	var plastic := _flat_material(Color(0.52, 0.53, 0.47))
	for index in SUNKEN_CRTS.size():
		var spec: Array = SUNKEN_CRTS[index]
		var monitor := Node3D.new()
		monitor.name = "SunkenCrt%02d" % (index + 1)
		monitor.position = spec[0]
		monitor.rotation = Vector3(float(spec[2]), float(spec[1]), 0.0)
		var cabinet := MeshInstance3D.new()
		var cabinet_mesh := BoxMesh.new()
		cabinet_mesh.size = Vector3(0.78, 0.64, 0.6)
		cabinet.mesh = cabinet_mesh
		cabinet.position = Vector3(0.0, 0.36, -0.08)
		cabinet.material_override = plastic
		monitor.add_child(cabinet)
		var glass := MeshInstance3D.new()
		glass.name = "Glass"
		var glass_mesh := QuadMesh.new()
		glass_mesh.size = Vector2(0.6, 0.45)
		glass.mesh = glass_mesh
		glass.position = Vector3(-0.02, 0.4, 0.225)
		var glow := StandardMaterial3D.new()
		glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		glow.albedo_color = SUNKEN_CRT_STANDBY
		glass.material_override = glow
		glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		monitor.add_child(glass)
		_sunken_glass.append(glow)
		var red := OmniLight3D.new()
		red.name = "RedScreenLight"
		red.position = Vector3(0.0, 0.4, 0.5)
		red.light_color = SIGNAL_RED
		red.light_energy = 0.85
		red.omni_range = 3.3
		red.visible = false
		monitor.add_child(red)
		_red_lights.append(red)
		sunk.add_child(monitor)
	_room_objects["sunken_crts"] = sunk


## The vase and the book of the exit table, both built and hidden until the seed picks one (`decorate`).
func _build_exit_table_props() -> void:
	var vase := Node3D.new()
	vase.name = "ExitTableVase"
	vase.position = EXIT_TABLE_TOP
	vase.visible = false
	var ceramic := _flat_material(Color(0.54, 0.58, 0.48))
	for part: Array in [[0.10, 0.075, 0.18, 0.09], [0.039, 0.085, 0.11, 0.235]]:
		var piece := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = float(part[0])
		mesh.bottom_radius = float(part[1])
		mesh.height = float(part[2])
		piece.mesh = mesh
		piece.position.y = float(part[3])
		piece.material_override = ceramic
		vase.add_child(piece)
	add_child(vase)
	var book := Node3D.new()
	book.name = "ExitTableBook"
	book.position = EXIT_TABLE_TOP + Vector3(0.0, 0.017, 0.0)
	book.rotation.y = 0.14
	book.visible = false
	var cover := _flat_material(Color(0.33, 0.25, 0.19))
	var pages := _flat_material(Color(0.69, 0.65, 0.54))
	for part: Array in [
		[Vector3(0.22, 0.027, 0.30), Vector3.ZERO, pages],
		[Vector3(0.23, 0.007, 0.31), Vector3(0.0, -0.017, 0.0), cover],
		[Vector3(0.23, 0.007, 0.31), Vector3(0.0, 0.017, 0.0), cover],
		[Vector3(0.01, 0.034, 0.31), Vector3(-0.112, 0.0, 0.0), cover],
	]:
		var piece := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = part[0]
		piece.mesh = mesh
		piece.position = part[1]
		piece.material_override = part[2]
		book.add_child(piece)
	add_child(book)


## Holds the room's sounds where they are, or lets them go on. A held sound reads as not playing, so nothing may start
## or stop one while held; letting go first settles them to the cues playing now (a whisper the switch ended meanwhile
## stops, the hum comes back if the room has one).
func _hold_sounds(held: bool) -> void:
	if held == _sounds_held:
		return
	_sounds_held = held
	if not held:
		_refresh_cues()
	for player: AudioStreamPlayer in [_whisper, _static, _hum]:
		if player != null:
			player.stream_paused = held


func _switch_ends(event: Dictionary) -> bool:
	var ends: Variant = event.get("switch_ends", false)
	return ends is bool and ends


## Whether the event's trigger holds now: the entry has shut behind the player, or they stand in the room's middle.
func _trigger_holds(trigger: String) -> bool:
	match trigger:
		"entry_sealed":
			return _entry_sealed
		"room_center":
			return _at_center
	return false


func _start_event(event: Dictionary, played: float) -> void:
	_started_ids.append(event["id"])
	if event.has("duration"):
		_playing[event["id"]] = played
		if event.get("cue") == "whisper_flicker" and _whisper != null and _whisper.stream != null:
			_whisper.play(played)
	GameEventBusScript.raise_event(GameEventsScript.ROOM_EVENT_STARTED, {GameEventsScript.KEY_EVENT: str(event["id"])})


## What the cues playing now do to the room: the whisper flickers the lamps and cuts the hum on their dark beats; the
## red screens put out every lamp and the CRT's green and turn every screen black, then red with a hiss.
func _refresh_cues() -> void:
	_cue_lamps_on = true
	_cue_crt_light_on = true
	_cue_hum_on = true
	_screen_color = NO_SIGNAL
	var whispering := false
	var hissing := -1.0
	for event: Variant in _events:
		if not event is Dictionary or not _playing.has(event.get("id")):
			continue
		var played := float(_playing[event["id"]])
		match str(event.get("cue", "")):
			"whisper_flicker":
				whispering = true
				var beat := int(played * FLICKER_BEATS)
				if beat % 5 == 1 or beat % 7 == 2:
					_cue_lamps_on = false
					_cue_hum_on = false
			"red_screens":
				_cue_lamps_on = false
				_cue_crt_light_on = false
				_cue_hum_on = false
				_screen_color = Color.BLACK if played < SIGNAL_BLACK_SECONDS else SIGNAL_RED
				if played >= SIGNAL_BLACK_SECONDS:
					hissing = played - SIGNAL_BLACK_SECONDS
	if not _sounds_held:
		if _whisper != null and not whispering:
			_whisper.stop()
		if _static != null and _static.stream != null:
			if hissing >= 0.0 and not _static.playing:
				_static.play(hissing)
			elif hissing < 0.0:
				_static.stop()
	_refresh_room()


## Lays the room state and the cues over the lamps, the hum and the screens.
func _refresh_room() -> void:
	if _environment == null or phase != ChapterOneProgressScript.PHASE_BASEMENT:
		return
	var brightness := float(_room_state.get("brightness", 1.0))
	var lit := bool(_room_state.get("lights", true)) and _cue_lamps_on
	for lamp: Dictionary in _lamps:
		var light := lamp["light"] as Light3D
		light.visible = lit
		light.light_energy = float(lamp["energy"]) * brightness
	for globe in _globes:
		globe.material_override = null if lit else _dark_globe
	_environment.ambient_light_energy = BASEMENT_AMBIENT_ENERGY * brightness * (1.0 if lit else DARK_AMBIENT_SHARE)
	if _crt_light != null:
		_crt_light.visible = _cue_crt_light_on
	var hum := float(_room_state.get("hum", 0.0))
	if _hum != null and not _sounds_held:
		if hum > 0.0 and _cue_hum_on:
			_hum.volume_db = linear_to_db(hum * HUM_GAIN)
			if not _hum.playing:
				_hum.play()
		else:
			_hum.stop()
	var showing := _screen_color != NO_SIGNAL
	for glass in _sunken_glass:
		glass.albedo_color = _screen_color if showing else SUNKEN_CRT_STANDBY
	for light in _red_lights:
		light.visible = _screen_color == SIGNAL_RED
	if _crt_screen != null:
		if showing:
			_crt_screen.show_signal(_screen_color)
		else:
			_crt_screen.clear_signal()


## Every clock the room shows now: the single clock, each clock of the wall, or the half clock where the single one hangs.
func _clock_points() -> Array:
	var points: Array = []
	for object_name: String in ["wall_clock", "half_clock"]:
		var clock := _room_objects.get(object_name) as Node3D
		if clock != null and clock.visible:
			points.append({"reach": Vector3(CLOCK_POSITION.x - CLOCK_REACH, 0.0, CLOCK_POSITION.z), "focus": CLOCK_POSITION})
	var wall := _room_objects.get("clock_wall") as Node3D
	if wall != null and wall.visible:
		for clock: Node3D in wall.get_children():
			points.append({"reach": clock.get_meta("reach"), "focus": clock.position})
	return points


func _pile_shown() -> bool:
	var pile := _room_objects.get("scattered_chairs") as Node3D
	return pile != null and pile.visible and pile.get_child_count() > 0


func _pile_points() -> Array:
	var points: Array = []
	for chair: Node3D in (_room_objects["scattered_chairs"] as Node3D).get_children():
		var at := chair.position
		points.append({"reach": Vector3(at.x, 0.0, at.z), "focus": Vector3(at.x, float(EXIT_PROP_FOCUS_HEIGHT["chair"]), at.z)})
	return points


## Finds every exit object of the room: the door, the stairs, the CRT, the tables (the phone's too), the chairs, the
## clock and the lamps.
func _collect_exit_points() -> void:
	_exit_points = {"door": [{"reach": EXIT_DOOR_REACH, "focus": EXIT_DOOR_FOCUS}], "stairs": EXIT_STAIRS.duplicate(true)}
	if _crt_screen != null:
		_exit_points["tv"] = [{"reach": crt_reach_position(), "focus": _crt_screen.center()}]
	_exit_points["table"] = [{"reach": TABLE_POSITION, "focus": TABLE_POSITION + Vector3(0.0, TABLE_SIZE.y, 0.0)}]
	for object_name: String in EXIT_PROP_NODES:
		var points: Array = _exit_points.get_or_add(object_name, [])
		for node_name: String in EXIT_PROP_NODES[object_name]:
			var prop := _model.find_child(node_name, true, false) as Node3D
			if prop == null:
				push_error("The basement model has no %s" % node_name)
				continue
			if object_name == "chair":
				_chairs.append(prop)
			var at := _model.transform * prop.position
			points.append({"reach": Vector3(at.x, 0.0, at.z), "focus": Vector3(at.x, at.y + float(EXIT_PROP_FOCUS_HEIGHT[object_name]), at.z)})


func _build_clock() -> void:
	var clock := Node3D.new()
	clock.name = "BasementClock"
	clock.position = CLOCK_POSITION
	clock.rotation_degrees.z = 90.0
	var rim := MeshInstance3D.new()
	rim.name = "Rim"
	var rim_mesh := CylinderMesh.new()
	rim_mesh.top_radius = CLOCK_RADIUS
	rim_mesh.bottom_radius = CLOCK_RADIUS
	rim_mesh.height = 0.05
	rim.mesh = rim_mesh
	rim.material_override = _flat_material(CLOCK_RIM_COLOR)
	clock.add_child(rim)
	var face := MeshInstance3D.new()
	face.name = "Face"
	var face_mesh := CylinderMesh.new()
	face_mesh.top_radius = CLOCK_RADIUS * 0.88
	face_mesh.bottom_radius = CLOCK_RADIUS * 0.88
	face_mesh.height = 0.01
	face.mesh = face_mesh
	face.position.y = 0.026
	face.material_override = _flat_material(CLOCK_FACE_COLOR)
	clock.add_child(face)
	for hand: Array in [[0.11, 0.0], [0.075, 125.0]]:
		var mesh_instance := MeshInstance3D.new()
		var hand_mesh := BoxMesh.new()
		hand_mesh.size = Vector3(0.012, 0.004, float(hand[0]))
		mesh_instance.mesh = hand_mesh
		mesh_instance.rotation_degrees.y = float(hand[1])
		mesh_instance.position = Vector3(0.0, 0.033, 0.0) + Basis(Vector3.UP, deg_to_rad(float(hand[1]))) * Vector3(0.0, 0.0, -float(hand[0]) * 0.5)
		mesh_instance.material_override = _flat_material(CLOCK_RIM_COLOR)
		clock.add_child(mesh_instance)
	add_child(clock)
	_room_objects["wall_clock"] = clock


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
	_npc.set_meta("actor_type", ChapterOneProgressScript.BASEMENT_NPC_ACTOR_TYPE)
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


func _build_table(phone_on_table: bool) -> void:
	var table := StaticBody3D.new()
	table.name = "BasementTable"
	table.position = TABLE_POSITION
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = TABLE_SIZE
	shape.shape = box
	shape.position.y = TABLE_SIZE.y * 0.5
	table.add_child(shape)
	var top := MeshInstance3D.new()
	top.name = "Top"
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(TABLE_SIZE.x, 0.04, TABLE_SIZE.z)
	top.mesh = top_mesh
	top.position.y = TABLE_SIZE.y - 0.02
	top.material_override = _flat_material(TABLE_COLOR)
	table.add_child(top)
	var leg_height := TABLE_SIZE.y - 0.04
	for corner in [Vector2(-1, -1), Vector2(-1, 1), Vector2(1, -1), Vector2(1, 1)]:
		var leg := MeshInstance3D.new()
		var leg_mesh := BoxMesh.new()
		leg_mesh.size = Vector3(0.04, leg_height, 0.04)
		leg.mesh = leg_mesh
		leg.position = Vector3(corner.x * (TABLE_SIZE.x * 0.5 - 0.03), leg_height * 0.5, corner.y * (TABLE_SIZE.z * 0.5 - 0.03))
		leg.material_override = top.material_override
		table.add_child(leg)
	add_child(table)
	if not phone_on_table:
		return
	_phone = MeshInstance3D.new()
	_phone.name = "BasementPhone"
	var phone_mesh := BoxMesh.new()
	phone_mesh.size = PHONE_SIZE
	_phone.mesh = phone_mesh
	_phone.position = TABLE_POSITION + Vector3(0.0, TABLE_SIZE.y + PHONE_SIZE.y * 0.5, 0.0)
	_phone.rotation_degrees.y = 18.0
	var phone_material := _flat_material(PHONE_COLOR)
	phone_material.emission_enabled = true
	phone_material.emission = PHONE_SCREEN_GLOW
	phone_material.emission_energy_multiplier = 0.35
	_phone.material_override = phone_material
	add_child(_phone)


func _build_exit_lamp() -> void:
	var lamp := MeshInstance3D.new()
	lamp.name = "ExitLamp"
	var mesh := BoxMesh.new()
	mesh.size = EXIT_LAMP_SIZE
	lamp.mesh = mesh
	lamp.position = EXIT_LAMP_POSITION
	var material := _flat_material(EXIT_LAMP_COLOR)
	material.emission_enabled = true
	material.emission = EXIT_LAMP_COLOR
	material.emission_energy_multiplier = 2.5
	lamp.material_override = material
	var glow := OmniLight3D.new()
	glow.name = "Glow"
	glow.light_color = EXIT_LAMP_COLOR
	glow.light_energy = 0.6
	glow.omni_range = 2.5
	lamp.add_child(glow)
	lamp.visible = false
	add_child(lamp)
	_room_objects["exit_lamp"] = lamp


func _flat_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.8
	return material


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
	_environment = environment
	add_child(world_environment)


func _on_knock_finished() -> void:
	if _knock_reported:
		return
	_knock_reported = true
	GameEventBusScript.raise_event(GameEventsScript.OPENING_KNOCK_FINISHED)
