extends SceneTree

const VIEW_SIZE := Vector2i(1280, 900)
const PROJECT_DIR := "/Users/zhang/Documents/游戏/babel-meme-game"
const HEADLESS_CAPTURE_ERROR := "Dreamcore screenshots require a rendered display. Run this tool without --headless."
const ARTIFACT_TYPES := [
	"false_window",
	"water_cooler",
	"crt_cart",
	"payphone",
	"folding_chair",
	"vending_machine",
	"fluorescent_troffer",
	"supply_crates",
	"pipe_manifold",
]
const TARGET_HEIGHTS := {
	"false_window": 1.70,
	"water_cooler": 1.05,
	"crt_cart": 1.18,
	"payphone": 1.20,
	"folding_chair": 1.02,
	"vending_machine": 1.22,
	"fluorescent_troffer": 1.62,
	"supply_crates": 1.18,
	"pipe_manifold": 1.30,
}
const CAMERA_OFFSETS := {
	"false_window": Vector3(3.7, 2.15, 7.5),
	"water_cooler": Vector3(2.4, 1.45, 4.9),
	"crt_cart": Vector3(3.0, 1.75, 5.8),
	"payphone": Vector3(2.5, 1.55, 5.2),
	"folding_chair": Vector3(2.6, 1.55, 5.0),
	"vending_machine": Vector3(2.9, 1.75, 5.9),
	"fluorescent_troffer": Vector3(2.9, 1.70, 5.8),
	"supply_crates": Vector3(3.2, 1.65, 6.0),
	"pipe_manifold": Vector3(3.0, 1.70, 5.8),
}


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if not _ensure_capture_supported():
		return
	var floor_number := clampi(int(OS.get_environment("BABEL_CAPTURE_FLOOR")), 2, 3)
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	main.new_game()
	main._skip_prologue()
	main.game.tower_floor = floor_number
	main._ensure_reality_floor_current()
	main.set_view_state("npc_up")
	main._phone_art_alpha = 0.0
	if main._phone_down_backdrop_image != null:
		main._phone_down_backdrop_image.visible = false
	_hide_canvas_layers(main)
	var actor_root := main._reality_scene_adapter.floor.get_node_or_null("Actors") as Node3D
	if actor_root != null:
		actor_root.visible = false
	for frame in 18:
		await process_frame
	main.set_process(false)
	var camera := main._camera as Camera3D
	if camera == null:
		push_error("Unable to locate the reality camera")
		quit(1)
		return
	camera.current = true
	camera.fov = 32.0
	camera.attributes = null
	_add_review_light(camera, floor_number)
	var artifacts: Array[Node3D] = []
	_collect_artifacts(main._reality_scene_adapter.floor, artifacts)
	_hide_non_preview_geometry(main._reality_scene_adapter.floor)
	var first_by_type: Dictionary = {}
	for artifact in artifacts:
		var artifact_type := str(artifact.get_meta("dreamcore_type", ""))
		if not first_by_type.has(artifact_type):
			first_by_type[artifact_type] = artifact
	if first_by_type.is_empty():
		push_error("No dreamcore artifacts found on floor %d" % floor_number)
		quit(1)
		return
	for artifact_type in ARTIFACT_TYPES:
		if not first_by_type.has(artifact_type):
			continue
		for artifact in artifacts:
			artifact.visible = artifact == first_by_type[artifact_type]
		var target_artifact := first_by_type[artifact_type] as Node3D
		_frame_artifact(camera, target_artifact, artifact_type)
		for frame in 10:
			await process_frame
		var image := root.get_texture().get_image()
		if image == null:
			push_error("Unable to read viewport for %s" % artifact_type)
			quit(1)
			return
		var output_path := "%s/tools/current_floor_%d_%s.png" % [PROJECT_DIR, floor_number, artifact_type]
		var error := image.save_png(output_path)
		if error != OK:
			push_error("Unable to save screenshot: %s" % output_path)
			quit(1)
			return
		print("saved screenshot: %s" % output_path)
	quit(0)


func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	for child in node.get_children():
		_hide_canvas_layers(child)


func _collect_artifacts(node: Node, output: Array[Node3D]) -> void:
	if node is Node3D and bool(node.get_meta("dreamcore_object", false)):
		output.append(node as Node3D)
	for child in node.get_children():
		_collect_artifacts(child, output)


func _hide_non_preview_geometry(node: Node) -> void:
	# Artifact roots remain intact and are switched one at a time in the capture
	# loop. Only architecture that can sit between the camera and item is hidden.
	if bool(node.get_meta("dreamcore_object", false)):
		return
	if node is VisualInstance3D:
		var keep_ground := node.name in ["StreetGround", "GalleryWalk", "FullMapGrass", "DiscSurface"]
		(node as VisualInstance3D).visible = keep_ground
	for child in node.get_children():
		_hide_non_preview_geometry(child)


func _frame_artifact(camera: Camera3D, artifact: Node3D, artifact_type: String) -> void:
	var target_height := float(TARGET_HEIGHTS.get(artifact_type, 1.4)) * artifact.global_basis.get_scale().y
	var target := artifact.global_position + Vector3.UP * target_height
	var local_offset := CAMERA_OFFSETS.get(artifact_type, Vector3(3.8, 2.3, 8.0)) as Vector3
	var facing_basis := artifact.global_basis.orthonormalized()
	camera.global_position = target + facing_basis * local_offset
	camera.look_at(target, Vector3.UP)


func _add_review_light(camera: Camera3D, floor_number: int) -> void:
	var light := OmniLight3D.new()
	light.name = "ArtifactReviewFill"
	light.light_color = Color("DDEBCE") if floor_number == 3 else Color("8FAE9B")
	light.light_energy = 1.4 if floor_number == 3 else 9.0
	light.omni_range = 18.0
	light.shadow_enabled = false
	camera.add_child(light)


func _ensure_capture_supported() -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
