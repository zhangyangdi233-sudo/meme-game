@tool
class_name PaletteSceneRoot
extends Control
## Root of an editor-authored UI scene: tints descendants by `palette_role` metadata and previews either palette in the editor.
## Tinting replaces RGB only, so alpha authored in the editor survives. Every Button gets the shared flat button style.
## GameUiTheme.apply_ui_theme skips this subtree.

const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")
const ROLE_META := "palette_role"
const SHADOW_ROLE_META := "palette_shadow_role"
const EDITOR_RESCAN_SECONDS := 0.5

@export_enum("palette_1", "pollution_palette_5") var preview_palette := "palette_1":
	set(value):
		preview_palette = value
		if Engine.is_editor_hint() and is_inside_tree():
			_refresh_editor_preview()

var _editor_rescan_elapsed := 0.0
var _editor_role_signature := ""


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_refresh_editor_preview()


func _process(delta: float) -> void:
	_editor_rescan_elapsed += delta
	if _editor_rescan_elapsed < EDITOR_RESCAN_SECONDS:
		return
	_editor_rescan_elapsed = 0.0
	if _role_signature() != _editor_role_signature:
		_refresh_editor_preview()


func apply_palette(palette: Dictionary) -> void:
	_tint(self, palette)


func palette_role_errors() -> PackedStringArray:
	var errors := PackedStringArray()
	_collect_role_errors(self, errors)
	return errors


func _get_configuration_warnings() -> PackedStringArray:
	return palette_role_errors()


func _refresh_editor_preview() -> void:
	_editor_role_signature = _role_signature()
	apply_palette(UiPaletteScript.palette(preview_palette))
	update_configuration_warnings()


func _tint(node: Node, palette: Dictionary) -> void:
	var role := str(node.get_meta(ROLE_META, ""))
	if UiPaletteScript.has_role(role):
		var role_color := UiPaletteScript.color(palette, role)
		if node is ColorRect:
			var rect := node as ColorRect
			rect.color = Color(role_color, rect.color.a)
		elif node is Label:
			_tint_theme_color(node as Control, "font_color", role_color)
	var shadow_role := str(node.get_meta(SHADOW_ROLE_META, ""))
	if node is Label and UiPaletteScript.has_role(shadow_role):
		_tint_theme_color(node as Control, "font_shadow_color", UiPaletteScript.color(palette, shadow_role))
	if node is Button:
		UiPaletteScript.apply_button_style(node as Button, palette)
	for child in node.get_children():
		_tint(child, palette)


func _tint_theme_color(control: Control, color_name: String, role_color: Color) -> void:
	var alpha := control.get_theme_color(color_name).a
	control.add_theme_color_override(color_name, Color(role_color, alpha))


func _collect_role_errors(node: Node, errors: PackedStringArray) -> void:
	for meta_name in [ROLE_META, SHADOW_ROLE_META]:
		if not node.has_meta(meta_name):
			continue
		var role := str(node.get_meta(meta_name))
		if not UiPaletteScript.has_role(role):
			errors.append("%s: %s \"%s\" is not a palette role" % [get_path_to(node), meta_name, role])
	for child in node.get_children():
		_collect_role_errors(child, errors)


func _role_signature() -> String:
	var parts := PackedStringArray()
	_collect_role_signature(self, parts)
	return "|".join(parts)


func _collect_role_signature(node: Node, parts: PackedStringArray) -> void:
	for meta_name in [ROLE_META, SHADOW_ROLE_META]:
		if node.has_meta(meta_name):
			parts.append("%s.%s=%s" % [get_path_to(node), meta_name, str(node.get_meta(meta_name))])
	for child in node.get_children():
		_collect_role_signature(child, parts)
