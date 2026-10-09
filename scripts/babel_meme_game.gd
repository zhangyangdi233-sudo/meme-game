extends Node3D

const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const RicherTextLabelScript = preload("res://addons/richtext2/richer_text_label.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const EchoQuoteContentScript = preload("res://scripts/narrative/echo_quote_content.gd")
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
const LanguageSelectionPanelScript = preload("res://scripts/ui/language_selection_panel.gd")
const ProloguePanelScript = preload("res://scripts/ui/prologue_panel.gd")
const CameraConsentPanelScript = preload("res://scripts/ui/camera_consent_panel.gd")
const PhoneCameraConnectionPanelScript = preload("res://scripts/ui/phone_camera_connection_panel.gd")
const PhoneLauncherPanelScript = preload("res://scripts/ui/phone_launcher_panel.gd")
const RealityConversationPanelScript = preload("res://scripts/ui/reality_conversation_panel.gd")
const RealityLanguageComposerPanelScript = preload("res://scripts/ui/reality_language_composer_panel.gd")
const NotebookAppPanelScript = preload("res://scripts/ui/notebook_app_panel.gd")
const BabelAppPanelScript = preload("res://scripts/ui/babel_app_panel.gd")
const DollGuidePanelScript = preload("res://scripts/ui/doll_guide_panel.gd")
const EndingScreenPanelScript = preload("res://scripts/ui/ending_screen_panel.gd")
const PlaytestAssistPanelScript = preload("res://scripts/ui/playtest_assist_panel.gd")
const AppleHudPanelScript = preload("res://scripts/ui/apple_hud_panel.gd")
const PollutionStageScript = preload("res://scripts/world/pollution_stage.gd")
const RealitySceneAdapterScript = preload("res://scripts/world/reality_scene_adapter.gd")
const CameraSessionScript = preload("res://scripts/integrations/camera_session.gd")
const HandTrackingStatusScript = preload("res://framework/integrations/hand_tracking_status.gd")
const GameAudioControllerScript = preload("res://scripts/integrations/game_audio_controller.gd")
const SocialFeedContentScript = preload("res://scripts/game/social_feed_content.gd")
const SocialFeedCatalogScript = preload("res://scripts/game/social_feed_catalog.gd")
const LanguageMaterialScript = preload("res://scripts/game/language_material.gd")
const NarrativeOverlayDirectorScript = preload("res://scripts/game/narrative_overlay_director.gd")
const GameUiThemeScript = preload("res://scripts/ui/game_ui_theme.gd")
const PropertyBootScript = preload("res://scripts/game/property_boot.gd")
const PropertyKeysScript = preload("res://scripts/property_keys.gd")
const ServiceKeysScript = preload("res://scripts/service_keys.gd")
const ServiceRegistryScript = preload("res://framework/service_registry.gd")
const FlowManagerScript = preload("res://framework/flow/flow_manager.gd")
const MainMenuFlowStateScript = preload("res://scripts/game/flow/main_menu_flow_state.gd")
const PrologueFlowStateScript = preload("res://scripts/game/flow/prologue_flow_state.gd")
const GameplayFlowStateScript = preload("res://scripts/game/flow/gameplay_flow_state.gd")
const NarrativeFlowStateScript = preload("res://scripts/game/flow/narrative_flow_state.gd")
const EndingFlowStateScript = preload("res://scripts/game/flow/ending_flow_state.gd")

const PHONE_DOWN_BACKDROP_PATH := "res://assets/generated/world/phone_down_backdrop.png"
const PLAYER_CHARACTER_PATH := "res://assets/generated/characters/protagonist_operator.png"
const GUIDE_DOLL_CHARACTER_PATH := "res://assets/generated/characters/guide_doll.png"
const NPC_CHARACTER_PATHS := [
	"res://assets/generated/characters/npc_late_arrival.png",
	"res://assets/generated/characters/npc_echo_tenant.png",
	"res://assets/generated/characters/npc_archive_witness.png",
]
const NO_SIGNAL_ICON_PATH := "res://assets/generated/ui/no_signal_icon.png"
const HUD_POLLUTION_ICON_PATH := "res://assets/generated/ui/hud_pollution_icon.png"
const HUD_MONEY_ICON_PATH := "res://assets/generated/ui/hud_money_icon.png"
const HUD_SETTINGS_ICON_PATH := "res://assets/generated/ui/hud_settings_icon.png"
const PHONE_LAUNCHER_WALLPAPER_PATH := "res://assets/generated/1/IMG_4835.PNG"
const SOCIAL_POSTER_SHEET_PATH := "res://assets/generated/social/poster_sheet.png"
const REALITY_MOUSE_SENSITIVITY := 0.064
const REALITY_TOUCH_SENSITIVITY := 0.082
const REALITY_TRACKPAD_SENSITIVITY := 1.8
# 句子单位软上限(参考 Bluesky 的 grapheme 计数语义;超过只提示不拦截)。
const COMPOSER_SOFT_UNIT_LIMIT := 12
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

var _social_channels: Array = SocialFeedCatalogScript.get_channels()
var _social_post_cards: Array = SocialFeedCatalogScript.get_post_cards()

var game: MemeGameState = MemeGameStateScript.new()
var _locale = GameLocaleScript.new()
var selected_meme_id := ""
var log_text := ""
var _phone_sway_time := 0.0

var _camera: Camera3D
var _reality_scene_adapter
var _reality_mouse_look_enabled := false
var _reality_touch_look_index := -1
var _canvas: CanvasLayer
var _ui_root: Control
var _texture_cache: Dictionary = {}
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
var _apple_hud_panel
var _edge_drawer: EdgeDrawer
var _world_prompt: Label
var _desk_log: Label
var _screen_manager: ScreenManager
var _ui_event_bus: GameEventBus
var _language_selection_panel: LanguageSelectionPanel
var _prologue_panel: ProloguePanel
var _camera_consent_panel: CameraConsentPanel
var _settings_window: PanelContainer
var _settings_history_panel: SettingsHistoryPanel
var _social_feed_panel
var _language_material
var _phone_launcher_panel
var _notebook_app_panel: NotebookAppPanel
var _babel_app_panel
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
var _reality_hover_choice_id := ""
var _reality_language_composer_panel
var _selected_language_token_id := ""
var _playtest_assist_panel
var _playtest_assist_enabled := OS.is_debug_build() or OS.get_environment("BABEL_PLAYTEST_ASSIST") == "1"
var _pickup_flight_layer: FlyToTargetLayer
var _notebook_squash_tween: Tween
var _doll_guide_panel
var _ending_screen_panel
var _phone_popup_expanded := true
var _phone_launcher_open := true
var _open_app_windows: Dictionary = {}
var _social_screen := "home"
var _social_channel := "discover"
var _social_detail_post_index := 0
var _social_detail_open := false
var _notebook_crafting_tab := "frame"
var _window_manager: DraggableWindowManager
var _last_responsive_layout_size := Vector2.ZERO
var _game_started := false
var _flow: FlowManager
var _play_screen_installed := false
var _ending_screen_installed := false
var _world_hotkeys_installed := false
var _vhs_enabled := true
var _master_volume := 80.0
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
		"game": game,
		"ui_root": _ui_root,
		"audio": _audio_controller,
		"request_narrative": func() -> void:
			_request_session_mode("narrative"),
		"complete_beat": _complete_narrative_beat,
		"ending_unlocked": _ending_is_unlocked,
		"settle_day": _settle_day_and_present_rewards,
		"hud_actions_label": _hud_actions_label_ref,
		"action_text": _action_text,
		"theme_color": _ui_theme_helper.theme_color,
		"ui_font_size": _ui_theme_helper.ui_font_size,
		"label_factory": _ui_theme_helper.label,
		"level_display_name": _locale.level_display_name,
		"day_progress": _day_progress_snapshot,
		"capture_frozen_frame": _capture_frozen_frame_texture,
	}


func _camera_session_deps() -> Dictionary:
	return {
		"game_started": _game_started,
		"persist_preferences": func() -> void:
			_locale.save_preferences(_master_volume, _vhs_enabled, _camera_session.enabled, _camera_session.source),
		"on_phone_source_enabled": _show_phone_camera_connection_overlay,
		"on_camera_disabled": _hide_phone_camera_connection_overlay,
		"hide_phone_connection_overlay": _hide_phone_camera_connection_overlay,
		"refresh_phone_connection_ui": _refresh_phone_camera_connection_ui,
		"set_localized_property": _ui_theme_helper.set_localized_property,
		"locale_translate": func(text: String) -> String: return _locale.translate(text),
		"ui_root": _ui_root,
		"phone_down_backdrop_image": _phone_down_backdrop_image,
	}


func _audio_controller_deps() -> Dictionary:
	return {
		"game": game,
		"game_started": _game_started,
		"day_progress": _day_progress_snapshot(),
		"phone_shell": _phone_shell_snapshot(),
		"reality_interaction_active": _reality_interaction_is_active(),
		"reality_conversation": _reality_conversation_snapshot(),
		"pollution_stage": _pollution_stage_snapshot(),
	}


func _social_content_deps() -> Dictionary:
	return {
		"post_cards": _social_post_cards,
		"social_channel": _social_channel,
		"game": game,
		"day_progress": _day_progress_snapshot(),
		"current_locale": _locale.current_locale,
		"translate": func(text: String) -> String: return _locale.translate(text),
		"is_following": func(author_id: String) -> bool: return _is_social_following(author_id),
		"is_post_liked": func(post_id: String) -> bool: return _is_social_post_liked(post_id),
		"level_display_name": func(floor_number: int) -> String: return _locale.level_display_name(floor_number),
		"poster_sheet_path": SOCIAL_POSTER_SHEET_PATH,
		"texture_cache": _texture_cache,
		"load_texture": _load_runtime_texture,
		"placed_meme": _placed_meme(),
		"pickable_units": func(text: String) -> Array[String]: return _locale.pickable_units(text),
	}


func _on_camera_tracking_ui_changed() -> void:
	if _camera_session == null:
		return
	_camera_session.refresh_source_buttons()
	_camera_session.refresh_status_ui(_camera_session_deps())
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
	_ui_theme_helper.configure({
		"ui_font_path": UI_FONT_PATH,
		"ui_font_grid": UI_FONT_GRID,
		"ui_font_min_size": UI_FONT_MIN_SIZE,
		"ui_font_max_size": UI_FONT_MAX_SIZE,
		"locale_translate": func(text: String) -> String: return _locale.translate(text),
		"pollution_stage": _pollution_stage_snapshot,
	})
	var preferences := _locale.load_preferences(_master_volume, _vhs_enabled)
	_master_volume = float(preferences.get("master_volume", _master_volume))
	_vhs_enabled = bool(preferences.get("vhs_enabled", _vhs_enabled))
	_ensure_camera_session()
	_camera_session.enabled = bool(preferences.get("camera_enabled", false))
	_camera_session.source = str(preferences.get("camera_source", "computer"))
	_camera_session_decided = false
	_camera_session.ensure_receiver()
	_ensure_window_manager()
	_ensure_edge_drawer()
	_apply_master_volume()
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
		_apply_responsive_layouts_if_needed()
		if _edge_drawer != null:
			_edge_drawer.tick(delta)
	_animate_world(delta)


func _exit_tree() -> void:
	if _camera_session != null:
		_camera_session.stop_receiver()


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
	_begin_game_session(fresh_state, {}, true)


func continue_game() -> bool:
	var payload := _load_save_payload()
	if payload.is_empty():
		return false
	var restored_state: MemeGameState = MemeGameStateScript.new()
	var saved_state: Variant = payload.get("game", {})
	if not saved_state is Dictionary or not restored_state.load_save_data(saved_state):
		return false
	_begin_game_session(restored_state, payload.get("world", {}), false)
	return true


func _begin_game_session(session_state: MemeGameState, world_data: Dictionary, show_prologue: bool) -> void:
	_game_started = true
	_phone_art_alpha = 1.0
	if _camera_session != null:
		_camera_session.second_layer_texture = null
	game = session_state
	_migrate_social_author_ids()
	_connect_game_state_signals()
	selected_meme_id = ""
	_phone_popup_expanded = true
	_phone_launcher_open = str(_phone_shell_snapshot().get("active_app_window", "")).is_empty()
	_open_app_windows = {}
	var shell_snapshot: Dictionary = _phone_shell_snapshot()
	var restored_app_window := str(shell_snapshot.get("active_app_window", ""))
	if not restored_app_window.is_empty():
		_open_app_windows[restored_app_window] = true
	_social_screen = "home"
	_social_channel = "discover"
	_social_detail_post_index = 0
	_social_detail_open = false
	if _social_feed_panel != null:
		_social_feed_panel.set_detail_post_index(0)
		_social_feed_panel.close_detail()
	_notebook_crafting_tab = "frame"
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
	log_text = "你低头，手机边框从视野下方亮起来。" if show_prologue else "你回到离开时的位置。"
	_session_world_data = world_data
	# Leave the title mounted until main-menu exit. Prologue and ending enter mount the in-run scene.
	if show_prologue:
		_request_session_mode("prologue")
	elif not _request_ending_if_unlocked():
		if session_mode() != "gameplay":
			_request_session_mode("gameplay")
		_mount_in_run_scene()
	if not show_prologue:
		_skip_prologue()
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
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_session.enabled, _camera_session.source)
	_game_started = false
	if _settings_history_panel != null and is_instance_valid(_settings_history_panel):
		_settings_history_panel.close_settings()
	_phone_art_alpha = 0.0
	_phone_launcher_open = false
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
		"social_screen": _social_screen,
		"social_channel": _social_channel,
		"social_detail_post_index": _social_detail_post_index,
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
	if not FileAccess.file_exists(_save_path):
		return {}
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return {}
	var payload: Variant = file.get_var()
	if not payload is Dictionary or int(payload.get("version", -1)) != SAVE_FILE_VERSION:
		return {}
	if not payload.get("game", {}) is Dictionary or not payload.get("world", {}) is Dictionary:
		return {}
	return payload


func _has_save_progress() -> bool:
	return not _load_save_payload().is_empty()


func _publish_has_save() -> void:
	PropertyBootScript.install()
	var manager := ServiceRegistryScript.resolve(ServiceKeysScript.PROPERTY_MANAGER) as PropertyManager
	if manager == null:
		return
	var has_save := manager.model(PropertyKeysScript.HAS_SAVE) as ValuePropertyModel
	if has_save == null:
		return
	has_save.write(_has_save_progress())


func _restore_saved_world(world_data: Dictionary) -> void:
	if world_data.is_empty():
		return
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.restore_world_pose(world_data)
	_social_screen = str(world_data.get("social_screen", "home"))
	if _social_screen not in ["home", "detail", "publish", "profile"]:
		_social_screen = "home"
	_social_channel = _normalize_social_channel(str(world_data.get("social_channel", "discover")))
	_social_detail_post_index = clampi(int(world_data.get("social_detail_post_index", 0)), 0, maxi(0, _social_post_cards.size() - 1))
	if _social_feed_panel != null:
		_social_feed_panel.set_detail_post_index(_social_detail_post_index)


func _normalize_social_channel(channel: String) -> String:
	var legacy_channels := {
		"关注": "following",
		"发现": "discover",
		"塔下": "tower_base",
		"附近": "nearby",
	}
	var normalized := str(legacy_channels.get(channel, channel))
	for channel_data in _social_channels:
		if str(channel_data.get("id", "")) == normalized:
			return normalized
	return "discover"


func _migrate_social_author_ids() -> void:
	var migrated: Array[String] = []
	for stored_author in game.social_followed_handles:
		var stable_id := str(stored_author)
		for post in _social_post_cards:
			if str(post.get("handle", "")) == stable_id:
				stable_id = str(post.get("id", stable_id))
				break
		if stable_id not in migrated:
			migrated.append(stable_id)
	game.replace_social_followed_handles(migrated)


func _connect_game_state_signals() -> void:
	if game == null:
		return
	if not game.social_engagement_changed.is_connected(_on_social_engagement_changed):
		game.social_engagement_changed.connect(_on_social_engagement_changed)
	if not game.phone_shell_changed.is_connected(_on_phone_shell_changed):
		game.phone_shell_changed.connect(_on_phone_shell_changed)
	if not game.action_economy_changed.is_connected(_on_action_economy_changed):
		game.action_economy_changed.connect(_on_action_economy_changed)
	if not game.settings_changed.is_connected(_on_settings_changed):
		game.settings_changed.connect(_on_settings_changed)
	if not game.reality_conversation_changed.is_connected(_on_reality_conversation_changed):
		game.reality_conversation_changed.connect(_on_reality_conversation_changed)
	if not game.day_progress_changed.is_connected(_on_day_progress_changed):
		game.day_progress_changed.connect(_on_day_progress_changed)
	if not game.inventory_changed.is_connected(_on_inventory_changed):
		game.inventory_changed.connect(_on_inventory_changed)
	if not game.progression_changed.is_connected(_on_progression_changed):
		game.progression_changed.connect(_on_progression_changed)


func _on_social_engagement_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_phone_shell()


func _on_phone_shell_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_phone_shell()
	_update_world_for_phone_view()


func _on_action_economy_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_phone_shell()


func _on_settings_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_settings_menu_labels()


func _on_reality_conversation_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_reality_hud()


func _on_day_progress_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_play_surfaces()


func _on_inventory_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	_refresh_phone_shell()
	_refresh_reality_hud()


func _on_progression_changed(_snapshot: Dictionary) -> void:
	if not _session_is_in_run():
		return
	if _request_ending_if_unlocked():
		_refresh_ending()
		return
	_render_status()
	_refresh_phone_shell()


func _phone_shell_snapshot() -> Dictionary:
	if game == null:
		return {
			"view_state": "phone_down",
			"active_app": "",
			"active_app_window": "",
			"phone_visible": true,
			"phone_open": true,
		}
	return game.get_phone_shell_snapshot()


func _settings_snapshot() -> Dictionary:
	if game == null:
		return {
			"autoplay_enabled": false,
			"exit_prompt_seen": false,
		}
	return game.get_settings_snapshot()


func _day_progress_snapshot() -> Dictionary:
	if game == null:
		return {
			"day": 1,
			"pollution": 0,
			"tower_floor": 1,
			"needs_day_settlement": false,
			"day_ended_reason": "",
			"pending_floor_transition": 0,
		}
	return game.get_day_progress_snapshot()


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
		"day_progress": _day_progress_snapshot(),
	}


func _social_engagement_snapshot() -> Dictionary:
	if game == null:
		return {"followed_handles": [], "liked_post_ids": []}
	return game.get_social_engagement_snapshot()


func _inventory_snapshot() -> Dictionary:
	if game == null:
		return {
			"completed_memes": [],
			"notebook_token_count": 0,
			"draft_slots": {},
			"craft_slot_fills": {},
		}
	return game.get_inventory_snapshot()


func _progression_snapshot() -> Dictionary:
	if game == null:
		return {
			"ending_unlocked": false,
			"ending_route": "",
			"ending_language_choice": "",
			"formal_floor_three_complete": false,
			"floor3_task_complete": false,
			"floor4_task_complete": false,
		}
	return game.get_progression_snapshot()


func _is_social_following(author_id: String) -> bool:
	return author_id in (_social_engagement_snapshot().get("followed_handles", []) as Array)


func _is_social_post_liked(post_id: String) -> bool:
	return post_id in (_social_engagement_snapshot().get("liked_post_ids", []) as Array)


func set_view_state(value: String) -> void:
	if value == "npc_up" and str(_phone_shell_snapshot().get("view_state", "")) == "phone_down":
		_capture_phone_layer_for_xray()
	if game.set_view_state(value):
		if _reality_scene_adapter != null:
			_reality_scene_adapter.apply_interaction({"action": "end"})
			_reality_scene_adapter.clear_nearby_targets()
		_reality_hover_choice_id = ""
		game.reset_typed_reality_conversation()
		if value == "npc_up":
			_set_reality_mouse_look(true)
			log_text = "你放下手机，大街重新获得纵深。"
			_phone_launcher_open = false
		else:
			_set_reality_mouse_look(false)
			log_text = "你又低头看向手机。"
			var phone_shell: Dictionary = _phone_shell_snapshot()
			_phone_launcher_open = str(phone_shell.get("active_app_window", "")).is_empty()
			var foreground_app := str(phone_shell.get("active_app_window", ""))
			if not foreground_app.is_empty():
				_open_app_windows[foreground_app] = true
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
	if not _reality_scene_adapter.cover_watcher_appeared.is_connected(_on_cover_watcher_appeared):
		_reality_scene_adapter.cover_watcher_appeared.connect(_on_cover_watcher_appeared)
	if not _reality_scene_adapter.cover_watcher_vanished.is_connected(_on_cover_watcher_vanished):
		_reality_scene_adapter.cover_watcher_vanished.connect(_on_cover_watcher_vanished)


func _reality_scene_deps() -> Dictionary:
	var progress := _day_progress_snapshot()
	var tower_floor := clampi(int(progress.get("tower_floor", 1)), 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	var locale_code: String = "zh"
	if _locale != null:
		locale_code = str(_locale.current_locale)
	var progression := _progression_snapshot()
	return {
		"day_progress": progress,
		"palette": _ui_theme_helper.active_palette(),
		"load_texture": _load_runtime_texture,
		"npc_character_paths": NPC_CHARACTER_PATHS,
		"guide_doll_path": GUIDE_DOLL_CHARACTER_PATH,
		"playtest_assist_enabled": _playtest_assist_enabled,
		"view_state": str(_phone_shell_snapshot().get("view_state", "")) if game != null else "",
		"locale": locale_code,
		"locale_translate": func(text: String) -> String: return _locale.translate(text),
		"cover_watcher_seen": game.has_seen_cover_watcher(tower_floor) if game != null else false,
		"collected_world_item_ids": game.collected_world_item_ids.duplicate() if game != null else [],
		"revealed_prerequisite_item_ids": game.revealed_prerequisite_item_ids.duplicate() if game != null else [],
		"collected_prerequisite_item_ids": game.collected_prerequisite_item_ids.duplicate() if game != null else [],
		"claimed_doll_ids": game.claimed_doll_ids.duplicate() if game != null else [],
		"floor3_task_complete": bool(progression.get("floor3_task_complete", false)),
		"floor4_task_complete": bool(progression.get("floor4_task_complete", false)),
	}


func _on_reality_nearby_targets_changed() -> void:
	_refresh_reality_hud()


func _apply_reality_look_delta(relative_motion: Vector2, sensitivity: float) -> void:
	_ensure_reality_scene_adapter()
	_reality_scene_adapter.apply_look_delta(relative_motion, sensitivity)


func _build_world(build_playable_floor: bool = true) -> void:
	if _narrative_director != null:
		_narrative_director.kill_day_transition_tween()
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
	for child in get_children():
		if child == _reality_scene_adapter or child == _narrative_director or child == _screen_manager:
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
	_apply_ui_theme()
	_ui_theme_helper.refresh_localized_ui(_ui_root)
	_ensure_settings_history_panel()
	_settings_history_panel.build_exit_confirmation_overlay(_ui_root, _settings_history_mount_deps())
	_update_visibility()


func uninstall_title_screen() -> void:
	if _screen_manager != null and is_instance_valid(_screen_manager):
		_screen_manager.close()


func install_prologue_screen() -> void:
	_mount_in_run_scene()
	_build_prologue_overlay()
	install_play_screen()


func uninstall_prologue_screen() -> void:
	if _prologue_panel != null and is_instance_valid(_prologue_panel):
		_prologue_panel.unmount()
	uninstall_play_screen()


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
	if actor_type == "doll":
		game.notify_tutorial("guide_found", {"actor_id": actor_id})
	_localize_active_conversation()
	_reality_hover_choice_id = ""
	_set_reality_mouse_look(false)
	log_text = "你停在%s面前。" % _active_actor_display_name()
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
		log_text = game.event_log[0]
	_refresh_reality_hud()
	return true


func _exit_reality_interaction(should_render: bool = true) -> void:
	if _reality_scene_adapter != null:
		_reality_scene_adapter.apply_interaction({"action": "end"})
	_reality_hover_choice_id = ""
	_selected_language_token_id = ""
	game.reset_typed_reality_conversation()
	if str(_phone_shell_snapshot().get("view_state", "")) == "npc_up":
		_set_reality_mouse_look(true)
	if should_render:
		_update_world_for_phone_view()
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


func _on_cover_watcher_appeared(floor_number: int) -> void:
	if game != null:
		game.mark_cover_watcher_seen(floor_number)
	if _audio_controller != null:
		_audio_controller.on_cover_watcher_appeared(floor_number)


func _on_cover_watcher_vanished(_floor_number: int) -> void:
	# The stinger is intentionally allowed to finish after the figure has withdrawn.
	if game != null:
		game.event_log.push_front("掩体后的人影缩了回去。它没有留下脸。")


func _sync_audio_state(immediate: bool = false) -> void:
	if _audio_controller != null:
		_audio_controller.sync_state(_audio_controller_deps(), immediate)


func _pollution_stage_snapshot() -> Dictionary:
	var progress := _day_progress_snapshot()
	return PollutionStageScript.stage(int(progress.get("pollution", 0)), int(progress.get("day", 1)))


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
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_session.enabled, _camera_session.source)
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
		_camera_session.refresh_status_ui(_camera_session_deps())


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
	_ui_theme_helper.apply_ui_font_theme(_ui_root)
	_canvas.add_child(_ui_root)

	var vignette := ColorRect.new()
	vignette.color = _ui_theme_helper.theme_color("ink").darkened(0.15)
	vignette.modulate.a = 0.16
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_world_prompt.add_theme_color_override("font_outline_color", Color("050705"))
	_world_prompt.add_theme_constant_override("outline_size", 6)
	_world_prompt.z_index = 10
	_ui_root.add_child(_world_prompt)

	_phone_tab = null

	_ensure_social_feed_panel()
	_social_feed_panel.mount(_ui_root, _social_feed_mount_deps())
	_ensure_phone_launcher_panel()
	_phone_launcher_panel.mount(_ui_root, _phone_launcher_mount_deps())
	_app_windows["social"] = _social_feed_panel.get_app_window()
	_app_titles["social"] = _social_feed_panel.get_app_title() as Label
	_app_bodies["social"] = _social_feed_panel.get_app_body() as VBoxContainer
	for app_id in ["babel", "notebook"]:
		_app_windows[app_id] = _phone_launcher_panel.get_app_window(app_id)
		_app_titles[app_id] = _phone_launcher_panel.get_app_title(app_id)
		_app_bodies[app_id] = _phone_launcher_panel.get_app_body(app_id)
	_ensure_notebook_app_panel()
	_ensure_babel_app_panel()

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
	_ensure_reality_language_composer_panel()
	_reality_language_composer_panel.mount(_ui_root, _reality_language_composer_mount_deps())

	_desk_log = _ui_theme_helper.label("", 16, _ui_theme_helper.theme_color("accent"))
	_desk_log.name = "DeskLog"
	_desk_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_desk_log.offset_left = 282
	_desk_log.offset_top = -146
	_desk_log.offset_right = 820
	_desk_log.offset_bottom = -112
	_desk_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_root.add_child(_desk_log)
	_build_playtest_assist_panel()

	_bind_narrative_director()
	_narrative_director.build_action_spend_overlay()
	_build_settings_window()
	_build_phone_camera_connection_overlay()
	_build_history_window()
	_narrative_director.build_day_transition_overlay()
	_build_pickup_flight_layer()
	_build_doll_guide_overlay()
	_narrative_director.build_flashback_overlay()
	_apply_responsive_layouts_if_needed(true)


func _build_playtest_assist_panel() -> void:
	_ensure_playtest_assist_panel()
	_playtest_assist_panel.mount(_ui_root, _playtest_assist_mount_deps())


func _ensure_playtest_assist_panel() -> void:
	if _playtest_assist_panel != null and is_instance_valid(_playtest_assist_panel):
		return
	_playtest_assist_panel = PlaytestAssistPanelScript.new()
	_playtest_assist_panel.name = "PlaytestAssistPanelHost"
	add_child(_playtest_assist_panel)


func _playtest_assist_mount_deps() -> Dictionary:
	return {
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
	}


func _build_prologue_overlay() -> void:
	_ensure_prologue_panel()
	_prologue_panel.mount(_ui_root, _prologue_mount_deps())


func _advance_prologue() -> void:
	if _prologue_panel == null or not is_instance_valid(_prologue_panel):
		return
	_prologue_panel.advance()


func _skip_prologue() -> void:
	if _prologue_panel == null or not is_instance_valid(_prologue_panel):
		return
	_prologue_panel.skip()


func _build_apple_hud() -> void:
	_ensure_apple_hud_panel()
	_apple_hud_panel.mount(_ui_root, _apple_hud_mount_deps())
	if not _apple_hud_panel.settings_pressed.is_connected(_toggle_settings_window):
		_apple_hud_panel.settings_pressed.connect(_toggle_settings_window)
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
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"style_factory": _ui_theme_helper.style,
		"load_texture": _load_runtime_texture,
		"rail_width": HUD_RAIL_WIDTH,
		"rail_max_height": HUD_RAIL_MAX_HEIGHT,
		"drawer_edge_hit_width": HUD_DRAWER_EDGE_HIT_WIDTH,
		"drawer_edge_cue_width": HUD_DRAWER_EDGE_CUE_WIDTH,
		"drawer_open_duration": HUD_DRAWER_OPEN_DURATION,
		"drawer_close_duration": HUD_DRAWER_CLOSE_DURATION,
		"pollution_icon_path": HUD_POLLUTION_ICON_PATH,
		"money_icon_path": HUD_MONEY_ICON_PATH,
		"settings_icon_path": HUD_SETTINGS_ICON_PATH,
		"on_tooltip_hidden": _on_apple_hud_tooltip_hidden,
	}


func _on_apple_hud_tooltip_hidden() -> void:
	if _edge_drawer != null:
		_edge_drawer.schedule_close()


func _apple_hud_snapshot() -> Dictionary:
	var progress := _day_progress_snapshot()
	return {
		"pollution": int(progress.get("pollution", 0)),
		"money": game.money,
		"actions": _action_text(game.actions_remaining),
		"tooltips": {
			"pollution": "污染 %d%%" % int(progress.get("pollution", 0)),
			"money": "资金 %d" % game.money,
			"settings": "设置",
		},
	}


func _render_apple_hud() -> void:
	if _apple_hud_panel == null or not is_instance_valid(_apple_hud_panel):
		_apple_hud_panel = null
		return
	_apple_hud_panel.render(_apple_hud_snapshot())


func _hud_rail() -> PanelContainer:
	if _apple_hud_panel == null:
		return null
	return _apple_hud_panel.get_rail()


func _hud_actions_label_ref() -> Label:
	if _apple_hud_panel == null:
		return null
	return _apple_hud_panel.get_actions_label()


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
	_cinematic_bars.bar_color = Color("050705")
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
	_settings_history_panel.refresh_menu_labels(int(_day_progress_snapshot().get("pollution", 0)), bool(_settings_snapshot().get("autoplay_enabled", false)))
	_settings_history_panel.build_exit_confirmation_overlay(_ui_root)
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
	_ui_event_bus = GameEventBusScript.new()
	_ui_event_bus.intent_emitted.connect(_on_ui_intent)
	_screen_manager = ScreenManagerScript.new(_ui_event_bus, MainMenuScreenScript, self)
	_screen_manager.name = "ScreenManager"
	add_child(_screen_manager)


func _on_ui_intent(intent_name: String) -> void:
	match intent_name:
		"start_game":
			new_game.call_deferred()
		"continue_game":
			continue_game.call_deferred()
		"exit_game":
			_request_quit_game()
		"language_picker":
			_build_language_selection_overlay(false)


func _ensure_language_selection_panel() -> void:
	if _language_selection_panel != null and is_instance_valid(_language_selection_panel):
		return
	_language_selection_panel = LanguageSelectionPanelScript.new()
	_language_selection_panel.name = "LanguageSelectionPanel"
	add_child(_language_selection_panel)
	_connect_language_selection_panel_signals()


func _language_selection_mount_deps() -> Dictionary:
	var locales: Array = []
	for locale_code in GameLocaleScript.SUPPORTED_LOCALES:
		locales.append({
			"code": str(locale_code),
			"name": _locale.native_language_name(str(locale_code)),
		})
	return {
		"soft_style": _ui_theme_helper.soft_style,
		"theme_color": _ui_theme_helper.theme_color,
		"ui_font_size": _ui_theme_helper.ui_font_size,
		"locales": locales,
		"language_selected": func() -> bool: return _locale.language_selected,
		"refresh_localized_ui": func() -> void:
			_ui_theme_helper.refresh_localized_ui(_ui_root),
	}


func _connect_language_selection_panel_signals() -> void:
	var panel := _language_selection_panel
	if panel == null:
		return
	if not panel.language_selected.is_connected(_on_language_selected):
		panel.language_selected.connect(_on_language_selected)


func _ensure_prologue_panel() -> void:
	if _prologue_panel != null and is_instance_valid(_prologue_panel):
		return
	_prologue_panel = ProloguePanelScript.new()
	_prologue_panel.name = "ProloguePanel"
	add_child(_prologue_panel)
	_connect_prologue_panel_signals()


func _prologue_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"set_localized_property": _ui_theme_helper.set_localized_property,
		"prologue_lines": NarrativeSessionCatalogScript.prologue_lines(_locale.current_locale),
	}


func _connect_prologue_panel_signals() -> void:
	var panel := _prologue_panel
	if panel == null:
		return
	if not panel.prologue_finished.is_connected(_on_prologue_finished):
		panel.prologue_finished.connect(_on_prologue_finished)


func _ensure_camera_consent_panel() -> void:
	if _camera_consent_panel != null and is_instance_valid(_camera_consent_panel):
		return
	_camera_consent_panel = CameraConsentPanelScript.new()
	_camera_consent_panel.name = "CameraConsentPanel"
	add_child(_camera_consent_panel)
	_connect_camera_consent_panel_signals()


func _camera_consent_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"soft_style": _ui_theme_helper.soft_style,
		"populate_camera_source_option": _populate_camera_source_option,
		"camera_enabled": _camera_session.enabled if _camera_session != null else false,
		"apply_ui_theme": _apply_ui_theme,
		"refresh_localized_ui": func() -> void:
			_ui_theme_helper.refresh_localized_ui(_ui_root),
	}


func _connect_camera_consent_panel_signals() -> void:
	var panel := _camera_consent_panel
	if panel == null:
		return
	if not panel.consent_resolved.is_connected(_resolve_camera_consent):
		panel.consent_resolved.connect(_resolve_camera_consent)
	if not panel.source_selected.is_connected(_on_camera_consent_source_selected):
		panel.source_selected.connect(_on_camera_consent_source_selected)


func _ensure_phone_camera_connection_panel() -> void:
	if _phone_camera_connection_panel != null and is_instance_valid(_phone_camera_connection_panel):
		return
	_phone_camera_connection_panel = PhoneCameraConnectionPanelScript.new()
	_phone_camera_connection_panel.name = "PhoneCameraConnectionPanelHost"
	add_child(_phone_camera_connection_panel)
	_connect_phone_camera_connection_panel_signals()


func _phone_camera_connection_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"soft_style": _ui_theme_helper.soft_style,
		"panel_factory": _ui_theme_helper.panel,
		"set_localized_property": _ui_theme_helper.set_localized_property,
	}


func _connect_phone_camera_connection_panel_signals() -> void:
	var panel := _phone_camera_connection_panel
	if panel == null:
		return
	if not panel.retry_requested.is_connected(_retry_phone_camera_connection):
		panel.retry_requested.connect(_retry_phone_camera_connection)
	if not panel.continue_requested.is_connected(_hide_phone_camera_connection_overlay):
		panel.continue_requested.connect(_hide_phone_camera_connection_overlay)
	if not panel.disable_requested.is_connected(_disable_phone_camera_from_connection):
		panel.disable_requested.connect(_disable_phone_camera_from_connection)


func _on_camera_consent_source_selected(index: int) -> void:
	if _camera_consent_source_option == null:
		return
	_on_camera_source_selected(index, _camera_consent_source_option)


func _on_prologue_finished() -> void:
	if _request_ending_if_unlocked():
		_set_reality_mouse_look(false)
		_refresh_ending()
	else:
		_set_reality_mouse_look(str(_phone_shell_snapshot().get("view_state", "")) == "npc_up")
		_request_session_mode("gameplay")
	_sync_audio_state(false)


func _ensure_settings_history_panel() -> void:
	if _settings_history_panel != null and is_instance_valid(_settings_history_panel):
		return
	_settings_history_panel = SettingsHistoryPanelScript.new()
	_settings_history_panel.name = "SettingsHistoryPanel"
	add_child(_settings_history_panel)
	_connect_settings_history_panel_signals()


func _settings_history_mount_deps() -> Dictionary:
	_ensure_window_manager()
	var locales: Array = []
	for locale_code in GameLocaleScript.SUPPORTED_LOCALES:
		locales.append({
			"code": str(locale_code),
			"name": _locale.native_language_name(str(locale_code)),
		})
	return {
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"soft_style": _ui_theme_helper.soft_style,
		"theme_color": _ui_theme_helper.theme_color,
		"ui_font_size": _ui_theme_helper.ui_font_size,
		"register_draggable": _window_manager.register,
		"master_volume": _master_volume,
		"vhs_enabled": _vhs_enabled,
		"autoplay_enabled": bool(_settings_snapshot().get("autoplay_enabled", false)),
		"locales": locales,
		"current_locale": _locale.current_locale if _locale != null else "",
	}


func _connect_settings_history_panel_signals() -> void:
	var panel := _settings_history_panel
	if panel == null:
		return
	if not panel.volume_changed.is_connected(_on_volume_changed):
		panel.volume_changed.connect(_on_volume_changed)
	if not panel.vhs_toggled.is_connected(_on_vhs_toggled):
		panel.vhs_toggled.connect(_on_vhs_toggled)
	if not panel.autoplay_toggled.is_connected(_on_autoplay_toggled):
		panel.autoplay_toggled.connect(_on_autoplay_toggled)
	if not panel.language_selected.is_connected(_on_settings_language_selected):
		panel.language_selected.connect(_on_settings_language_selected)
	if not panel.manual_save_pressed.is_connected(_on_manual_save_pressed):
		panel.manual_save_pressed.connect(_on_manual_save_pressed)
	if not panel.return_main_menu_pressed.is_connected(_on_return_main_menu_pressed):
		panel.return_main_menu_pressed.connect(_on_return_main_menu_pressed)
	if not panel.exit_game_requested.is_connected(_request_quit_game):
		panel.exit_game_requested.connect(_request_quit_game)
	if not panel.exit_confirmed.is_connected(_confirm_quit_game):
		panel.exit_confirmed.connect(_confirm_quit_game)
	if not panel.history_toggle_requested.is_connected(_toggle_history_window):
		panel.history_toggle_requested.connect(_toggle_history_window)
	if not panel.settings_open_changed.is_connected(_on_settings_open_changed):
		panel.settings_open_changed.connect(_on_settings_open_changed)


func _ensure_social_feed_panel() -> void:
	_ensure_language_material()
	if _social_feed_panel != null and is_instance_valid(_social_feed_panel):
		return
	_social_feed_panel = SocialFeedPanelScript.new()
	_social_feed_panel.name = "SocialFeedPanel"
	add_child(_social_feed_panel)
	_connect_social_feed_panel_signals()


func _ensure_language_material() -> void:
	if _language_material != null:
		return
	_language_material = LanguageMaterialScript.new()
	_language_material.configure({
		"game": func(): return game,
		"locale": func() -> String: return _locale.current_locale,
		"mouse_origin": func() -> Vector2: return get_viewport().get_mouse_position(),
	})
	_connect_language_material()


func _connect_language_material() -> void:
	if _language_material == null:
		return
	if not _language_material.sfx_requested.is_connected(_on_language_material_sfx):
		_language_material.sfx_requested.connect(_on_language_material_sfx)
	if not _language_material.effective_action.is_connected(_after_effective_action):
		_language_material.effective_action.connect(_after_effective_action)
	if not _language_material.ui_refresh_requested.is_connected(_on_language_ui_refresh_requested):
		_language_material.ui_refresh_requested.connect(_on_language_ui_refresh_requested)
	if not _language_material.log_requested.is_connected(_on_language_material_log):
		_language_material.log_requested.connect(_on_language_material_log)
	if not _language_material.notebook_home_requested.is_connected(_ensure_notebook_window_home):
		_language_material.notebook_home_requested.connect(_ensure_notebook_window_home)
	if not _language_material.pickup_flight_requested.is_connected(_on_language_pickup_flight):
		_language_material.pickup_flight_requested.connect(_on_language_pickup_flight)
	if not _language_material.place_flight_requested.is_connected(_on_language_place_flight):
		_language_material.place_flight_requested.connect(_on_language_place_flight)
	if not _language_material.status_refresh_requested.is_connected(_render_status):
		_language_material.status_refresh_requested.connect(_render_status)


func _on_language_ui_refresh_requested() -> void:
	_refresh_phone_shell()
	_render_status()


func _social_feed_mount_deps() -> Dictionary:
	_ensure_window_manager()
	_ensure_language_material()
	return {
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"style_fn": _ui_theme_helper.style,
		"soft_style": _ui_theme_helper.soft_style,
		"theme_color": _ui_theme_helper.theme_color,
		"ui_font_size": _ui_theme_helper.ui_font_size,
		"register_draggable": _window_manager.register,
		"load_texture": _load_runtime_texture,
		"poster_texture": func(post_index: int) -> Texture2D:
			return SocialFeedContentScript.poster_texture(post_index, _social_content_deps()),
		"channels": _social_channels,
		"no_signal_icon_path": NO_SIGNAL_ICON_PATH,
		"poster_sheet_path": SOCIAL_POSTER_SHEET_PATH,
		"poster_sheet_count": SocialFeedContentScript.SOCIAL_POSTER_COUNT,
		"visible_post_indices": func() -> Array[int]:
			return SocialFeedContentScript.visible_post_indices(_social_content_deps()),
		"post_for_index": func(post_index: int) -> Dictionary:
			return SocialFeedContentScript.post_for_index(post_index, _social_content_deps()),
		"is_following": func(author_id: String) -> bool: return _is_social_following(author_id),
		"like_text": func(post: Dictionary, post_index: int) -> String:
			return SocialFeedContentScript.like_text(post, post_index, _social_content_deps()),
		"caption_text": func(post: Dictionary, post_index: int) -> String:
			return SocialFeedContentScript.caption(post, post_index, _social_content_deps()),
		"corrupt_text": _corrupt,
		"floor_label": func() -> String:
			return SocialFeedContentScript.floor_label(_social_content_deps()),
		"translate": func(text: String) -> String: return _locale.translate(text),
		"language_material": _language_material,
		"author_id": SocialFeedContentScript.author_id,
		"player_echo_quote": func() -> String: return game.get_player_echo_quote(_locale.current_locale) if game != null else "",
		"echo_comment_handle": func() -> String: return EchoQuoteContentScript.anon_handle(_locale.current_locale),
		"game_day": func() -> int: return int(_day_progress_snapshot().get("day", 0)) if game != null else 0,
		"current_locale": func() -> String: return _locale.current_locale,
		"publish_result": func() -> Dictionary:
			return SocialFeedContentScript.publish_result(_social_content_deps()),
		"free_sentence_units": func() -> Array: return game.get_free_sentence_units() if game != null else [],
		"apply_composer_tile_theme": _ui_theme_helper.apply_composer_tile_theme,
		"free_sentence_text": func() -> String: return game.get_free_sentence_text(_locale.current_locale) if game != null else "",
		"can_spend_action": func() -> bool: return game != null and game.can_spend_action(),
		"completed_memes_count": func() -> int:
			return (_inventory_snapshot().get("completed_memes", []) as Array).size() if game != null else 0,
		"pollution": func() -> int: return int(_day_progress_snapshot().get("pollution", 0)) if game != null else 0,
		"player_character_path": PLAYER_CHARACTER_PATH,
		"composer_soft_unit_limit": COMPOSER_SOFT_UNIT_LIMIT,
	}


func _connect_social_feed_panel_signals() -> void:
	var panel = _social_feed_panel
	if panel == null:
		return
	if not panel.channel_pressed.is_connected(_on_social_channel_pressed):
		panel.channel_pressed.connect(_on_social_channel_pressed)
	if not panel.screen_requested.is_connected(_set_social_screen):
		panel.screen_requested.connect(_set_social_screen)
	if not panel.card_clicked.is_connected(_open_social_post):
		panel.card_clicked.connect(_open_social_post)
	if not panel.like_pressed.is_connected(_on_social_like_pressed):
		panel.like_pressed.connect(_on_social_like_pressed)
	if not panel.follow_pressed.is_connected(_on_social_follow_pressed):
		panel.follow_pressed.connect(_on_social_follow_pressed)
	if not panel.close_requested.is_connected(_close_app_window.bind("social")):
		panel.close_requested.connect(_close_app_window.bind("social"))
	if not panel.detail_close_requested.is_connected(_close_social_detail_window):
		panel.detail_close_requested.connect(_close_social_detail_window)
	if not panel.publish_confirm_requested.is_connected(_on_confirm_dialogue_pressed):
		panel.publish_confirm_requested.connect(_on_confirm_dialogue_pressed)
	if not panel.pickup_unit_clicked.is_connected(_language_material.pick_from_post):
		panel.pickup_unit_clicked.connect(_language_material.pick_from_post)
	if not panel.composer_area_dropped.is_connected(_language_material.drop_on_area):
		panel.composer_area_dropped.connect(_language_material.drop_on_area)
	if not panel.composer_tile_dropped.is_connected(_language_material.drop_before):
		panel.composer_tile_dropped.connect(_language_material.drop_before)
	if not panel.composer_answer_tapped.is_connected(_language_material.remove_at):
		panel.composer_answer_tapped.connect(_language_material.remove_at)
	if not panel.composer_submit_requested.is_connected(_language_material.submit):
		panel.composer_submit_requested.connect(_language_material.submit)


func _ensure_phone_launcher_panel() -> void:
	if _phone_launcher_panel != null and is_instance_valid(_phone_launcher_panel):
		return
	_phone_launcher_panel = PhoneLauncherPanelScript.new()
	_phone_launcher_panel.name = "PhoneLauncherPanel"
	add_child(_phone_launcher_panel)
	_connect_phone_launcher_panel_signals()


func _phone_launcher_mount_deps() -> Dictionary:
	_ensure_window_manager()
	return {
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
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
		"no_signal_icon_path": NO_SIGNAL_ICON_PATH,
	}


func _connect_phone_launcher_panel_signals() -> void:
	var panel = _phone_launcher_panel
	if panel == null:
		return
	if not panel.app_icon_pressed.is_connected(_on_app_pressed):
		panel.app_icon_pressed.connect(_on_app_pressed)
	if not panel.phone_close_requested.is_connected(set_view_state.bind("npc_up")):
		panel.phone_close_requested.connect(set_view_state.bind("npc_up"))
	if not panel.app_window_close_requested.is_connected(_close_app_window):
		panel.app_window_close_requested.connect(_close_app_window)


func _ensure_reality_conversation_panel() -> void:
	if _reality_conversation_panel != null and is_instance_valid(_reality_conversation_panel):
		return
	_reality_conversation_panel = RealityConversationPanelScript.new()
	_reality_conversation_panel.name = "RealityConversationPanel"
	add_child(_reality_conversation_panel)
	_connect_reality_conversation_panel_signals()


func _reality_conversation_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"ui_font_size": _ui_theme_helper.ui_font_size,
		"viewport_size": _viewport_size,
		"install_rich_text_effect": _install_rich_text_effect,
		"set_dialogue_text": _set_dialogue_text,
		"set_richer_bbcode": _set_richer_bbcode,
		"clear_children": _clear,
	}


func _connect_reality_conversation_panel_signals() -> void:
	if _reality_conversation_panel == null:
		return
	if not _reality_conversation_panel.choice_hovered.is_connected(_on_reality_choice_hovered):
		_reality_conversation_panel.choice_hovered.connect(_on_reality_choice_hovered)
	if not _reality_conversation_panel.choice_unhovered.is_connected(_on_reality_choice_unhovered):
		_reality_conversation_panel.choice_unhovered.connect(_on_reality_choice_unhovered)
	if not _reality_conversation_panel.choice_pressed.is_connected(_on_reality_choice_selected):
		_reality_conversation_panel.choice_pressed.connect(_on_reality_choice_selected)
	if not _reality_conversation_panel.continue_pressed.is_connected(_on_reality_continue_pressed):
		_reality_conversation_panel.continue_pressed.connect(_on_reality_continue_pressed)


func _ensure_reality_language_composer_panel() -> void:
	if _reality_language_composer_panel != null and is_instance_valid(_reality_language_composer_panel):
		return
	_reality_language_composer_panel = RealityLanguageComposerPanelScript.new()
	_reality_language_composer_panel.name = "RealityLanguageComposerPanel"
	add_child(_reality_language_composer_panel)
	_connect_reality_language_composer_panel_signals()


func _reality_language_composer_mount_deps() -> Dictionary:
	return {
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"clear_children": _clear,
	}


func _connect_reality_language_composer_panel_signals() -> void:
	if _reality_language_composer_panel == null:
		return
	if not _reality_language_composer_panel.token_pressed.is_connected(_on_language_token_pressed):
		_reality_language_composer_panel.token_pressed.connect(_on_language_token_pressed)
	if not _reality_language_composer_panel.token_dropped.is_connected(_on_language_token_dropped):
		_reality_language_composer_panel.token_dropped.connect(_on_language_token_dropped)
	if not _reality_language_composer_panel.slot_pressed.is_connected(_on_language_slot_pressed):
		_reality_language_composer_panel.slot_pressed.connect(_on_language_slot_pressed)
	if not _reality_language_composer_panel.confirm_pressed.is_connected(_on_confirm_doctor_sentence_pressed):
		_reality_language_composer_panel.confirm_pressed.connect(_on_confirm_doctor_sentence_pressed)


func _ensure_babel_app_panel() -> void:
	if _babel_app_panel != null and is_instance_valid(_babel_app_panel):
		return
	_babel_app_panel = BabelAppPanelScript.new()
	_babel_app_panel.name = "BabelAppPanel"
	add_child(_babel_app_panel)
	_babel_app_panel.configure(_babel_mount_deps())


func _babel_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"clear_children": _clear,
		"tower_floor": func() -> int: return int(_day_progress_snapshot().get("tower_floor", 1)) if game != null else 1,
		"money": func() -> int: return game.money if game != null else 0,
		"pollution": func() -> int: return int(_day_progress_snapshot().get("pollution", 0)) if game != null else 0,
		"event_log": func() -> Array:
			return game.event_log if game != null else [],
		"level_display_name": func(floor_number: int) -> String:
			return _locale.level_display_name(floor_number),
	}


func _ensure_notebook_app_panel() -> void:
	if _notebook_app_panel != null and is_instance_valid(_notebook_app_panel):
		return
	_notebook_app_panel = NotebookAppPanelScript.new()
	_notebook_app_panel.name = "NotebookAppPanel"
	add_child(_notebook_app_panel)
	_notebook_app_panel.configure(_notebook_mount_deps())
	_connect_notebook_app_panel_signals()


func _notebook_mount_deps() -> Dictionary:
	return {
		"panel_factory": _ui_theme_helper.panel,
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"clear_children": _clear,
		"composer_tile_style": _ui_theme_helper.composer_tile_style,
		"fusion_slot_text": _fusion_slot_text,
		"current_locale": func() -> String: return _locale.current_locale,
		"collected_char_units": func(locale_code: String) -> Array[String]:
			return game.get_collected_char_units(locale_code) if game != null else [],
		"free_sentence_units": func() -> Array:
			return game.get_free_sentence_units() if game != null else [],
		"world_rules": func() -> Array:
			return game.get_world_rules() if game != null else [],
		"char_canvas_position": func(unit: String, locale_code: String) -> Vector2:
			return game.get_char_canvas_position(unit, locale_code) if game != null else Vector2.ZERO,
		"can_spend_action": func() -> bool: return game != null and game.can_spend_action(),
		"fusion_ready": func() -> bool:
			return game != null and (_inventory_snapshot().get("fusion_slots", {}) as Dictionary).size() >= 2,
	}


func _connect_notebook_app_panel_signals() -> void:
	var panel = _notebook_app_panel
	if panel == null:
		return
	if not panel.craft_requested.is_connected(_on_composer_submit_pressed):
		panel.craft_requested.connect(_on_composer_submit_pressed)
	if not panel.fusion_requested.is_connected(_on_confirm_fusion_pressed):
		panel.fusion_requested.connect(_on_confirm_fusion_pressed)
	if not panel.tab_changed.is_connected(_set_notebook_crafting_tab):
		panel.tab_changed.connect(_set_notebook_crafting_tab)
	if not panel.canvas_tile_moved.is_connected(_on_canvas_tile_moved):
		panel.canvas_tile_moved.connect(_on_canvas_tile_moved)
	if not panel.canvas_tile_dropped_outside.is_connected(_on_canvas_tile_dropped_outside):
		panel.canvas_tile_dropped_outside.connect(_on_canvas_tile_dropped_outside)
	if not panel.composer_bank_tapped.is_connected(_on_composer_bank_tapped):
		panel.composer_bank_tapped.connect(_on_composer_bank_tapped)
	if not panel.fusion_meme_dropped.is_connected(_on_fusion_meme_dropped):
		panel.fusion_meme_dropped.connect(_on_fusion_meme_dropped)
	if not panel.fusion_slot_pressed.is_connected(_on_fusion_slot_pressed):
		panel.fusion_slot_pressed.connect(_on_fusion_slot_pressed)


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
	_render_history_window()


func _toggle_history_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.toggle(game.get_history_entries())


func _close_history_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.close()


func _render_history_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.refresh_history(game.get_history_entries())


func _refresh_settings_menu_labels() -> void:
	if _settings_history_panel != null and game != null:
		var progress := _day_progress_snapshot()
		_settings_history_panel.refresh_menu_labels(int(progress.get("pollution", 0)), bool(_settings_snapshot().get("autoplay_enabled", false)))


func _on_autoplay_toggled(value: bool) -> void:
	game.set_autoplay_enabled(value)


func _settings_is_open() -> bool:
	return _settings_history_panel != null and is_instance_valid(_settings_history_panel) and _settings_history_panel.is_settings_open()


func _toggle_settings_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.toggle_settings()


func _close_settings_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.close_settings()


func _on_settings_open_changed(_open: bool) -> void:
	if _apple_hud_panel != null:
		_apple_hud_panel.hide_tooltip()
	_update_visibility()


func _on_volume_changed(value: float) -> void:
	_master_volume = value
	_apply_master_volume()


func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, _master_volume / 100.0)))


func _on_settings_language_selected(locale_code: String) -> void:
	if locale_code.is_empty():
		return
	if _reality_interaction_is_active():
		_exit_reality_interaction(false)
	if not _locale.select_language(locale_code):
		return
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_session.enabled, _camera_session.source)
	# 换语言即换字池:清空造句台,避免旧语言的字混进新语言的句子。
	if game != null:
		game.free_sentence_clear()
	_render()
	_ui_theme_helper.refresh_localized_ui(_ui_root)
	_refresh_camera_source_option_labels()


func _on_manual_save_pressed() -> void:
	var progress_saved := _save_progress()
	var preferences_saved := _locale.save_preferences(_master_volume, _vhs_enabled, _camera_session.enabled, _camera_session.source)
	if _settings_history_panel != null:
		_settings_history_panel.set_save_status(
			"已保存当前进度与设置。" if progress_saved and preferences_saved else "保存失败，请检查本地写入权限。"
		)
	_ui_theme_helper.refresh_localized_ui(_ui_root)


func _on_return_main_menu_pressed() -> void:
	call_deferred("show_main_menu")


func _on_vhs_toggled(value: bool) -> void:
	_vhs_enabled = value
	if _vhs_overlay != null:
		_vhs_overlay.visible = value


func _on_camera_access_toggled(value: bool) -> void:
	_camera_session_decided = true
	_set_camera_enabled(value, true)


func _request_quit_game() -> void:
	game.mark_exit_prompt_seen()
	if _settings_history_panel != null:
		_settings_history_panel.request_quit()


func _cancel_quit_game() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.cancel_quit()


func _confirm_quit_game() -> void:
	if _game_started:
		_save_progress()
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_session.enabled, _camera_session.source)
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
		_phone_launcher_panel.layout_popup(str(_phone_shell_snapshot().get("view_state", "")) == "phone_down")
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
		targets.append(_phone_launcher_panel.get_app_window("babel"))
		targets.append(_phone_launcher_panel.get_app_window("notebook"))
	if _social_feed_panel != null:
		targets.append(_social_feed_panel.get_app_window())
		targets.append(_social_feed_panel.get_detail_window())
	for target in targets:
		if target == null or not is_instance_valid(target):
			continue
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
	_render_apple_hud()
	if _desk_log != null:
		_desk_log.text = log_text
	_refresh_settings_menu_labels()
	if _settings_history_panel != null and _settings_history_panel.is_open():
		_render_history_window()
	_render_playtest_assist()
	_update_doll_guide()
	if _reality_scene_adapter != null:
		_reality_scene_adapter.sync_ultimate_task_props(_reality_scene_deps())


func _render_playtest_assist() -> void:
	if _playtest_assist_panel == null or not is_instance_valid(_playtest_assist_panel):
		_playtest_assist_panel = null
		return
	_playtest_assist_panel.render(_playtest_assist_snapshot())


func _playtest_assist_snapshot() -> Dictionary:
	# 引导台词由常驻玩偶小窗承担;本面板只在纯测试辅助开启时出现,不再双显同一句。
	var visible := _session_shows_play_chrome() and not _settings_is_open() and _playtest_assist_enabled
	var lines: Array[String] = []
	if not visible or not _playtest_assist_enabled or game == null:
		return {"visible": visible, "lines": lines}
	var step: Dictionary = game.get_tutorial_step()
	lines.append(str(step.get("test_instruction", "测试提示：继续探索。")))
	var day_progress := _day_progress_snapshot()
	var floor_number := clampi(int(day_progress.get("tower_floor", 1)), 1, 4)
	if floor_number <= 3:
		var progress: Dictionary = game.get_key_clue_progress(floor_number)
		var item: Dictionary = game.get_prerequisite_item_for_floor(floor_number)
		var item_id := str(item.get("id", ""))
		var clue_state := "已答对" if bool(progress.get("solved", false)) else "未完成"
		var item_state := "已拾取" if item_id in game.collected_prerequisite_item_ids else ("已显形" if item_id in game.revealed_prerequisite_item_ids else "未显形")
		lines.append("本层测试：关键 NPC %s / 前置物 %s" % [clue_state, item_state])
		if bool(progress.get("solved", false)) and item_id not in game.collected_prerequisite_item_ids:
			lines.append("目标：%s。%s" % [str(item.get("label", "前置物")), str(item.get("location_hint", "跟随荧光测试标记。"))])
	var collected_count := game.collected_prerequisite_item_ids.size()
	lines.append("隐藏层测试：前置物 %d/3 · 污染 %d/80 · 第三层结束检查" % [collected_count, int(day_progress.get("pollution", 0))])
	return {"visible": visible, "lines": lines}


func _action_text(actions: int) -> String:
	return "今日行动\n%s" % _action_pips(actions)


func _action_pips(actions: int) -> String:
	var pips := ""
	for index in game.max_actions_per_day:
		if index > 0:
			pips += " "
		pips += "●" if index < actions else "○"
	return pips


func _render_world_prompt() -> void:
	if _world_prompt == null:
		return
	var hud := _reality_hud_snapshot()
	var plan := _day_plan()
	var day_progress: Dictionary = hud.get("day_progress", {})
	if str(hud.get("view_state", "")) == "phone_down":
		_world_prompt.text = "DAY %d. %s\n路面在脚下滑动。手机 App 的窗口浮在屏幕旁边。" % [int(day_progress.get("day", 1)), plan["title"]]
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
			_:
				_world_prompt.text = ""


func _render_app() -> void:
	for app_id in ["social", "babel", "notebook"]:
		if not _app_bodies.has(app_id):
			continue
		_app_body = _app_bodies[app_id] as VBoxContainer
		_app_title = _app_titles[app_id] as Label
		match app_id:
			"babel":
				_app_title.text = "巴别塔 App"
				_render_babel_app()
			"notebook":
				_app_title.text = "笔记本 App"
				_render_notebook_app()
			"social":
				_render_social_app()


func _render_social_app() -> void:
	_app_title.text = "社交媒体 App"
	if _social_feed_panel == null:
		return
	_social_feed_panel.render_app(_social_screen, _social_channel)
	_social_feed_panel.render_companion()


func _render_babel_app() -> void:
	if _babel_app_panel == null:
		return
	_babel_app_panel.render(_app_body)


func _set_social_screen(screen: String) -> void:
	_social_screen = screen
	_social_detail_open = false
	if _social_feed_panel != null:
		_social_feed_panel.close_detail()
	_social_channel = "discover"
	_refresh_phone_shell()


func _on_social_channel_pressed(channel: String) -> void:
	_social_channel = channel
	if channel == "tower_base":
		_social_screen = "home"
		_social_detail_post_index = 0
		_social_detail_open = true
		if _social_feed_panel != null:
			_social_feed_panel.open_detail(0)
	else:
		_social_screen = "home"
		_social_detail_open = false
		if _social_feed_panel != null:
			_social_feed_panel.close_detail()
	_refresh_phone_shell()


func _on_social_follow_pressed(author_id: String) -> void:
	var followed := game.toggle_social_follow(author_id)
	var display_handle := SocialFeedContentScript.author_display(author_id, _social_content_deps())
	log_text = "已关注 @%s。" % display_handle if followed else "已取消关注 @%s。" % display_handle


func _on_social_like_pressed(post_id: String) -> void:
	var liked := game.toggle_social_like(post_id)
	log_text = "已保存这条信号。" if liked else "已取消保存。"


func _open_social_post(post_index: int) -> void:
	if _social_feed_panel != null:
		_social_feed_panel.open_detail(post_index)
	_social_detail_post_index = post_index
	_social_detail_open = true
	game.notify_tutorial("post_opened", {"post_index": post_index})
	_refresh_phone_shell()


func _render_notebook_app() -> void:
	if _notebook_app_panel == null:
		return
	_notebook_app_panel.render(_app_body, _notebook_crafting_tab)


func _set_notebook_crafting_tab(tab_id: String) -> void:
	if tab_id not in ["frame", "fusion"]:
		return
	_notebook_crafting_tab = tab_id
	_refresh_phone_shell()


func _render_reality() -> void:
	_render_reality_language_composer()
	if _reality_conversation_panel == null:
		return
	var hud := _reality_hud_snapshot()
	var plan := _day_plan()
	var conversation: Dictionary = hud.get("conversation", {})
	var interaction_active := bool(hud.get("interaction_active", false))
	var prompt := str(conversation.get("prompt", ""))
	var npc_line: String = prompt if interaction_active and not prompt.is_empty() else str(plan["line"])
	var hover_preview := ""
	if not _reality_hover_choice_id.is_empty():
		hover_preview = game.preview_typed_reality_choice(_reality_hover_choice_id)
	var actor_label := str(conversation.get("actor_label", ""))
	_reality_conversation_panel.render({
		"interaction_active": interaction_active,
		"actor_name": actor_label if interaction_active and not actor_label.is_empty() else _reality_hud_actor_label(hud),
		"npc_line": npc_line,
		"conversation_feedback": str(conversation.get("feedback", "")),
		"phase": str(conversation.get("phase", "")),
		"conversation_can_continue": bool(conversation.get("can_continue", false)),
		"conversation_actor_type": str(conversation.get("actor_type", "")),
		"last_polluted_sentence": game.last_polluted_sentence,
		"npc_understanding": game.npc_understanding,
		"choices": conversation.get("choices", []),
		"hover_choice_id": _reality_hover_choice_id,
		"hover_choice_preview": hover_preview,
		"playtest_assist_enabled": _playtest_assist_enabled,
		"typed_reality_bbcode": _typed_reality_bbcode(),
		"typing_reveal_index": int(conversation.get("reveal_index", 0)),
		"typing_unit_count": game.get_typed_reality_unit_count(),
	})


func _render_reality_language_composer() -> void:
	if _reality_language_composer_panel == null:
		return
	var hud := _reality_hud_snapshot()
	var conversation: Dictionary = hud.get("conversation", {})
	var composing := bool(hud.get("interaction_active", false)) and str(conversation.get("phase", "")) == "composing" and str(conversation.get("mode", "")) == "lexeme"
	var slots: Array = []
	if composing:
		for slot_value in game.get_craft_slots():
			var slot: Dictionary = (slot_value as Dictionary).duplicate()
			var slot_id := str(slot.get("id", ""))
			slot["filled_text"] = _language_slot_text(slot_id, str(slot.get("placeholder", "等待词语")), "doctor")
			slots.append(slot)
	_reality_language_composer_panel.render({
		"composing": composing,
		"token_options": game.get_language_token_options("doctor") if composing else [],
		"slots": slots,
		"preview": game.get_language_sentence_preview("doctor") if composing else {},
		"can_spend_action": game.can_spend_action(),
	})


func _typed_reality_bbcode() -> String:
	var normal_color := _ui_theme_helper.theme_color("surface").to_html(false)
	var pending_color := Color("777B72").to_html(false)
	var corrupted_color := Color("FF3B30").to_html(false)
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


func _on_reality_choice_hovered(choice_id: String) -> void:
	_reality_hover_choice_id = choice_id
	if _reality_conversation_panel != null:
		var preview := game.preview_typed_reality_choice(choice_id)
		_reality_conversation_panel.set_intent_preview(preview)


func _on_reality_choice_unhovered(choice_id: String) -> void:
	if _reality_hover_choice_id != choice_id:
		return
	_reality_hover_choice_id = ""
	if _reality_conversation_panel != null:
		_reality_conversation_panel.clear_intent_preview()


func _on_reality_choice_selected(choice_id: String) -> void:
	if game.select_typed_reality_choice(choice_id):
		_reality_hover_choice_id = ""
		_sync_audio_state(false)


func _on_reality_continue_pressed() -> void:
	if str(_reality_conversation_snapshot().get("phase", "")) == "result" and game.continue_typed_reality_conversation():
		_localize_active_conversation()
		_reality_hover_choice_id = ""
		_sync_audio_state(false)
		return
	_exit_reality_interaction()


func _advance_typed_reality_character() -> bool:
	if not _reality_interaction_is_active():
		return false
	var actions_before := int(game.actions_remaining)
	var result: Dictionary = game.advance_typed_reality_character()
	if not bool(result.get("advanced", false)):
		return false
	if bool(result.get("locked_out", false)):
		if _reality_scene_adapter != null:
			_reality_scene_adapter.apply_interaction({"action": "end"})
			_reality_scene_adapter.clear_nearby_targets()
		_set_reality_mouse_look(true)
	if bool(result.get("action_spent", false)):
		_after_effective_action(actions_before)
	else:
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
		_settings_window.visible = _settings_is_open() and show_play
	if _desk_log != null:
		_desk_log.visible = show_play and in_phone
	if _vhs_overlay != null:
		_vhs_overlay.visible = _vhs_enabled and show_play
	if _apple_hud_panel != null:
		var rail: PanelContainer = _apple_hud_panel.get_rail()
		if rail != null:
			rail.visible = show_play
		var reveal_zone: Control = _apple_hud_panel.get_reveal_zone()
		if reveal_zone != null:
			reveal_zone.visible = show_play
		var tooltip: PanelContainer = _apple_hud_panel.get_tooltip()
		if tooltip != null and not show_play:
			tooltip.visible = false
	_update_reality_hud_visibility()
	# 可见性判定与 _render_playtest_assist 保持同一公式:引导台词由玩偶小窗独占,
	# 本面板只在测试辅助开启时出现。
	_render_playtest_assist()
	_update_doll_guide()
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
			_reality_conversation_panel.update_visibility(false, "", "")
		if _reality_language_composer_panel != null:
			_reality_language_composer_panel.update_visibility(false, "", "")
		return
	var hud := _reality_hud_snapshot()
	var in_phone := str(hud.get("view_state", "phone_down")) == "phone_down"
	var interaction_active := bool(hud.get("interaction_active", false))
	if _world_prompt != null:
		var nearby_kind := str((hud.get("nearby", {}) as Dictionary).get("kind", "none"))
		_world_prompt.visible = (not in_phone) and (not interaction_active) and nearby_kind != "none"
	var interaction_visible := (not in_phone) and interaction_active
	var conversation: Dictionary = hud.get("conversation", {})
	if _reality_conversation_panel != null:
		_reality_conversation_panel.update_visibility(interaction_visible, str(conversation.get("phase", "")), _reality_hover_choice_id)
	if _reality_language_composer_panel != null:
		_reality_language_composer_panel.update_visibility(
			interaction_visible,
			str(conversation.get("phase", "")),
			str(conversation.get("mode", ""))
		)


func _phone_view_is_down() -> bool:
	return str(_phone_shell_snapshot().get("view_state", "phone_down")) == "phone_down"


func _update_phone_shell_visibility() -> void:
	var in_phone := _phone_view_is_down()
	var show_play := _session_shows_play_chrome()
	# 手机始终留在画面上:打开 App 只是弹出对应窗口,不会让手机消失。
	var show_phone_home := show_play and in_phone
	if _phone_popup_expanded != show_phone_home:
		_phone_popup_expanded = show_phone_home
		if _phone_launcher_panel != null:
			_phone_launcher_panel.layout_popup(show_phone_home)
	var phone_panel: PanelContainer = _phone_launcher_panel.get_phone_panel() if _phone_launcher_panel != null else null
	if phone_panel != null:
		phone_panel.visible = show_phone_home
	if _phone_tab != null:
		_phone_tab.visible = false
	if _phone_launcher_panel != null:
		_phone_launcher_panel.set_content_visible(show_phone_home)
	if show_phone_home:
		var foreground_app := str(_phone_shell_snapshot().get("active_app_window", ""))
		if not foreground_app.is_empty():
			_open_app_windows[foreground_app] = true
	for app_id in _app_windows.keys():
		var app_window := _app_windows[app_id] as Control
		if app_window != null:
			app_window.visible = show_phone_home and bool(_open_app_windows.get(app_id, false))
	if _social_feed_panel != null:
		_social_feed_panel.update_visibility(show_phone_home, bool(_open_app_windows.get("social", false)))
	if _phone_down_backdrop_image != null:
		_phone_down_backdrop_image.visible = show_play and (in_phone or _phone_art_alpha > 0.03)
	if _hand_phone_image != null:
		_hand_phone_image.visible = show_play and (in_phone or _phone_art_alpha > 0.03)


func _update_world_for_phone_view() -> void:
	var in_phone := _phone_view_is_down()
	if _view_toggle_button != null:
		_view_toggle_button.visible = _session_shows_play_chrome() and not _settings_is_open() and (in_phone or not _reality_interaction_is_active())
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
	if _texture_cache.has(path):
		return _texture_cache[path]
	var image := Image.new()
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var err := image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = image.load_webp_from_buffer(bytes)
		if err != OK:
			return null
		var texture := ImageTexture.create_from_image(image)
		_texture_cache[path] = texture
		return texture
	if FileAccess.file_exists("%s.import" % path):
		var resource := load(path)
		if resource is Texture2D:
			_texture_cache[path] = resource
			return resource
	return null




func _is_pickable_social_character(character: String) -> bool:
	return not character.is_empty() and not " \t\r\n，。！？；：、,.!?;:（）()【】[]《》<>“”\"'—-…".contains(character)


func _close_app_window(app_id: String) -> void:
	_open_app_windows[app_id] = false
	if app_id == "social":
		_social_detail_open = false
		if _social_feed_panel != null:
			_social_feed_panel.close_detail()
	var foreground_app := str(_phone_shell_snapshot().get("active_app_window", ""))
	if foreground_app == app_id:
		var remaining_open_apps: Array[String] = []
		for candidate in ["social", "babel", "notebook"]:
			if bool(_open_app_windows.get(candidate, false)):
				remaining_open_apps.append(candidate)
		game.close_app_window(app_id, remaining_open_apps)
	var any_open := false
	for open_value in _open_app_windows.values():
		if bool(open_value):
			any_open = true
			break
	_phone_launcher_open = not any_open
	log_text = "关闭 %s 窗口。" % app_id
	_refresh_phone_shell()


func _open_phone_launcher() -> void:
	game.set_view_state("phone_down")
	_set_reality_mouse_look(false)
	_phone_launcher_open = true
	if _phone_launcher_panel != null:
		_phone_launcher_panel.move_phone_to_front()
	log_text = "展开手机主页。"
	_refresh_phone_shell()


func _close_social_detail_window() -> void:
	if _social_feed_panel != null:
		_social_feed_panel.close_detail()
	_social_detail_open = false
	if _social_channel == "tower_base":
		_social_channel = "discover"
	log_text = "关闭社交详情。"
	_refresh_phone_shell()


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
	_sync_window_manager_enabled()


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
	return bool(_progression_snapshot().get("ending_unlocked", false))


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
	_ending_screen_panel.render(_ending_screen_render_state())


func _ensure_ending_screen_panel() -> void:
	if _ending_screen_panel != null and is_instance_valid(_ending_screen_panel):
		return
	_ending_screen_panel = EndingScreenPanelScript.new()
	_ending_screen_panel.name = "EndingScreenPanel"
	add_child(_ending_screen_panel)
	_connect_ending_screen_panel_signals()


func _ending_screen_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"restart": new_game,
		"translate": func(text: String) -> String: return _locale.translate(text),
		"set_localized_property": _ui_theme_helper.set_localized_property,
	}


func _ending_screen_render_state() -> Dictionary:
	var progression := _progression_snapshot()
	return {
		"epilogue_lines": NarrativeSessionCatalogScript.epilogue_lines(_locale.current_locale),
		"show_language_choices": str(progression.get("ending_language_choice", "")).is_empty(),
		"language_choices": game.get_ending_language_choices(_locale.current_locale),
		"language_output": game.get_ending_language_output(_locale.current_locale),
		"relationship_residue": game.relationship_residue,
		"relationship_state_label": game.get_relationship_state_label(),
	}


func _connect_ending_screen_panel_signals() -> void:
	if _ending_screen_panel == null:
		return
	if not _ending_screen_panel.ending_language_selected.is_connected(_on_ending_language_selected):
		_ending_screen_panel.ending_language_selected.connect(_on_ending_language_selected)


func _on_ending_language_selected(choice_id: String) -> void:
	game.choose_ending_language(choice_id)


func _on_app_pressed(app_id: String) -> void:
	game.set_view_state("phone_down")
	_set_reality_mouse_look(false)
	game.set_active_app(app_id)
	if app_id == "social":
		game.notify_tutorial("social_opened")
	elif app_id == "notebook":
		game.notify_tutorial("notebook_opened")
	_open_app_windows[app_id] = true
	_phone_launcher_open = false
	if _app_windows.has(app_id):
		var window := _app_windows[app_id] as Control
		if window != null:
			window.move_to_front()
	log_text = "打开 %s。" % app_id
	_refresh_phone_shell()


## ============ 玩偶全程引导(常驻小窗,承担教程与楼层任务提示)============

func _build_doll_guide_overlay() -> void:
	_ensure_doll_guide_panel()
	_doll_guide_panel.mount(_ui_root, _doll_guide_mount_deps())


func _ensure_doll_guide_panel() -> void:
	if _doll_guide_panel != null and is_instance_valid(_doll_guide_panel):
		return
	_doll_guide_panel = DollGuidePanelScript.new()
	_doll_guide_panel.name = "DollGuidePanel"
	add_child(_doll_guide_panel)


func _doll_guide_mount_deps() -> Dictionary:
	return {
		"label_factory": _ui_theme_helper.label,
		"theme_color": _ui_theme_helper.theme_color,
		"load_texture": _load_runtime_texture,
		"register_draggable": _make_draggable_window,
		"portrait_path": GUIDE_DOLL_CHARACTER_PATH,
	}


func _toggle_doll_guide_collapsed() -> void:
	if _doll_guide_panel != null:
		_doll_guide_panel.toggle_collapsed()


func _update_doll_guide() -> void:
	if _doll_guide_panel == null or not is_instance_valid(_doll_guide_panel):
		_doll_guide_panel = null
		return
	# 派蒙式退避:玩家与 NPC 对话/交互时,玩偶(连同气泡窗)一起隐身,不抢戏。
	var should_show := _session_shows_play_chrome() and game != null and not _reality_interaction_is_active()
	_doll_guide_panel.refresh(should_show, _doll_guide_current_line() if should_show else "")


func _doll_guide_current_line() -> String:
	var step: Dictionary = game.get_tutorial_step()
	if not bool(step.get("is_complete", false)):
		var line := str(step.get("guide_line", ""))
		# 一步一步教:多次数步骤显示进度(如 拾取三个字 1/3)。
		var required_count := int(step.get("required_count", 0))
		if required_count > 1:
			line += "(%d/%d)" % [clampi(int(step.get("event_count", 0)), 0, required_count), required_count]
		return line
	var day_progress := _day_progress_snapshot()
	var progression := _progression_snapshot()
	var tower_floor := int(day_progress.get("tower_floor", 1))
	var floor3_complete := bool(progression.get("floor3_task_complete", false))
	var floor4_complete := bool(progression.get("floor4_task_complete", false))
	if tower_floor == 3 and not floor3_complete:
		return "门在等一句话。去笔记本里拼给它。"
	if tower_floor == 3 and floor3_complete:
		return "门记得这句话。"
	if tower_floor == 4 and not floor4_complete:
		return "出口还不存在。让它存在。"
	if tower_floor == 4 and floor4_complete:
		return "出口存在了。这里不会记下我们。"
	return str(step.get("guide_line", "你已经会自己走了。至少现在是。"))


## ============ 自由造句台(多邻国式:tap 入句、tap 撤回、随时投稿)============

## 多邻国 U1 质感:圆角约为高度 1/4、浅底细描边、底部厚边模拟浮起阴影;
## 按下时下沉 2px(上边距+2/下边距-2,底厚边收薄);ghost 为凹陷灰。

func _on_canvas_tile_moved(unit: String, tile_position: Vector2) -> void:
	game.set_char_canvas_position(unit, tile_position, _locale.current_locale)


func _commit_notebook_canvas_positions() -> void:
	if _notebook_app_panel == null or not is_instance_valid(_notebook_app_panel):
		return
	_notebook_app_panel.commit_canvas_positions()


## 把字从笔记本画布拖到发布页的句子区:命中即入句,未命中则飞回画布原位。
func _on_canvas_tile_dropped_outside(unit: String, release_global: Vector2) -> void:
	_ensure_language_material()
	var answer_panel := _find_control_by_name(_ui_root, "ComposerAnswerPanel")
	_language_material.place_if_over_answer(unit, release_global, answer_panel)


func _on_composer_bank_tapped(unit: String) -> void:
	_ensure_language_material()
	_language_material.place_from_bank(unit)


func _on_composer_answer_tapped(unit_index: int) -> void:
	_ensure_language_material()
	_language_material.remove_at(unit_index)


func _on_composer_area_drop(data: Dictionary) -> void:
	_ensure_language_material()
	_language_material.drop_on_area(data)


func _on_composer_tile_drop(data: Dictionary, before_index: int) -> void:
	_ensure_language_material()
	_language_material.drop_before(data, before_index)


func _handle_composer_drop(data: Dictionary, target_index: int) -> void:
	_ensure_language_material()
	_language_material.apply_drop_at(data, target_index)


func _composer_answer_target() -> Vector2:
	var answer_flow := _find_control_by_name(_ui_root, "ComposerAnswerFlow")
	if answer_flow != null and is_instance_valid(answer_flow):
		return LanguageMaterialScript.composer_answer_target(answer_flow)
	return _notebook_flight_target()


func _on_composer_submit_pressed() -> void:
	_ensure_language_material()
	_language_material.submit()


func _build_pickup_flight_layer() -> void:
	_pickup_flight_layer = FlyToTargetLayer.new()
	_pickup_flight_layer.name = "PickupFlightLayer"
	_pickup_flight_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 高于日结过场(95),低于闪回(100):日结黑幕不吞掉仍在飞行的字。
	_pickup_flight_layer.z_index = 97
	_ui_root.add_child(_pickup_flight_layer)
	_pickup_flight_layer.flight_landed.connect(_on_pickup_flight_landed)


## 拾字时把笔记本窗口召回左上角初始位置并打开,让玩家看见字飞进去。
func _ensure_notebook_window_home() -> void:
	_open_app_windows["notebook"] = true
	var window := _notebook_window_control()
	if window == null:
		return
	if _phone_launcher_panel != null:
		_phone_launcher_panel.layout_app_window("notebook")
	window.visible = game != null and str(_phone_shell_snapshot().get("view_state", "")) == "phone_down"


func _pickup_bbcode(source_text: String) -> String:
	_ensure_language_material()
	return _language_material.marked_text(source_text, _ui_theme_helper.theme_color("flash_text"))


func _on_pickup_unit_meta(meta: Variant, post_id: String) -> void:
	_ensure_language_material()
	_language_material.pick_from_post(meta, post_id)


func _on_pickup_flight_landed(_unit: String) -> void:
	_play_ui_sound(_audio_controller.pickup_land_audio if _audio_controller != null else null)
	_play_ui_sound(_audio_controller.notebook_hinge_audio if _audio_controller != null else null)
	_squash_notebook_window()


func _on_language_material_sfx(kind: String) -> void:
	if _audio_controller == null:
		return
	match kind:
		"pickup_press":
			_play_ui_sound(_audio_controller.pickup_press_audio)


func _on_language_material_log(text: String) -> void:
	log_text = text


func _on_language_pickup_flight(unit: String, origin: Vector2) -> void:
	if _pickup_flight_layer != null:
		_pickup_flight_layer.play_hold_flight(unit, origin, _notebook_flight_target, _ui_theme_helper.theme_color("flash_text"))


func _on_language_place_flight(unit: String) -> void:
	if _pickup_flight_layer != null:
		_pickup_flight_layer.play_place_flight(unit, get_viewport().get_mouse_position(), _composer_answer_target, _ui_theme_helper.theme_color("accent"))


## 短促 UI 音效:重复触发时从头播放,不叠加成噪音。
func _play_ui_sound(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player) or player.stream == null or not player.is_inside_tree():
		return
	player.stop()
	player.play()


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


func _on_language_token_pressed(token_id: String) -> void:
	_selected_language_token_id = token_id
	log_text = "选中了一个带到医生面前的词。"
	_refresh_reality_hud()


func _on_language_token_dropped(data: Dictionary, slot_id: String) -> void:
	var token_id := str(data.get("id", ""))
	if token_id.is_empty():
		return
	_selected_language_token_id = token_id
	if game.place_language_token(slot_id, token_id, "doctor"):
		log_text = "词已经进入医生句槽。"
	else:
		log_text = "这个词不能放在句子的这个位置。"
	_refresh_reality_hud()


func _on_language_slot_pressed(slot_id: String) -> void:
	if _selected_language_token_id.is_empty():
		log_text = "先选择一个词。"
	elif game.place_language_token(slot_id, _selected_language_token_id, "doctor"):
		log_text = "词已经进入医生句槽。"
	else:
		log_text = "这个词不能放在句子的这个位置。"
	_refresh_reality_hud()


func _on_confirm_doctor_sentence_pressed() -> void:
	var actions_before := int(game.actions_remaining)
	if game.confirm_doctor_sentence():
		_selected_language_token_id = ""
		log_text = "同一句话到了医生那里，已经不是原来的样子。"
		_after_effective_action(actions_before)
	else:
		log_text = "句子还不完整，或者这些词还没有在手机里发布。"
		_refresh_reality_hud()


func _on_fusion_meme_dropped(data: Dictionary, slot_id: String) -> void:
	var meme_id := str(data.get("id", ""))
	if game.place_meme_in_fusion_slot(slot_id, meme_id):
		selected_meme_id = meme_id
		log_text = "旧梗已放入融合槽。"
	else:
		log_text = "两个融合槽必须放入不同的完整梗。"
	_refresh_phone_shell()


func _on_fusion_slot_pressed(slot_id: String) -> void:
	if selected_meme_id.is_empty():
		log_text = "先从融合列表选择一个完整梗。"
	elif game.place_meme_in_fusion_slot(slot_id, selected_meme_id):
		log_text = "旧梗已放入融合槽。"
	else:
		log_text = "两个融合槽不能使用同一个梗。"
	_refresh_phone_shell()


func _on_confirm_fusion_pressed() -> void:
	var actions_before := int(game.actions_remaining)
	if game.confirm_meme_fusion():
		var fused_memes: Array = _inventory_snapshot().get("completed_memes", [])
		if not fused_memes.is_empty():
			var fused: Dictionary = fused_memes[0] as Dictionary
			selected_meme_id = str(fused.get("id", ""))
			log_text = "融合完成：%s" % str(fused.get("title", "复合梗"))
		_after_effective_action(actions_before)
	else:
		log_text = "需要两个不同且尚未融合过的完整梗。"
		_refresh_phone_shell()


func _on_confirm_dialogue_pressed() -> void:
	var actions_before: int = int(game.actions_remaining)
	if game.confirm_dialogue():
		selected_meme_id = ""
		log_text = "句子发出去了。资金到账，污染留下。"
		_after_effective_action(actions_before)
	else:
		log_text = "发布空格里还没有完整梗。"
		_refresh_phone_shell()


func _after_effective_action(actions_before: int = -1) -> void:
	var settlement := _narrative_settlement(actions_before)
	if not settlement.is_empty():
		var hud_actions_label := _hud_actions_label_ref()
		if hud_actions_label != null and settlement.has("actions_before"):
			hud_actions_label.text = _action_text(int(settlement.get("actions_before", 0)))
		_bind_narrative_director()
		_narrative_director.play_beat(settlement, _ending_is_unlocked())
		return
	if _settle_day_and_present_rewards():
		return
	_refresh_play_surfaces()


func _narrative_settlement(actions_before: int) -> Dictionary:
	if game == null:
		return {}
	var spent := actions_before >= 0 and int(game.actions_remaining) < actions_before
	var flashback := bool(game.pollution_flashback_pending)
	if not spent and not flashback:
		return {}
	var settlement := {
		"day_transition": bool(game.needs_day_settlement),
		"flashback": flashback,
	}
	if spent:
		settlement["actions_before"] = actions_before
		settlement["actions_after"] = int(game.actions_remaining)
	return settlement


func _settle_day_and_present_rewards(from_flashback: bool = false) -> bool:
	var settled := game != null and game.settle_day_if_needed()
	if not settled and not from_flashback:
		return false
	if settled:
		if _reality_scene_adapter != null:
			_reality_scene_adapter.apply_interaction({"action": "end"})
			_reality_scene_adapter.clear_nearby_targets()
		_reality_hover_choice_id = ""
		_sync_audio_state(false)
	selected_meme_id = ""
	if from_flashback:
		log_text = "黑屏之后，已经是第二天。"
		if game != null and not game.event_log.is_empty():
			log_text = "%s\n%s" % [log_text, game.event_log[0]]
	elif game != null and not game.event_log.is_empty():
		log_text = game.event_log[0]
	return settled


func _day_plan() -> Dictionary:
	var current_day := 1 if game == null else int(_day_progress_snapshot().get("day", 1))
	return SocialFeedCatalogScript.day_plan_for_day(current_day)


func _language_slot_text(slot_id: String, placeholder: String, world: String) -> String:
	var token_id := str(game.language_sentence_slots.get(slot_id, ""))
	if token_id.is_empty():
		return placeholder
	for option_value in game.get_language_token_options(world):
		var option: Dictionary = option_value as Dictionary
		if str(option.get("id", "")) == token_id:
			return str(option.get("display_text", option.get("text", placeholder)))
	return placeholder


func _fusion_slot_text(slot_id: String) -> String:
	var inventory := _inventory_snapshot()
	var meme_id := str((inventory.get("fusion_slots", {}) as Dictionary).get(slot_id, ""))
	if meme_id.is_empty():
		return "旧梗 A" if slot_id == "left" else "旧梗 B"
	for meme in inventory.get("completed_memes", []):
		if str((meme as Dictionary).get("id", "")) == meme_id:
			return str((meme as Dictionary).get("title", (meme as Dictionary).get("text", "完整梗")))
	return "等待完整梗"


func _placed_meme() -> Dictionary:
	if game.dialogue_blanks.has("blank_1"):
		var meme_id := str(game.dialogue_blanks["blank_1"])
		for meme in _inventory_snapshot().get("completed_memes", []):
			if str((meme as Dictionary).get("id", "")) == meme_id:
				return (meme as Dictionary).duplicate(true)
	return {}


func _corrupt(text: String) -> String:
	text = _locale.translate(text)
	var snapshot := _pollution_stage_snapshot()
	var replacements := [_locale.translate("哈吉米"), "□", _locale.translate("沉默"), "……"]
	return PollutionStageScript.corrupt_sentence_ui(
		text,
		int(snapshot.get("pollution", 0)),
		int(snapshot.get("day", 0)),
		_locale.current_locale,
		replacements,
	)


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
