class_name PollutionFlashbackDirector
extends Control
## 60% 污染闪回导演:数据驱动的八拍时间线,无任何随机调用。
##
## 设计依据 docs/design/pollution_flashback_storyboard.md 与
## docs/research/flashback_deep_research.md:
## - Mouthwashing 公式:冻结当下 → 声音先死 → 硬切,不做 jump scare;
## - 今敏式同构匹配剪辑:关键句恒定钉在屏上,背后世界(玩偶↔医生)整体替换;
## - 语言污染只污染元数据(名牌、引号、归属),正文字形零污染;
## - 黑帧是 150-250ms 的"阅读标点",不是频闪;
## - WCAG 2.2:任意 1 秒窗口内明暗切换 ≤3(见 luminance_flip_budget 与配套测试)。

signal sequence_finished

const KEY_SENTENCE := "我只是想让你留在安全的地方。"
const SECOND_SENTENCE := "你不需要再听见那个声音。"
const SECOND_SENTENCE_CUT := "你不需要再听见那个声"
const SENTENCE_SEGMENTS := ["我只是想让你", "留在", "安全的地方。"]
const EMPTY_SPEAKER_PLATE := "【　　　】"
const UNREGISTERED_CARD_TEXT := "区域：未记录"
const DOCTOR_OFFSET_PX := 12.0
const LEFT_MISSING_FRAME_WIDTH := 22.0
const UNREGISTERED_CARD_DELAY := 0.06
const UNREGISTERED_CARD_FLASH := 0.12

## 相位表:start/duration 单位秒,连续无缝;luminance 0=暗 1=亮,供闪烁预算断言。
const PHASES := [
	{"id": "freeze", "start": 0.00, "duration": 0.50, "luminance": 1},
	{"id": "black_gap_a", "start": 0.50, "duration": 0.20, "luminance": 0},
	{"id": "doll_scene", "start": 0.70, "duration": 0.75, "luminance": 0},
	{"id": "black_gap_b", "start": 1.45, "duration": 0.17, "luminance": 0},
	{"id": "doctor_scene", "start": 1.62, "duration": 0.75, "luminance": 0},
	{"id": "attribution", "start": 2.37, "duration": 0.20, "luminance": 0},
	{"id": "triple_echo", "start": 2.57, "duration": 0.38, "luminance": 0},
	{"id": "residue_return", "start": 2.95, "duration": 0.35, "luminance": 1},
	{"id": "empty_frames", "start": 3.30, "duration": 0.25, "luminance": 0},
]
const TOTAL_DURATION := 3.55

var _phase_roots: Dictionary = {}
var _timeline: Tween
var _colors := {
	"ink": Color(0.063, 0.078, 0.059),
	"surface": Color(1.0, 0.945, 0.788),
	"flash_text": Color(0.612, 1.0, 0.141),
	"accent": Color(0.212, 0.357, 0.176),
}
var _freeze_rects: Array[TextureRect] = []
var _unregistered_card: Label
var _empty_frames_blackout: ColorRect


static func max_luminance_flips_in_window(window_seconds: float) -> int:
	## 在任意 window_seconds 的滚动窗口里,明暗类别切换的最大次数。
	var flips: Array[float] = []
	for index in range(1, PHASES.size()):
		if int(PHASES[index]["luminance"]) != int(PHASES[index - 1]["luminance"]):
			flips.append(float(PHASES[index]["start"]))
	var worst := 0
	for anchor_index in flips.size():
		var count := 0
		for other_index in flips.size():
			var delta: float = flips[other_index] - flips[anchor_index]
			if delta >= 0.0 and delta < window_seconds:
				count += 1
		worst = maxi(worst, count)
	return worst


func configure_colors(colors: Dictionary) -> void:
	for key in _colors.keys():
		if colors.has(key):
			_colors[key] = colors[key]


func build_phases() -> void:
	for child in get_children():
		child.queue_free()
	_phase_roots.clear()
	_freeze_rects.clear()

	var backdrop := ColorRect.new()
	backdrop.name = "FlashbackBackdrop"
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	_build_freeze_phase("freeze", "FlashbackPhaseFreeze", false)
	_build_black_gap_a()
	_build_scene_phase("doll_scene", "FlashbackPhaseDollScene", false)
	_build_black_gap_b()
	_build_scene_phase("doctor_scene", "FlashbackPhaseDoctorScene", true)
	_build_attribution_phase()
	_build_triple_echo_phase()
	_build_freeze_phase("residue_return", "FlashbackPhaseResidueReturn", true)
	_build_empty_frames_phase()


func play(frozen_texture: Texture2D) -> void:
	stop()
	visible = true
	modulate.a = 1.0
	for rect in _freeze_rects:
		rect.texture = frozen_texture
		rect.visible = frozen_texture != null
	_timeline = create_tween()
	for phase in PHASES:
		var phase_id := str(phase["id"])
		var duration := float(phase["duration"])
		_timeline.tween_callback(_show_only_phase.bind(phase_id))
		if phase_id == "empty_frames":
			_timeline.tween_interval(UNREGISTERED_CARD_DELAY)
			_timeline.tween_callback(_show_unregistered_card)
			_timeline.tween_interval(UNREGISTERED_CARD_FLASH)
			_timeline.tween_callback(_finish_empty_frames)
			_timeline.tween_interval(maxf(0.0, duration - UNREGISTERED_CARD_DELAY - UNREGISTERED_CARD_FLASH))
		else:
			_timeline.tween_interval(duration)
	_timeline.tween_callback(_complete_sequence)


func stop() -> void:
	if _timeline != null and _timeline.is_valid():
		_timeline.kill()
	_timeline = null
	for phase_root: Control in _phase_roots.values():
		phase_root.visible = false
	visible = false


func is_playing() -> bool:
	return _timeline != null and _timeline.is_valid()


func get_phase_root(phase_id: String) -> Control:
	return _phase_roots.get(phase_id, null)


func _complete_sequence() -> void:
	_timeline = null
	sequence_finished.emit()


func _show_only_phase(phase_id: String) -> void:
	for key: String in _phase_roots.keys():
		(_phase_roots[key] as Control).visible = key == phase_id
	if phase_id == "empty_frames":
		if _unregistered_card != null:
			_unregistered_card.visible = false
		if _empty_frames_blackout != null:
			_empty_frames_blackout.visible = false


func _show_unregistered_card() -> void:
	if _unregistered_card != null:
		_unregistered_card.visible = true


func _finish_empty_frames() -> void:
	if _unregistered_card != null:
		_unregistered_card.visible = false
	if _empty_frames_blackout != null:
		_empty_frames_blackout.visible = true


func _register_phase(phase_id: String, node_name: String) -> Control:
	var phase_root := Control.new()
	phase_root.name = node_name
	phase_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.visible = false
	phase_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(phase_root)
	_phase_roots[phase_id] = phase_root
	return phase_root


func _build_freeze_phase(phase_id: String, node_name: String, with_residue: bool) -> void:
	var phase_root := _register_phase(phase_id, node_name)
	var fallback := ColorRect.new()
	fallback.name = "FrozenFallback"
	fallback.color = _colors["ink"]
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(fallback)
	var frozen := TextureRect.new()
	frozen.name = "FrozenFrameRect"
	frozen.set_anchors_preset(Control.PRESET_FULL_RECT)
	frozen.stretch_mode = TextureRect.STRETCH_SCALE
	frozen.visible = false
	phase_root.add_child(frozen)
	_freeze_rects.append(frozen)
	if not with_residue:
		return
	frozen.modulate = Color(0.9, 0.96, 0.88, 1.0)
	for stripe_index in 3:
		var stripe := ColorRect.new()
		stripe.name = "ResidueTearStripe%d" % stripe_index
		stripe.color = Color(_colors["flash_text"], 0.16)
		stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
		stripe.offset_top = 150.0 + float(stripe_index) * 214.0
		stripe.offset_bottom = stripe.offset_top + 3.0
		stripe.offset_left = -14.0 + float(stripe_index) * 9.0
		phase_root.add_child(stripe)
	var plate := _make_label("FlashbackResiduePlate", EMPTY_SPEAKER_PLATE, 22, Color(_colors["surface"], 0.9))
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.offset_top = -168.0
	plate.offset_bottom = -132.0
	plate.offset_left = -220.0
	plate.offset_right = 220.0
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_root.add_child(plate)
	var second := _make_label("FlashbackSecondSentenceLabel", SECOND_SENTENCE_CUT, 30, _colors["surface"])
	second.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	second.offset_top = -126.0
	second.offset_bottom = -78.0
	second.offset_left = -420.0
	second.offset_right = 420.0
	second.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_root.add_child(second)


func _build_black_gap_a() -> void:
	var phase_root := _register_phase("black_gap_a", "FlashbackPhaseBlackGapA")
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(cover)


func _build_black_gap_b() -> void:
	var phase_root := _register_phase("black_gap_b", "FlashbackPhaseBlackGapB")
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(cover)
	var plate := _make_plate_label("FlashbackEmptySpeakerPlate", EMPTY_SPEAKER_PLATE, false)
	plate.set_anchors_preset(Control.PRESET_CENTER)
	plate.offset_left = -110.0
	plate.offset_right = 110.0
	plate.offset_top = -22.0
	plate.offset_bottom = 22.0
	phase_root.add_child(plate)


func _build_scene_phase(phase_id: String, node_name: String, is_doctor: bool) -> void:
	var phase_root := _register_phase(phase_id, node_name)
	var bg := ColorRect.new()
	bg.color = _colors["ink"]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(bg)

	var missing_frame := ColorRect.new()
	missing_frame.name = "MissingFrameStrip"
	missing_frame.color = Color.BLACK
	missing_frame.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	missing_frame.offset_right = LEFT_MISSING_FRAME_WIDTH
	phase_root.add_child(missing_frame)

	# 场景道具容器:医生场整体右错 12px(椅子错位,句子不动 —— 归属变化而非台词变化)。
	var scenery := Control.new()
	scenery.name = "SceneryRoot"
	scenery.set_anchors_preset(Control.PRESET_CENTER)
	scenery.position.x += DOCTOR_OFFSET_PX if is_doctor else 0.0
	phase_root.add_child(scenery)

	var chair_seat := ColorRect.new()
	chair_seat.name = "ChairSeat"
	chair_seat.color = _colors["surface"]
	chair_seat.position = Vector2(-140.0 + (DOCTOR_OFFSET_PX if is_doctor else 0.0), 10.0)
	chair_seat.size = Vector2(128.0, 16.0)
	scenery.add_child(chair_seat)
	var chair_back := ColorRect.new()
	chair_back.name = "ChairBack"
	chair_back.color = _colors["surface"]
	chair_back.position = chair_seat.position + Vector2(-16.0, -84.0)
	chair_back.size = Vector2(14.0, 100.0)
	scenery.add_child(chair_back)
	for leg_index in 2:
		var leg := ColorRect.new()
		leg.name = "ChairLeg%d" % leg_index
		leg.color = _colors["surface"]
		leg.position = chair_seat.position + Vector2(8.0 + float(leg_index) * 104.0, 16.0)
		leg.size = Vector2(9.0, 52.0)
		scenery.add_child(leg)

	# 空出的玩偶位置:只有描边的空框(可在真结局回认的空位 motif)。
	var vacancy := Panel.new()
	vacancy.name = "DollVacancyOutline"
	var vacancy_style := StyleBoxFlat.new()
	vacancy_style.bg_color = Color(0, 0, 0, 0)
	vacancy_style.border_color = Color(_colors["surface"], 0.55)
	vacancy_style.set_border_width_all(2)
	vacancy_style.set_corner_radius_all(6)
	vacancy.add_theme_stylebox_override("panel", vacancy_style)
	vacancy.position = chair_seat.position + Vector2(36.0, -64.0)
	vacancy.size = Vector2(56.0, 62.0)
	scenery.add_child(vacancy)

	var plate_text := "『医生』" if is_doctor else "「玩偶」"
	var plate := _make_plate_label(
		"FlashbackSpeakerPlateDoctor" if is_doctor else "FlashbackSpeakerPlateDoll",
		plate_text,
		is_doctor
	)
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.offset_left = -80.0
	plate.offset_right = 80.0
	plate.offset_top = -186.0
	plate.offset_bottom = -146.0
	phase_root.add_child(plate)

	# 关键句:两场字形、字号、位置完全一致,永远完整可读,位于场景之上。
	var sentence := _make_label(
		"FlashbackKeySentenceDoctor" if is_doctor else "FlashbackKeySentenceDoll",
		KEY_SENTENCE,
		32,
		_colors["surface"]
	)
	sentence.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sentence.offset_left = -430.0
	sentence.offset_right = 430.0
	sentence.offset_top = -132.0
	sentence.offset_bottom = -80.0
	sentence.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_root.add_child(sentence)


func _build_attribution_phase() -> void:
	var phase_root := _register_phase("attribution", "FlashbackPhaseAttribution")
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(cover)
	var card := RichTextLabel.new()
	card.name = "FlashbackAttributionCard"
	card.bbcode_enabled = true
	card.fit_content = true
	card.scroll_active = false
	card.text = "[center][s]玩偶[/s]　[u]医生[/u][/center]"
	card.add_theme_font_size_override("normal_font_size", 30)
	card.add_theme_color_override("default_color", Color(_colors["surface"], 0.92))
	card.set_meta("flashback_text", true)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -160.0
	card.offset_right = 160.0
	card.offset_top = -30.0
	card.offset_bottom = 30.0
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phase_root.add_child(card)


func _build_triple_echo_phase() -> void:
	var phase_root := _register_phase("triple_echo", "FlashbackPhaseTripleEcho")
	var bg := ColorRect.new()
	bg.color = _colors["ink"]
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(bg)
	for row_index in 3:
		var parts: Array[String] = []
		for segment_index in SENTENCE_SEGMENTS.size():
			if segment_index == row_index:
				var blank := ""
				for _blank_index in SENTENCE_SEGMENTS[segment_index].length():
					blank += "　"
				parts.append(blank)
			else:
				parts.append(SENTENCE_SEGMENTS[segment_index])
		var row := _make_label("FlashbackEchoRow%d" % row_index, "".join(parts), 28, Color(_colors["surface"], 0.88 - float(row_index) * 0.1))
		row.set_anchors_preset(Control.PRESET_CENTER)
		row.offset_left = -430.0 + float(row_index - 1) * 9.0
		row.offset_right = 430.0 + float(row_index - 1) * 9.0
		row.offset_top = -84.0 + float(row_index) * 52.0
		row.offset_bottom = row.offset_top + 44.0
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		phase_root.add_child(row)


func _build_empty_frames_phase() -> void:
	var phase_root := _register_phase("empty_frames", "FlashbackPhaseEmptyFrames")
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(bg)
	for square_index in 3:
		var square := Panel.new()
		square.name = "FlashbackEmptySquare%d" % square_index
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0)
		style.border_color = Color(_colors["flash_text"], 0.85)
		style.set_border_width_all(2)
		if square_index == 1:
			style.border_width_bottom = 0
		square.add_theme_stylebox_override("panel", style)
		square.set_anchors_preset(Control.PRESET_CENTER)
		square.offset_left = -132.0 + float(square_index) * 92.0
		square.offset_right = square.offset_left + 64.0
		square.offset_top = -32.0
		square.offset_bottom = 32.0
		phase_root.add_child(square)
	_unregistered_card = _make_label("FlashbackUnregisteredCard", UNREGISTERED_CARD_TEXT, 26, Color(_colors["flash_text"], 0.95))
	_unregistered_card.set_anchors_preset(Control.PRESET_CENTER)
	_unregistered_card.offset_left = -220.0
	_unregistered_card.offset_right = 220.0
	_unregistered_card.offset_top = 58.0
	_unregistered_card.offset_bottom = 100.0
	_unregistered_card.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_unregistered_card.visible = false
	phase_root.add_child(_unregistered_card)
	_empty_frames_blackout = ColorRect.new()
	_empty_frames_blackout.name = "FlashbackFinalBlackout"
	_empty_frames_blackout.color = Color.BLACK
	_empty_frames_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_empty_frames_blackout.visible = false
	phase_root.add_child(_empty_frames_blackout)


func _make_label(node_name: String, text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.set_meta("flashback_text", true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _make_plate_label(node_name: String, text_value: String, is_doctor: bool) -> Label:
	var plate := _make_label(node_name, text_value, 22, _colors["surface"])
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.35)
	style.border_color = Color(_colors["surface"], 0.7)
	if is_doctor:
		style.set_border_width_all(1)
		style.set_corner_radius_all(0)
	else:
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	plate.add_theme_stylebox_override("normal", style)
	return plate
