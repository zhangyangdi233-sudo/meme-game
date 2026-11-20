class_name CrtLessonOverlay
extends Control
## Round one's CRT lesson drawn on the terminal's own display, above its apps (the old version's
## `chapter_crt_tutorial_overlay.gd`, restored by the planner on 2026-11-16): everything is dimmed but one or two
## highlighted rectangles, the holes, which alone take the pointer; one large caption stands in a fixed safe area of the
## step. It is static: it redraws only when the panel presents a step. The old numbers were for a 1600x1200 display;
## this one is 960x720, so they are scaled by 0.6 and the font sizes kept to multiples of 9 (the terminal's pixel font).

const DIM_COLOR := Color(0.02, 0.025, 0.02, 0.80)
const OUTLINE_COLOR := Color("d7f5a6")
const OUTLINE_WIDTH := 2.0
const OUTLINE_GROW := 1.0
const CAPTION_COLOR := Color("e5f5cf")
const CAPTION_OUTLINE_COLOR := Color(0.015, 0.02, 0.015, 0.95)
const CAPTION_OUTLINE_SIZE := 7
## The caption shrinks from the first size to the last while it is taller than its area (the old 64 to 48).
const CAPTION_FONT_SIZES: Array[int] = [36, 27]
const CAPTION_PADDING := 8.0
## Where each step's caption stands on the 960x720 display, clear of that step's holes: right of the feed while a post
## is to be opened, over the dimmed feed while the post beside it is read, in the middle under the tabs, right of the
## word canvas, and above the post button. The old areas' sizes scaled by 0.6; their places follow this terminal's
## layout (the feed and the open post side by side, the notebook alone).
const CAPTION_AREAS := {
	"post": Rect2(510, 300, 414, 134),
	"collect": Rect2(36, 300, 414, 134),
	"notebook": Rect2(273, 300, 414, 134),
	"compose": Rect2(556, 300, 380, 174),
	"publish": Rect2(556, 420, 380, 162),
}
## The publish caption keeps to two lines, as the old one did.
const CAPTION_MAX_LINES := {"publish": 2}

var _holes: Array[Rect2] = []
var _step := ""
var _caption: Label


func _init() -> void:
	name = "CrtLessonOverlay"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 120
	_caption = Label.new()
	_caption.name = "CrtLessonCaption"
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_color_override("font_color", CAPTION_COLOR)
	_caption.add_theme_color_override("font_outline_color", CAPTION_OUTLINE_COLOR)
	_caption.add_theme_constant_override("outline_size", CAPTION_OUTLINE_SIZE)
	# The caption comes from the catalog in the chosen language already.
	_caption.set_meta("skip_localization", true)
	_caption.set_meta("on_dark", true)
	add_child(_caption)


## Shows a step: its holes in this overlay's own coordinates and its caption. Redraws only when something changed.
func present(step: String, holes: Array[Rect2], caption: String) -> void:
	if step == _step and holes == _holes and caption == _caption.text:
		return
	_step = step
	_holes = holes.duplicate()
	_caption.text = caption
	_fit_caption()
	queue_redraw()


func holes() -> Array[Rect2]:
	return _holes.duplicate()


func caption_text() -> String:
	return _caption.text


## The holes let the pointer through to the controls under them; everywhere else the overlay takes it.
func _has_point(point: Vector2) -> bool:
	for hole in _holes:
		if hole.has_point(point):
			return false
	return Rect2(Vector2.ZERO, size).has_point(point)


## Dims every cell of the grid the holes' edges make that lies outside every hole, then outlines each hole.
func _draw() -> void:
	var xs: Array[float] = [0.0, size.x]
	var ys: Array[float] = [0.0, size.y]
	for hole in _holes:
		xs.append_array([clampf(hole.position.x, 0.0, size.x), clampf(hole.end.x, 0.0, size.x)])
		ys.append_array([clampf(hole.position.y, 0.0, size.y), clampf(hole.end.y, 0.0, size.y)])
	xs.sort()
	ys.sort()
	for column in xs.size() - 1:
		for row in ys.size() - 1:
			var cell := Rect2(xs[column], ys[row], xs[column + 1] - xs[column], ys[row + 1] - ys[row])
			if cell.size.x <= 0.0 or cell.size.y <= 0.0:
				continue
			var inside := false
			for hole in _holes:
				if hole.has_point(cell.get_center()):
					inside = true
					break
			if not inside:
				draw_rect(cell, DIM_COLOR)
	for hole in _holes:
		draw_rect(hole.grow(OUTLINE_GROW), OUTLINE_COLOR, false, OUTLINE_WIDTH)


## Shrinks the caption in steps of the pixel font's size until it fits its step's area, then centres it there.
func _fit_caption() -> void:
	var area: Rect2 = CAPTION_AREAS.get(_step, Rect2(273, 300, 414, 134))
	var inner := area.grow(-CAPTION_PADDING)
	var font := _caption.get_theme_font("font")
	var chosen := CAPTION_FONT_SIZES[CAPTION_FONT_SIZES.size() - 1]
	for font_size in CAPTION_FONT_SIZES:
		var text_size := font.get_multiline_string_size(_caption.text, HORIZONTAL_ALIGNMENT_CENTER, inner.size.x, font_size)
		var lines := _caption.text.split("\n").size()
		var max_lines := int(CAPTION_MAX_LINES.get(_step, 0))
		if text_size.y <= inner.size.y and (max_lines == 0 or lines <= max_lines):
			chosen = font_size
			break
	_caption.add_theme_font_size_override("font_size", chosen)
	_caption.position = inner.position
	_caption.size = inner.size
