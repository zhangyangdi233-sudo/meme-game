extends RefCounted
class_name GameUiTheme
## Palette, pixel-font theme, panel factories, and control-tree styling for the main scene adapter.

const PixelFontThemeScript = preload("res://framework/ui/pixel_font_theme.gd")

const PALETTE_1 := {
	"name": "palette_1",
	"bg": "B7D957",
	"surface": "FFF1C9",
	"text": "10140F",
	"ink": "10140F",
	"accent": "365B2D",
	"muted": "DDEB8A",
	"danger_stripe": "10140F",
	"flash_text": "9CFF24",
}
const POLLUTION_PALETTE_5 := {
	"name": "pollution_palette_5",
	"bg": "9CFF24",
	"surface": "FFF2B8",
	"text": "0D1009",
	"ink": "0D1009",
	"accent": "2F6B1F",
	"muted": "D8FF66",
	"danger_stripe": "0D1009",
	"flash_text": "39FF14",
}

var ui_font_path := "res://assets/fonts/BoutiqueBitmap9x9.ttf"
var ui_font_grid := 9
var ui_font_min_size := 9
var ui_font_max_size := 45

var _ui_theme: Theme
var _locale_translate: Callable = Callable()
var _pollution_stage_fn: Callable = Callable()


func configure(deps: Dictionary) -> void:
	ui_font_path = str(deps.get("ui_font_path", ui_font_path))
	ui_font_grid = int(deps.get("ui_font_grid", ui_font_grid))
	ui_font_min_size = int(deps.get("ui_font_min_size", ui_font_min_size))
	ui_font_max_size = int(deps.get("ui_font_max_size", ui_font_max_size))
	_locale_translate = deps.get("locale_translate", Callable())
	_pollution_stage_fn = deps.get("pollution_stage", Callable())


func current_pollution_stage() -> Dictionary:
	return _pollution_stage_fn.call() if _pollution_stage_fn.is_valid() else {}


func _stage(pollution_stage = null) -> Dictionary:
	if pollution_stage == null:
		return current_pollution_stage()
	return pollution_stage


func active_palette(pollution_stage = null) -> Dictionary:
	if str(_stage(pollution_stage).get("palette_key", "palette_1")) == "pollution_palette_5":
		return POLLUTION_PALETTE_5
	return PALETTE_1


func theme_color(key: String, pollution_stage = null) -> Color:
	var palette := active_palette(_stage(pollution_stage))
	return Color(str(palette.get(key, PALETTE_1.get(key, "FFF1C9"))))


func ensure_ui_font_theme() -> Theme:
	if _ui_theme != null:
		return _ui_theme
	_ui_theme = PixelFontThemeScript.build(ui_font_path, ui_font_grid)
	return _ui_theme


func ui_font_size(requested_size: int) -> int:
	return PixelFontThemeScript.snap_size(requested_size, ui_font_grid, ui_font_min_size, ui_font_max_size)


func apply_ui_font_theme(target: Control) -> void:
	PixelFontThemeScript.apply(target, ensure_ui_font_theme())


func panel(pollution_stage = null) -> PanelContainer:
	var stage := _stage(pollution_stage)
	var panel_node := PanelContainer.new()
	panel_node.add_theme_stylebox_override("panel", style(theme_color("surface", stage), theme_color("accent", stage)))
	return panel_node


func wrap(node: Control, pollution_stage = null) -> PanelContainer:
	var panel_node := panel(_stage(pollution_stage))
	panel_node.add_child(node)
	return panel_node


func label(text: String, size: int, color: Color) -> Label:
	var label_node := Label.new()
	label_node.text = text
	set_localized_property(label_node, "text")
	label_node.add_theme_font_size_override("font_size", ui_font_size(size))
	label_node.add_theme_color_override("font_color", color)
	return label_node


func refresh_localized_ui(ui_root: Control) -> void:
	if ui_root == null or not is_instance_valid(ui_root):
		return
	localize_control_tree(ui_root)


func localize_control_tree(node: Node) -> void:
	if node is Control and not bool(node.get_meta("skip_localization", false)):
		var control := node as Control
		if control is Label or control is Button:
			set_localized_property(control, "text")
		if control is LineEdit:
			set_localized_property(control, "placeholder_text")
		set_localized_property(control, "tooltip_text")
	for child in node.get_children():
		localize_control_tree(child)


func set_localized_property(control: Control, property_name: String) -> void:
	if control == null:
		return
	if control.has_meta("skip_localization"):
		return
	var current_text := str(control.get(property_name))
	if current_text.is_empty():
		return
	var source_meta := "locale_source_%s" % property_name
	var last_meta := "locale_last_%s" % property_name
	var source_text := str(control.get_meta(source_meta, ""))
	var last_text := str(control.get_meta(last_meta, ""))
	if source_text.is_empty() or current_text != last_text:
		source_text = current_text
		control.set_meta(source_meta, source_text)
	var localized_text := source_text
	if _locale_translate.is_valid():
		localized_text = _locale_translate.call(source_text)
	control.set(property_name, localized_text)
	control.set_meta(last_meta, localized_text)


func style(bg: Color, border: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = border
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(5)
	style_box.set_content_margin_all(10)
	return style_box


func soft_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = Color(bg, 0.94)
	style_box.border_color = Color(border, 0.24)
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(16)
	style_box.set_content_margin_all(16)
	return style_box


func phone_shell_style(pollution_stage: Dictionary) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = theme_color("ink", pollution_stage)
	style_box.border_color = theme_color("ink", pollution_stage)
	style_box.set_border_width_all(6)
	style_box.set_corner_radius_all(24)
	style_box.set_content_margin_all(6)
	return style_box


func phone_surface_style(pollution_stage: Dictionary) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = theme_color("surface", pollution_stage)
	style_box.border_color = theme_color("surface", pollution_stage)
	style_box.set_border_width_all(0)
	style_box.set_corner_radius_all(16)
	style_box.set_content_margin_all(10)
	return style_box


func launcher_app_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = border
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.set_content_margin_all(12)
	return style_box


func window_close_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = border
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(4)
	style_box.set_content_margin_all(4)
	return style_box


func reward_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = border
	style_box.set_border_width_all(2)
	style_box.set_corner_radius_all(6)
	style_box.set_content_margin_all(12)
	return style_box


func poster_frame_style(pollution_stage: Dictionary) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = theme_color("muted", pollution_stage)
	style_box.border_color = Color(theme_color("ink", pollution_stage), 0.65)
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(8)
	style_box.set_content_margin_all(0)
	return style_box


func flat_button_state_style(bg: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = Color(bg, 0.0)
	style_box.set_border_width_all(0)
	style_box.set_corner_radius_all(10)
	style_box.set_content_margin_all(4)
	return style_box


func composer_tile_style(kind: String, pollution_stage = null) -> StyleBoxFlat:
	var stage := _stage(pollution_stage)
	var style_box := StyleBoxFlat.new()
	style_box.set_corner_radius_all(10)
	style_box.content_margin_left = 10.0
	style_box.content_margin_right = 10.0
	style_box.content_margin_top = 5.0
	style_box.content_margin_bottom = 7.0
	match kind:
		"pressed":
			style_box.bg_color = theme_color("surface", stage).darkened(0.05)
			style_box.border_color = Color(theme_color("accent", stage), 0.9)
			style_box.set_border_width_all(1)
			style_box.content_margin_top = 7.0
			style_box.content_margin_bottom = 5.0
		"ghost":
			style_box.bg_color = Color(theme_color("muted", stage), 0.30)
			style_box.border_color = Color(theme_color("accent", stage), 0.22)
			style_box.set_border_width_all(1)
		_:
			style_box.bg_color = theme_color("surface", stage)
			style_box.border_color = Color(theme_color("accent", stage), 0.55)
			style_box.set_border_width_all(1)
			style_box.border_width_bottom = 3
	return style_box


func apply_composer_tile_theme(tile: Button, is_ghost: bool, pollution_stage = null) -> void:
	var stage := _stage(pollution_stage)
	if is_ghost:
		tile.add_theme_stylebox_override("normal", composer_tile_style("ghost", stage))
		tile.add_theme_stylebox_override("disabled", composer_tile_style("ghost", stage))
		return
	tile.add_theme_stylebox_override("normal", composer_tile_style("normal", stage))
	tile.add_theme_stylebox_override("hover", composer_tile_style("normal", stage))
	tile.add_theme_stylebox_override("pressed", composer_tile_style("pressed", stage))


func apply_ui_theme(node: Node, pollution_stage = null) -> void:
	if node == null:
		return
	pollution_stage = _stage(pollution_stage)
	if node is Label and not node.has_meta("flashback_text") and not node.has_meta("action_overlay_text"):
		if node.has_meta("hud_action_label"):
			(node as Label).add_theme_color_override("font_color", theme_color("muted", pollution_stage))
		elif node.has_meta("on_dark"):
			(node as Label).add_theme_color_override("font_color", theme_color("surface", pollution_stage))
		else:
			(node as Label).add_theme_color_override("font_color", theme_color("ink", pollution_stage))
	elif node is Button:
		var button := node as Button
		if button.has_meta("hud_icon"):
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override("normal", empty)
			button.add_theme_stylebox_override("hover", style(Color(theme_color("muted", pollution_stage), 0.18), Color(theme_color("muted", pollution_stage), 0.20)))
			button.add_theme_stylebox_override("pressed", style(Color(theme_color("muted", pollution_stage), 0.32), Color(theme_color("muted", pollution_stage), 0.32)))
		elif button.has_meta("phone_app_icon"):
			button.add_theme_color_override("font_color", theme_color("surface", pollution_stage))
			button.add_theme_color_override("font_hover_color", theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_pressed_color", theme_color("ink", pollution_stage))
			button.add_theme_font_size_override("font_size", ui_font_size(18))
			button.add_theme_stylebox_override("normal", launcher_app_style(theme_color("ink", pollution_stage), theme_color("muted", pollution_stage)))
			button.add_theme_stylebox_override("hover", launcher_app_style(theme_color("muted", pollution_stage), theme_color("ink", pollution_stage)))
			button.add_theme_stylebox_override("pressed", launcher_app_style(theme_color("bg", pollution_stage), theme_color("ink", pollution_stage)))
		elif button.has_meta("dark_window_close_button"):
			button.add_theme_color_override("font_color", theme_color("surface", pollution_stage))
			button.add_theme_color_override("font_hover_color", theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_pressed_color", theme_color("ink", pollution_stage))
			button.add_theme_stylebox_override("normal", window_close_style(Color(theme_color("ink", pollution_stage), 0.0), theme_color("muted", pollution_stage)))
			button.add_theme_stylebox_override("hover", window_close_style(theme_color("muted", pollution_stage), theme_color("surface", pollution_stage)))
			button.add_theme_stylebox_override("pressed", window_close_style(theme_color("surface", pollution_stage), theme_color("surface", pollution_stage)))
		elif button.has_meta("window_close_button"):
			button.add_theme_color_override("font_color", theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_hover_color", theme_color("surface", pollution_stage))
			button.add_theme_color_override("font_pressed_color", theme_color("surface", pollution_stage))
			button.add_theme_stylebox_override("normal", window_close_style(Color(theme_color("surface", pollution_stage), 0.0), theme_color("accent", pollution_stage)))
			button.add_theme_stylebox_override("hover", window_close_style(theme_color("ink", pollution_stage), theme_color("ink", pollution_stage)))
			button.add_theme_stylebox_override("pressed", window_close_style(theme_color("accent", pollution_stage), theme_color("ink", pollution_stage)))
		elif button.has_meta("notebook_browser_tab"):
			var tab_active := bool(button.get_meta("active_tab", false))
			button.add_theme_color_override("font_color", theme_color("surface", pollution_stage) if tab_active else theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_hover_color", theme_color("ink", pollution_stage))
			button.add_theme_stylebox_override("normal", style(theme_color("ink", pollution_stage) if tab_active else Color(theme_color("surface", pollution_stage), 0.72), theme_color("accent", pollution_stage)))
			button.add_theme_stylebox_override("hover", style(theme_color("muted", pollution_stage), theme_color("ink", pollution_stage)))
			button.add_theme_stylebox_override("pressed", style(theme_color("accent", pollution_stage), theme_color("ink", pollution_stage)))
		elif button.has_meta("flat_phone_button"):
			var flat := StyleBoxEmpty.new()
			button.add_theme_color_override("font_color", theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_hover_color", theme_color("accent", pollution_stage))
			button.add_theme_color_override("font_pressed_color", theme_color("ink", pollution_stage))
			button.add_theme_stylebox_override("normal", flat)
			button.add_theme_stylebox_override("hover", flat_button_state_style(Color(theme_color("muted", pollution_stage), 0.24)))
			button.add_theme_stylebox_override("pressed", flat_button_state_style(Color(theme_color("muted", pollution_stage), 0.40)))
		else:
			button.add_theme_color_override("font_color", theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_hover_color", theme_color("ink", pollution_stage))
			button.add_theme_color_override("font_pressed_color", theme_color("surface", pollution_stage))
			button.add_theme_color_override("font_disabled_color", theme_color("accent", pollution_stage).lightened(0.22))
			button.add_theme_stylebox_override("normal", style(theme_color("surface", pollution_stage), theme_color("accent", pollution_stage)))
			button.add_theme_stylebox_override("hover", style(theme_color("muted", pollution_stage), theme_color("ink", pollution_stage)))
			button.add_theme_stylebox_override("pressed", style(theme_color("accent", pollution_stage), theme_color("ink", pollution_stage)))
			button.add_theme_stylebox_override("disabled", style(theme_color("surface", pollution_stage).darkened(0.10), theme_color("accent", pollution_stage).lightened(0.20)))
	elif node is PanelContainer:
		if node.has_meta("phone_shell"):
			(node as PanelContainer).add_theme_stylebox_override("panel", phone_shell_style(pollution_stage))
		elif node.has_meta("movie_subtitle"):
			(node as PanelContainer).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		elif node.has_meta("portrait_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", reward_card_style(theme_color("ink", pollution_stage), theme_color("muted", pollution_stage)))
		elif node.has_meta("phone_surface"):
			(node as PanelContainer).add_theme_stylebox_override("panel", phone_surface_style(pollution_stage))
		elif node.has_meta("poster_frame"):
			(node as PanelContainer).add_theme_stylebox_override("panel", poster_frame_style(pollution_stage))
		elif node.has_meta("dark_rail"):
			(node as PanelContainer).add_theme_stylebox_override("panel", style(theme_color("ink", pollution_stage), Color(theme_color("muted", pollution_stage), 0.22)))
		elif node.has_meta("tooltip_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", style(theme_color("muted", pollution_stage), theme_color("accent", pollution_stage)))
		elif node.has_meta("soft_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", soft_style(theme_color("surface", pollution_stage), theme_color("accent", pollution_stage)))
		else:
			var panel_node := node as PanelContainer
			if not panel_node.has_theme_stylebox_override("panel"):
				panel_node.add_theme_stylebox_override("panel", style(theme_color("surface", pollution_stage), theme_color("accent", pollution_stage)))
	elif node is LineEdit:
		var edit := node as LineEdit
		edit.add_theme_color_override("font_color", theme_color("ink", pollution_stage))
		edit.add_theme_color_override("font_placeholder_color", theme_color("accent", pollution_stage))
		edit.add_theme_stylebox_override("normal", style(theme_color("surface", pollution_stage), theme_color("accent", pollution_stage)))
	for child in node.get_children():
		apply_ui_theme(child, pollution_stage)
