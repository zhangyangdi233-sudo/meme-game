class_name HoldRing
extends Control
## A pale gray ring that fills white clockwise from twelve o'clock; `progress` 1 is a full ring.
## Draws centered in its own rect. Fixed colors, not palette roles: the ticket asks for gray and white.

const TRACK_COLOR := Color("c8c8c8")
const FILL_COLOR := Color.WHITE
const LINE_WIDTH := 6.0
const ARC_POINTS := 64

var progress := 0.0:
	set(value):
		progress = clampf(value, 0.0, 1.0)
		queue_redraw()


## Start and end angles of the white arc. Screen y points down, so the growing end angle turns clockwise.
static func fill_arc(fraction: float) -> Vector2:
	var start := -PI / 2.0
	return Vector2(start, start + TAU * clampf(fraction, 0.0, 1.0))


func center_at(point: Vector2) -> void:
	global_position = point - size * 0.5


func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - LINE_WIDTH * 0.5
	draw_arc(center, radius, 0.0, TAU, ARC_POINTS, TRACK_COLOR, LINE_WIDTH, true)
	if progress <= 0.0:
		return
	var arc := fill_arc(progress)
	draw_arc(center, radius, arc.x, arc.y, ARC_POINTS, FILL_COLOR, LINE_WIDTH, true)
