extends Node
class_name NarrativeOverlayDirector
## Plays one narrative beat: the pollution flashback.
## The host supplies the settlement result and whether the ending is unlocked.
## While in the tree it subscribes to FLASHBACK_FINISHED: the pollution flashback director raises it when the
## timeline ends, and this director closes the flashback and moves the beat on.

const NarrativeBeatScript = preload("res://scripts/game/narrative_beat.gd")
const FlashbackOverlayPanelScript = preload("res://scripts/ui/flashback_overlay_panel.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")

var flashback_panel: FlashbackOverlayPanel
var flashback_overlay: Control

var _host: Node
var _deps: Dictionary = {}
var _beat = null
var _installed_presentation := false
var _event_bus: GameEventBus


func attach_to(host: Node) -> void:
	_host = host
	name = "NarrativeOverlayDirector"
	host.add_child(self)


## The host binds the bus in its own _enter_tree, which runs before this one.
func _enter_tree() -> void:
	_event_bus = GameEventBusScript.bound()
	if _event_bus != null:
		_event_bus.subscribe(GameEventsScript.FLASHBACK_FINISHED, _on_flashback_finished)


func _exit_tree() -> void:
	if _event_bus != null:
		_event_bus.unsubscribe(GameEventsScript.FLASHBACK_FINISHED, _on_flashback_finished)
	_event_bus = null


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
	if flashback_panel != null and is_instance_valid(flashback_panel):
		flashback_panel.stop()


func reset_session() -> void:
	_beat = null
	_installed_presentation = false


func build_flashback_overlay() -> void:
	_ensure_flashback_panel()
	var ui_root := _deps.get("ui_root") as Control
	if flashback_panel == null or ui_root == null:
		return
	flashback_panel.mount(ui_root)
	_sync_flashback_refs()
	flashback_panel.build_phases()


func play_beat(settlement: Dictionary, ending_unlocked: bool) -> void:
	_beat = NarrativeBeatScript.new()
	_beat.play(settlement, ending_unlocked)
	if _beat.is_finished():
		_beat = null
		return
	_request_narrative()
	if not consume_installed_presentation():
		_play_beat_segment()


func play_pollution_flashback() -> void:
	if _beat == null or _beat.is_finished():
		if flashback_panel == null:
			return
		play_beat({"flashback": true}, _ending_unlocked_now())
		return
	if _beat.current_segment() == "flashback":
		_play_flashback_visual()


## Only a finish heard while the beat is on its flashback moves the beat on.
func _on_flashback_finished(_payload: Dictionary) -> void:
	var on_segment: bool = _beat != null and str(_beat.current_segment()) == "flashback"
	_stop_flashback_presentation()
	if not on_segment:
		return
	_advance_beat()


func _play_beat_segment() -> void:
	if _beat == null or _beat.is_finished():
		_finish_beat()
		return
	var played := false
	if str(_beat.current_segment()) == "flashback":
		played = _play_flashback_visual()
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
	if exit_mode.is_empty():
		return
	var complete: Callable = _deps.get("complete_beat", Callable())
	if complete.is_valid():
		complete.call(exit_mode)


func _play_flashback_visual() -> bool:
	if flashback_panel == null:
		return false
	flashback_panel.refresh_colors()
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


func _ensure_flashback_panel() -> void:
	if flashback_panel != null and is_instance_valid(flashback_panel):
		return
	flashback_panel = FlashbackOverlayPanelScript.new()
	flashback_panel.name = "FlashbackOverlayPanel"
	_host.add_child(flashback_panel)


func _sync_flashback_refs() -> void:
	if flashback_panel == null:
		return
	flashback_overlay = flashback_panel.get_overlay()


func _request_narrative() -> void:
	var callback: Callable = _deps.get("request_narrative", Callable())
	if callback.is_valid():
		callback.call()


func _ending_unlocked_now() -> bool:
	var reader: Callable = _deps.get("ending_unlocked", Callable())
	if not reader.is_valid():
		return false
	return bool(reader.call())


func _audio_call(method_name: String) -> void:
	var audio: Variant = _deps.get("audio")
	if audio != null and audio.has_method(method_name):
		audio.call(method_name)


func _duck_ambience() -> void:
	_audio_call("duck_ambience_for_flashback")


func _play_flashback_audio() -> void:
	_audio_call("play_flashback")


func _stop_flashback_audio() -> void:
	_audio_call("stop_flashback")
