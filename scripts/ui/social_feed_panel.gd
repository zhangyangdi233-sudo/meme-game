class_name SocialFeedPanel
extends Node
## Game-side social phone shell: window chrome, home feed masonry, bottom nav, and UI intents on the event bus.
## While the app is shown, it watches the followed authors, the liked posts, the held words, the finished memes
## and the published records, and repaints itself.
## The publish page is its own SocialPublishPanel; this shell only hands it the page host.
## The page, the channel and the open post are this screen's own view and live only here.
## What it paints comes from the SocialFeedSource bound in the service registry.
## Moving between them repaints the panel at once; the host hears the channel or screen intent only to re-theme the new nodes.
## Its windows' drag handles go to the window manager bound in the service registry.

const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const PropertyWatchScript = preload("res://scripts/game/property_watch.gd")
const SocialPublishPanelScript = preload("res://scripts/ui/social_publish_panel.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")

const SOCIAL_FEED_WHEEL_STEP := 2
const SCREENS := ["home", "publish", "profile"]
const DEFAULT_SCREEN := "home"
const DEFAULT_CHANNEL := "discover"
## Opening this channel opens its first post beside the feed.
const TOWER_BASE_CHANNEL := "tower_base"
## The open post's index, or this when no post is open.
const NO_POST := -1
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
var _detail_post_index := NO_POST
var _source: SocialFeedSource
var _publish: SocialPublishPanel
var _screen := DEFAULT_SCREEN
var _channel := DEFAULT_CHANNEL
var _rendered := false
var _app_shown := false
var _followed: Array = []
var _liked: Array = []
var _held_chars: Array = []
var _completed_memes: Array = []
var _published: Array = []
var _painted_followed: Array = []
var _painted_liked: Array = []
var _painted_held_chars: Array = []
var _painted_memes: Array = []
var _painted_published: Array = []
var _watch: PropertyWatchScript = PropertyWatchScript.new(self, {
	PropertyKeysScript.SOCIAL_FOLLOWED_HANDLES: _on_followed,
	PropertyKeysScript.SOCIAL_LIKED_POST_IDS: _on_liked,
	PropertyKeysScript.COLLECTED_CHAR_UNITS: _on_held_chars,
	PropertyKeysScript.COMPLETED_MEMES: _on_completed_memes,
	PropertyKeysScript.PUBLISHED_MEMES: _on_published,
})


func _init() -> void:
	_publish = SocialPublishPanelScript.new()
	_publish.name = "SocialPublishPanel"
	add_child(_publish)


func mount(parent: Control) -> void:
	_resolve_source()
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


func is_detail_open() -> bool:
	return _detail_post_index != NO_POST


## Opens one post beside the feed and tells the host which one.
func open_post(post_index: int) -> void:
	_open_detail(post_index)
	render_companion()
	GameEventBus.raise(UiIntentsScript.SOCIAL_CARD_CLICKED, {UiIntentsScript.KEY_POST_INDEX: post_index})


## Shuts the open post, for example when the app window closes.
func close_detail() -> void:
	_detail_post_index = NO_POST
	_show_detail_window()


func show_screen(screen: String) -> void:
	if screen not in SCREENS:
		return
	_screen = screen
	_channel = DEFAULT_CHANNEL
	close_detail()
	if _repaint_page():
		GameEventBus.raise(UiIntentsScript.SOCIAL_SCREEN_REQUESTED, {UiIntentsScript.KEY_SCREEN: screen})


func select_channel(channel: String) -> void:
	_channel = channel
	_screen = DEFAULT_SCREEN
	if channel == TOWER_BASE_CHANNEL:
		_open_detail(0)
	else:
		close_detail()
	if _repaint_page():
		GameEventBus.raise(UiIntentsScript.SOCIAL_CHANNEL_PRESSED, {UiIntentsScript.KEY_CHANNEL: channel})


## A new run starts on the home feed with no post open.
func reset_view() -> void:
	_screen = DEFAULT_SCREEN
	_channel = DEFAULT_CHANNEL
	close_detail()


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


## The phone decides whether the social app shows. While it shows, the models decide who is followed and what is liked.
func update_visibility(in_phone: bool, social_app_open: bool) -> void:
	_app_shown = in_phone and social_app_open
	_show_detail_window()
	_publish.set_shown(_app_shown)
	if _app_shown:
		# Registering delivers each list once; one repaint after all of them covers a list that changed while hidden.
		if not _watch.is_active() and _watch.start():
			_repaint_if_stale()
	else:
		_watch.stop()


func render_companion() -> void:
	if _detail_body == null:
		return
	_painted_held_chars = _held_chars
	_painted_published = _published
	_clear(_detail_body)
	if not is_detail_open():
		return
	if _detail_title != null:
		_detail_title.text = _source.floor_label()
	_render_detail_page(_detail_body)


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


func render_app() -> void:
	if _app_body == null:
		return
	var screen := _screen
	var channel := _channel
	_rendered = true
	_publish.release()
	_painted_followed = _followed
	_painted_liked = _liked
	_painted_memes = _completed_memes
	_clear(_app_body)
	var phone_view := _theme().panel() as PanelContainer
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
	_register_drag_handle(_app_window, "app:social", status_bar)
	var time_label := _theme().label("9:41", 14, _theme().theme_color("ink")) as Label
	time_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	time_label.custom_minimum_size.x = 40
	status_bar.add_child(time_label)
	var no_signal_group := HBoxContainer.new()
	no_signal_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_signal_group.add_theme_constant_override("separation", 5)
	status_bar.add_child(no_signal_group)
	var no_signal_icon := TextureRect.new()
	no_signal_icon.name = "SocialNoSignalIcon"
	no_signal_icon.texture = _source.load_texture(_source.no_signal_icon_path())
	no_signal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_signal_icon.visible = true
	no_signal_icon.custom_minimum_size = Vector2(22, 22)
	no_signal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	no_signal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	no_signal_group.add_child(no_signal_icon)
	var signal_label := _theme().label("无信号", 13, _theme().theme_color("accent")) as Label
	signal_label.name = "SocialNoSignalLabel"
	signal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	no_signal_group.add_child(signal_label)
	var top_spacer := Control.new()
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_bar.add_child(top_spacer)
	var drag_grip := ColorRect.new()
	drag_grip.name = "SocialStatusDragGrip"
	drag_grip.color = _theme().theme_color("accent")
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
	for channel_data in _source.channels():
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
		underline.color = _theme().theme_color("muted")
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
		"publish":
			_publish.render(page_host)
		"profile":
			_render_profile_page(page_host)
		_:
			_render_home_page(page_host, channel)

	_render_bottom_nav(phone_box)


func _resolve_source() -> void:
	_source = ServiceRegistryScript.resolve(ServiceKeysScript.SOCIAL_FEED_SOURCE) as SocialFeedSource


func _build_social_app_window(parent: Control) -> void:
	if _app_window != null:
		return
	_app_window = _theme().panel() as PanelContainer
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

	_app_title = _theme().label("社交媒体 App", 21, _theme().theme_color("accent")) as Label
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
	_detail_window = _theme().panel() as PanelContainer
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

	_detail_title = _theme().label("第 1 层 / 3", 18, _theme().theme_color("surface")) as Label
	_detail_title.name = "SocialDetailWindowHandle"
	_detail_title.set_meta("on_dark", true)
	_detail_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_detail_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_detail_title)
	_register_drag_handle(_detail_window, "social-detail", header)
	_register_drag_handle(_detail_window, "social-detail", _detail_title)

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

	var visible_post_indices: Array = _source.visible_post_indices(_followed, channel)
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
		var post: Dictionary = _source.post_for_index(post_index)
		var card_height := _feed_card_height(post_index)
		var column_index := 0 if float(masonry_heights[0]) <= float(masonry_heights[1]) else 1
		var card_panel := _theme().panel() as PanelContainer
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
		var caption_text := _source.caption_text(post, post_index)
		var caption := _theme().label(caption_text, 14, _theme().theme_color("ink")) as Label
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
		var like_text := _source.like_text(post, post_index, _liked)
		likes.text = like_text
		likes.set_meta("flat_phone_button", true)
		likes.custom_minimum_size = Vector2(64, 44)
		likes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		likes.pressed.connect(_on_like_pressed.bind(str(post.get("id", ""))))
		meta_row.add_child(likes)
		var follow := Button.new()
		follow.name = "SocialPostFollowButton%d" % post_index
		var author_id := _source.author_id(post)
		var following := _followed.has(author_id)
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
	var scroll_hint := _theme().label("继续下滑浏览更多信号", 13, _theme().theme_color("accent")) as Label
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
	var eyebrow := _theme().label("NO SIGNAL / 00", 13, _theme().theme_color("muted")) as Label
	eyebrow.set_meta("on_dark", true)
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(eyebrow)
	var heading := _theme().label(title, 24, _theme().theme_color("surface")) as Label
	heading.set_meta("on_dark", true)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_child(heading)
	var message := _theme().label(body, 15, _theme().theme_color("muted")) as Label
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
	poster.add_theme_stylebox_override("panel", _theme().style(_poster_color(post_index), _theme().theme_color("accent")))
	parent.add_child(poster)

	var poster_texture := TextureRect.new()
	poster_texture.name = "SocialPostTexture%d" % post_index
	var poster_cell := int(post.get("poster_cell", post_index))
	poster_texture.texture = _source.poster_texture(poster_cell)
	poster_texture.set_meta("poster_sheet_path", _source.poster_sheet_path())
	poster_texture.set_meta("poster_sheet_cell", poster_cell % maxi(1, _source.poster_sheet_count()))
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
			nav_button.add_theme_stylebox_override("normal", _theme().style(_theme().theme_color("accent"), _theme().theme_color("ink")))
			nav_button.add_theme_stylebox_override("hover", _theme().style(_theme().theme_color("accent").lightened(0.12), _theme().theme_color("ink")))
			nav_button.add_theme_stylebox_override("pressed", _theme().style(_theme().theme_color("accent").darkened(0.12), _theme().theme_color("ink")))
			nav_button.add_theme_color_override("font_color", _theme().theme_color("surface"))
			nav_button.add_theme_font_size_override("font_size", _theme().ui_font_size(17))
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
	home_indicator.color = _theme().theme_color("ink")
	home_indicator.custom_minimum_size = Vector2(94, 4)
	indicator_wrap.add_child(home_indicator)


func _feed_poster_height(post_index: int) -> float:
	return float(SOCIAL_FEED_POSTER_HEIGHTS[posmod(post_index, SOCIAL_FEED_POSTER_HEIGHTS.size())])


func _feed_card_height(post_index: int) -> float:
	return _feed_poster_height(post_index) + SOCIAL_FEED_CARD_CHROME_HEIGHT


func _poster_color(post_index: int) -> Color:
	match post_index % 4:
		0:
			return _theme().theme_color("muted")
		1:
			return _theme().theme_color("surface")
		2:
			return _theme().theme_color("accent").lightened(0.46)
		_:
			return _theme().theme_color("bg").lightened(0.10)


func _scroll_feed(feed_scroll: ScrollContainer, delta: int) -> void:
	var max_scroll := int(feed_scroll.get_v_scroll_bar().max_value)
	feed_scroll.scroll_vertical = clampi(feed_scroll.scroll_vertical + delta, 0, max_scroll)


func _on_close_pressed() -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_CLOSE_REQUESTED)


func _on_channel_tab_pressed(channel_id: String) -> void:
	select_channel(channel_id)


func _on_nav_pressed(screen: String) -> void:
	show_screen(screen)


func _on_like_pressed(post_id: String) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_LIKE_PRESSED, {UiIntentsScript.KEY_POST_ID: post_id})


func _on_follow_pressed(author_id: String) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_FOLLOW_PRESSED, {UiIntentsScript.KEY_AUTHOR_ID: author_id})


func _on_card_gui_input(event: InputEvent, post_index: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		open_post(post_index)
	elif event is InputEventScreenTouch and event.pressed:
		open_post(post_index)


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


func _render_detail_page(parent: VBoxContainer) -> void:
	var detail_page := VBoxContainer.new()
	detail_page.name = "SocialPostDetailPage"
	detail_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_page.add_theme_constant_override("separation", 8)
	parent.add_child(detail_page)

	var post: Dictionary = _source.post_for_index(_detail_post_index)

	var companion_meta := HBoxContainer.new()
	companion_meta.add_theme_constant_override("separation", 8)
	detail_page.add_child(companion_meta)
	var handle_text := _source.translate(str(post.get("handle", "")))
	var companion_handle := _theme().label("@%s" % handle_text, 15, _theme().theme_color("surface")) as Label
	companion_handle.set_meta("on_dark", true)
	companion_handle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	companion_meta.add_child(companion_handle)
	var floor_marker := _theme().label("信号档案", 13, _theme().theme_color("muted")) as Label
	floor_marker.name = "SocialDetailSignalArchive"
	floor_marker.set_meta("on_dark", true)
	companion_meta.add_child(floor_marker)

	var detail_card := _theme().panel() as PanelContainer
	detail_card.name = "SocialPostDetailCard"
	detail_card.add_theme_stylebox_override("panel", _detail_dark_style())
	detail_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_page.add_child(detail_card)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 9)
	detail_card.add_child(detail_box)
	var media := PanelContainer.new()
	media.custom_minimum_size.y = 320
	media.set_meta("poster_frame", true)
	media.add_theme_stylebox_override("panel", _theme().style(_theme().theme_color("muted"), _theme().theme_color("accent")))
	detail_box.add_child(media)
	var media_texture := TextureRect.new()
	media_texture.name = "SocialDetailPostTexture"
	var poster_cell := int(post.get("poster_cell", _detail_post_index))
	media_texture.texture = _source.poster_texture(poster_cell)
	media_texture.set_meta("poster_sheet_path", _source.poster_sheet_path())
	media_texture.set_meta("poster_sheet_cell", poster_cell % maxi(1, _source.poster_sheet_count()))
	media_texture.custom_minimum_size = Vector2(300, 320)
	media_texture.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	media_texture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	media_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	media_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	media.add_child(media_texture)
	var post_body := _source.corrupt_text(str(post.get("text", "")))
	var post_text := _theme().label(post_body, 17, _theme().theme_color("surface")) as Label
	post_text.set_meta("on_dark", true)
	post_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(post_text)
	var post_card_id := str(post.get("id", ""))
	var locale := _source.current_locale()
	var pickup_line := ""
	if _source.language_material() != null:
		pickup_line = str(_source.language_material().pickup_line(post_card_id, locale))
	if not pickup_line.is_empty():
		detail_box.add_child(_make_pickup_rich_text("SocialPickupLineText", pickup_line, post_card_id))
		var pickup_hint := _theme().label("今天第一次拾字消耗一次行动；之后当天免费。", 12, _theme().theme_color("muted")) as Label
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
	var like_text := _source.like_text(post, int(post.get("card_index", _detail_post_index)), _liked)
	detail_like.text = like_text
	detail_like.custom_minimum_size = Vector2(120, 44)
	detail_like.pressed.connect(_on_like_pressed.bind(post_card_id))
	engagement.add_child(detail_like)
	var detail_follow := Button.new()
	detail_follow.name = "SocialDetailFollowButton"
	var author_id := _source.author_id(post)
	var following := _followed.has(author_id)
	detail_follow.text = "已关注" if following else "关注"
	detail_follow.custom_minimum_size = Vector2(120, 44)
	detail_follow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_follow.pressed.connect(_on_follow_pressed.bind(author_id))
	engagement.add_child(detail_follow)
	var signal_profile := _theme().label("拾取字词不增加污染；使用它才会改变语言。", 13, _theme().theme_color("muted")) as Label
	signal_profile.name = "SocialCardSignalProfile"
	signal_profile.set_meta("on_dark", true)
	signal_profile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_box.add_child(signal_profile)
	var post_comments: Array = []
	if _source.language_material() != null:
		post_comments = _source.language_material().pickup_comments(post_card_id, locale)
	if not post_comments.is_empty():
		var comments_rule := ColorRect.new()
		comments_rule.name = "SocialCommentsRule"
		comments_rule.color = Color(_theme().theme_color("muted"), 0.35)
		comments_rule.custom_minimum_size.y = 1.0
		detail_box.add_child(comments_rule)
		var comments_header := _theme().label("评论 · %d" % post_comments.size(), 14, _theme().theme_color("muted")) as Label
		comments_header.name = "SocialCommentsHeader"
		comments_header.set_meta("on_dark", true)
		detail_box.add_child(comments_header)
		for comment_index in post_comments.size():
			var comment: Dictionary = post_comments[comment_index]
			var comment_box := VBoxContainer.new()
			comment_box.name = "SocialComment%d" % comment_index
			comment_box.add_theme_constant_override("separation", 2)
			detail_box.add_child(comment_box)
			var comment_meta := _theme().label("%s  ·  %s" % [str(comment.get("handle", "")), str(comment.get("time", ""))], 12, _theme().theme_color("muted")) as Label
			comment_meta.name = "SocialCommentMeta%d" % comment_index
			comment_meta.set_meta("on_dark", true)
			comment_meta.set_meta("skip_localization", true)
			comment_box.add_child(comment_meta)
			comment_box.add_child(_make_pickup_rich_text("SocialCommentText%d" % comment_index, str(comment.get("text", "")), post_card_id))
		_render_player_echo_comment(detail_box, post_comments.size())


## 玩家投稿回流:楼里最后一条永远是陌生人在引用你写过的话,系统不作任何提示。
func _render_player_echo_comment(detail_box: VBoxContainer, comment_index: int) -> void:
	var quote := _source.player_echo_quote()
	if quote.is_empty():
		return
	var echo_box := VBoxContainer.new()
	echo_box.name = "SocialEchoComment"
	echo_box.add_theme_constant_override("separation", 2)
	detail_box.add_child(echo_box)
	var handle := _source.echo_comment_handle()
	var game_day := _source.game_day()
	var echo_meta := _theme().label("%s  ·  %02d:%02d" % [handle, 3 + comment_index, 7 + game_day], 12, _theme().theme_color("muted")) as Label
	echo_meta.name = "SocialEchoCommentMeta"
	echo_meta.set_meta("on_dark", true)
	echo_meta.set_meta("skip_localization", true)
	echo_box.add_child(echo_meta)
	var echo_text := _theme().label(quote, 14, _theme().theme_color("surface")) as Label
	echo_text.name = "SocialEchoCommentText"
	echo_text.set_meta("on_dark", true)
	echo_text.set_meta("skip_localization", true)
	echo_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	echo_box.add_child(echo_text)


## Shutting the tower base post leaves its channel too.
func _on_detail_close_pressed() -> void:
	close_detail()
	if _channel == TOWER_BASE_CHANNEL:
		_channel = DEFAULT_CHANNEL
		_repaint_page()
	else:
		render_companion()
	GameEventBus.raise(UiIntentsScript.SOCIAL_DETAIL_CLOSE_REQUESTED)


func _open_detail(post_index: int) -> void:
	_detail_post_index = post_index
	if _detail_window != null:
		_detail_window.move_to_front()
	_show_detail_window()


func _show_detail_window() -> void:
	if _detail_window != null:
		_detail_window.visible = _app_shown and is_detail_open()


## A page that was never drawn is left to the host, like the model repaints. Says whether it repainted.
func _repaint_page() -> bool:
	if not _rendered:
		return false
	render_app()
	render_companion()
	return true


func _render_profile_page(parent: VBoxContainer) -> void:
	var profile_page := VBoxContainer.new()
	profile_page.name = "SocialProfilePage"
	profile_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	profile_page.add_theme_constant_override("separation", 10)
	parent.add_child(profile_page)
	profile_page.add_child(_theme().label("我的", 22, _theme().theme_color("accent")) as Label)
	var identity_frame := PanelContainer.new()
	identity_frame.name = "SocialPlayerIdentityFrame"
	identity_frame.custom_minimum_size.y = 188
	identity_frame.set_meta("poster_frame", true)
	identity_frame.add_theme_stylebox_override("panel", _theme().style(_theme().theme_color("ink"), _theme().theme_color("accent")))
	profile_page.add_child(identity_frame)
	var identity_portrait := TextureRect.new()
	identity_portrait.name = "SocialPlayerIdentityPortrait"
	identity_portrait.texture = _source.load_texture(_source.player_character_path())
	identity_portrait.set_meta("asset_path", _source.player_character_path())
	identity_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	identity_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	identity_frame.add_child(identity_portrait)
	var completed_count := _completed_memes.size()
	var pollution := _source.pollution()
	profile_page.add_child(_theme().label("已合成梗：%d" % completed_count, 17, _theme().theme_color("ink")) as Label)
	profile_page.add_child(_theme().label("污染：%d%%" % pollution, 17, _theme().theme_color("ink")) as Label)
	var note := _theme().label("你的语言档案会随着塔层上升变窄。", 16, _theme().theme_color("accent")) as Label
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	profile_page.add_child(note)


func _social_feed_dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme().theme_color("ink")
	style.border_color = Color(_theme().theme_color("muted"), 0.18)
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(6)
	return style


func _social_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme().theme_color("surface")
	style.border_color = Color(_theme().theme_color("muted"), 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	return style


func _detail_dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme().theme_color("ink")
	style.border_color = _theme().theme_color("ink")
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
	rich.add_theme_font_size_override("normal_font_size", _theme().ui_font_size(16))
	rich.add_theme_color_override("default_color", _theme().theme_color("surface"))
	rich.set_meta("on_dark", true)
	var bbcode := source_text
	if _source.language_material() != null:
		var pickable_color = _theme().theme_color("flash_text") if _theme() != null else Color("9cff24")
		var locale := _source.current_locale()
		bbcode = LanguageMaterialScript.pickup_bbcode(
			source_text,
			locale,
			MemeGameStateScript.char_units_for_locale(_held_chars, locale),
			(pickable_color as Color).to_html(false)
		)
	rich.text = bbcode
	rich.meta_clicked.connect(_on_pickup_meta_clicked.bind(post_id))
	return rich


func _on_pickup_meta_clicked(meta: Variant, post_id: String) -> void:
	GameEventBus.raise(UiIntentsScript.SOCIAL_PICKUP_UNIT_CLICKED, {UiIntentsScript.KEY_META: meta, UiIntentsScript.KEY_POST_ID: post_id})


func _on_followed(value: Variant) -> void:
	_followed = value as Array
	_repaint_unless_syncing()


func _on_liked(value: Variant) -> void:
	_liked = value as Array
	_repaint_unless_syncing()


func _on_held_chars(value: Variant) -> void:
	_held_chars = value as Array
	_repaint_unless_syncing()


func _on_completed_memes(value: Variant) -> void:
	_completed_memes = value as Array
	_repaint_unless_syncing()


func _on_published(value: Variant) -> void:
	_published = value as Array
	_repaint_unless_syncing()


func _repaint_unless_syncing() -> void:
	if not _watch.is_syncing():
		_repaint_if_stale()


## A page that was never drawn is left to the host; a page that shows these lists already needs nothing.
## Held words and published records (the echo under a post) mark the post detail only,
## and finished memes show on the profile page only. The publish panel repaints its own page.
func _repaint_if_stale() -> void:
	if not _rendered:
		return
	var profile_stale := _screen == "profile" and _completed_memes != _painted_memes
	var feed_stale := _followed != _painted_followed or _liked != _painted_liked or profile_stale
	if feed_stale:
		render_app()
		_theme_window(_app_window)
	if feed_stale or _held_chars != _painted_held_chars or _published != _painted_published:
		render_companion()
		_theme_window(_detail_window)


func _theme_window(window: Control) -> void:
	if window == null or not is_instance_valid(window):
		return
	_theme().apply_ui_theme(window)
	_theme().localize_control_tree(window)


func _clear(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()


## The UI theme bound by the host; panels resolve it instead of taking theme callables.
func _theme() -> GameUiTheme:
	return ServiceRegistryScript.resolve(ServiceKeysScript.UI_THEME) as GameUiTheme


## Hands a window's title handle to the bound window manager, so the player can drag that window.
func _register_drag_handle(window: Control, window_id: String, handle: Control) -> void:
	if not ServiceRegistryScript.has(ServiceKeysScript.WINDOW_MANAGER):
		return
	(ServiceRegistryScript.resolve(ServiceKeysScript.WINDOW_MANAGER) as DraggableWindowManager).register(window, window_id, handle)
