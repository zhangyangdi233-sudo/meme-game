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
