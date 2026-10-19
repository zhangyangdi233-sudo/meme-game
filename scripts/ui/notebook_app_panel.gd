class_name NotebookAppPanel
extends Node
## Game-side notebook app body: sentence header, word canvas, rules list, and the post button.
## While shown, it watches the held words, the sentence and the world rules, and repaints itself.
## Tile positions stay on the canvas; they leave in one batch before a redraw, a hide, or a save.
## Every player action leaves as a UI intent on the event bus.

const WordPhysicsCanvasScript = preload("res://framework/ui/word_physics_canvas.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _clear_fn: Callable
var _current_locale_fn: Callable
var _char_canvas_position_fn: Callable
var _word_canvas: WordPhysicsCanvas
var _app_body: VBoxContainer
var _shown := false
var _paint_queued := false
var _painted_chars: Array = []
var _painted_units: Array = []
var _painted_rules: Dictionary = {}
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.COLLECTED_CHAR_UNITS: _on_model_changed,
	PropertyKeysScript.FREE_SENTENCE_UNITS: _on_model_changed,
	PropertyKeysScript.WORLD_RULES: _on_model_changed,
})


func configure(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_clear_fn = deps.get("clear_children", Callable())
	_current_locale_fn = deps.get("current_locale", Callable())
	_char_canvas_position_fn = deps.get("char_canvas_position", Callable())


## The phone decides whether the notebook window shows. While it shows, the models decide what it holds.
func set_shown(shown: bool) -> void:
	var was_shown := _shown
	_shown = shown
	if shown:
		_watch.start()
	elif was_shown:
		commit_canvas_positions()
		_watch.stop()


func commit_canvas_positions() -> void:
	if _word_canvas == null or not is_instance_valid(_word_canvas):
		return
	var positions: Dictionary = _word_canvas.settled_tile_positions()
	if positions.is_empty():
		return
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CANVAS_POSITIONS_COMMITTED, {UiIntentsScript.KEY_TILE_POSITIONS: positions})


func render(app_body: VBoxContainer) -> void:
	_app_body = app_body
	_paint()


func _paint() -> void:
	var app_body := _app_body
	if app_body == null or not is_instance_valid(app_body) or _theme() == null:
		return
	_painted_chars = _read_list(PropertyKeysScript.COLLECTED_CHAR_UNITS)
	_painted_units = _read_list(PropertyKeysScript.FREE_SENTENCE_UNITS)
	_painted_rules = _read_map(PropertyKeysScript.WORLD_RULES)
	commit_canvas_positions()
	_word_canvas = null
	_clear_fn.call(app_body)

	var notebook_page := VBoxContainer.new()
	notebook_page.name = "NotebookCraftPage"
	notebook_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_page.add_theme_constant_override("separation", 8)
	app_body.add_child(notebook_page)

	_render_sentence_header(notebook_page)

	var notebook_scroll := ScrollContainer.new()
	notebook_scroll.name = "NotebookCraftScroll"
	notebook_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	notebook_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	notebook_page.add_child(notebook_scroll)

	var notebook_content := VBoxContainer.new()
	notebook_content.name = "NotebookCraftContent"
	notebook_content.add_theme_constant_override("separation", 10)
	notebook_scroll.add_child(notebook_content)

	_render_frame_tab(notebook_content)
	_render_action_bar(notebook_page)


func _render_sentence_header(notebook_page: VBoxContainer) -> void:
	var notebook_header := VBoxContainer.new()
	notebook_header.name = "NotebookSentenceHeader"
	notebook_header.add_theme_constant_override("separation", 3)
	notebook_page.add_child(notebook_header)
	notebook_header.add_child(_theme().label("完整句子", 24, _theme().theme_color("ink")))
	var header_hint := _theme().label("从帖子拾取原词，再按语法位置组成手机世界会使用的句子。", 14, _theme().theme_color("accent")) as Label
	header_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_header.add_child(header_hint)
	var tab_rule := ColorRect.new()
	tab_rule.name = "NotebookSentenceRule"
	tab_rule.color = _theme().theme_color("accent")
	tab_rule.custom_minimum_size.y = 3.0
	notebook_page.add_child(tab_rule)


func _render_frame_tab(notebook_content: VBoxContainer) -> void:
	notebook_content.add_child(_theme().label("拾到的字", 18, _theme().theme_color("accent")))
	var canvas_hint := _theme().label("字被拾取后一直留在这里。可以随意拖动摆放,也可以拖进发布页的句子里。", 13, _theme().theme_color("muted")) as Label
	canvas_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(canvas_hint)

	var canvas_frame := _theme().panel() as PanelContainer
	canvas_frame.name = "NotebookCanvasFrame"
	notebook_content.add_child(canvas_frame)
	var canvas := WordPhysicsCanvasScript.new()
	canvas.name = "NotebookWordCanvas"
	canvas.custom_minimum_size = MemeGameStateScript.CHAR_CANVAS_SIZE
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_child(canvas)
	_word_canvas = canvas
	canvas.tile_dropped_outside.connect(_on_canvas_tile_dropped_outside)
	canvas.tile_tapped.connect(_on_composer_bank_tapped)

	var locale_code: String = _current_locale_fn.call() if _current_locale_fn.is_valid() else "zh"
	var collected_units: Array[String] = MemeGameStateScript.char_units_for_locale(_painted_chars, locale_code)
	var placed_units := _painted_units
	if collected_units.is_empty():
		var empty_hint := _theme().label("还没有拾到字。帖子里发亮的字可以点。", 13, _theme().theme_color("muted")) as Label
		empty_hint.name = "NotebookCharEmptyHint"
		empty_hint.position = Vector2(10.0, 10.0)
		canvas.add_child(empty_hint)
	for unit in collected_units:
		var is_ghost := str(unit) in placed_units
		var tile_style: StyleBox = _theme().composer_tile_style("ghost" if is_ghost else "normal") if _theme() != null else null
		var tile_position: Vector2 = _char_canvas_position_fn.call(str(unit), locale_code) if _char_canvas_position_fn.is_valid() else Vector2.ZERO
		canvas.add_tile(
			str(unit),
			tile_position,
			_theme().theme_color("ink"),
			tile_style,
			is_ghost
		)

	var active_rules: Array = MemeGameStateScript.world_rule_list(_painted_rules)
	if not active_rules.is_empty():
		notebook_content.add_child(_theme().label("现行规则", 18, _theme().theme_color("accent")))
		var rules_box := VBoxContainer.new()
		rules_box.name = "ComposerRulesList"
		rules_box.add_theme_constant_override("separation", 3)
		notebook_content.add_child(rules_box)
		for rule in active_rules:
			var rule_text := RuleEngineScript.rule_display_text(str(rule.get("key", "")), bool(rule.get("negated", false)), locale_code)
			var rule_label := _theme().label("· %s" % rule_text, 14, _theme().theme_color("accent")) as Label
			rule_label.set_meta("skip_localization", true)
			rules_box.add_child(rule_label)


func _render_action_bar(notebook_page: VBoxContainer) -> void:
	var action_bar := _theme().panel() as PanelContainer
	action_bar.name = "NotebookCraftActionBar"
	action_bar.set_meta("fixed_action_bar", true)
	notebook_page.add_child(action_bar)
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_bar.add_child(action_box)
	var craft := Button.new()
	craft.name = "NotebookCraftButton"
	craft.text = "投稿这句话"
	craft.custom_minimum_size.y = 56
	craft.disabled = _painted_units.is_empty()
	craft.pressed.connect(_on_craft_pressed)
	action_box.add_child(craft)


func _on_model_changed(_value: Variant) -> void:
	if _is_stale():
		_request_paint()


## A value the page already shows needs no repaint.
func _is_stale() -> bool:
	if _read_list(PropertyKeysScript.COLLECTED_CHAR_UNITS) != _painted_chars:
		return true
	return _read_list(PropertyKeysScript.FREE_SENTENCE_UNITS) != _painted_units \
		or _read_map(PropertyKeysScript.WORLD_RULES) != _painted_rules


## Showing syncs at once. A later change repaints at the end of the frame, so a host redraw
## in the same frame already covers it and the falling tiles are not rebuilt twice.
func _request_paint() -> void:
	if _watch.is_syncing():
		_paint()
		return
	if _paint_queued:
		return
	_paint_queued = true
	_flush_paint.call_deferred()


func _flush_paint() -> void:
	_paint_queued = false
	if not _watch.is_active():
		return
	if _is_stale():
		_paint()


func _read_list(property_name: String) -> Array:
	var value: Variant = _watch.read(property_name)
	return value as Array if value is Array else []


func _read_map(property_name: String) -> Dictionary:
	var value: Variant = _watch.read(property_name)
	return value as Dictionary if value is Dictionary else {}


func _on_craft_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED)


func _on_canvas_tile_dropped_outside(unit: String, release_global: Vector2) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CANVAS_TILE_DROPPED_OUTSIDE, {UiIntentsScript.KEY_UNIT: unit, UiIntentsScript.KEY_RELEASE_GLOBAL: release_global})


func _on_composer_bank_tapped(unit: String) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: unit})


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
