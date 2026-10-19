extends RefCounted
## First-basement onboarding, deliberately separate from the retired guide.

const PHASES := ["post", "collect", "compose", "publish", "complete"]
const UNITS := {"zh": ["门", "打", "开"], "en": ["door", "can", "open"], "ja": ["ドア", "は", "ひらく"]}
const POST_ID := "floor_13"

static func normalize(raw: Variant) -> Dictionary:
	var value: Dictionary = raw if raw is Dictionary else {}
	var locale := str(value.get("locale", "zh"))
	if not UNITS.has(locale):
		locale = "zh"
	var phase := str(value.get("lesson_phase", "post"))
	if phase not in PHASES:
		phase = "post"
	var picked := _known(value.get("collected", []), UNITS[locale])
	var dragged := _known(value.get("dragged", []), picked)
	if phase in ["compose", "publish", "complete"] and picked.size() != 3:
		phase = "collect"
	if phase in ["publish", "complete"] and dragged.size() != 3:
		phase = "compose"
	if phase == "complete" and not _true(value.get("published", false)):
		phase = "publish"
	return {
		"version": 1, "focus_started": _true(value.get("focus_started", false)),
		"focus_done": _true(value.get("focus_done", false)),
		"focus_line": clampi(int(_number(value.get("focus_line", 1), 1.0)), 1, 7),
		"focus_pose": _numbers(value.get("focus_pose", []), 12),
		"focus_player": _numbers(value.get("focus_player", []), 3),
		"focus_fov": clampf(_number(value.get("focus_fov", 58.0), 58.0), 30.0, 100.0),
		"lesson_phase": phase, "locale": locale,
		"collected": picked, "dragged": dragged, "published": phase == "complete",
	}

static func teaching_units(locale: String) -> Array:
	return (UNITS.get(locale, UNITS.zh) as Array).duplicate()

static func _true(value: Variant) -> bool:
	return value is bool and value

static func _number(value: Variant, fallback: float) -> float:
	return float(value) if (value is float or value is int) and is_finite(float(value)) else fallback

static func _known(raw: Variant, allowed: Array) -> Array:
	var result: Array = []
	if raw is Array:
		for item in raw:
			if item is String and item in allowed and item not in result:
				result.append(item)
	return result

static func _numbers(raw: Variant, length: int) -> Array:
	if not raw is Array or raw.size() != length:
		return []
	for value in raw:
		if not (value is float or value is int) or not is_finite(float(value)):
			return []
	return raw.duplicate()
