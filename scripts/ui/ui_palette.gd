@tool
class_name UiPalette
extends RefCounted
## Palette tables, role lookup, and the shared flat button recipe; @tool so editor previews read the same colors as the game.

## Fixed colors outside the palette tables: pollution never changes them, so they are not roles.
## VOID is the true-black horror backdrop (flashback, prologue, day transition, cinematic bars).
const VOID := Color("000000")
## OUTLINE is the near-black outline under text, 3D markers and labels.
const OUTLINE := Color("050705")
const PALETTE_1 := {
	"name": "palette_1",
	"bg": "B7D957",
	"surface": "FFF1C9",
	"text": "10140F",
	"ink": "10140F",
	"accent": "365B2D",
	"muted": "DDEB8A",
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
	"flash_text": "39FF14",
}


static func palette(palette_key: String) -> Dictionary:
	return POLLUTION_PALETTE_5 if palette_key == "pollution_palette_5" else PALETTE_1


static func has_role(role: String) -> bool:
	return role != "name" and PALETTE_1.has(role)


## A gap in `active` is reported and answered from PALETTE_1; an unknown role is reported and answered black.
static func color(active: Dictionary, role: String) -> Color:
	if not has_role(role):
		push_error("UiPalette: unknown role '%s'" % role)
		return Color.BLACK
	if not active.has(role):
		push_error("UiPalette: palette '%s' has no role '%s'; using palette_1" % [str(active.get("name", "unnamed")), role])
		return Color(str(PALETTE_1[role]))
	return Color(str(active[role]))


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
