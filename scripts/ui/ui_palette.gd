@tool
class_name UiPalette
extends RefCounted
## Palette tables, role lookup, and the shared flat button recipe; @tool so editor previews read the same colors as the game.

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
	"menu_bg": "5DAE6B",
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
	"menu_bg": "9CFF24",
}


static func palette(palette_key: String) -> Dictionary:
	return POLLUTION_PALETTE_5 if palette_key == "pollution_palette_5" else PALETTE_1


static func has_role(role: String) -> bool:
	return role != "name" and PALETTE_1.has(role)


static func color(active: Dictionary, role: String) -> Color:
	return Color(str(active.get(role, PALETTE_1.get(role, "FFF1C9"))))


static func flat_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style_box := StyleBoxFlat.new()
	style_box.bg_color = bg
	style_box.border_color = border
	style_box.set_border_width_all(1)
	style_box.set_corner_radius_all(5)
	style_box.set_content_margin_all(10)
	return style_box


static func apply_button_style(button: Button, active: Dictionary) -> void:
	var surface := color(active, "surface")
	var ink := color(active, "ink")
	var accent := color(active, "accent")
	var muted := color(active, "muted")
	button.add_theme_color_override("font_color", ink)
	button.add_theme_color_override("font_hover_color", ink)
	button.add_theme_color_override("font_pressed_color", surface)
	button.add_theme_color_override("font_disabled_color", accent.lightened(0.22))
	button.add_theme_stylebox_override("normal", flat_style(surface, accent))
	button.add_theme_stylebox_override("hover", flat_style(muted, ink))
	button.add_theme_stylebox_override("pressed", flat_style(accent, ink))
	button.add_theme_stylebox_override("disabled", flat_style(surface.darkened(0.10), accent.lightened(0.20)))
