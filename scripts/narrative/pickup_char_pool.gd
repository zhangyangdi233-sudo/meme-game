class_name PickupCharPool
extends RefCounted
## 瀑布流拾取字池:三语言各自维护 20-30 个可拾取单位(中文单字/日文单词/英文单词)、
## 合词词典(拾取单位 → 可组成的词与语法角色)、每帖的埋字文案与匿名评论区。
##
## 设计约束(docs/plans/2026-08-17-cowork-rework-plan.md §2.2):
## - 帖子文案必须包含分配给它的可拾取单位;
## - 合词后主语/谓语/宾语词各 ≥2(test_pickup_char_flow 断言);
## - 覆盖规则引擎 MVP 所需词(门/可以/打开/出口/存在/灯/亮/不/没);
## - 本脚本自带三语言文本,不经过 catalog 翻译层。

## 每语言的完整字池。中文一字一单位;日文单词(单一文字系统内);英文单词。
const UNIT_POOLS := {
	"zh": [
		"门", "可", "以", "打", "开", "出", "口", "存", "在", "不",
		"没", "灯", "亮", "我", "你", "家", "回", "名", "字", "声",
		"音", "安", "全", "被", "地", "方", "留", "下", "是", "想",
	],
	"ja": [
		"ドア", "ひらく", "でぐち", "ある", "ない", "でんき", "つく",
		"わたし", "あなた", "いえ", "かえる", "なまえ", "こえ",
		"あんぜん", "ばしょ", "できる", "のこる", "いる", "その", "みち",
	],
	"en": [
		"door", "can", "be", "opened", "open", "exit", "exists", "exist",
		"not", "light", "lit", "is", "I", "you", "home", "name", "voice",
		"safe", "place", "stay", "want", "return", "the", "no",
	],
}

## 合词词典:词 → {units: 组成单位, roles: 语法角色}。
## 角色:subject / verb / object / negation / modal / particle / modifier。
## 一个词可以既作主语又作宾语(如 门、名字)。
const WORD_DICTIONARY := {
	"zh": {
		"门": {"units": ["门"], "roles": ["subject", "object"]},
		"灯": {"units": ["灯"], "roles": ["subject"]},
		"我": {"units": ["我"], "roles": ["subject", "object"]},
		"你": {"units": ["你"], "roles": ["subject", "object"]},
		"出口": {"units": ["出", "口"], "roles": ["subject", "object"]},
		"名字": {"units": ["名", "字"], "roles": ["subject", "object"]},
		"声音": {"units": ["声", "音"], "roles": ["subject", "object"]},
		"家": {"units": ["家"], "roles": ["object"]},
		"地方": {"units": ["地", "方"], "roles": ["object"]},
		"打开": {"units": ["打", "开"], "roles": ["verb"]},
		"开": {"units": ["开"], "roles": ["verb"]},
		"亮": {"units": ["亮"], "roles": ["verb"]},
		"存在": {"units": ["存", "在"], "roles": ["verb"]},
		"在": {"units": ["在"], "roles": ["verb"]},
		"回家": {"units": ["回", "家"], "roles": ["verb"]},
		"留下": {"units": ["留", "下"], "roles": ["verb"]},
		"是": {"units": ["是"], "roles": ["verb"]},
		"想": {"units": ["想"], "roles": ["verb"]},
		"可以": {"units": ["可", "以"], "roles": ["modal"]},
		"不": {"units": ["不"], "roles": ["negation"]},
		"没": {"units": ["没"], "roles": ["negation"]},
		"被": {"units": ["被"], "roles": ["particle"]},
		"安全": {"units": ["安", "全"], "roles": ["modifier"]},
	},
	"ja": {
		"ドア": {"units": ["ドア"], "roles": ["subject", "object"]},
		"でんき": {"units": ["でんき"], "roles": ["subject"]},
		"わたし": {"units": ["わたし"], "roles": ["subject", "object"]},
		"あなた": {"units": ["あなた"], "roles": ["subject", "object"]},
		"でぐち": {"units": ["でぐち"], "roles": ["subject", "object"]},
		"なまえ": {"units": ["なまえ"], "roles": ["subject", "object"]},
		"こえ": {"units": ["こえ"], "roles": ["subject", "object"]},
		"いえ": {"units": ["いえ"], "roles": ["object"]},
		"ばしょ": {"units": ["ばしょ"], "roles": ["object"]},
		"みち": {"units": ["みち"], "roles": ["object"]},
		"ひらく": {"units": ["ひらく"], "roles": ["verb"]},
		"ある": {"units": ["ある"], "roles": ["verb"]},
		"つく": {"units": ["つく"], "roles": ["verb"]},
		"かえる": {"units": ["かえる"], "roles": ["verb"]},
		"のこる": {"units": ["のこる"], "roles": ["verb"]},
		"いる": {"units": ["いる"], "roles": ["verb"]},
		"できる": {"units": ["できる"], "roles": ["modal"]},
		"ない": {"units": ["ない"], "roles": ["negation"]},
		"その": {"units": ["その"], "roles": ["particle"]},
		"あんぜん": {"units": ["あんぜん"], "roles": ["modifier"]},
	},
	"en": {
		"door": {"units": ["door"], "roles": ["subject", "object"]},
		"light": {"units": ["light"], "roles": ["subject", "object"]},
		"I": {"units": ["I"], "roles": ["subject"]},
		"you": {"units": ["you"], "roles": ["subject", "object"]},
		"exit": {"units": ["exit"], "roles": ["subject", "object"]},
		"name": {"units": ["name"], "roles": ["subject", "object"]},
		"voice": {"units": ["voice"], "roles": ["subject", "object"]},
		"home": {"units": ["home"], "roles": ["object"]},
		"place": {"units": ["place"], "roles": ["object"]},
		"open": {"units": ["open"], "roles": ["verb"]},
		"opened": {"units": ["opened"], "roles": ["verb"]},
		"exists": {"units": ["exists"], "roles": ["verb"]},
		"exist": {"units": ["exist"], "roles": ["verb"]},
		"is": {"units": ["is"], "roles": ["verb"]},
		"lit": {"units": ["lit"], "roles": ["verb"]},
		"stay": {"units": ["stay"], "roles": ["verb"]},
		"want": {"units": ["want"], "roles": ["verb"]},
		"return": {"units": ["return"], "roles": ["verb"]},
		"can": {"units": ["can"], "roles": ["modal"]},
		"be": {"units": ["be"], "roles": ["particle"]},
		"not": {"units": ["not"], "roles": ["negation"]},
		"no": {"units": ["no"], "roles": ["negation"]},
		"the": {"units": ["the"], "roles": ["particle"]},
		"safe": {"units": ["safe"], "roles": ["modifier"]},
	},
}

## 每帖埋字:帖 id → {units: {locale: [单位]}, line: {locale: 埋字句},
## comments: [{handle: {locale}, time: String, text: {locale}, units: {locale: [单位]}}]}。
## line 与每条 comment 的文本必须包含各自 units 中的全部单位(测试逐一断言)。
const POST_SEEDS_PATH := "res://content/pickup_post_seeds.json"
const ContentJsonScript = preload("res://framework/content_json.gd")

static func _get_post_seeds(path: String = POST_SEEDS_PATH) -> Dictionary:
	return ContentJsonScript.load_dictionary_cached(path, "PickupCharPool")


static func get_post_ids() -> Array:
	var result: Array = []
	for post_id in _get_post_seeds().keys():
		result.append(post_id)
	return result


static func validate_post_seeds_catalog() -> Dictionary:
	var problems: Array[String] = []
	var seeds := _get_post_seeds()
	if seeds.is_empty():
		problems.append("post seeds catalog is empty")
		return {"ok": false, "problems": problems}
	if seeds.size() != 12:
		problems.append("post seeds catalog should contain twelve posts, got %d" % seeds.size())
	for post_id in seeds.keys():
		var seed: Dictionary = seeds[post_id] as Dictionary
		for field_name in ["units", "line", "comments"]:
			if not seed.has(field_name):
				problems.append("post %s missing %s" % [post_id, field_name])
		for locale in SUPPORTED_LOCALES:
			var line := str((seed.get("line", {}) as Dictionary).get(locale, ""))
			if line.is_empty():
				problems.append("post %s missing pickup line for %s" % [post_id, locale])
	return {"ok": problems.is_empty(), "problems": problems}

const SUPPORTED_LOCALES := ["zh", "ja", "en"]


static func get_unit_pool(locale: String) -> Array:
	return (UNIT_POOLS.get(locale, UNIT_POOLS["zh"]) as Array).duplicate()


static func get_word_dictionary(locale: String) -> Dictionary:
	return (WORD_DICTIONARY.get(locale, WORD_DICTIONARY["zh"]) as Dictionary).duplicate(true)


static func get_post_seed(post_id: String) -> Dictionary:
	return (_get_post_seeds().get(post_id, {}) as Dictionary).duplicate(true)


static func get_post_units(post_id: String, locale: String) -> Array:
	var seed: Dictionary = _get_post_seeds().get(post_id, {})
	var units: Dictionary = seed.get("units", {})
	var result: Array = (units.get(locale, []) as Array).duplicate()
	for comment: Dictionary in seed.get("comments", []):
		for unit in (comment.get("units", {}) as Dictionary).get(locale, []):
			if unit not in result:
				result.append(unit)
	return result


static func get_pickup_line(post_id: String, locale: String) -> String:
	var seed: Dictionary = _get_post_seeds().get(post_id, {})
	return str((seed.get("line", {}) as Dictionary).get(locale, ""))


static func get_comments(post_id: String, locale: String) -> Array:
	var seed: Dictionary = _get_post_seeds().get(post_id, {})
	var result: Array = []
	for comment: Dictionary in seed.get("comments", []):
		result.append({
			"handle": str((comment.get("handle", {}) as Dictionary).get(locale, "")),
			"time": str(comment.get("time", "")),
			"text": str((comment.get("text", {}) as Dictionary).get(locale, "")),
			"units": ((comment.get("units", {}) as Dictionary).get(locale, []) as Array).duplicate(),
		})
	return result


static func is_unit_in_pool(unit: String, locale: String) -> bool:
	return unit in (UNIT_POOLS.get(locale, []) as Array)


## 语法角色计数(按词典合词后)。测试用:主/谓/宾各 ≥2。
static func role_word_counts(locale: String) -> Dictionary:
	var counts := {"subject": 0, "verb": 0, "object": 0, "negation": 0, "modal": 0}
	var dictionary: Dictionary = WORD_DICTIONARY.get(locale, {})
	for word in dictionary.keys():
		for role in (dictionary[word] as Dictionary).get("roles", []):
			if counts.has(role):
				counts[role] = int(counts[role]) + 1
	return counts


## 单位是否以"可拾取形态"出现在文本中。
## 英文:大小写不敏感 + 完整单词边界,与 UI 点击判定共用同一套规则(单一事实源)。
static func contains_pickable_unit(text: String, unit: String, locale: String) -> bool:
	if unit.is_empty():
		return false
	if locale != "en":
		return text.contains(unit)
	var lowered_text := text.to_lower()
	var lowered_unit := unit.to_lower()
	var search_from := 0
	while true:
		var found := lowered_text.find(lowered_unit, search_from)
		if found < 0:
			return false
		var before_ok := found == 0 or not is_word_character(text.substr(found - 1, 1))
		var after_index := found + unit.length()
		var after_ok := after_index >= text.length() or not is_word_character(text.substr(after_index, 1))
		if before_ok and after_ok:
			return true
		search_from = found + 1
	return false


static func is_word_character(character: String) -> bool:
	if character.is_empty():
		return false
	var code := character.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or (code >= 48 and code <= 57) or character == "'"


## 单位是否埋在指定帖子的可拾取内容(埋字句 + 评论)里。
static func is_unit_seeded_in_post(post_id: String, unit: String, locale: String) -> bool:
	var seed: Dictionary = _get_post_seeds().get(post_id, {})
	if seed.is_empty():
		return false
	if contains_pickable_unit(get_pickup_line(post_id, locale), unit, locale):
		return true
	for comment: Dictionary in seed.get("comments", []):
		var comment_text := str((comment.get("text", {}) as Dictionary).get(locale, ""))
		if contains_pickable_unit(comment_text, unit, locale):
			return true
	return false


## 校验:字池的每个单位都被埋进至少一个帖子;每个词典词的组成单位都在字池里;
## 每条埋字文本确实以可拾取形态包含它声明的单位。返回 {ok, problems: Array[String]}。
static func validate(locale: String) -> Dictionary:
	var problems: Array[String] = []
	var pool: Array = UNIT_POOLS.get(locale, [])
	var seeded_units: Array[String] = []
	for post_id in _get_post_seeds().keys():
		var line := get_pickup_line(post_id, locale)
		var line_units: Array = ((_get_post_seeds()[post_id] as Dictionary).get("units", {}) as Dictionary).get(locale, [])
		for unit in line_units:
			if not contains_pickable_unit(line, str(unit), locale):
				problems.append("%s 的埋字句缺少单位 %s (%s)" % [post_id, unit, locale])
			if str(unit) not in seeded_units:
				seeded_units.append(str(unit))
		for comment: Dictionary in (_get_post_seeds()[post_id] as Dictionary).get("comments", []):
			var comment_text := str((comment.get("text", {}) as Dictionary).get(locale, ""))
			for unit in (comment.get("units", {}) as Dictionary).get(locale, []):
				if not contains_pickable_unit(comment_text, str(unit), locale):
					problems.append("%s 的评论缺少单位 %s (%s)" % [post_id, unit, locale])
				if str(unit) not in seeded_units:
					seeded_units.append(str(unit))
	for unit in pool:
		if str(unit) not in seeded_units:
			problems.append("字池单位 %s 没有埋进任何帖子 (%s)" % [unit, locale])
	var dictionary: Dictionary = WORD_DICTIONARY.get(locale, {})
	for word in dictionary.keys():
		for unit in (dictionary[word] as Dictionary).get("units", []):
			if str(unit) not in pool:
				problems.append("词 %s 的组成单位 %s 不在字池里 (%s)" % [word, unit, locale])
	return {"ok": problems.is_empty(), "problems": problems}
