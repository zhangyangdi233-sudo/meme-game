extends RefCounted
## Single snapshot for pollution-driven presentation rules in the main scene adapter.
## Thresholds are intentionally per-channel (see comments); do not unify without test review.

# Music ambience ramps (babel_meme_game._sync_audio_state via music_db).
const MUSIC_QUIET_MAX := 40
const MUSIC_MID_MAX := 60
const MUSIC_HIGH_MAX := 80

# Settings menu copy tiers (settings_history_panel._menu_display_label).
const MENU_MID_MIN := 25
const MENU_CORRUPT_MIN := 60

# Palette swap (matches MemeGameState.POLLUTION_FLASHBACK_THRESHOLD).
const PALETTE_POLLUTED_MIN := 60

# UI text corruption (babel_meme_game._corrupt).
const CORRUPT_MIN := 35
const CORRUPT_INTERVAL_BASE := 8
const CORRUPT_INTERVAL_DIVISOR := 14

# Reality sentence corruption (meme_game_state.pollute_reality_sentence).
# Threshold matches CORRUPT_MIN; interval formula intentionally differs from UI.
const REALITY_CORRUPT_INTERVAL_BASE := 9
const REALITY_CORRUPT_INTERVAL_DIVISOR := 12
const REALITY_SENTENCE_MARKERS := ["■", "□", "▦", "∴", "//", "≠", "…"]

# VHS overlay uses continuous pollution ratios (babel_meme_game._animate_vhs).
const VHS_INTENSITY_BASE := 0.58
const VHS_INTENSITY_SLOPE := 0.0022
const VHS_INTENSITY_CAP := 0.22


static func stage(pollution_value: int, day: int = 0) -> Dictionary:
	var pollution := clampi(pollution_value, 0, 100)
	return {
		"pollution": pollution,
		"day": maxi(0, day),
		"palette_key": _palette_key(pollution),
		"music_db": _music_db(pollution),
		"menu_tier": _menu_tier(pollution),
		"corrupt_active": pollution >= CORRUPT_MIN,
		"corrupt_interval": _corrupt_interval(pollution),
		"vhs_pollution": clampf(float(pollution) / 100.0, 0.0, 1.0),
		"vhs_intensity": VHS_INTENSITY_BASE + minf(VHS_INTENSITY_CAP, float(pollution) * VHS_INTENSITY_SLOPE),
	}


static func _palette_key(pollution: int) -> String:
	if pollution >= PALETTE_POLLUTED_MIN:
		return "pollution_palette_5"
	return "palette_1"


static func _music_db(pollution: int) -> float:
	if pollution <= MUSIC_QUIET_MAX:
		return -60.0
	if pollution <= MUSIC_MID_MAX:
		return remap(float(pollution), float(MUSIC_QUIET_MAX + 1), float(MUSIC_MID_MAX), -42.0, -24.0)
	if pollution <= MUSIC_HIGH_MAX:
		return remap(float(pollution), float(MUSIC_MID_MAX), float(MUSIC_HIGH_MAX), -24.0, -10.0)
	return remap(float(pollution), float(MUSIC_HIGH_MAX), 100.0, -10.0, -3.0)


static func _menu_tier(pollution: int) -> int:
	if pollution < MENU_MID_MIN:
		return 0
	if pollution < MENU_CORRUPT_MIN:
		return 1
	return 2


static func _corrupt_interval(pollution: int) -> int:
	return maxi(2, CORRUPT_INTERVAL_BASE - int(pollution / CORRUPT_INTERVAL_DIVISOR))


static func _reality_corrupt_interval(pollution: int) -> int:
	return maxi(2, REALITY_CORRUPT_INTERVAL_BASE - int(pollution / REALITY_CORRUPT_INTERVAL_DIVISOR))


## UI channel: locale-aware corruption for HUD and phone surfaces (babel_meme_game._corrupt).
## Caller must pass already-translated text and localized replacement tokens.
static func corrupt_sentence_ui(
	text: String,
	pollution_value: int,
	day: int,
	locale: String,
	replacements: Array,
) -> String:
	var snapshot := stage(pollution_value, day)
	if not bool(snapshot.get("corrupt_active", false)):
		return text
	var interval := int(snapshot.get("corrupt_interval", 2))
	if locale == "en":
		return _corrupt_english_words(text, replacements, interval, day)
	return _corrupt_characters(text, replacements, interval, day)


## Reality channel: doctor sentence pollution (meme_game_state.pollute_reality_sentence).
static func corrupt_sentence_reality(sentence: String, pollution_value: int, day: int = 0) -> String:
	if pollution_value < CORRUPT_MIN:
		return sentence
	return _corrupt_characters(sentence, REALITY_SENTENCE_MARKERS, _reality_corrupt_interval(pollution_value), day)


static func _corrupt_characters(text: String, replacements: Array, interval: int, day: int) -> String:
	var result := ""
	for index in text.length():
		var ch := text.substr(index, 1)
		if ch == " ":
			result += ch
		elif index % interval == 0:
			result += str(replacements[(index + day) % replacements.size()])
		else:
			result += ch
	return result


static func _corrupt_english_words(text: String, replacements: Array, interval: int, day: int) -> String:
	var word_regex := RegEx.new()
	word_regex.compile("(\\S+)(\\s*)")
	var units := word_regex.search_all(text)
	if units.is_empty():
		return text
	var result := ""
	for index in units.size():
		var unit := units[index] as RegExMatch
		var word := unit.get_string(1)
		var spacing := unit.get_string(2)
		if index % interval == 0:
			word = str(replacements[(index + day) % replacements.size()])
		result += word + spacing
	return result
