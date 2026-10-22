class_name FloorLook
extends RefCounted
## The colors of the 3D street: material roles, the environment's background / ambient / fog,
## light colors and fixed tints, by floor (1 to 4), district style and UI palette.
## RealityFloorGenerator asks here for every color; this script is the only place they are decided
## (Color.WHITE on character art means "untinted" and stays in the generator).
##
## A color entry picks a base and may blend it toward a palette role:
## - "base": a hex color; "styles" / "floors" replace it for a district style or a floor (style wins).
## - "toward" + "weight": blend the base that far toward that palette role.
## - "shade": a palette role used directly, "darken" / "lighten" by an amount.

const UiPaletteScript = preload("res://scripts/ui/ui_palette.gd")

## A role not listed here is painted the palette's muted color.
const MATERIALS := {
	"brick": {"base": "D7B77F", "toward": "surface", "weight": 0.12},
	"brick_light": {"base": "E8CEA0", "toward": "surface", "weight": 0.10},
	"brick_dark": {"base": "8F7655", "toward": "accent", "weight": 0.08},
	"white_wall": {"base": "9DA99C", "floors": {3: "DCE4D2"}, "styles": {"night_white_blocks": "F0F2E9"}},
	"window": {"base": "0B0D0B", "toward": "ink", "weight": 0.35},
	"grass": {"base": "4F7134", "floors": {3: "5F8D3E"}, "styles": {"night_white_blocks": "17321D"}, "toward": "accent", "weight": 0.12},
	"grass_ground": {"base": "527D42", "toward": "accent", "weight": 0.10},
	"gallery_floor": {"base": "68756B", "floors": {3: "819978"}, "toward": "accent", "weight": 0.08},
	"sunlit_paving": {"base": "D7C8A8", "toward": "surface", "weight": 0.16},
	"night_path": {"base": "151613", "toward": "ink", "weight": 0.42},
	"crosswalk": {"base": "F3E8CD", "toward": "surface", "weight": 0.24},
	"lamp": {"base": "22241F", "toward": "ink", "weight": 0.35},
	"lamp_light": {"base": "E4D6A0", "styles": {"night_white_blocks": "FFBE58"}},
	"ground": {"shade": "ink", "lighten": 0.055},
	"road": {"shade": "accent", "darken": 0.54},
	"sidewalk": {"shade": "bg", "darken": 0.36},
	"lot_floor": {"shade": "accent", "darken": 0.30},
	"floor": {"shade": "accent", "darken": 0.38},
	"floor_alt": {"shade": "accent", "darken": 0.24},
	"wall": {"shade": "bg", "darken": 0.38},
	"wall_dark": {"shade": "ink", "lighten": 0.035},
	"ceiling": {"shade": "surface", "darken": 0.58},
	"accent": {"shade": "accent", "darken": 0.10},
	"item": {"shade": "flash_text"},
	"backrooms_beige": {"base": "E0D6A7", "floors": {2: "CBBE8E"}},
	"fixture_metal": {"base": "9AA79A", "floors": {2: "69746D"}},
	"cart_metal": {"base": "7D8D80", "floors": {2: "4F5A54"}},
	"chair_metal": {"base": "A8B6A9", "floors": {2: "758079"}},
	"chair_vinyl": {"base": "6E8B72", "floors": {2: "485C50"}},
	"pipe_metal": {"base": "8CA392", "floors": {2: "60736B"}},
	"machine_green": {"base": "688E69", "floors": {2: "3B5A48"}},
	"cooler_blue": {"base": "8FC9C1", "floors": {2: "538A8C"}},
	"indicator_red": {"base": "C86A76", "floors": {2: "8F4050"}},
	"screen_glow": {"base": "B5DBAA", "floors": {2: "6E9A7D"}},
	"fluorescent": {"base": "F0F3CB", "floors": {2: "D7E7AF"}},
	"crate_wood": {"base": "A68B5C", "floors": {2: "725B3F"}},
	"crate_dark": {"base": "65563B", "floors": {2: "3E3529"}},
	"rubber_black": {"base": "111614"},
	"dream_pink": {"base": "B75A82", "floors": {3: "F3A7BD"}},
	"dream_cyan": {"base": "4C918D", "floors": {3: "A8E1D3"}},
	"dream_ivory": {"base": "A99775", "floors": {3: "FFF0BF"}},
}
const UNLISTED_MATERIAL := {"shade": "muted"}

## Background, ambient light and fog. A floor in "floors" has its own color; the first floor and
## the later floors otherwise pick by district style, "" being any other style.
const ENVIRONMENT := {
	"background": {
		"floors": {
			2: {"base": "030607", "toward": "ink", "weight": 0.08},
			3: {"base": "82B9B0", "toward": "surface", "weight": 0.10},
		},
		"first_floor": {
			"sunlit_brick_street": {"base": "1479B8", "toward": "accent", "weight": 0.10},
			"night_white_blocks": {"base": "10090B", "toward": "ink", "weight": 0.22},
			"overgrown_gallery": {"base": "D4DDD0", "toward": "muted", "weight": 0.18},
			"": {"shade": "ink"},
		},
		"later_floors": {
			"night_white_blocks": {"base": "0B1112", "toward": "ink", "weight": 0.14},
			"overgrown_gallery": {"base": "202923", "toward": "ink", "weight": 0.14},
			"": {"base": "263A42", "toward": "ink", "weight": 0.12},
		},
	},
	"ambient": {
		"floors": {
			2: {"base": "55716B", "toward": "muted", "weight": 0.08},
			3: {"base": "E1EBCF", "toward": "surface", "weight": 0.12},
		},
		"first_floor": {
			"night_white_blocks": {"base": "AEB8A2", "toward": "muted", "weight": 0.18},
			"overgrown_gallery": {"base": "F3F2DD", "toward": "surface", "weight": 0.24},
			"": {"base": "FFE4B8", "toward": "surface", "weight": 0.18},
		},
		"later_floors": {
			"night_white_blocks": {"base": "89A096", "toward": "muted", "weight": 0.12},
			"overgrown_gallery": {"base": "7A8A7D", "toward": "muted", "weight": 0.10},
			"": {"base": "9FB4BC", "toward": "muted", "weight": 0.12},
		},
	},
	"fog": {
		"floors": {
			2: {"base": "111A19", "toward": "ink", "weight": 0.10},
			3: {"base": "B5D4B4", "toward": "surface", "weight": 0.10},
		},
		"first_floor": {
			"night_white_blocks": {"base": "23181A", "toward": "accent", "weight": 0.10},
			"overgrown_gallery": {"base": "C9D6C0", "toward": "muted", "weight": 0.20},
			"": {"base": "7DB5C2", "toward": "accent", "weight": 0.12},
		},
		"later_floors": {
			"night_white_blocks": {"base": "202B2A", "toward": "accent", "weight": 0.06},
			"overgrown_gallery": {"base": "39463D", "toward": "accent", "weight": 0.08},
			"": {"base": "607780", "toward": "accent", "weight": 0.08},
		},
	},
}


## Light colors by use. "material" lights glow in that material role's color.
const LIGHTS := {
	# Floors run 1 to 4 (the generator clamps), so the key light's base is floor 4's.
	"key": {"base": "A9BBC4", "floors": {1: "FFF3D3", 2: "78918C", 3: "FFF4CB"}},
	"memory": {"base": "91B99A", "floors": {3: "D9FFB5", 4: "D9FFB5"}},
	"threshold": {"base": "FFF1C9"},
	"suspense": {"base": "9DB9B4"},
	"suspense_warm": {"base": "D0A572"},
	"disc_pool": {"base": "668783"},
	"disc_pool_warm": {"base": "B07B55"},
	"street_lamp": {"base": "FFB54A"},
	"dead_sign": {"material": "fluorescent"},
	"item_glow": {"material": "item"},
}


## Fixed tints that no palette changes: sprites, the disc path glow and the face scribble ink.
const TINTS := {
	"claimed_doll": Color(0.82, 0.90, 0.82, 1.0),
	"cover_watcher": Color(0.76, 0.86, 0.58, 0.92),
	"distant_mirage": Color(0.82, 0.92, 0.64, 1.0),
	"disc_path_glow": Color("28453A"),
	"face_scribble_ink": Color("020202"),
}
## Grass blades cycle through this many brightness shades.
const GRASS_BLADE_SHADES := 6

static func material_color(role: String, floor_number: int, district_style: String, palette: Dictionary) -> Color:
	return _resolve(MATERIALS.get(role, UNLISTED_MATERIAL), floor_number, district_style, palette)


## `use` is "background", "ambient" or "fog".
static func environment_color(use: String, floor_number: int, district_style: String, palette: Dictionary) -> Color:
	if not ENVIRONMENT.has(use):
		push_error("FloorLook: unknown environment use '%s'" % use)
		return Color.BLACK
	var table: Dictionary = ENVIRONMENT[use]
	var floors: Dictionary = table["floors"]
	if floors.has(floor_number):
		return _resolve(floors[floor_number], floor_number, district_style, palette)
	var by_style: Dictionary = table["later_floors"] if floor_number >= 2 else table["first_floor"]
	return _resolve(by_style.get(district_style, by_style[""]), floor_number, district_style, palette)


## `use` names the light: "key", "memory", "threshold", "suspense", "suspense_warm", "disc_pool",
## "disc_pool_warm", "street_lamp", "dead_sign" or "item_glow".
static func light_color(use: String, floor_number: int, district_style: String, palette: Dictionary) -> Color:
	if not LIGHTS.has(use):
		push_error("FloorLook: unknown light '%s'" % use)
		return Color.WHITE
	var entry: Dictionary = LIGHTS[use]
	if entry.has("material"):
		return material_color(str(entry["material"]), floor_number, district_style, palette)
	return _resolve(entry, floor_number, district_style, palette)


## `use` is a key of TINTS. The distant mirage's alpha is set per layer by the caller.
static func tint(use: String) -> Color:
	if not TINTS.has(use):
		push_error("FloorLook: unknown tint '%s'" % use)
		return Color.WHITE
	return TINTS[use]


## The vertex color of a grass blade; `variant` wraps around GRASS_BLADE_SHADES.
static func grass_blade_tint(variant: int) -> Color:
	var brightness := 0.80 + float(posmod(variant, GRASS_BLADE_SHADES)) * 0.035
	return Color(brightness, 0.92 + (brightness - 0.8) * 0.25, 0.72, 1.0)


static func _resolve(entry: Dictionary, floor_number: int, district_style: String, palette: Dictionary) -> Color:
	if entry.has("shade"):
		var shade := UiPaletteScript.color(palette, str(entry["shade"]))
		if entry.has("darken"):
			return shade.darkened(float(entry["darken"]))
		if entry.has("lighten"):
			return shade.lightened(float(entry["lighten"]))
		return shade
	var base := str(entry["base"])
	var floors: Dictionary = entry.get("floors", {})
	var styles: Dictionary = entry.get("styles", {})
	if styles.has(district_style):
		base = str(styles[district_style])
	elif floors.has(floor_number):
		base = str(floors[floor_number])
	if entry.has("toward"):
		return Color(base).lerp(UiPaletteScript.color(palette, str(entry["toward"])), float(entry["weight"]))
	return Color(base)
