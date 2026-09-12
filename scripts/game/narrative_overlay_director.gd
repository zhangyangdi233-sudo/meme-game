extends Node
class_name NarrativeOverlayDirector
## Day-transition tween, action-spend overlay glue, and flashback start/finish
## coordination. MemeGameState intents and `_render()` stay on the adapter.

const ActionSpendPanelScript = preload("res://scripts/ui/action_spend_panel.gd")
const DayTransitionPanelScript = preload("res://scripts/ui/day_transition_panel.gd")
const FlashbackOverlayPanelScript = preload("res://scripts/ui/flashback_overlay_panel.gd")

var action_spend_panel: ActionSpendPanel
var action_spend_overlay: Control
var action_spend_should_settle := false
var day_transition_panel: DayTransitionPanel
var day_transition_overlay: Control
var day_transition_day_label: Label
var day_transition_meta_label: Label
var day_transition_hint_label: Label
var day_transition_rule: ColorRect
var day_transition_tween: Tween
var day_transition_settled := false
var flashback_panel: FlashbackOverlayPanel
var flashback_overlay: Control

var _host: Node
var _deps: Dictionary = {}


func attach_to(host: Node) -> void:
	_host = host
	name = "NarrativeOverlayDirector"
	host.add_child(self)


func apply_deps(deps: Dictionary) -> void:
	if not deps.is_empty():
		_deps = deps


func reset_session() -> void:
	if action_spend_panel != null and is_instance_valid(action_spend_panel):
		action_spend_panel.reset_state()
	action_spend_should_settle = false
	day_transition_settled = false
	kill_day_transition_tween()


func kill_day_transition_tween() -> void:
	if day_transition_tween != null and day_transition_tween.is_valid():
		day_transition_tween.kill()
	day_transition_tween = null


func apply_input_lock_filters(locked: bool) -> void:
	if flashback_overlay != null:
		flashback_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if locked else Control.MOUSE_FILTER_IGNORE
	if action_spend_overlay != null:
		action_spend_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if locked and action_spend_overlay.visible else Control.MOUSE_FILTER_IGNORE
	if day_transition_overlay != null:
		day_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if locked and day_transition_overlay.visible else Control.MOUSE_FILTER_IGNORE


func build_action_spend_overlay() -> void:
	_ensure_action_spend_panel()
	var ui_root := _deps.get("ui_root") as Control
	if action_spend_panel == null or ui_root == null:
		return
	action_spend_panel.mount(ui_root, {
		"hud_actions_label": _hud_actions_label(),
		"action_text": _deps.get("action_text", Callable()),
		"theme_color": _deps.get("theme_color", Callable()),
		"ui_font_size": _deps.get("ui_font_size", Callable()),
		"on_animation_finished": finish_action_spend_animation,
	})
	_sync_action_spend_refs()


func build_day_transition_overlay() -> void:
	_ensure_day_transition_panel()
	var ui_root := _deps.get("ui_root") as Control
	if day_transition_panel == null or ui_root == null:
		return
	day_transition_panel.mount(ui_root, {
		"label_factory": _deps.get("label_factory", Callable()),
		"theme_color": _deps.get("theme_color", Callable()),
		"level_display_name": _deps.get("level_display_name", Callable()),
	})
	_sync_day_transition_refs()


func build_flashback_overlay() -> void:
	_ensure_flashback_panel()
	var ui_root := _deps.get("ui_root") as Control
	if flashback_panel == null or ui_root == null:
		return
	flashback_panel.mount(ui_root, {
		"theme_color": _deps.get("theme_color", Callable()),
		"on_sequence_finished": finish_pollution_flashback,
	})
	_sync_flashback_refs()
	flashback_panel.build_phases()


func play_action_spend_animation(before_actions: int, after_actions: int) -> void:
	if _hud_actions_label() == null or action_spend_panel == null:
		return
	var play_tick: Callable = _deps.get("play_action_tick", Callable())
	if play_tick.is_valid():
		play_tick.call()
	var game: Variant = _deps.get("game")
	action_spend_should_settle = game != null and bool(game.needs_day_settlement)
	_request_narrative()
	_set_input_locked(true)
	action_spend_panel.play(before_actions, after_actions)


func finish_action_spend_animation() -> void:
	var after_actions := -1
	if action_spend_panel != null and is_instance_valid(action_spend_panel):
		after_actions = action_spend_panel.finish()
	var should_transition := action_spend_should_settle
	action_spend_should_settle = false
	if should_transition:
		play_day_transition()
		return
	_set_input_locked(false)
	_sync_audio(false)
	_render()
	_request_gameplay_from_narrative()
	var hud_actions_label := _hud_actions_label()
	var action_text: Callable = _deps.get("action_text", Callable())
	if hud_actions_label != null and after_actions >= 0 and action_text.is_valid():
		hud_actions_label.text = action_text.call(after_actions)


func update_floor_transition_card(floor_number: int) -> void:
	if day_transition_panel != null and is_instance_valid(day_transition_panel):
		day_transition_panel.refresh_copy(floor_number)


func play_day_transition() -> void:
	if day_transition_overlay == null:
		_settle_day()
		_set_input_locked(false)
		_render()
		_request_gameplay_from_narrative()
		return
	kill_day_transition_tween()
	day_transition_settled = false
	_request_narrative()
	_set_input_locked(true)
	if day_transition_panel != null:
		day_transition_panel.prepare_show()
	update_floor_transition_card(_tower_floor())
	if not is_inside_tree():
		return
	day_transition_tween = create_tween()
	day_transition_tween.set_parallel(true)
	day_transition_tween.tween_property(day_transition_overlay, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	day_transition_tween.tween_property(day_transition_rule, "scale:x", 1.0, 0.72).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	day_transition_tween.set_parallel(false)
	day_transition_tween.tween_property(day_transition_day_label, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	day_transition_tween.tween_interval(0.55)
	day_transition_tween.tween_callback(commit_day_transition_settlement)
	day_transition_tween.tween_interval(0.95)
	day_transition_tween.tween_property(day_transition_overlay, "modulate:a", 0.0, 0.80).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	day_transition_tween.tween_callback(finish_day_transition)


func commit_day_transition_settlement() -> void:
	if day_transition_settled:
		return
	day_transition_settled = true
	if _settle_day():
		_notify_day_settled(false)
	update_floor_transition_card(_tower_floor())


func finish_day_transition() -> void:
	kill_day_transition_tween()
	if not day_transition_settled:
		commit_day_transition_settlement()
	if day_transition_panel != null and is_instance_valid(day_transition_panel):
		day_transition_panel.hide_overlay()
	_set_input_locked(false)
	_sync_audio(false)
	_render()
	_request_gameplay_from_narrative()


func play_pollution_flashback() -> void:
	if flashback_panel == null:
		return
	_request_narrative()
	_set_input_locked(true)
	var theme_color: Callable = _deps.get("theme_color", Callable())
	if theme_color.is_valid():
		flashback_panel.configure_colors({
			"ink": theme_color.call("ink"),
			"surface": theme_color.call("surface"),
			"flash_text": theme_color.call("flash_text"),
		})
	flashback_panel.build_phases()
	var capture: Callable = _deps.get("capture_frozen_frame", Callable())
	var frozen_texture: Texture2D = null
	if capture.is_valid():
		frozen_texture = capture.call() as Texture2D
	var duck: Callable = _deps.get("duck_ambience", Callable())
	if duck.is_valid():
		duck.call()
	var play_audio: Callable = _deps.get("play_flashback_audio", Callable())
	if play_audio.is_valid():
		play_audio.call()
	flashback_panel.play(frozen_texture)


func finish_pollution_flashback() -> void:
	if flashback_panel != null and is_instance_valid(flashback_panel):
		flashback_panel.stop()
	var stop_audio: Callable = _deps.get("stop_flashback_audio", Callable())
	if stop_audio.is_valid():
		stop_audio.call()
	_set_input_locked(false)
	var consume: Callable = _deps.get("consume_pollution_flashback", Callable())
	var should_settle: bool = bool(consume.call()) if consume.is_valid() else false
	if should_settle and _settle_day():
		_notify_day_settled(true)
	_sync_audio(false)
	_render()
	_request_gameplay_from_narrative()


func _ensure_action_spend_panel() -> void:
	if action_spend_panel != null and is_instance_valid(action_spend_panel):
		return
	action_spend_panel = ActionSpendPanelScript.new()
	action_spend_panel.name = "ActionSpendPanel"
	_host.add_child(action_spend_panel)


func _ensure_day_transition_panel() -> void:
	if day_transition_panel != null and is_instance_valid(day_transition_panel):
		return
	day_transition_panel = DayTransitionPanelScript.new()
	day_transition_panel.name = "DayTransitionPanel"
	_host.add_child(day_transition_panel)


func _ensure_flashback_panel() -> void:
	if flashback_panel != null and is_instance_valid(flashback_panel):
		return
	flashback_panel = FlashbackOverlayPanelScript.new()
	flashback_panel.name = "FlashbackOverlayPanel"
	_host.add_child(flashback_panel)


func _sync_action_spend_refs() -> void:
	if action_spend_panel == null:
		return
	action_spend_overlay = action_spend_panel.get_overlay()
	action_spend_panel.update_hud_label_ref(_hud_actions_label())


func _sync_day_transition_refs() -> void:
	if day_transition_panel == null:
		return
	day_transition_overlay = day_transition_panel.get_overlay()
	day_transition_day_label = day_transition_panel.get_day_label()
	day_transition_meta_label = day_transition_panel.get_meta_label()
	day_transition_hint_label = day_transition_panel.get_hint_label()
	day_transition_rule = day_transition_panel.get_rule()


func _sync_flashback_refs() -> void:
	if flashback_panel == null:
		return
	flashback_overlay = flashback_panel.get_overlay()


func _hud_actions_label() -> Label:
	var getter: Callable = _deps.get("hud_actions_label", Callable())
	return getter.call() as Label if getter.is_valid() else null


func _tower_floor() -> int:
	var snapshot_fn: Callable = _deps.get("day_progress", Callable())
	if snapshot_fn.is_valid():
		return int(snapshot_fn.call().get("tower_floor", 1))
	return 1


func _request_narrative() -> void:
	var callback: Callable = _deps.get("request_narrative", Callable())
	if callback.is_valid():
		callback.call()


func _request_gameplay_from_narrative() -> void:
	var callback: Callable = _deps.get("request_gameplay_from_narrative", Callable())
	if callback.is_valid():
		callback.call()


func _set_input_locked(value: bool) -> void:
	var callback: Callable = _deps.get("set_input_locked", Callable())
	if callback.is_valid():
		callback.call(value)


func _sync_audio(immediate: bool) -> void:
	var callback: Callable = _deps.get("sync_audio_state", Callable())
	if callback.is_valid():
		callback.call(immediate)


func _render() -> void:
	var callback: Callable = _deps.get("render", Callable())
	if callback.is_valid():
		callback.call()


func _settle_day() -> bool:
	var callback: Callable = _deps.get("settle_day", Callable())
	return bool(callback.call()) if callback.is_valid() else false


func _notify_day_settled(from_flashback: bool) -> void:
	var key := "on_flashback_settled" if from_flashback else "on_day_settled"
	var callback: Callable = _deps.get(key, Callable())
	if callback.is_valid():
		callback.call()
