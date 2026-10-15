extends SceneTree
## Exercises the production scene, authored table pickup, save/continue, input
## handlers and shared app controls. Only the opening and NPC delivery proofs
## use trusted chapter events; no physical camera or user's save is accessed.

const State = preload("res://scripts/meme_game_state.gd")
const Director = preload("res://scripts/progression/basement_loop_director.gd")
const World = preload("res://scripts/world/chapter_world.gd")

class FakeReceiver:
	extends RefCounted
	signal frame_received(hands: Array, timestamp_msec: int)
	signal status_changed(status: String)
	signal source_ready(source: String, selected_index: int)
	var camera_source := "computer"
	var start_count := 0
	func start(_launch_sidecar: bool = true) -> bool:
		start_count += 1
		return true
	func stop() -> void:
		pass
	func poll() -> void:
		pass
	func get_status() -> String:
		return "Phone integration test: physical camera disabled"

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	root.size = Vector2i(1600, 900)
	await _test_required_pickup_exit()
	var main = load("res://scenes/babel_meme_game.tscn").instantiate()
	var receiver := FakeReceiver.new()
	main._hand_tracking_receiver = receiver
	receiver.frame_received.connect(main._on_hand_tracking_frame)
	receiver.status_changed.connect(main._on_hand_tracking_status_changed)
	receiver.source_ready.connect(main._on_camera_source_ready)
	main._save_path = "user://aphasia_test_phone_dock_flow.dat"
	main._locale.preferences_path = "user://aphasia_test_phone_dock_flow.cfg"
	main._locale.save_preferences(80, false, false, "computer")
	root.add_child(main)
	main._resolve_camera_consent(false)
	main._locale.set_locale("zh")
	main._begin_game_session(_basement_state(), {}, false)
	main._set_reality_mouse_look(false)
	await _frames()
	await _test_pickup_and_continue(main)
	await _test_edge_and_tab_input(main)
	await _test_earned_apps(main)
	await _test_small_viewports(main)
	_check(receiver.start_count == 0, "phone flow never starts a physical camera")
	main._set_reality_mouse_look(false)
	main.free()
	await _frames()
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("phone dock flow tests passed (%d checks; real scene, authored GLB, F, save/continue, edge tween, Tab, NPC app permissions and small viewports)" % checks)
	quit(0 if failures.is_empty() else 1)

func _test_required_pickup_exit() -> void:
	# Bind the real basement GLB, including its table. This proves the physical
	# exit cannot strand a new player in the tower without ever taking a phone.
	var state := _basement_state()
	var token: int = state.chapter1_progress.transition_serial
	state.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
	state.notify_chapter1("npc_help_completed", {"round_token": token, "task_id": Director.TASK_IDS[0], "npc_id": Director.NPC_IDS[0]})
	var world := World.new()
	root.add_child(world)
	_check(world.configure_stage(state.chapter1_progress, {}), "exit safety fixture binds the production basement GLB")
	world.event_requested.connect(func(event_id: String, payload: Dictionary):
		var result: Dictionary = state.notify_chapter1(event_id, payload)
		if result.accepted:
			world.sync_progress(state.chapter1_progress)
	)
	var phone: Area3D
	var exit_actor: Area3D
	for actor: Area3D in world.get_interactable_actors():
		match str(actor.get_meta("actor_type", "")):
			"chapter1_phone": phone = actor
			"chapter1_exit": exit_actor = actor
	_check(phone != null and exit_actor != null, "completed first NPC still leaves both table phone and physical exit")
	if phone != null and exit_actor != null:
		var door: Node = world.get_door("exit")
		_check(not world.interact(exit_actor), "completed NPC cannot bypass the uncollected phone at the exit")
		_check(not door.request_open() and not door.is_passable(), "authored exit collision stays closed while phone waits on table")
		_check(world.interact(phone), "player can still take the table phone after completing first NPC")
		_check(bool(state.chapter1_progress.phone_collected), "physical pickup synchronizes persistent ownership")
		_check(world.interact(exit_actor), "same exit accepts interaction after physical pickup")
		_check(door.request_open(), "pickup releases the real exit hinge lock")
		await create_timer(door.get_open_duration() + 0.05).timeout
		_check(door.is_passable(), "exit collision becomes passable after its opening animation")
	world.free()
	await _frames()

func _test_pickup_and_continue(main: Node) -> void:
	var dock = main._phone_panel
	_check(main._chapter_world_ready, "production basement binds for the phone pickup")
	_check(not dock.visible and not dock.tab.visible, "uncollected phone has no body or edge handle")
	_key(main, KEY_TAB)
	await _frames()
	_check(main.game.view_state == "npc_up" and not dock.visible, "Tab cannot open an uncollected phone")
	main._on_app_pressed("social")
	_check(main.game.active_app_window.is_empty(), "direct app callback cannot bypass physical ownership")
	var actor := _phone_actor(main)
	_check(actor != null, "first basement contains the authored table phone actor")
	if actor == null:
		return
	var model := actor.get_node_or_null("PhoneModel") as Node3D
	_check(model != null and model.is_visible_in_tree(), "physical PhoneModel is visible before pickup")
	_check(model != null and model.find_children("*", "MeshInstance3D", true, false).size() >= 2, "table pickup contains imported phone geometry")
	main._reality_player.global_position = actor.global_position + Vector3(0.0, 0.05, 0.35)
	main._reality_player.velocity = Vector3.ZERO
	main._reality_last_safe_position = main._reality_player.position
	main._refresh_nearby_reality_actor()
	_check(main._nearby_reality_actor == actor, "approaching table selects its physical phone for F")
	_key(main, KEY_F)
	await _frames()
	_check(bool(main.game.chapter1_progress.get("phone_collected", false)), "F reaches the real pickup event and grants ownership")
	_check(not actor.is_visible_in_tree() and not model.is_visible_in_tree(), "successful pickup hides the table actor and its mesh")
	_check(_phone_actor(main) == null, "collected phone is removed from the reachable actor list")
	_check(dock.tab.visible, "collected phone exposes its right-edge handle")
	_check(dock.app_buttons.values().filter(func(button: Button): return button.visible).size() == 2 and not dock.app_buttons.map.visible, "chapter-one launcher contains exactly two visible apps and keeps map hidden")
	_check(dock.app_buttons.social.disabled and dock.app_buttons.notebook.disabled, "pickup alone leaves both apps disabled")
	main._save_progress()
	_check(main.continue_game(), "actual main-scene save envelope can continue the pickup")
	await _frames()
	main._set_reality_mouse_look(false)
	_check(bool(main.game.chapter1_progress.get("phone_collected", false)), "continue preserves ownership")
	_check(_phone_actor(main) == null, "continued basement does not recreate a collectible phone")
	var continued_model := main._reality_floor.find_child("PhoneModel", true, false) as Node3D
	_check(continued_model == null or not continued_model.is_visible_in_tree(), "continued world has no visible duplicate table model")
	_check(main._phone_panel.tab.visible, "continue restores the edge handle")

func _test_edge_and_tab_input(main: Node) -> void:
	var dock = main._phone_panel
	main.set_view_state("npc_up")
	await create_timer(0.60).timeout
	var closed_x: float = dock.position.x
	_check(closed_x > main._viewport_size().x, "closed body rests beyond the right edge")
	dock.tab.pressed.emit()
	_check(main.game.view_state == "phone_down", "clicking edge handle opens the phone")
	_check(is_equal_approx(dock.position.x, closed_x), "opening starts from the closed position without snapping")
	await create_timer(0.20).timeout
	var opening_x: float = dock.position.x
	_check(opening_x < closed_x and opening_x > main._viewport_size().x - dock.size.x * dock.scale.x - 24, "opening passes through an intermediate eased position")
	await create_timer(0.40).timeout
	_check(dock.position.x < opening_x, "opening finishes its animated travel")
	_check(main._reality_floor.visible and main._reality_player.visible, "live world remains visible behind the phone")
	_check(main._phone_down_backdrop_image == null or not main._phone_down_backdrop_image.visible, "legacy hand-held backdrop stays hidden while open")
	_check(main._hand_phone_image == null or not main._hand_phone_image.visible, "legacy hand image stays hidden while open")
	_check(main._phone_rig == null or not main._phone_rig.visible, "retired floating 3D phone stays hidden")
	var open_x: float = dock.position.x
	dock.tab.pressed.emit()
	_check(main.game.view_state == "npc_up", "same edge handle closes the phone")
	await create_timer(0.20).timeout
	_check(dock.position.x > open_x and dock.position.x < closed_x, "closing also traverses an intermediate eased position")
	await create_timer(0.40).timeout
	_check(dock.position.x >= closed_x - 0.5 and dock.tab.visible, "closed phone leaves only its handle available")
	_key(main, KEY_TAB)
	await create_timer(0.60).timeout
	_check(main.game.view_state == "phone_down", "Tab remains compatible with opening")
	_key(main, KEY_TAB)
	await create_timer(0.60).timeout
	_check(main.game.view_state == "npc_up", "Tab remains compatible with closing")

func _test_earned_apps(main: Node) -> void:
	# Deliver through the main chapter event bridge, so app refresh, world sync
	# and automatic persistence execute as they do after the dialogue proof.
	for visit in range(3):
		var token: int = main.game.chapter1_progress.transition_serial
		main.notify_chapter1("entrance_threshold_crossed", {"round_token": token})
		var result: Dictionary = main.notify_chapter1("npc_help_completed", {"round_token": token, "task_id": Director.TASK_IDS[visit], "npc_id": Director.NPC_IDS[visit]})
		_check(result.accepted, "NPC %d delivery reaches the production chapter bridge" % (visit + 1))
		await _frames()
		var dock = main._phone_panel
		_check(not dock.app_buttons.social.disabled, "NPC %d retains earned waterfall permission" % (visit + 1))
		_check(dock.app_buttons.notebook.disabled == (visit < 2), "notebook remains locked until NPC 3 delivery")
		main.set_view_state("phone_down")
		await create_timer(0.60).timeout
		dock.app_buttons.social.pressed.emit()
		await create_timer(0.26).timeout
		_check(main.game.active_app_window == "social", "earned waterfall icon opens its real app")
		_check(main._app_windows.social.get_parent() == dock.screen and dock.screen.clip_contents, "social app is inside the phone's clipping screen")
		_check(main._app_windows.social.is_visible_in_tree() and not dock.launcher.visible, "social page replaces the launcher inside the phone")
		_check(_rect_inside(main._app_windows.social.get_global_rect(), dock.screen.get_global_rect()), "social window cannot float beyond the phone's content bounds")
		_check(main._social_detail_window.get_parent() == dock.screen, "social detail is also attached inside the phone")
		if visit == 2:
			main._on_pickup_unit_meta("门", "floor_13")
			await _frames()
			_check(main.game.is_social_char_collected("门", "zh"), "phone social pickup adds the real word to shared inventory")
			_check(main.game.active_app_window == "social" and main._app_windows.social.is_visible_in_tree() and not main._app_windows.notebook.visible, "picking a word keeps the social page visible instead of opening notebook over it")
			_check(main._notebook_window_control() == main._app_windows.notebook, "pickup feedback resolves the embedded notebook without a draggable-window registry")
			_check(dock.get_global_rect().has_point(main._notebook_flight_target()), "word pickup flight lands inside the actual phone body")
			main._pickup_flight_layer.finish_all_immediately()
			main._phone_go_home()
			dock.app_buttons.notebook.pressed.emit()
			await create_timer(0.26).timeout
			_check(main.game.active_app_window == "notebook", "NPC 3's notebook icon opens its real app")
			_check(main._app_windows.notebook.get_parent() == dock.screen and main._app_windows.notebook.is_visible_in_tree(), "notebook stays inside the same phone screen")
			_check(_rect_inside(main._app_windows.notebook.get_global_rect(), dock.screen.get_global_rect()), "notebook cannot float beyond the phone content bounds")
			main._phone_go_home()
			_check(dock.launcher.visible and not main._app_windows.social.visible and not main._app_windows.notebook.visible, "phone home returns to only two icons")
		main.set_view_state("npc_up")
		if visit < 2:
			main.notify_chapter1("basement_tunnel_entered", {"round_token": token})
			var next: Dictionary = main.notify_chapter1("basement_exit_requested", {"round_token": token})
			_check(next.accepted, "phone test proceeds to the next authored basement visit")
			await _frames()

func _test_small_viewports(main: Node) -> void:
	# Configure the actual dock against tiny layout surfaces directly; this
	# avoids project window scaling silently substituting a 1600px viewport.
	main.set_process(false)
	var dock = main._phone_panel
	for viewport in [Vector2(320, 240), Vector2(160, 120), Vector2(80, 60), Vector2(32, 32)]:
		dock.configure(true, true, {"social": true, "notebook": true}, viewport, true)
		await create_timer(0.60).timeout
		var bounds := Rect2(Vector2.ZERO, viewport)
		_check(dock.scale.x > 0 and dock.scale.y > 0, "%s viewport never produces a reversed or zero-size phone" % viewport)
		_check(_rect_inside(dock.get_global_rect().abs(), bounds), "%s viewport contains the open phone body" % viewport)
		_check(_rect_inside(dock.tab.get_global_rect(), bounds), "%s viewport contains the complete clickable edge handle" % viewport)
		_check(dock.get_global_rect().has_point(main._notebook_flight_target()), "%s viewport keeps the scaled word pickup destination inside the phone" % viewport)
	dock.configure(true, false, {"social": true, "notebook": true}, Vector2(1600, 900), true)

func _phone_actor(main: Node) -> Area3D:
	for actor: Area3D in main._reality_floor.get_interactable_actors():
		if str(actor.get_meta("actor_type", "")) == "chapter1_phone":
			return actor
	return null

func _key(main: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	main._unhandled_input(event)

func _rect_inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5

func _basement_state() -> MemeGameState:
	var state := State.new()
	state.new_run()
	state.start_chapter1()
	state.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_knock_completed", {"sequence_id": "chapter1_opening"})
	state.notify_chapter1("opening_door_opened")
	state.view_state = "npc_up"
	state.active_app_window = ""
	return state

func _frames(count: int = 3) -> void:
	for index in range(count):
		await process_frame

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
