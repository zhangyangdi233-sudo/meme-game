class_name LanguageMaterial
extends RefCounted
## Pickup marking, composer place/reorder/submit, and flight-target helpers.
## Language material stays in Game; it is not a Content catalog.

const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")

const PICKABLE_PULSE_FREQ := 0.5
const PICKABLE_FONT_SIZE := 19
const COLLECTED_COLOR := "8b8f84"
const NOTEBOOK_FLIGHT_FALLBACK := Vector2(84.0, 64.0)
const NOTEBOOK_FLIGHT_INSET := Vector2(56.0, 40.0)
const COMPOSER_FLIGHT_INSET_Y := 20.0

signal sfx_requested(kind: String)
signal effective_action(actions_before: int)
signal ui_refresh_requested
signal log_requested(text: String)
signal notebook_home_requested
signal pickup_flight_requested(unit: String, origin: Vector2)
signal place_flight_requested(unit: String)
signal status_refresh_requested

var _game_getter: Callable = Callable()
var _locale_getter: Callable = Callable()
var _mouse_origin_getter: Callable = Callable()


func configure(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_game_getter = deps.get("game", _game_getter)
	_locale_getter = deps.get("locale", _locale_getter)
	_mouse_origin_getter = deps.get("mouse_origin", _mouse_origin_getter)


func pick_from_post(meta: Variant, post_id: String) -> Dictionary:
	var game = _game()
	if game == null:
		return {"picked": false, "reason": "no-game"}
	var unit := str(meta)
	var locale_code := _locale()
	var actions_before: int = int(game.actions_remaining)
	var pick_result: Dictionary = game.pick_social_char(post_id, unit, locale_code)
	if bool(pick_result.get("picked", false)):
		log_requested.emit("一个字进入了笔记本。")
		sfx_requested.emit("pickup_press")
		notebook_home_requested.emit()
		pickup_flight_requested.emit(unit, _mouse_origin())
		if bool(pick_result.get("action_spent", false)):
			effective_action.emit(actions_before)
		else:
			status_refresh_requested.emit()
		return pick_result
	match str(pick_result.get("reason", "")):
		"duplicate":
			log_requested.emit("这个字已经在笔记本里了。")
		"no-actions":
			log_requested.emit("今天没有行动了。明天第一次拾字会重新消耗行动。")
		_:
			log_requested.emit("这个字没有进入笔记本。")
	status_refresh_requested.emit()
	return pick_result


func place_from_bank(unit: String) -> bool:
	var game = _game()
	if game == null:
		return false
	if not game.free_sentence_place(unit, _locale()):
		return false
	log_requested.emit("字进入了句子。")
	place_flight_requested.emit(unit)
	ui_refresh_requested.emit()
	return true


func place_if_over_answer(unit: String, release_global: Vector2, answer_panel: Control) -> bool:
	var game = _game()
	if game == null:
		return false
	var dropped_into_sentence := false
	if answer_panel != null and is_instance_valid(answer_panel) and answer_panel.is_visible_in_tree():
		if answer_panel.get_global_rect().has_point(release_global):
			dropped_into_sentence = game.free_sentence_place(unit, _locale())
	if dropped_into_sentence:
		log_requested.emit("字进入了句子。")
	ui_refresh_requested.emit()
	return dropped_into_sentence


func drop_on_area(data: Dictionary) -> Dictionary:
	var game = _game()
	var target_index := 0
	if game != null:
		target_index = game.get_free_sentence_units().size()
	return apply_drop_at(data, target_index)


func drop_before(data: Dictionary, before_index: int) -> Dictionary:
	return apply_drop_at(data, before_index)


func apply_drop_at(data: Dictionary, target_index: int) -> Dictionary:
	var result: Dictionary = apply_drop(_game(), data, target_index, _locale())
	if bool(result.get("applied", false)):
		if str(result.get("kind", "")) == "composer_unit":
			log_requested.emit("字进入了句子。")
		ui_refresh_requested.emit()
	return result


func remove_at(unit_index: int) -> bool:
	var game = _game()
	if game == null or not game.free_sentence_remove(unit_index):
		return false
	ui_refresh_requested.emit()
	return true


func submit() -> Dictionary:
	var game = _game()
	if game == null:
		return {"submitted": false, "reason": "no-game"}
	var actions_before: int = int(game.actions_remaining)
	var submit_result: Dictionary = game.submit_free_sentence(_locale())
	if not bool(submit_result.get("submitted", false)):
		match str(submit_result.get("reason", "")):
			"empty":
				log_requested.emit("句子还空着。")
			"no-actions":
				log_requested.emit("今天没有行动了。明天第一次拾字会重新消耗行动。")
			_:
				log_requested.emit("投稿没有发出去。")
		status_refresh_requested.emit()
		return submit_result
	var log_line := ""
	match str(submit_result.get("tier", "")):
		"rule":
			log_line = "投稿已发出。有什么地方遵守了它。"
		"misread":
			log_line = "投稿已发出。世界读错了它。"
		_:
			log_line = "投稿已发出。没有回应,只有噪声。"
	if bool(submit_result.get("floor3_task_completed", false)):
		log_line += "\n" + "第三层的门开了。"
	if bool(submit_result.get("floor4_task_completed", false)):
		log_line += "\n" + "出口开始存在。"
	log_requested.emit(log_line)
	effective_action.emit(actions_before)
	return submit_result


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


static func apply_drop(game, data: Dictionary, target_index: int, locale_code: String) -> Dictionary:
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


func _game():
	return _game_getter.call() if _game_getter.is_valid() else null


func _locale() -> String:
	return str(_locale_getter.call()) if _locale_getter.is_valid() else "zh"


func _mouse_origin() -> Vector2:
	if _mouse_origin_getter.is_valid():
		return _mouse_origin_getter.call()
	return Vector2.ZERO
