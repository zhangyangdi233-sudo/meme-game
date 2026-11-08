class_name DropButton
extends Button

signal dropped(data: Dictionary, target_id: String)

var accepted_kind: String = ""
var target_id: String = ""


func configure_drop_target(kind: String, id: String) -> void:
	accepted_kind = kind
	target_id = id
	tooltip_text = "可投放：%s" % kind


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return str(data.get("kind", "")) == accepted_kind


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	dropped.emit(data, target_id)
