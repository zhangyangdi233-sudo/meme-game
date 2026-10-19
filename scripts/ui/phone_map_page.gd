extends Control
## Persistent north-up map. Grid pixels are cached separately from the live
## position/heading; configure() can be called every frame without rebuilding UI.

const ROAD_COLOR := Color("FFF1C9")
const WALL_COLOR := Color("73776C")
const INK_COLOR := Color("3F2937")
const STRINGS := {
	"zh": ["第二层 · 已探索 %d%%", "黑：未知　米白：道路　灰：建筑", "▲ 你的位置　↑ 北", "此区域尚无定位"],
	"en": ["FLOOR 2 · EXPLORED %d%%", "Black: unknown · Cream: paths · Gray: walls", "▲ Your position   ↑ North", "Location unavailable here"],
	"ja": ["第2層 · 探索済み %d%%", "黒：未探索　白：道　灰：建物", "▲ 現在地　↑ 北", "このエリアでは測位できません"],
}

var grid_rebuild_count := 0
var _columns := 0
var _rows := 0
var _explored := PackedByteArray()
var _walkable := PackedByteArray()
var _xray_walkable := PackedByteArray()
var _xray_texture: ImageTexture
var _xray_frame := Rect2()
var _xray_viewport_size := Vector2.ZERO
var _xray_active := false
var _exit_uv := Vector2(-1, -1)
var _grid_image: Image
var _grid_texture: ImageTexture
var _player_uv := Vector2.ZERO
var _heading := 0.0
var _show_marker := false
var _percent := 0
var _locale_code := ""
var _map_rect := Rect2()
var _summary_label: Label
var _legend_label: Label
var _location_label: Label

func _ready() -> void:
	_ensure_ui()
	resized.connect(_layout_map)
	_layout_map.call_deferred()

func configure(snapshot: Dictionary, locale_code: String = "zh") -> void:
	_ensure_ui()
	var columns := clampi(int(snapshot.get("columns", 0)), 0, 512)
	var rows := clampi(int(snapshot.get("rows", 0)), 0, 512)
	var explored := _byte_array(snapshot.get("explored", PackedByteArray()))
	var walkable := _byte_array(snapshot.get("walkable", PackedByteArray()))
	var xray_walkable := _byte_array(snapshot.get("xray_walkable", walkable))
	_exit_uv = snapshot.get("exit_uv", Vector2(-1, -1))
	var grid_changed := columns != _columns or rows != _rows or explored != _explored or walkable != _walkable or xray_walkable != _xray_walkable
	if grid_changed:
		_columns = columns
		_rows = rows
		_explored = explored.duplicate()
		_walkable = walkable.duplicate()
		_xray_walkable = xray_walkable.duplicate()
		_rebuild_grid()
		_layout_map()
	var point: Variant = snapshot.get("player_uv", Vector2.ZERO)
	var player_uv: Vector2 = point if point is Vector2 else Vector2.ZERO
	var heading := float(snapshot.get("heading_radians", 0.0))
	if not is_finite(heading):
		heading = 0.0
	var show_marker := bool(snapshot.get("active", false)) and _grid_texture != null and player_uv.is_finite() and player_uv.x >= 0 and player_uv.x <= 1 and player_uv.y >= 0 and player_uv.y <= 1
	var percent := clampi(int(round(float(snapshot.get("explored_ratio", 0.0)) * 100.0)), 0, 100)
	var language := locale_code if STRINGS.has(locale_code) else "en"
	var label_changed := language != _locale_code or percent != _percent or show_marker != _show_marker
	var marker_changed := player_uv != _player_uv or heading != _heading or show_marker != _show_marker
	_player_uv = player_uv
	_heading = heading
	_show_marker = show_marker
	_percent = percent
	_locale_code = language
	if label_changed:
		_refresh_labels()
	if marker_changed or grid_changed:
		queue_redraw()

func _ensure_ui() -> void:
	if _summary_label != null:
		return
	name = "PhoneMapPage"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_summary_label = _make_label("MapExplorationLabel", 18)
	_legend_label = _make_label("MapLegendLabel", 18)
	_location_label = _make_label("MapLocationLabel", 18)
	_location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _make_label(node_name: String, font_size: int) -> Label:
	var label := Label.new()
	label.name = node_name
	label.clip_text = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.set_meta("skip_localization", true)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK_COLOR)
	add_child(label)
	return label

func _byte_array(value: Variant) -> PackedByteArray:
	if value is PackedByteArray:
		return value
	if value is Array:
		return PackedByteArray(value)
	return PackedByteArray()

func _rebuild_grid() -> void:
	grid_rebuild_count += 1
	if _columns <= 0 or _rows <= 0:
		_grid_image = null
		_grid_texture = null
		_xray_texture = null
		return
	_grid_image = Image.create(_columns, _rows, false, Image.FORMAT_RGBA8)
	_grid_image.fill(Color.BLACK)
	for index in mini(_columns * _rows, _explored.size()):
		if _explored[index] == 0:
			continue
		var color := ROAD_COLOR if index < _walkable.size() and _walkable[index] != 0 else WALL_COLOR
		_grid_image.set_pixel(index % _columns, index / _columns, color)
	if _grid_texture != null and _grid_texture.get_width() == _columns and _grid_texture.get_height() == _rows:
		_grid_texture.update(_grid_image)
	else:
		_grid_texture = ImageTexture.create_from_image(_grid_image)
	var xray_image := _grid_image.duplicate() as Image
	for index in mini(_columns * _rows, _explored.size()):
		if _explored[index] == 0:
			continue
		xray_image.set_pixel(index % _columns, index / _columns, ROAD_COLOR if index < _xray_walkable.size() and _xray_walkable[index] != 0 else WALL_COLOR)
	_xray_texture = ImageTexture.create_from_image(xray_image)


func set_xray_frame(frame: Rect2, viewport_size: Vector2, active: bool) -> void:
	_xray_frame = frame
	_xray_viewport_size = viewport_size
	_xray_active = active
	queue_redraw()


func _local_xray_clip() -> Rect2:
	if not _xray_active or _xray_viewport_size.x <= 0 or _xray_viewport_size.y <= 0:
		return Rect2()
	var inverse := get_global_transform().affine_inverse()
	var start := inverse * (_xray_frame.position * _xray_viewport_size)
	var finish := inverse * (_xray_frame.end * _xray_viewport_size)
	return Rect2(start, finish - start).abs().intersection(_map_rect)


func _draw_xray_map() -> void:
	var clip := _local_xray_clip()
	if not clip.has_area() or _xray_texture == null:
		return
	var source := Rect2((clip.position - _map_rect.position) / _map_rect.size * Vector2(_columns, _rows), clip.size / _map_rect.size * Vector2(_columns, _rows))
	draw_texture_rect_region(_xray_texture, clip, source)
	draw_rect(clip, Color("A7BD8B"), false, 2.0)


func _draw_xray_exit() -> void:
	var clip := _local_xray_clip()
	if not clip.has_area() or _xray_texture == null:
		return
	var cell := Vector2i((_exit_uv * Vector2(_columns, _rows)).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= _columns or cell.y >= _rows or _explored[cell.y * _columns + cell.x] == 0:
		return
	var icon := Rect2(_map_rect.position + _exit_uv * _map_rect.size - Vector2(3, 5), Vector2(6, 10))
	if clip.encloses(icon):
		draw_rect(icon.grow(1), INK_COLOR)
		draw_rect(icon, Color.WHITE)


func observed_xray_targets(layout: Dictionary, player: Vector3) -> Array[String]:
	var result: Array[String] = []
	var clip := _local_xray_clip()
	if not is_visible_in_tree() or not clip.has_area() or _columns <= 0 or _rows <= 0:
		return result
	var bounds: Rect2 = layout.get("bounds", Rect2())
	if not bounds.has_area():
		return result
	for target: Dictionary in layout.get("xray_targets", []):
		var point: Vector3 = target.position
		if player.distance_to(point) > float(target.get("max_distance", 9.0)):
			continue
		var uv: Vector2 = (Vector2(point.x, point.z) - bounds.position) / bounds.size
		if str(target.id) == "exit":
			uv = _exit_uv
		var cell := Vector2i((uv * Vector2(_columns, _rows)).floor())
		if cell.x < 0 or cell.y < 0 or cell.x >= _columns or cell.y >= _rows:
			continue
		var index := cell.y * _columns + cell.x
		if index >= _explored.size() or _explored[index] == 0:
			continue
		var visible_mark := Rect2(_map_rect.position + uv * _map_rect.size - Vector2(3, 5), Vector2(6, 10))
		if clip.encloses(visible_mark):
			result.append(str(target.id))
	return result

func _refresh_labels() -> void:
	var words: Array = STRINGS[_locale_code]
	_summary_label.text = str(words[0]) % _percent
	_legend_label.text = str(words[1])
	_location_label.text = str(words[2] if _show_marker else words[3])

func _layout_map() -> void:
	if _summary_label == null or size.x <= 0 or size.y <= 0:
		return
	_summary_label.position = Vector2.ZERO
	_summary_label.size = Vector2(size.x, 28)
	_legend_label.position = Vector2(0, 30)
	_legend_label.size = Vector2(size.x, 46)
	_location_label.position = Vector2(0, maxf(0, size.y - 34))
	_location_label.size = Vector2(size.x, 34)
	var available := Vector2(size.x, maxf(1, size.y - 120))
	var aspect := float(_columns) / maxf(1, _rows) if _columns > 0 else 1.0
	var width := minf(available.x, available.y * aspect)
	var map_size := Vector2(width, width / maxf(0.001, aspect))
	_map_rect = Rect2(Vector2((size.x - map_size.x) * 0.5, 82 + (available.y - map_size.y) * 0.5), map_size)
	queue_redraw()

func _marker_direction() -> Vector2:
	return Vector2(-sin(_heading), -cos(_heading))

func _map_global_rect() -> Rect2:
	var transform := get_global_transform()
	return Rect2(transform * _map_rect.position, transform.basis_xform(_map_rect.size)).abs()

func _draw() -> void:
	if _map_rect.size.x <= 0 or _map_rect.size.y <= 0:
		return
	draw_rect(_map_rect, Color.BLACK)
	if _grid_texture != null:
		draw_texture_rect(_grid_texture, _map_rect, false)
	_draw_xray_map()
	draw_rect(_map_rect, Color("8B887E"), false, 1)
	if not _show_marker:
		_draw_xray_exit()
		return
	var radius := minf(12, minf(_map_rect.size.x, _map_rect.size.y) * 0.04)
	var center := _map_rect.position + _player_uv * _map_rect.size
	center = center.clamp(_map_rect.position + Vector2.ONE * radius, _map_rect.end - Vector2.ONE * radius)
	var forward := _marker_direction()
	var right := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([center + forward * radius, center - forward * radius * 0.7 + right * radius * 0.6, center - forward * radius * 0.3, center - forward * radius * 0.7 - right * radius * 0.6])
	draw_colored_polygon(points, INK_COLOR)
	points.append(points[0])
	draw_polyline(points, ROAD_COLOR, 2, true)
	# Near the doorway, the position marker must not hide the only exit clue.
	_draw_xray_exit()
