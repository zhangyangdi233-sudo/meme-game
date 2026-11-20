extends SceneTree
## The docked phone (the old version's phone): one phone at the right edge with a narrow tab, watching whether it is up,
## which app is in front, which apps are unlocked and the pollution; its apps show inside its screen one at a time, and
## its tab, icons, home bar and the notebook's close raise intents.

const BootScript = preload("res://scripts/game/property_boot.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PhoneDockPanelScript = preload("res://scripts/ui/phone_dock_panel.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const RegistryScript = preload("res://framework/service_registry.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

const VIEW := Vector2(1600, 900)

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_showing_registers_once_and_hiding_lets_go()
	await _test_the_home_offers_social_notebook_and_a_locked_map()
	await _test_controls_raise_their_intents()
	await _test_the_phone_slides_in_and_out_from_the_right_edge()
	await _test_apps_show_inside_the_screen_one_at_a_time()
	await _test_small_windows_keep_the_phone_and_tab_inside()
	await _test_a_freed_panel_unregisters()
	if _failures.is_empty():
		print("phone dock panel tests passed")
		RegistryScript.clear()
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		RegistryScript.clear()
		quit(1)


func _test_showing_registers_once_and_hiding_lets_go() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	var view: ValuePropertyModel = mounted["view"]
	var front: ValuePropertyModel = mounted["front"]
	_assert_eq(_listener_count(view), 0, "a mounted phone should not listen before it is shown")
	_assert_true(not panel.get_body().visible and not panel.get_tab().visible, "a phone the chrome has not shown has no body and no tab")
	view.write("phone_down")
	_assert_true(not panel.get_body().visible, "a model write should not show a phone the chrome has not shown")
	panel.set_shown(true)
	panel.set_shown(true)
	_assert_eq(_listener_count(view), 1, "showing should register once on whether the phone is up")
	_assert_eq(_listener_count(front), 1, "showing should register once on the app in front")
	_assert_eq(_listener_count(mounted["unlocked"]), 1, "showing should register once on the unlocked apps")
	_assert_eq(_listener_count(mounted["pollution"]), 1, "showing should register once on the pollution")
	_assert_true(panel.get_body().visible and panel.get_tab().visible, "a shown phone has its body and its edge tab")
	panel.set_shown(false)
	_assert_eq(_listener_count(view), 0, "hiding should let go of the models")
	_assert_true(not panel.get_body().visible and not panel.get_tab().visible, "hiding should hide the body and the tab")
	await _dispose(mounted)


## The old phone's home: the feed and the notebook side by side, the map below them, always locked in the demo; none of
## the first launcher's words.
func _test_the_home_offers_social_notebook_and_a_locked_map() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	var host := mounted["host"] as Control
	var icons: Array[String] = []
	for node in panel.get_launcher().find_children("PhoneAppIcon*", "Button", true, false):
		icons.append(str(node.name))
	_assert_eq(icons, ["PhoneAppIconSocial", "PhoneAppIconNotebook", "PhoneAppIconMap"], "the home should offer the feed, the notebook and the map")
	_assert_eq(panel.get_app_icon("social").text, "瀑布流", "the feed's icon keeps the old phone's label")
	_assert_eq(panel.get_app_icon("notebook").text, "笔记本", "the notebook's icon keeps the old phone's label")
	_assert_eq(panel.get_app_icon("map").text, "地图", "the map's icon keeps the old phone's label")
	for app_id in ["social", "notebook", "map"]:
		_assert_true(panel.get_app_icon(app_id).icon != null, "the %s icon should show the old phone's picture" % app_id)
	(mounted["unlocked"] as ListPropertyModel).replace_all(["social", "notebook"])
	panel.set_shown(true)
	_assert_true(not panel.get_app_icon("social").disabled and not panel.get_app_icon("notebook").disabled, "picking the phone up gives the feed and the notebook")
	_assert_true(panel.get_app_icon("map").visible and panel.get_app_icon("map").disabled, "the map shows on the home but stays locked")
	for node in host.find_children("*", "", true, false):
		var text := ""
		if node is Label:
			text = (node as Label).text
		elif node is Button:
			text = (node as Button).text
		for retired in ["BABEL", "APP LAUNCHER", "选择一个窗口", "语言工坊", "每个 App"]:
			_assert_true(not text.contains(retired), "the phone should not show the first launcher's \"%s\" (%s)" % [retired, node.name])
	_assert_true(host.find_child("PhoneLauncherWallpaper", true, false) == null, "the phone has no launcher wallpaper")
	await _dispose(mounted)


func _test_controls_raise_their_intents() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	var heard: Array = []
	var bus := GameEventBusScript.new()
	RegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, bus)
	bus.intent_emitted.connect(func(intent: String, payload: Dictionary) -> void: heard.append([intent, payload]))
	panel.set_shown(true)
	for app_id in ["social", "notebook", "map"]:
		panel.get_app_icon(app_id).pressed.emit()
	_assert_eq(heard, [], "a locked icon should raise nothing")
	(mounted["unlocked"] as ListPropertyModel).replace_all(["social", "notebook"])
	panel.get_app_icon("social").pressed.emit()
	panel.get_app_icon("map").pressed.emit()
	panel.get_tab().pressed.emit()
	panel.get_home_button().pressed.emit()
	(panel.get_app_window("notebook").find_child("NotebookAppWindowCloseButton", true, false) as Button).pressed.emit()
	_assert_eq(heard, [
		[UiIntentsScript.APP_ICON_PRESSED, {UiIntentsScript.KEY_APP_ID: "social"}],
		[UiIntentsScript.PHONE_TOGGLE_REQUESTED, {}],
		[UiIntentsScript.PHONE_HOME_REQUESTED, {}],
		[UiIntentsScript.APP_WINDOW_CLOSE_REQUESTED, {UiIntentsScript.KEY_APP_ID: "notebook"}],
	], "the icons, the edge tab, the home bar and the notebook's close raise their intents; the locked map raises nothing")
	await _dispose(mounted)


## The old motion: the phone eases in from past the right edge and back out, and the tab stays at the edge.
func _test_the_phone_slides_in_and_out_from_the_right_edge() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	var view: ValuePropertyModel = mounted["view"]
	view.write("npc_up")
	panel.set_shown(true)
	var body := panel.get_body() as Control
	var tab := panel.get_tab() as Control
	var away_x := body.position.x
	_assert_true(away_x >= VIEW.x, "a phone that is away rests past the right edge")
	_assert_true(is_equal_approx(tab.get_global_rect().end.x, VIEW.x), "the tab sticks out of the right edge")
	_assert_true(tab.size.x <= 24.0 and tab.size.y <= 86.0, "the tab is the old narrow handle")
	view.write("phone_down")
	_assert_true(is_equal_approx(body.position.x, away_x), "opening starts where the phone was, without a jump")
	await create_timer(0.2).timeout
	var midway := body.position.x
	_assert_true(midway < away_x and midway > VIEW.x - body.size.x * body.scale.x - 24.0, "an opening phone passes through an eased middle")
	await create_timer(0.45).timeout
	var up_x := body.position.x
	_assert_true(up_x < midway, "an opening phone finishes its travel")
	_assert_true(body.get_global_rect().end.x <= tab.get_global_rect().position.x + 0.5, "the open phone rests just left of the tab")
	_assert_true(is_equal_approx(panel.slide_fraction(), 1.0) and panel.is_open(), "an open phone has slid all the way in")
	view.write("npc_up")
	await create_timer(0.2).timeout
	_assert_true(body.position.x > up_x and body.position.x < away_x, "closing also eases through the middle")
	await create_timer(0.45).timeout
	_assert_true(body.position.x >= away_x - 0.5 and tab.visible, "a closed phone leaves only its tab")
	await _dispose(mounted)


func _test_apps_show_inside_the_screen_one_at_a_time() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	var view: ValuePropertyModel = mounted["view"]
	var front: ValuePropertyModel = mounted["front"]
	var social := PanelContainer.new()
	social.name = "SocialAppWindow"
	social.set_meta("phone_shell", true)
	panel.get_screen().add_child(social)
	panel.add_page("social", social)
	var notebook := panel.get_app_window("notebook")
	_assert_true(notebook != null and notebook.get_parent() == panel.get_screen(), "the notebook is a page on the phone's screen")
	_assert_true(not social.has_meta("phone_shell"), "a page inside the phone gets no second phone frame")
	_assert_true(panel.get_screen().clip_contents, "the screen clips its pages")
	front.write("social")
	view.write("phone_down")
	panel.set_shown(true)
	await process_frame
	_assert_true(social.visible and not notebook.visible and not panel.get_launcher().visible, "the app in front replaces the home")
	_assert_eq(social.get_global_rect(), panel.get_screen().get_global_rect(), "a page fills the phone's screen")
	front.write("notebook")
	_assert_true(notebook.visible and not social.visible, "one app shows at a time")
	_assert_true(panel.get_body().get_global_rect().has_point(panel.home_point()), "a picked word lands on the phone's own home bar")
	front.write("")
	_assert_true(panel.get_launcher().visible and not notebook.visible and not social.visible, "no app in front shows the home")
	front.write("social")
	view.write("npc_up")
	_assert_true(panel.get_launcher().visible and not social.visible, "a phone that goes away shows its home again")
	await _dispose(mounted)


func _test_small_windows_keep_the_phone_and_tab_inside() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	(mounted["view"] as ValuePropertyModel).write("phone_down")
	panel.set_shown(true)
	for viewport in [Vector2(1280, 720), Vector2(320, 240), Vector2(80, 60)]:
		panel.relayout(viewport)
		await create_timer(0.6).timeout
		var bounds := Rect2(Vector2.ZERO, viewport)
		var body := panel.get_body() as Control
		_assert_true(body.scale.x > 0.0, "%s keeps a phone of some size" % viewport)
		_assert_true(_inside(body.get_global_rect(), bounds), "%s contains the open phone" % viewport)
		_assert_true(_inside((panel.get_tab() as Control).get_global_rect(), bounds), "%s contains the whole tab" % viewport)
	await _dispose(mounted)


func _test_a_freed_panel_unregisters() -> void:
	var mounted := _mount()
	var panel: PhoneDockPanelScript = mounted["panel"]
	panel.set_shown(true)
	panel.free()
	mounted["panel"] = null
	_assert_eq(_listener_count(mounted["view"]), 0, "a freed phone should let go of its models")
	await _dispose(mounted)


func _mount() -> Dictionary:
	RegistryScript.clear()
	BootScript.install()
	RegistryScript.bind(ServiceKeysScript.UI_THEME, GameUiThemeScript.new())
	var manager: PropertyManager = RegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	root.size = Vector2i(VIEW)
	var host := Control.new()
	host.name = "PhoneHost"
	host.size = VIEW
	root.add_child(host)
	var panel = PhoneDockPanelScript.new()
	panel.name = "PhoneDockPanel"
	root.add_child(panel)
	panel.mount(host)
	panel.relayout(VIEW)
	return {
		"host": host,
		"panel": panel,
		"view": manager.model(PropertyKeysScript.VIEW_STATE),
		"front": manager.model(PropertyKeysScript.ACTIVE_APP_WINDOW),
		"unlocked": manager.model(PropertyKeysScript.UNLOCKED_APPS),
		"pollution": manager.model(PropertyKeysScript.POLLUTION),
	}


func _dispose(mounted: Dictionary) -> void:
	var panel: Node = mounted["panel"]
	if panel != null and is_instance_valid(panel):
		panel.free()
	var host: Node = mounted["host"]
	if host != null and is_instance_valid(host):
		host.free()
	await process_frame
	RegistryScript.clear()


func _listener_count(model: PropertyModel) -> int:
	if model == null:
		return -1
	return model.changed.get_connections().size()


func _inside(inner: Rect2, outer: Rect2) -> bool:
	return inner.position.x >= outer.position.x - 0.5 and inner.position.y >= outer.position.y - 0.5 and inner.end.x <= outer.end.x + 0.5 and inner.end.y <= outer.end.y + 0.5


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq(actual, expected, message: String) -> void:
	if actual != expected:
		_failures.append("%s (expected %s, got %s)" % [message, str(expected), str(actual)])
