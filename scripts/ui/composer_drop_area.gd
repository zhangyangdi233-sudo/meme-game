class_name ComposerDropArea
extends PanelContainer
## 造句台答案区面板:接住拖到空白处的词库瓦片(追加到句尾)与答案瓦片(移到句尾)。

signal unit_dropped(data: Dictionary)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return str((data as Dictionary).get("kind", "")) in ["composer_unit", "composer_reorder"]


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(_at_position, data):
		return
	unit_dropped.emit(data as Dictionary)
