class_name LocaleFont
extends RefCounted
## The formal typeface each game language uses where the pixel font is not: the Dialog and the main menu's
## hold to restart hint. English is Roboto Condensed Bold, Simplified Chinese Noto Sans SC Medium, and Japanese
## Noto Sans JP Medium, so Japanese kanji keep their Japanese shapes. A locale outside the table uses the default
## language's face. Each language's font is built once and reused. Sources and licenses: assets/fonts/FONT_PROVENANCE.md.

const PropertyKeysScript = preload("res://scripts/property_keys.gd")

const ROBOTO_CONDENSED_PATH := "res://assets/fonts/RobotoCondensed-VariableFont_wght.ttf"
const NOTO_SANS_SC_PATH := "res://assets/fonts/NotoSansSC-Medium.otf"
const NOTO_SANS_JP_PATH := "res://assets/fonts/NotoSansJP-Medium.otf"
const KEY_PATH := "path"
const KEY_WEIGHT := "weight"
## Per locale: the font file and the weight-axis value to set; zero keeps the file's own weight.
const FACES := {
	"en": {KEY_PATH: ROBOTO_CONDENSED_PATH, KEY_WEIGHT: 700},
	"zh": {KEY_PATH: NOTO_SANS_SC_PATH, KEY_WEIGHT: 0},
	"ja": {KEY_PATH: NOTO_SANS_JP_PATH, KEY_WEIGHT: 0},
}

static var _built: Dictionary = {}


static func font(locale_code: String) -> Font:
	var key := locale_code if FACES.has(locale_code) else PropertyKeysScript.DEFAULT_LOCALE
	if not _built.has(key):
		_built[key] = _build(FACES[key])
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
