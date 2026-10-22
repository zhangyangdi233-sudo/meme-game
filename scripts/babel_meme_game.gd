extends Node3D

const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const RicherTextLabelScript = preload("res://addons/richtext2/richer_text_label.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const SocialFeedCatalogScript = preload("res://scripts/game/social_feed_catalog.gd")
const NarrativeSessionCatalogScript = preload("res://scripts/game/narrative_session_catalog.gd")
const CinematicBarsScript = preload("res://framework/ui/cinematic_bars.gd")
const VhsOverlayScript = preload("res://framework/ui/vhs_overlay.gd")
const DraggableWindowManagerScript = preload("res://framework/ui/draggable_window_manager.gd")
const EdgeDrawerScript = preload("res://framework/ui/edge_drawer.gd")
const SettingsHistoryPanelScript = preload("res://scripts/ui/settings_history_panel.gd")
const SocialFeedPanelScript = preload("res://scripts/ui/social_feed_panel.gd")
const ScreenManagerScript = preload("res://scripts/ui/screen_manager.gd")
const GameEventBusScript = preload("res://scripts/ui/game_event_bus.gd")
const MainMenuScreenScript = preload("res://scripts/ui/main_menu_screen.gd")
const DialogScreenScript = preload("res://scripts/ui/dialog_screen.gd")
const DialogDebugPanelScene = preload("res://scenes/ui/dialog_debug_panel.tscn")
const SaveSlotScript = preload("res://scripts/game/save_slot.gd")
const LanguageSelectionPanelScript = preload("res://scripts/ui/language_selection_panel.gd")
const OpeningNarrationPanelScript = preload("res://scripts/ui/opening_narration_panel.gd")
const ChapterOneProgressScript = preload("res://scripts/game/chapter_one_progress.gd")
const CameraConsentPanelScript = preload("res://scripts/ui/camera_consent_panel.gd")
const PhoneCameraConnectionPanelScript = preload("res://scripts/ui/phone_camera_connection_panel.gd")
const PhoneLauncherPanelScript = preload("res://scripts/ui/phone_launcher_panel.gd")
const RealityConversationPanelScript = preload("res://scripts/ui/reality_conversation_panel.gd")
const NotebookAppPanelScript = preload("res://scripts/ui/notebook_app_panel.gd")
const EndingScreenPanelScript = preload("res://scripts/ui/ending_screen_panel.gd")
const AppleHudPanelScript = preload("res://scripts/ui/apple_hud_panel.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const CameraSessionScript = preload("res://scripts/integrations/camera_session.gd")
const HandTrackingStatusScript = preload("res://framework/integrations/hand_tracking_status.gd")
const GameAudioControllerScript = preload("res://scripts/integrations/game_audio_controller.gd")
const GameSocialFeedSourceScript = preload("res://scripts/game/game_social_feed_source.gd")
const RuntimeTextureCacheScript = preload("res://scripts/game/runtime_texture_cache.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const CoverWatcherSightingsScript = preload("res://scripts/game/cover_watcher_sightings.gd")
const LanguagePresenterScript = preload("res://scripts/game/language_presenter.gd")
const GameEventsScript = preload("res://scripts/game_events.gd")
const IntentResultScript = preload("res://scripts/game/intent_result.gd")
const SocialIntentHandlerScript = preload("res://scripts/game/social_intent_handler.gd")
const NotebookIntentHandlerScript = preload("res://scripts/game/notebook_intent_handler.gd")
const SettingsIntentHandlerScript = preload("res://scripts/game/settings_intent_handler.gd")
const GameModelsScript = preload("res://scripts/game/game_models.gd")
const NarrativeOverlayDirectorScript = preload("res://scripts/game/narrative_overlay_director.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const DeskLogLabelScript = preload("res://scripts/ui/desk_log_label.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const UiIntentsScript = preload("res://scripts/ui_intents.gd")
const FlowManagerScript = preload("res://framework/flow/flow_manager.gd")
const MainMenuFlowStateScript = preload("res://scripts/game/flow/main_menu_flow_state.gd")
const PrologueFlowStateScript = preload("res://scripts/game/flow/prologue_flow_state.gd")
const GameplayFlowStateScript = preload("res://scripts/game/flow/gameplay_flow_state.gd")
const NarrativeFlowStateScript = preload("res://scripts/game/flow/narrative_flow_state.gd")
const EndingFlowStateScript = preload("res://scripts/game/flow/ending_flow_state.gd")
const ActionOutcomeScript = preload("res://scripts/game/action_outcome.gd")

const PHONE_DOWN_BACKDROP_PATH := "res://assets/generated/world/phone_down_backdrop.png"
const GUIDE_DOLL_CHARACTER_PATH := "res://assets/generated/characters/guide_doll.png"
const NPC_CHARACTER_PATHS := [
	"res://assets/generated/characters/npc_late_arrival.png",
	"res://assets/generated/characters/npc_echo_tenant.png",
	"res://assets/generated/characters/npc_archive_witness.png",
]
const HUD_POLLUTION_ICON_PATH := "res://assets/generated/ui/hud_pollution_icon.png"
const HUD_SETTINGS_ICON_PATH := "res://assets/generated/ui/hud_settings_icon.png"
const PHONE_LAUNCHER_WALLPAPER_PATH := "res://assets/generated/1/IMG_4835.PNG"
const REALITY_MOUSE_SENSITIVITY := 0.064
const REALITY_TOUCH_SENSITIVITY := 0.082
const REALITY_TRACKPAD_SENSITIVITY := 1.8
# 点阵字体(Boutique Bitmap 9x9,OFL):三语共用一套字形,字号必须吸附到 9 的整数倍。
const UI_FONT_PATH := "res://assets/fonts/BoutiqueBitmap9x9.ttf"
const UI_FONT_GRID := 9
const UI_FONT_MIN_SIZE := 9
const UI_FONT_MAX_SIZE := 45
const CINEMATIC_ASPECT_RATIO := 2.35
const CINEMATIC_MAX_BAR_RATIO := 0.12
const HUD_RAIL_WIDTH := 158.0
const HUD_RAIL_MAX_HEIGHT := 700.0
const HUD_RAIL_FRAME_MARGIN := 10.0
const HUD_DRAWER_EDGE_HIT_WIDTH := 44.0
const HUD_DRAWER_EDGE_CUE_WIDTH := 5.0
const HUD_DRAWER_OPEN_DURATION := 0.26
const HUD_DRAWER_CLOSE_DURATION := 0.18
const HUD_DRAWER_CLOSE_DELAY := 0.22
const SAVE_PATH := "user://babel_meme_save.dat"
const SAVE_FILE_VERSION := 1
const WORLD_HOTKEY_ACTIONS := [
	"reality_forward",
	"reality_back",
	"reality_left",
	"reality_right",
	"reality_sprint",
	"reality_interact",
	"reality_phone",
]


var game: MemeGameState = MemeGameStateScript.new()
var _locale = GameLocaleScript.new()
var _phone_sway_time := 0.0

var _camera: Camera3D
var _reality_scene_adapter
var _reality_mouse_look_enabled := false
var _reality_touch_look_index := -1
var _canvas: CanvasLayer
var _ui_root: Control
var _textures: RuntimeTextureCache = RuntimeTextureCacheScript.new()
var _phone_down_backdrop_image: TextureRect
var _hand_phone_image: TextureRect
var _camera_session
var _audio_controller
var _narrative_director: NarrativeOverlayDirector
var _ui_theme_helper := GameUiThemeScript.new()
var _camera_consent_overlay: Control
var _camera_access_toggle: CheckButton
var _camera_consent_source_option: OptionButton
var _camera_computer_button: Button
var _camera_phone_button: Button
var _camera_source_button_group: ButtonGroup
var _camera_status_label: Label
var _phone_camera_connection_overlay: Control
var _phone_camera_connection_panel: PhoneCameraConnectionPanel
var _cinematic_bars: CinematicBars
var _apple_hud_panel: AppleHudPanel
var _edge_drawer: EdgeDrawer
var _world_prompt: Label
var _desk_log: DeskLogLabelScript
var _screen_manager: ScreenManager
var _dialog_manager: ScreenManager
var _dialog_debug_panel: DialogDebugPanel
var _ui_event_bus: GameEventBus
var _language_selection_panel: LanguageSelectionPanel
var _opening_narration_panel: OpeningNarrationPanel
## Black cover over the white door opening; it darkens as the door finishes and lifts in the next stage.
var _door_fade: ColorRect
var _door_was_opening := false
var _camera_consent_panel: CameraConsentPanel
var _settings_window: PanelContainer
var _settings_history_panel: SettingsHistoryPanel
var _social_feed_panel: SocialFeedPanel
var _social_source: GameSocialFeedSource
var _language_material: LanguageMaterial
var _cover_watcher_sightings: CoverWatcherSightings =CoverWatcherSightingsScript.new()
var _language_presenter: LanguagePresenter
var _social_intent_handler: SocialIntentHandler = SocialIntentHandlerScript.new()
var _notebook_intent_handler: NotebookIntentHandler = NotebookIntentHandlerScript.new()
var _settings_intent_handler: SettingsIntentHandler = SettingsIntentHandlerScript.new()
## Asked in turn for every intent; the first that claims it handles it and the host presents the result (ADR 0007).
var _intent_handlers: Array[IntentHandler] = [_social_intent_handler, _notebook_intent_handler, _settings_intent_handler]
var _phone_launcher_panel
var _notebook_app_panel: NotebookAppPanel
var _language_overlay: Control
var _view_toggle_button: Button
var _vhs_overlay: VhsOverlayScript
var _phone_tab: Button
var _app_window: PanelContainer
var _app_title: Label
var _app_body: VBoxContainer
var _app_windows: Dictionary = {}
var _app_titles: Dictionary = {}
var _app_bodies: Dictionary = {}
var _reality_conversation_panel
## The title-corner dialog debug panel shows only in debug builds.
var _dialog_debug_enabled := OS.is_debug_build()
var _pickup_flight_layer: FlyToTargetLayer
var _notebook_squash_tween: Tween
var _ending_screen_panel
var _window_manager: DraggableWindowManager
var _last_responsive_layout_size := Vector2.ZERO
var _game_started := false
var _flow: FlowManager
var _play_screen_installed := false
var _ending_screen_installed := false
var _world_hotkeys_installed := false
var _vhs_enabled := true
var _camera_session_decided := false
var _phone_art_alpha := 0.0
var _save_path := SAVE_PATH
var _session_world_data: Dictionary = {}


func _ensure_camera_session() -> void:
	if _camera_session != null and is_instance_valid(_camera_session):
		return
	_camera_session = CameraSessionScript.new()
	_camera_session.attach_to(self)
	_camera_session.ensure_receiver()
	if not _camera_session.tracking_ui_changed.is_connected(_on_camera_tracking_ui_changed):
		_camera_session.tracking_ui_changed.connect(_on_camera_tracking_ui_changed)


func _ensure_audio_controller() -> void:
	if _audio_controller != null and is_instance_valid(_audio_controller):
		return
	_audio_controller = GameAudioControllerScript.new()
	_audio_controller.attach_to(self)


func _ensure_narrative_director() -> void:
	if _narrative_director != null and is_instance_valid(_narrative_director):
		return
	_narrative_director = NarrativeOverlayDirectorScript.new()
	_narrative_director.attach_to(self)


func _narrative_overlay_deps() -> Dictionary:
	return {
		"ui_root": _ui_root,
		"audio": _audio_controller,
		"request_narrative": func() -> void:
			_request_session_mode("narrative"),
		"complete_beat": _complete_narrative_beat,
		"ending_unlocked": _ending_is_unlocked,
		"capture_frozen_frame": _capture_frozen_frame_texture,
	}


func _camera_session_deps() -> Dictionary:
	return {
		"game_started": _game_started,
		"persist_preferences": func() -> void:
			_locale.save_preferences(_vhs_enabled, _camera_session.enabled, _camera_session.source),
		"on_phone_source_enabled": _show_phone_camera_connection_overlay,
		"on_camera_disabled": _hide_phone_camera_connection_overlay,
		"hide_phone_connection_overlay": _hide_phone_camera_connection_overlay,
		"refresh_phone_connection_ui": _refresh_phone_camera_connection_ui,
		"locale_translate": func(text: String) -> String: return _locale.translate(text),
		"ui_root": _ui_root,
		"phone_down_backdrop_image": _phone_down_backdrop_image,
	}


func _audio_controller_deps() -> Dictionary:
	return {
		"game": game,
		"game_started": _game_started,
		"day_progress": game.get_day_progress_snapshot() if game != null else {},
		"phone_shell": _phone_shell_snapshot(),
		"reality_interaction_active": _reality_interaction_is_active(),
		"reality_conversation": _reality_conversation_snapshot(),
		"pollution_stage": _pollution_stage_snapshot(),
	}


## The social panel's content, kept on the current run, locale and language material.
func _social_feed_source() -> GameSocialFeedSource:
	if _social_source == null:
		_social_source = GameSocialFeedSourceScript.new(_textures)
		_social_source.configure(game, _locale, _language_material)
	return _social_source


## Binds this host's social source as a service so the social panel can resolve it.
## A source left by an earlier host is replaced, like the UI theme.
func _bind_social_feed_source() -> void:
	_rebind_service(ServiceKeysScript.SOCIAL_FEED_SOURCE, _social_feed_source())


func _on_camera_tracking_ui_changed() -> void:
	if _camera_session == null:
		return
	_camera_session.refresh_source_buttons()
	_camera_session.refresh_status_ui()
	_refresh_phone_camera_connection_ui()


func _on_hand_tracking_status_changed(status: HandTrackingStatusScript.Status) -> void:
	if _camera_session == null:
		return
	_camera_session.tracking_status = status
	if HandTrackingStatusScript.clears_ready_source(status):
		_camera_session.ready_source = ""
		_camera_session.ready_index = -1
	_on_camera_tracking_ui_changed()


func _on_camera_source_ready(source: String, selected_index: int) -> void:
	if _camera_session == null or source not in ["computer", "phone"]:
		return
	_camera_session.ready_source = source
	_camera_session.ready_index = selected_index
	_on_camera_tracking_ui_changed()


func _ready() -> void:
	PropertyBootScript.install()
	_bind_ui_theme()
	_bind_social_feed_source()
	_ui_theme_helper.configure({
		"ui_font_path": UI_FONT_PATH,
		"ui_font_grid": UI_FONT_GRID,
		"ui_font_min_size": UI_FONT_MIN_SIZE,
		"ui_font_max_size": UI_FONT_MAX_SIZE,
		"locale_translate": func(text: String) -> String: return _locale.translate(text),
		"pollution_stage": _pollution_stage_snapshot,
	})
	var preferences := _locale.load_preferences(_vhs_enabled)
	_vhs_enabled = bool(preferences.get("vhs_enabled", _vhs_enabled))
	_ensure_camera_session()
	_camera_session.enabled = bool(preferences.get("camera_enabled", false))
	_camera_session.source = str(preferences.get("camera_source", "computer"))
	_camera_session_decided = false
	_camera_session.ensure_receiver()
	_ensure_window_manager()
	_ensure_edge_drawer()
	_ensure_dialog_manager()
	_ensure_flow_manager()
	show_main_menu()
	if not _locale.language_selected:
		_build_language_selection_overlay(true)


func _process(delta: float) -> void:
	if _camera_session != null:
		_camera_session.poll_receiver()
	if _camera == null:
		return
	if _game_started:
		if not _ending_screen_installed:
			_ensure_reality_floor_current()
		_refresh_nearby_reality_actor()
		_update_door_fade(delta)
		_apply_responsive_layouts_if_needed()
		if _edge_drawer != null:
			_edge_drawer.tick(delta)
	_animate_world(delta)


func _enter_tree() -> void:
	_ensure_ui_event_bus()
	_cover_watcher_sightings.configure(game)
	_cover_watcher_sightings.attach(_ui_event_bus)
	_ui_event_bus.subscribe(GameEventsScript.OPENING_KNOCK_FINISHED, _on_opening_knock_finished)
	var volume := _master_volume_model()
	if volume != null:
		volume.register(_apply_master_volume)
	var settings_open := _value_model(PropertyKeysScript.SETTINGS_OPEN)
	if settings_open != null:
		settings_open.register(_on_settings_open_changed)


func _exit_tree() -> void:
	if _camera_session != null:
		_camera_session.stop_receiver()
	if _ui_event_bus != null and _ui_event_bus.intent_emitted.is_connected(_on_ui_intent):
		_ui_event_bus.intent_emitted.disconnect(_on_ui_intent)
	_cover_watcher_sightings.detach()
	if _ui_event_bus != null:
		_ui_event_bus.unsubscribe(GameEventsScript.OPENING_KNOCK_FINISHED, _on_opening_knock_finished)
	# The theme caches a font Theme; leaving it in the static table crashes engine shutdown.
	ServiceRegistryScript.unbind(ServiceKeysScript.UI_THEME, _ui_theme_helper)
	ServiceRegistryScript.unbind(ServiceKeysScript.SOCIAL_FEED_SOURCE, _social_source)
	ServiceRegistryScript.unbind(ServiceKeysScript.WINDOW_MANAGER, _window_manager)
	ServiceRegistryScript.unbind(ServiceKeysScript.DIALOG, _dialog_manager)
	if ServiceRegistryScript.has(ServiceKeysScript.PROPERTY_MANAGER):
		var volume := _master_volume_model()
		if volume != null:
			volume.unregister(_apply_master_volume)
		var settings_open := _value_model(PropertyKeysScript.SETTINGS_OPEN)
		if settings_open != null:
			settings_open.unregister(_on_settings_open_changed)


func _physics_process(delta: float) -> void:
	if not _world_hotkeys_installed or _reality_scene_adapter == null or not bool(_reality_scene_adapter.pose().get("has_player", false)):
		return
	_update_reality_player(delta)


func _input(event: InputEvent) -> void:
	if not _world_hotkeys_installed:
		_reality_touch_look_index = -1
		return
	if _edge_drawer != null and _edge_drawer.handle_global_input(event):
		return
	if _handle_reality_touch_look(event):
		return
	if _handle_reality_trackpad_pan(event):
		return
	if _window_manager != null:
		_window_manager.handle_global_input(event)


func _handle_reality_touch_look(event: InputEvent) -> bool:
	var can_touch_look: bool = str(_phone_shell_snapshot().get("view_state", "")) == "npc_up" and not _reality_interaction_is_active()
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			if touch.index == _reality_touch_look_index:
				_reality_touch_look_index = -1
			return false
		if can_touch_look and _reality_touch_look_index < 0:
			_reality_touch_look_index = touch.index
		return false
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not can_touch_look:
			_reality_touch_look_index = -1
			return false
		if _reality_touch_look_index < 0:
			_reality_touch_look_index = drag.index
		if drag.index != _reality_touch_look_index:
			return false
		var delta: Vector2 = drag.screen_relative
		if delta.is_zero_approx():
			delta = drag.relative
		if not delta.is_zero_approx():
			_apply_reality_look_delta(delta, REALITY_TOUCH_SENSITIVITY)
		get_viewport().set_input_as_handled()
		return true
	return false


func _handle_reality_trackpad_pan(event: InputEvent) -> bool:
	if not event is InputEventPanGesture:
		return false
	var can_trackpad_look: bool = str(_phone_shell_snapshot().get("view_state", "")) == "npc_up" and not _reality_interaction_is_active()
	if not can_trackpad_look:
		return false
	var pan := event as InputEventPanGesture
	if pan.delta.is_zero_approx():
		return false
	# macOS reports pan as content-scroll direction, opposite to the fingers.
	_apply_reality_look_delta(-pan.delta, REALITY_TRACKPAD_SENSITIVITY)
	get_viewport().set_input_as_handled()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _flow != null:
		_flow.handle_input(event)


func handle_gameplay_unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if _reality_interaction_is_active() and str(_reality_conversation_snapshot().get("phase", "")) == "typing" and event.keycode != KEY_ESCAPE:
			if _advance_typed_reality_character():
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("reality_interact"):
			_try_reality_interaction()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("reality_phone"):
			_toggle_view_state()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _reality_interaction_is_active():
				# The white door cannot be turned back once it is opening.
				if not _reality_door_opening():
					_exit_reality_interaction()
			else:
				_set_reality_mouse_look(false)
			get_viewport().set_input_as_handled()
			return
	if str(_phone_shell_snapshot().get("view_state", "")) != "npc_up" or _reality_interaction_is_active():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_reality_mouse_look(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _reality_mouse_look_enabled:
		var motion := event as InputEventMouseMotion
		_apply_reality_look_delta(motion.relative, REALITY_MOUSE_SENSITIVITY)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _reality_mouse_look_enabled:
		var drag := event as InputEventScreenDrag
		_apply_reality_look_delta(drag.relative, REALITY_TOUCH_SENSITIVITY)
		get_viewport().set_input_as_handled()


func new_game() -> void:
	var fresh_state: MemeGameState = MemeGameStateScript.new()
	fresh_state.new_run()
	_begin_game_session(fresh_state, {})


func continue_game() -> bool:
	var payload := _load_save_payload()
	if payload.is_empty():
		return false
	var restored_state: MemeGameState = MemeGameStateScript.new()
	var saved_state: Variant = payload.get("game", {})
	if not saved_state is Dictionary or not restored_state.load_save_data(saved_state):
		return false
	_begin_game_session(restored_state, payload.get("world", {}))
	return true


## START sends continue whenever the title believes a save exists; a save that cannot be read starts a new game.
func _continue_or_new_game() -> void:
	if continue_game():
		return
	push_warning("无法读取存档，改为开新游戏：%s" % _save_path)
	new_game()


## A run still reading chapter one's opening narration (a new one, or a save made during it) opens on the
## narration; any other run goes straight to the world.
func _begin_game_session(session_state: MemeGameState, world_data: Dictionary) -> void:
	_game_started = true
	_phone_art_alpha = 1.0
	if _camera_session != null:
		_camera_session.second_layer_texture = null
	game = session_state
	_cover_watcher_sightings.configure(game)
	if _language_material != null:
		_language_material.configure(game, _locale)
	_social_feed_source().configure(game, _locale, _language_material)
	_migrate_social_author_ids()
	if _social_feed_panel != null:
		_social_feed_panel.reset_view()
	_app_windows = {}
	_app_titles = {}
	_app_bodies = {}
	if _narrative_director != null:
		_narrative_director.reset_session()
	_ensure_window_manager()
	_window_manager.clear()
	_last_responsive_layout_size = Vector2.ZERO
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.reset_session_state()
	_set_reality_mouse_look(false)
	var show_opening := _reading_opening_narration()
	_write_feedback_text("你低头，手机边框从视野下方亮起来。" if show_opening else "你回到离开时的位置。")
	_session_world_data = world_data
	# Leave the title mounted until main-menu exit. Prologue and ending enter mount the in-run scene.
	if show_opening:
		game.set_view_state("npc_up")
		if session_mode() == "prologue":
			# A new run started from inside the opening remounts it for the new run.
			uninstall_prologue_screen()
			install_prologue_screen()
		else:
			_request_session_mode("prologue")
	elif not _request_ending_if_unlocked():
		if session_mode() != "gameplay":
			_request_session_mode("gameplay")
		_mount_in_run_scene()
	var look_in_world := _world_hotkeys_installed and str(_phone_shell_snapshot().get("view_state", "")) == "npc_up"
	_set_reality_mouse_look(look_in_world)
	_render()
	_sync_audio_state(true)


func _mount_in_run_scene() -> void:
	_build_world(not _ending_is_unlocked())
	_restore_saved_world(_session_world_data)
	_build_ui()


func show_main_menu() -> void:
	if _game_started:
		if _reality_interaction_is_active():
			_exit_reality_interaction(false)
		_save_progress()
	_locale.save_preferences(_vhs_enabled, _camera_session.enabled, _camera_session.source)
	_game_started = false
	if _settings_history_panel != null and is_instance_valid(_settings_history_panel):
		_settings_history_panel.close_settings()
	_phone_art_alpha = 0.0
	if _reality_scene_adapter != null:
		_reality_scene_adapter.apply_interaction({"action": "end"})
		_reality_scene_adapter.clear_nearby_targets()
	_set_reality_mouse_look(false)
	var staying_on_title := session_mode() == "main_menu"
	_build_world()
	if staying_on_title:
		install_title_screen()
	else:
		_request_session_mode("main_menu")
	if _locale.language_selected and not _camera_session_decided:
		_build_camera_consent_overlay()
	_sync_audio_state(true)


func _save_progress() -> bool:
	if not _game_started or game == null:
		return false
	_commit_notebook_canvas_positions()
	var world_pose: Dictionary = _reality_scene_adapter.world_save_pose() if _reality_scene_adapter != null else {}
	var world_data := {
		"player_position": world_pose.get("player_position", Vector3.ZERO),
		"yaw": world_pose.get("yaw", 0.0),
		"pitch": world_pose.get("pitch", 0.0),
	}
	var payload := {
		"version": SAVE_FILE_VERSION,
		"game": game.to_save_data(),
		"world": world_data,
	}
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档：%s" % _save_path)
		return false
	file.store_var(payload)
	file.flush()
	# Close before has_save is read back from the same path.
	file.close()
	_publish_has_save()
	return true


func _load_save_payload() -> Dictionary:
	return _save_slot().load_payload()


func _has_save_progress() -> bool:
	return _save_slot().has_progress()


func _save_slot() -> SaveSlotScript:
	return SaveSlotScript.new(_save_path, SAVE_FILE_VERSION)


func _publish_has_save() -> void:
	var has_save := _value_model(PropertyKeysScript.HAS_SAVE)
	if has_save == null:
		return
	has_save.write(_has_save_progress())


func _restore_saved_world(world_data: Dictionary) -> void:
	if world_data.is_empty():
		return
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.restore_world_pose(world_data)


func _migrate_social_author_ids() -> void:
	var migrated: Array[String] = []
	for stored_author in game.get_social_followed_handles():
		var stable_id := str(stored_author)
		for post in _social_feed_source().post_cards:
			if str(post.get("handle", "")) == stable_id:
				stable_id = str(post.get("id", stable_id))
				break
		if stable_id not in migrated:
			migrated.append(stable_id)
	game.replace_social_followed_handles(migrated)


func _phone_shell_snapshot() -> Dictionary:
	if game == null:
		return {"view_state": "phone_down"}
	return game.get_phone_shell_snapshot()


func _foreground_app() -> String:
	return game.active_app_window if game != null else ""


func _reality_conversation_snapshot() -> Dictionary:
	if game == null:
		return {
			"phase": "idle",
			"mode": "authored",
			"actor_type": "npc",
			"actor_label": "",
			"prompt": "",
			"result_line": "",
			"choices": [],
			"can_continue": false,
			"feedback": "",
			"reveal_index": 0,
			"revealed_units": [],
		}
	return game.get_reality_conversation_snapshot()


func _reality_interaction_is_active() -> bool:
	if _reality_scene_adapter == null:
		return false
	return bool(_reality_scene_adapter.interaction_outcome().get("interaction_active", false))


func _reality_hud_snapshot() -> Dictionary:
	var nearby: Dictionary = {}
	var look_pose: Dictionary = {}
	var active_actor: Dictionary = {}
	if _reality_scene_adapter != null:
		nearby = _reality_scene_adapter.nearby_outcome()
		look_pose = _reality_scene_adapter.pose()
		active_actor = _reality_scene_adapter.active_actor_outcome()
	else:
		nearby = {"kind": "none", "action": "none"}
		look_pose = {
			"player_position": Vector3.ZERO,
			"yaw": 0.0,
			"pitch": 0.0,
			"has_player": false,
		}
		active_actor = {"kind": "none", "action": "none"}
	return {
		"nearby": nearby,
		"pose": look_pose,
		"active_actor": active_actor,
		"conversation": _reality_conversation_snapshot(),
		"interaction_active": _reality_interaction_is_active(),
		"view_state": str(_phone_shell_snapshot().get("view_state", "")),
		"day_progress": game.get_day_progress_snapshot() if game != null else {},
	}


func _inventory_snapshot() -> Dictionary:
	if game == null:
		return {
			"completed_memes": [],
			"notebook_token_count": 0,
			"draft_slots": {},
			"craft_slot_fills": {},
		}
	return game.get_inventory_snapshot()


func set_view_state(value: String) -> void:
	if value == "phone_down" and _phone_locked():
		return
	if value == "npc_up" and str(_phone_shell_snapshot().get("view_state", "")) == "phone_down":
		_capture_phone_layer_for_xray()
	if game.set_view_state(value):
		if _reality_scene_adapter != null:
			_reality_scene_adapter.apply_interaction({"action": "end"})
			_reality_scene_adapter.clear_nearby_targets()
		game.reset_typed_reality_conversation()
		if value == "npc_up":
			_set_reality_mouse_look(true)
			_write_feedback_text("你放下手机，大街重新获得纵深。")
		else:
			_set_reality_mouse_look(false)
			_write_feedback_text("你又低头看向手机。")
			if _phone_launcher_panel != null:
				_phone_launcher_panel.move_phone_to_front()
		_refresh_phone_shell()
		_update_world_for_phone_view()
		_sync_audio_state(false)


func _toggle_view_state() -> void:
	if str(_phone_shell_snapshot().get("view_state", "")) == "phone_down":
		set_view_state("npc_up")
	else:
		set_view_state("phone_down")


func _capture_phone_layer_for_xray() -> bool:
	return _camera_session.capture_phone_layer_for_xray(_camera_session_deps()) if _camera_session != null else false


func _set_reality_mouse_look(enabled: bool) -> void:
	_reality_mouse_look_enabled = enabled
	if not enabled or str(_phone_shell_snapshot().get("view_state", "")) != "npc_up":
		_reality_touch_look_index = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE)


func _ensure_reality_scene_adapter() -> void:
	if _reality_scene_adapter != null and is_instance_valid(_reality_scene_adapter):
		return
	_reality_scene_adapter = RealitySceneAdapterScript.new()
	_reality_scene_adapter.attach_to(self)
	if not _reality_scene_adapter.nearby_targets_changed.is_connected(_on_reality_nearby_targets_changed):
		_reality_scene_adapter.nearby_targets_changed.connect(_on_reality_nearby_targets_changed)


func _reality_scene_deps() -> Dictionary:
	var progress: Dictionary = game.get_day_progress_snapshot() if game != null else {}
	var tower_floor := clampi(int(progress.get("tower_floor", 1)), 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	var locale_code: String = "zh"
	if _locale != null:
		locale_code = str(_locale.current_locale)
	return {
		"day_progress": progress,
		"palette": _ui_theme_helper.active_palette(),
		"load_texture": _load_runtime_texture,
		"npc_character_paths": NPC_CHARACTER_PATHS,
		"guide_doll_path": GUIDE_DOLL_CHARACTER_PATH,
		"view_state": str(_phone_shell_snapshot().get("view_state", "")) if game != null else "",
		"locale": locale_code,
		"locale_translate": func(text: String) -> String: return _locale.translate(text),
		"cover_watcher_seen": game.has_seen_cover_watcher(tower_floor) if game != null else false,
		"collected_world_item_ids": game.collected_world_item_ids.duplicate() if game != null else [],
		"revealed_prerequisite_item_ids": game.revealed_prerequisite_item_ids.duplicate() if game != null else [],
		"collected_prerequisite_item_ids": game.collected_prerequisite_item_ids.duplicate() if game != null else [],
		"claimed_doll_ids": game.claimed_doll_ids.duplicate() if game != null else [],
		"floor3_task_complete": game.floor3_task_complete if game != null else false,
		"floor4_task_complete": game.floor4_task_complete if game != null else false,
		"chapter_one_progress": game.chapter_one_progress if game != null else ChapterOneProgressScript.tower(),
	}


func _on_reality_nearby_targets_changed() -> void:
	_refresh_reality_hud()


func _apply_reality_look_delta(relative_motion: Vector2, sensitivity: float) -> void:
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.apply_look_delta(relative_motion, sensitivity)


func _build_world(build_playable_floor: bool = true) -> void:
	if _audio_controller != null:
		_audio_controller.reset_session()
	if _camera_session != null:
		_camera_session.reset_session()
	_camera_consent_overlay = null
	_camera_access_toggle = null
	_camera_consent_source_option = null
	_camera_computer_button = null
	_camera_phone_button = null
	_camera_source_button_group = null
	_camera_status_label = null
	_phone_camera_connection_overlay = null
	if _phone_camera_connection_panel != null:
		_phone_camera_connection_panel.close()
	_phone_camera_connection_panel = null
	if _screen_manager != null and is_instance_valid(_screen_manager):
		_screen_manager.retain()
	# A dialog never outlives the world it was opened over; it closes without running a callback.
	if _dialog_manager != null and is_instance_valid(_dialog_manager):
		_dialog_manager.close()
	# The window manager is freed with the other children; the next one binds itself.
	ServiceRegistryScript.unbind(ServiceKeysScript.WINDOW_MANAGER, _window_manager)
	_window_manager = null
	for child in get_children():
		if child == _reality_scene_adapter or child == _narrative_director or child == _screen_manager or child == _dialog_manager:
			continue
		remove_child(child)
		child.free()

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	add_child(_camera)
	_camera.current = true
	_camera.fov = 58.0
	_configure_reality_depth_of_field()

	_ensure_reality_scene_adapter()
	_reality_scene_adapter.build_world_nodes()
	if build_playable_floor:
		_reality_scene_adapter.rebuild_floor(_reality_scene_deps())

	_canvas = CanvasLayer.new()
	_canvas.name = "CanvasLayer"
	add_child(_canvas)
	_ui_root = null
	_ensure_audio_controller()
	_audio_controller.build_players(_audio_controller_deps())


func _configure_reality_depth_of_field() -> void:
	if _camera == null:
		return
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 18.0
	attributes.dof_blur_far_transition = 12.0
	attributes.dof_blur_amount = 0.08
	attributes.dof_blur_near_enabled = false
	_camera.attributes = attributes
	_camera.set_meta("fixed_focus_profile", "near_clear_far_soft")
	_camera.set_meta("focus_distance_m", 18.0)
	_camera.set_meta("far_transition_m", 12.0)


func _ensure_reality_input_map() -> void:
	_set_key_action("reality_forward", [KEY_W, KEY_UP])
	_set_key_action("reality_back", [KEY_S, KEY_DOWN])
	_set_key_action("reality_left", [KEY_A, KEY_LEFT])
	_set_key_action("reality_right", [KEY_D, KEY_RIGHT])
	_set_key_action("reality_sprint", [KEY_SHIFT])
	_set_key_action("reality_interact", [KEY_F])
	_set_key_action("reality_phone", [KEY_TAB])


func _clear_reality_input_map() -> void:
	for action_name in WORLD_HOTKEY_ACTIONS:
		if InputMap.has_action(action_name):
			InputMap.action_erase_events(action_name)
			InputMap.erase_action(action_name)


func install_world_hotkeys() -> void:
	_world_hotkeys_installed = true
	_ensure_reality_input_map()
	_sync_window_manager_enabled()


func uninstall_world_hotkeys() -> void:
	_world_hotkeys_installed = false
	_clear_reality_input_map()
	_sync_window_manager_enabled()


func install_play_screen() -> void:
	_play_screen_installed = true
	if _play_chrome_is_live():
		_update_visibility()


func uninstall_play_screen() -> void:
	_play_screen_installed = false
	if _play_chrome_is_live():
		_update_visibility()


func _play_chrome_is_live() -> bool:
	return _view_toggle_button != null and is_instance_valid(_view_toggle_button)


func install_narrative_screen() -> void:
	_bind_narrative_director()
	_narrative_director.present_installed_screen()


func uninstall_narrative_screen() -> void:
	if _narrative_director != null:
		_narrative_director.dismiss_installed_screen()


func install_title_screen() -> void:
	if _canvas == null:
		return
	# Play windows lived on the previous canvas. Drop the refs before the next visibility pass.
	_app_windows.clear()
	_app_titles.clear()
	_app_bodies.clear()
	_ensure_title_ui_root()
	_ensure_screen_manager()
	_publish_has_save()
	_screen_manager.open({})
	_mount_dialog_debug_panel()
	_apply_ui_theme()
	_ui_theme_helper.refresh_localized_ui(_ui_root)
	_ensure_settings_history_panel()
	_update_visibility()


func uninstall_title_screen() -> void:
	if _screen_manager != null and is_instance_valid(_screen_manager):
		_screen_manager.close()
	_unmount_dialog_debug_panel()


## Debug builds only: a title-corner panel that opens sample dialogs and simulates the save for START.
func _mount_dialog_debug_panel() -> void:
	_unmount_dialog_debug_panel()
	if not _dialog_debug_enabled or _ui_root == null:
		return
	var panel := DialogDebugPanelScene.instantiate() as DialogDebugPanel
	panel.configure(_save_slot())
	_dialog_debug_panel = panel
	_ui_root.add_child(panel)


func _unmount_dialog_debug_panel() -> void:
	if _dialog_debug_panel != null and is_instance_valid(_dialog_debug_panel):
		# Leave the tree now, so the next mount keeps the panel's name.
		if _dialog_debug_panel.get_parent() != null:
			_dialog_debug_panel.get_parent().remove_child(_dialog_debug_panel)
		_dialog_debug_panel.queue_free()
	_dialog_debug_panel = null


## The opening narration sits under the rest of the in-run UI, so the HUD and settings stay clickable above it.
func install_prologue_screen() -> void:
	_mount_in_run_scene()
	_unmount_opening_narration()
	_opening_narration_panel = OpeningNarrationPanelScript.new()
	_ui_root.add_child(_opening_narration_panel)
	_ui_root.move_child(_opening_narration_panel, 0)
	install_play_screen()


func uninstall_prologue_screen() -> void:
	_unmount_opening_narration()
	uninstall_play_screen()


func _unmount_opening_narration() -> void:
	if _opening_narration_panel != null and is_instance_valid(_opening_narration_panel):
		_opening_narration_panel.get_parent().remove_child(_opening_narration_panel)
		_opening_narration_panel.queue_free()
	_opening_narration_panel = null


func install_ending_screen() -> void:
	_ending_screen_installed = true
	# Continue from the title has no play chrome yet. An in-run unlock must not rebuild it.
	if _view_toggle_button == null or not is_instance_valid(_view_toggle_button):
		_mount_in_run_scene()
	_render_ending()
	_update_visibility()


func uninstall_ending_screen() -> void:
	_ending_screen_installed = false
	if _ending_screen_panel != null and is_instance_valid(_ending_screen_panel):
		_ending_screen_panel.unmount()


func _set_key_action(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for keycode in keycodes:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(keycode)
		InputMap.action_add_event(action_name, key_event)


func _rebuild_reality_floor() -> void:
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.rebuild_floor(_reality_scene_deps())


func _ensure_reality_floor_current() -> void:
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.ensure_floor_current(_reality_scene_deps())


func _update_reality_player(delta: float) -> void:
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.update_player(delta, _reality_scene_deps())


func _refresh_nearby_reality_actor() -> void:
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.refresh_nearby_actor(_reality_scene_deps())


func _try_reality_interaction() -> bool:
	if str(_phone_shell_snapshot().get("view_state", "")) != "npc_up":
		return false
	# The white door cannot be turned back once it is opening.
	if _reality_door_opening():
		return true
	if _reality_interaction_is_active():
		_exit_reality_interaction()
		return true
	_ensure_reality_scene_adapter()
	var outcome: Dictionary = _reality_scene_adapter.probe_interaction(_reality_scene_deps())
	match str(outcome.get("action", "none")):
		"collect":
			return _collect_nearby_reality_item(outcome.get("item_data", {}) as Dictionary)
		"converse":
			return _begin_reality_actor_interaction(outcome)
		"open_door":
			return _open_reality_door()
	return false


func _begin_reality_actor_interaction(outcome: Dictionary) -> bool:
	var actor_id := str(outcome.get("actor_id", "")).strip_edges()
	if actor_id.is_empty():
		return false
	var actor_type := str(outcome.get("actor_type", "npc"))
	var actor_label := str(outcome.get("actor_label", "对方"))
	var started := game.start_typed_reality_conversation(actor_id, actor_type, actor_label)
	_ensure_reality_scene_adapter()
	var applied: Dictionary = _reality_scene_adapter.apply_interaction({
		"action": "converse",
		"actor_id": actor_id,
		"accepted": started,
	})
	if not bool(applied.get("interaction_active", false)):
		if started:
			game.reset_typed_reality_conversation()
		return false
	_localize_active_conversation()
	_set_reality_mouse_look(false)
	_write_feedback_text("你停在%s面前。" % _active_actor_display_name())
	_update_world_for_phone_view()
	_refresh_reality_hud()
	_sync_audio_state(false)
	return true


func _localize_active_conversation() -> void:
	game.configure_conversation_locale(_locale.current_locale)


func _collect_nearby_reality_item(item_data: Dictionary = {}) -> bool:
	if item_data.is_empty() and _reality_scene_adapter != null:
		item_data = _reality_scene_adapter.nearby_outcome().get("item_data", {}) as Dictionary
	if item_data.is_empty():
		return false
	if not game.collect_world_item(item_data):
		return false
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.apply_interaction({
		"action": "collect",
		"item_id": str(item_data.get("id", "")),
	})
	if not game.event_log.is_empty():
		_write_feedback_text(game.event_log[0])
	_present_progress()
	return true


## Leaving a conversation the player spoke in completes an interaction; the state checks progress and the host
## presents a new floor or the ending.
func _exit_reality_interaction(should_render: bool = true) -> void:
	if _reality_scene_adapter != null:
		_reality_scene_adapter.apply_interaction({"action": "end"})
	var outcome: ActionOutcomeScript = game.end_typed_reality_conversation()
	if str(_phone_shell_snapshot().get("view_state", "")) == "npc_up":
		_set_reality_mouse_look(true)
	if not should_render:
		return
	_update_world_for_phone_view()
	_present_conversation_outcome(outcome)


## A conversation already shows through the models; the host presents it only when it changed more than the street.
func _present_conversation_outcome(outcome: ActionOutcomeScript) -> void:
	if _interaction_changed_the_run(outcome):
		_present_interaction_outcome(outcome)
		return
	_refresh_reality_hud()
	_sync_audio_state(false)


func _active_actor_display_name() -> String:
	return _reality_hud_actor_label(_reality_hud_snapshot())


func _reality_hud_actor_label(hud: Dictionary) -> String:
	var conversation: Dictionary = hud.get("conversation", {})
	var label := str(conversation.get("actor_label", "")).strip_edges()
	if label.is_empty():
		label = str((hud.get("active_actor", {}) as Dictionary).get("actor_label", "")).strip_edges()
	if label.is_empty():
		return _locale.translate("对方")
	return _locale.translate(label)


func _sync_audio_state(immediate: bool = false) -> void:
	if _audio_controller != null:
		_audio_controller.sync_state(_audio_controller_deps(), immediate)


func _pollution_stage_snapshot() -> Dictionary:
	if game == null:
		return PollutionStageScript.stage(0, 1)
	return PollutionStageScript.stage(game.pollution, game.day)


func _ensure_title_ui_root() -> void:
	if _canvas == null:
		return
	if _ui_root != null and is_instance_valid(_ui_root):
		return
	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_theme_helper.apply_ui_font_theme(_ui_root)
	_canvas.add_child(_ui_root)


func _build_language_selection_overlay(first_run: bool = false) -> void:
	if _ui_root == null:
		return
	_ensure_language_selection_panel()
	_language_selection_panel.build(_ui_root, first_run, _language_selection_mount_deps())
	_language_overlay = _language_selection_panel.get_overlay()


func _on_language_selected(locale_code: String) -> void:
	if not _locale.select_language(locale_code):
		return
	# 首次启动尚未选语言,show_main_menu() 不会建 consent overlay,
	# 于是 _build_world() 释放的 session 无人重建。
	_ensure_camera_session()
	_locale.save_preferences(_vhs_enabled, _camera_session.enabled, _camera_session.source)
	_close_language_selection_overlay()
	# 换语言即换字池:清空造句台,避免旧语言的字混进新语言的句子。
	if game != null:
		game.free_sentence_clear()
	if _session_is_in_run():
		_render()
	else:
		install_title_screen()
		if not _camera_session_decided:
			_build_camera_consent_overlay()
	_ui_theme_helper.refresh_localized_ui(_ui_root)


func _close_language_selection_overlay() -> void:
	if _language_selection_panel == null:
		return
	if not _language_selection_panel.close():
		return
	_language_overlay = null


func _build_camera_consent_overlay() -> void:
	if _ui_root == null or _camera_session_decided:
		return
	_ensure_camera_consent_panel()
	_camera_consent_panel.build(_ui_root, _camera_consent_mount_deps())
	_camera_consent_overlay = _camera_consent_panel.get_overlay()
	_camera_consent_source_option = _camera_consent_panel.get_source_option()
	if _camera_session != null:
		_camera_session.consent_source_option = _camera_consent_source_option


func _resolve_camera_consent(allowed: bool) -> void:
	_camera_session_decided = true
	_set_camera_enabled(allowed, true)
	if _camera_consent_panel != null:
		_camera_consent_panel.close()
	_camera_consent_overlay = null
	_camera_consent_source_option = null


func _set_camera_enabled(value: bool, persist: bool = true) -> void:
	_ensure_camera_session()
	_camera_session.access_toggle = _camera_access_toggle
	_camera_session.set_enabled(value, _camera_session_deps(), persist)


func _set_camera_source(value: String, persist: bool = true) -> void:
	_ensure_camera_session()
	_camera_session.consent_source_option = _camera_consent_source_option
	_camera_session.set_source(value, _camera_session_deps(), persist)


func _populate_camera_source_option(option: OptionButton) -> void:
	_ensure_camera_session()
	_camera_session.populate_source_option(option, _camera_session_deps())


func _sync_camera_source_options() -> void:
	if _camera_session != null:
		_camera_session.consent_source_option = _camera_consent_source_option
		_camera_session.sync_source_options()


func _refresh_camera_source_option_labels() -> void:
	if _camera_session != null:
		_camera_session.consent_source_option = _camera_consent_source_option
		_camera_session.refresh_source_option_labels(_camera_session_deps())


func _on_camera_source_selected(index: int, option: OptionButton) -> void:
	if option == null or index < 0 or index >= option.item_count:
		return
	_set_camera_source(str(option.get_item_metadata(index)), true)


func _activate_camera_source(source: String) -> void:
	_camera_session_decided = true
	if _camera_session != null:
		_camera_session.computer_button = _camera_computer_button
		_camera_session.phone_button = _camera_phone_button
		_camera_session.activate_source(source, _camera_session_deps())


func _refresh_camera_source_buttons() -> void:
	if _camera_session != null:
		_camera_session.computer_button = _camera_computer_button
		_camera_session.phone_button = _camera_phone_button
		_camera_session.refresh_source_buttons()


func _refresh_camera_status_ui() -> void:
	if _camera_session != null:
		_camera_session.status_label = _camera_status_label
		_camera_session.refresh_status_ui()


func _build_hand_xray_overlay() -> void:
	_ensure_camera_session()
	_camera_session.build_hand_xray_overlay(_camera_session_deps())


func _build_ui() -> void:
	if _canvas == null:
		return
	for child in _canvas.get_children():
		child.queue_free()

	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Full-screen layers must let mouse events through, or street look and click-to-capture never reach _unhandled_input.
	_ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui_theme_helper.apply_ui_font_theme(_ui_root)
	_canvas.add_child(_ui_root)

	var vignette := ColorRect.new()
	vignette.color = _ui_theme_helper.theme_color("ink").darkened(0.15)
	vignette.modulate.a = 0.16
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = 2
	_ui_root.add_child(vignette)

	_build_vhs_overlay()

	_phone_down_backdrop_image = TextureRect.new()
	_phone_down_backdrop_image.name = "PhoneDownBackdropImage"
	_phone_down_backdrop_image.texture = _load_runtime_texture(PHONE_DOWN_BACKDROP_PATH)
	_phone_down_backdrop_image.set_meta("asset_path", PHONE_DOWN_BACKDROP_PATH)
	_phone_down_backdrop_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_phone_down_backdrop_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_phone_down_backdrop_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_down_backdrop_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_down_backdrop_image.set_meta("walking_bob_amplitude", 2.4)
	_phone_down_backdrop_image.z_index = 1
	_ui_root.add_child(_phone_down_backdrop_image)
	_hand_phone_image = null
	_build_hand_xray_overlay()
	_build_cinematic_bars()

	_build_apple_hud()

	_world_prompt = _ui_theme_helper.label("", 18, _ui_theme_helper.theme_color("surface"))
	_world_prompt.name = "WorldPrompt"
	_world_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_world_prompt.offset_left = 520
	_world_prompt.offset_top = -162
	_world_prompt.offset_right = -520
	_world_prompt.offset_bottom = -108
	_world_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_world_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_prompt.set_meta("on_dark", true)
	_world_prompt.add_theme_color_override("font_outline_color", UiPalette.OUTLINE)
	_world_prompt.add_theme_constant_override("outline_size", 6)
	_world_prompt.z_index = 10
	_ui_root.add_child(_world_prompt)

	_phone_tab = null

	_ensure_social_feed_panel()
	_social_feed_panel.mount(_ui_root)
	_ensure_phone_launcher_panel()
	_phone_launcher_panel.mount(_ui_root, _phone_launcher_mount_deps())
	_app_windows["social"] = _social_feed_panel.get_app_window()
	_app_titles["social"] = _social_feed_panel.get_app_title() as Label
	_app_bodies["social"] = _social_feed_panel.get_app_body() as VBoxContainer
	_app_windows["notebook"] = _phone_launcher_panel.get_app_window("notebook")
	_app_titles["notebook"] = _phone_launcher_panel.get_app_title("notebook")
	_app_bodies["notebook"] = _phone_launcher_panel.get_app_body("notebook")
	_ensure_notebook_app_panel()

	_view_toggle_button = Button.new()
	_view_toggle_button.name = "PhoneViewToggleButton"
	_view_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_view_toggle_button.offset_left = 470
	_view_toggle_button.offset_top = -92
	_view_toggle_button.offset_right = 596
	_view_toggle_button.offset_bottom = -36
	_view_toggle_button.custom_minimum_size = Vector2(126, 56)
	_view_toggle_button.z_index = 42
	_view_toggle_button.pressed.connect(_toggle_view_state)
	_ui_root.add_child(_view_toggle_button)

	_ensure_reality_conversation_panel()
	_reality_conversation_panel.mount(_ui_root, _reality_conversation_mount_deps())

	_desk_log = DeskLogLabelScript.new()
	_desk_log.add_theme_font_size_override("font_size", _ui_theme_helper.ui_font_size(16))
	_desk_log.add_theme_color_override("font_color", _ui_theme_helper.theme_color("accent"))
	_desk_log.name = "DeskLog"
	_desk_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_desk_log.offset_left = 282
	_desk_log.offset_top = -146
	_desk_log.offset_right = 820
	_desk_log.offset_bottom = -112
	_desk_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_root.add_child(_desk_log)

	_bind_narrative_director()
	_build_settings_window()
	_build_phone_camera_connection_overlay()
	_build_history_window()
	_build_pickup_flight_layer()
	_narrative_director.build_flashback_overlay()
	_apply_responsive_layouts_if_needed(true)


func _reading_opening_narration() -> bool:
	return game != null and ChapterOneProgressScript.is_reading_narration(game.chapter_one_progress)


## The narration locks the phone until it is read, and a door that is opening keeps it down.
func _phone_locked() -> bool:
	return _reading_opening_narration() or _reality_door_opening()


func _reality_door_opening() -> bool:
	if _reality_scene_adapter == null:
		return false
	return str(_reality_scene_adapter.interaction_outcome().get("kind", "none")) == "door"


func _advance_opening_narration() -> void:
	if session_mode() != "prologue" or _model_is_on(PropertyKeysScript.SETTINGS_OPEN):
		return
	if not game.advance_opening_narration():
		return
	if not _reading_opening_narration():
		_finish_opening_narration()


func _finish_opening_narration() -> void:
	if _request_ending_if_unlocked():
		_set_reality_mouse_look(false)
		_refresh_ending()
	else:
		_request_session_mode("gameplay")
		_set_reality_mouse_look(str(_phone_shell_snapshot().get("view_state", "")) == "npc_up")
		_refresh_play_surfaces()
	_sync_audio_state(false)


func _on_opening_knock_finished(_payload: Dictionary) -> void:
	if game != null:
		game.complete_opening_knock()


## Development and test seam: leaves chapter one for the tower street with the phone up, as a run used to begin.
func _skip_chapter_one() -> void:
	game.skip_chapter_one()
	game.set_view_state("phone_down")
	_finish_opening_narration()
	_rebuild_reality_floor()
	_render()
	_sync_audio_state(true)


## Opening the white door: the state moves on to the basement and the adapter plays the door before it rebuilds.
func _open_reality_door() -> bool:
	if not game.open_opening_door():
		return false
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.apply_interaction({"action": "open_door"})
	_door_was_opening = true
	_update_visibility()
	_refresh_reality_hud()
	return true


## Darkens the screen as the door finishes opening, then lifts it once the next stage is built.
func _update_door_fade(delta: float) -> void:
	if _ui_root == null or not is_instance_valid(_ui_root):
		return
	var outcome: Dictionary = _reality_scene_adapter.interaction_outcome() if _reality_scene_adapter != null else {}
	var target := 0.0
	var opening := str(outcome.get("kind", "none")) == "door"
	if opening:
		target = smoothstep(0.7, 1.0, float(outcome.get("progress", 0.0)))
	if _door_was_opening and not opening:
		# The next stage is built: the phone and the prompt come back.
		_door_was_opening = false
		_update_visibility()
		_refresh_reality_hud()
	if _door_fade == null or not is_instance_valid(_door_fade):
		if target <= 0.0:
			return
		_door_fade = ColorRect.new()
		_door_fade.name = "DoorFade"
		_door_fade.color = Color(UiPalette.VOID, 0.0)
		_door_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_door_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ui_root.add_child(_door_fade)
	var alpha := target if target > 0.0 else move_toward(_door_fade.color.a, 0.0, delta * 2.0)
	_door_fade.color = Color(UiPalette.VOID, alpha)
	if alpha <= 0.0:
		_door_fade.queue_free()
		_door_fade = null


func _build_apple_hud() -> void:
	_ensure_apple_hud_panel()
	_apple_hud_panel.mount(_ui_root, _apple_hud_mount_deps())
	_ensure_edge_drawer()
	_edge_drawer.configure(
		HUD_RAIL_WIDTH,
		HUD_DRAWER_OPEN_DURATION,
		HUD_DRAWER_CLOSE_DURATION,
		HUD_DRAWER_CLOSE_DELAY
	)
	_edge_drawer.attach(_apple_hud_panel.get_rail(), _apple_hud_panel.get_reveal_zone())
	_edge_drawer.add_companion(_apple_hud_panel.get_tooltip())
	_sync_edge_drawer_enabled()
	_layout_hud_rail()


func _ensure_apple_hud_panel() -> void:
	if _apple_hud_panel != null and is_instance_valid(_apple_hud_panel):
		return
	_apple_hud_panel = AppleHudPanelScript.new()
	_apple_hud_panel.name = "AppleHudPanelHost"
	add_child(_apple_hud_panel)


func _apple_hud_mount_deps() -> Dictionary:
	return {
		"load_texture": _load_runtime_texture,
		"rail_width": HUD_RAIL_WIDTH,
		"rail_max_height": HUD_RAIL_MAX_HEIGHT,
		"drawer_edge_hit_width": HUD_DRAWER_EDGE_HIT_WIDTH,
		"drawer_edge_cue_width": HUD_DRAWER_EDGE_CUE_WIDTH,
		"drawer_open_duration": HUD_DRAWER_OPEN_DURATION,
		"drawer_close_duration": HUD_DRAWER_CLOSE_DURATION,
		"pollution_icon_path": HUD_POLLUTION_ICON_PATH,
		"settings_icon_path": HUD_SETTINGS_ICON_PATH,
		"on_tooltip_hidden": _on_apple_hud_tooltip_hidden,
	}


func _on_apple_hud_tooltip_hidden() -> void:
	if _edge_drawer != null:
		_edge_drawer.schedule_close()


func _hud_rail() -> PanelContainer:
	if _apple_hud_panel == null:
		return null
	return _apple_hud_panel.get_rail()


func _is_hud_drawer_expanded() -> bool:
	_ensure_edge_drawer()
	return _edge_drawer.is_expanded()


func _set_hud_drawer_expanded(expanded: bool, animate: bool = true) -> void:
	_ensure_edge_drawer()
	_edge_drawer.set_expanded(expanded, animate)


func _hud_drawer_x(expanded: bool) -> float:
	_ensure_edge_drawer()
	return _edge_drawer.panel_x(expanded)


func _update_hud_drawer_auto_close(delta: float) -> void:
	if _edge_drawer != null:
		_edge_drawer.tick(delta)


func _handle_hud_drawer_global_input(event: InputEvent) -> bool:
	if _edge_drawer == null:
		return false
	return _edge_drawer.handle_global_input(event)


func _ensure_edge_drawer() -> void:
	if _edge_drawer != null:
		return
	_edge_drawer = EdgeDrawerScript.new()
	_edge_drawer.name = "EdgeDrawer"
	add_child(_edge_drawer)


func _sync_edge_drawer_enabled() -> void:
	if _edge_drawer != null:
		_edge_drawer.enabled = _world_hotkeys_installed


func _add_hud_metric(parent: VBoxContainer, label_text: String, value_name: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key := _ui_theme_helper.label(label_text, 13, _ui_theme_helper.theme_color("accent"))
	key.custom_minimum_size.x = 70
	row.add_child(key)
	var value := _ui_theme_helper.label("", 17, _ui_theme_helper.theme_color("ink"))
	value.name = value_name
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _build_vhs_overlay() -> void:
	_vhs_overlay = VhsOverlayScript.new()
	_vhs_overlay.name = "VHSOverlay"
	_vhs_overlay.visible = _vhs_enabled
	_vhs_overlay.z_index = 3
	_ui_root.add_child(_vhs_overlay)


func _build_cinematic_bars() -> void:
	_cinematic_bars = CinematicBarsScript.new()
	_cinematic_bars.name = "CinematicBars"
	_ui_root.add_child(_cinematic_bars)
	_cinematic_bars.bar_color = UiPalette.VOID
	_cinematic_bars.configure(CINEMATIC_ASPECT_RATIO, CINEMATIC_MAX_BAR_RATIO)
	_cinematic_bars.relayout(_viewport_size())


func _layout_hud_rail() -> void:
	var hud_rail := _hud_rail()
	if hud_rail == null:
		return
	var hud_reveal_zone: Control = _apple_hud_panel.get_reveal_zone() if _apple_hud_panel != null else null
	var viewport_size := _viewport_size()
	var uses_cinematic_frame: bool = _session_shows_play_chrome() and game != null and str(_phone_shell_snapshot().get("view_state", "")) == "npc_up"
	var frame_inset := 0.0
	if uses_cinematic_frame and _cinematic_bars != null:
		frame_inset = _cinematic_bars.bar_height(viewport_size)
	var top_limit := frame_inset + HUD_RAIL_FRAME_MARGIN
	var bottom_limit := viewport_size.y - frame_inset - HUD_RAIL_FRAME_MARGIN
	var available_height := maxf(1.0, bottom_limit - top_limit)
	var rail_height := minf(HUD_RAIL_MAX_HEIGHT, available_height)
	var center_y := (top_limit + bottom_limit) * 0.5
	var rail_x := _edge_drawer.layout_panel_x() if _edge_drawer != null else _hud_drawer_x(_is_hud_drawer_expanded())
	var desired_top := center_y - rail_height * 0.5
	var desired_bottom := center_y + rail_height * 0.5
	var clamped_top := maxf(top_limit, desired_top)
	var clamped_bottom := minf(bottom_limit, desired_bottom)
	if clamped_bottom - clamped_top > available_height:
		clamped_top = top_limit
		clamped_bottom = bottom_limit
	hud_rail.set_anchors_preset(Control.PRESET_TOP_LEFT)
	hud_rail.offset_left = 0.0
	hud_rail.offset_top = clamped_top
	hud_rail.offset_right = HUD_RAIL_WIDTH
	hud_rail.offset_bottom = clamped_bottom
	hud_rail.position.x = rail_x
	hud_rail.set_meta("cinematic_safe_top", top_limit)
	hud_rail.set_meta("cinematic_safe_bottom", bottom_limit)
	hud_rail.set_meta("collapsed_x", _hud_drawer_x(false))
	hud_rail.set_meta("expanded_x", _hud_drawer_x(true))
	if hud_reveal_zone != null:
		hud_reveal_zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
		hud_reveal_zone.offset_left = 0.0
		hud_reveal_zone.offset_top = center_y - rail_height * 0.5
		hud_reveal_zone.offset_right = HUD_DRAWER_EDGE_HIT_WIDTH
		hud_reveal_zone.offset_bottom = center_y + rail_height * 0.5


func _build_settings_window() -> void:
	_ensure_settings_history_panel()
	_settings_history_panel.mount(_ui_root, _settings_history_mount_deps())
	_settings_window = _settings_history_panel.get_settings_window() as PanelContainer
	_inject_settings_camera_block()
	_layout_settings_window()
	if _edge_drawer != null and _settings_window != null:
		_edge_drawer.add_exclusion(_settings_window)


func _build_phone_camera_connection_overlay() -> void:
	if _ui_root == null:
		return
	_ensure_phone_camera_connection_panel()
	_phone_camera_connection_panel.build(_ui_root, _phone_camera_connection_mount_deps())
	_phone_camera_connection_overlay = _phone_camera_connection_panel.get_overlay()
	_refresh_phone_camera_connection_ui()
	if _camera_session != null and _camera_session.enabled and _camera_session.source == "phone":
		_show_phone_camera_connection_overlay()


func _show_phone_camera_connection_overlay() -> void:
	if _phone_camera_connection_panel == null:
		return
	_phone_camera_connection_panel.show_overlay()
	_refresh_phone_camera_connection_ui()


func _hide_phone_camera_connection_overlay() -> void:
	if _phone_camera_connection_panel == null:
		return
	_phone_camera_connection_panel.hide_overlay()


func _retry_phone_camera_connection() -> void:
	_activate_camera_source("phone")


func _disable_phone_camera_from_connection() -> void:
	_set_camera_enabled(false, true)
	_hide_phone_camera_connection_overlay()


func _refresh_phone_camera_connection_ui() -> void:
	if _phone_camera_connection_panel == null:
		return
	_phone_camera_connection_panel.refresh(_phone_camera_connection_view())


func _phone_camera_connection_view() -> Dictionary:
	return _camera_session.connection_view() if _camera_session != null else {}


func _layout_settings_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.layout_settings(_viewport_size())


func _ensure_screen_manager() -> void:
	if _screen_manager != null and is_instance_valid(_screen_manager):
		return
	_ensure_ui_event_bus()
	_screen_manager = ScreenManagerScript.new(_ui_event_bus, MainMenuScreenScript, self)
	_screen_manager.name = "ScreenManager"
	add_child(_screen_manager)


## The dialog opener every panel resolves under ServiceKeys.DIALOG. Built once at boot and kept across world rebuilds.
func _ensure_dialog_manager() -> void:
	if _dialog_manager != null and is_instance_valid(_dialog_manager):
		return
	_ensure_ui_event_bus()
	_dialog_manager = ScreenManagerScript.new(_ui_event_bus, DialogScreenScript, self)
	_dialog_manager.name = "DialogManager"
	add_child(_dialog_manager)
	_rebind_service(ServiceKeysScript.DIALOG, _dialog_manager)


## Binds this host's UI theme as a service so panels can resolve it instead of taking theme callables.
## A theme left by an earlier host is replaced, so that host's exit cannot unbind the theme in use.
func _bind_ui_theme() -> void:
	_rebind_service(ServiceKeysScript.UI_THEME, _ui_theme_helper)


## Binds this host's service under the key, replacing whatever an earlier host left there.
func _rebind_service(key: String, service: Object) -> void:
	if ServiceRegistryScript.has(key):
		ServiceRegistryScript.unbind(key, ServiceRegistryScript.resolve(key))
	ServiceRegistryScript.bind(key, service)


## Binds the UI event bus as a service so runtime-built controls can resolve it.
## A bus already bound (an earlier host in the same process) is reused, like the property manager.
func _ensure_ui_event_bus() -> void:
	if _ui_event_bus == null:
		if ServiceRegistryScript.has(ServiceKeysScript.UI_EVENT_BUS):
			_ui_event_bus = ServiceRegistryScript.resolve(ServiceKeysScript.UI_EVENT_BUS) as GameEventBus
		else:
			_ui_event_bus = GameEventBusScript.new()
			ServiceRegistryScript.bind(ServiceKeysScript.UI_EVENT_BUS, _ui_event_bus)
	if not _ui_event_bus.intent_emitted.is_connected(_on_ui_intent):
		_ui_event_bus.intent_emitted.connect(_on_ui_intent)


func _on_ui_intent(intent_name: String, payload: Dictionary) -> void:
	for handler in _intent_handlers:
		if handler.handles(intent_name):
			_configure_intent_handler(handler)
			_present_intent_result(handler.handle(intent_name, payload))
			return
	match intent_name:
		UiIntentsScript.START_GAME:
			new_game.call_deferred()
		UiIntentsScript.CONTINUE_GAME:
			_continue_or_new_game.call_deferred()
		UiIntentsScript.EXIT_GAME:
			_request_quit_game()
		UiIntentsScript.LANGUAGE_PICKER:
			_build_language_selection_overlay(false)
		UiIntentsScript.LANGUAGE_SELECTED:
			# The settings window picks a language mid-run; the picker only opens outside a run.
			var locale_code := str(payload.get(UiIntentsScript.KEY_LOCALE, ""))
			if _session_is_in_run():
				_on_settings_language_selected(locale_code)
			else:
				_on_language_selected(locale_code)
		UiIntentsScript.OPENING_NARRATION_ADVANCED:
			_advance_opening_narration()
		UiIntentsScript.ENDING_LANGUAGE_SELECTED:
			_on_ending_language_selected(str(payload.get(UiIntentsScript.KEY_CHOICE_ID, "")))
		UiIntentsScript.RESTART_REQUESTED:
			new_game()
		UiIntentsScript.APP_ICON_PRESSED:
			_on_app_pressed(str(payload.get(UiIntentsScript.KEY_APP_ID, "")))
		UiIntentsScript.PHONE_CLOSE_REQUESTED:
			set_view_state("npc_up")
		UiIntentsScript.APP_WINDOW_CLOSE_REQUESTED:
			_close_app_window(str(payload.get(UiIntentsScript.KEY_APP_ID, "")))
		UiIntentsScript.CAMERA_CONSENT_RESOLVED:
			_resolve_camera_consent(bool(payload.get(UiIntentsScript.KEY_ALLOWED, false)))
		UiIntentsScript.CAMERA_SOURCE_SELECTED:
			_on_camera_consent_source_selected(int(payload.get(UiIntentsScript.KEY_INDEX, -1)))
		UiIntentsScript.PHONE_CAMERA_RETRY:
			_retry_phone_camera_connection()
		UiIntentsScript.PHONE_CAMERA_CONTINUE:
			_hide_phone_camera_connection_overlay()
		UiIntentsScript.PHONE_CAMERA_DISABLE:
			_disable_phone_camera_from_connection()
		UiIntentsScript.CONVERSATION_CHOICE_PRESSED:
			_on_reality_choice_selected(str(payload.get(UiIntentsScript.KEY_CHOICE_ID, "")))
		UiIntentsScript.CONVERSATION_CONTINUE_PRESSED:
			_on_reality_continue_pressed()


func _ensure_language_selection_panel() -> void:
	if _language_selection_panel != null and is_instance_valid(_language_selection_panel):
		return
	_language_selection_panel = LanguageSelectionPanelScript.new()
	_language_selection_panel.name = "LanguageSelectionPanel"
	add_child(_language_selection_panel)


func _language_selection_mount_deps() -> Dictionary:
	var locales: Array = []
	for locale_code in GameLocaleScript.SUPPORTED_LOCALES:
		locales.append({
			"code": str(locale_code),
			"name": _locale.native_language_name(str(locale_code)),
		})
	return {
		"locales": locales,
		"language_selected": func() -> bool: return _locale.language_selected,
		"refresh_localized_ui": func() -> void:
			_ui_theme_helper.refresh_localized_ui(_ui_root),
	}


func _ensure_camera_consent_panel() -> void:
	if _camera_consent_panel != null and is_instance_valid(_camera_consent_panel):
		return
	_camera_consent_panel = CameraConsentPanelScript.new()
	_camera_consent_panel.name = "CameraConsentPanel"
	add_child(_camera_consent_panel)


func _camera_consent_mount_deps() -> Dictionary:
	return {
		"populate_camera_source_option": _populate_camera_source_option,
		"camera_enabled": _camera_session.enabled if _camera_session != null else false,
		"apply_ui_theme": _apply_ui_theme,
		"refresh_localized_ui": func() -> void:
			_ui_theme_helper.refresh_localized_ui(_ui_root),
	}


func _ensure_phone_camera_connection_panel() -> void:
	if _phone_camera_connection_panel != null and is_instance_valid(_phone_camera_connection_panel):
		return
	_phone_camera_connection_panel = PhoneCameraConnectionPanelScript.new()
	_phone_camera_connection_panel.name = "PhoneCameraConnectionPanelHost"
	add_child(_phone_camera_connection_panel)


func _phone_camera_connection_mount_deps() -> Dictionary:
	return {
		"set_localized_property": _ui_theme_helper.set_localized_property,
	}


func _on_camera_consent_source_selected(index: int) -> void:
	if _camera_consent_source_option == null:
		return
	_on_camera_source_selected(index, _camera_consent_source_option)


func _ensure_settings_history_panel() -> void:
	if _settings_history_panel != null and is_instance_valid(_settings_history_panel):
		return
	_settings_history_panel = SettingsHistoryPanelScript.new()
	_settings_history_panel.name = "SettingsHistoryPanel"
	add_child(_settings_history_panel)


func _settings_history_mount_deps() -> Dictionary:
	_ensure_window_manager()
	var locales: Array = []
	for locale_code in GameLocaleScript.SUPPORTED_LOCALES:
		locales.append({
			"code": str(locale_code),
			"name": _locale.native_language_name(str(locale_code)),
		})
	return {
		"register_draggable": _window_manager.register,
		"vhs_enabled": _vhs_enabled,
		"locales": locales,
	}


func _ensure_social_feed_panel() -> void:
	_ensure_language_material()
	if _social_feed_panel != null and is_instance_valid(_social_feed_panel):
		return
	_ensure_window_manager()
	_social_feed_panel = SocialFeedPanelScript.new()
	_social_feed_panel.name = "SocialFeedPanel"
	add_child(_social_feed_panel)


func _ensure_language_material() -> void:
	if _language_material != null:
		return
	_language_material = LanguageMaterialScript.new()
	_language_material.configure(game, _locale)
	_social_feed_source().configure(game, _locale, _language_material)


## Rebinds the presenter each use: the flight layer is built after the material.
func _presenter() -> LanguagePresenter:
	if _language_presenter == null:
		_language_presenter = LanguagePresenterScript.new()
		_language_presenter.notebook_home_requested.connect(_ensure_notebook_window_home)
	_language_presenter.configure(
		_pickup_flight_layer,
		_notebook_flight_target,
		_composer_answer_target,
		_ui_theme_helper.theme_color("flash_text"),
		_ui_theme_helper.theme_color("accent"),
	)
	return _language_presenter


func _ensure_phone_launcher_panel() -> void:
	if _phone_launcher_panel != null and is_instance_valid(_phone_launcher_panel):
		return
	_phone_launcher_panel = PhoneLauncherPanelScript.new()
	_phone_launcher_panel.name = "PhoneLauncherPanel"
	add_child(_phone_launcher_panel)


func _phone_launcher_mount_deps() -> Dictionary:
	_ensure_window_manager()
	return {
		"load_texture": _load_runtime_texture,
		"register_draggable": _make_draggable_window,
		"viewport_size": _viewport_size,
		"hud_safe_left": func() -> float:
			var safe_left := 12.0
			var hud_rail := _hud_rail()
			if hud_rail != null:
				safe_left = maxf(safe_left, hud_rail.offset_right + 10.0)
			return safe_left,
		"phone_popup_hud_safe_left": func() -> float:
			var safe_left := 176.0
			var hud_rail := _hud_rail()
			if hud_rail != null:
				safe_left = hud_rail.offset_right + 18.0
			return safe_left,
		"notebook_window_left": func() -> float: return 188.0 if _hud_rail() != null else 44.0,
		"launcher_wallpaper_path": PHONE_LAUNCHER_WALLPAPER_PATH,
		"no_signal_icon_path": GameSocialFeedSourceScript.NO_SIGNAL_ICON_PATH,
	}


func _ensure_reality_conversation_panel() -> void:
	if _reality_conversation_panel != null and is_instance_valid(_reality_conversation_panel):
		return
	_reality_conversation_panel = RealityConversationPanelScript.new()
	_reality_conversation_panel.name = "RealityConversationPanel"
	add_child(_reality_conversation_panel)


func _reality_conversation_mount_deps() -> Dictionary:
	return {
		"viewport_size": _viewport_size,
		"install_rich_text_effect": _install_rich_text_effect,
		"set_dialogue_text": _set_dialogue_text,
		"set_richer_bbcode": _set_richer_bbcode,
		"clear_children": _clear,
		"day_line": func() -> String: return str(_day_plan()["line"]),
		"fallback_actor_name": func() -> String: return _reality_hud_actor_label(_reality_hud_snapshot()),
		"last_spoken_sentence": func() -> String: return game.last_polluted_sentence,
		"npc_understanding": func() -> int: return game.npc_understanding,
		"choice_preview": func(choice_id: String) -> String: return game.preview_typed_reality_choice(choice_id),
		"typed_bbcode": _typed_reality_bbcode,
		"typing_unit_count": func() -> int: return game.get_typed_reality_unit_count(),
	}


func _ensure_notebook_app_panel() -> void:
	if _notebook_app_panel != null and is_instance_valid(_notebook_app_panel):
		return
	_notebook_app_panel = NotebookAppPanelScript.new()
	_notebook_app_panel.name = "NotebookAppPanel"
	add_child(_notebook_app_panel)
	_notebook_app_panel.configure(_notebook_mount_deps())


func _notebook_mount_deps() -> Dictionary:
	return {
		"clear_children": _clear,
		"current_locale": func() -> String: return _locale.current_locale,
		"char_canvas_position": func(unit: String, locale_code: String) -> Vector2:
			return game.get_char_canvas_position(unit, locale_code) if game != null else Vector2.ZERO,
	}


func _inject_settings_camera_block() -> void:
	var slot := _settings_history_panel.get_camera_slot() if _settings_history_panel != null else null
	if slot == null or slot.get_child_count() > 0:
		return
	var camera_rule := HSeparator.new()
	slot.add_child(camera_rule)
	_camera_access_toggle = CheckButton.new()
	_camera_access_toggle.name = "SettingsCameraAccessToggle"
	_camera_access_toggle.text = "允许访问摄像头"
	_camera_access_toggle.button_pressed = _camera_session.enabled if _camera_session != null else false
	_camera_access_toggle.custom_minimum_size.y = 48
	_camera_access_toggle.set_meta("privacy_control", true)
	_camera_access_toggle.toggled.connect(_on_camera_access_toggled)
	slot.add_child(_camera_access_toggle)
	var camera_source_label := _ui_theme_helper.label("摄像头来源", 15, _ui_theme_helper.theme_color("ink"))
	camera_source_label.name = "SettingsCameraSourceLabel"
	slot.add_child(camera_source_label)
	_camera_source_button_group = ButtonGroup.new()
	_camera_source_button_group.allow_unpress = false
	_camera_computer_button = Button.new()
	_camera_computer_button.name = "SettingsOpenComputerCameraButton"
	_camera_computer_button.text = "打开电脑摄像头并开启 X-ray"
	_camera_computer_button.tooltip_text = "只会选择电脑内置或 USB 摄像头。"
	_camera_computer_button.toggle_mode = true
	_camera_computer_button.button_group = _camera_source_button_group
	_camera_computer_button.set_meta("camera_source_id", "computer")
	_camera_computer_button.custom_minimum_size.y = 52
	_camera_computer_button.pressed.connect(_activate_camera_source.bind("computer"))
	slot.add_child(_camera_computer_button)
	_camera_phone_button = Button.new()
	_camera_phone_button.name = "SettingsConnectPhoneCameraButton"
	_camera_phone_button.text = "连接手机摄像头并开启 X-ray"
	_camera_phone_button.tooltip_text = "只会选择手机连续互通或虚拟摄像头。"
	_camera_phone_button.toggle_mode = true
	_camera_phone_button.button_group = _camera_source_button_group
	_camera_phone_button.set_meta("camera_source_id", "phone")
	_camera_phone_button.custom_minimum_size.y = 52
	_camera_phone_button.pressed.connect(_activate_camera_source.bind("phone"))
	slot.add_child(_camera_phone_button)
	_refresh_camera_source_buttons()
	var phone_fallback_note := _ui_theme_helper.label("手机备用会优先寻找连续互通相机或虚拟摄像头。", 13, _ui_theme_helper.theme_color("ink"))
	phone_fallback_note.name = "SettingsPhoneCameraFallbackNote"
	phone_fallback_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(phone_fallback_note)
	var camera_privacy := _ui_theme_helper.label("镜头仅在启用时由本地 MediaPipe 读取。", 13, _ui_theme_helper.theme_color("ink"))
	camera_privacy.name = "SettingsCameraPrivacyNote"
	camera_privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(camera_privacy)
	_camera_status_label = _ui_theme_helper.label(
		HandTrackingStatusScript.display_text(_camera_session.tracking_status) if _camera_session != null else HandTrackingStatusScript.display_text(HandTrackingStatusScript.Status.DISABLED),
		14,
		_ui_theme_helper.theme_color("accent")
	)
	_camera_status_label.name = "SettingsCameraStatus"
	_camera_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(_camera_status_label)
	if _camera_session != null:
		_camera_session.access_toggle = _camera_access_toggle
		_camera_session.computer_button = _camera_computer_button
		_camera_session.phone_button = _camera_phone_button
		_camera_session.status_label = _camera_status_label


func _build_history_window() -> void:
	_ensure_settings_history_panel()
	_settings_history_panel.mount(_ui_root, _settings_history_mount_deps())


func _toggle_history_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.toggle()


func _close_history_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.close()


func _model_is_on(property_name: String) -> bool:
	var model := _value_model(property_name)
	return model != null and bool(model.read())


func _toggle_settings_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.toggle_settings()


func _close_settings_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.close_settings()


func _on_settings_open_changed(_open: Variant) -> void:
	# Registering in _enter_tree delivers the current value before the UI exists.
	if not is_node_ready():
		return
	if _reality_scene_adapter != null:
		_reality_scene_adapter.set_paused(_model_is_on(PropertyKeysScript.SETTINGS_OPEN))
	if _apple_hud_panel != null:
		_apple_hud_panel.hide_tooltip()
	_update_visibility()


func _apply_master_volume(value: Variant) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, float(value) / 100.0)))


func _master_volume_model() -> ValuePropertyModel:
	return _value_model(PropertyKeysScript.MASTER_VOLUME)


func _value_model(property_name: String) -> ValuePropertyModel:
	return GameModelsScript.value(property_name)


func _on_settings_language_selected(locale_code: String) -> void:
	if locale_code.is_empty():
		return
	if _reality_interaction_is_active():
		_exit_reality_interaction(false)
	if not _locale.select_language(locale_code):
		return
	_locale.save_preferences(_vhs_enabled, _camera_session.enabled, _camera_session.source)
	# 换语言即换字池:清空造句台,避免旧语言的字混进新语言的句子。
	if game != null:
		game.free_sentence_clear()
	_render()
	_ui_theme_helper.refresh_localized_ui(_ui_root)
	_refresh_camera_source_option_labels()


func _on_manual_save_pressed() -> void:
	var progress_saved := _save_progress()
	var preferences_saved := _locale.save_preferences(_vhs_enabled, _camera_session.enabled, _camera_session.source)
	var save_status := _value_model(PropertyKeysScript.SAVE_STATUS)
	if save_status != null:
		save_status.write("已保存当前进度与设置。" if progress_saved and preferences_saved else "保存失败，请检查本地写入权限。")
	_ui_theme_helper.refresh_localized_ui(_ui_root)


func _on_return_main_menu_pressed() -> void:
	call_deferred("show_main_menu")


func _present_vhs(value: bool) -> void:
	_vhs_enabled = value
	if _vhs_overlay != null:
		_vhs_overlay.visible = value


func _on_camera_access_toggled(value: bool) -> void:
	_camera_session_decided = true
	_set_camera_enabled(value, true)


func _request_quit_game() -> void:
	game.mark_exit_prompt_seen()
	_show_quit_prompt()


func _show_quit_prompt() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.request_quit()


func _confirm_quit_game() -> void:
	if _game_started:
		_save_progress()
	_locale.save_preferences(_vhs_enabled, _camera_session.enabled, _camera_session.source)
	get_tree().quit()


func _quit_game() -> void:
	_request_quit_game()


func _apply_reality_layout() -> void:
	var hud_right := 0.0
	var hud_rail := _hud_rail()
	if hud_rail != null:
		hud_right = hud_rail.offset_right
	if _reality_conversation_panel != null:
		_reality_conversation_panel.layout(hud_right)


func _apply_view_toggle_layout() -> void:
	if _view_toggle_button == null:
		return
	var viewport_size := _viewport_size()
	_view_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	if viewport_size.x >= 760.0:
		_view_toggle_button.offset_left = 470.0
		_view_toggle_button.offset_top = -92.0
		_view_toggle_button.offset_right = 596.0
		_view_toggle_button.offset_bottom = -36.0
		return
	var safe_left := 12.0
	var hud_rail := _hud_rail()
	if hud_rail != null:
		safe_left = hud_rail.offset_right + 12.0
	var safe_right := viewport_size.x - 12.0
	var available_width := maxf(126.0, safe_right - safe_left)
	var button_width := minf(220.0, available_width)
	var button_left := safe_left + (available_width - button_width) * 0.5
	_view_toggle_button.offset_left = button_left
	_view_toggle_button.offset_top = -76.0
	_view_toggle_button.offset_right = button_left + button_width
	_view_toggle_button.offset_bottom = -20.0


func _apply_responsive_layouts_if_needed(force: bool = false) -> void:
	var viewport_size := _viewport_size()
	if not force and viewport_size == _last_responsive_layout_size:
		return
	_last_responsive_layout_size = viewport_size
	if _phone_launcher_panel != null and game != null:
		_phone_launcher_panel.relayout()
	if _social_feed_panel != null:
		var social_safe_left := 12.0
		var hud_rail := _hud_rail()
		if hud_rail != null:
			social_safe_left = maxf(social_safe_left, hud_rail.offset_right + 10.0)
		_social_feed_panel.layout_detail(viewport_size, social_safe_left)
		_social_feed_panel.layout_window(viewport_size, social_safe_left)
	_apply_reality_layout()
	_apply_view_toggle_layout()
	_layout_settings_window()
	if _cinematic_bars != null:
		_cinematic_bars.relayout(_viewport_size())
	_layout_hud_rail()


func _refresh_phone_shell() -> void:
	if _ending_screen_installed:
		return
	_render_app()
	_update_phone_shell_visibility()
	_apply_phone_shell_theme()


func _refresh_reality_hud() -> void:
	if _ending_screen_installed:
		return
	_render_world_prompt()
	_render_reality()
	_update_reality_hud_visibility()


func _refresh_reality_hud_in_run() -> void:
	if _session_is_in_run():
		_refresh_reality_hud()


func _refresh_ending() -> void:
	if not _ending_screen_installed:
		return
	_render_ending()
	_update_visibility()
	var ending := _ending_screen_control()
	if ending != null:
		_ui_theme_helper.refresh_localized_ui(ending)


func _refresh_play_surfaces() -> void:
	if _ending_screen_installed:
		return
	_ensure_reality_floor_current()
	if _reality_scene_adapter != null:
		_reality_scene_adapter.sync_world_state(_reality_scene_deps())
	_render_status()
	_refresh_phone_shell()
	_refresh_reality_hud()
	_update_visibility()
	_apply_world_theme()
	_apply_ui_theme()
	_ui_theme_helper.refresh_localized_ui(_ui_root)


func _apply_phone_shell_theme() -> void:
	var targets: Array[Node] = []
	if _phone_launcher_panel != null:
		targets.append(_phone_launcher_panel.get_phone_panel())
		targets.append(_phone_launcher_panel.get_app_window("notebook"))
	if _social_feed_panel != null:
		targets.append(_social_feed_panel.get_app_window())
		targets.append(_social_feed_panel.get_detail_window())
	for target in targets:
		_theme_phone_window(target)


func _theme_phone_window(target: Node) -> void:
	if target == null or not is_instance_valid(target):
		return
	_apply_ui_theme(target)
	_ui_theme_helper.localize_control_tree(target)


func _render() -> void:
	if _world_hotkeys_installed:
		_request_ending_if_unlocked()
	if _ending_screen_installed:
		_refresh_ending()
		return
	_refresh_play_surfaces()


func _render_status() -> void:
	if _reality_scene_adapter != null:
		_reality_scene_adapter.sync_ultimate_task_props(_reality_scene_deps())


func _render_world_prompt() -> void:
	if _world_prompt == null:
		return
	var hud := _reality_hud_snapshot()
	var plan := _day_plan()
	if str(hud.get("view_state", "")) == "phone_down":
		_world_prompt.text = "%s\n路面在脚下滑动。手机 App 的窗口浮在屏幕旁边。" % plan["title"]
	elif _reality_door_opening():
		_world_prompt.text = ""
	elif bool(hud.get("interaction_active", false)):
		var conversation: Dictionary = hud.get("conversation", {})
		_world_prompt.text = "%s：%s" % [_reality_hud_actor_label(hud), _corrupt(str(conversation.get("prompt", "")))]
	else:
		var nearby: Dictionary = hud.get("nearby", {})
		match str(nearby.get("kind", "none")):
			"item":
				var item_data: Dictionary = nearby.get("item_data", {})
				_world_prompt.text = "F  拾取 · %s\n%s" % [
					str(item_data.get("label", "街区遗物")),
					str(item_data.get("description", "信号已经写入。")),
				]
			"actor":
				_world_prompt.text = "F  交谈 · %s" % str(nearby.get("actor_label", "对方"))
			"door":
				_world_prompt.text = "F  开门"
			_:
				_world_prompt.text = ""


func _render_app() -> void:
	for app_id in ["social", "notebook"]:
		if not _app_bodies.has(app_id):
			continue
		_app_body = _app_bodies[app_id] as VBoxContainer
		_app_title = _app_titles[app_id] as Label
		match app_id:
			"notebook":
				_app_title.text = "笔记本 App"
				_render_notebook_app()
			"social":
				_render_social_app()


func _render_social_app() -> void:
	_app_title.text = "社交媒体 App"
	if _social_feed_panel == null:
		return
	_social_feed_panel.render_app()
	_social_feed_panel.render_companion()


## The social panel already repainted its new page; only the shell around it needs the theme and visibility.
func _on_social_page_changed() -> void:
	if _ending_screen_installed:
		return
	_update_phone_shell_visibility()
	_apply_phone_shell_theme()


## Points the handler about to handle an intent at the current run; only the social feed and the notebook need
## the language material, so only they build it.
func _configure_intent_handler(handler: IntentHandler) -> void:
	if handler == _settings_intent_handler:
		_settings_intent_handler.configure(game)
	else:
		_ensure_language_material()
		_social_intent_handler.configure(game, _language_material, _social_feed_source())
		_notebook_intent_handler.configure(game, _language_material, _locale, _composer_answer_panel)


## The publish page's answer area a notebook tile can be dropped on, or null while it is not built.
func _composer_answer_panel() -> Control:
	return _find_control_by_name(_ui_root, "ComposerAnswerPanel")


## A handler already changed the state and wrote its feedback; the host only presents what it asks for.
func _present_intent_result(result: IntentResult) -> void:
	match result.presentation:
		IntentResultScript.SUBMIT:
			_present_submit_outcome(result.outcome)
		SocialIntentHandlerScript.PAGE_CHANGED:
			_on_social_page_changed()
		SocialIntentHandlerScript.WINDOW_CLOSED:
			_present_app_window_closed("social")
		SocialIntentHandlerScript.PICKUP:
			_presenter().present_pickup(result.outcome, result.unit, get_viewport().get_mouse_position())
			_present_pickup_outcome(result.outcome)
		NotebookIntentHandlerScript.PLACE:
			_presenter().present_place(bool(result.value), result.unit, get_viewport().get_mouse_position())
		SettingsIntentHandlerScript.VHS_TOGGLED:
			_present_vhs(bool(result.value))
		SettingsIntentHandlerScript.SAVE_REQUESTED:
			_on_manual_save_pressed()
		SettingsIntentHandlerScript.MAIN_MENU_REQUESTED:
			_on_return_main_menu_pressed()
		SettingsIntentHandlerScript.QUIT_PROMPTED:
			_show_quit_prompt()
		SettingsIntentHandlerScript.QUIT_CONFIRMED:
			_confirm_quit_game()
		SettingsIntentHandlerScript.HISTORY_TOGGLED:
			_toggle_history_window()
		SettingsIntentHandlerScript.SETTINGS_TOGGLED:
			_toggle_settings_window()


func _render_notebook_app() -> void:
	if _notebook_app_panel == null:
		return
	_notebook_app_panel.render(_app_body)


func _render_reality() -> void:
	if _reality_conversation_panel != null:
		_reality_conversation_panel.render()


func _typed_reality_bbcode() -> String:
	var normal_color := _ui_theme_helper.theme_color("surface").to_html(false)
	var pending_color := _ui_theme_helper.theme_color("pending").to_html(false)
	var corrupted_color := _ui_theme_helper.theme_color("error").to_html(false)
	var parts: Array[String] = []
	var conversation: Dictionary = _reality_conversation_snapshot()
	for unit in conversation.get("revealed_units", []):
		var color := corrupted_color if bool(unit.get("corrupted", false)) else normal_color
		var display := _escape_bbcode(str(unit.get("display", "")))
		if bool(unit.get("corrupted", false)):
			parts.append("[color=#%s][cuss]%s[][]" % [color, display])
		else:
			parts.append("[color=#%s]%s[]" % [color, display])
	var suffix := game.get_typed_reality_unrevealed_suffix()
	if not suffix.is_empty():
		parts.append("[color=#%s]%s[]" % [pending_color, _escape_bbcode(suffix)])
	return "[curspull pull=0.18]%s[]" % "".join(parts)


func _set_dialogue_text(label: RichTextLabel, value: String) -> void:
	if value.is_empty():
		_set_richer_bbcode(label, "")
		return
	_set_richer_bbcode(label, "[curspull pull=0.12]%s[]" % _escape_bbcode(_locale.translate(value)))


func _set_richer_bbcode(label: RichTextLabel, value: String) -> void:
	label.call("set_bbcode", value)


func _install_rich_text_effect(label: RichTextLabel, effect_name: String) -> void:
	label.call("_install_effect", effect_name)


func _escape_bbcode(value: String) -> String:
	# 先把左括号替换成不含括号的哨兵,避免替换级联("[" 变成 "[lb[rb]")。
	var sentinel := String.chr(1)
	return value.replace("[", sentinel).replace("]", "[rb]").replace(sentinel, "[lb]")


func _on_reality_choice_selected(choice_id: String) -> void:
	if game.select_typed_reality_choice(choice_id):
		_refresh_reality_hud_in_run()
		_sync_audio_state(false)


func _on_reality_continue_pressed() -> void:
	if str(_reality_conversation_snapshot().get("phase", "")) == "result" and game.continue_typed_reality_conversation():
		_localize_active_conversation()
		_refresh_reality_hud_in_run()
		_sync_audio_state(false)
		return
	_exit_reality_interaction()


func _advance_typed_reality_character() -> bool:
	if not _reality_interaction_is_active():
		return false
	var result: Dictionary = game.advance_typed_reality_character()
	if not bool(result.get("advanced", false)):
		return false
	_refresh_reality_hud_in_run()
	_sync_audio_state(false)
	if str(_reality_conversation_snapshot().get("actor_type", "")) == "doll" and _reality_scene_adapter != null:
		_reality_scene_adapter.sync_world_state(_reality_scene_deps())
	return true


func _update_visibility() -> void:
	_update_phone_shell_visibility()
	_update_world_for_phone_view()
	var in_phone := _phone_view_is_down()
	var show_play := _session_shows_play_chrome()
	if _camera_session != null and _camera_session.hand_xray_overlay != null:
		_camera_session.hand_xray_overlay.visible = _camera_session.enabled and show_play and not in_phone
	if _settings_window != null:
		_settings_window.visible = _model_is_on(PropertyKeysScript.SETTINGS_OPEN) and show_play
	if _desk_log != null:
		_desk_log.visible = show_play and in_phone
	if _vhs_overlay != null:
		_vhs_overlay.visible = _vhs_enabled and show_play
	if _apple_hud_panel != null:
		_apple_hud_panel.set_shown(show_play)
	_update_reality_hud_visibility()
	_layout_hud_rail()


func _ending_screen_control() -> Control:
	if _ui_root == null:
		return null
	return _ui_root.get_node_or_null("EndingScreen") as Control


func _update_reality_hud_visibility() -> void:
	if not _session_shows_play_chrome():
		if _world_prompt != null:
			_world_prompt.visible = false
		if _reality_conversation_panel != null:
			_reality_conversation_panel.set_shown(false)
		return
	var hud := _reality_hud_snapshot()
	var in_phone := str(hud.get("view_state", "phone_down")) == "phone_down"
	var interaction_active := bool(hud.get("interaction_active", false))
	if _world_prompt != null:
		var nearby_kind := str((hud.get("nearby", {}) as Dictionary).get("kind", "none"))
		_world_prompt.visible = (not in_phone) and (not interaction_active) and nearby_kind != "none"
	var interaction_visible := (not in_phone) and interaction_active and not _reality_door_opening()
	if _reality_conversation_panel != null:
		_reality_conversation_panel.set_shown(interaction_visible)


func _app_window_is_open(app_id: String) -> bool:
	return game != null and game.is_app_window_open(app_id)


func _phone_view_is_down() -> bool:
	return str(_phone_shell_snapshot().get("view_state", "phone_down")) == "phone_down"


func _update_phone_shell_visibility() -> void:
	var in_phone := _phone_view_is_down()
	var show_play := _session_shows_play_chrome()
	# 手机始终留在画面上:打开 App 只是弹出对应窗口,不会让手机消失。
	var show_phone_home := show_play and in_phone
	if _phone_launcher_panel != null:
		_phone_launcher_panel.set_shown(show_play and not _phone_locked())
	if _phone_tab != null:
		_phone_tab.visible = false
	for app_id in _app_windows.keys():
		var app_window := _app_windows[app_id] as Control
		if app_window != null:
			app_window.visible = show_phone_home and _app_window_is_open(app_id)
	if _social_feed_panel != null:
		_social_feed_panel.update_visibility(show_phone_home, _app_window_is_open("social"))
	if _notebook_app_panel != null and is_instance_valid(_notebook_app_panel):
		_notebook_app_panel.set_shown(show_phone_home and _app_window_is_open("notebook"))
	if _phone_down_backdrop_image != null:
		_phone_down_backdrop_image.visible = show_play and (in_phone or _phone_art_alpha > 0.03)
	if _hand_phone_image != null:
		_hand_phone_image.visible = show_play and (in_phone or _phone_art_alpha > 0.03)


func _update_world_for_phone_view() -> void:
	var in_phone := _phone_view_is_down()
	if _view_toggle_button != null:
		_view_toggle_button.visible = (
			_session_shows_play_chrome()
			and not _model_is_on(PropertyKeysScript.SETTINGS_OPEN)
			and not _phone_locked()
			and (in_phone or not _reality_interaction_is_active())
		)
		_view_toggle_button.text = "放下手机" if in_phone else "拿起手机"
	if _reality_scene_adapter != null:
		_reality_scene_adapter.set_street_shown(not in_phone)
	if _cinematic_bars != null:
		_cinematic_bars.set_bars_visible(_session_shows_play_chrome() and not in_phone)


func _animate_world(delta: float) -> void:
	if not _game_started:
		if _camera != null:
			_camera.position = _camera.position.lerp(Vector3(0.0, 1.54, 2.55), minf(1.0, delta * 3.0))
			_camera.rotation_degrees = _camera.rotation_degrees.lerp(Vector3(-18.0, 0.0, 0.0), minf(1.0, delta * 3.0))
		_animate_vhs(delta)
		return
	var camera_target_pos := Vector3(0.0, 1.45, 2.2)
	var camera_target_rot := Vector3(-54.0, 0.0, 0.0)
	var look_pose: Dictionary = _reality_scene_adapter.pose() if _reality_scene_adapter != null else {}
	if str(_phone_shell_snapshot().get("view_state", "")) == "npc_up" and bool(look_pose.get("has_player", false)):
		camera_target_pos = (look_pose.get("player_position", Vector3.ZERO) as Vector3) + Vector3(0.0, 1.56, 0.0)
		camera_target_rot = Vector3(float(look_pose.get("pitch", 0.0)), float(look_pose.get("yaw", 0.0)), 0.0)
	var camera_lerp := minf(1.0, delta * (7.0 if str(_phone_shell_snapshot().get("view_state", "")) == "npc_up" else 5.0))
	_camera.position = _camera.position.lerp(camera_target_pos, camera_lerp)
	var current_rotation := _camera.rotation_degrees
	current_rotation.x = lerpf(current_rotation.x, camera_target_rot.x, camera_lerp)
	current_rotation.y = rad_to_deg(lerp_angle(deg_to_rad(current_rotation.y), deg_to_rad(camera_target_rot.y), camera_lerp))
	current_rotation.z = lerpf(current_rotation.z, 0.0, camera_lerp)
	_camera.rotation_degrees = current_rotation
	_camera.fov = 58.0
	var target_alpha := 1.0 if str(_phone_shell_snapshot().get("view_state", "")) == "phone_down" else 0.0
	_phone_art_alpha = lerpf(_phone_art_alpha, target_alpha, minf(1.0, delta * 3.4))
	_phone_sway_time += delta * 1.4
	if _phone_down_backdrop_image != null:
		_phone_down_backdrop_image.visible = str(_phone_shell_snapshot().get("view_state", "")) == "phone_down" or _phone_art_alpha > 0.03
		_phone_down_backdrop_image.modulate.a = _phone_art_alpha
		var viewport_size := _viewport_size()
		var bob := sin(_phone_sway_time * 2.2) * 2.4
		var sway := sin(_phone_sway_time * 1.1) * 1.1
		_phone_down_backdrop_image.pivot_offset = viewport_size * 0.5
		_phone_down_backdrop_image.scale = Vector2(1.012, 1.012)
		var settled_position := Vector2(-viewport_size.x * 0.006 + sway, -viewport_size.y * 0.006 + bob)
		_phone_down_backdrop_image.position = Vector2(settled_position.x, lerpf(70.0, settled_position.y, _phone_art_alpha))
	if str(_phone_shell_snapshot().get("view_state", "")) == "npc_up" and bool(look_pose.get("has_player", false)):
		_reality_scene_adapter.update_authored_events(delta, -_camera.global_basis.z)
	_animate_vhs(delta)


func _animate_vhs(_delta: float) -> void:
	if _vhs_overlay == null or not _vhs_enabled:
		return
	var snapshot := _pollution_stage_snapshot()
	_vhs_overlay.configure(
		float(snapshot.get("vhs_intensity", 0.58)),
		float(snapshot.get("vhs_pollution", 0.0))
	)


func _viewport_size() -> Vector2:
	if get_viewport() != null:
		return get_viewport().get_visible_rect().size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	)


func _load_runtime_texture(path: String) -> Texture2D:
	return _textures.load_texture(path)




func _is_pickable_social_character(character: String) -> bool:
	return not character.is_empty() and not " \t\r\n，。！？；：、,.!?;:（）()【】[]《》<>“”\"'—-…".contains(character)


func _close_app_window(app_id: String) -> void:
	game.close_app_window(app_id)
	_write_feedback_text("关闭 %s 窗口。" % app_id)
	_present_app_window_closed(app_id)


## The window model is already closed; shut the social post with it and repaint the shell.
func _present_app_window_closed(app_id: String) -> void:
	if app_id == "social" and _social_feed_panel != null:
		_social_feed_panel.close_detail()
	_refresh_phone_shell()


func _open_phone_launcher() -> void:
	game.set_view_state("phone_down")
	_set_reality_mouse_look(false)
	if _phone_launcher_panel != null:
		_phone_launcher_panel.move_phone_to_front()
	_write_feedback_text("展开手机主页。")
	_refresh_phone_shell()
	_update_world_for_phone_view()


func _ensure_window_manager() -> void:
	if _window_manager != null:
		return
	_window_manager = DraggableWindowManagerScript.new()
	_window_manager.name = "DraggableWindowManager"
	add_child(_window_manager)
	_window_manager.set_clamp_bounds(
		-1.0e6,
		DraggableWindowManager.DEFAULT_VISIBLE_EDGE,
		DraggableWindowManager.DEFAULT_BOTTOM_INSET
	)
	_bind_window_manager()
	_sync_window_manager_enabled()


## Binds this host's window manager as a service so panels can register their own drag handles.
## A manager left by an earlier host is replaced, like the UI theme.
func _bind_window_manager() -> void:
	_rebind_service(ServiceKeysScript.WINDOW_MANAGER, _window_manager)


func _sync_window_manager_enabled() -> void:
	if _window_manager != null:
		_window_manager.enabled = _world_hotkeys_installed
	_sync_edge_drawer_enabled()


func _move_window_for_test(window_id: String, delta: Vector2) -> bool:
	_ensure_window_manager()
	return _window_manager.move_window(window_id, delta)


func _window_position_for_test(window_id: String) -> Vector2:
	_ensure_window_manager()
	return _window_manager.get_window_position(window_id)


func _make_draggable_window(window: Control, window_id: String, handle: Control) -> void:
	_ensure_window_manager()
	_window_manager.register(window, window_id, handle)


func _find_control_by_name(node: Node, node_name: String) -> Control:
	if node == null:
		return null
	if node.name == node_name and node is Control:
		return node as Control
	for child in node.get_children():
		var found := _find_control_by_name(child, node_name)
		if found != null:
			return found
	return null


func _apply_world_theme() -> void:
	if _reality_scene_adapter != null:
		_reality_scene_adapter.apply_palette(_ui_theme_helper.active_palette())


func _apply_ui_theme(node: Node = null) -> void:
	if node == null:
		node = _ui_root
	if node == null:
		return
	_ui_theme_helper.apply_ui_theme(node)


func _bind_narrative_director() -> void:
	_ensure_narrative_director()
	_narrative_director.apply_deps(_narrative_overlay_deps())


func _capture_frozen_frame_texture() -> Texture2D:
	var viewport := get_viewport()
	if viewport == null or DisplayServer.get_name().to_lower() == "headless":
		return null
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		return null
	var frozen_image := viewport_texture.get_image()
	if frozen_image == null or frozen_image.is_empty():
		return null
	return ImageTexture.create_from_image(frozen_image)


func session_mode() -> String:
	_ensure_flow_manager()
	return _flow.current_id()


func has_session_state(id: String) -> bool:
	_ensure_flow_manager()
	return _flow.has(id)


func _session_is_in_run() -> bool:
	return session_mode() in ["prologue", "gameplay", "narrative", "ending"]


func _session_shows_play_chrome() -> bool:
	return _play_screen_installed


func session_screen_set() -> PackedStringArray:
	_ensure_flow_manager()
	var state: FlowState = _flow.current_state()
	if state != null and state.has_method("screen_set"):
		return state.screen_set()
	return PackedStringArray()


func _ensure_flow_manager() -> void:
	if _flow != null:
		return
	_flow = FlowManagerScript.new()
	_flow.register(MainMenuFlowStateScript.new(self))
	_flow.register(PrologueFlowStateScript.new(self))
	_flow.register(GameplayFlowStateScript.new(self))
	_flow.register(NarrativeFlowStateScript.new(self))
	_flow.register(EndingFlowStateScript.new(self))


func _request_session_mode(id: String) -> bool:
	_ensure_flow_manager()
	if _flow.current_id() == id:
		return true
	var changed := _flow.transition_to(id)
	if changed:
		_sync_window_manager_enabled()
	return changed


func _ending_is_unlocked() -> bool:
	return game != null and game.ending_unlocked


## The progress check after a valid interaction can unlock the ending; the host asks right after it ran.
func _present_ending_if_unlocked() -> bool:
	if not _session_is_in_run() or not _request_ending_if_unlocked():
		return false
	_refresh_ending()
	return true


func _request_ending_if_unlocked() -> bool:
	if not _ending_is_unlocked():
		return false
	_request_session_mode("ending")
	return true


func _complete_narrative_beat(exit_mode: String) -> void:
	_sync_audio_state(false)
	if exit_mode == "ending":
		_request_session_mode("ending")
		_refresh_ending()
		return
	if exit_mode == "gameplay":
		_request_session_mode("gameplay")
	_refresh_play_surfaces()


func _render_ending() -> void:
	if _canvas == null:
		_build_world(not _ending_is_unlocked())
	_ensure_ending_screen_panel()
	_ending_screen_panel.mount(_ui_root, _ending_screen_mount_deps())
	_ending_screen_panel.render()


func _ensure_ending_screen_panel() -> void:
	if _ending_screen_panel != null and is_instance_valid(_ending_screen_panel):
		return
	_ending_screen_panel = EndingScreenPanelScript.new()
	_ending_screen_panel.name = "EndingScreenPanel"
	add_child(_ending_screen_panel)


func _ending_screen_mount_deps() -> Dictionary:
	return {
		"translate": func(text: String) -> String: return _locale.translate(text),
		"set_localized_property": _ui_theme_helper.set_localized_property,
		"refresh_localized": _ui_theme_helper.refresh_localized_ui,
		"epilogue_lines": func() -> Array: return NarrativeSessionCatalogScript.epilogue_lines(_locale.current_locale),
		"language_choices": func() -> Array: return game.get_ending_language_choices(_locale.current_locale),
		"language_output": func() -> String: return game.get_ending_language_output(_locale.current_locale),
		"relationship_residue": func() -> int: return game.relationship_residue,
		"relationship_state_label": func() -> String: return game.get_relationship_state_label(),
	}


func _on_ending_language_selected(choice_id: String) -> void:
	game.choose_ending_language(choice_id)


func _on_app_pressed(app_id: String) -> void:
	game.set_view_state("phone_down")
	_set_reality_mouse_look(false)
	game.set_active_app(app_id)
	if app_id == "social":
		var social_window := _app_windows.get("social") as Control
		if social_window != null:
			social_window.move_to_front()
	_write_feedback_text("打开 %s。" % app_id)
	_refresh_phone_shell()
	_update_world_for_phone_view()


## ============ 自由造句台(多邻国式:tap 入句、tap 撤回、随时投稿)============

## 多邻国 U1 质感:圆角约为高度 1/4、浅底细描边、底部厚边模拟浮起阴影;
## 按下时下沉 2px(上边距+2/下边距-2,底厚边收薄);ghost 为凹陷灰。

func _commit_notebook_canvas_positions() -> void:
	if _notebook_app_panel == null or not is_instance_valid(_notebook_app_panel):
		return
	_notebook_app_panel.commit_canvas_positions()


func _composer_answer_target() -> Vector2:
	var answer_flow := _find_control_by_name(_ui_root, "ComposerAnswerFlow")
	if answer_flow != null and is_instance_valid(answer_flow):
		return LanguageMaterialScript.composer_answer_target(answer_flow)
	return _notebook_flight_target()


func _build_pickup_flight_layer() -> void:
	_pickup_flight_layer = FlyToTargetLayer.new()
	_pickup_flight_layer.name = "PickupFlightLayer"
	_pickup_flight_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 低于闪回(100):闪回黑幕之下,仍在飞行的字不被其他覆盖层吞掉。
	_pickup_flight_layer.z_index = 97
	_ui_root.add_child(_pickup_flight_layer)
	_pickup_flight_layer.flight_landed.connect(_on_pickup_flight_landed)


## 拾字时把笔记本窗口召回左上角初始位置并打开,让玩家看见字飞进去。
func _ensure_notebook_window_home() -> void:
	game.open_app_window("notebook")
	var window := _notebook_window_control()
	if window == null:
		return
	if _phone_launcher_panel != null:
		_phone_launcher_panel.layout_app_window("notebook")
	window.visible = game != null and str(_phone_shell_snapshot().get("view_state", "")) == "phone_down"


## A pickup already shows through the models; the host presents it only when it changed more than the notebook.
func _present_pickup_outcome(outcome: ActionOutcomeScript) -> void:
	if _interaction_changed_the_run(outcome):
		_present_interaction_outcome(outcome)


## Whether a valid interaction left a flashback to play, a new floor or an open ending.
func _interaction_changed_the_run(outcome: ActionOutcomeScript) -> bool:
	return outcome.succeeded and (outcome.flashback or outcome.floor_changed or _ending_is_unlocked())


func _present_submit_outcome(outcome: ActionOutcomeScript) -> void:
	if outcome.succeeded:
		_present_interaction_outcome(outcome)


func _on_pickup_flight_landed(_unit: String) -> void:
	GameEventBusScript.raise_event(GameEventsScript.SFX_REQUESTED, {GameEventsScript.KEY_CUE: GameEventsScript.CUE_PICKUP_LAND})
	GameEventBusScript.raise_event(GameEventsScript.SFX_REQUESTED, {GameEventsScript.KEY_CUE: GameEventsScript.CUE_NOTEBOOK_HINGE})
	_squash_notebook_window()


func _notebook_window_control() -> Control:
	var window := _app_windows.get("notebook") as Control
	if window != null and is_instance_valid(window):
		return window
	return null


func _notebook_flight_target() -> Vector2:
	return LanguageMaterialScript.notebook_flight_target(_notebook_window_control())


func _squash_notebook_window() -> void:
	var window := _notebook_window_control()
	if window == null or not window.visible:
		return
	if _notebook_squash_tween != null and _notebook_squash_tween.is_valid():
		_notebook_squash_tween.kill()
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2.ONE
	_notebook_squash_tween = create_tween()
	_notebook_squash_tween.tween_property(window, "scale", Vector2(1.05, 0.96), 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_notebook_squash_tween.tween_property(window, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _write_feedback_text(text: String) -> void:
	GameModelsScript.write_feedback(text)


## A valid interaction completed. A flashback it crossed plays as a narrative beat; otherwise the host presents the
## new floor or the ending the progress check left.
func _present_interaction_outcome(outcome: ActionOutcomeScript) -> void:
	var settlement := outcome.settlement()
	if settlement.is_empty():
		_present_progress()
		return
	_refresh_play_surfaces()
	_sync_audio_state(false)
	_bind_narrative_director()
	_narrative_director.play_beat(settlement, _ending_is_unlocked())


## Shows the ending when the progress check unlocked it; otherwise redraws the play surfaces, which rebuild the floor
## when it moved.
func _present_progress() -> void:
	_sync_audio_state(false)
	if _present_ending_if_unlocked():
		return
	_refresh_play_surfaces()


func _day_plan() -> Dictionary:
	var current_day := 1 if game == null else game.day
	return SocialFeedCatalogScript.day_plan_for_day(current_day)


func _corrupt(text: String) -> String:
	return _social_feed_source().corrupt_text(text)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
