class_name NotebookAppPanel
extends Node
## Game-side notebook app body, the one place a sentence is composed and posted (#154): the picked-up words on a
## canvas above, the sentence, the rules and the post button below, with a split between them the player can drag.
## A word in the sentence leaves the canvas and comes back to its spot when it leaves the sentence.
## While shown, it watches the held words, the sentence, the world rules and the posts, and repaints itself.
## Tile positions stay on the canvas; they leave in one batch before a redraw, a hide, or a save.
## Every player action leaves as a UI intent on the event bus.

const ComposerAnswerTileScript = preload("res://scripts/ui/composer_answer_tile.gd")
const ComposerDropAreaScript = preload("res://scripts/ui/composer_drop_area.gd")
const WordPhysicsCanvasScript = preload("res://framework/ui/word_physics_canvas.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const PollutionPolicyScript = preload("res://scripts/game/pollution_policy.gd")
const PostSlipScript = preload("res://scripts/ui/post_slip.gd")
const RoomContentScript = preload("res://scripts/game/room_content.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const SentenceWarningScript = preload("res://scripts/ui/sentence_warning.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

## The canvas keeps room for about two rows of words however far the split is dragged.
const WORD_AREA_MIN_HEIGHT := 96.0
const SENTENCE_AREA_MIN_HEIGHT := 120.0
const CANVAS_HINT := "点字放进下方的句子;从句子拿掉的字会回到这里。"

var _clear_fn: Callable
var _current_locale_fn: Callable
var _char_canvas_position_fn: Callable
var _word_canvas: WordPhysicsCanvas
var _answer_panel: Control
var _sentence_scroll: ScrollContainer
var _app_body: VBoxContainer
## Where the player dragged the split; a repaint builds the page again and puts the split back there.
var _split_offset := 0
var _shown := false
var _paint_queued := false
var _painted_chars: Array = []
var _painted_units: Array = []
var _painted_rules: Dictionary = {}
var _painted_polluted: Dictionary = {}
var _painted_post: Dictionary = {}
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.COLLECTED_CHAR_UNITS: _on_model_changed,
	PropertyKeysScript.FREE_SENTENCE_UNITS: _on_model_changed,
	PropertyKeysScript.WORLD_RULES: _on_model_changed,
	PropertyKeysScript.POLLUTED_WORDS: _on_model_changed,
	PropertyKeysScript.PUBLISHED_MEMES: _on_model_changed,
	PropertyKeysScript.CHAPTER_ONE_PROGRESS: _on_model_changed,
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
	var leaving_sentence := _painted_units
	_painted_chars = _read_list(PropertyKeysScript.COLLECTED_CHAR_UNITS)
	_painted_units = _read_list(PropertyKeysScript.FREE_SENTENCE_UNITS)
	_painted_rules = _read_map(PropertyKeysScript.WORLD_RULES)
	_painted_polluted = _read_map(PropertyKeysScript.POLLUTED_WORDS)
	_painted_post = _last_post()
	commit_canvas_positions()
	_word_canvas = null
	_answer_panel = null
	_sentence_scroll = null
	_clear_fn.call(app_body)

	var notebook_page := VBoxContainer.new()
	notebook_page.name = "NotebookCraftPage"
	notebook_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_page.add_theme_constant_override("separation", 8)
	app_body.add_child(notebook_page)

	var split := VSplitContainer.new()
	split.name = "NotebookSplit"
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.dragging_enabled = true
	split.split_offset = _split_offset
	split.dragged.connect(_on_split_dragged)
	notebook_page.add_child(split)

	var polluted_units := SentenceWarningScript.polluted_units(_painted_polluted, _read_map(PropertyKeysScript.CHAPTER_ONE_PROGRESS), _locale())
	_render_word_area(split, polluted_units, leaving_sentence)
	_render_sentence_area(split, polluted_units)


## The upper part: the words picked up and not in the sentence, free to arrange. Words that were in the sentence
## (`leaving_sentence`) go down last, so a word resting in one of their spots keeps it.
func _render_word_area(split: VSplitContainer, polluted_units: Array, leaving_sentence: Array) -> void:
	var word_area := VBoxContainer.new()
	word_area.name = "NotebookWordArea"
	word_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	word_area.add_theme_constant_override("separation", 6)
	split.add_child(word_area)
	word_area.add_child(_theme().label("拾到的字", 18, _theme().theme_color("accent")))
	var canvas_hint := _theme().label(CANVAS_HINT, 13, _theme().theme_color("muted")) as Label
	canvas_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	word_area.add_child(canvas_hint)

	var canvas_frame := _theme().panel() as PanelContainer
	canvas_frame.name = "NotebookCanvasFrame"
	canvas_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	word_area.add_child(canvas_frame)
	var canvas := WordPhysicsCanvasScript.new()
	canvas.name = "NotebookWordCanvas"
	canvas.custom_minimum_size = Vector2(0.0, WORD_AREA_MIN_HEIGHT)
	# Saved spots live in the state's canvas space; the canvas is laid out only after its words are placed.
	canvas.expected_size = MemeGameStateScript.CHAR_CANVAS_SIZE
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_child(canvas)
	_word_canvas = canvas
	canvas.tile_dropped_outside.connect(_on_canvas_tile_dropped_outside)
	canvas.tile_tapped.connect(_on_composer_bank_tapped)

	var locale_code := _locale()
	var collected_units: Array[String] = MemeGameStateScript.char_units_for_locale(_painted_chars, locale_code)
	if collected_units.is_empty():
		var empty_hint := _theme().label("还没有拾到字。帖子里发亮的字可以点。", 13, _theme().theme_color("muted")) as Label
		empty_hint.name = "NotebookCharEmptyHint"
		empty_hint.position = Vector2(10.0, 10.0)
		canvas.add_child(empty_hint)
	var resting: Array[String] = []
	var returning: Array[String] = []
	for unit in collected_units:
		# A word already in the sentence is there, not here; it comes back to its spot when it leaves the sentence.
		if unit in _painted_units:
			continue
		if unit in leaving_sentence:
			returning.append(unit)
		else:
			resting.append(unit)
	for unit in resting + returning:
		var is_polluted := unit in polluted_units
		var tile_position: Vector2 = _char_canvas_position_fn.call(unit, locale_code) if _char_canvas_position_fn.is_valid() else Vector2.ZERO
		canvas.add_tile(
			unit,
			tile_position,
			_theme().theme_color("ink"),
			_theme().composer_tile_style("normal"),
			PollutionPolicyScript.garbled(unit) if is_polluted else ""
		)
		if is_polluted:
			_theme().set_font_role(canvas.tile_label(unit), "error")


## The lower part: the sentence being composed, the rules in force, and the post button with the last post under it.
func _render_sentence_area(split: VSplitContainer, polluted_units: Array) -> void:
	var sentence_area := VBoxContainer.new()
	sentence_area.name = "NotebookSentenceArea"
	sentence_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sentence_area.add_theme_constant_override("separation", 6)
	split.add_child(sentence_area)

	var sentence_scroll := ScrollContainer.new()
	sentence_scroll.name = "NotebookSentenceScroll"
	sentence_scroll.custom_minimum_size.y = SENTENCE_AREA_MIN_HEIGHT
	sentence_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sentence_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sentence_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	sentence_area.add_child(sentence_scroll)
	_sentence_scroll = sentence_scroll
	var sentence_content := VBoxContainer.new()
	sentence_content.name = "NotebookSentenceContent"
	sentence_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sentence_content.add_theme_constant_override("separation", 8)
	sentence_scroll.add_child(sentence_content)

	_render_sentence_header(sentence_content)
	_render_sentence(sentence_content, polluted_units)
	_render_rules(sentence_content, polluted_units)
	_render_action_bar(sentence_area)


func _render_sentence_header(parent: VBoxContainer) -> void:
	var notebook_header := VBoxContainer.new()
	notebook_header.name = "NotebookSentenceHeader"
	notebook_header.add_theme_constant_override("separation", 3)
	parent.add_child(notebook_header)
	notebook_header.add_child(_theme().label("完整句子", 20, _theme().theme_color("ink")))
	var header_hint := _theme().label("从帖子拾取原词，再按语法位置组成手机世界会使用的句子。", 13, _theme().theme_color("accent")) as Label
	header_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_header.add_child(header_hint)


func _render_sentence(parent: VBoxContainer, polluted_units: Array) -> void:
	var placed_units := _painted_units
	var answer_panel := ComposerDropAreaScript.new()
	answer_panel.name = "ComposerAnswerPanel"
	answer_panel.custom_minimum_size.y = 64
	answer_panel.add_theme_stylebox_override("panel", _theme().soft_style(_theme().theme_color("surface"), _theme().theme_color("accent")))
	answer_panel.unit_dropped.connect(_on_sentence_area_dropped)
	parent.add_child(answer_panel)
	_answer_panel = answer_panel
	var answer_box := VBoxContainer.new()
	answer_box.add_theme_constant_override("separation", 4)
	answer_panel.add_child(answer_box)
	var answer_flow := HFlowContainer.new()
	answer_flow.name = "ComposerAnswerFlow"
	answer_flow.add_theme_constant_override("h_separation", 6)
	answer_flow.add_theme_constant_override("v_separation", 6)
	answer_flow.custom_minimum_size.y = 46
	answer_box.add_child(answer_flow)
	if placed_units.is_empty():
		var placeholder := _theme().label("……(句子还空着)", 14, _theme().theme_color("muted")) as Label
		placeholder.name = "ComposerAnswerPlaceholder"
		answer_flow.add_child(placeholder)
	var shown_units := PollutionPolicyScript.shown_units(placed_units, polluted_units)
	for unit_index in placed_units.size():
		var placed_tile := ComposerAnswerTileScript.new()
		placed_tile.name = "ComposerAnswerTile%d" % unit_index
		placed_tile.text = str(shown_units[unit_index])
		placed_tile.focus_mode = Control.FOCUS_NONE
		placed_tile.custom_minimum_size = Vector2(44, 42)
		placed_tile.set_meta("skip_localization", true)
		placed_tile.configure_answer_tile(unit_index, str(shown_units[unit_index]))
		placed_tile.pressed.connect(_on_sentence_tile_tapped.bind(unit_index))
		placed_tile.unit_dropped_before.connect(_on_sentence_tile_dropped)
		_theme().apply_composer_tile_theme(placed_tile, false)
		placed_tile.drag_preview_color = _theme().theme_color("accent")
		if placed_units[unit_index] in polluted_units:
			_theme().set_font_role(placed_tile, "error")
		answer_flow.add_child(placed_tile)
	var answer_rule := ColorRect.new()
	answer_rule.name = "ComposerAnswerUnderline"
	answer_rule.color = Color(_theme().theme_color("accent"), 0.8)
	answer_rule.custom_minimum_size.y = 2.0
	answer_box.add_child(answer_rule)

	var preview_label := _theme().label(MemeGameStateScript.sentence_text(shown_units, _locale()), 15, _theme().theme_color("ink")) as Label
	preview_label.name = "ComposerPreviewLabel"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.set_meta("skip_localization", true)
	if shown_units != placed_units:
		_theme().set_font_role(preview_label, "error")
	parent.add_child(preview_label)


func _render_rules(parent: VBoxContainer, polluted_units: Array) -> void:
	var active_rules: Array = MemeGameStateScript.world_rule_list(_painted_rules)
	if active_rules.is_empty():
		return
	parent.add_child(_theme().label("现行规则", 18, _theme().theme_color("accent")))
	var rules_box := VBoxContainer.new()
	rules_box.name = "ComposerRulesList"
	rules_box.add_theme_constant_override("separation", 3)
	parent.add_child(rules_box)
	var locale_code := _locale()
	for rule in active_rules:
		var rule_label := _theme().label("· %s" % PollutionPolicyScript.shown_text(_rule_text(rule, locale_code), polluted_units), 14, _theme().theme_color("accent")) as Label
		rule_label.set_meta("skip_localization", true)
		rules_box.add_child(rule_label)


## A room's rule reads as its room words it, or as the player wrote it until that language is authored.
func _rule_text(rule: Dictionary, locale_code: String) -> String:
	var rule_key := str(rule.get("key", ""))
	var negated := bool(rule.get("negated", false))
	var round_number := int(rule.get("round", 0))
	if round_number == 0:
		return RuleEngineScript.rule_display_text(rule_key, negated, locale_code)
	var authored := RoomContentScript.rule_text(round_number, rule_key, negated, locale_code)
	return authored if not authored.is_empty() else str(rule.get("source_text", ""))


func _render_action_bar(parent: VBoxContainer) -> void:
	var action_bar := _theme().panel() as PanelContainer
	action_bar.name = "NotebookCraftActionBar"
	action_bar.set_meta("fixed_action_bar", true)
	parent.add_child(action_bar)
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_bar.add_child(action_box)
	var craft := Button.new()
	craft.name = "NotebookCraftButton"
	craft.text = "投稿这句话"
	craft.custom_minimum_size.y = 56
	craft.disabled = _painted_units.is_empty()
	craft.pressed.connect(_on_craft_pressed)
	SentenceWarningScript.add_to(action_box, _painted_units, _painted_polluted, _read_map(PropertyKeysScript.CHAPTER_ONE_PROGRESS), _locale(), _theme())
	action_box.add_child(craft)
	PostSlipScript.add_to(action_box, _painted_post, _theme())


func _on_model_changed(_value: Variant) -> void:
	if _is_stale():
		_request_paint()


## A value the page already shows needs no repaint.
func _is_stale() -> bool:
	if _read_list(PropertyKeysScript.COLLECTED_CHAR_UNITS) != _painted_chars:
		return true
	return _read_list(PropertyKeysScript.FREE_SENTENCE_UNITS) != _painted_units \
		or _read_map(PropertyKeysScript.WORLD_RULES) != _painted_rules \
		or _read_map(PropertyKeysScript.POLLUTED_WORDS) != _painted_polluted \
		or _last_post() != _painted_post


## Showing syncs at once. A later change repaints at the end of the frame, so a host redraw
## in the same frame already covers it and the falling tiles are not rebuilt twice.
func _request_paint() -> void:
	if _watch.is_syncing():
		_repaint()
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
		_repaint()


## A repaint the notebook starts itself carries the theme and the language, as the host's redraw would.
func _repaint() -> void:
	_paint()
	if _app_body == null or not is_instance_valid(_app_body) or _theme() == null:
		return
	_theme().apply_ui_theme(_app_body)
	_theme().localize_control_tree(_app_body)


func _locale() -> String:
	return _current_locale_fn.call() if _current_locale_fn.is_valid() else "zh"


func _last_post() -> Dictionary:
	return PostSlipScript.latest(_read_list(PropertyKeysScript.PUBLISHED_MEMES), _read_map(PropertyKeysScript.CHAPTER_ONE_PROGRESS))


func _read_list(property_name: String) -> Array:
	var value: Variant = _watch.read(property_name)
	return value as Array if value is Array else []


func _read_map(property_name: String) -> Dictionary:
	var value: Variant = _watch.read(property_name)
	return value as Dictionary if value is Dictionary else {}


func _on_craft_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_CRAFT_REQUESTED)


func _on_split_dragged(offset: int) -> void:
	_split_offset = offset


## A tile dragged off the canvas joins the sentence where it lands: before the sentence word under it, or at the end
## anywhere else on the sentence. Dropped anywhere else, it stays on the canvas.
func _on_canvas_tile_dropped_outside(unit: String, release_global: Vector2) -> void:
	if _answer_panel == null or not is_instance_valid(_answer_panel) or not _answer_panel.is_visible_in_tree():
		return
	# Only the part of the sentence the scroll shows takes a word.
	if not _answer_panel.get_global_rect().intersection(_sentence_scroll.get_global_rect()).has_point(release_global):
		return
	var data := {"kind": "composer_unit", "id": unit}
	for tile in _answer_panel.find_children("ComposerAnswerTile*", "ComposerAnswerTile", true, false):
		var answer_tile := tile as ComposerAnswerTile
		if answer_tile.get_global_rect().has_point(release_global):
			_on_sentence_tile_dropped(data, answer_tile.answer_index)
			return
	_on_sentence_area_dropped(data)


func _on_composer_bank_tapped(unit: String) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_COMPOSER_BANK_TAPPED, {UiIntentsScript.KEY_UNIT: unit})


func _on_sentence_area_dropped(data: Dictionary) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_SENTENCE_AREA_DROPPED, {UiIntentsScript.KEY_DATA: data})


func _on_sentence_tile_dropped(data: Dictionary, before_index: int) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_SENTENCE_TILE_DROPPED, {UiIntentsScript.KEY_DATA: data, UiIntentsScript.KEY_BEFORE_INDEX: before_index})


func _on_sentence_tile_tapped(unit_index: int) -> void:
	GameEventBus.raise(UiIntentsScript.NOTEBOOK_SENTENCE_TILE_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: unit_index})


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
