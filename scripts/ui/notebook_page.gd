extends Control
## A fixed notebook page. The sentence tray and publishing controls remain
## above the physics bank; neither section contributes an oversized minimum.

var _layout_pending := false

func _ready() -> void:
	clip_contents = true
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_queue_layout)
	theme_changed.connect(_queue_layout)
	_queue_layout()

func _queue_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	_layout_page.call_deferred()

func _layout_page() -> void:
	_layout_pending = false
	if not is_inside_tree() or size.x <= 0 or size.y <= 0:
		return
	var width := size.x
	var height := size.y
	var enlarged := width > 600.0
	var unit := 1.5 if enlarged else 1.0
	var y := 0.0
	_place("NotebookSentenceHeader", Rect2(0, y, width, 25 * unit))
	y += 29 * unit
	_place("NotebookSentenceHint", Rect2(0, y, width, 34 * unit))
	y += 40 * unit
	var tray_height := minf(132 * unit, height * 0.21)
	_place("ComposerAnswerPanel", Rect2(0, y, width, tray_height))
	y += tray_height + 5 * unit
	var preview_height := minf(74 * unit, height * 0.12)
	_place("ComposerPreviewLabel", Rect2(0, y, width, preview_height))
	y += preview_height + 6 * unit
	_place("NotebookCraftButton", Rect2(0, y, width, 44 * unit))
	y += 49 * unit
	_place("NotebookPublishFeedback", Rect2(0, y, width, 30 * unit))
	y += 34 * unit
	var rules := get_node_or_null("ComposerRulesList") as Control
	if rules != null:
		_place("ComposerRulesList", Rect2(0, y, width, 30 * unit))
		y += 34 * unit
	_place("NotebookBankLabel", Rect2(0, y, width, 24 * unit))
	y += 29 * unit
	_place("NotebookCanvasFrame", Rect2(0, y, width, maxf(1, height - y)))
	_fit_label(get_node_or_null("NotebookSentenceHint") as Label, 14 if not enlarged else 23)
	_fit_label(get_node_or_null("ComposerPreviewLabel") as Label, 21 if not enlarged else 32)
	_fit_label(get_node_or_null("NotebookPublishFeedback") as Label, 13 if not enlarged else 20)
	if rules != null:
		_fit_label(rules.get_child(0) as Label, 12 if not enlarged else 18)
	# PanelContainer resolves its style margins after this parent layout.
	_fit_sentence.call_deferred()

func _place(node_name: String, rect: Rect2) -> void:
	var control := get_node_or_null(node_name) as Control
	if control == null:
		return
	control.position = rect.position
	control.size = rect.size

func _fit_label(label: Label, maximum_font: int) -> void:
	if label == null:
		return
	for font_size in range(maximum_font, 7, -1):
		label.add_theme_font_size_override("font_size", font_size)
		if label.get_line_count() * label.get_line_height() <= label.size.y + 1:
			break

func _fit_sentence() -> void:
	var panel := get_node_or_null("ComposerAnswerPanel") as Control
	if panel == null:
		return
	var flow := panel.get_node_or_null("ComposerAnswerFlow") as Control
	if flow == null or flow.size.x <= 0 or flow.size.y <= 0:
		return
	var tiles: Array[Control] = []
	for child in flow.get_children():
		if child is Button:
			tiles.append(child)
	if tiles.is_empty():
		var placeholder := flow.get_node_or_null("ComposerAnswerPlaceholder") as Label
		if placeholder != null:
			placeholder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	var factor := 1.0
	var points: Array[Vector2] = []
	for attempt in 60:
		points.clear()
		var available_width := flow.size.x / factor
		var cursor := Vector2.ZERO
		var row_height := 0.0
		for tile in tiles:
			var tile_size := tile.get_combined_minimum_size().max(Vector2(44, 40))
			tile.size = tile_size
			if cursor.x > 0 and cursor.x + tile_size.x > available_width:
				cursor = Vector2(0, cursor.y + row_height + 5)
				row_height = 0
			points.append(cursor)
			cursor.x += tile_size.x + 5
			row_height = maxf(row_height, tile_size.y)
		if (cursor.y + row_height) * factor <= flow.size.y and tiles.all(func(tile: Control): return tile.size.x * factor <= flow.size.x):
			break
		factor *= 0.9
	for index in tiles.size():
		tiles[index].position = points[index] * factor
		tiles[index].scale = Vector2.ONE * factor
