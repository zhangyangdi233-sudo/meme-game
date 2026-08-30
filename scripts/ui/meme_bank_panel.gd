class_name MemeBankPanel
extends Node
## Game-side meme bank shell: popup chrome, radial ring host, drag handle, and layout modes.

signal tab_pressed
signal selection_changed(index: int)

const RadialSelectorRingScript = preload("res://framework/ui/radial_selector_ring.gd")

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


func _on_tab_pressed() -> void:
	tab_pressed.emit()


func _on_ring_selection_changed(index: int) -> void:
	selection_changed.emit(index)
