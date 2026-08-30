class_name DollGuidePanel
extends Node
## Persistent bottom-left guide window for the stitched doll tutorial and floor tasks.

var _overlay: PanelContainer
var _body: VBoxContainer
var _line_label: Label

var _label_factory: Callable
var _theme_color_fn: Callable
var _load_texture_fn: Callable
var _register_draggable_fn: Callable
var _portrait_path := ""


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)


func get_overlay() -> PanelContainer:
	return _overlay


func toggle_collapsed() -> void:
	if _body == null or _overlay == null or not is_instance_valid(_overlay) or not is_instance_valid(_body):
		return
	_body.visible = not _body.visible
	var collapse_button := _find_control_by_name(_overlay, "DollGuideCollapseButton") as Button
	if collapse_button != null:
		collapse_button.text = "折叠" if _body.visible else "展开"


func refresh(should_show: bool, line_text: String = "") -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	_overlay.visible = should_show
	if not should_show or _line_label == null or not is_instance_valid(_line_label):
		return
	_line_label.text = line_text


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_load_texture_fn = deps.get("load_texture", Callable())
	_register_draggable_fn = deps.get("register_draggable", Callable())
	_portrait_path = str(deps.get("portrait_path", ""))


func _build_overlay(parent: Control) -> void:
	_overlay = PanelContainer.new()
	_overlay.name = "DollGuideOverlay"
	# 低于设置窗(30)与各弹层;高于普通应用窗口。
	_overlay.z_index = 25
	_overlay.custom_minimum_size = Vector2(252, 0)
	parent.add_child(_overlay)

	var guide_box := VBoxContainer.new()
	guide_box.add_theme_constant_override("separation", 4)
	_overlay.add_child(guide_box)

	var header := HBoxContainer.new()
	header.name = "DollGuideHeader"
	header.add_theme_constant_override("separation", 6)
	guide_box.add_child(header)

	var portrait := TextureRect.new()
	portrait.name = "DollGuidePortrait"
	if _load_texture_fn.is_valid() and not _portrait_path.is_empty():
		portrait.texture = _load_texture_fn.call(_portrait_path)
	portrait.custom_minimum_size = Vector2(52, 52)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)

	var title: Label = _label_factory.call("缝线布偶", 15, _theme_color_fn.call("accent")) if _label_factory.is_valid() else Label.new()
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var collapse := Button.new()
	collapse.name = "DollGuideCollapseButton"
	collapse.text = "折叠"
	collapse.custom_minimum_size = Vector2(58, 34)
	collapse.focus_mode = Control.FOCUS_NONE
	collapse.pressed.connect(toggle_collapsed)
	header.add_child(collapse)

	_body = VBoxContainer.new()
	_body.name = "DollGuideBody"
	guide_box.add_child(_body)

	_line_label = _label_factory.call("", 14, _theme_color_fn.call("ink")) if _label_factory.is_valid() else Label.new()
	_line_label.name = "DollGuideLine"
	_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_line_label.custom_minimum_size = Vector2(236, 0)
	_body.add_child(_line_label)

	# 常驻画面左下角:玩家视觉的余光位置,不挡中心视野。
	_overlay.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	_overlay.offset_left = 16.0
	_overlay.offset_bottom = -16.0
	_overlay.grow_vertical = Control.GROW_DIRECTION_BEGIN
	if _register_draggable_fn.is_valid():
		_register_draggable_fn.call(_overlay, "doll_guide", header)
	# 玩偶从头到尾在玩家视线内:没有关闭按钮,只能折叠或拖动。
	_overlay.visible = false


func _find_control_by_name(root: Node, target_name: String) -> Node:
	if root == null:
		return null
	if root.name == target_name:
		return root
	for child in root.get_children():
		var found := _find_control_by_name(child, target_name)
		if found != null:
			return found
	return null
