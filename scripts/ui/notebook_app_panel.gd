class_name NotebookAppPanel
extends Node
## Game-side notebook app body: sentence header, word canvas, rules list, and fusion tab.
## While shown, it watches the held words and the finished memes and repaints itself.
## Tile positions stay on the canvas; they leave in one batch before a redraw, a hide, or a save.

signal craft_requested
signal fusion_requested
signal tab_changed(tab_id: String)
signal canvas_positions_committed(tile_positions: Dictionary)
signal canvas_tile_dropped_outside(unit: String, release_global: Vector2)
signal composer_bank_tapped(unit: String)
signal fusion_meme_dropped(data: Dictionary, slot_id: String)
signal fusion_slot_pressed(slot_id: String)

const WordPhysicsCanvasScript = preload("res://framework/ui/word_physics_canvas.gd")
const DropButtonScript = preload("res://framework/ui/drop_button.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")

var _panel_factory: Callable
var _label_factory: Callable
var _theme_color_fn: Callable
var _clear_fn: Callable
var _composer_tile_style_fn: Callable
var _fusion_slot_text_fn: Callable
var _current_locale_fn: Callable
var _free_sentence_units_fn: Callable
var _world_rules_fn: Callable
var _char_canvas_position_fn: Callable
var _can_spend_action_fn: Callable
var _fusion_ready_fn: Callable
var _word_canvas: WordPhysicsCanvas
var _app_body: VBoxContainer
var _active_tab := "frame"
var _shown := false
var _paint_queued := false
var _painted_chars: Array = []
var _painted_memes: Array = []
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.COLLECTED_CHAR_UNITS: _on_held_chars,
	PropertyKeysScript.COMPLETED_MEMES: _on_completed_memes,
})


func configure(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_clear_fn = deps.get("clear_children", Callable())
	_composer_tile_style_fn = deps.get("composer_tile_style", Callable())
	_fusion_slot_text_fn = deps.get("fusion_slot_text", Callable())
	_current_locale_fn = deps.get("current_locale", Callable())
	_free_sentence_units_fn = deps.get("free_sentence_units", Callable())
	_world_rules_fn = deps.get("world_rules", Callable())
	_char_canvas_position_fn = deps.get("char_canvas_position", Callable())
	_can_spend_action_fn = deps.get("can_spend_action", Callable())
	_fusion_ready_fn = deps.get("fusion_ready", Callable())


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
	canvas_positions_committed.emit(positions)


func render(app_body: VBoxContainer, active_tab: String) -> void:
	_app_body = app_body
	_active_tab = active_tab
	_paint()


func _paint() -> void:
	var app_body := _app_body
	if app_body == null or not is_instance_valid(app_body) or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	var active_tab := _active_tab
	_painted_chars = _read_list(PropertyKeysScript.COLLECTED_CHAR_UNITS)
	_painted_memes = _read_list(PropertyKeysScript.COMPLETED_MEMES)
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

	if active_tab == "fusion":
		_render_fusion_tab(notebook_content)
	else:
		_render_frame_tab(notebook_content)

	_render_action_bar(notebook_page, active_tab)


func _render_sentence_header(notebook_page: VBoxContainer) -> void:
	var notebook_header := VBoxContainer.new()
	notebook_header.name = "NotebookSentenceHeader"
	notebook_header.add_theme_constant_override("separation", 3)
	notebook_page.add_child(notebook_header)
	notebook_header.add_child(_label_factory.call("完整句子", 24, _theme_color_fn.call("ink")))
	var header_hint := _label_factory.call("从帖子拾取原词，再按语法位置组成手机世界会使用的句子。", 14, _theme_color_fn.call("accent")) as Label
	header_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_header.add_child(header_hint)
	var tab_rule := ColorRect.new()
	tab_rule.name = "NotebookSentenceRule"
	tab_rule.color = _theme_color_fn.call("accent")
	tab_rule.custom_minimum_size.y = 3.0
	notebook_page.add_child(tab_rule)


func _render_frame_tab(notebook_content: VBoxContainer) -> void:
	notebook_content.add_child(_label_factory.call("拾到的字", 18, _theme_color_fn.call("accent")))
	var canvas_hint := _label_factory.call("字被拾取后一直留在这里。可以随意拖动摆放,也可以拖进发布页的句子里。", 13, _theme_color_fn.call("muted")) as Label
	canvas_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(canvas_hint)

	var canvas_frame := _panel_factory.call() as PanelContainer
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
	var placed_units: Array = _free_sentence_units_fn.call() if _free_sentence_units_fn.is_valid() else []
	if collected_units.is_empty():
		var empty_hint := _label_factory.call("还没有拾到字。帖子里发亮的字可以点。", 13, _theme_color_fn.call("muted")) as Label
		empty_hint.name = "NotebookCharEmptyHint"
		empty_hint.position = Vector2(10.0, 10.0)
		canvas.add_child(empty_hint)
	for unit in collected_units:
		var is_ghost := str(unit) in placed_units
		var tile_style: StyleBox = _composer_tile_style_fn.call("ghost" if is_ghost else "normal") if _composer_tile_style_fn.is_valid() else null
		var tile_position: Vector2 = _char_canvas_position_fn.call(str(unit), locale_code) if _char_canvas_position_fn.is_valid() else Vector2.ZERO
		canvas.add_tile(
			str(unit),
			tile_position,
			_theme_color_fn.call("ink"),
			tile_style,
			is_ghost
		)

	var active_rules: Array = _world_rules_fn.call() if _world_rules_fn.is_valid() else []
	if not active_rules.is_empty():
		notebook_content.add_child(_label_factory.call("现行规则", 18, _theme_color_fn.call("accent")))
		var rules_box := VBoxContainer.new()
		rules_box.name = "ComposerRulesList"
		rules_box.add_theme_constant_override("separation", 3)
		notebook_content.add_child(rules_box)
		for rule in active_rules:
			var rule_text := RuleEngineScript.rule_display_text(str(rule.get("key", "")), bool(rule.get("negated", false)), locale_code)
			var rule_label := _label_factory.call("· %s" % rule_text, 14, _theme_color_fn.call("accent")) as Label
			rule_label.set_meta("skip_localization", true)
			rules_box.add_child(rule_label)


func _render_fusion_tab(notebook_content: VBoxContainer) -> void:
	notebook_content.add_child(_label_factory.call("旧梗融合", 18, _theme_color_fn.call("accent")))
	var fusion_hint := _label_factory.call("将两则不同的完整梗放入左右槽位。", 14, _theme_color_fn.call("accent")) as Label
	fusion_hint.name = "NotebookFusionHint"
	fusion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(fusion_hint)
	var fusion_row := HBoxContainer.new()
	fusion_row.name = "NotebookFusionSlots"
	fusion_row.add_theme_constant_override("separation", 8)
	notebook_content.add_child(fusion_row)
	for fusion_slot_id in ["left", "right"]:
		var fusion_slot = DropButtonScript.new()
		fusion_slot.name = "FusionSlot%s" % fusion_slot_id.capitalize()
		fusion_slot.text = _fusion_slot_text_fn.call(fusion_slot_id) if _fusion_slot_text_fn.is_valid() else fusion_slot_id
		fusion_slot.custom_minimum_size = Vector2(150, 58)
		fusion_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fusion_slot.configure_drop_target("meme", fusion_slot_id)
		fusion_slot.dropped.connect(_on_fusion_meme_dropped)
		fusion_slot.pressed.connect(_on_fusion_slot_pressed.bind(fusion_slot_id))
		fusion_row.add_child(fusion_slot)
	var warning := _label_factory.call("融合会保留两侧文字，并立即增加污染。发布前会显示资金与污染变化。", 14, _theme_color_fn.call("accent")) as Label
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(warning)


func _render_action_bar(notebook_page: VBoxContainer, active_tab: String) -> void:
	var action_bar := _panel_factory.call() as PanelContainer
	action_bar.name = "NotebookCraftActionBar"
	action_bar.set_meta("fixed_action_bar", true)
	notebook_page.add_child(action_bar)
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_bar.add_child(action_box)
	if active_tab == "fusion":
		var fuse := Button.new()
		fuse.name = "NotebookFusionButton"
		fuse.text = "确认融合"
		fuse.custom_minimum_size.y = 56
		var fusion_ready: bool = bool(_fusion_ready_fn.call()) if _fusion_ready_fn.is_valid() else false
		var can_spend: bool = bool(_can_spend_action_fn.call()) if _can_spend_action_fn.is_valid() else false
		fuse.disabled = not can_spend or not fusion_ready
		fuse.pressed.connect(_on_fusion_pressed)
		action_box.add_child(fuse)
	else:
		var craft := Button.new()
		craft.name = "NotebookCraftButton"
		craft.text = "投稿这句话"
		craft.custom_minimum_size.y = 56
		var placed_units: Array = _free_sentence_units_fn.call() if _free_sentence_units_fn.is_valid() else []
		var can_spend: bool = bool(_can_spend_action_fn.call()) if _can_spend_action_fn.is_valid() else false
		craft.disabled = placed_units.is_empty() or not can_spend
		craft.pressed.connect(_on_craft_pressed)
		action_box.add_child(craft)


## A list the page already shows needs no repaint.
func _on_held_chars(value: Variant) -> void:
	if value != _painted_chars:
		_request_paint()


## Only the fusion tab shows finished memes, so the word canvas is not thrown away for them.
func _on_completed_memes(value: Variant) -> void:
	if value != _painted_memes and _active_tab == "fusion":
		_request_paint()


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
	var chars_stale := _read_list(PropertyKeysScript.COLLECTED_CHAR_UNITS) != _painted_chars
	var memes_stale := _active_tab == "fusion" and _read_list(PropertyKeysScript.COMPLETED_MEMES) != _painted_memes
	if chars_stale or memes_stale:
		_paint()


func _read_list(property_name: String) -> Array:
	var value: Variant = _watch.read(property_name)
	return value as Array if value is Array else []


func _on_craft_pressed() -> void:
	craft_requested.emit()


func _on_fusion_pressed() -> void:
	fusion_requested.emit()


func _on_canvas_tile_dropped_outside(unit: String, release_global: Vector2) -> void:
	canvas_tile_dropped_outside.emit(unit, release_global)


func _on_composer_bank_tapped(unit: String) -> void:
	composer_bank_tapped.emit(unit)


func _on_fusion_meme_dropped(data: Dictionary, slot_id: String) -> void:
	fusion_meme_dropped.emit(data, slot_id)


func _on_fusion_slot_pressed(slot_id: String) -> void:
	fusion_slot_pressed.emit(slot_id)
