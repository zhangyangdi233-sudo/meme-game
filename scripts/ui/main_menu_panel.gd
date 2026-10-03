class_name MainMenuPanel
extends Node
## Game-side main menu: mounts the editor-authored layout scene, tints it with the active palette, and emits intent signals.

const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")
const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")

signal start_game_requested
signal continue_game_requested
signal exit_game_requested
signal language_picker_requested

var _main_menu_layer: Control
var _continue_button: Button
var _active_palette_fn: Callable
var _has_save_fn: Callable


func mount(parent: Control, deps: Dictionary) -> void:
	_apply_mount_deps(deps)
	_build_main_menu(parent)


func get_layer() -> Control:
	return _main_menu_layer


func unmount() -> void:
	if _main_menu_layer != null and is_instance_valid(_main_menu_layer):
		_main_menu_layer.visible = false
		_main_menu_layer.queue_free()
	_main_menu_layer = null
	_continue_button = null


func refresh_continue_state() -> void:
	if _continue_button == null or not is_instance_valid(_continue_button):
		return
	var has_save := _has_save_fn.is_valid() and bool(_has_save_fn.call())
	_continue_button.disabled = not has_save
	_continue_button.tooltip_text = "回到上次离开的位置" if has_save else "暂无自动存档"


func _apply_mount_deps(deps: Dictionary) -> void:
	if deps.is_empty():
		return
	_active_palette_fn = deps.get("active_palette", Callable())
	_has_save_fn = deps.get("has_save", Callable())


func _build_main_menu(parent: Control) -> void:
	if parent == null:
		return
	_main_menu_layer = MainMenuScene.instantiate()
	parent.add_child(_main_menu_layer)
	var palette: Dictionary = _active_palette_fn.call() if _active_palette_fn.is_valid() else UiPaletteScript.PALETTE_1
	_main_menu_layer.apply_palette(palette)

	_continue_button = _main_menu_layer.get_node("%MainMenuContinueButton")
	refresh_continue_state()
	_continue_button.pressed.connect(_on_continue_pressed, CONNECT_DEFERRED)
	(_main_menu_layer.get_node("%MainMenuStartButton") as Button).pressed.connect(_on_start_pressed, CONNECT_DEFERRED)
	(_main_menu_layer.get_node("%MainMenuExitButton") as Button).pressed.connect(_on_exit_pressed)
	(_main_menu_layer.get_node("%MainMenuLanguageButton") as Button).pressed.connect(_on_language_pressed)


func _on_start_pressed() -> void:
	start_game_requested.emit()


func _on_continue_pressed() -> void:
	continue_game_requested.emit()


func _on_exit_pressed() -> void:
	exit_game_requested.emit()


func _on_language_pressed() -> void:
	language_picker_requested.emit()
