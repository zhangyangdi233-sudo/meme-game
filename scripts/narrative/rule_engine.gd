class_name RuleEngine
extends RefCounted
## 句子规则引擎:把玩家自由拼装的单位序列解析成"世界规则"。
##
## 架构依据 docs/research/sentence_rules_deep_research.md:
## - Baba Is You 三件套:规则=规范式字符串数据、世界侧查表生效、变更即全量重算;
## - 受控词库(20-30 单位)下用「词典最大匹配合词 → 主语×谓语×极性」槽匹配,零机器学习;
## - 语序宽容(中文"门可以打开"与"打开门"同判),否定词是最强单字算子(《文字游戏》);
## - 三层响应:rule(命中)/ misread(世界误读)/ noise(噪声),任何投稿都有反馈。

## MVP 支持的规则组合(规范式 subject|predicate)。
const SUPPORTED_RULES := {
	"door|can_open": {"zh": "门可以打开", "ja": "ドアがひらく", "en": "the door can open"},
	"exit|exists": {"zh": "出口存在", "ja": "でぐちがある", "en": "the exit exists"},
	"light|lit": {"zh": "灯亮", "ja": "でんきがつく", "en": "the light is lit"},
}

## 词 → 规范主语。
const SUBJECT_CANON := {
	"zh": {"门": "door", "出口": "exit", "灯": "light", "我": "self", "你": "other", "名字": "name", "声音": "voice", "家": "home", "地方": "place"},
	"ja": {"ドア": "door", "でぐち": "exit", "でんき": "light", "わたし": "self", "あなた": "other", "なまえ": "name", "こえ": "voice", "いえ": "home", "ばしょ": "place", "みち": "place"},
	"en": {"door": "door", "exit": "exit", "light": "light", "I": "self", "you": "other", "name": "name", "voice": "voice", "home": "home", "place": "place"},
}

## 词 → 规范谓语。
const PREDICATE_CANON := {
	"zh": {"打开": "can_open", "开": "can_open", "亮": "lit", "存在": "exists", "在": "exists", "回家": "return_home", "留下": "stay", "是": "is", "想": "want"},
	"ja": {"ひらく": "can_open", "つく": "lit", "ある": "exists", "いる": "exists", "かえる": "return_home", "のこる": "stay"},
	"en": {"open": "can_open", "opened": "can_open", "lit": "lit", "exists": "exists", "exist": "exists", "is": "is", "stay": "stay", "want": "want", "return": "return_home"},
}

const NEGATION_WORDS := {
	"zh": ["不", "没"],
	"ja": ["ない"],
	"en": ["not", "no"],
}


## 词典最大匹配合词:把单位序列(中文单字/日文词/英文词)合并成词典词。
## 未能合词的单位以原样进入结果(unknown 词)。
static func segment_units(units: Array, locale: String) -> Array[String]:
	var dictionary: Dictionary = PickupCharPool.get_word_dictionary(locale)
	var word_unit_lists: Array = []
	for word in dictionary.keys():
		word_unit_lists.append({"word": str(word), "units": (dictionary[word] as Dictionary).get("units", [])})
	word_unit_lists.sort_custom(func(left, right): return (left["units"] as Array).size() > (right["units"] as Array).size())

	var words: Array[String] = []
	var index := 0
	while index < units.size():
		var matched := ""
		var matched_length := 0
		for candidate in word_unit_lists:
			var candidate_units: Array = candidate["units"]
			if candidate_units.is_empty() or index + candidate_units.size() > units.size():
				continue
			var fits := true
			for offset in candidate_units.size():
				if str(units[index + offset]) != str(candidate_units[offset]):
					fits = false
					break
			if fits:
				matched = str(candidate["word"])
				matched_length = candidate_units.size()
				break
		if matched.is_empty():
			words.append(str(units[index]))
			index += 1
		else:
			words.append(matched)
			index += matched_length
	return words


## 解析:返回 {tier: "rule"|"misread"|"noise", subject, predicate, negated, rule_key, words}。
## 语序宽容:主语与谓语在句中任意位置均可;否定词出现在句中任何位置即视为否定。
static func parse(units: Array, locale: String) -> Dictionary:
	var result := {
		"tier": "noise",
		"subject": "",
		"predicate": "",
		"negated": false,
		"rule_key": "",
		"words": [] as Array[String],
	}
	if units.is_empty():
		return result
	var words := segment_units(units, locale)
	result["words"] = words
	var subject_map: Dictionary = SUBJECT_CANON.get(locale, {})
	var predicate_map: Dictionary = PREDICATE_CANON.get(locale, {})
	var negation_list: Array = NEGATION_WORDS.get(locale, [])

	var subject := ""
	var predicate := ""
	var negated := false
	for word in words:
		if word in negation_list:
			negated = true
		if subject.is_empty() and subject_map.has(word):
			subject = str(subject_map[word])
			continue
		if predicate.is_empty() and predicate_map.has(word):
			predicate = str(predicate_map[word])
	# 谓语兼作主语的中文单字(如 在/开)已被 continue 规避:主语优先占位后,后续同词可作谓语。
	if subject.is_empty() and predicate.is_empty():
		return result
	result["subject"] = subject
	result["predicate"] = predicate
	result["negated"] = negated
	if subject.is_empty() or predicate.is_empty():
		result["tier"] = "misread"
		return result
	var rule_key := "%s|%s" % [subject, predicate]
	if SUPPORTED_RULES.has(rule_key):
		result["tier"] = "rule"
		result["rule_key"] = rule_key
	else:
		result["tier"] = "misread"
	return result


## 规则的展示文本(笔记本"现行规则"列表用)。
static func rule_display_text(rule_key: String, negated: bool, locale: String) -> String:
	var base := str((SUPPORTED_RULES.get(rule_key, {}) as Dictionary).get(locale, rule_key))
	if not negated:
		return base
	match locale:
		"ja":
			return base + " — 打ち消し"
		"en":
			return "NOT: " + base
		_:
			return "不再成立：" + base
