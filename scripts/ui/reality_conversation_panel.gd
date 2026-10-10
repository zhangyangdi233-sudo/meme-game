class_name RealityConversationPanel
extends Node
## Reality subtitle, choice row, typing line, and continue button chrome.
## While shown, it watches the conversation progress models and repaints itself.

const RicherTextLabelScript = preload("res://addons/richtext2/richer_text_label.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")

const WATCHED: Array[String] = [
	PropertyKeysScript.CONVERSATION_PHASE,
	PropertyKeysScript.CONVERSATION_ACTOR_TYPE,
	PropertyKeysScript.CONVERSATION_ACTOR_LABEL,
	PropertyKeysScript.CONVERSATION_PROMPT,
	PropertyKeysScript.CONVERSATION_CHOICES,
	PropertyKeysScript.CONVERSATION_CAN_CONTINUE,
	PropertyKeysScript.CONVERSATION_FEEDBACK,
	PropertyKeysScript.CONVERSATION_REVEAL_INDEX,
	PropertyKeysScript.CONVERSATION_REVEALED_UNITS,
]

signal choice_hovered(choice_id: String)
signal choice_unhovered(choice_id: String)
signal choice_pressed(choice_id: String)
signal continue_pressed

var _subtitle_panel: PanelContainer
var _subtitle_label: RichTextLabel
var _choice_row: HBoxContainer
var _intent_preview: RichTextLabel
var _typing_line: RichTextLabel
var _typing_progress: Label
var _continue_button: Button

var _label_factory: Callable
var _theme_color_fn: Callable
var _ui_font_size_fn: Callable
var _viewport_size_fn: Callable
var _install_rich_text_effect_fn: Callable
var _set_dialogue_text_fn: Callable
var _set_richer_bbcode_fn: Callable
var _clear_children_fn: Callable
var _day_line_fn: Callable
var _fallback_actor_name_fn: Callable
var _last_spoken_sentence_fn: Callable
var _npc_understanding_fn: Callable
var _hover_choice_id_fn: Callable
var _hover_choice_preview_fn: Callable
var _playtest_assist_fn: Callable
var _typed_bbcode_fn: Callable
var _typing_unit_count_fn: Callable

var _shown := false
var _observing := false
var _listeners: Dictionary = {}
var _values: Dictionary = {}


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_chrome(parent)


## The play chrome decides whether the conversation may show at all. While it shows, the models decide the rest.
func set_shown(shown: bool) -> void:
	_shown = shown
	if shown:
		var was_observing := _observing
		_start_observing()
		if was_observing:
			_paint()
	else:
		_stop_observing()
		_hide_all()


## Repaints for what the models cannot tell, for example a new hover, a language change, or the day line.
func render() -> void:
	if _shown:
		_paint()


func _exit_tree() -> void:
	_stop_observing()


func _start_observing() -> void:
	if _observing:
		return
	var models: Dictionary = {}
	for property_name in WATCHED:
		var model := _property_model(property_name)
		if model == null:
			return
		models[property_name] = model
	_observing = true
	_values.clear()
	for property_name in WATCHED:
		var listener := _on_property.bind(property_name)
		_listeners[property_name] = listener
		(models[property_name] as PropertyModel).register(listener)


func _stop_observing() -> void:
	if not _observing:
		return
	_observing = false
	var listeners := _listeners
	_listeners = {}
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		return
	for property_name in listeners:
		var model := _property_model(str(property_name))
		if model != null:
			model.unregister(listeners[property_name])


func _on_property(value: Variant, property_name: String) -> void:
	_values[property_name] = value
	# Registering delivers each value once; the first paint waits until all of them arrived.
	if _values.size() == WATCHED.size() and _shown:
		_paint()


func _property_model(property_name: String) -> PropertyModel:
	if not ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		push_error("Conversation panel cannot see the property service")
		return null
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return null
	return manager.model(property_name)


func _hide_all() -> void:
	if _subtitle_panel == null or not is_instance_valid(_subtitle_panel):
		return
	_subtitle_panel.visible = false
	_choice_row.visible = false
	_intent_preview.visible = false
	_typing_line.visible = false
	_typing_progress.visible = false


func _paint() -> void:
	if _values.size() < WATCHED.size() or _subtitle_label == null or not is_instance_valid(_subtitle_label) or not _clear_children_fn.is_valid():
		return
	_clear_children_fn.call(_choice_row)
	var phase := str(_values.get(PropertyKeysScript.CONVERSATION_PHASE, ""))
	var choosing := phase == "choosing"
	var typing := phase == "typing"
	var result := phase == "result"
	var actor_label := str(_values.get(PropertyKeysScript.CONVERSATION_ACTOR_LABEL, ""))
	var actor_type := str(_values.get(PropertyKeysScript.CONVERSATION_ACTOR_TYPE, ""))
	var actor_name: String = actor_label if not actor_label.is_empty() else str(_call(_fallback_actor_name_fn, ""))
	var prompt := str(_values.get(PropertyKeysScript.CONVERSATION_PROMPT, ""))
	var npc_line: String = prompt if not prompt.is_empty() else str(_call(_day_line_fn, ""))
	var subtitle := "%s：%s" % [actor_name, npc_line]
	var feedback := str(_values.get(PropertyKeysScript.CONVERSATION_FEEDBACK, ""))
	if not feedback.is_empty():
		subtitle += "\n" + feedback
	_set_dialogue_text_fn.call(_subtitle_label, subtitle)
	if result and bool(_values.get(PropertyKeysScript.CONVERSATION_CAN_CONTINUE, false)):
		_continue_button.text = "继续交谈"
	elif result:
		_continue_button.text = "结束"
	else:
		_continue_button.text = "离开"
	var last_spoken := str(_call(_last_spoken_sentence_fn, ""))
	if result and actor_type == "doctor" and not last_spoken.is_empty():
		_set_dialogue_text_fn.call(_subtitle_label, "%s：%s\n你说：%s\n理解度：%d%%" % [
			actor_name,
			feedback,
			last_spoken,
			int(_call(_npc_understanding_fn, 0)),
		])
	_subtitle_panel.visible = true
	_continue_button.visible = true
	_choice_row.visible = choosing
	_typing_line.visible = typing
	_typing_progress.visible = typing
	var hover_choice_id := str(_call(_hover_choice_id_fn, ""))
	_intent_preview.visible = choosing and not hover_choice_id.is_empty()
	if choosing:
		var playtest_assist_enabled := bool(_call(_playtest_assist_fn, false))
		var viewport_size: Vector2 = _viewport_size_fn.call()
		var compact: bool = viewport_size.x < 760.0
		for choice_value in _values.get(PropertyKeysScript.CONVERSATION_CHOICES, []):
			var choice: Dictionary = choice_value as Dictionary
			var choice_id := str(choice.get("id", ""))
			var button := Button.new()
			button.name = "RealityChoice%s" % choice_id.to_pascal_case()
			button.text = str(choice.get("summary", "回应"))
			if playtest_assist_enabled and actor_type == "key_npc" and bool(choice.get("correct", false)):
				button.text = "✓ TEST  %s" % button.text
			button.custom_minimum_size = Vector2(96 if compact else 164, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if compact:
				button.add_theme_font_size_override("font_size", _ui_font_size_fn.call(13))
			button.set_meta("reality_response_choice", true)
			button.disabled = bool(choice.get("locked", false))
			if button.disabled:
				button.tooltip_text = "这部分还听不清。"
			button.mouse_entered.connect(_on_choice_hovered.bind(choice_id))
			button.mouse_exited.connect(_on_choice_unhovered.bind(choice_id))
			if not button.disabled:
				button.pressed.connect(_on_choice_pressed.bind(choice_id))
			_choice_row.add_child(button)
		if hover_choice_id.is_empty():
			_set_dialogue_text_fn.call(_intent_preview, "")
		else:
			_set_dialogue_text_fn.call(_intent_preview, str(_call(_hover_choice_preview_fn, "")))
	if typing:
		_set_richer_bbcode_fn.call(_typing_line, str(_call(_typed_bbcode_fn, "")))
		_typing_progress.text = "任意键  %d / %d" % [
			int(_values.get(PropertyKeysScript.CONVERSATION_REVEAL_INDEX, 0)),
			int(_call(_typing_unit_count_fn, 0)),
		]
	else:
		_set_richer_bbcode_fn.call(_typing_line, "")
		_typing_progress.text = ""


func _call(callback: Callable, fallback: Variant) -> Variant:
	return callback.call() if callback.is_valid() else fallback


func layout(hud_right: float) -> void:
	if _intent_preview == null:
		return
	var viewport_size: Vector2 = _viewport_size_fn.call()
	var compact := viewport_size.x < 760.0
	var safe_left := maxf(18.0, hud_right + (12.0 if compact else 48.0))
	var right_margin := 18.0 if compact else 150.0
	var content_left := safe_left + (4.0 if compact else 80.0)
	var content_right := -right_margin
	_intent_preview.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_intent_preview.offset_left = content_left
	_intent_preview.offset_top = -354.0
	_intent_preview.offset_right = content_right
	_intent_preview.offset_bottom = -282.0
	_choice_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_choice_row.offset_left = content_left
	_choice_row.offset_top = -272.0
	_choice_row.offset_right = content_right
	_choice_row.offset_bottom = -208.0
	_typing_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_typing_line.offset_left = content_left
	_typing_line.offset_top = -300.0
	_typing_line.offset_right = content_right
	_typing_line.offset_bottom = -208.0
	_typing_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_typing_progress.offset_left = content_left
	_typing_progress.offset_top = -208.0
	_typing_progress.offset_right = content_right
	_typing_progress.offset_bottom = -182.0
	_subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_panel.offset_left = content_left
	_subtitle_panel.offset_top = -178.0
	_subtitle_panel.offset_right = content_right
	_subtitle_panel.offset_bottom = -104.0


func set_intent_preview(text: String) -> void:
	if _intent_preview == null:
		return
	_set_dialogue_text_fn.call(_intent_preview, text)
	_intent_preview.visible = not text.is_empty()


func clear_intent_preview() -> void:
	if _intent_preview == null:
		return
	_set_dialogue_text_fn.call(_intent_preview, "")
	_intent_preview.visible = false


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_ui_font_size_fn = deps.get("ui_font_size", Callable())
	_viewport_size_fn = deps.get("viewport_size", Callable())
	_install_rich_text_effect_fn = deps.get("install_rich_text_effect", Callable())
	_set_dialogue_text_fn = deps.get("set_dialogue_text", Callable())
	_set_richer_bbcode_fn = deps.get("set_richer_bbcode", Callable())
	_clear_children_fn = deps.get("clear_children", Callable())
	_day_line_fn = deps.get("day_line", Callable())
	_fallback_actor_name_fn = deps.get("fallback_actor_name", Callable())
	_last_spoken_sentence_fn = deps.get("last_spoken_sentence", Callable())
	_npc_understanding_fn = deps.get("npc_understanding", Callable())
	_hover_choice_id_fn = deps.get("hover_choice_id", Callable())
	_hover_choice_preview_fn = deps.get("hover_choice_preview", Callable())
	_playtest_assist_fn = deps.get("playtest_assist_enabled", Callable())
	_typed_bbcode_fn = deps.get("typed_bbcode", Callable())
	_typing_unit_count_fn = deps.get("typing_unit_count", Callable())


func _build_chrome(parent: Control) -> void:
	if _subtitle_panel != null and is_instance_valid(_subtitle_panel):
		return
	if parent == null or not _label_factory.is_valid():
		return

	_intent_preview = RicherTextLabelScript.new()
	_install_rich_text_effect_fn.call(_intent_preview, "curspull")
	_intent_preview.name = "RealityIntentPreview"
	_intent_preview.bbcode_enabled = true
	_intent_preview.fit_content = false
	_intent_preview.scroll_active = false
	_intent_preview.set_meta("on_dark", true)
	_intent_preview.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_intent_preview.offset_left = 310
	_intent_preview.offset_top = -360
	_intent_preview.offset_right = -250
	_intent_preview.offset_bottom = -286
	_intent_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intent_preview.add_theme_font_size_override("normal_font_size", _ui_font_size_fn.call(28))
	_intent_preview.add_theme_color_override("default_color", _theme_color_fn.call("surface"))
	_intent_preview.add_theme_color_override("font_outline_color", Color("050705"))
	_intent_preview.add_theme_constant_override("outline_size", 8)
	_intent_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intent_preview.z_index = 14
	parent.add_child(_intent_preview)

	_choice_row = HBoxContainer.new()
	_choice_row.name = "RealityResponseChoices"
	_choice_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_choice_row.offset_left = 350
	_choice_row.offset_top = -270
	_choice_row.offset_right = -290
	_choice_row.offset_bottom = -206
	_choice_row.add_theme_constant_override("separation", 14)
	_choice_row.clip_contents = true
	_choice_row.z_index = 15
	parent.add_child(_choice_row)

	_typing_line = RicherTextLabelScript.new()
	_install_rich_text_effect_fn.call(_typing_line, "curspull")
	_install_rich_text_effect_fn.call(_typing_line, "cuss")
	_typing_line.name = "RealityTypingLine"
	_typing_line.bbcode_enabled = true
	_typing_line.fit_content = false
	_typing_line.scroll_active = false
	_typing_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_typing_line.offset_left = 280
	_typing_line.offset_top = -300
	_typing_line.offset_right = -220
	_typing_line.offset_bottom = -206
	_typing_line.add_theme_font_size_override("normal_font_size", _ui_font_size_fn.call(30))
	_typing_line.add_theme_color_override("default_color", _theme_color_fn.call("surface"))
	_typing_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_typing_line.z_index = 15
	parent.add_child(_typing_line)

	_typing_progress = _label_factory.call("", 14, _theme_color_fn.call("muted")) as Label
	_typing_progress.name = "RealityTypingProgress"
	_typing_progress.set_meta("on_dark", true)
	_typing_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_typing_progress.offset_left = 520
	_typing_progress.offset_top = -210
	_typing_progress.offset_right = -460
	_typing_progress.offset_bottom = -184
	_typing_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_typing_progress.z_index = 15
	parent.add_child(_typing_progress)

	_subtitle_panel = PanelContainer.new()
	_subtitle_panel.name = "RealitySubtitlePanel"
	_subtitle_panel.set_meta("movie_subtitle", true)
	_subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle_panel.offset_left = 360
	_subtitle_panel.offset_top = -178
	_subtitle_panel.offset_right = -300
	_subtitle_panel.offset_bottom = -104
	_subtitle_panel.z_index = 14
	parent.add_child(_subtitle_panel)
	var subtitle_box := HBoxContainer.new()
	subtitle_box.add_theme_constant_override("separation", 12)
	_subtitle_panel.add_child(subtitle_box)
	_subtitle_label = RicherTextLabelScript.new()
	_install_rich_text_effect_fn.call(_subtitle_label, "curspull")
	_subtitle_label.name = "RealitySubtitleLabel"
	_subtitle_label.bbcode_enabled = true
	_subtitle_label.fit_content = false
	_subtitle_label.scroll_active = false
	_subtitle_label.set_meta("on_dark", true)
	_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle_label.add_theme_font_size_override("normal_font_size", _ui_font_size_fn.call(20))
	_subtitle_label.add_theme_color_override("default_color", _theme_color_fn.call("surface"))
	_subtitle_label.add_theme_color_override("font_outline_color", Color("050705"))
	_subtitle_label.add_theme_constant_override("outline_size", 6)
	subtitle_box.add_child(_subtitle_label)
	_continue_button = Button.new()
	_continue_button.name = "RealityConversationContinue"
	_continue_button.text = "结束"
	_continue_button.custom_minimum_size = Vector2(92, 48)
	_continue_button.pressed.connect(_on_continue_pressed)
	subtitle_box.add_child(_continue_button)
	_hide_all()


func _on_choice_hovered(choice_id: String) -> void:
	choice_hovered.emit(choice_id)


func _on_choice_unhovered(choice_id: String) -> void:
	choice_unhovered.emit(choice_id)


func _on_choice_pressed(choice_id: String) -> void:
	choice_pressed.emit(choice_id)


func _on_continue_pressed() -> void:
	continue_pressed.emit()
