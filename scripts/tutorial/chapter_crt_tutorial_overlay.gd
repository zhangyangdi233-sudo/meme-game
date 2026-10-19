extends Control
## A genuine input shield: highlighted rectangles are holes in hit testing.

var holes: Array[Rect2] = []
var caption := ""
var _label: Label

func _ready() -> void:
	name = "CRTTutorialOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 120
	mouse_filter = Control.MOUSE_FILTER_STOP
	_label = Label.new()
	_label.name = "CRTTutorialInstruction"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_meta("skip_localization", true)
	_label.set_meta("on_dark", true)
	_label.position = Vector2(24, 1166)
	_label.size = Vector2(1552, 32)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 24)
	_label.add_theme_color_override("font_color", Color("e5f5cf"))
	add_child(_label)

func present(rectangles: Array[Rect2], text: String) -> void:
	holes = rectangles
	caption = text
	_label.text = text
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	for rect in holes:
		if rect.has_point(point):
			return false
	return Rect2(Vector2.ZERO, size).has_point(point)

func _draw() -> void:
	var xs: Array[float] = [0.0, size.x]
	var ys: Array[float] = [0.0, size.y]
	for hole in holes:
		xs.append(clampf(hole.position.x, 0, size.x))
		xs.append(clampf(hole.end.x, 0, size.x))
		ys.append(clampf(hole.position.y, 0, size.y))
		ys.append(clampf(hole.end.y, 0, size.y))
	xs.sort()
	ys.sort()
	for x in xs.size() - 1:
		for y in ys.size() - 1:
			var rect := Rect2(Vector2(xs[x], ys[y]), Vector2(xs[x + 1] - xs[x], ys[y + 1] - ys[y]))
			if _has_point(rect.get_center()):
				draw_rect(rect, Color(0.02, 0.025, 0.02, 0.80))
	for hole in holes:
		draw_rect(hole.grow(2.0), Color("d7f5a6"), false, 3.0)
