extends SceneTree

const VIEW_SIZE := Vector2i(1672, 941)
const PROJECT_DIR := "/Users/zhang/Documents/游戏/babel-meme-game"
const HEADLESS_CAPTURE_ERROR := "Screenshot capture requires a rendered display. Run this tool without --headless from a GUI session."


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if not _ensure_capture_supported():
		return
	var requested_floor := int(OS.get_environment("BABEL_CAPTURE_FLOOR"))
	var user_args := OS.get_cmdline_user_args()
	if not user_args.is_empty():
		requested_floor = int(user_args[0])
	var floor_number := clampi(requested_floor, 1, 5)
	if floor_number == 0:
		floor_number = 1
	var scene := load("res://scenes/babel_meme_game.tscn") as PackedScene
	if scene == null:
		push_error("Unable to load main scene")
		quit(1)
		return
	var main := scene.instantiate()
	root.add_child(main)
	main._locale.set_locale("zh")
	main.new_game()
	main._skip_prologue()
	main.game.tower_floor = floor_number
	main._ensure_reality_floor_current()
	main.set_view_state("npc_up")
	main._phone_art_alpha = 0.0
	var capture_crossroad := OS.get_environment("BABEL_CAPTURE_CROSSROAD") == "1" and floor_number == 1
	var capture_overview := OS.get_environment("BABEL_CAPTURE_OVERVIEW") == "1" and floor_number == 2
	main._reality_scene_adapter.yaw = -90.0 if capture_crossroad else main._reality_scene_adapter.floor.start_yaw_degrees()
	main._reality_scene_adapter.pitch = -3.0
	if main._phone_down_backdrop_image != null:
		main._phone_down_backdrop_image.visible = false
	if main._reality_scene_adapter.player != null:
		main._reality_scene_adapter.player.position = Vector3(0.0, 0.08, 0.0) if capture_crossroad else main._reality_scene_adapter.floor.start_position()
	for frame in 72:
		await process_frame
	if capture_overview:
		main.set_process(false)
		main._camera.attributes = null
		main._camera.fov = 86.0
		main._camera.global_position = Vector3(0.0, 145.0, 38.0)
		main._camera.look_at(Vector3(0.0, -0.2, 0.0), Vector3.UP)
		_set_canvas_layers_visible(main, false)
		var world_environment := _find_node_by_type(main, "WorldEnvironment") as WorldEnvironment
		if world_environment != null and world_environment.environment != null:
			world_environment.environment.fog_enabled = false
			world_environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			world_environment.environment.ambient_light_color = Color("C7D5BA")
			world_environment.environment.ambient_light_energy = 1.12
			world_environment.environment.background_color = Color("07110C")
		var review_light := DirectionalLight3D.new()
		review_light.name = "FloorTwoOverviewReviewLight"
		review_light.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
		review_light.light_color = Color("DDE8C9")
		review_light.light_energy = 1.35
		review_light.shadow_enabled = false
		main.add_child(review_light)
		for frame in 12:
			await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Unable to read root viewport image")
		quit(1)
		return
	var output_path := "%s/tools/current_reality_crossroad.png" % PROJECT_DIR if capture_crossroad else ("%s/tools/current_reality_floor_2_overview.png" % PROJECT_DIR if capture_overview else "%s/tools/current_reality_floor_%d.png" % [PROJECT_DIR, floor_number])
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Unable to save screenshot: %s" % error)
		quit(1)
		return
	print("saved screenshot: %s" % output_path)
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _ensure_capture_supported() -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true


func _set_canvas_layers_visible(node: Node, value: bool) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = value
	for child in node.get_children():
		_set_canvas_layers_visible(child, value)


func _find_node_by_type(node: Node, type_name: String) -> Node:
	if node.is_class(type_name):
		return node
	for child in node.get_children():
		var found := _find_node_by_type(child, type_name)
		if found != null:
			return found
	return null
