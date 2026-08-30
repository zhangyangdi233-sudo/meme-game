class_name MemeBankPanel
extends Node
## Game-side meme bank shell: popup chrome, radial ring host, drag handle, and layout modes.

signal tab_pressed
signal selection_changed(index: int)
signal meme_pressed(meme_id: String)

const RadialSelectorRingScript = preload("res://framework/ui/radial_selector_ring.gd")
const DraggableButtonScript = preload("res://framework/ui/draggable_button.gd")

var _window: Control
var _ring: Control
var _tab: Button
var _drag_handle: Label
var _content: Control
var _focus_label: Label

var _label_factory: Callable
var _theme_color_fn: Callable
var _register_draggable: Callable
var _viewport_size_fn: Callable
var _clear_children_fn: Callable
var _corrupt_text_fn: Callable

var _selected_index := 0
var _last_completed_memes: Array = []
var _last_publish_state: Dictionary = {}


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_popup(parent)


func get_popup() -> Control:
	return _window


func get_ring() -> Control:
	return _ring


func get_tab() -> Button:
	return _tab


func get_content() -> Control:
	return _content


func get_focus_label() -> Label:
	return _focus_label


func get_drag_handle() -> Label:
	return _drag_handle


func get_bank_list() -> Control:
	return _ring


func move_to_front() -> void:
	if _window != null and is_instance_valid(_window):
		_window.move_to_front()


func layout_popup(mode: String) -> void:
	if _window == null:
		return
	if not _viewport_size_fn.is_valid():
		return
	var viewport_size: Vector2 = _viewport_size_fn.call()
	if mode == "open":
		_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		var ring_size := minf(680.0, maxf(430.0, minf(viewport_size.x * 0.48, viewport_size.y - 54.0)))
		_window.offset_left = -ring_size
		_window.offset_top = -ring_size * 0.5
		_window.offset_right = 18.0
		_window.offset_bottom = ring_size * 0.5
	elif mode == "collapsed":
		_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_window.offset_left = -144.0
		_window.offset_top = -66.0
		_window.offset_right = -12.0
		_window.offset_bottom = 66.0
	else:
		_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_window.offset_left = -1.0
		_window.offset_top = -1.0
		_window.offset_right = 0.0
		_window.offset_bottom = 0.0


func render(state: Dictionary) -> void:
	if _tab == null or _ring == null:
		return
	var completed_memes: Array = state.get("completed_memes", [])
	var theme_colors: Dictionary = state.get("theme_colors", {})
	var surface := theme_colors.get("surface", _theme_color_fn.call("surface")) as Color
	var muted := theme_colors.get("muted", _theme_color_fn.call("muted")) as Color
	var accent := theme_colors.get("accent", _theme_color_fn.call("accent")) as Color
	var meme_bank_open := bool(state.get("meme_bank_open", false))
	var should_show_meme_bank := bool(state.get("should_show_meme_bank", false))
	_render_tab_chrome(meme_bank_open, should_show_meme_bank, completed_memes.size())
	_ring.set_palette(surface, Color(muted, 0.88), accent)
	if _clear_children_fn.is_valid():
		_clear_children_fn.call(_ring)
	if completed_memes.is_empty():
		if _focus_label != null:
			_focus_label.text = "还没有完整梗。"
		_last_completed_memes = []
		_last_publish_state = {
			"publish_blank": state.get("publish_blank"),
			"confirm_publish_button": state.get("confirm_publish_button"),
			"placed_meme": state.get("placed_meme", {}),
			"can_spend_action": state.get("can_spend_action", false),
		}
		_render_publish_controls(_last_publish_state)
		return
	_selected_index = clampi(int(state.get("selected_index", _selected_index)), 0, completed_memes.size() - 1)
	var selected_meme_id := str(state.get("selected_meme_id", ""))
	if not selected_meme_id.is_empty():
		for index in completed_memes.size():
			if str((completed_memes[index] as Dictionary).get("id", "")) == selected_meme_id:
				_selected_index = index
				break
	for index in completed_memes.size():
		var meme: Dictionary = completed_memes[index] as Dictionary
		var meme_id := str(meme.get("id", index))
		var btn = DraggableButtonScript.new()
		btn.name = "MemeRingItem_%s" % meme_id
		btn.set_meta("radial_meme_item", true)
		btn.set_meta("meme_index", index)
		btn.custom_minimum_size = Vector2(134, 54)
		var display_text := str(meme.get("text", ""))
		if _corrupt_text_fn.is_valid():
			display_text = str(_corrupt_text_fn.call(display_text))
		btn.text = "%s\n%s" % [meme.get("title", ""), display_text]
		btn.set_drag_payload("meme", meme_id, str(meme.get("title", "")))
		btn.pressed.connect(_on_meme_item_pressed.bind(meme_id))
		btn.gui_input.connect(_on_meme_ring_item_gui_input.bind(btn))
		_ring.add_child(btn)
	_ring.set_selected_index(_selected_index)
	_update_focus_label(completed_memes)
	_last_completed_memes = completed_memes
	_last_publish_state = {
		"publish_blank": state.get("publish_blank"),
		"confirm_publish_button": state.get("confirm_publish_button"),
		"placed_meme": state.get("placed_meme", {}),
		"can_spend_action": state.get("can_spend_action", false),
	}
	_render_publish_controls(_last_publish_state)


func update_open_parts_visible(show_meme_bank: bool, is_open: bool) -> void:
	var show_open_parts := show_meme_bank and is_open
	if _content != null:
		_content.visible = show_open_parts
	if _ring != null:
		_ring.visible = show_open_parts
	if _drag_handle != null:
		_drag_handle.visible = show_open_parts


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_register_draggable = deps.get("register_draggable", Callable())
	_viewport_size_fn = deps.get("viewport_size", Callable())
	_clear_children_fn = deps.get("clear_children", Callable())
	_corrupt_text_fn = deps.get("corrupt_text", Callable())


func _build_popup(parent: Control) -> void:
	if _window != null and is_instance_valid(_window):
		return
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return

	_window = Control.new()
	_window.name = "MemeBankPopup"
	_window.set_meta("meme_bank_popup", true)
	_window.set_meta("radial_meme_bank", true)
	_window.mouse_filter = Control.MOUSE_FILTER_PASS
	_window.z_index = 18
	parent.add_child(_window)
	layout_popup("peek")

	_ring = RadialSelectorRingScript.new()
	_ring.name = "MemeBankRadialRing"
	_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ring.set_palette(_theme_color_fn.call("surface"), Color(_theme_color_fn.call("muted"), 0.88), _theme_color_fn.call("accent"))
	_ring.selection_changed.connect(_on_ring_selection_changed)
	_window.add_child(_ring)

	_tab = Button.new()
	_tab.name = "MemeBankTab"
	_tab.text = "梗"
	_tab.set_meta("meme_bank_tab", true)
	_tab.set_meta("radial_center_button", true)
	_tab.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_tab.offset_left = -142.0
	_tab.offset_top = -58.0
	_tab.offset_right = -22.0
	_tab.offset_bottom = 58.0
	_tab.custom_minimum_size = Vector2(120, 116)
	_tab.pressed.connect(_on_tab_pressed)
	_window.add_child(_tab)

	_drag_handle = _label_factory.call("≡", 24, _theme_color_fn.call("accent")) as Label
	_drag_handle.name = "MemeBankDragHandle"
	_drag_handle.tooltip_text = "拖动梗仓库"
	_drag_handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_drag_handle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_drag_handle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_drag_handle.offset_left = -70.0
	_drag_handle.offset_top = 14.0
	_drag_handle.offset_right = -26.0
	_drag_handle.offset_bottom = 58.0
	_drag_handle.custom_minimum_size = Vector2(44, 44)
	_window.add_child(_drag_handle)
	if _register_draggable.is_valid():
		_register_draggable.call(_window, "bank", _drag_handle)

	_content = Control.new()
	_content.name = "MemeBankContent"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_window.add_child(_content)

	_focus_label = _label_factory.call("还没有完整梗", 16, _theme_color_fn.call("accent")) as Label
	_focus_label.name = "MemeBankFocusLabel"
	_focus_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_focus_label.offset_left = 24.0
	_focus_label.offset_top = -92.0
	_focus_label.offset_right = 286.0
	_focus_label.offset_bottom = -26.0
	_focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_focus_label.max_lines_visible = 1
	_focus_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_focus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(_focus_label)


func _render_tab_chrome(meme_bank_open: bool, should_show_meme_bank: bool, completed_count: int) -> void:
	if _tab == null:
		return
	if meme_bank_open:
		_tab.text = "×"
		_tab.set_meta("meme_bank_peek", false)
		_tab.custom_minimum_size = Vector2(88, 88)
	elif should_show_meme_bank:
		_tab.text = "梗 %d" % completed_count
		_tab.set_meta("meme_bank_peek", false)
		_tab.custom_minimum_size = Vector2(104, 88)
	else:
		_tab.text = ""
		_tab.set_meta("meme_bank_peek", true)
		_tab.custom_minimum_size = Vector2.ZERO


func _render_publish_controls(state: Dictionary) -> void:
	var publish_blank: Control = state.get("publish_blank") as Control
	var confirm_publish_button: Button = state.get("confirm_publish_button") as Button
	var placed_meme: Dictionary = state.get("placed_meme", {}) as Dictionary
	if publish_blank != null:
		var title := "等待完整梗"
		if not placed_meme.is_empty():
			title = str(placed_meme.get("title", "等待完整梗"))
		publish_blank.text = "发布空格：%s" % title
	if confirm_publish_button != null:
		confirm_publish_button.disabled = placed_meme.is_empty() or not bool(state.get("can_spend_action", false))


func _update_focus_label(completed_memes: Array) -> void:
	if _focus_label == null or completed_memes.is_empty():
		return
	_selected_index = clampi(_selected_index, 0, completed_memes.size() - 1)
	var meme: Dictionary = completed_memes[_selected_index] as Dictionary
	_focus_label.text = "%d/%d  ·  %s" % [
		_selected_index + 1,
		completed_memes.size(),
		str(meme.get("title", meme.get("text", "完整梗"))),
	]


func _on_tab_pressed() -> void:
	tab_pressed.emit()


func _on_meme_item_pressed(meme_id: String) -> void:
	meme_pressed.emit(meme_id)


func _on_meme_ring_item_gui_input(event: InputEvent, source_button: Control) -> void:
	if _ring != null and _ring.handle_navigation_event(event):
		source_button.accept_event()


func _on_ring_selection_changed(index: int) -> void:
	_selected_index = index
	if not _last_completed_memes.is_empty():
		_update_focus_label(_last_completed_memes)
	selection_changed.emit(index)
