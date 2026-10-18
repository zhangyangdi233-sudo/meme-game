class_name LocaleFont
extends RefCounted
## The formal typeface each game language uses where the pixel font is not: the Dialog and the main menu's
## hold to restart hint. English is Roboto Condensed Bold, Simplified Chinese Noto Sans SC Medium, and Japanese
## Noto Sans JP Medium, so Japanese kanji keep their Japanese shapes. A locale outside the table uses the default
## language's face. English falls back to the Simplified Chinese face for Han text it cannot draw, such as a line with
## no catalog entry left in its source language. Each language's font is built once and reused.
## Sources and licenses: assets/fonts/FONT_PROVENANCE.md.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")

const ROBOTO_CONDENSED_PATH := "res://assets/fonts/RobotoCondensed-VariableFont_wght.ttf"
const NOTO_SANS_SC_PATH := "res://assets/fonts/NotoSansSC-Medium.otf"
const NOTO_SANS_JP_PATH := "res://assets/fonts/NotoSansJP-Medium.otf"
const KEY_PATH := "path"
const KEY_WEIGHT := "weight"
const KEY_FALLBACK := "fallback"
## Per locale: the font file, the weight-axis value to set (zero keeps the file's own weight), and optionally the
## locale whose face draws the glyphs this one lacks.
const FACES := {
	"en": {KEY_PATH: ROBOTO_CONDENSED_PATH, KEY_WEIGHT: 700, KEY_FALLBACK: "zh"},
	"zh": {KEY_PATH: NOTO_SANS_SC_PATH, KEY_WEIGHT: 0},
	"ja": {KEY_PATH: NOTO_SANS_JP_PATH, KEY_WEIGHT: 0},
}

static var _built: Dictionary = {}


static func font(locale_code: String) -> Font:
	var key := locale_code if FACES.has(locale_code) else PropertyKeysScript.DEFAULT_LOCALE
	if not _built.has(key):
		var built := _build(FACES[key])
		var fallback := str(FACES[key].get(KEY_FALLBACK, ""))
		if built != null and not fallback.is_empty():
			built.fallbacks = [font(fallback)]
		_built[key] = built
	return _built[key]


static func _build(face: Dictionary) -> Font:
	var file := load(str(face[KEY_PATH])) as FontFile
	var weight := int(face[KEY_WEIGHT])
	if file == null or weight <= 0:
		return file
	var instance := FontVariation.new()
	instance.base_font = file
	instance.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return instance
