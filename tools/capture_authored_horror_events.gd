extends SceneTree

const VIEW_SIZE := Vector2i(1280, 900)
const PROJECT_DIR := "/Users/zhang/Documents/游戏/babel-meme-game"
const HEADLESS_CAPTURE_ERROR := "Authored horror event screenshots require a rendered display. Run this tool without --headless."


func _init() -> void:
	call_deferred("_capture")


func _capture() -> void:
	root.size = VIEW_SIZE
	if not _ensure_capture_supported():
		return
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
	main.game.tower_floor = 3
	main.game.day = 1
	main._ensure_reality_floor_current()
	main.set_view_state("npc_up")
	main._phone_art_alpha = 0.0
	if main._phone_down_backdrop_image != null:
		main._phone_down_backdrop_image.visible = false
	_hide_canvas_layers(main)
	var actors := main._reality_scene_adapter.floor.get_node_or_null("Actors") as Node3D
	if actors != null:
		actors.visible = false
	for item in main._reality_scene_adapter.floor.get_interactable_items():
		item.visible = false
	for frame in 20:
		await process_frame
	main.set_process(false)
	var camera := main._camera as Camera3D
	camera.current = true
	camera.fov = 40.0
	camera.attributes = null
	var floor_root = main._reality_scene_adapter.floor
	var start: Vector3 = floor_root.start_position()

	var sign_event := _find_node_by_name(floor_root, "DeadSignEvent") as Node3D
	if sign_event == null:
		push_error("Unable to locate dead-sign event")
		quit(1)
		return
	var moved := start + Vector3(8.0, 0.0, 0.0)
	var toward_sign := (sign_event.global_position + Vector3.UP * 2.1 - moved).normalized()
	floor_root.update_authored_events(0.1, moved, toward_sign)
	floor_root.update_authored_events(0.1, moved, -toward_sign)
	_show_only_event(floor_root, sign_event)
	_frame_event(camera, sign_event, Vector3(3.0, 0.0, 5.5), 2.0)
	await _save_after_frames("current_horror_dead_sign.png")

	floor_root.configure_authored_events(2, main._ui_theme_helper.active_palette())
	var light_event := _find_node_by_name(floor_root, "LightMemoryEvent") as Node3D
	if light_event == null:
		push_error("Unable to locate light-memory event")
		quit(1)
		return
	moved = start + Vector3(5.0, 0.0, 0.0)
	floor_root.update_authored_events(0.50, moved, Vector3(0.0, 0.0, -1.0))
	_show_only_event(floor_root, light_event)
	_frame_event(camera, light_event, Vector3(3.2, -0.40, 6.4), 2.75)
	await _save_after_frames("current_horror_light_memory.png")

	floor_root.configure_authored_events(4, main._ui_theme_helper.active_palette())
	var mirage_event := _find_node_by_name(floor_root, "DistantMirageEvent") as Node3D
	if mirage_event == null:
		push_error("Unable to locate distant-mirage event")
		quit(1)
		return
	moved = start + Vector3(9.0, 0.0, 0.0)
	floor_root.update_authored_events(0.1, moved, Vector3(0.0, 0.0, -1.0))
	_show_only_event(floor_root, mirage_event)
	_frame_event(camera, mirage_event, Vector3(4.2, 0.25, 17.0), 1.20)
	await _save_after_frames("current_horror_distant_mirage.png")

	var watcher_event := _find_node_by_name(floor_root, "CoverWatcherEvent") as Node3D
	var watcher_sprite := _find_node_by_name(floor_root, "CoverWatcherSprite") as Sprite3D
	if watcher_event == null or watcher_sprite == null:
		push_error("Unable to locate cover-watcher event")
		quit(1)
		return
	_show_only_event(floor_root, watcher_event)
	var watcher_player: Vector3 = floor_root.start_position()
	var toward_watcher: Vector3 = (watcher_event.global_position - watcher_player).normalized()
	floor_root.update_authored_events(0.80, watcher_player, toward_watcher)
	if not watcher_sprite.visible or not bool(floor_root.get_cover_watcher_state().get("observed_in_view", false)):
		push_error("Cover watcher did not appear through the runtime observation path")
		quit(1)
		return
	_frame_event(camera, watcher_event, Vector3(0.0, 0.10, 7.0), 1.45)
	await _save_after_frames("current_horror_cover_watcher.png")
	var near_watcher := watcher_event.global_position + Vector3(0.0, 0.0, 5.7)
	floor_root.update_authored_events(0.01, near_watcher, toward_watcher)
	await _save_after_frames("current_horror_cover_watcher_retreat.png")
	floor_root.update_authored_events(0.71, near_watcher, toward_watcher)
	await _save_after_frames("current_horror_cover_watcher_gone.png")
	main.queue_free()
	await process_frame
	await process_frame
	quit(0)


func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	for child in node.get_children():
		_hide_canvas_layers(child)


func _show_only_event(floor_root: Node, target: Node3D) -> void:
	var events: Array[Node3D] = []
	_collect_event_roots(floor_root, events)
	for event_root in events:
		event_root.visible = event_root == target


func _collect_event_roots(node: Node, output: Array[Node3D]) -> void:
	if node is Node3D and bool(node.get_meta("authored_horror_event", false)):
		output.append(node as Node3D)
		return
	for child in node.get_children():
		_collect_event_roots(child, output)


func _frame_event(camera: Camera3D, event_root: Node3D, local_offset: Vector3, target_height: float) -> void:
	var target := event_root.global_position + Vector3.UP * target_height
	var facing_basis := event_root.global_basis.orthonormalized()
	camera.global_position = target + facing_basis * local_offset
	camera.look_at(target, Vector3.UP)


func _save_after_frames(file_name: String) -> void:
	for frame in 10:
		await process_frame
	var image := root.get_texture().get_image()
	if image == null:
		push_error("Unable to read viewport for %s" % file_name)
		quit(1)
		return
	var output_path := "%s/tools/%s" % [PROJECT_DIR, file_name]
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Unable to save screenshot: %s" % output_path)
		quit(1)
		return
	print("saved screenshot: %s" % output_path)


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for child in node.get_children():
		var found := _find_node_by_name(child, node_name)
		if found != null:
			return found
	return null


func _ensure_capture_supported() -> bool:
	if DisplayServer.get_name().to_lower() == "headless":
		push_error(HEADLESS_CAPTURE_ERROR)
		quit(2)
		return false
	return true
