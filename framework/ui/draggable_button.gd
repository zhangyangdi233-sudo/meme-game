class_name DraggableButton
extends Button

var drag_kind: String = ""
var drag_id: String = ""
var drag_label: String = ""


func set_drag_payload(kind: String, id: String, label: String) -> void:
	drag_kind = kind
	drag_id = id
	drag_label = label
	tooltip_text = "拖动：%s" % label


func _get_drag_data(_at_position: Vector2) -> Variant:
	if drag_kind.is_empty() or drag_id.is_empty():
		return null
	if is_inside_tree():
		var preview := Label.new()
		preview.text = drag_label
		preview.add_theme_font_size_override("font_size", 16)
		preview.add_theme_color_override("font_color", Color("365B2D"))
		set_drag_preview(preview)
	return {
		"kind": drag_kind,
		"id": drag_id,
		"label": drag_label,
	}
