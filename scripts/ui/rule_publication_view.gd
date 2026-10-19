extends Control
## Transient confirmation follows the shared pickup layer into the physical CRT.
## The saved publication/world rule remain owned by game state, never by this view.

signal feed_requested

const Rules = preload("res://scripts/narrative/rule_engine.gd")
const PAPER := Color("fff1c9")
const CURRENT := Color("624047")
const HISTORY := Color("55564d")
const HOLD_SECONDS := 1.65

var active := false
var _motion: Tween
var _card: Panel
var _shade: ColorRect
var _heading: Label
var _sentence: Label
var _target: Callable


static func describe(publications: Array, index: int, world_rules: Dictionary, locale: String) -> Dictionary:
	var post: Dictionary = publications[index]
	var key := str(post.get("rule_key", ""))
	if post.get("tier", "") != "rule" or not Rules.SUPPORTED_RULES.has(key):
		return {"is_rule": false}
	var current := world_rules.has(key)
	if current:
		current = bool(world_rules[key].get("negated", false)) == bool(post.get("negated", false))
	for newer in range(index):
		if publications[newer] is Dictionary and publications[newer].get("tier", "") == "rule" and publications[newer].get("rule_key", "") == key:
			current = false
			break
	return {
		"is_rule": true, "rule_key": key, "rule_current": current,
		"negated": bool(post.get("negated", false)),
		"rule_text": Rules.rule_display_text(key, bool(post.get("negated", false)), locale),
		"rule_status": status_text(current, locale),
	}


static func status_text(current: bool, locale: String) -> String:
	match locale:
		"ja": return "現在のルール" if current else "以前のルール"
		"en": return "CURRENT RULE" if current else "PREVIOUS RULE"
		_: return "现行规则" if current else "已替代的规则"


static func card_style(current: bool, poster: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (CURRENT if current else HISTORY) if poster else (Color("eed5c2") if current else Color("d1ccba"))
	style.border_color = Color("ba8b7a") if current else Color("858578")
	style.set_border_width_all(2 if current else 1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _ready() -> void:
	name = "RulePublicationReveal"
	set_meta("rule_presentation_theme", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10
	_shade = ColorRect.new()
	_shade.color = Color(0.015, 0.018, 0.015, 0.62)
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card = Panel.new()
	_card.name = "RuleRevealCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := card_style(true, true)
	style.set_content_margin_all(24)
	_card.add_theme_stylebox_override("panel", style)
	add_child(_card)
	_heading = _make_label("RuleRevealStatus")
	_card.add_child(_heading)
	_sentence = _make_label("RuleRevealText")
	_card.add_child(_sentence)
	visible = false


func _make_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.set_meta("skip_localization", true)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", PAPER)
	return label


func present(text: String, locale: String, target: Callable) -> void:
	cancel()
	_target = target
	_heading.text = {"zh": "规则已改变", "ja": "ルールが変わった", "en": "THE RULE HAS CHANGED"}.get(locale, "规则已改变")
	_sentence.text = text
	_heading.add_theme_font_size_override("font_size", clampi(roundi(size.x * 0.018), 18, 28))
	_sentence.add_theme_font_size_override("font_size", clampi(roundi(size.x * 0.046), 30, 72))
	_card.size = Vector2(minf(size.x * 0.80, 980), minf(size.y * 0.44, 380))
	_heading.position = Vector2(24, 24)
	_heading.size = Vector2(_card.size.x - 48, 40)
	_sentence.position = Vector2(28, 84)
	_sentence.size = Vector2(_card.size.x - 56, _card.size.y - 108)
	# Wrapped labels first measure at their previous (initially zero) width.
	# Reapply the fixed bounds once shaping has consumed the new width.
	_heading.set_deferred("size", Vector2(_card.size.x - 48, 40))
	_sentence.set_deferred("size", Vector2(_card.size.x - 56, _card.size.y - 108))
	_card.pivot_offset = _card.size * 0.5
	_card.position = (size - _card.size) * 0.5 + Vector2(0, 40)
	_card.scale = Vector2.ONE * 0.84
	_card.modulate.a = 0.0
	_shade.modulate.a = 0.0
	visible = true
	active = true
	_motion = create_tween()
	_motion.set_parallel(true)
	_motion.tween_property(_card, "position:y", (size.y - _card.size.y) * 0.5, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_card, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_motion.tween_property(_card, "modulate:a", 1.0, 0.20)
	_motion.tween_property(_shade, "modulate:a", 1.0, 0.24)
	_motion.chain().tween_interval(HOLD_SECONDS)
	_motion.chain().tween_callback(_land)


func _land() -> void:
	feed_requested.emit()
	# Wait for the feed containers to settle before tracking the rule card.
	_motion = create_tween()
	_motion.tween_interval(0.06)
	_motion.tween_method(_glide.bind(_card.position), 0.0, 1.0, 0.40).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_motion.parallel().tween_property(_card, "scale", Vector2.ONE * 0.18, 0.40)
	_motion.parallel().tween_property(_card, "modulate:a", 0.0, 0.40)
	_motion.parallel().tween_property(_shade, "modulate:a", 0.0, 0.40)
	_motion.tween_callback(cancel)


func _glide(progress: float, origin: Vector2) -> void:
	var destination := size * Vector2(0.35, 0.3)
	if _target.is_valid():
		destination = get_global_transform().affine_inverse() * Vector2(_target.call())
	_card.position = origin.lerp(destination - _card.pivot_offset, progress)


func cancel() -> void:
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = null
	active = false
	visible = false
