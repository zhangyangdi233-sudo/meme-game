extends Control
## Original paper artwork shared by the world texture and the inspect view.

const HANDWRITING = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const ORIGINAL_TEXT := "墙不再是墙，路不再是路"
const LINES := ["墙不再是墙，", "路不再是路"]
const INK := Color("9c2325")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func handwriting_font_size() -> int:
	return maxi(1, floori(size.x * 0.115))

func handwriting_fits() -> bool:
	for line in LINES:
		if HANDWRITING.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, handwriting_font_size()).x > size.x * 0.80:
			return false
	return handwriting_font_size() * 2.7 < size.y

func _draw() -> void:
	var w := size.x
	var h := size.y
	# Slightly uneven edges, fibres and fold marks are original procedural art.
	var outline := PackedVector2Array([
		Vector2(w * 0.018, h * 0.024), Vector2(w * 0.32, h * 0.010),
		Vector2(w * 0.67, h * 0.020), Vector2(w * 0.986, h * 0.008),
		Vector2(w * 0.977, h * 0.48), Vector2(w * 0.992, h * 0.978),
		Vector2(w * 0.66, h * 0.987), Vector2(w * 0.28, h * 0.976),
		Vector2(w * 0.008, h * 0.990), Vector2(w * 0.016, h * 0.53),
	])
	draw_colored_polygon(outline, Color("ddd0ad"))
	var rng := RandomNumberGenerator.new()
	rng.seed = 191019
	for index in range(420):
		var at := Vector2(rng.randf_range(0.025, 0.975) * w, rng.randf_range(0.03, 0.97) * h)
		draw_line(at, at + Vector2(rng.randf_range(0.001, 0.009) * w, 0), Color(0.34, 0.28, 0.16, rng.randf_range(0.025, 0.08)), 1.0)
	draw_line(Vector2(w * 0.502, h * 0.025), Vector2(w * 0.495, h * 0.977), Color(0.42, 0.32, 0.20, 0.13), maxf(1, w * 0.002))
	draw_line(Vector2(w * 0.505, h * 0.025), Vector2(w * 0.498, h * 0.977), Color(1, 0.96, 0.81, 0.22), maxf(1, w * 0.0015))
	draw_line(Vector2(w * 0.018, h * 0.51), Vector2(w * 0.976, h * 0.50), Color(0.42, 0.32, 0.20, 0.09), maxf(1, w * 0.002))
	var font_size := handwriting_font_size()
	for index in range(LINES.size()):
		var baseline := Vector2(w * (0.12 if index == 0 else 0.16), h * (0.43 if index == 0 else 0.74))
		draw_string(HANDWRITING, baseline, LINES[index], HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
