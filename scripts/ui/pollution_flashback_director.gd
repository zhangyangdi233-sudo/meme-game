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
var _freeze_rects: Array[TextureRect] = []
var _unregistered_card: Label
var _empty_frames_blackout: ColorRect


static func max_luminance_flips_in_window(window_seconds: float) -> int:
	## 在任意 window_seconds 的滚动窗口里,明暗类别切换的最大次数。
	## 计入退场翻转:结束时全屏覆盖消失,画面从末相位(暗)回到游戏画面(亮)。
	var flips: Array[float] = []
	for index in range(1, PHASES.size()):
		if int(PHASES[index]["luminance"]) != int(PHASES[index - 1]["luminance"]):
			flips.append(float(PHASES[index]["start"]))
	if int(PHASES[PHASES.size() - 1]["luminance"]) == 0:
		flips.append(TOTAL_DURATION)
	var worst := 0
	for anchor_index in flips.size():
		var count := 0
		for other_index in flips.size():
			var delta: float = flips[other_index] - flips[anchor_index]
			if delta >= 0.0 and delta < window_seconds:
				count += 1
		worst = maxi(worst, count)
	return worst


func bind_scene(
	phase_roots: Dictionary,
	freeze_rects: Array[TextureRect],
	unregistered_card: Label,
	empty_frames_blackout: ColorRect,
) -> void:
	_phase_roots = phase_roots
	_freeze_rects = freeze_rects
	_unregistered_card = unregistered_card
	_empty_frames_blackout = empty_frames_blackout


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
	# 若外部未连接 finish(防御):时间线走完后自行收场,不让全屏覆盖滞留。
	if visible:
		stop()


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
