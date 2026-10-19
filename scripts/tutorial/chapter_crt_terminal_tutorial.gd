extends RefCounted
## The session owns this stateful guard; only a dispatched CRT pointer event can
## commit progress. Gray presentation alone never authorizes an app action.

const State = preload("res://scripts/tutorial/chapter_crt_tutorial_state.gd")
const Content = preload("res://scripts/tutorial/chapter_crt_tutorial_content.gd")
const Overlay = preload("res://scripts/tutorial/chapter_crt_tutorial_overlay.gd")
const Pool = preload("res://scripts/narrative/pickup_char_pool.gd")

var _host: Node
var _content: Control
var _overlay: Control
var _enabled := false
var _in_input := false
var _held := false
var _press := Vector2.ZERO
var _distance := 0.0
var _buttons: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
var _authorized: Dictionary = {}
var _needs_post_scroll := true

func begin(host: Node, content: Control) -> void:
	_host = host
	_content = content
	var game: Variant = host.get("game")
	if not game is Object:
		return
	var progress: Dictionary = game.get("chapter1_progress")
	if str(progress.get("phase", "")) != "basement" or int(progress.get("round_index", -1)) != 0:
		return
	var data := _data()
	if data.lesson_phase == "complete":
		return
	if data.lesson_phase == "publish" and not _exact_sentence(data):
		data.lesson_phase = "compose"
		_store(data)
	_enabled = true
	_overlay = Overlay.new()
	content.add_child(_overlay)
	_resume_ui(data)
	refresh()

func active() -> bool:
	return _enabled

func before_input(event: InputEvent) -> void:
	_in_input = true
	_authorized.clear()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_held = true
		_press = event.position
		_distance = 0.0
	elif event is InputEventMouseMotion and _held:
		_distance = maxf(_distance, event.position.distance_to(_press))

func after_input(event: InputEvent) -> void:
	_in_input = false
	_authorized.clear()
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_held = false
		_distance = 0.0

func allows(action: String, payload: Dictionary = {}) -> bool:
	if not _enabled:
		return true
	if not _in_input:
		return false
	var data := _data()
	var unit := str(payload.get("unit", ""))
	var allowed := false
	match action:
		"open_post":
			allowed = data.lesson_phase == "post" and str(payload.get("post_id", "")) == State.POST_ID
		"pickup":
			allowed = data.lesson_phase == "collect" and str(payload.get("post_id", "")) == State.POST_ID and unit in State.teaching_units(data.locale) and unit not in data.collected
		"place":
			allowed = data.lesson_phase == "compose" and unit in data.collected and bool(payload.get("dragged", false)) and _held and _distance >= 6.0
		"remove", "reorder":
			allowed = data.lesson_phase in ["compose", "publish"]
		"publish":
			var units: Array = payload.get("units", [])
			allowed = data.lesson_phase == "publish" and units.size() == 3 and data.dragged.size() == 3
			for required in State.teaching_units(data.locale):
				allowed = allowed and required in units
	if allowed:
		_authorized[action] = payload.duplicate(true)
	return allowed

func commit(action: String, payload: Dictionary = {}) -> void:
	if not _enabled or not _in_input or not _authorized.has(action) or _authorized[action] != payload:
		return
	_authorized.erase(action)
	var data := _data()
	match action:
		"open_post":
			data.lesson_phase = "collect"
		"pickup":
			data.collected.append(str(payload.unit))
			if data.collected.size() == 3:
				data.lesson_phase = "compose"
		"place":
			if str(payload.unit) not in data.dragged:
				data.dragged.append(str(payload.unit))
			if data.dragged.size() == 3 and _exact_sentence(data):
				data.lesson_phase = "publish"
		"remove":
			data.lesson_phase = "publish" if data.dragged.size() == 3 and _exact_sentence(data) else "compose"
		"publish":
			data.lesson_phase = "complete"
			data.published = true
	_store(data)
	if data.lesson_phase == "complete":
		end()
	else:
		refresh()

func refresh() -> void:
	if not _enabled or not is_instance_valid(_content):
		return
	var data := _data()
	var locale := _current_locale()
	if locale != data.locale:
		# Inventory is language-specific. Restart only this unfinished lesson;
		# words already earned in every language remain in the shared notebook.
		data.locale = locale
		data.lesson_phase = "post"
		data.collected = []
		data.dragged = []
		_store(data)
		_resume_ui(data)
	var rectangles: Array[Rect2] = []
	var exit_button := _content.find_child("TerminalExit", true, false) as Control
	_add_rect(rectangles, exit_button)
	var target_post: Control
	for candidate in _content.find_children("SocialPostCard*", "Control", true, false):
		if str(candidate.get_meta("post_id", "")) == State.POST_ID:
			target_post = candidate
			break
	match data.lesson_phase:
		"post":
			if is_instance_valid(target_post) and _needs_post_scroll:
				var ancestor := target_post.get_parent()
				while ancestor is Control and ancestor != _content:
					if ancestor is ScrollContainer:
						ancestor.ensure_control_visible(target_post)
						_needs_post_scroll = false
						break
					ancestor = ancestor.get_parent()
			_add_rect(rectangles, target_post)
		"collect":
			_add_rect(rectangles, _host.get("_social_detail_window"))
		"compose":
			var apps: Dictionary = _host.get("_app_windows")
			_add_rect(rectangles, apps.notebook)
		"publish":
			_add_rect(rectangles, _content.find_child("NotebookCraftButton", true, false))
			_add_rect(rectangles, _content.find_child("ComposerAnswerPanel", true, false))
	for candidate in _content.find_children("*", "BaseButton", true, false):
		var button := candidate as BaseButton
		if not button.has_meta("crt_tutorial_saved_disabled"):
			button.set_meta("crt_tutorial_saved_disabled", button.disabled)
			_buttons.append({"node": button, "disabled": button.disabled})
		var permitted: bool = button == exit_button or (data.lesson_phase == "publish" and str(button.name) == "NotebookCraftButton")
		# Answer tiles may still be removed/reordered to correct a sentence.
		permitted = permitted or (data.lesson_phase in ["compose", "publish"] and str(button.name).begins_with("ComposerAnswerTile"))
		button.disabled = bool(button.get_meta("crt_tutorial_saved_disabled")) or not permitted
	for candidate in _content.find_children("*", "RichTextLabel", true, false):
		if not candidate.has_meta("pickup_rich_text"):
			continue
		var rich := candidate as RichTextLabel
		if not rich.has_meta("crt_tutorial_original"):
			rich.set_meta("crt_tutorial_original", rich.text)
			rich.set_meta("crt_tutorial_plain", rich.get_parsed_text())
			_texts.append({"node": rich, "text": rich.text})
		var marked_text := _pickup_text(str(rich.get_meta("crt_tutorial_plain")), data)
		if rich.text != marked_text:
			rich.text = marked_text
	_overlay.present(rectangles, Content.hint(data.lesson_phase, locale, State.teaching_units(data.locale)), data.lesson_phase)

func _pickup_text(text: String, data: Dictionary) -> String:
	var result := ""
	var index := 0
	var required := State.teaching_units(data.locale)
	while index < text.length():
		var matched := ""
		for item in required:
			var unit := str(item)
			if text.substr(index, unit.length()).to_lower() == unit.to_lower():
				if data.locale == "en" and ((index > 0 and Pool.is_word_character(text.substr(index - 1, 1))) or (index + unit.length() < text.length() and Pool.is_word_character(text.substr(index + unit.length(), 1)))):
					continue
				matched = unit
				break
		if matched.is_empty():
			result += "[color=#72796c]%s[/color]" % text.substr(index, 1).replace("[", "[lb]")
			index += 1
		else:
			var display := text.substr(index, matched.length())
			result += "[color=#84917c]%s[/color]" % display if matched in data.collected else "[color=#f0ffbe][url=%s][u]%s[/u][/url][/color]" % [matched, display]
			index += matched.length()
	return result

func _resume_ui(data: Dictionary) -> void:
	_needs_post_scroll = true
	_host.set("_social_channel", "discover")
	_host.set("_social_screen", "home")
	_host.set("_social_detail_open", data.lesson_phase != "post")
	if _host.has_method("_social_post_for_index"):
		for index in 64:
			var post: Dictionary = _host._social_post_for_index(index)
			if str(post.get("id", "")) == State.POST_ID:
				_host.set("_social_detail_post_index", index)
				break
	if _host.has_method("_render"):
		_host._render.call_deferred()

func _current_locale() -> String:
	var locale: Variant = _host.get("_locale")
	return str(locale.get("current_locale")) if locale is Object else "zh"

func _data() -> Dictionary:
	var progress: Dictionary = _host.get("game").get("chapter1_progress")
	return State.normalize(progress.get("crt_tutorial", {}))

func _store(data: Dictionary) -> void:
	var progress: Dictionary = _host.get("game").get("chapter1_progress")
	progress["crt_tutorial"] = State.normalize(data)
	if _host.has_method("_save_progress"):
		_host._save_progress()

func _exact_sentence(data: Dictionary) -> bool:
	var units: Array = _host.get("game").get_free_sentence_units()
	if units.size() != 3:
		return false
	for item in State.teaching_units(data.locale):
		if item not in units:
			return false
	return true

func _add_rect(rects: Array[Rect2], control: Control) -> void:
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	var rect := control.get_global_rect()
	var parent := control.get_parent()
	while parent is Control:
		if parent.clip_contents:
			rect = rect.intersection(parent.get_global_rect())
		parent = parent.get_parent()
	if rect.has_area():
		rects.append(Rect2(rect.position - _content.global_position, rect.size))

func end() -> void:
	_enabled = false
	_in_input = false
	_held = false
	_authorized.clear()
	for saved in _buttons:
		if is_instance_valid(saved.node):
			saved.node.disabled = saved.disabled
			saved.node.remove_meta("crt_tutorial_saved_disabled")
	for saved in _texts:
		if is_instance_valid(saved.node):
			saved.node.text = saved.text
			saved.node.remove_meta("crt_tutorial_original")
			saved.node.remove_meta("crt_tutorial_plain")
	_buttons.clear()
	_texts.clear()
	if is_instance_valid(_overlay):
		_overlay.hide()
		_overlay.queue_free()
	_overlay = null
