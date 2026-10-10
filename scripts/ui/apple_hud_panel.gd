class_name AppleHudPanel
extends Node
## Left HUD rail. While shown, it watches money and remaining actions and paints those numbers itself.

signal settings_pressed

const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

var _rail: PanelContainer
var _reveal_zone: Control
var _actions_label: Label
var _tooltip: PanelContainer
var _tooltip_label: Label

var _panel_factory: Callable
var _label_factory: Callable
var _theme_color_fn: Callable
var _style_fn: Callable
var _load_texture_fn: Callable
var _on_tooltip_hidden: Callable

var _rail_width := 158.0
var _rail_max_height := 700.0
var _drawer_edge_hit_width := 44.0
var _drawer_edge_cue_width := 5.0
var _drawer_open_duration := 0.26
var _drawer_close_duration := 0.18
var _pollution_icon_path := ""
var _money_icon_path := ""
var _settings_icon_path := ""

var _tooltip_texts: Dictionary = {}
var _tooltip_kind := ""
var _max_actions_fn: Callable
var _shown := false
var _observing := false


static func action_label(actions: int, max_actions: int) -> String:
	var total := maxi(1, max_actions)
	var pips := ""
	for index in total:
		if index > 0:
			pips += " "
		pips += "●" if index < actions else "○"
	return "今日行动\n%s" % pips


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _panel_factory.is_valid() or not _label_factory.is_valid():
		return
	var keep_shown := _shown
	_stop_observing()
	if _rail != null and is_instance_valid(_rail):
		_rail.queue_free()
	if _reveal_zone != null and is_instance_valid(_reveal_zone):
		_reveal_zone.queue_free()
	if _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.queue_free()
	_build_rail(parent)
	_build_reveal_zone(parent)
	_build_tooltip(parent)
	if keep_shown:
		set_shown(true)


func set_shown(shown: bool) -> void:
	_shown = shown
	if _rail != null and is_instance_valid(_rail):
		_rail.visible = shown
	if _reveal_zone != null and is_instance_valid(_reveal_zone):
		_reveal_zone.visible = shown
	if not shown and _tooltip != null and is_instance_valid(_tooltip):
		_tooltip.visible = false
	if shown:
		_start_observing()
	else:
		_stop_observing()


func _exit_tree() -> void:
	_stop_observing()


func get_rail() -> PanelContainer:
	return _rail


func get_reveal_zone() -> Control:
	return _reveal_zone


func get_tooltip() -> PanelContainer:
	return _tooltip


func get_actions_label() -> Label:
	return _actions_label


func render(state: Dictionary) -> void:
	if _rail == null or not is_instance_valid(_rail):
		return
	var tooltips := state.get("tooltips", {}) as Dictionary
	if tooltips.has("pollution"):
		_tooltip_texts["pollution"] = str(tooltips["pollution"])
	elif state.has("pollution"):
		_tooltip_texts["pollution"] = "污染 %d%%" % int(state.get("pollution", 0))
	if tooltips.has("settings"):
		_tooltip_texts["settings"] = str(tooltips["settings"])
	elif not _tooltip_texts.has("settings"):
		_tooltip_texts["settings"] = "设置"


func hide_tooltip() -> void:
	_hide_tooltip()


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_style_fn = deps.get("style_factory", Callable())
	_load_texture_fn = deps.get("load_texture", Callable())
	_on_tooltip_hidden = deps.get("on_tooltip_hidden", Callable())
	_rail_width = float(deps.get("rail_width", _rail_width))
	_rail_max_height = float(deps.get("rail_max_height", _rail_max_height))
	_drawer_edge_hit_width = float(deps.get("drawer_edge_hit_width", _drawer_edge_hit_width))
	_drawer_edge_cue_width = float(deps.get("drawer_edge_cue_width", _drawer_edge_cue_width))
	_drawer_open_duration = float(deps.get("drawer_open_duration", _drawer_open_duration))
	_drawer_close_duration = float(deps.get("drawer_close_duration", _drawer_close_duration))
	_pollution_icon_path = str(deps.get("pollution_icon_path", _pollution_icon_path))
	_money_icon_path = str(deps.get("money_icon_path", _money_icon_path))
	_settings_icon_path = str(deps.get("settings_icon_path", _settings_icon_path))
	_max_actions_fn = deps.get("max_actions", Callable())


func _build_rail(parent: Control) -> void:
	_rail = _panel_factory.call() as PanelContainer
	_rail.name = "InternationalHUDRail"
	_rail.set_meta("dark_rail", true)
	_rail.set_meta("drawer_state", "collapsed")
	_rail.set_meta("slide_direction", "left_to_right")
	_rail.set_meta("open_duration", _drawer_open_duration)
	_rail.set_meta("close_duration", _drawer_close_duration)
	_rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_rail.offset_left = 0.0
	_rail.offset_top = 0.0
	_rail.offset_right = _rail_width
	_rail.offset_bottom = _rail_max_height
	_rail.z_index = 40
	_rail.clip_contents = true
	_rail.mouse_filter = Control.MOUSE_FILTER_STOP
	_rail.add_theme_stylebox_override(
		"panel",
		_style_fn.call(_theme_color_fn.call("ink"), Color(_theme_color_fn.call("muted"), 0.22))
	)
	parent.add_child(_rail)
	_rail.tree_exiting.connect(_stop_if_current_rail_exits.bind(_rail))

	var center := CenterContainer.new()
	center.name = "InternationalHUDCenter"
	_rail.add_child(center)

	var box := VBoxContainer.new()
	box.name = "InternationalHUDStack"
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_add_hud_icon(box, "HUDPollutionIcon", "pollution", _pollution_icon_path)
	_add_hud_icon(box, "HUDMoneyIcon", "money", _money_icon_path)

	var action_divider := ColorRect.new()
	action_divider.color = _theme_color_fn.call("muted")
	action_divider.modulate.a = 0.42
	action_divider.custom_minimum_size.y = 1
	box.add_child(action_divider)

	var action_spacer := Control.new()
	action_spacer.custom_minimum_size.y = 6
	box.add_child(action_spacer)

	_actions_label = _label_factory.call("", 18, _theme_color_fn.call("muted")) as Label
	_actions_label.name = "HUDActionsLabel"
	_actions_label.set_meta("action_animation_mode", "inline_pulse")
	_actions_label.set_meta("hud_action_label", true)
	_actions_label.custom_minimum_size = Vector2(118, 64)
	_actions_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_actions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_actions_label)

	var settings_spacer := Control.new()
	settings_spacer.custom_minimum_size.y = 10
	box.add_child(settings_spacer)
	var settings_icon := _add_hud_icon(box, "HUDSettingsIcon", "settings", _settings_icon_path)
	settings_icon.pressed.connect(_on_settings_pressed)


func _build_reveal_zone(parent: Control) -> void:
	_reveal_zone = Control.new()
	_reveal_zone.name = "HUDRevealZone"
	_reveal_zone.set_meta("hover_reveals", true)
	_reveal_zone.set_meta("touch_reveals", true)
	_reveal_zone.set_meta("touch_target_width", _drawer_edge_hit_width)
	_reveal_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_reveal_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_reveal_zone.tooltip_text = "打开状态栏"
	_reveal_zone.z_index = 39
	parent.add_child(_reveal_zone)

	var reveal_indicator := ColorRect.new()
	reveal_indicator.name = "HUDRevealIndicator"
	reveal_indicator.color = _theme_color_fn.call("muted")
	reveal_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reveal_indicator.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	reveal_indicator.offset_left = 0.0
	reveal_indicator.offset_top = -46.0
	reveal_indicator.offset_right = _drawer_edge_cue_width
	reveal_indicator.offset_bottom = 46.0
	reveal_indicator.set_meta("edge_cue", true)
	_reveal_zone.add_child(reveal_indicator)


func _build_tooltip(parent: Control) -> void:
	_tooltip = _panel_factory.call() as PanelContainer
	_tooltip.name = "HUDTooltip"
	_tooltip.set_meta("tooltip_panel", true)
	_tooltip.visible = false
	_tooltip.z_index = 45
	_tooltip.add_theme_stylebox_override(
		"panel",
		_style_fn.call(_theme_color_fn.call("muted"), _theme_color_fn.call("accent"))
	)
	parent.add_child(_tooltip)
	_tooltip_label = _label_factory.call("", 19, _theme_color_fn.call("ink")) as Label
	_tooltip_label.name = "HUDTooltipLabel"
	_tooltip.add_child(_tooltip_label)


func _add_hud_icon(parent: VBoxContainer, node_name: String, kind: String, texture_path: String) -> Button:
	var icon := Button.new()
	icon.name = node_name
	icon.set_meta("hud_icon", true)
	icon.text = ""
	if _load_texture_fn.is_valid() and not texture_path.is_empty():
		icon.icon = _load_texture_fn.call(texture_path) as Texture2D
	icon.custom_minimum_size = Vector2(60, 60)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.focus_mode = Control.FOCUS_ALL
	icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon.pressed.connect(_show_tooltip.bind(kind, icon))
	icon.mouse_entered.connect(_show_tooltip.bind(kind, icon))
	icon.mouse_exited.connect(_hide_tooltip)
	parent.add_child(icon)
	return icon


func _show_tooltip(kind: String, source: Control) -> void:
	if _tooltip == null or _tooltip_label == null or source == null:
		return
	_tooltip_kind = kind
	_tooltip_label.text = str(_tooltip_texts.get(kind, ""))
	_tooltip.position = source.global_position + Vector2(118, 18)
	_tooltip.visible = true


func _hide_tooltip() -> void:
	if _tooltip != null:
		_tooltip.visible = false
	if _on_tooltip_hidden.is_valid():
		_on_tooltip_hidden.call()


func _on_settings_pressed() -> void:
	settings_pressed.emit()


func _start_observing() -> void:
	if _observing:
		return
	var money := _property_model(PropertyKeysScript.MONEY)
	var actions := _property_model(PropertyKeysScript.ACTIONS_REMAINING)
	if money == null or actions == null:
		return
	money.register(_on_money)
	actions.register(_on_actions)
	_observing = true


func _stop_observing() -> void:
	if not _observing:
		return
	_observing = false
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	var money := _property_model(PropertyKeysScript.MONEY)
	var actions := _property_model(PropertyKeysScript.ACTIONS_REMAINING)
	if money != null:
		money.unregister(_on_money)
	if actions != null:
		actions.unregister(_on_actions)


func _stop_if_current_rail_exits(rail: Node) -> void:
	if rail != _rail:
		return
	_stop_observing()


func _on_money(value: Variant) -> void:
	var text := "资金 %d" % int(value)
	_tooltip_texts["money"] = text
	if _tooltip_label == null:
		return
	if _tooltip_kind == "money" or _tooltip == null or not _tooltip.visible:
		_tooltip_label.text = text


func _on_actions(value: Variant) -> void:
	if _actions_label == null or not is_instance_valid(_actions_label):
		return
	_actions_label.text = action_label(int(value), _max_actions())


func _max_actions() -> int:
	if _max_actions_fn.is_valid():
		return int(_max_actions_fn.call())
	return PropertyBootScript.DEFAULT_MAX_ACTIONS


func _property_model(property_name: String) -> PropertyModel:
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		push_error("Status column cannot see the property service")
		return null
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)
