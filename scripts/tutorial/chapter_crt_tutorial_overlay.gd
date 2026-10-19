extends Control
## A genuine input shield: highlighted rectangles are holes in hit testing.

const REFERENCE_SIZE := Vector2(1600, 1200)
# These areas contain no app text: the empty lower half of the unused answer
# area, the dimmed post image, and the empty top of the inactive word tray.
# Keep the compose guide entirely left of the right-hand drag/drop workspace.
const CAPTION_AREAS := {
	"post": Rect2(850, 350, 690, 224),
	"collect": Rect2(850, 350, 690, 224),
	"compose": Rect2(50, 236, 700, 290),
	"publish": Rect2(1298, 850, 268, 270),
}
const CAPTION_PADDING := 14.0

var holes: Array[Rect2] = []
var caption := ""
var caption_safe_rect := Rect2()
var _phase := "post"
var _laid_out_text := ""
var _laid_out_rect := Rect2()
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
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.add_theme_font_size_override("font_size", 64)
	_label.add_theme_color_override("font_color", Color("e5f5cf"))
	_label.add_theme_color_override("font_outline_color", Color(0.015, 0.02, 0.015, 0.95))
	_label.add_theme_constant_override("outline_size", 12)
	add_child(_label)
	resized.connect(_layout_caption)

func present(rectangles: Array[Rect2], text: String, phase: String) -> void:
	holes = rectangles
	caption = text
	_phase = phase
	_label.text = text
	_layout_caption()
	queue_redraw()

func _layout_caption() -> void:
	if not is_instance_valid(_label) or size.x <= 0.0 or size.y <= 0.0:
		return
	var reference: Rect2 = CAPTION_AREAS.get(_phase, CAPTION_AREAS.post)
	var scale_factor := size / REFERENCE_SIZE
	caption_safe_rect = Rect2(reference.position * scale_factor, reference.size * scale_factor)
	if _laid_out_text == caption and _laid_out_rect == caption_safe_rect:
		return
	_laid_out_text = caption
	_laid_out_rect = caption_safe_rect
	# The entire label plus its 12px outline must fit the safe area, including
	# translated wrapping. Adapt only when a translation needs the extra room.
	var inner := caption_safe_rect.grow(-CAPTION_PADDING)
	_label.size = Vector2(inner.size.x, 0.0)
	var font_size := 64
	_label.add_theme_font_size_override("font_size", font_size)
	while font_size > 48 and (_label.get_minimum_size().y > inner.size.y or (_phase == "publish" and _label.get_line_count() > 2)):
		font_size -= 2
		_label.add_theme_font_size_override("font_size", font_size)
	_label.size = Vector2(inner.size.x, _label.get_minimum_size().y)
	_label.position = Vector2(inner.position.x, inner.get_center().y - _label.size.y * 0.5)

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
