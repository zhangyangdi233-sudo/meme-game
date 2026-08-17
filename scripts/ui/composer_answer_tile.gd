class_name ComposerAnswerTile
extends DraggableButton
## 造句台答案区瓦片:既是拖拽源(重排),也是投放目标(插到本瓦片之前)。

signal unit_dropped_before(data: Dictionary, before_index: int)

var answer_index: int = -1


func configure_answer_tile(index: int, unit: String) -> void:
	answer_index = index
	set_drag_payload("composer_reorder", str(index), unit)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return str((data as Dictionary).get("kind", "")) in ["composer_unit", "composer_reorder"]


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	unit_dropped_before.emit(data as Dictionary, answer_index)
