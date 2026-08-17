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
		"音", "安", "全", "的", "地", "方", "留", "下", "是", "想",
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
		"的": {"units": ["的"], "roles": ["particle"]},
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
const POST_SEEDS := {
	"floor_13": {
		"units": {"zh": ["门", "开", "出"], "ja": ["ドア", "ひらく"], "en": ["door", "open"]},
		"line": {
			"zh": "顶楼的门开着。没人出来。",
			"ja": "屋上のドアがひらく音。だれも出ない。",
			"en": "The top-floor door stands open. Nobody came out.",
		},
		"comments": [
			{
				"handle": {"zh": "打不开就别打", "ja": "名無しの住人", "en": "do_not_knock"},
				"time": "02:13",
				"text": {
					"zh": "打不开的那种门,最好也别打听。",
					"ja": "ひらかないドアは、ないことにしている。",
					"en": "If a door can't be opened, don't ask what it can do.",
				},
				"units": {"zh": ["打"], "ja": [], "en": ["can", "be", "opened"]},
			},
			{
				"handle": {"zh": "13F业主群已解散", "ja": "13F", "en": "floor13_owner"},
				"time": "02:41",
				"text": {
					"zh": "楼层按钮只到12。可它响了十三次。",
					"ja": "ボタンは12まで。音は十三回。",
					"en": "The panel stops at 12. It chimed thirteen times.",
				},
				"units": {"zh": ["可"], "ja": [], "en": []},
			},
		],
	},
	"self_call": {
		"units": {"zh": ["我", "你", "想"], "ja": ["わたし", "あなた"], "en": ["I", "you", "want"]},
		"line": {
			"zh": "短信只有三个字:我想你。发件人是我自己。",
			"ja": "「わたしはあなた」とだけ。差出人はわたし。",
			"en": "The text said: I want you home. Sender: I.",
		},
		"comments": [
			{
				"handle": {"zh": "别回消息", "ja": "既読つけるな", "en": "dont_reply"},
				"time": "03:07",
				"text": {
					"zh": "回了就等于承认那边也是你。",
					"ja": "返信したら、むこうもあなたになる。",
					"en": "Reply, and you agree that one is you too.",
				},
				"units": {"zh": [], "ja": ["あなた"], "en": ["you"]},
			},
		],
	},
	"missing_window": {
		"units": {"zh": ["灯", "亮", "没"], "ja": ["でんき", "つく", "ない"], "en": ["lit", "not"]},
		"line": {
			"zh": "那扇窗的灯又亮了。楼里没有这一户。",
			"ja": "あの窓のでんきがまたつく。その部屋はない。",
			"en": "That window is lit again. The room is not on any floor plan.",
		},
		"comments": [
			{
				"handle": {"zh": "物业不接电话", "ja": "管理人不在", "en": "no_landlord"},
				"time": "00:58",
				"text": {
					"zh": "去年停电那晚,只有它亮着。",
					"ja": "停電の夜も、あそこだけつく。",
					"en": "The night of the blackout, one light stayed lit.",
				},
				"units": {"zh": ["亮"], "ja": ["つく"], "en": ["light", "lit"]},
			},
			{
				"handle": {"zh": "顶楼安全员", "ja": "安全第一", "en": "safety_officer"},
				"time": "01:12",
				"text": {
					"zh": "那户人家很安全。安全得过分。",
					"ja": "あの部屋はあんぜん。あんぜんすぎる。",
					"en": "That household is safe. Too safe.",
				},
				"units": {"zh": ["安", "全"], "ja": ["あんぜん"], "en": ["safe"]},
			},
		],
	},
	"extra_moon": {
		"units": {"zh": ["是", "的", "地"], "ja": ["その", "ばしょ"], "en": ["is", "the", "place"]},
		"line": {
			"zh": "照片右下角的地面上,影子是双份的。",
			"ja": "写真のすみ、そのばしょだけ影がふたつ。",
			"en": "In the corner of the photo, the ground is the only place with two shadows.",
		},
		"comments": [
			{
				"handle": {"zh": "冲印店学徒", "ja": "現像係", "en": "darkroom_kid"},
				"time": "23:47",
				"text": {
					"zh": "底片上没有第二个。洗出来才有。",
					"ja": "ネガにはない。焼くと出る。",
					"en": "It is not on the negative. Only on the print.",
				},
				"units": {"zh": ["没"], "ja": ["ない"], "en": ["not"]},
			},
		],
	},
	"last_bus": {
		"units": {"zh": ["回", "家", "下"], "ja": ["いえ", "かえる"], "en": ["home", "return"]},
		"line": {
			"zh": "司机广播:到家的乘客请下车。没有人回话。",
			"ja": "「いえに着いた方は」と放送。かえる人はいない。",
			"en": "The driver announced: passengers now home, please return to the doors. No one moved.",
		},
		"comments": [
			{
				"handle": {"zh": "末班常客", "ja": "終バス常連", "en": "last_seat"},
				"time": "01:44",
				"text": {
					"zh": "我坐过一次全程。窗外一直是同一条街。",
					"ja": "一度乗り通した。窓の外はずっと同じみち。",
					"en": "I rode it to the end once. The same street the whole way.",
				},
				"units": {"zh": ["我"], "ja": ["みち"], "en": ["I"]},
			},
		],
	},
	"blackout_broadcast": {
		"units": {"zh": ["声", "音", "名"], "ja": ["こえ", "なまえ"], "en": ["voice", "name"]},
		"line": {
			"zh": "录音里广播念名单,最后一个声音是我的。",
			"ja": "放送がなまえを読む。最後のこえはわたしの。",
			"en": "The recording reads a name list. The last voice is mine.",
		},
		"comments": [
			{
				"handle": {"zh": "半个电工", "ja": "電気屋見習い", "en": "half_electrician"},
				"time": "04:20",
				"text": {
					"zh": "那站的喇叭线,九八年就剪了。",
					"ja": "あの駅の配線は98年に切った。",
					"en": "They cut that station's wiring in '98.",
				},
				"units": {"zh": [], "ja": [], "en": []},
			},
			{
				"handle": {"zh": "重听三遍的人", "ja": "三回聞いた", "en": "listened_thrice"},
				"time": "04:26",
				"text": {
					"zh": "念到你名字时别应声。它在点名。",
					"ja": "なまえを呼ばれてもこえを出すな。",
					"en": "When it reads your name, keep your voice down. It is taking attendance.",
				},
				"units": {"zh": ["名", "你"], "ja": ["なまえ", "こえ"], "en": ["name", "voice"]},
			},
		],
	},
	"station_lit": {
		"units": {"zh": ["出", "口", "在"], "ja": ["でぐち", "ある"], "en": ["exit", "exists"]},
		"line": {
			"zh": "站台只有一个出口。它昨晚不在原来的位置。",
			"ja": "でぐちはひとつ。ゆうべは別の場所にある。",
			"en": "The platform has one exit. By morning the exit exists somewhere else.",
		},
		"comments": [
			{
				"handle": {"zh": "拆迁办旧人", "ja": "元作業員", "en": "old_crew"},
				"time": "22:05",
				"text": {
					"zh": "它存在过,就删不干净。",
					"ja": "一度あったものは、消してものこる。",
					"en": "What exists once cannot be deleted clean.",
				},
				"units": {"zh": ["存", "在"], "ja": ["のこる"], "en": ["exists"]},
			},
		],
	},
	"no_shadow": {
		"units": {"zh": ["留", "下"], "ja": ["のこる"], "en": ["stay", "no"]},
		"line": {
			"zh": "他没有影子,地上却留下两串脚印。",
			"ja": "影がないのに、足あとだけのこる。",
			"en": "He has no shadow, yet two sets of footprints stay on the floor.",
		},
		"comments": [
			{
				"handle": {"zh": "夜班对面楼", "ja": "向かいのビル", "en": "across_street"},
				"time": "03:33",
				"text": {
					"zh": "灯全关了他还在货架间走。",
					"ja": "でんきを消しても歩いている。",
					"en": "Half the lights stay lit after closing. He keeps walking the aisles.",
				},
				"units": {"zh": ["灯"], "ja": ["でんき"], "en": ["lit"]},
			},
		],
	},
	"future_notice": {
		"units": {"zh": ["名", "字", "不"], "ja": ["なまえ", "ない"], "en": ["name", "not"]},
		"line": {
			"zh": "通知上的名字被涂掉了。笔迹不像人写的。",
			"ja": "貼り紙のなまえは塗りつぶし。人の字ではない。",
			"en": "The name on the notice is blacked out. The handwriting is not a person's.",
		},
		"comments": [
			{
				"handle": {"zh": "撕过一次的人", "ja": "剥がした者", "en": "tore_it_once"},
				"time": "05:01",
				"text": {
					"zh": "撕下来第二天,门缝里有一张一样的。",
					"ja": "剥がした翌日、ドアのすきまに同じ紙。",
					"en": "I tore it down. Next day the same sheet was under my door.",
				},
				"units": {"zh": ["门", "下"], "ja": ["ドア"], "en": ["door"]},
			},
		],
	},
	"old_post_today": {
		"units": {"zh": ["字", "是", "你"], "ja": ["あなた", "いる"], "en": ["you", "is"]},
		"line": {
			"zh": "回帖只有一行字:是你吗。",
			"ja": "返信は一行。「あなたはまだいる?」",
			"en": "The reply is one line: is that you.",
		},
		"comments": [
			{
				"handle": {"zh": "考古队散了", "ja": "過去ログ班", "en": "thread_digger"},
				"time": "23:59",
				"text": {
					"zh": "楼主十年没上线。头像昨天换了。",
					"ja": "主は十年不在。アイコンは昨日更新。",
					"en": "OP has been gone ten years. The avatar changed yesterday.",
				},
				"units": {"zh": [], "ja": [], "en": []},
			},
		],
	},
	"deleted_road": {
		"units": {"zh": ["地", "方", "回"], "ja": ["ばしょ", "かえる", "みち"], "en": ["place", "return", "the"]},
		"line": {
			"zh": "地图上那个地方还在,只是回不去了。",
			"ja": "そのばしょは地図にある。かえるみちがない。",
			"en": "The place is still on the map. There is no way to return.",
		},
		"comments": [
			{
				"handle": {"zh": "住过那条街", "ja": "元住民", "en": "used_to_live_there"},
				"time": "21:18",
				"text": {
					"zh": "导航说:您已到达。窗外是一堵墙。",
					"ja": "「到着しました」。窓の外は壁。",
					"en": "Navigation said: you have arrived. Outside the window, a wall.",
				},
				"units": {"zh": [], "ja": [], "en": []},
			},
		],
	},
	"access_record": {
		"units": {"zh": ["门", "在", "我"], "ja": ["ドア", "いる"], "en": ["door", "I", "exist"]},
		"line": {
			"zh": "门禁记录:我在屋里,也在屋外。",
			"ja": "記録では、わたしはドアの内にいる。外にもいる。",
			"en": "Access log: I exist inside the room, and outside the door.",
		},
		"comments": [
			{
				"handle": {"zh": "楼下都这么说", "ja": "下の階の噂", "en": "downstairs_says"},
				"time": "00:00",
				"text": {
					"zh": "可以进,不可以出。楼下都这么说。",
					"ja": "入ることはできる。出ることは、と噂。",
					"en": "You can get in. Whether you can get out, they don't say.",
				},
				"units": {"zh": ["可", "以", "不"], "ja": ["できる"], "en": ["can", "you"]},
			},
		],
	},
}

const SUPPORTED_LOCALES := ["zh", "ja", "en"]


static func get_unit_pool(locale: String) -> Array:
	return (UNIT_POOLS.get(locale, UNIT_POOLS["zh"]) as Array).duplicate()


static func get_word_dictionary(locale: String) -> Dictionary:
	return (WORD_DICTIONARY.get(locale, WORD_DICTIONARY["zh"]) as Dictionary).duplicate(true)


static func get_post_seed(post_id: String) -> Dictionary:
	return (POST_SEEDS.get(post_id, {}) as Dictionary).duplicate(true)


static func get_post_units(post_id: String, locale: String) -> Array:
	var seed: Dictionary = POST_SEEDS.get(post_id, {})
	var units: Dictionary = seed.get("units", {})
	var result: Array = (units.get(locale, []) as Array).duplicate()
	for comment: Dictionary in seed.get("comments", []):
		for unit in (comment.get("units", {}) as Dictionary).get(locale, []):
			if unit not in result:
				result.append(unit)
	return result


static func get_pickup_line(post_id: String, locale: String) -> String:
	var seed: Dictionary = POST_SEEDS.get(post_id, {})
	return str((seed.get("line", {}) as Dictionary).get(locale, ""))


static func get_comments(post_id: String, locale: String) -> Array:
	var seed: Dictionary = POST_SEEDS.get(post_id, {})
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
	var seed: Dictionary = POST_SEEDS.get(post_id, {})
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
	for post_id in POST_SEEDS.keys():
		var line := get_pickup_line(post_id, locale)
		var line_units: Array = ((POST_SEEDS[post_id] as Dictionary).get("units", {}) as Dictionary).get(locale, [])
		for unit in line_units:
			if not contains_pickable_unit(line, str(unit), locale):
				problems.append("%s 的埋字句缺少单位 %s (%s)" % [post_id, unit, locale])
			if str(unit) not in seeded_units:
				seeded_units.append(str(unit))
		for comment: Dictionary in (POST_SEEDS[post_id] as Dictionary).get("comments", []):
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
