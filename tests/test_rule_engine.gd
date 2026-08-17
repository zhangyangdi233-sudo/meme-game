extends SceneTree
## 规则引擎回归测试:词典合词、三层响应、语序宽容、否定算子、
## 以及"全枚举可达句"——受控词库让整个句子空间可以离线穷举验证。

const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const PoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")

var _failures: Array[String] = []


func _init() -> void:
	_run()
	if _failures.is_empty():
		print("rule engine tests passed")
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		quit(1)


func _run() -> void:
	_test_segmentation()
	_test_parse_tiers()
	_test_exhaustive_enumeration()


func _test_segmentation() -> void:
	_assert_eq_array(RuleEngineScript.segment_units(["出", "口", "存", "在"], "zh"), ["出口", "存在"], "greedy max-match should merge 出口+存在")
	_assert_eq_array(RuleEngineScript.segment_units(["门", "可", "以", "打", "开"], "zh"), ["门", "可以", "打开"], "door sentence should merge into three words")
	_assert_eq_array(RuleEngineScript.segment_units(["在", "存"], "zh"), ["在", "存"], "unknown orderings should fall back to single units")
	_assert_eq_array(RuleEngineScript.segment_units(["door", "can", "be", "opened"], "en"), ["door", "can", "be", "opened"], "English units are already words")


func _test_parse_tiers() -> void:
	var door: Dictionary = RuleEngineScript.parse(["门", "可", "以", "打", "开"], "zh")
	_assert_eq_text(str(door.get("tier", "")), "rule", "门可以打开 should parse as a rule")
	_assert_eq_text(str(door.get("rule_key", "")), "door|can_open", "the door rule should canonicalize")
	_assert_true(not bool(door.get("negated", false)), "the plain door rule should not be negated")

	var reordered: Dictionary = RuleEngineScript.parse(["打", "开", "门"], "zh")
	_assert_eq_text(str(reordered.get("rule_key", "")), "door|can_open", "free word order (打开门) must still hit the rule")

	var negated: Dictionary = RuleEngineScript.parse(["门", "不", "可", "以", "打", "开"], "zh")
	_assert_eq_text(str(negated.get("tier", "")), "rule", "a negated known combo still parses as a rule")
	_assert_true(bool(negated.get("negated", false)), "不 must flip the rule polarity")

	_assert_eq_text(str(RuleEngineScript.parse(["出", "口", "存", "在"], "zh").get("rule_key", "")), "exit|exists", "出口存在 should canonicalize")
	_assert_eq_text(str(RuleEngineScript.parse(["灯", "亮"], "zh").get("rule_key", "")), "light|lit", "灯亮 should canonicalize")

	var misread: Dictionary = RuleEngineScript.parse(["我", "想", "回", "家"], "zh")
	_assert_eq_text(str(misread.get("tier", "")), "misread", "known subject+verb outside the rule table should be misread")

	var noise: Dictionary = RuleEngineScript.parse(["被", "安", "全"], "zh")
	_assert_eq_text(str(noise.get("tier", "")), "noise", "particles and modifiers alone should be noise")

	var passive: Dictionary = RuleEngineScript.parse(["门", "可", "以", "被", "打", "开"], "zh")
	_assert_eq_text(str(passive.get("rule_key", "")), "door|can_open", "the user's example 门可以被打开 must hit the door rule")

	var two_unit: Dictionary = RuleEngineScript.parse(["开", "门"], "zh")
	_assert_eq_text(str(two_unit.get("rule_key", "")), "door|can_open", "the two-unit 开门 should still resolve the door rule")

	var english: Dictionary = RuleEngineScript.parse(["the", "door", "can", "be", "opened"], "en")
	_assert_eq_text(str(english.get("rule_key", "")), "door|can_open", "the English door sentence should hit the rule")
	var english_negated: Dictionary = RuleEngineScript.parse(["no", "exit", "exists"], "en")
	_assert_true(bool(english_negated.get("negated", false)) and str(english_negated.get("rule_key", "")) == "exit|exists", "no exit exists should be a negated exit rule")

	_assert_eq_text(str(RuleEngineScript.parse(["ドア", "ひらく"], "ja").get("rule_key", "")), "door|can_open", "Japanese door sentence should hit the rule")
	_assert_eq_text(str(RuleEngineScript.parse(["でぐち", "ある"], "ja").get("rule_key", "")), "exit|exists", "Japanese exit sentence should hit the rule")
	var japanese_negated: Dictionary = RuleEngineScript.parse(["でんき", "つく", "ない"], "ja")
	_assert_true(bool(japanese_negated.get("negated", false)), "ない anywhere should negate")


func _test_exhaustive_enumeration() -> void:
	# 受控词库的核心红利:全部 ≤3 词的句子都能被枚举检查。
	for locale in ["zh", "ja", "en"]:
		var dictionary: Dictionary = PoolScript.get_word_dictionary(locale)
		var words: Array = dictionary.keys()
		var reachable_rules := {}
		var parse_count := 0
		for first in words:
			for second in words:
				var sequences := [[first, second]]
				for third in words:
					sequences.append([first, second, third])
				for sequence in sequences:
					var units: Array = []
					for word in sequence:
						units.append_array((dictionary[word] as Dictionary).get("units", []))
					var parsed: Dictionary = RuleEngineScript.parse(units, locale)
					parse_count += 1
					var tier := str(parsed.get("tier", ""))
					_assert_true(tier in ["rule", "misread", "noise"], "every sentence must resolve to a tier (%s)" % locale)
					if tier == "rule":
						reachable_rules[str(parsed.get("rule_key", ""))] = true
						_assert_true(RuleEngineScript.SUPPORTED_RULES.has(str(parsed.get("rule_key", ""))), "rule keys must stay inside the supported table (%s)" % locale)
		for rule_key in RuleEngineScript.SUPPORTED_RULES.keys():
			_assert_true(reachable_rules.has(str(rule_key)), "rule %s must be reachable by some player sentence in %s" % [rule_key, locale])
		_assert_true(parse_count > 0, "enumeration should actually run for %s" % locale)

	# 原始单位层面的乱序:门句五单位的全部 120 种排列都必须稳定解析(玩家可以任意拼装)。
	var door_units := ["门", "可", "以", "打", "开"]
	var permutations := _permutations(door_units)
	_assert_true(permutations.size() == 120, "five units should yield 120 permutations")
	var permutation_rule_hits := 0
	for permutation in permutations:
		var parsed: Dictionary = RuleEngineScript.parse(permutation, "zh")
		_assert_true(str(parsed.get("tier", "")) in ["rule", "misread", "noise"], "every raw permutation must parse to a tier")
		if str(parsed.get("rule_key", "")) == "door|can_open":
			permutation_rule_hits += 1
	_assert_true(permutation_rule_hits >= 2, "multiple raw orderings (e.g. 门可以打开 / 打开门…) should reach the door rule, got %d" % permutation_rule_hits)

	# 字池任意两单位组合(30x30)不崩溃扫描。
	var zh_pool: Array = PoolScript.get_unit_pool("zh")
	for first_unit in zh_pool:
		for second_unit in zh_pool:
			var pair_parsed: Dictionary = RuleEngineScript.parse([first_unit, second_unit], "zh")
			_assert_true(str(pair_parsed.get("tier", "")) in ["rule", "misread", "noise"], "raw unit pairs must never crash the parser")


func _permutations(values: Array) -> Array:
	if values.size() <= 1:
		return [values.duplicate()]
	var result: Array = []
	for index in values.size():
		var rest := values.duplicate()
		rest.remove_at(index)
		for tail in _permutations(rest):
			var sequence: Array = [values[index]]
			sequence.append_array(tail)
			result.append(sequence)
	return result


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _assert_eq_text(value: String, expected: String, message: String) -> void:
	if value != expected:
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])


func _assert_eq_array(value: Array, expected: Array, message: String) -> void:
	if str(value) != str(expected):
		_failures.append("%s (got %s, expected %s)" % [message, value, expected])
