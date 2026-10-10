class_name BabelAppPanel
extends Node
## Game-side babel tower app body: floor heading, danger/hint cards, money/pollution, event log.
## While shown, it watches the floor, money, and pollution and repaints itself when one changes.

const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")

var _label_factory: Callable
var _theme_color_fn: Callable
var _clear_fn: Callable
var _event_log_fn: Callable
var _level_display_name_fn: Callable
var _app_body: VBoxContainer
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.TOWER_FLOOR: _repaint_on_change,
	PropertyKeysScript.MONEY: _repaint_on_change,
	PropertyKeysScript.POLLUTION: _repaint_on_change,
})


func configure(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_clear_fn = deps.get("clear_children", Callable())
	_event_log_fn = deps.get("event_log", Callable())
	_level_display_name_fn = deps.get("level_display_name", Callable())


## The phone decides whether the babel window shows. While it shows, the models decide what it holds.
func set_shown(shown: bool) -> void:
	if not shown:
		_watch.stop()
	elif not _watch.is_active() and _watch.start():
		_paint()


func render(app_body: VBoxContainer) -> void:
	_app_body = app_body
	_paint()


func _repaint_on_change(_value: Variant) -> void:
	if _watch.is_syncing():
		return
	_paint()


func _paint() -> void:
	var app_body := _app_body
	if app_body == null or not is_instance_valid(app_body) or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	_clear_fn.call(app_body)

	var displayed_floor := _read_int(PropertyKeysScript.TOWER_FLOOR, 1)
	var floor_heading := str(_level_display_name_fn.call(displayed_floor)) if _level_display_name_fn.is_valid() else ""
	var heading := _label_factory.call(floor_heading, 24, _theme_color_fn.call("ink")) as Label
	heading.name = "BabelFloorHeading"
	app_body.add_child(heading)

	var floor_card: Dictionary = LanguageCorruptionContentScript.get_floor_card_display(displayed_floor)
	var floor_field_names := {"危险": "Danger", "提示": "Hint"}
	for field_name in ["危险", "提示"]:
		var card_line := _label_factory.call(
			"%s：%s" % [field_name, str(floor_card.get(field_name, ""))],
			16,
			_theme_color_fn.call("ink")
		) as Label
		card_line.name = "BabelFloor%sLabel" % floor_field_names[field_name]
		card_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		app_body.add_child(card_line)

	var money := _read_int(PropertyKeysScript.MONEY, 0)
	app_body.add_child(_label_factory.call(
		"资金 %d  /  通过发布完整表达获得" % money,
		16,
		_theme_color_fn.call("accent")
	))

	var pollution := _read_int(PropertyKeysScript.POLLUTION, 0)
	app_body.add_child(_label_factory.call(
		"污染 %d%%  /  发布与现实表达会推进污染" % pollution,
		16,
		_theme_color_fn.call("accent")
	))

	var event_log: Array = _event_log_fn.call() if _event_log_fn.is_valid() else []
	for item in event_log:
		app_body.add_child(_label_factory.call(str(item), 15, _theme_color_fn.call("accent")))


func _read_int(property_name: String, fallback: int) -> int:
	var value: Variant = _watch.read(property_name)
	return int(value) if value != null else fallback
