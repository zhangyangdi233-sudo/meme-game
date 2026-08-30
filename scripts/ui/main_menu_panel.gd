class_name MainMenuPanel
extends Node
## Game-side main menu chrome: green background, poster stripes, title stack, buttons, and intent signals.

signal start_game_requested
signal continue_game_requested
signal exit_game_requested
signal language_picker_requested

var _main_menu_layer: Control
var _continue_button: Button
var _label_factory: Callable
var _theme_color_fn: Callable
var _has_save_fn: Callable


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_main_menu(parent)


func get_layer() -> Control:
	return _main_menu_layer


func refresh_continue_state() -> void:
	if _continue_button == null or not is_instance_valid(_continue_button):
		return
	var has_save := _has_save_fn.is_valid() and bool(_has_save_fn.call())
	_continue_button.disabled = not has_save
	_continue_button.tooltip_text = "回到上次离开的位置" if has_save else "暂无自动存档"


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_label_factory = deps.get("label_factory", Callable())
	_theme_color_fn = deps.get("theme_color", Callable())
	_has_save_fn = deps.get("has_save", Callable())


func _build_main_menu(parent: Control) -> void:
	if parent == null or not _label_factory.is_valid() or not _theme_color_fn.is_valid():
		return

	_main_menu_layer = Control.new()
	_main_menu_layer.name = "MainMenuLayer"
	_main_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(_main_menu_layer)

	var bg := ColorRect.new()
	bg.name = "MainMenuGreenBackground"
	bg.color = Color("5DAE6B")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_menu_layer.add_child(bg)

	for index in 7:
		var stripe := ColorRect.new()
		stripe.name = "MainMenuPosterStripe%d" % index
		stripe.color = Color(_theme_color_fn.call("surface"), 0.96 if index % 2 == 0 else 0.0)
		stripe.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stripe.offset_left = 74 + index * 144
		stripe.offset_top = 322
		stripe.offset_right = stripe.offset_left + 122
		stripe.offset_bottom = 430
		_main_menu_layer.add_child(stripe)
		var cut := ColorRect.new()
		cut.name = "MainMenuBlackCut%d" % index
		cut.color = _theme_color_fn.call("ink")
		cut.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cut.offset_left = stripe.offset_left + 10
		cut.offset_top = 322 + (index % 3) * 18
		cut.offset_right = cut.offset_left + 118
		cut.offset_bottom = cut.offset_top + 22
		cut.rotation = deg_to_rad(-22 + index * 9)
		_main_menu_layer.add_child(cut)

	var title_stack := VBoxContainer.new()
	title_stack.name = "MainMenuTextStack"
	title_stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_stack.offset_left = 70
	title_stack.offset_top = 218
	title_stack.offset_right = 1040
	title_stack.offset_bottom = 560
	title_stack.add_theme_constant_override("separation", 18)
	_main_menu_layer.add_child(title_stack)

	var chapter := _label_factory.call("Cartridge 3", 52, Color(_theme_color_fn.call("surface"), 0.82)) as Label
	chapter.name = "MainMenuChapter"
	title_stack.add_child(chapter)

	var title := _label_factory.call("HAJIMI", 94, _theme_color_fn.call("surface")) as Label
	title.name = "MainMenuTitle"
	title.add_theme_color_override("font_shadow_color", _theme_color_fn.call("ink"))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title_stack.add_child(title)

	var subtitle := _label_factory.call(
		"Die Grenzen meiner Sprache bedeuten die Grenzen meiner Welt.",
		28,
		Color(_theme_color_fn.call("surface"), 0.78),
	) as Label
	subtitle.name = "MainMenuSubtitle"
	title_stack.add_child(subtitle)

	var buttons := HBoxContainer.new()
	buttons.name = "MainMenuButtons"
	buttons.add_theme_constant_override("separation", 18)
	title_stack.add_child(buttons)

	_continue_button = Button.new()
	_continue_button.name = "MainMenuContinueButton"
	_continue_button.text = "继续游戏"
	_continue_button.custom_minimum_size = Vector2(168, 54)
	refresh_continue_state()
	_continue_button.pressed.connect(_on_continue_pressed, CONNECT_DEFERRED)
	buttons.add_child(_continue_button)

	var start_button := Button.new()
	start_button.name = "MainMenuStartButton"
	start_button.text = "新游戏"
	start_button.custom_minimum_size = Vector2(168, 54)
	start_button.pressed.connect(_on_start_pressed, CONNECT_DEFERRED)
	buttons.add_child(start_button)

	var exit_button := Button.new()
	exit_button.name = "MainMenuExitButton"
	exit_button.text = "退出游戏"
	exit_button.set_meta("skip_localization", true)
	exit_button.custom_minimum_size = Vector2(168, 54)
	exit_button.pressed.connect(_on_exit_pressed)
	buttons.add_child(exit_button)

	var language_button := Button.new()
	language_button.name = "MainMenuLanguageButton"
	language_button.text = "语言"
	language_button.custom_minimum_size = Vector2(132, 54)
	language_button.pressed.connect(_on_language_pressed)
	buttons.add_child(language_button)

	var mark := Control.new()
	mark.name = "MainMenuCornerMark"
	mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.offset_left = -150
	mark.offset_top = -126
	mark.offset_right = -56
	mark.offset_bottom = -36
	_main_menu_layer.add_child(mark)
	var mark_circle := ColorRect.new()
	mark_circle.color = _theme_color_fn.call("surface")
	mark_circle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark_circle.offset_left = 28
	mark_circle.offset_top = 0
	mark_circle.offset_right = 62
	mark_circle.offset_bottom = 34
	mark.add_child(mark_circle)
	var mark_stem := ColorRect.new()
	mark_stem.color = _theme_color_fn.call("ink")
	mark_stem.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark_stem.offset_left = 46
	mark_stem.offset_top = 0
	mark_stem.offset_right = 62
	mark_stem.offset_bottom = 34
	mark.add_child(mark_stem)
	for index in 3:
		var base := ColorRect.new()
		base.color = _theme_color_fn.call("surface")
		base.set_anchors_preset(Control.PRESET_TOP_LEFT)
		base.offset_left = 20 - index * 2
		base.offset_top = 54 + index * 10
		base.offset_right = 76 + index * 2
		base.offset_bottom = base.offset_top + 4
		mark.add_child(base)


func _on_start_pressed() -> void:
	start_game_requested.emit()


func _on_continue_pressed() -> void:
	continue_game_requested.emit()


func _on_exit_pressed() -> void:
	exit_game_requested.emit()


func _on_language_pressed() -> void:
	language_picker_requested.emit()
