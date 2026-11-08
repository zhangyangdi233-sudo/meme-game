extends SceneTree
## Renders the basement of every round from a few fixed viewpoints, so the room's look (the model's materials, its
## lamps, the clutter, the taped door) can be checked on a real GPU. Round three is taken once its outage is over.
##
##   & $env:GODOT_BIN --path . --script res://tools/capture_basement_rounds.gd -- <output dir> [round ...]
##
## Needs a rendered display: run it without --headless.

const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RoomRulesScript = preload("res://scripts/game/room_rules.gd")

const VIEW_SIZE := Vector2i(1600, 900)
const EYE := 1.56
const FOV := 58.0
const SEED := 7
## Name, where the eye is, what it looks at (Godot space).
const VIEWS := [
	["landing", Vector3(-2.5, 2.72 + EYE, -1.6), Vector3(0.5, 0.9, 2.5)],
	["crt", Vector3(0.2, EYE, -0.6), Vector3(2.0, 1.0, 3.69)],
	["sealed_door", Vector3(0.2, 1.3, -1.9), Vector3(-1.83, 1.0, -2.0)],
	["rear", Vector3(2.4, EYE, 2.8), Vector3(-1.4, 0.8, -3.4)],
	["exit_door", Vector3(0.6, EYE, 0.6), Vector3(-3.2, 1.1, -3.43)],
	["stairs", Vector3(1.6, EYE, -0.2), Vector3(-2.4, 1.2, 1.6)],
	["tv_stairs", Vector3(2.5, 1.45, 3.3), Vector3(-1.8, 1.1, -1.4)],
]


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error("Run without --headless: the capture needs a rendered display.")
		quit(2)
		return
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- <output dir> [round ...]")
		quit(2)
		return
	var out_dir := args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	var rounds: Array[int] = []
	for value in args.slice(1):
		rounds.append(int(value))
	if rounds.is_empty():
		rounds = [1, 2, 3, 4, 5]
	root.size = VIEW_SIZE
	for round_number in rounds:
		var room := RoomContentScript.room(round_number)
		var started: Array = []
		for event: Dictionary in room.get("events", []):
			if event.get("cue") == "blackout":
				started.append(event["id"])
		var stage := ChapterOneStage.new()
		root.add_child(stage)
		stage.build(ChapterOneProgressScript.PHASE_BASEMENT, round_number, round_number == 1, RoomRulesScript.stands_npc(room))
		stage.decorate(SEED)
		stage.apply_room_state(RoomRulesScript.world_state(room, {}, round_number, started, started))
		var camera := Camera3D.new()
		camera.fov = FOV
		root.add_child(camera)
		camera.make_current()
		for view: Array in VIEWS:
			camera.look_at_from_position(view[1], view[2])
			for frame in 12:
				await process_frame
			var path := out_dir.path_join("round%d_%s.png" % [round_number, view[0]])
			root.get_texture().get_image().save_png(path)
			print("saved %s" % path)
		camera.queue_free()
		stage.queue_free()
		await process_frame
	quit(0)
