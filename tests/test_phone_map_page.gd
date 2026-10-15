extends SceneTree

var failures: Array[String] = []
var checks := 0

func _init() -> void:
	root.visible = false
	_run.call_deferred()

func _run() -> void:
	if not ResourceLoader.exists("res://scripts/ui/phone_map_page.gd"):
		_check(false, "phone map page component exists")
		_finish()
		return
	var dock = load("res://scripts/ui/phone_dock.gd").new()
	var host := Control.new()
	root.add_child(host)
	host.add_child(dock)
	await process_frame
	dock.configure(true, true, {"social": true, "notebook": true}, Vector2(1600, 900))
	await create_timer(0.6).timeout
	_check(dock.app_buttons.has("map"), "third app uses the normal phone registry")
	if not dock.app_buttons.has("map"):
		host.free()
		_finish()
		return
	_check(dock.app_buttons.map.icon != null, "map app loads its original folded-map icon")
	_check(not dock.app_buttons.map.visible, "chapter one retains exactly two visible app icons")
	_check(dock.app_buttons.social.position == Vector2(39, 87) and dock.app_buttons.notebook.position == Vector2(210, 87), "first two app positions remain unchanged")
	dock.configure(true, true, {"social": true, "notebook": true, "map": false}, Vector2(1600, 900))
	_check(dock.app_buttons.map.visible and dock.app_buttons.map.disabled, "second floor shows the locked map before reward")
	dock.configure(true, true, {"social": true, "notebook": true, "map": true}, Vector2(1600, 900))
	_check(not dock.app_buttons.map.disabled, "map reward enables the existing app button")
	var requests: Array[String] = []
	dock.app_requested.connect(func(app_id: String): requests.append(app_id))
	dock.app_buttons.map.pressed.emit()
	_check(requests == ["map"], "map uses the same app_requested contract")
	var page = load("res://scripts/ui/phone_map_page.gd").new()
	# The host may configure before adding/layout; both calls must be safe.
	page.configure({})
	page.configure(_snapshot())
	dock.screen.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dock.show_page("map", {"map": page})
	await _frames()
	_check(page.find_children("*", "ScrollContainer", true, false).is_empty(), "map has no scroll viewport")
	_check(page.find_children("*", "Camera3D", true, false).is_empty() and page.find_children("*", "SubViewport", true, false).is_empty(), "map UI adds no camera or extra world viewport")
	_check(page._grid_image.get_pixel(0, 0) == Color.BLACK, "unexplored grid stays opaque pure black")
	_check(page._grid_image.get_pixel(1, 1) == page.ROAD_COLOR, "revealed walkable grid uses paper road color")
	_check(page._grid_image.get_pixel(2, 1) == page.WALL_COLOR, "revealed blocked grid uses gray building color")
	var image_id: int = page._grid_texture.get_instance_id()
	var nodes_before: int = page.get_child_count()
	var rebuilds: int = page.grid_rebuild_count
	for index in 120:
		var moved := _snapshot()
		moved.player_uv = Vector2(0.4 + index * 0.001, 0.5)
		moved.heading_radians = index * 0.01
		page.configure(moved)
	_check(page._grid_texture.get_instance_id() == image_id and page.grid_rebuild_count == rebuilds, "per-frame marker movement reuses the cached grid texture")
	_check(page.get_child_count() == nodes_before, "per-frame configure never rebuilds controls")
	var changed := _snapshot()
	changed.explored[0] = 1
	page.configure(changed)
	_check(page.grid_rebuild_count == rebuilds + 1, "new exploration rebuilds only the grid image")
	for heading in [0.0, PI * 0.5, PI, PI * 1.5]:
		changed.heading_radians = heading
		page.configure(changed)
		var expected: Vector2 = [Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT][int(round(heading / (PI * 0.5))) % 4]
		_check(page._marker_direction().is_equal_approx(expected), "heading %.2f respects north-up XZ mapping" % heading)
	changed.active = false
	page.configure(changed)
	_check(not page._show_marker and page._location_label.text == "此区域尚无定位", "outside the mapped floor shows no invented player location")
	_check(page._grid_texture != null, "leaving the floor preserves the explored grid")
	page.configure(changed, "en")
	_check(page._location_label.text == "Location unavailable here", "map status localizes without rebuilding the page")
	var cracks := dock.find_child("PhoneScreenCracks", true, false) as Control
	_check(cracks != null and cracks.z_index > page.z_index and cracks.mouse_filter == Control.MOUSE_FILTER_IGNORE, "phone glass remains above the map without intercepting input")
	for viewport in [Vector2(1600, 900), Vector2(640, 720), Vector2(320, 240), Vector2(80, 60), Vector2(32, 32)]:
		dock.configure(true, true, {"social": true, "notebook": true, "map": true}, viewport)
		await create_timer(0.6).timeout
		var screen: Rect2 = dock.screen.get_global_rect()
		_check(_inside(page.get_global_rect(), screen), "map page stays inside phone at %s" % viewport)
		_check(_inside(page._map_global_rect(), screen), "whole map grid fits phone at %s" % viewport)
		for child in page.get_children():
			if child is Control:
				_check(_inside(child.get_global_rect(), screen), "map label %s fits phone at %s" % [child.name, viewport])
		_check(_inside(dock.app_buttons.map.get_global_rect(), screen), "map icon fits phone at %s" % viewport)
	page.configure({"columns": 0, "rows": 0, "active": true})
	_check(page._grid_texture == null and not page._show_marker, "empty snapshots are safe before grid availability")
	host.free()
	await _frames()
	_finish()

func _snapshot() -> Dictionary:
	return {"columns": 4, "rows": 4, "explored": PackedByteArray([0,0,0,0, 0,1,1,0, 0,1,0,0, 0,0,0,0]), "walkable": PackedByteArray([0,0,0,0, 0,1,0,0, 0,1,1,0, 0,0,0,0]), "player_uv": Vector2(0.375, 0.375), "heading_radians": 0.0, "active": true, "explored_ratio": 0.1875}

func _frames() -> void:
	for frame in 4:
		await process_frame

func _inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func _finish() -> void:
	for failure in failures:
		push_error(failure)
	if failures.is_empty():
		print("phone map page tests passed (%d checks)" % checks)
	quit(0 if failures.is_empty() else 1)
