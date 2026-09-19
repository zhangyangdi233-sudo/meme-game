class_name FlashbackOverlayPanel
extends Node
## Pollution flashback overlay shell: owns Control tree; director drives the timeline.

const PollutionFlashbackDirectorScript = preload("res://scripts/ui/pollution_flashback_director.gd")

var _overlay: Control
var _director: PollutionFlashbackDirector
var _theme_color_fn: Callable
var _on_sequence_finished: Callable
var _colors := {
	"ink": Color(0.063, 0.078, 0.059),
	"surface": Color(1.0, 0.945, 0.788),
	"flash_text": Color(0.612, 1.0, 0.141),
}
var _phase_roots: Dictionary = {}
var _freeze_rects: Array[TextureRect] = []
var _unregistered_card: Label
var _empty_frames_blackout: ColorRect


func mount(parent: Control, deps: Dictionary = {}) -> void:
	_apply_mount_deps(deps)
	if parent == null or not _theme_color_fn.is_valid():
		return
	if _overlay != null and is_instance_valid(_overlay):
		_overlay.queue_free()
	_build_overlay(parent)
	if _on_sequence_finished.is_valid():
		_director.sequence_finished.connect(_on_sequence_finished)


func get_overlay() -> Control:
	return _overlay


func get_director() -> PollutionFlashbackDirector:
	return _director


func configure_colors(colors: Dictionary) -> void:
	for key in _colors.keys():
		if colors.has(key):
			_colors[key] = colors[key]


func build_phases() -> void:
	if _director == null:
		return
	_director.stop()
	for child in _director.get_children():
		_director.remove_child(child)
		child.free()
	_phase_roots.clear()
	_freeze_rects.clear()
	_unregistered_card = null
	_empty_frames_blackout = null

	var backdrop := ColorRect.new()
	backdrop.name = "FlashbackBackdrop"
	backdrop.color = Color.BLACK
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_director.add_child(backdrop)

	_build_freeze_phase("freeze", "FlashbackPhaseFreeze", false)
	_build_black_gap_phase("black_gap_a", "FlashbackPhaseBlackGapA", false)
	_build_scene_phase("doll_scene", "FlashbackPhaseDollScene", false)
	_build_black_gap_phase("black_gap_b", "FlashbackPhaseBlackGapB", true)
	_build_scene_phase("doctor_scene", "FlashbackPhaseDoctorScene", true)
	_build_attribution_phase()
	_build_triple_echo_phase()
	_build_freeze_phase("residue_return", "FlashbackPhaseResidueReturn", true)
	_build_empty_frames_phase()
	_director.bind_scene(_phase_roots, _freeze_rects, _unregistered_card, _empty_frames_blackout)


func play(frozen_texture: Texture2D) -> void:
	if _overlay != null:
		_overlay.visible = true
		_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	if _director != null:
		_director.play(frozen_texture)


func stop() -> void:
	if _director != null:
		_director.stop()
	if _overlay != null:
		_overlay.visible = false
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE


func is_playing() -> bool:
	return _director != null and _director.is_playing()


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_theme_color_fn = deps.get("theme_color", Callable())
	_on_sequence_finished = deps.get("on_sequence_finished", Callable())


func _build_overlay(parent: Control) -> void:
	_overlay = Control.new()
	_overlay.name = "PollutionFlashbackOverlay"
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	_overlay.z_index = 100
	parent.add_child(_overlay)

	_director = PollutionFlashbackDirectorScript.new()
	_director.name = "PollutionFlashbackDirector"
	_director.set_anchors_preset(Control.PRESET_FULL_RECT)
	_director.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_director.visible = false
	_overlay.add_child(_director)

	if _theme_color_fn.is_valid():
		configure_colors({
			"ink": _theme_color_fn.call("ink"),
			"surface": _theme_color_fn.call("surface"),
			"flash_text": _theme_color_fn.call("flash_text"),
		})


func _register_phase(phase_id: String, node_name: String) -> Control:
	var phase_root := Control.new()
	phase_root.name = node_name
	phase_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.visible = false
	phase_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_director.add_child(phase_root)
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
	var plate := _make_label(
		"FlashbackResiduePlate",
		PollutionFlashbackDirector.EMPTY_SPEAKER_PLATE,
		22,
		Color(_colors["surface"], 0.9)
	)
	plate.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	plate.offset_top = -168.0
	plate.offset_bottom = -132.0
	plate.offset_left = -220.0
	plate.offset_right = 220.0
	plate.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_root.add_child(plate)
	var second := _make_label(
		"FlashbackSecondSentenceLabel",
		PollutionFlashbackDirector.SECOND_SENTENCE_CUT,
		30,
		_colors["surface"]
	)
	second.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	second.offset_top = -126.0
	second.offset_bottom = -78.0
	second.offset_left = -420.0
	second.offset_right = 420.0
	second.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	phase_root.add_child(second)


func _build_black_gap_phase(phase_id: String, node_name: String, with_empty_speaker_plate: bool) -> void:
	var phase_root := _register_phase(phase_id, node_name)
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	phase_root.add_child(cover)
	if not with_empty_speaker_plate:
		return
	var plate := _make_plate_label(
		"FlashbackEmptySpeakerPlate",
		PollutionFlashbackDirector.EMPTY_SPEAKER_PLATE,
		false
	)
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
	missing_frame.offset_right = PollutionFlashbackDirector.LEFT_MISSING_FRAME_WIDTH
	phase_root.add_child(missing_frame)

	var scenery := Control.new()
	scenery.name = "SceneryRoot"
	scenery.set_anchors_preset(Control.PRESET_CENTER)
	scenery.position.x += PollutionFlashbackDirector.DOCTOR_OFFSET_PX if is_doctor else 0.0
	phase_root.add_child(scenery)

	var chair_seat := ColorRect.new()
	chair_seat.name = "ChairSeat"
	chair_seat.color = _colors["surface"]
	chair_seat.position = Vector2(-140.0, 10.0)
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

	var sentence := _make_label(
		"FlashbackKeySentenceDoctor" if is_doctor else "FlashbackKeySentenceDoll",
		PollutionFlashbackDirector.KEY_SENTENCE,
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
		for segment_index in PollutionFlashbackDirector.SENTENCE_SEGMENTS.size():
			if segment_index == row_index:
				var blank := ""
				for _blank_index in PollutionFlashbackDirector.SENTENCE_SEGMENTS[segment_index].length():
					blank += "　"
				parts.append(blank)
			else:
				parts.append(PollutionFlashbackDirector.SENTENCE_SEGMENTS[segment_index])
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
	_unregistered_card = _make_label(
		"FlashbackUnregisteredCard",
		PollutionFlashbackDirector.UNREGISTERED_CARD_TEXT,
		26,
		Color(_colors["flash_text"], 0.95)
	)
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
