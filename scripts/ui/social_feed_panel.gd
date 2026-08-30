class_name SocialFeedPanel
extends Node
## Game-side social phone shell: window chrome, home feed masonry, bottom nav, and intent signals.

signal channel_pressed(channel: String)
signal screen_requested(screen: String)
signal card_clicked(post_index: int)
signal like_pressed(post_id: String)
signal follow_pressed(author_id: String)
signal close_requested

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
var _render_detail_page_fn: Callable
var _render_publish_page_fn: Callable
var _render_profile_page_fn: Callable
var _channels: Array = []
var _no_signal_icon_path := ""
var _poster_sheet_path := ""
var _poster_sheet_count := 0
var _input_locked_fn: Callable


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_social_app_window(parent)


func get_app_window() -> Control:
	return _app_window


func get_app_body() -> Control:
	return _app_body


func get_app_title() -> Control:
	return _app_title


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
			if _render_detail_page_fn.is_valid():
				_render_detail_page_fn.call(page_host)
		"publish":
			if _render_publish_page_fn.is_valid():
				_render_publish_page_fn.call(page_host)
		"profile":
			if _render_profile_page_fn.is_valid():
				_render_profile_page_fn.call(page_host)
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
	_render_detail_page_fn = deps.get("render_detail_page", Callable())
	_render_publish_page_fn = deps.get("render_publish_page", Callable())
	_render_profile_page_fn = deps.get("render_profile_page", Callable())
	_channels = deps.get("channels", [])
	_no_signal_icon_path = str(deps.get("no_signal_icon_path", ""))
	_poster_sheet_path = str(deps.get("poster_sheet_path", ""))
	_poster_sheet_count = int(deps.get("poster_sheet_count", 0))
	_input_locked_fn = deps.get("input_locked", Callable())


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
	feed_frame.set_meta("social_feed_dark", true)
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
	frame.set_meta("social_feed_dark", true)
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


func _input_locked() -> bool:
	return _input_locked_fn.is_valid() and bool(_input_locked_fn.call())


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
	if _input_locked():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		card_clicked.emit(post_index)
	elif event is InputEventScreenTouch and event.pressed:
		card_clicked.emit(post_index)


func _on_feed_scroll_gui_input(event: InputEvent, feed_scroll: ScrollContainer) -> void:
	if _input_locked():
		return
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


func _clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()
