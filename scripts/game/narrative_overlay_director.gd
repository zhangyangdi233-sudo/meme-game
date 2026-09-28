extends Node
class_name NarrativeOverlayDirector
## Plays one narrative beat: action spend, day transition, then flashback.
## The host supplies the settlement result and whether the ending is unlocked.

const NarrativeBeatScript = preload("res://scripts/game/narrative_beat.gd")
const ActionSpendPanelScript = preload("res://scripts/ui/action_spend_panel.gd")
const DayTransitionPanelScript = preload("res://scripts/ui/day_transition_panel.gd")
const FlashbackOverlayPanelScript = preload("res://scripts/ui/flashback_overlay_panel.gd")

var action_spend_panel: ActionSpendPanel
var action_spend_overlay: Control
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
var _beat = null
var _beat_settlement: Dictionary = {}
var _installed_presentation := false


func attach_to(host: Node) -> void:
	_host = host
	name = "NarrativeOverlayDirector"
	host.add_child(self)


func apply_deps(deps: Dictionary) -> void:
	if not deps.is_empty():
		_deps = deps


func present_installed_screen() -> void:
	_installed_presentation = true
	_play_beat_segment()


func consume_installed_presentation() -> bool:
	var presented := _installed_presentation
	_installed_presentation = false
	return presented


func dismiss_installed_screen() -> void:
	kill_day_transition_tween()
	if action_spend_panel != null and is_instance_valid(action_spend_panel):
		action_spend_panel.finish()
	if day_transition_panel != null and is_instance_valid(day_transition_panel):
		day_transition_panel.hide_overlay()
	if flashback_panel != null and is_instance_valid(flashback_panel):
		flashback_panel.stop()


func reset_session() -> void:
	if action_spend_panel != null and is_instance_valid(action_spend_panel):
		action_spend_panel.reset_state()
	day_transition_settled = false
	_beat = null
	_beat_settlement = {}
	_installed_presentation = false
	kill_day_transition_tween()


func kill_day_transition_tween() -> void:
	if day_transition_tween != null and day_transition_tween.is_valid():
		day_transition_tween.kill()
	day_transition_tween = null


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


func play_beat(settlement: Dictionary, ending_unlocked: bool) -> void:
	_beat = NarrativeBeatScript.new()
	_beat_settlement = settlement.duplicate()
	_beat.play(settlement, ending_unlocked)
	if _beat.is_finished():
		_beat = null
		_beat_settlement = {}
		return
	_request_narrative()
	if not consume_installed_presentation():
		_play_beat_segment()


func play_action_spend_animation(before_actions: int, after_actions: int) -> void:
	if _beat == null or _beat.is_finished():
		if _hud_actions_label() == null or action_spend_panel == null:
			return
		var game: Variant = _deps.get("game")
		play_beat({
			"actions_before": before_actions,
			"actions_after": after_actions,
			"day_transition": game != null and bool(game.needs_day_settlement),
			"flashback": false,
		}, _ending_unlocked_now())
		return
	_play_action_spend_visual(before_actions, after_actions)


func finish_action_spend_animation() -> void:
	var after_actions := -1
	if action_spend_panel != null and is_instance_valid(action_spend_panel):
		after_actions = action_spend_panel.finish()
	_apply_action_label(after_actions)
	if _beat != null and _beat.current_segment() == "action_spend":
		_advance_beat()


func update_floor_transition_card(floor_number: int) -> void:
	if day_transition_panel != null and is_instance_valid(day_transition_panel):
		day_transition_panel.refresh_copy(floor_number)


func play_day_transition() -> void:
	if _beat == null or _beat.is_finished():
		play_beat({"day_transition": true}, _ending_unlocked_now())
		return
	if _beat.current_segment() == "day_transition":
		_play_day_transition_visual()


func commit_day_transition_settlement() -> void:
	if day_transition_settled:
		return
	day_transition_settled = true
	_settle_day(false)
	update_floor_transition_card(_tower_floor())


func finish_day_transition() -> void:
	kill_day_transition_tween()
	if not day_transition_settled:
		commit_day_transition_settlement()
	if day_transition_panel != null and is_instance_valid(day_transition_panel):
		day_transition_panel.hide_overlay()
	if _beat != null and _beat.current_segment() == "day_transition":
		_advance_beat()


func play_pollution_flashback() -> void:
	if _beat == null or _beat.is_finished():
		if flashback_panel == null:
			return
		play_beat({"flashback": true}, _ending_unlocked_now())
		return
	if _beat.current_segment() == "flashback":
		_play_flashback_visual()


func finish_pollution_flashback() -> void:
	var on_segment: bool = _beat != null and str(_beat.current_segment()) == "flashback"
	_stop_flashback_presentation()
	if not on_segment:
		return
	_settle_day(true)
	_advance_beat()


func _play_beat_segment() -> void:
	if _beat == null or _beat.is_finished():
		_finish_beat()
		return
	var played := false
	match str(_beat.current_segment()):
		"action_spend":
			played = _play_action_spend_visual(
				int(_beat_settlement.get("actions_before", 0)),
				int(_beat_settlement.get("actions_after", 0))
			)
		"day_transition":
			played = _play_day_transition_visual()
		"flashback":
			played = _play_flashback_visual()
		_:
			played = false
	if not played:
		_advance_beat()


func _advance_beat() -> void:
	if _beat == null or _beat.is_finished():
		return
	if _beat.is_last_segment():
		_beat.note_ending_unlocked(_ending_unlocked_now())
	_beat.advance()
	if _beat.is_finished():
		_finish_beat()
	else:
		_play_beat_segment()


func _finish_beat() -> void:
	var exit_mode := ""
	if _beat != null:
		exit_mode = str(_beat.exit_mode())
	_beat = null
	_beat_settlement = {}
	if exit_mode.is_empty():
		return
	var complete: Callable = _deps.get("complete_beat", Callable())
	if complete.is_valid():
		complete.call(exit_mode)


func _play_action_spend_visual(before_actions: int, after_actions: int) -> bool:
	if _hud_actions_label() == null or action_spend_panel == null:
		return false
	_play_action_tick()
	action_spend_panel.play(before_actions, after_actions)
	return true


func _play_day_transition_visual() -> bool:
	if day_transition_overlay == null:
		commit_day_transition_settlement()
		return false
	kill_day_transition_tween()
	day_transition_settled = false
	if day_transition_panel != null:
		day_transition_panel.prepare_show()
	update_floor_transition_card(_tower_floor())
	if not is_inside_tree():
		return false
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
	return true


func _play_flashback_visual() -> bool:
	if flashback_panel == null:
		return false
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
	_duck_ambience()
	_play_flashback_audio()
	flashback_panel.play(frozen_texture)
	return true


func _stop_flashback_presentation() -> void:
	if flashback_panel != null and is_instance_valid(flashback_panel):
		flashback_panel.stop()
	_stop_flashback_audio()


func _apply_action_label(after_actions: int) -> void:
	var hud_actions_label := _hud_actions_label()
	var action_text: Callable = _deps.get("action_text", Callable())
	if hud_actions_label != null and after_actions >= 0 and action_text.is_valid():
		hud_actions_label.text = action_text.call(after_actions)


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


func _ending_unlocked_now() -> bool:
	var reader: Callable = _deps.get("ending_unlocked", Callable())
	if not reader.is_valid():
		return false
	return bool(reader.call())


func _settle_day(from_flashback: bool) -> bool:
	var callback: Callable = _deps.get("settle_day", Callable())
	if not callback.is_valid():
		return false
	return bool(callback.call(from_flashback))


func _audio_call(method_name: String) -> void:
	var audio: Variant = _deps.get("audio")
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _play_action_tick() -> void:
	_audio_call("play_action_tick")


func _duck_ambience() -> void:
	_audio_call("duck_ambience_for_flashback")


func _play_flashback_audio() -> void:
	_audio_call("play_flashback")


func _stop_flashback_audio() -> void:
	_audio_call("stop_flashback")
