class_name LanguageMaterial
extends RefCounted
## Pickup marking, composer place/reorder/submit, feedback lines, and flight-target helpers.
## Flights, sounds, and the notebook home are LanguagePresenter's job.
## Language material stays in Game; it is not a Content catalog.

const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")

const PICKABLE_PULSE_FREQ := 0.5
const PICKABLE_FONT_SIZE := 19
const COLLECTED_COLOR := "8b8f84"
const NOTEBOOK_FLIGHT_FALLBACK := Vector2(84.0, 64.0)
const NOTEBOOK_FLIGHT_INSET := Vector2(56.0, 40.0)
const COMPOSER_FLIGHT_INSET_Y := 20.0
const PLACED_LINE := "字进入了句子。"

var _game: MemeGameState
var _locale: BabelGameLocale


func configure(game: MemeGameState, locale: BabelGameLocale) -> void:
	_game = game
	_locale = locale


## Picks one unit into the notebook. The host presents the returned outcome when the pickup went through.
func pick_from_post(meta: Variant, post_id: String) -> ActionOutcomeScript:
	if _game == null:
		return ActionOutcomeScript.new()
	var pick_result: Dictionary = _game.pick_social_char(post_id, str(meta), _locale_code())
	_write_feedback(pickup_feedback(pick_result))
	return pick_result["outcome"]


func place_from_bank(unit: String) -> bool:
	if _game == null or not _game.free_sentence_place(unit, _locale_code()):
		return false
	_write_feedback(PLACED_LINE)
	return true


func place_if_over_answer(unit: String, release_global: Vector2, answer_panel: Control) -> bool:
	if _game == null:
		return false
	var dropped_into_sentence := false
	if answer_panel != null and is_instance_valid(answer_panel) and answer_panel.is_visible_in_tree():
		if answer_panel.get_global_rect().has_point(release_global):
			dropped_into_sentence = _game.free_sentence_place(unit, _locale_code())
	if dropped_into_sentence:
		_write_feedback(PLACED_LINE)
	return dropped_into_sentence


func drop_on_area(data: Dictionary) -> Dictionary:
	var target_index := 0
	if _game != null:
		target_index = _game.get_free_sentence_units().size()
	return apply_drop_at(data, target_index)


func drop_before(data: Dictionary, before_index: int) -> Dictionary:
	return apply_drop_at(data, before_index)


func apply_drop_at(data: Dictionary, target_index: int) -> Dictionary:
	var result: Dictionary = apply_drop(_game, data, target_index, _locale_code())
	if bool(result.get("applied", false)) and str(result.get("kind", "")) == "composer_unit":
		_write_feedback(PLACED_LINE)
	return result


func remove_at(unit_index: int) -> bool:
	return _game != null and _game.free_sentence_remove(unit_index)


## Posts the free sentence. The host presents the returned outcome when it was posted.
func submit() -> ActionOutcomeScript:
	if _game == null:
		return ActionOutcomeScript.new()
	var submit_result: Dictionary = _game.submit_free_sentence(_locale_code())
	_write_feedback(submit_feedback(submit_result))
	return submit_result["outcome"]


## The feedback line for one pickup result.
static func pickup_feedback(pick_result: Dictionary) -> String:
	if bool(pick_result.get("picked", false)):
		return "一个字进入了笔记本。"
	match str(pick_result.get("reason", "")):
		"duplicate":
			return "这个字已经在笔记本里了。"
		_:
			return "这个字没有进入笔记本。"


## The feedback line for one submit result, including any floor task it completed.
static func submit_feedback(submit_result: Dictionary) -> String:
	if not bool(submit_result.get("submitted", false)):
		match str(submit_result.get("reason", "")):
			"empty":
				return "句子还空着。"
			_:
				return "投稿没有发出去。"
	var line := ""
	match str(submit_result.get("tier", "")):
		"rule":
			line = "投稿已发出。有什么地方遵守了它。"
		"misread":
			line = "投稿已发出。世界读错了它。"
		_:
			line = "投稿已发出。没有回应,只有噪声。"
	if bool(submit_result.get("floor3_task_completed", false)):
		line += "\n" + "第三层的门开了。"
	if bool(submit_result.get("floor4_task_completed", false)):
		line += "\n" + "出口开始存在。"
	return line


static func pickup_line(post_id: String, locale_code: String) -> String:
	return PickupCharPoolScript.get_pickup_line(post_id, locale_code)


static func pickup_comments(post_id: String, locale_code: String) -> Array:
	return PickupCharPoolScript.get_comments(post_id, locale_code)


static func escape_bbcode(value: String) -> String:
	var sentinel := String.chr(1)
	return value.replace("[", sentinel).replace("]", "[rb]").replace(sentinel, "[lb]")


static func pickup_bbcode(source_text: String, locale_code: String, collected: Array, pickable_color: String) -> String:
	var units: Array = PickupCharPoolScript.get_unit_pool(locale_code)
	units.sort_custom(func(left, right): return str(left).length() > str(right).length())
	var collected_units: Array[String] = []
	for unit_value in collected:
		collected_units.append(str(unit_value))
	var result := ""
	var index := 0
	var text_length := source_text.length()
	while index < text_length:
		var matched := ""
		var matched_display := ""
		for unit_value in units:
			var unit := str(unit_value)
			if unit.is_empty() or index + unit.length() > text_length:
				continue
			var slice := source_text.substr(index, unit.length())
			if locale_code == "en":
				if slice.to_lower() != unit.to_lower():
					continue
				if not _word_boundary_ok(source_text, index, unit.length()):
					continue
			elif slice != unit:
				continue
			matched = unit
			matched_display = slice
			break
		if matched.is_empty():
			result += escape_bbcode(source_text.substr(index, 1))
			index += 1
			continue
		if matched in collected_units:
			result += "[color=#%s]%s[/color]" % [COLLECTED_COLOR, escape_bbcode(matched_display)]
		else:
			result += "[color=#%s][url=%s][u][pulse freq=%.1f color=#ffffff55 ease=-2.0][font_size=%d]%s[/font_size][/pulse][/u][/url][/color]" % [
				pickable_color, matched, PICKABLE_PULSE_FREQ, PICKABLE_FONT_SIZE, escape_bbcode(matched_display),
			]
		index += matched.length()
	return result


static func apply_drop(game: MemeGameState, data: Dictionary, target_index: int, locale_code: String) -> Dictionary:
	if game == null:
		return {"applied": false, "kind": "", "reason": "no-game"}
	var kind := str(data.get("kind", ""))
	match kind:
		"composer_unit":
			var placed: bool = game.free_sentence_place_at(str(data.get("id", "")), target_index, locale_code)
			return {"applied": placed, "kind": kind, "reason": "" if placed else "rejected"}
		"composer_reorder":
			var from_index := int(str(data.get("id", "-1")))
			var to_index := target_index
			if from_index < to_index:
				to_index -= 1
			var moved: bool = game.free_sentence_move(from_index, to_index)
			return {"applied": moved, "kind": kind, "reason": "" if moved else "rejected"}
		_:
			return {"applied": false, "kind": kind, "reason": "unknown-kind"}


static func notebook_flight_target(window: Control) -> Vector2:
	if window != null and is_instance_valid(window) and window.visible:
		return window.get_global_position() + NOTEBOOK_FLIGHT_INSET
	return NOTEBOOK_FLIGHT_FALLBACK


static func composer_answer_target(answer_flow: Control) -> Vector2:
	if answer_flow != null and is_instance_valid(answer_flow):
		return answer_flow.get_global_position() + Vector2(answer_flow.size.x * 0.5, COMPOSER_FLIGHT_INSET_Y)
	return NOTEBOOK_FLIGHT_FALLBACK


static func _word_boundary_ok(text: String, start_index: int, unit_length: int) -> bool:
	if start_index > 0 and PickupCharPoolScript.is_word_character(text.substr(start_index - 1, 1)):
		return false
	var after_index := start_index + unit_length
	if after_index < text.length() and PickupCharPoolScript.is_word_character(text.substr(after_index, 1)):
		return false
	return true


func _write_feedback(text: String) -> void:
	GameModelsScript.write_feedback(text)


func _locale_code() -> String:
	return _locale.current_locale if _locale != null else "zh"
