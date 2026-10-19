class_name SocialPublishPanel
extends Node
## Game-side publish page of the social app: the sentence composer and its post button. Posting is never limited.
## The social panel hands it the page host to paint into; while shown it watches the sentence being composed and
## repaints its own page.
## What it paints comes from the SocialFeedSource bound in the service registry.
## Every player action is raised on the event bus (ADR 0007).

const ComposerAnswerTileScript = preload("res://scripts/ui/composer_answer_tile.gd")
const ComposerDropAreaScript = preload("res://scripts/ui/composer_drop_area.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

var _host: Control
var _page: Control
var _painted_sentence_units: Array = []
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.FREE_SENTENCE_UNITS: _on_model_changed,
})


## Paints the publish page into `host`; later model writes repaint it there until it is released.
func render(host: Control) -> void:
	_host = host
	_paint()


## The social panel is about to clear the page host; this page no longer repaints itself.
func release() -> void:
	_host = null
	_page = null


## Watches the models while the social app shows and lets go when it hides.
func set_shown(shown: bool) -> void:
	if shown:
		# Registering delivers each value once; one repaint after all of them covers a value that changed while hidden.
		if not _watch.is_active() and _watch.start():
			_repaint_if_stale()
	else:
		_watch.stop()


func _paint() -> void:
	if _host == null:
		return
	if _page != null and is_instance_valid(_page):
		_host.remove_child(_page)
		_page.queue_free()
	_painted_sentence_units = _sentence_units()
	_render_publish_page(_host)


func _render_publish_page(parent: Control) -> void:
	var publish_page := VBoxContainer.new()
	publish_page.name = "SocialPublishPage"
	publish_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	publish_page.add_theme_constant_override("separation", 6)
	parent.add_child(publish_page)
	_page = publish_page

	var page_header := HBoxContainer.new()
	page_header.name = "SocialPublishHeader"
	page_header.custom_minimum_size.y = 44
	page_header.add_theme_constant_override("separation", 8)
	publish_page.add_child(page_header)
	var page_title := _theme().label("发布新信号", 22, _theme().theme_color("ink")) as Label
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_header.add_child(page_title)
	var game_day := _source().game_day()
	page_header.add_child(_theme().label("DAY %02d" % game_day, 12, _theme().theme_color("accent")) as Label)

	var publish_scroll := ScrollContainer.new()
	publish_scroll.name = "SocialPublishScroll"
	publish_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	publish_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	publish_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	publish_page.add_child(publish_scroll)

	var publish_content := VBoxContainer.new()
	publish_content.name = "SocialPublishContent"
	publish_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	publish_content.add_theme_constant_override("separation", 8)
	publish_scroll.add_child(publish_content)

	var composer := _theme().panel() as PanelContainer
	composer.name = "SocialPublishComposer"
	composer.set_meta("soft_panel", true)
	publish_content.add_child(composer)
	var composer_box := VBoxContainer.new()
	composer_box.add_theme_constant_override("separation", 6)
	composer.add_child(composer_box)
	var placed_sentence_units := _painted_sentence_units
	var composer_header := HBoxContainer.new()
	composer_header.add_theme_constant_override("separation", 8)
	composer_box.add_child(composer_header)
	var composer_step := _theme().label("01  /  内容", 13, _theme().theme_color("accent")) as Label
	composer_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer_header.add_child(composer_step)
	# 计数器语义参考 Bluesky:一枚字 = 1 个单位,软上限提示而非硬拦截。
	var unit_counter := _theme().label(
		"%d / %d 字" % [placed_sentence_units.size(), _source().composer_soft_unit_limit()],
		12,
		_theme().theme_color("accent")
	) as Label
	unit_counter.name = "SocialPublishUnitCounter"
	composer_header.add_child(unit_counter)
	composer_box.add_child(_theme().label("把笔记本里的字拖进来", 17, _theme().theme_color("ink")) as Label)
	_render_publish_sentence_area(composer_box, placed_sentence_units)


func _render_publish_sentence_area(composer_box: VBoxContainer, placed_units: Array) -> void:
	var answer_panel := ComposerDropAreaScript.new()
	answer_panel.name = "ComposerAnswerPanel"
	answer_panel.custom_minimum_size.y = 92
	if _theme() != null:
		answer_panel.add_theme_stylebox_override(
			"panel",
			_theme().soft_style(_theme().theme_color("surface"), _theme().theme_color("accent"))
		)
	answer_panel.unit_dropped.connect(_on_composer_area_dropped)
	composer_box.add_child(answer_panel)
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
	for unit_index in placed_units.size():
		var placed_tile := ComposerAnswerTileScript.new()
		placed_tile.name = "ComposerAnswerTile%d" % unit_index
		placed_tile.text = str(placed_units[unit_index])
		placed_tile.focus_mode = Control.FOCUS_NONE
		placed_tile.custom_minimum_size = Vector2(44, 42)
		placed_tile.set_meta("skip_localization", true)
		placed_tile.configure_answer_tile(unit_index, str(placed_units[unit_index]))
		placed_tile.pressed.connect(_on_composer_answer_pressed.bind(unit_index))
		placed_tile.unit_dropped_before.connect(_on_composer_tile_dropped)
		if _theme() != null:
			_theme().apply_composer_tile_theme(placed_tile, false)
			placed_tile.drag_preview_color = _theme().theme_color("accent")
		answer_flow.add_child(placed_tile)
	var answer_rule := ColorRect.new()
	answer_rule.name = "ComposerAnswerUnderline"
	answer_rule.color = Color(_theme().theme_color("accent"), 0.8)
	answer_rule.custom_minimum_size.y = 2.0
	answer_box.add_child(answer_rule)

	var locale := _source().current_locale()
	var preview_text := MemeGameStateScript.sentence_text(placed_units, locale)
	var preview_label := _theme().label(preview_text, 15, _theme().theme_color("ink")) as Label
	preview_label.name = "ComposerPreviewLabel"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.set_meta("skip_localization", true)
	composer_box.add_child(preview_label)

	var post_button := Button.new()
	post_button.name = "SocialPublishPostButton"
	post_button.custom_minimum_size.y = 52
	if placed_units.is_empty():
		post_button.text = "先放入一个字"
		post_button.disabled = true
	else:
		post_button.text = "投稿"
		post_button.disabled = false
		post_button.add_theme_stylebox_override("normal", _theme().style(_theme().theme_color("accent"), _theme().theme_color("ink")))
		post_button.add_theme_color_override("font_color", _theme().theme_color("surface"))
	post_button.pressed.connect(_on_composer_submit_pressed)
	composer_box.add_child(post_button)


func _on_composer_area_dropped(data: Dictionary) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_AREA_DROPPED, {UiIntentsScript.KEY_DATA: data})


func _on_composer_tile_dropped(data: Dictionary, before_index: int) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_TILE_DROPPED, {UiIntentsScript.KEY_DATA: data, UiIntentsScript.KEY_BEFORE_INDEX: before_index})


func _on_composer_answer_pressed(unit_index: int) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_ANSWER_TAPPED, {UiIntentsScript.KEY_UNIT_INDEX: unit_index})


func _on_composer_submit_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_COMPOSER_SUBMIT_REQUESTED)


func _on_model_changed(_value: Variant) -> void:
	_repaint_unless_syncing()


func _repaint_unless_syncing() -> void:
	if not _watch.is_syncing():
		_repaint_if_stale()


## A page that is not painted is left to the social panel; a page that shows these values already needs nothing.
func _repaint_if_stale() -> void:
	if _host == null:
		return
	if _sentence_units() == _painted_sentence_units:
		return
	_paint()
	_theme().apply_ui_theme(_page)
	_theme().localize_control_tree(_page)


func _sentence_units() -> Array:
	var value: Variant = _watch.read(PropertyKeysScript.FREE_SENTENCE_UNITS)
	return value as Array if value is Array else []


func _source() -> SocialFeedSource:
	return ServiceRegistryScript.resolve(ServiceKeysScript.SOCIAL_FEED_SOURCE) as SocialFeedSource


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme
