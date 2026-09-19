class_name SocialFeedPanel
extends Node
## Game-side social phone shell: window chrome, home feed masonry, bottom nav, and intent signals.

const ComposerAnswerTileScript = preload("res://scripts/ui/composer_answer_tile.gd")
const ComposerDropAreaScript = preload("res://scripts/ui/composer_drop_area.gd")

signal channel_pressed(channel: String)
signal screen_requested(screen: String)
signal card_clicked(post_index: int)
signal like_pressed(post_id: String)
signal follow_pressed(author_id: String)
signal close_requested
signal detail_close_requested
signal publish_confirm_requested

const SOCIAL_FEED_WHEEL_STEP := 2
const SOCIAL_FEED_POSTER_HEIGHTS := [
	214.0, 176.0, 238.0, 194.0,
	226.0, 184.0, 218.0, 202.0,
	244.0, 188.0, 232.0, 180.0,
]
const SOCIAL_FEED_CAPTION_HEIGHT := 62.0
const SOCIAL_FEED_CARD_CHROME_HEIGHT := 130.0
const SOCIAL_WINDOW_LEFT := -835.0
const SOCIAL_WINDOW_TOP := 18.0
const SOCIAL_WINDOW_RIGHT := -397.0
const SOCIAL_WINDOW_BOTTOM := 910.0

var _app_window: PanelContainer
var _app_body: VBoxContainer
var _app_title: Label
var _detail_window: PanelContainer
var _detail_body: VBoxContainer
var _detail_title: Label
var _social_detail_post_index := 0
var _social_detail_open := false
var _panel_factory: Callable
var _label_factory: Callable
var _style_fn: Callable
var _theme_color_fn: Callable
var _ui_font_size_fn: Callable
var _register_draggable: Callable
var _load_texture_fn: Callable
var _poster_texture_fn: Callable
var _visible_post_indices_fn: Callable
var _post_for_index_fn: Callable
var _is_following_fn: Callable
var _like_text_fn: Callable
var _caption_text_fn: Callable
var _corrupt_text_fn: Callable
var _floor_label_fn: Callable
var _translate_fn: Callable
var _pickup_bbcode_fn: Callable
var _pickup_meta_fn: Callable
var _author_id_fn: Callable
var _pickup_line_fn: Callable
var _pickup_comments_fn: Callable
var _player_echo_quote_fn: Callable
var _echo_comment_handle_fn: Callable
var _game_day_fn: Callable
var _current_locale_fn: Callable
var _publish_result_fn: Callable
var _free_sentence_units_fn: Callable
var _soft_style_fn: Callable
var _composer_area_drop_fn: Callable
var _composer_tile_drop_fn: Callable
var _composer_answer_tapped_fn: Callable
var _composer_submit_fn: Callable
var _apply_composer_tile_theme_fn: Callable
var _free_sentence_text_fn: Callable
var _can_spend_action_fn: Callable
var _completed_memes_count_fn: Callable
var _pollution_fn: Callable
var _player_character_path := ""
var _composer_soft_unit_limit := 12
var _confirm_publish_button: Button
var _channels: Array = []
var _no_signal_icon_path := ""
var _poster_sheet_path := ""
var _poster_sheet_count := 0


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_social_app_window(parent)
	_build_social_detail_window(parent)


func get_app_window() -> Control:
	return _app_window


func get_detail_window() -> Control:
	return _detail_window


func get_app_body() -> Control:
	return _app_body


func get_app_title() -> Control:
	return _app_title


func get_detail_post_index() -> int:
	return _social_detail_post_index


func set_detail_post_index(post_index: int) -> void:
	_social_detail_post_index = post_index


func is_detail_open() -> bool:
	return _social_detail_open


func get_confirm_publish_button() -> Button:
	return _confirm_publish_button


func open_detail(post_index: int) -> void:
	_social_detail_post_index = post_index
	_social_detail_open = true
	if _detail_window != null:
		_detail_window.move_to_front()


func close_detail() -> void:
	_social_detail_open = false


func layout_detail(viewport_size: Vector2, hud_safe_left: float = 12.0) -> void:
	if _detail_window == null:
		return
	_detail_window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	if viewport_size.x >= 900.0:
		_detail_window.offset_left = -379.0
		_detail_window.offset_top = 96.0
		_detail_window.offset_right = -24.0
		_detail_window.offset_bottom = minf(850.0, viewport_size.y - 24.0)
		return
	var safe_left := maxf(12.0, hud_safe_left)
	var right_margin := 12.0
	var available_width := maxf(220.0, viewport_size.x - safe_left - right_margin)
	var target_width := minf(376.0, available_width)
	_detail_window.offset_right = -right_margin
	_detail_window.offset_left = _detail_window.offset_right - target_width
	_detail_window.offset_top = 20.0
	_detail_window.offset_bottom = viewport_size.y - 12.0


func update_visibility(in_phone: bool, social_app_open: bool) -> void:
	if _detail_window != null:
		_detail_window.visible = in_phone and _social_detail_open and social_app_open


func render_companion() -> void:
	if _detail_body == null:
		return
	_clear(_detail_body)
	if not _social_detail_open:
		return
	if _detail_title != null and _floor_label_fn.is_valid():
		_detail_title.text = str(_floor_label_fn.call())
	_render_detail_page(_detail_body, true)


func layout_window(viewport_size: Vector2, hud_safe_left: float = 12.0) -> void:
	if _app_window == null:
		return
	var window := _app_window as Control
	if viewport_size.x >= 900.0:
		window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		window.offset_left = SOCIAL_WINDOW_LEFT
		window.offset_top = SOCIAL_WINDOW_TOP
		window.offset_right = SOCIAL_WINDOW_RIGHT
		window.offset_bottom = SOCIAL_WINDOW_BOTTOM
		return
	window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var right_margin := 12.0
	var available_width := maxf(220.0, viewport_size.x - hud_safe_left - right_margin)
	var original_width := SOCIAL_WINDOW_RIGHT - SOCIAL_WINDOW_LEFT
	var target_width := minf(original_width, available_width)
	var top_margin := 6.0
	target_width = minf(target_width, (viewport_size.y - top_margin - 8.0) * 0.62)
	window.offset_right = -right_margin
	window.offset_left = window.offset_right - target_width
	window.offset_top = top_margin
	window.offset_bottom = viewport_size.y - 8.0


func render_app(screen: String, channel: String) -> void:
	if _app_body == null:
		return
	_clear(_app_body)
	var phone_view := _panel_factory.call() as PanelContainer
	phone_view.name = "SocialPhoneView"
	phone_view.set_meta("phone_surface", true)
	phone_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_app_body.add_child(phone_view)

	var phone_box := VBoxContainer.new()
	phone_box.add_theme_constant_override("separation", 4)
	phone_view.add_child(phone_box)

	var status_bar := HBoxContainer.new()
	status_bar.name = "SocialPhoneStatusBar"
	status_bar.custom_minimum_size.y = 52
	status_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	status_bar.add_theme_constant_override("separation", 6)
	phone_box.add_child(status_bar)
	_register_draggable.call(_app_window, "app:social", status_bar)
	var time_label := _label_factory.call("9:41", 14, _theme_color_fn.call("ink")) as Label
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.custom_minimum_size.x = 40
	status_bar.add_child(time_label)
	var no_signal_group := HBoxContainer.new()
	no_signal_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_signal_group.add_theme_constant_override("separation", 5)
	status_bar.add_child(no_signal_group)
	var no_signal_icon := TextureRect.new()
	no_signal_icon.name = "SocialNoSignalIcon"
	no_signal_icon.texture = _load_texture_fn.call(_no_signal_icon_path) as Texture2D
	no_signal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_signal_icon.visible = true
	no_signal_icon.custom_minimum_size = Vector2(22, 22)
	no_signal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	no_signal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	no_signal_group.add_child(no_signal_icon)
	var signal_label := _label_factory.call("无信号", 13, _theme_color_fn.call("accent")) as Label
	signal_label.name = "SocialNoSignalLabel"
	signal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_signal_group.add_child(signal_label)
	var top_spacer := Control.new()
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(top_spacer)
	var drag_grip := ColorRect.new()
	drag_grip.name = "SocialStatusDragGrip"
	drag_grip.color = _theme_color_fn.call("accent")
	drag_grip.modulate.a = 0.45
	drag_grip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drag_grip.custom_minimum_size = Vector2(36, 3)
	drag_grip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_bar.add_child(drag_grip)
	var close_social := Button.new()
	close_social.name = "SocialAppInlineCloseButton"
	close_social.text = "X"
	close_social.set_meta("window_close_button", true)
	close_social.custom_minimum_size = Vector2(48, 48)
	close_social.pressed.connect(_on_close_pressed)
	status_bar.add_child(close_social)

	var channel_tabs := HBoxContainer.new()
	channel_tabs.name = "SocialChannelTabs"
	channel_tabs.custom_minimum_size.y = 48
	channel_tabs.add_theme_constant_override("separation", 2)
	phone_box.add_child(channel_tabs)
	for channel_data in _channels:
		var channel_id := str(channel_data.get("id", "discover"))
		var tab_text := str(channel_data.get("label", ""))
		var tab_item := VBoxContainer.new()
		tab_item.name = "SocialChannelTabItem%s" % channel_id
		tab_item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_item.add_theme_constant_override("separation", 0)
		channel_tabs.add_child(tab_item)
		var tab := Button.new()
		tab.name = "SocialChannelTab%s" % channel_id
		tab.text = tab_text
		tab.set_meta("flat_phone_button", true)
		tab.custom_minimum_size = Vector2(88, 48)
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.pressed.connect(_on_channel_tab_pressed.bind(channel_id))
		tab_item.add_child(tab)
		var underline := ColorRect.new()
		underline.name = "SocialChannelTabUnderline%s" % channel_id
		underline.color = _theme_color_fn.call("muted")
		underline.custom_minimum_size.y = 3
		underline.visible = channel_id == channel
		tab_item.add_child(underline)

	var page_host := VBoxContainer.new()
	page_host.name = "SocialPageHost"
	page_host.clip_contents = true
	page_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page_host.add_theme_constant_override("separation", 8)
	phone_box.add_child(page_host)

	match screen:
		"detail":
			_render_detail_page(page_host, false)
		"publish":
			_render_publish_page(page_host)
		"profile":
			_render_profile_page(page_host)
		_:
			_render_home_page(page_host, channel)

	_render_bottom_nav(phone_box)


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_panel_factory = deps.get("panel_factory", Callable())
	_label_factory = deps.get("label_factory", Callable())
	_style_fn = deps.get("style_fn", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_ui_font_size_fn = deps.get("ui_font_size", Callable())
	_register_draggable = deps.get("register_draggable", Callable())
	_load_texture_fn = deps.get("load_texture", Callable())
	_poster_texture_fn = deps.get("poster_texture", Callable())
	_visible_post_indices_fn = deps.get("visible_post_indices", Callable())
	_post_for_index_fn = deps.get("post_for_index", Callable())
	_is_following_fn = deps.get("is_following", Callable())
	_like_text_fn = deps.get("like_text", Callable())
	_caption_text_fn = deps.get("caption_text", Callable())
	_corrupt_text_fn = deps.get("corrupt_text", Callable())
	_floor_label_fn = deps.get("floor_label", Callable())
	_translate_fn = deps.get("translate", Callable())
	_pickup_bbcode_fn = deps.get("pickup_bbcode", Callable())
	_pickup_meta_fn = deps.get("pickup_meta", Callable())
	_author_id_fn = deps.get("author_id", Callable())
	_pickup_line_fn = deps.get("pickup_line", Callable())
	_pickup_comments_fn = deps.get("pickup_comments", Callable())
	_player_echo_quote_fn = deps.get("player_echo_quote", Callable())
	_echo_comment_handle_fn = deps.get("echo_comment_handle", Callable())
	_game_day_fn = deps.get("game_day", Callable())
	_current_locale_fn = deps.get("current_locale", Callable())
	_publish_result_fn = deps.get("publish_result", Callable())
	_free_sentence_units_fn = deps.get("free_sentence_units", Callable())
	_soft_style_fn = deps.get("soft_style", Callable())
	_composer_area_drop_fn = deps.get("composer_area_drop", Callable())
	_composer_tile_drop_fn = deps.get("composer_tile_drop", Callable())
	_composer_answer_tapped_fn = deps.get("composer_answer_tapped", Callable())
	_composer_submit_fn = deps.get("composer_submit", Callable())
	_apply_composer_tile_theme_fn = deps.get("apply_composer_tile_theme", Callable())
	_free_sentence_text_fn = deps.get("free_sentence_text", Callable())
	_can_spend_action_fn = deps.get("can_spend_action", Callable())
	_completed_memes_count_fn = deps.get("completed_memes_count", Callable())
	_pollution_fn = deps.get("pollution", Callable())
	_player_character_path = str(deps.get("player_character_path", ""))
	_composer_soft_unit_limit = int(deps.get("composer_soft_unit_limit", 12))
	_channels = deps.get("channels", [])
	_no_signal_icon_path = str(deps.get("no_signal_icon_path", ""))
	_poster_sheet_path = str(deps.get("poster_sheet_path", ""))
	_poster_sheet_count = int(deps.get("poster_sheet_count", 0))


func _build_social_app_window(parent: Control) -> void:
	if _app_window != null:
		return
	_app_window = _panel_factory.call() as PanelContainer
	_app_window.name = "SocialAppWindow"
	_app_window.clip_contents = true
	_app_window.set_meta("phone_shell", true)
	_app_window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_app_window.z_index = 10
	parent.add_child(_app_window)
	layout_window(parent.size)

	var app_box := VBoxContainer.new()
	app_box.add_theme_constant_override("separation", 4)
	_app_window.add_child(app_box)

	_app_title = _label_factory.call("社交媒体 App", 21, _theme_color_fn.call("accent")) as Label
	_app_title.name = "SocialAppWindowHandle"
	_app_title.visible = false
	_app_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_app_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_app_window.add_child(_app_title)

	_app_body = VBoxContainer.new()
	_app_body.name = "SocialAppBody"
	_app_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_app_body.add_theme_constant_override("separation", 8)
	app_box.add_child(_app_body)


func _build_social_detail_window(parent: Control) -> void:
	if _detail_window != null:
		return
	_detail_window = _panel_factory.call() as PanelContainer
	_detail_window.name = "SocialDetailWindow"
	_detail_window.add_theme_stylebox_override("panel", _detail_dark_style())
	_detail_window.clip_contents = true
	_detail_window.z_index = 24
	parent.add_child(_detail_window)
	layout_detail(parent.size)

	var shell := VBoxContainer.new()
	shell.name = "SocialDetailShell"
	shell.add_theme_constant_override("separation", 8)
	_detail_window.add_child(shell)

	var header := HBoxContainer.new()
	header.name = "SocialDetailWindowHeader"
	header.custom_minimum_size.y = 56
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_theme_constant_override("separation", 8)
	shell.add_child(header)

	_detail_title = _label_factory.call("第 1 层 / 3", 18, _theme_color_fn.call("surface")) as Label
	_detail_title.name = "SocialDetailWindowHandle"
	_detail_title.set_meta("on_dark", true)
	_detail_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_detail_title)
	_register_draggable.call(_detail_window, "social-detail", header)
	_register_draggable.call(_detail_window, "social-detail", _detail_title)

	var close_button := Button.new()
	close_button.name = "SocialDetailWindowCloseButton"
	close_button.text = "X"
	close_button.set_meta("dark_window_close_button", true)
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(_on_detail_close_pressed)
	header.add_child(close_button)

	var detail_scroll := ScrollContainer.new()
	detail_scroll.name = "SocialDetailScroll"
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	shell.add_child(detail_scroll)

	_detail_body = VBoxContainer.new()
	_detail_body.name = "SocialDetailBody"
	_detail_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_body.add_theme_constant_override("separation", 8)
	detail_scroll.add_child(_detail_body)
	_detail_window.visible = false


func _render_home_page(parent: VBoxContainer, channel: String) -> void:
	var home_page := VBoxContainer.new()
	home_page.name = "SocialHomePage"
	home_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home_page.add_theme_constant_override("separation", 0)
	parent.add_child(home_page)
	if channel == "nearby":
		_render_channel_empty_state(
			home_page,
			"SocialNearbyUnavailable",
			"无法定位",
			"设备保持无信号。附近内容无法取得位置。"
		)
		return

	var visible_post_indices: Array = []
	if _visible_post_indices_fn.is_valid():
		visible_post_indices = _visible_post_indices_fn.call()
	if channel == "following" and visible_post_indices.is_empty():
		_render_channel_empty_state(
			home_page,
			"SocialFollowingEmptyState",
			"还没有关注",
			"在发现瀑布流里关注一个账号，它的帖子会留在这里。"
		)
		return

	var feed_frame := PanelContainer.new()
	feed_frame.name = "SocialFeedDarkFrame"
	feed_frame.add_theme_stylebox_override("panel", _social_feed_dark_style())
	feed_frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	home_page.add_child(feed_frame)

	var feed_scroll := ScrollContainer.new()
	feed_scroll.name = "SocialFeedScroll"
	feed_scroll.set_meta("slow_scroll_step", SOCIAL_FEED_WHEEL_STEP)
	feed_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	feed_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	feed_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	feed_scroll.gui_input.connect(_on_feed_scroll_gui_input.bind(feed_scroll))
	feed_frame.add_child(feed_scroll)

	var feed_content := VBoxContainer.new()
	feed_content.name = "SocialFeedContent"
	feed_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	feed_content.add_theme_constant_override("separation", 10)
	feed_scroll.add_child(feed_content)

	var masonry := HBoxContainer.new()
	masonry.name = "SocialFeedMasonry"
	masonry.add_theme_constant_override("separation", 12)
	masonry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	masonry.set_meta("layout_mode", "independent_equal_width_columns")
	feed_content.add_child(masonry)
	var masonry_columns: Array[VBoxContainer] = []
	var masonry_heights := [0.0, 0.0]
	for column_index in 2:
		var column := VBoxContainer.new()
		column.name = "SocialMasonryColumn%d" % column_index
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.size_flags_stretch_ratio = 1.0
		column.add_theme_constant_override("separation", 10)
		column.set_meta("masonry_column_index", column_index)
		masonry.add_child(column)
		masonry_columns.append(column)
	for visible_index in visible_post_indices.size():
		var post_index: int = int(visible_post_indices[visible_index])
		var post: Dictionary = {}
		if _post_for_index_fn.is_valid():
			post = _post_for_index_fn.call(post_index)
		var card_height := _feed_card_height(post_index)
		var column_index := 0 if float(masonry_heights[0]) <= float(masonry_heights[1]) else 1
		var card_panel := _panel_factory.call() as PanelContainer
		card_panel.name = "SocialPostCard%d" % post_index
		card_panel.set_meta("social_card", true)
		card_panel.add_theme_stylebox_override("panel", _social_card_style())
		card_panel.set_meta("masonry_column_index", column_index)
		card_panel.custom_minimum_size = Vector2(0, card_height)
		card_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		card_panel.clip_contents = true
		card_panel.mouse_filter = Control.MOUSE_FILTER_STOP
		card_panel.gui_input.connect(_on_card_gui_input.bind(post_index))
		card_panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		masonry_columns[column_index].add_child(card_panel)
		masonry_heights[column_index] = float(masonry_heights[column_index]) + card_height + 10.0
		var card_clip := Control.new()
		card_clip.name = "SocialPostClip%d" % post_index
		card_clip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_clip.size_flags_vertical = Control.SIZE_EXPAND_FILL
		card_clip.clip_contents = true
		card_clip.mouse_filter = Control.MOUSE_FILTER_PASS
		card_panel.add_child(card_clip)
		var card := VBoxContainer.new()
		card.name = "SocialPostLayout%d" % post_index
		card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		card.add_theme_constant_override("separation", 6)
		card.clip_contents = true
		card_clip.add_child(card)
		_render_card_poster(card, post_index, post)
		var caption_slot := Control.new()
		caption_slot.name = "SocialPostCaptionSlot%d" % post_index
		caption_slot.custom_minimum_size = Vector2(0, SOCIAL_FEED_CAPTION_HEIGHT)
		caption_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		caption_slot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		caption_slot.clip_contents = true
		caption_slot.mouse_filter = Control.MOUSE_FILTER_PASS
		card.add_child(caption_slot)
		var caption_text := ""
		if _caption_text_fn.is_valid():
			caption_text = str(_caption_text_fn.call(post, post_index))
		var caption := _label_factory.call(caption_text, 14, _theme_color_fn.call("ink")) as Label
		caption.name = "SocialPostCaption%d" % post_index
		caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.max_lines_visible = 3
		caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		caption.mouse_filter = Control.MOUSE_FILTER_PASS
		caption_slot.add_child(caption)
		var meta_row := HBoxContainer.new()
		meta_row.name = "SocialPostActions%d" % post_index
		meta_row.custom_minimum_size.y = 44
		meta_row.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		meta_row.clip_contents = true
		meta_row.mouse_filter = Control.MOUSE_FILTER_PASS
		meta_row.add_theme_constant_override("separation", 4)
		card.add_child(meta_row)
		var likes := Button.new()
		likes.name = "SocialPostLikeButton%d" % post_index
		var like_text := ""
		if _like_text_fn.is_valid():
			like_text = str(_like_text_fn.call(post, post_index))
		likes.text = like_text
		likes.set_meta("flat_phone_button", true)
		likes.custom_minimum_size = Vector2(64, 44)
		likes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		likes.pressed.connect(_on_like_pressed.bind(str(post.get("id", ""))))
		meta_row.add_child(likes)
		var follow := Button.new()
		follow.name = "SocialPostFollowButton%d" % post_index
		var author_id := str(post.get("id", post.get("handle", "unknown-author")))
		if _author_id_fn.is_valid():
			author_id = str(_author_id_fn.call(post))
		var following := false
		if _is_following_fn.is_valid():
			following = bool(_is_following_fn.call(author_id))
		follow.text = "已关注" if following else "关注"
		follow.set_meta("flat_phone_button", true)
		follow.custom_minimum_size = Vector2(74, 44)
		follow.pressed.connect(_on_follow_pressed.bind(author_id))
		meta_row.add_child(follow)
	var hint_slot := Control.new()
	hint_slot.name = "SocialScrollHintSlot"
	hint_slot.custom_minimum_size.y = 32
	hint_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint_slot.clip_contents = true
	feed_content.add_child(hint_slot)
	var scroll_hint := _label_factory.call("继续下滑浏览更多信号", 13, _theme_color_fn.call("accent")) as Label
	scroll_hint.name = "SocialScrollHint"
	scroll_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_slot.add_child(scroll_hint)
	var hint_spacer := Control.new()
	hint_spacer.name = "SocialScrollHintSpacer"
	hint_spacer.custom_minimum_size.y = 32
	feed_content.add_child(hint_spacer)


func _render_channel_empty_state(parent: VBoxContainer, node_name: String, title: String, body: String) -> void:
	var frame := PanelContainer.new()
	frame.name = node_name
	frame.add_theme_stylebox_override("panel", _social_feed_dark_style())
	frame.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(frame)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(center)
	var copy := VBoxContainer.new()
	copy.custom_minimum_size.x = 300
	copy.add_theme_constant_override("separation", 12)
	center.add_child(copy)
	var eyebrow := _label_factory.call("NO SIGNAL / 00", 13, _theme_color_fn.call("muted")) as Label
	eyebrow.set_meta("on_dark", true)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(eyebrow)
	var heading := _label_factory.call(title, 24, _theme_color_fn.call("surface")) as Label
	heading.set_meta("on_dark", true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(heading)
	var message := _label_factory.call(body, 15, _theme_color_fn.call("muted")) as Label
	message.name = "%sMessage" % node_name
	message.set_meta("on_dark", true)
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(message)


func _render_card_poster(parent: VBoxContainer, post_index: int, post: Dictionary) -> void:
	var poster := PanelContainer.new()
	poster.name = "SocialPostPoster%d" % post_index
	poster.set_meta("poster_frame", true)
	poster.custom_minimum_size.y = _feed_poster_height(post_index)
	poster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poster.mouse_filter = Control.MOUSE_FILTER_PASS
	poster.add_theme_stylebox_override("panel", _style_fn.call(_poster_color(post_index), _theme_color_fn.call("accent")))
	parent.add_child(poster)

	var poster_texture := TextureRect.new()
	poster_texture.name = "SocialPostTexture%d" % post_index
	var poster_cell := int(post.get("poster_cell", post_index))
	if _poster_texture_fn.is_valid():
		poster_texture.texture = _poster_texture_fn.call(poster_cell) as Texture2D
	poster_texture.set_meta("poster_sheet_path", _poster_sheet_path)
	poster_texture.set_meta("poster_sheet_cell", poster_cell % maxi(1, _poster_sheet_count))
	poster_texture.custom_minimum_size = Vector2(0, poster.custom_minimum_size.y)
	poster_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	poster_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	poster_texture.mouse_filter = Control.MOUSE_FILTER_PASS
	poster_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	poster_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	poster.add_child(poster_texture)


func _render_bottom_nav(phone_box: VBoxContainer) -> void:
	var bottom_nav := HBoxContainer.new()
	bottom_nav.name = "SocialBottomNav"
	bottom_nav.set_meta("phone_nav", true)
	bottom_nav.custom_minimum_size.y = 54
	bottom_nav.add_theme_constant_override("separation", 6)
	phone_box.add_child(bottom_nav)
	var nav_items := [
		{"name": "SocialNavHome", "text": "首页", "screen": "home"},
		{"name": "SocialNavCreate", "text": "发布", "screen": "publish"},
		{"name": "SocialNavMine", "text": "我的", "screen": "profile"},
	]
	for nav in nav_items:
		var nav_button := Button.new()
		nav_button.name = str(nav["name"])
		nav_button.text = str(nav["text"])
		nav_button.pressed.connect(_on_nav_pressed.bind(str(nav["screen"])))
		if str(nav["screen"]) == "publish":
			nav_button.custom_minimum_size = Vector2(132, 50)
			nav_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			nav_button.size_flags_stretch_ratio = 1.35
			nav_button.add_theme_stylebox_override("normal", _style_fn.call(_theme_color_fn.call("accent"), _theme_color_fn.call("ink")))
			nav_button.add_theme_stylebox_override("hover", _style_fn.call(_theme_color_fn.call("accent").lightened(0.12), _theme_color_fn.call("ink")))
			nav_button.add_theme_stylebox_override("pressed", _style_fn.call(_theme_color_fn.call("accent").darkened(0.12), _theme_color_fn.call("ink")))
			nav_button.add_theme_color_override("font_color", _theme_color_fn.call("surface"))
			nav_button.add_theme_font_size_override("font_size", _ui_font_size_fn.call(17))
		else:
			nav_button.set_meta("flat_phone_button", true)
			nav_button.custom_minimum_size = Vector2(100, 50)
			nav_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bottom_nav.add_child(nav_button)
	var indicator_wrap := CenterContainer.new()
	indicator_wrap.name = "SocialHomeIndicatorWrap"
	indicator_wrap.custom_minimum_size.y = 12
	phone_box.add_child(indicator_wrap)
	var home_indicator := ColorRect.new()
	home_indicator.name = "SocialHomeIndicator"
	home_indicator.color = _theme_color_fn.call("ink")
	home_indicator.custom_minimum_size = Vector2(94, 4)
	indicator_wrap.add_child(home_indicator)


func _feed_poster_height(post_index: int) -> float:
	return float(SOCIAL_FEED_POSTER_HEIGHTS[posmod(post_index, SOCIAL_FEED_POSTER_HEIGHTS.size())])


func _feed_card_height(post_index: int) -> float:
	return _feed_poster_height(post_index) + SOCIAL_FEED_CARD_CHROME_HEIGHT


func _poster_color(post_index: int) -> Color:
	match post_index % 4:
		0:
			return _theme_color_fn.call("muted")
		1:
			return _theme_color_fn.call("surface")
		2:
			return _theme_color_fn.call("accent").lightened(0.46)
		_:
			return _theme_color_fn.call("bg").lightened(0.10)


func _scroll_feed(feed_scroll: ScrollContainer, delta: int) -> void:
	var max_scroll := int(feed_scroll.get_v_scroll_bar().max_value)
	feed_scroll.scroll_vertical = clampi(feed_scroll.scroll_vertical + delta, 0, max_scroll)


func _on_close_pressed() -> void:
	close_requested.emit()


func _on_channel_tab_pressed(channel_id: String) -> void:
	channel_pressed.emit(channel_id)


func _on_nav_pressed(screen: String) -> void:
	screen_requested.emit(screen)


func _on_like_pressed(post_id: String) -> void:
	like_pressed.emit(post_id)


func _on_follow_pressed(author_id: String) -> void:
	follow_pressed.emit(author_id)


func _on_card_gui_input(event: InputEvent, post_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(post_index)
	elif event is InputEventScreenTouch and event.pressed:
		card_clicked.emit(post_index)


func _on_feed_scroll_gui_input(event: InputEvent, feed_scroll: ScrollContainer) -> void:
	if event is InputEventMouseButton and event.pressed:
		var direction := 0
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			direction = 1
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			direction = -1
		if direction != 0:
			_scroll_feed(feed_scroll, direction * SOCIAL_FEED_WHEEL_STEP)
			feed_scroll.accept_event()
	elif event is InputEventPanGesture:
		var vertical_delta := int(round((event as InputEventPanGesture).delta.y * float(SOCIAL_FEED_WHEEL_STEP)))
		if vertical_delta != 0:
			_scroll_feed(feed_scroll, vertical_delta)
			feed_scroll.accept_event()


func _render_detail_page(parent: VBoxContainer, companion: bool = false) -> void:
	var detail_page := VBoxContainer.new()
	detail_page.name = "SocialPostDetailPage"
	detail_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_page.add_theme_constant_override("separation", 8)
	parent.add_child(detail_page)

	var post: Dictionary = {}
	if _post_for_index_fn.is_valid():
		post = _post_for_index_fn.call(_social_detail_post_index)

	if companion:
		var companion_meta := HBoxContainer.new()
		companion_meta.add_theme_constant_override("separation", 8)
		detail_page.add_child(companion_meta)
		var handle_text := str(post.get("handle", ""))
		if _translate_fn.is_valid():
			handle_text = str(_translate_fn.call(handle_text))
		var companion_handle := _label_factory.call("@%s" % handle_text, 15, _theme_color_fn.call("surface")) as Label
		companion_handle.set_meta("on_dark", true)
		companion_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		companion_meta.add_child(companion_handle)
		var floor_marker := _label_factory.call("信号档案", 13, _theme_color_fn.call("muted")) as Label
		floor_marker.name = "SocialDetailSignalArchive"
		floor_marker.set_meta("on_dark", true)
		companion_meta.add_child(floor_marker)
	else:
		var top_row := HBoxContainer.new()
		top_row.add_theme_constant_override("separation", 8)
		detail_page.add_child(top_row)
		var back := Button.new()
		back.name = "SocialBackToHome"
		back.text = "‹"
		back.custom_minimum_size = Vector2(76, 56)
		back.pressed.connect(_on_detail_close_pressed)
		top_row.add_child(back)
		var handle_text := str(post.get("handle", ""))
		if _translate_fn.is_valid():
			handle_text = str(_translate_fn.call(handle_text))
		var title := _label_factory.call("@%s" % handle_text, 18, _theme_color_fn.call("accent")) as Label
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		top_row.add_child(title)
		var floor_text := ""
		if _floor_label_fn.is_valid():
			floor_text = str(_floor_label_fn.call())
		var floor_label := _label_factory.call(floor_text, 16, _theme_color_fn.call("ink")) as Label
		floor_label.name = "SocialDetailTowerFloor"
		top_row.add_child(floor_label)

	var detail_card := _panel_factory.call() as PanelContainer
	detail_card.name = "SocialPostDetailCard"
	detail_card.add_theme_stylebox_override("panel", _detail_dark_style())
	detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_page.add_child(detail_card)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 9)
	detail_card.add_child(detail_box)
	var media := PanelContainer.new()
	media.custom_minimum_size.y = 320 if companion else 274
	media.set_meta("poster_frame", true)
	media.add_theme_stylebox_override("panel", _style_fn.call(_theme_color_fn.call("muted"), _theme_color_fn.call("accent")))
	detail_box.add_child(media)
	var media_texture := TextureRect.new()
	media_texture.name = "SocialDetailPostTexture"
	var poster_cell := int(post.get("poster_cell", _social_detail_post_index))
	if _poster_texture_fn.is_valid():
		media_texture.texture = _poster_texture_fn.call(poster_cell) as Texture2D
	media_texture.set_meta("poster_sheet_path", _poster_sheet_path)
	media_texture.set_meta("poster_sheet_cell", poster_cell % maxi(1, _poster_sheet_count))
	media_texture.custom_minimum_size = Vector2(300, 320 if companion else 274)
	media_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	media_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	media_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	media.add_child(media_texture)
	var post_body := str(post.get("text", ""))
	if _corrupt_text_fn.is_valid():
		post_body = str(_corrupt_text_fn.call(post_body))
	var post_text := _label_factory.call(post_body, 17, _theme_color_fn.call("surface")) as Label
	post_text.set_meta("on_dark", true)
	post_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(post_text)
	var post_card_id := str(post.get("id", ""))
	var locale := ""
	if _current_locale_fn.is_valid():
		locale = str(_current_locale_fn.call())
	var pickup_line := ""
	if _pickup_line_fn.is_valid():
		pickup_line = str(_pickup_line_fn.call(post_card_id, locale))
	if not pickup_line.is_empty():
		detail_box.add_child(_make_pickup_rich_text("SocialPickupLineText", pickup_line, post_card_id))
		var pickup_hint := _label_factory.call("今天第一次拾字消耗一次行动；之后当天免费。", 12, _theme_color_fn.call("muted")) as Label
		pickup_hint.name = "SocialPickupCostHint"
		pickup_hint.set_meta("on_dark", true)
		pickup_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_box.add_child(pickup_hint)
	var engagement := HBoxContainer.new()
	engagement.name = "SocialDetailEngagementRow"
	engagement.add_theme_constant_override("separation", 8)
	detail_box.add_child(engagement)
	var detail_like := Button.new()
	detail_like.name = "SocialDetailLikeButton"
	var like_text := ""
	if _like_text_fn.is_valid():
		like_text = str(_like_text_fn.call(post, int(post.get("card_index", _social_detail_post_index))))
	detail_like.text = like_text
	detail_like.custom_minimum_size = Vector2(120, 44)
	detail_like.pressed.connect(_on_like_pressed.bind(post_card_id))
	engagement.add_child(detail_like)
	var detail_follow := Button.new()
	detail_follow.name = "SocialDetailFollowButton"
	var author_id := str(post.get("id", post.get("handle", "unknown-author")))
	if _author_id_fn.is_valid():
		author_id = str(_author_id_fn.call(post))
	var following := false
	if _is_following_fn.is_valid():
		following = bool(_is_following_fn.call(author_id))
	detail_follow.text = "已关注" if following else "关注"
	detail_follow.custom_minimum_size = Vector2(120, 44)
	detail_follow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_follow.pressed.connect(_on_follow_pressed.bind(author_id))
	engagement.add_child(detail_follow)
	var signal_profile := _label_factory.call("拾取字词不增加污染；使用它才会改变语言。", 13, _theme_color_fn.call("muted")) as Label
	signal_profile.name = "SocialCardSignalProfile"
	signal_profile.set_meta("on_dark", true)
	signal_profile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(signal_profile)
	var post_comments: Array = []
	if _pickup_comments_fn.is_valid():
		post_comments = _pickup_comments_fn.call(post_card_id, locale)
	if not post_comments.is_empty():
		var comments_rule := ColorRect.new()
		comments_rule.name = "SocialCommentsRule"
		comments_rule.color = Color(_theme_color_fn.call("muted"), 0.35)
		comments_rule.custom_minimum_size.y = 1.0
		detail_box.add_child(comments_rule)
		var comments_header := _label_factory.call("评论 · %d" % post_comments.size(), 14, _theme_color_fn.call("muted")) as Label
		comments_header.name = "SocialCommentsHeader"
		comments_header.set_meta("on_dark", true)
		detail_box.add_child(comments_header)
		for comment_index in post_comments.size():
			var comment: Dictionary = post_comments[comment_index]
			var comment_box := VBoxContainer.new()
			comment_box.name = "SocialComment%d" % comment_index
			comment_box.add_theme_constant_override("separation", 2)
			detail_box.add_child(comment_box)
			var comment_meta := _label_factory.call("%s  ·  %s" % [str(comment.get("handle", "")), str(comment.get("time", ""))], 12, _theme_color_fn.call("muted")) as Label
			comment_meta.name = "SocialCommentMeta%d" % comment_index
			comment_meta.set_meta("on_dark", true)
			comment_meta.set_meta("skip_localization", true)
			comment_box.add_child(comment_meta)
			comment_box.add_child(_make_pickup_rich_text("SocialCommentText%d" % comment_index, str(comment.get("text", "")), post_card_id))
		_render_player_echo_comment(detail_box, post_comments.size())


## 玩家投稿回流:楼里最后一条永远是陌生人在引用你写过的话,系统不作任何提示。
func _render_player_echo_comment(detail_box: VBoxContainer, comment_index: int) -> void:
	var quote := ""
	if _player_echo_quote_fn.is_valid():
		quote = str(_player_echo_quote_fn.call())
	if quote.is_empty():
		return
	var echo_box := VBoxContainer.new()
	echo_box.name = "SocialEchoComment"
	echo_box.add_theme_constant_override("separation", 2)
	detail_box.add_child(echo_box)
	var handle := ""
	if _echo_comment_handle_fn.is_valid():
		handle = str(_echo_comment_handle_fn.call())
	var game_day := 0
	if _game_day_fn.is_valid():
		game_day = int(_game_day_fn.call())
	var echo_meta := _label_factory.call("%s  ·  %02d:%02d" % [handle, 3 + comment_index, 7 + game_day], 12, _theme_color_fn.call("muted")) as Label
	echo_meta.name = "SocialEchoCommentMeta"
	echo_meta.set_meta("on_dark", true)
	echo_meta.set_meta("skip_localization", true)
	echo_box.add_child(echo_meta)
	var echo_text := _label_factory.call(quote, 14, _theme_color_fn.call("surface")) as Label
	echo_text.name = "SocialEchoCommentText"
	echo_text.set_meta("on_dark", true)
	echo_text.set_meta("skip_localization", true)
	echo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	echo_box.add_child(echo_text)


func _on_detail_close_pressed() -> void:
	detail_close_requested.emit()


func _render_publish_page(parent: VBoxContainer) -> void:
	_confirm_publish_button = null
	var publish_page := VBoxContainer.new()
	publish_page.name = "SocialPublishPage"
	publish_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	publish_page.add_theme_constant_override("separation", 6)
	parent.add_child(publish_page)

	var page_header := HBoxContainer.new()
	page_header.name = "SocialPublishHeader"
	page_header.custom_minimum_size.y = 44
	page_header.add_theme_constant_override("separation", 8)
	publish_page.add_child(page_header)
	var page_title := _label_factory.call("发布新信号", 22, _theme_color_fn.call("ink")) as Label
	page_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_header.add_child(page_title)
	var game_day := 0
	if _game_day_fn.is_valid():
		game_day = int(_game_day_fn.call())
	page_header.add_child(_label_factory.call("DAY %02d" % game_day, 12, _theme_color_fn.call("accent")) as Label)

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

	var publish_result: Dictionary = {}
	if _publish_result_fn.is_valid():
		publish_result = _publish_result_fn.call()

	var composer := _panel_factory.call() as PanelContainer
	composer.name = "SocialPublishComposer"
	composer.set_meta("soft_panel", true)
	publish_content.add_child(composer)
	var composer_box := VBoxContainer.new()
	composer_box.add_theme_constant_override("separation", 6)
	composer.add_child(composer_box)
	var placed_sentence_units: Array = []
	if _free_sentence_units_fn.is_valid():
		placed_sentence_units = _free_sentence_units_fn.call()
	var composer_header := HBoxContainer.new()
	composer_header.add_theme_constant_override("separation", 8)
	composer_box.add_child(composer_header)
	var composer_step := _label_factory.call("01  /  内容", 13, _theme_color_fn.call("accent")) as Label
	composer_step.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	composer_header.add_child(composer_step)
	# 计数器语义参考 Bluesky:一枚字 = 1 个单位,软上限提示而非硬拦截。
	var unit_counter := _label_factory.call(
		"%d / %d 字" % [placed_sentence_units.size(), _composer_soft_unit_limit],
		12,
		_theme_color_fn.call("accent")
	) as Label
	unit_counter.name = "SocialPublishUnitCounter"
	composer_header.add_child(unit_counter)
	composer_box.add_child(_label_factory.call("把笔记本里的字拖进来", 17, _theme_color_fn.call("ink")) as Label)
	_render_publish_sentence_area(composer_box, placed_sentence_units)

	var result_panel := _panel_factory.call() as PanelContainer
	result_panel.name = "SocialPublishOutcomePanel"
	result_panel.set_meta("soft_panel", true)
	publish_content.add_child(result_panel)
	var result_box := VBoxContainer.new()
	result_box.add_theme_constant_override("separation", 8)
	result_panel.add_child(result_box)
	result_box.add_child(_label_factory.call("02  /  本次变化", 13, _theme_color_fn.call("accent")) as Label)
	var outcome_row := HBoxContainer.new()
	outcome_row.add_theme_constant_override("separation", 12)
	result_box.add_child(outcome_row)
	var money_text := "+%d" % int(publish_result.get("money_gain", 0)) if not publish_result.is_empty() else "--"
	var money_outcome := _label_factory.call("资金  %s" % money_text, 22, _theme_color_fn.call("ink")) as Label
	money_outcome.name = "SocialPublishMoneyOutcome"
	money_outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome_row.add_child(money_outcome)
	var pollution_text := "+%d%%" % int(publish_result.get("pollution_gain", 0)) if not publish_result.is_empty() else "--"
	var pollution_outcome := _label_factory.call("污染  %s" % pollution_text, 22, _theme_color_fn.call("ink")) as Label
	pollution_outcome.name = "SocialPublishPollutionOutcome"
	pollution_outcome.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outcome_row.add_child(pollution_outcome)

	var hint := _label_factory.call("确认发布消耗 1 次行动；预览与拖拽不扣行动。", 13, _theme_color_fn.call("accent")) as Label
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	publish_content.add_child(hint)

	var action_bar := _panel_factory.call() as PanelContainer
	action_bar.name = "SocialPublishActionBar"
	action_bar.set_meta("fixed_action_bar", true)
	action_bar.set_meta("soft_panel", true)
	publish_page.add_child(action_bar)
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_bar.add_child(action_box)
	_confirm_publish_button = Button.new()
	_confirm_publish_button.name = "SocialPublishButton"
	_confirm_publish_button.text = "确认发布"
	_confirm_publish_button.custom_minimum_size.y = 56
	_confirm_publish_button.pressed.connect(_on_publish_confirm_pressed)
	action_box.add_child(_confirm_publish_button)


func _render_profile_page(parent: VBoxContainer) -> void:
	var profile_page := VBoxContainer.new()
	profile_page.name = "SocialProfilePage"
	profile_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_page.add_theme_constant_override("separation", 10)
	parent.add_child(profile_page)
	profile_page.add_child(_label_factory.call("我的", 22, _theme_color_fn.call("accent")) as Label)
	var identity_frame := PanelContainer.new()
	identity_frame.name = "SocialPlayerIdentityFrame"
	identity_frame.custom_minimum_size.y = 188
	identity_frame.set_meta("poster_frame", true)
	identity_frame.add_theme_stylebox_override("panel", _style_fn.call(_theme_color_fn.call("ink"), _theme_color_fn.call("accent")))
	profile_page.add_child(identity_frame)
	var identity_portrait := TextureRect.new()
	identity_portrait.name = "SocialPlayerIdentityPortrait"
	identity_portrait.texture = _load_texture_fn.call(_player_character_path) as Texture2D
	identity_portrait.set_meta("asset_path", _player_character_path)
	identity_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	identity_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity_frame.add_child(identity_portrait)
	var completed_count := 0
	if _completed_memes_count_fn.is_valid():
		completed_count = int(_completed_memes_count_fn.call())
	var pollution := 0
	if _pollution_fn.is_valid():
		pollution = int(_pollution_fn.call())
	profile_page.add_child(_label_factory.call("已合成梗：%d" % completed_count, 17, _theme_color_fn.call("ink")) as Label)
	profile_page.add_child(_label_factory.call("污染：%d%%" % pollution, 17, _theme_color_fn.call("ink")) as Label)
	var note := _label_factory.call("你的语言档案会随着塔层上升变窄。", 16, _theme_color_fn.call("accent")) as Label
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_page.add_child(note)


func _on_publish_confirm_pressed() -> void:
	publish_confirm_requested.emit()


func _social_feed_dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color_fn.call("ink")
	style.border_color = Color(_theme_color_fn.call("muted"), 0.18)
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(6)
	return style


func _social_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color_fn.call("surface")
	style.border_color = Color(_theme_color_fn.call("muted"), 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	return style


func _detail_dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color_fn.call("ink")
	style.border_color = _theme_color_fn.call("ink")
	style.set_border_width_all(0)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style


func _make_pickup_rich_text(node_name: String, source_text: String, post_id: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.name = node_name
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_font_size_override("normal_font_size", _ui_font_size_fn.call(16))
	rich.add_theme_color_override("default_color", _theme_color_fn.call("surface"))
	rich.set_meta("on_dark", true)
	var bbcode := source_text
	if _pickup_bbcode_fn.is_valid():
		bbcode = str(_pickup_bbcode_fn.call(source_text))
	rich.text = bbcode
	if _pickup_meta_fn.is_valid():
		rich.meta_clicked.connect(_pickup_meta_fn.bind(post_id))
	return rich


func _render_publish_sentence_area(composer_box: VBoxContainer, placed_units: Array) -> void:
	var answer_panel := ComposerDropAreaScript.new()
	answer_panel.name = "ComposerAnswerPanel"
	answer_panel.custom_minimum_size.y = 92
	if _soft_style_fn.is_valid():
		answer_panel.add_theme_stylebox_override(
			"panel",
			_soft_style_fn.call(_theme_color_fn.call("surface"), _theme_color_fn.call("accent"))
		)
	if _composer_area_drop_fn.is_valid():
		answer_panel.unit_dropped.connect(_composer_area_drop_fn)
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
		var placeholder := _label_factory.call("……(句子还空着)", 14, _theme_color_fn.call("muted")) as Label
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
		if _composer_answer_tapped_fn.is_valid():
			placed_tile.pressed.connect(_composer_answer_tapped_fn.bind(unit_index))
		if _composer_tile_drop_fn.is_valid():
			placed_tile.unit_dropped_before.connect(_composer_tile_drop_fn)
		if _apply_composer_tile_theme_fn.is_valid():
			_apply_composer_tile_theme_fn.call(placed_tile, false)
		answer_flow.add_child(placed_tile)
	var answer_rule := ColorRect.new()
	answer_rule.name = "ComposerAnswerUnderline"
	answer_rule.color = Color(_theme_color_fn.call("accent"), 0.8)
	answer_rule.custom_minimum_size.y = 2.0
	answer_box.add_child(answer_rule)

	var preview_text := ""
	if _free_sentence_text_fn.is_valid():
		preview_text = str(_free_sentence_text_fn.call())
	var preview_label := _label_factory.call(preview_text, 15, _theme_color_fn.call("ink")) as Label
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
	elif not _can_spend_action_fn.is_valid() or not bool(_can_spend_action_fn.call()):
		post_button.text = "今天不能再投稿"
		post_button.disabled = true
	else:
		post_button.text = "投稿"
		post_button.disabled = false
		post_button.add_theme_stylebox_override("normal", _style_fn.call(_theme_color_fn.call("accent"), _theme_color_fn.call("ink")))
		post_button.add_theme_color_override("font_color", _theme_color_fn.call("surface"))
	if _composer_submit_fn.is_valid():
		post_button.pressed.connect(_composer_submit_fn)
	composer_box.add_child(post_button)


func _clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
