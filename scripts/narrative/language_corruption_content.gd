class_name LanguageCorruptionContent
extends RefCounted

## Authored narrative data only. State changes remain the responsibility of MemeGameState.

const REALITY_DIALOGUES_BY_FLOOR := {
	1: [
		{
			"line_id": "f1_npc0_open",
			"speaker_id": "latecomer",
			"speaker": "迟到者",
			"line": "这张票印的是明天。可车刚走。你能陪我等下一班吗？",
			"result": "迟到者把票折回掌心，往旁边让出半个座位。",
			"subtext": "他怕的不是迟到，而是独自留下。",
			"choices": [
				{"id": "f1n0_wait", "intent": "approach", "summary": "陪他等", "sentence": "我陪你等。下一班来了再看日期。"},
				{"id": "f1n0_time", "intent": "check", "summary": "核对站钟", "sentence": "先看站钟。它停在九点十七分。"},
				{"id": "f1n0_leave", "intent": "refuse", "summary": "沿路离开", "sentence": "我不等了。你要一起沿车辙走吗？"},
			],
		},
		{
			"line_id": "f1_npc1_open",
			"speaker_id": "echo_tenant",
			"speaker": "回声住户",
			"line": "水阀关了，楼上还在滴。你听，门后是不是有人？",
			"result": "住户没去碰门，只把一把小扳手递了过来。",
			"subtext": "他想有人同行，又不敢确认屋里是谁。",
			"choices": [
				{"id": "f1n1_home", "intent": "approach", "summary": "陪他上楼", "sentence": "我陪你上去。先别开门。"},
				{"id": "f1n1_pipe", "intent": "check", "summary": "再关水阀", "sentence": "把扳手给我。我再关一次。"},
				{"id": "f1n1_name", "intent": "check", "summary": "确认名字", "sentence": "等一下。刚才叫的是谁的名字？"},
			],
		},
		{
			"line_id": "f1_npc2_open",
			"speaker_id": "copyist",
			"speaker": "抄写员",
			"line": "第四行被擦过。不是我擦的。你看，橡皮屑还在。",
			"result": "抄写员按住纸角，拇指上沾着同色的灰。",
			"subtext": "他改过记录，却希望纸替他承担责任。",
			"choices": [
				{"id": "f1n2_count", "intent": "approach", "summary": "重新核对", "sentence": "从第一行重数。你念，我记。"},
				{"id": "f1n2_blank", "intent": "check", "summary": "保留空行", "sentence": "第四行先空着。别替它填人。"},
				{"id": "f1n2_stop", "intent": "refuse", "summary": "让他停笔", "sentence": "把笔放下。纸边还有你的指印。"},
			],
		},
		{
			"line_id": "f1_npc3_open",
			"speaker_id": "believer",
			"speaker": "无名信徒",
			"line": "队伍只差一个位置。你站进去，我们就能开始。",
			"result": "信徒朝空位点头，没有看主角一眼。",
			"subtext": "他想躲进群体，也需要别人替他承担被看见。",
			"choices": [
				{"id": "f1n3_sky", "intent": "approach", "summary": "站在队尾", "sentence": "我站边上。先看是谁没来。"},
				{"id": "f1n3_receipt", "intent": "check", "summary": "查看次序纸", "sentence": "这张次序纸是谁写的？"},
				{"id": "f1n3_ground", "intent": "refuse", "summary": "留下空位", "sentence": "我不占那个位置。让它空着。"},
			],
		},
		{
			"line_id": "f1_npc4_open",
			"speaker_id": "post_witness",
			"speaker": "旧帖目击者",
			"line": "我删过三次。这句回复每次都会回来：‘你到了吗？’",
			"result": "目击者熄掉屏幕。那五个字仍映在指甲上。",
			"subtext": "他想证明自己没编造，又不敢独自读下去。",
			"choices": [
				{"id": "f1n4_yes", "intent": "approach", "summary": "承认见过", "sentence": "像是我回的。可我不记得发过。"},
				{"id": "f1n4_no", "intent": "check", "summary": "查看时间", "sentence": "不是我。先看发送时间。"},
				{"id": "f1n4_reply", "intent": "approach", "summary": "留下回复", "sentence": "别删了。回一句‘还没有’。"},
			],
		},
	],
	2: [
		{
			"line_id": "f2_npc0_open",
			"speaker_id": "latecomer",
			"speaker": "迟到者",
			"line": "我想跟司机道歉。可一开口，就是楼下那句。你先听哪句？",
			"result": "迟到者张了张嘴，旧句先替他吸了一口气。",
			"subtext": "他需要有人承认，道歉后面还有自己的理由。",
			"choices": [
				{"id": "f2n0_order", "intent": "approach", "summary": "等他说完", "sentence": "先把旧句说完。我等你自己的话。"},
				{"id": "f2n0_reason", "intent": "check", "summary": "先问迟到", "sentence": "先说为什么迟到。别管它插嘴。"},
				{"id": "f2n0_refuse", "intent": "refuse", "summary": "不再道歉", "sentence": "别道歉了。把票递给他就走。"},
			],
		},
		{
			"line_id": "f2_npc1_open",
			"speaker_id": "echo_tenant",
			"speaker": "回声住户",
			"line": "我问邻居借扳手。他只回楼下那句话。是没听见吗？",
			"result": "住户把耳朵贴在门上，钥匙却插进了自己的锁。",
			"subtext": "他想确认邻居还在，又怕答案只是一句借来的话。",
			"choices": [
				{"id": "f2n1_lock", "intent": "refuse", "summary": "先锁好门", "sentence": "先锁门。今晚别让那句话进来。"},
				{"id": "f2n1_follow", "intent": "check", "summary": "再问一次", "sentence": "我替你问。只问扳手，不提楼下。"},
				{"id": "f2n1_return", "intent": "approach", "summary": "归还旧话", "sentence": "把那句写下来，明早放回楼梯口。"},
			],
		},
		{
			"line_id": "f2_npc2_open",
			"speaker_id": "copyist",
			"speaker": "抄写员",
			"line": "表上写‘已说明’，下面却没有我的话。你听见我说什么了吗？",
			"result": "抄写员把空白转向主角，印章藏进袖口。",
			"subtext": "他需要证人，也害怕证人说出不同版本。",
			"choices": [
				{"id": "f2n2_again", "intent": "approach", "summary": "请他重说", "sentence": "再说一次。慢一点，我听着。"},
				{"id": "f2n2_record", "intent": "check", "summary": "核对笔迹", "sentence": "先看‘已说明’是谁写的。"},
				{"id": "f2n2_stamp", "intent": "refuse", "summary": "不要盖章", "sentence": "别盖。空白至少没有冒充你。"},
			],
		},
		{
			"line_id": "f2_npc3_open",
			"speaker_id": "believer",
			"speaker": "无名信徒",
			"line": "点名时，他们念楼下那句，不念名字。现在轮到你了。",
			"result": "人群齐齐吸气。信徒自己的名字卡在喉咙里。",
			"subtext": "他维护规则，因为规则能遮住自己的声音。",
			"choices": [
				{"id": "f2n3_name", "intent": "refuse", "summary": "只说名字", "sentence": "我只报名字。后面那句不是我。"},
				{"id": "f2n3_legacy", "intent": "approach", "summary": "照例点名", "sentence": "我先念旧句。名字留到最后。"},
				{"id": "f2n3_none", "intent": "refuse", "summary": "保持沉默", "sentence": "这次我不答。你们可以跳过去。"},
			],
		},
	],
	3: [
		{
			"line_id": "f3_npc0_open",
			"speaker_id": "latecomer",
			"speaker": "迟到者",
			"line": "票上只剩‘去’。站名没了。你……还看得懂吗？",
			"result": "迟到者把票举到眼前。‘去’字朝两边同时褪色。",
			"subtext": "他已无法说明目的地，只想有人一起做决定。",
			"choices": [
				{"id": "f3n0_submit", "intent": "approach", "summary": "先上车", "sentence": "去。先上车。"},
				{"id": "f3n0_copy", "intent": "check", "summary": "认出笔迹", "sentence": "这字……像我的。"},
				{"id": "f3n0_window", "intent": "refuse", "summary": "不提交票", "sentence": "不。没有站名。"},
			],
		},
		{
			"line_id": "f3_npc1_open",
			"speaker_id": "echo_tenant",
			"speaker": "回声住户",
			"line": "门牌只剩‘我’。里面有人说，那是他的。",
			"result": "住户试了两把钥匙。门内外同时响了一声。",
			"subtext": "方位和人称一起松动，他不敢再说这是自己的家。",
			"choices": [
				{"id": "f3n1_actual", "intent": "approach", "summary": "试着开门", "sentence": "门。钥匙。先开……"},
				{"id": "f3n1_metaphor", "intent": "check", "summary": "问谁写的", "sentence": "‘我’是谁写的？"},
				{"id": "f3n1_nohome", "intent": "refuse", "summary": "擦掉门牌", "sentence": "擦掉。别留给下一户。"},
			],
		},
		{
			"line_id": "f3_npc2_open",
			"speaker_id": "copyist",
			"speaker": "抄写员",
			"line": "缺失栏……它自己填了你的名字。",
			"result": "抄写员没有碰纸。笔尖仍在一下一下地点。",
			"subtext": "记录终于指向主角，他无法再假装只是文书错误。",
			"choices": [
				{"id": "f3n2_self", "intent": "check", "summary": "先划掉", "sentence": "先划掉。那是我……不，是名字。"},
				{"id": "f3n2_missing", "intent": "refuse", "summary": "保持缺失", "sentence": "空着。让缺失还是缺失。"},
				{"id": "f3n2_drawer", "intent": "approach", "summary": "打开抽屉", "sentence": "抽屉里。有人在呼吸。打开。"},
			],
		},
	],
}

const REALITY_FOLLOWUPS_BY_NPC_INDEX := {
	0: {
		"archetype": "latecomer",
		"turns": [
			{
				"line_id": "late_followup_clock",
				"line": "站钟走了两分钟，票却退回一分钟。你信哪一个？",
				"result": "迟到者把票压在表盘下，只露出那行日期。",
				"choices": [
					{"id": "late_signal_wait", "intent": "approach", "summary": "相信站钟", "sentence": "信站钟。它至少还在往前。"},
					{"id": "late_signal_tower", "intent": "check", "summary": "检查票背", "sentence": "先看票背。有没有改过的墨？"},
					{"id": "late_signal_walk", "intent": "refuse", "summary": "沿车辙走", "sentence": "都不信。我们沿车辙走。"},
				],
			},
			{
				"line_id": "late_followup_stop",
				"line": "车来了。报站器只念旧句。你在哪儿下？",
				"result": "迟到者把手停在铃上，等一句不属于楼下的话。",
				"choices": [
					{"id": "late_stop_today", "intent": "approach", "summary": "等今天的停顿", "sentence": "旧句念完，第一处停顿就下。"},
					{"id": "late_stop_silence", "intent": "check", "summary": "听沉默站点", "sentence": "它不报站的地方。就那里。"},
					{"id": "late_stop_own", "intent": "refuse", "summary": "暂不下车", "sentence": "先不下。等有人自己说地名。"},
				],
			},
		],
		"interrupt": "报站声盖过最后一个字。迟到者说：‘算了，车还没来。’",
	},
	1: {
		"archetype": "echo_tenant",
		"turns": [
			{
				"line_id": "echo_followup_wall",
				"line": "墙里把你刚才的话说了一遍，多了我的门牌。留哪句？",
				"result": "住户拿粉笔圈住多出的门牌，没有念出来。",
				"choices": [
					{"id": "echo_keep_original", "intent": "approach", "summary": "留下原话", "sentence": "留第一遍。那才是我说的。"},
					{"id": "echo_mark_legacy", "intent": "check", "summary": "标出多余处", "sentence": "把多的圈起来。别擦。"},
					{"id": "echo_close_pipe", "intent": "refuse", "summary": "关掉管道", "sentence": "先关阀。今晚不回答墙。"},
				],
			},
			{
				"line_id": "echo_followup_water",
				"line": "水出来了。它叫了我一声，又叫成楼下。你听见了吗？",
				"result": "住户接住一杯水，没敢把杯子带回屋。",
				"choices": [
					{"id": "echo_check_reflection", "intent": "check", "summary": "看杯中倒影", "sentence": "先看倒影。别回答它。"},
					{"id": "echo_try_name", "intent": "approach", "summary": "再叫一次水", "sentence": "我只叫它水。看它回什么。"},
					{"id": "echo_leave_nameless", "intent": "refuse", "summary": "不再命名", "sentence": "别叫了。让它先流走。"},
				],
			},
		],
		"interrupt": "墙里抢着回答。住户拧紧阀门：‘今晚到这里。’",
	},
	2: {
		"archetype": "copyist",
		"turns": [
			{
				"line_id": "copy_followup_source",
				"line": "‘来源’那栏被涂黑了。主管会问。你让我写什么？",
				"result": "抄写员悬着笔，墨在纸上落成一个小圆点。",
				"choices": [
					{"id": "copy_source_now", "intent": "approach", "summary": "填写此刻", "sentence": "写‘刚才’。别补具体时间。"},
					{"id": "copy_refuse_source", "intent": "refuse", "summary": "保持空白", "sentence": "不填。活话不需要出处。"},
					{"id": "copy_mark_pollution", "intent": "check", "summary": "注明被改过", "sentence": "写‘被改过’。别写是谁。"},
				],
			},
			{
				"line_id": "copy_followup_stamp",
				"line": "章盖下去，主语就没了。还盖吗？",
				"result": "抄写员把章翻过来，底面粘着一个很小的‘我’。",
				"choices": [
					{"id": "copy_no_stamp", "intent": "refuse", "summary": "不盖章", "sentence": "不盖。把‘我’放回句首。"},
					{"id": "copy_edge_stamp", "intent": "check", "summary": "盖在纸边", "sentence": "盖边上。别碰那句话。"},
					{"id": "copy_rewrite_rule", "intent": "approach", "summary": "先改说明", "sentence": "先写清楚：章不能删主语。"},
				],
			},
		],
		"interrupt": "盖章机咬住纸角。抄写员断电，没再说‘流程’。",
	},
	3: {
		"archetype": "believer",
		"turns": [
			{
				"line_id": "believer_followup_speaker",
				"line": "喇叭没接线。大家还是听见了。你呢？",
				"result": "信徒等人群先点头，自己最后才轻轻点了一下。",
				"choices": [
					{"id": "believer_crowd", "intent": "approach", "summary": "听见人群", "sentence": "我听见他们互相跟着念。"},
					{"id": "believer_legacy", "intent": "check", "summary": "听见旧句", "sentence": "只听见楼下那句。没有旋律。"},
					{"id": "believer_static", "intent": "refuse", "summary": "只承认杂音", "sentence": "我听见电流。别替它起名。"},
				],
			},
			{
				"line_id": "believer_followup_lead",
				"line": "轮到你领唱。说一句不会逼别人跟着的话。",
				"result": "信徒没有复述，只替下一人留出一口气。",
				"choices": [
					{"id": "believer_question", "intent": "check", "summary": "允许不回答", "sentence": "你可以不回答。"},
					{"id": "believer_names", "intent": "approach", "summary": "归还名字", "sentence": "名字请各自拿回去。"},
					{"id": "believer_pause", "intent": "refuse", "summary": "留下停顿", "sentence": "我说完了。现在不唱。"},
				],
			},
		],
		"interrupt": "人群抢走第一个音。信徒抬手：‘停。让她自己说。’",
	},
	4: {
		"archetype": "post_witness",
		"turns": [
			{
				"line_id": "post_followup_future",
				"line": "帖子写着十年后。下面有人刚回了‘在吗’。点开吗？",
				"result": "目击者把屏幕侧过来，只让主角看见发送时间。",
				"choices": [
					{"id": "post_earliest", "intent": "check", "summary": "看第一条", "sentence": "点最早那条。先看头像。"},
					{"id": "post_unsent", "intent": "approach", "summary": "看未发送的", "sentence": "看草稿。它还没成为回复。"},
					{"id": "post_close", "intent": "refuse", "summary": "关掉页面", "sentence": "先关掉。它在等我们回答。"},
				],
			},
			{
				"line_id": "post_followup_blank",
				"line": "空框问：今天留哪个词？我不想替你选。",
				"result": "目击者松开手机。空框没有自动填字。",
				"choices": [
					{"id": "post_leave_exist", "intent": "approach", "summary": "留下‘在’", "sentence": "留‘在’。只留这一个字。"},
					{"id": "post_leave_signal", "intent": "check", "summary": "留下‘断线’", "sentence": "留‘断线’。免得沉默被误认。"},
					{"id": "post_leave_nothing", "intent": "refuse", "summary": "保持空框", "sentence": "什么都不留。空着也算回答。"},
				],
			},
		],
		"interrupt": "页面开始替主角输入。目击者锁屏：‘这句不算。’",
	},
}

const LANGUAGE_PERSONA_SCENES := [
	{
		"scene_id": "doll_names_lamp",
		"floor": 1,
		"speaker_id": "doll",
		"speaker": "玩偶",
		"line": "你又叫它台灯。它叫小月亮。我们以前说好的。",
		"subtext": "玩偶把共享称呼当作两人关系的凭证。",
	},
	{
		"scene_id": "doll_safe_first",
		"floor": 1,
		"speaker_id": "doll",
		"speaker": "玩偶",
		"line": "我只是想让你留在安全的地方。",
		"subtext": "温柔的保护同时是一项留下来的要求。",
	},
	{
		"scene_id": "doctor_safe_repeat",
		"floor": 2,
		"speaker_id": "doctor",
		"speaker": "医生",
		"line": "我只是想让你留在安全的地方。",
		"subtext": "同一句话被程序化语气接管，来源开始不稳定。",
	},
	{
		"scene_id": "doctor_voice_first",
		"floor": 2,
		"speaker_id": "doctor",
		"speaker": "医生",
		"line": "你不需要再听见那个声音。",
		"subtext": "医生把无法分类的语言当作应当停止的刺激。",
	},
	{
		"scene_id": "doll_voice_repeat",
		"floor": 3,
		"speaker_id": "doll",
		"speaker": "玩偶",
		"line": "你不需要再听见那个声音。",
		"subtext": "玩偶借用医生的句式，试图把医生排除在世界外。",
	},
	{
		"scene_id": "unregistered_safe_residue",
		"floor": 4,
		"speaker_id": "blank",
		"speaker": "",
		"line": "我只是想让你留在安全的地方。",
		"subtext": "说话者消失后，句子仍在决定什么叫安全。",
	},
]

const AUTHORED_CRITICAL_CORRUPTIONS := [
	{
		"corruption_id": "safe_becomes_stable",
		"source_line_id": "doll_safe_first",
		"minimum_pollution": 60,
		"original_speaker": "玩偶",
		"current_speaker": "医生",
		"clean_text": "我只是想让你留在安全的地方。",
		"display_text": "我只是想让你留在{del}安全{/del}{ins}稳定{/ins}的地方。",
	},
	{
		"corruption_id": "voice_becomes_outside",
		"source_line_id": "doctor_voice_first",
		"minimum_pollution": 68,
		"original_speaker": "医生",
		"current_speaker": "玩偶",
		"clean_text": "你不需要再听见那个声音。",
		"display_text": "你不需要再听见{del}那个声音{/del}{ins}外面的声音{/ins}。",
	},
	{
		"corruption_id": "ticket_date_reversal",
		"source_line_id": "f1_npc0_open",
		"minimum_pollution": 35,
		"original_speaker": "迟到者",
		"current_speaker": "迟到者",
		"clean_text": "这张票印的是明天。可车刚走。",
		"display_text": "这张票印的是{del}明天{/del}{ins}昨天{/ins}。可车刚走。",
	},
	{
		"corruption_id": "form_claims_consent",
		"source_line_id": "f2_npc2_open",
		"minimum_pollution": 55,
		"original_speaker": "抄写员",
		"current_speaker": "抄写员",
		"clean_text": "表上写‘已说明’，下面却没有我的话。",
		"display_text": "表上写‘{del}已说明{/del}{ins}已同意{/ins}’，下面却没有我的话。",
	},
	{
		"corruption_id": "missing_name_ownership",
		"source_line_id": "f3_npc2_open",
		"minimum_pollution": 75,
		"original_speaker": "抄写员",
		"current_speaker": "主角",
		"clean_text": "缺失栏……它自己填了你的名字。",
		"display_text": "缺失栏……{del}它{/del}{ins}我{/ins}自己填了你的名字。",
	},
]

const PROTECTED_TEXTS := [
	"我只是想让你留在安全的地方。",
	"你不需要再听见那个声音。",
	"玩偶",
	"医生",
	"主角",
	"语言污染",
	"安全",
	"声音",
	"名字",
	"退出游戏",
	"返回",
	"仍然退出",
]

const PROTECTED_PUNCTUATION := [
	"，", "。", "！", "？", "；", "：", "、", "……", "…",
	",", ".", "!", "?", ";", ":", "‘", "’", "“", "”", "（", "）", "(", ")",
]

const PLAYER_CHOICE_FRAGMENTS_BY_FLOOR := {
	1: [
		{"intent": "approach", "revision_stage": 0, "display_text": "我先陪你。", "tiles": ["我", "先", "陪你"]},
		{"intent": "check", "revision_stage": 0, "display_text": "等一下，让我确认。", "tiles": ["等一下", "让我", "确认"]},
		{"intent": "refuse", "revision_stage": 0, "display_text": "不了。我先走。", "tiles": ["不了", "我", "先走"]},
	],
	2: [
		{"intent": "approach", "revision_stage": 1, "display_text": "我先……陪你。", "tiles": ["我先……", "陪你"]},
		{"intent": "check", "revision_stage": 1, "display_text": "等一下，是谁在说？", "tiles": ["等一下", "谁", "在说"]},
		{"intent": "refuse", "revision_stage": 1, "display_text": "不是。我没有答应。", "tiles": ["不是", "我没有", "答应"]},
	],
	3: [
		{"intent": "approach", "revision_stage": 2, "display_text": "我 / 先……", "tiles": ["我", "先……"]},
		{"intent": "check", "revision_stage": 2, "display_text": "谁 / 在说", "tiles": ["谁", "在说"]},
		{"intent": "refuse", "revision_stage": 2, "display_text": "不 / ……", "tiles": ["不", "……"]},
	],
}

const HISTORY_REVISIONS := [
	{
		"lineId": "history_doll_safe_original",
		"originalSpeaker": "玩偶",
		"currentSpeaker": "玩偶",
		"originalText": "我只是想让你留在安全的地方。",
		"displayText": "我只是想让你留在安全的地方。",
		"revisionStage": 0,
		"revisionMarkup": "none",
	},
	{
		"lineId": "history_doctor_safe_revision",
		"originalSpeaker": "玩偶",
		"currentSpeaker": "医生",
		"originalText": "我只是想让你留在安全的地方。",
		"displayText": "我只是想让你留在{del}安全{/del}{ins}稳定{/ins}的地方。",
		"revisionStage": 1,
		"revisionMarkup": "replace",
	},
	{
		"lineId": "history_doctor_voice_original",
		"originalSpeaker": "医生",
		"currentSpeaker": "医生",
		"originalText": "你不需要再听见那个声音。",
		"displayText": "你不需要再听见那个声音。",
		"revisionStage": 0,
		"revisionMarkup": "none",
	},
	{
		"lineId": "history_doll_voice_revision",
		"originalSpeaker": "医生",
		"currentSpeaker": "玩偶",
		"originalText": "你不需要再听见那个声音。",
		"displayText": "你不需要再听见{del}那个声音{/del}{ins}外面的声音{/ins}。",
		"revisionStage": 2,
		"revisionMarkup": "replace",
	},
	{
		"lineId": "history_unregistered_safe",
		"originalSpeaker": "玩偶",
		"currentSpeaker": "",
		"originalText": "我只是想让你留在安全的地方。",
		"displayText": "我只是想让你留在安全的地方。",
		"revisionStage": 3,
		"revisionMarkup": "speaker_shift",
	},
]

const KEY_NPC_DIALOGUES_BY_FLOOR := {
	1: {
		"actor_label": "护灯人",
		"turns": [
			{
				"line": "先别往灯上看。你听见她怎么叫那盏灯了吗？",
				"result": "护灯人把手从灯杆上拿开，等你把名字说完整。",
				"choices": [
					{"id": "key_f1_t1_moon", "summary": "沿用她的名字", "sentence": "她叫它小月亮。", "correct": true},
					{"id": "key_f1_t1_lamp", "summary": "纠正名称", "sentence": "那只是一盏坏掉的路灯。", "correct": false},
					{"id": "key_f1_t1_unsure", "summary": "避开回答", "sentence": "我没有听清，也不想替她命名。", "correct": false},
				],
			},
			{
				"line": "要是有人说她叫错了，你按哪个名字去找？",
				"result": "护灯人朝街外侧偏了一下头，没有用手指方向。",
				"choices": [
					{"id": "key_f1_t2_keep", "summary": "按她的名字找", "sentence": "我先按她给的名字找，不在路上纠正。", "correct": true},
					{"id": "key_f1_t2_fix", "summary": "按正式名称找", "sentence": "我会按路灯的编号找，名字不重要。", "correct": false},
					{"id": "key_f1_t2_leave", "summary": "拒绝寻找", "sentence": "既然名字会变，我就不去找了。", "correct": false},
				],
			},
		],
		"success_line": "好。那块旧名牌还认得这个叫法。",
		"failure_line": "护灯人把嘴闭上了。你答完了，但他没有说出地点。",
	},
	2: {
		"actor_label": "两醒者",
		"turns": [
			{
				"line": "你今天醒过几次？别数现在这一次。",
				"result": "两醒者用指节在掌心敲了两下，第二下没有声音。",
				"choices": [
					{"id": "key_f2_t1_twice", "summary": "承认两次", "sentence": "两次。第一次醒来时，我还在这里。", "correct": true},
					{"id": "key_f2_t1_once", "summary": "只算一次", "sentence": "一次。我醒来以后就没有再睡。", "correct": false},
					{"id": "key_f2_t1_now", "summary": "只承认现在", "sentence": "我只确定现在这一回是真的。", "correct": false},
				],
			},
			{
				"line": "两次醒来都听见了什么？",
				"result": "两醒者摸了摸空口袋，像在确认磁带没有提前回来。",
				"choices": [
					{"id": "key_f2_t2_same", "summary": "同一句话", "sentence": "两次都有同一句话，只是声音的方向相反。", "correct": true},
					{"id": "key_f2_t2_silence", "summary": "什么都没有", "sentence": "第一次没有声音，第二次我也不记得。", "correct": false},
					{"id": "key_f2_t2_music", "summary": "一段音乐", "sentence": "我只听见很远的音乐，没有人说话。", "correct": false},
				],
			},
		],
		"success_line": "那不是回声。有人把同一句录在了磁带两面。",
		"failure_line": "两醒者把第二下敲击收回掌心，没有说出地点。",
	},
	3: {
		"actor_label": "删句员",
		"turns": [
			{
				"line": "这张病历第一行少了什么？别念后面的诊断。",
				"result": "删句员压住纸角。那一行没有被风吹动。",
				"choices": [
					{"id": "key_f3_t1_subject", "summary": "指出主语", "sentence": "少了主语。没有写是谁经历了这些。", "correct": true},
					{"id": "key_f3_t1_date", "summary": "指出日期", "sentence": "少了日期，所以记录没有发生过。", "correct": false},
					{"id": "key_f3_t1_name", "summary": "补上名字", "sentence": "少了我的名字，我可以现在写上去。", "correct": false},
				],
			},
			{
				"line": "空着的地方应该填谁？",
				"result": "删句员松开纸角，空白仍然没有向任何人靠近。",
				"choices": [
					{"id": "key_f3_t2_blank", "summary": "保留空白", "sentence": "先不要填。缺少主语本身就是这页留下的信息。", "correct": true},
					{"id": "key_f3_t2_self", "summary": "填写自己", "sentence": "填我。至少我现在还站在这里。", "correct": false},
					{"id": "key_f3_t2_doctor", "summary": "填写医生", "sentence": "填医生，他会知道该怎样归类。", "correct": false},
				],
			},
		],
		"success_line": "别补那一格。原页被夹在一扇向外开的假窗下面。",
		"failure_line": "删句员把纸翻到背面。你给了答案，他没有说出地点。",
	},
}

const DOLL_ENCOUNTERS_BY_FLOOR := {
	1: {
		"doll_id": "doll_small_moon",
		"actor_label": "缝线布偶",
		"world_hint": "一盏不亮的路灯背后",
		"turns": [{
			"line": "你把我放反了。缝口应该朝着路，不是朝着你。先拿起手机。帖子里有三种能拼成一句话的词。",
			"result": "布偶把一只纽扣眼转向手机。它没有催你，但路边的测试标记亮了。",
			"choices": [
				{"id": "doll_f1_open_phone", "summary": "先打开手机", "sentence": "我先去看帖子。三个词，拼成一句完整的话。", "guide_feedback": "先打开社交媒体，再打开任意一篇帖子。"},
				{"id": "doll_f1_ask_three", "summary": "为什么是三个", "sentence": "为什么一定要三个词？少一个会发生什么？", "guide_feedback": "对象、动作、去向。少一个，手机就会替你补。"},
				{"id": "doll_f1_ask_owner", "summary": "问词属于谁", "sentence": "帖子里的词属于写下它的人，还是拾走它的人？", "guide_feedback": "先拾取。等你使用它时，再看它选择了谁。"},
			],
		}],
		"repeat_line": "它又指向手机。三个词。对象、动作、去向。",
	},
	2: {
		"doll_id": "doll_window_memory",
		"actor_label": "缝线布偶",
		"world_hint": "一栋亮窗房子背面的低坡",
		"turns": [{
			"line": "你把那句话发出去了。现在放下手机，去找医生。不要换词，只换说话的地方。",
			"result": "布偶摸了摸右眼的纽扣。相同的三个词在里面排成了另一句话。",
			"choices": [
				{"id": "doll_f2_find_doctor", "summary": "去找医生", "sentence": "我会用发布过的词，再说一次同样的句子。", "guide_feedback": "医生就在这一层，荧光测试标记会指出位置。"},
				{"id": "doll_f2_ask_change", "summary": "问词为什么会变", "sentence": "如果词没有换，为什么句子的意思会变？", "guide_feedback": "因为手机和医生都坚持自己才是词的原主人。"},
				{"id": "doll_f2_refuse_explain", "summary": "不替句子解释", "sentence": "我只把词放进去，不替任何一个世界解释。", "guide_feedback": "很好。让两个版本并排留下。"},
			],
		}],
		"repeat_line": "它重复：发布过的词才能带到医生面前。",
	},
	3: {
		"doll_id": "doll_missing_subject",
		"actor_label": "缝线布偶",
		"world_hint": "第三排立柱后的假窗内侧",
		"turns": [{
			"line": "这一层会检查你从下面带回来的东西。记录没有写数量，也没有写检查会在什么时候发生。",
			"result": "布偶腹部的缝线自己松开一针。里面不是棉花，是一小段没有登记的楼梯声。",
			"choices": [
				{"id": "doll_f3_check_items", "summary": "检查带回的东西", "sentence": "我会确认从下面带回来的东西都还在。", "guide_feedback": "不要只数口袋。也要记住是谁告诉你去找它们。"},
				{"id": "doll_f3_raise_pollution", "summary": "问检查的时机", "sentence": "要到什么时候，这一层才会承认我已经准备好？", "guide_feedback": "等语言再也装不成干净的时候，出口才会做一次检查。"},
				{
					"id": "doll_f3_ask_missing_level",
					"summary": "问不存在的楼层",
					"locked_summary": "■■还没念到这里",
					"sentence": "如果还有下一层，为什么所有记录都只写到这里？",
					"guide_feedback": "因为那一层不是被锁住，而是没有被承认。",
					"required_pollution_min": 70,
				},
			],
		}],
		"repeat_line": "它的腹部已经缝好。针脚数量和记录里的空格对不上。",
	},
}

const FLOOR_CARDS := {
	1: {"区域": "被保存的儿童房", "危险": "B", "提示": "《游戏与现实》"},
	2: {"区域": "两次醒来之间", "危险": "A", "提示": "《梦的解析》"},
	3: {"区域": "没有说完的地方", "危险": "A", "提示": "《自我与本我》"},
	4: {"区域": "未记录", "危险": "S", "提示": "《超越快乐原则》"},
}

const FLOOR_CARD_DISPLAY_VARIANTS := {
	1: {"区域": "被保存的儿童□", "危险": "B", "提示": "《游戏与现实》"},
	2: {"区域": "两次醒来之□", "危险": "A", "提示": "《梦的解□》"},
	3: {"区域": "没□说完的地□□", "危险": "A", "提示": "《自□与本我》"},
	4: {"区域": "未□□录", "危险": "S", "提示": "《超□□乐原□》"},
}

const MENU_LABEL_VARIANTS := {
	"save": {"function_id": "save", "stages": ["保存", "保 存", "留下"]},
	"autoplay": {"function_id": "autoplay", "stages": ["自动播放", "替你播放", "不用开口"]},
	"history": {"function_id": "history", "stages": ["历史记录", "已经说过", "不是你说的"]},
	"settings": {"function_id": "settings", "stages": ["设置", "修正", "恢复正常"]},
}


static func get_dialogues_for_floor(floor_number: int) -> Array:
	var entries: Array = REALITY_DIALOGUES_BY_FLOOR.get(floor_number, [])
	return entries.duplicate(true)


static func get_followups_for_archetype(archetype_index: int) -> Dictionary:
	var entry: Dictionary = REALITY_FOLLOWUPS_BY_NPC_INDEX.get(archetype_index, {})
	return entry.duplicate(true)


## The five basement rounds' NPCs, in order: the old first floor's lamp keeper, then its four pedestrians. Each route
## reuses that NPC's first-floor lines; the player's line is the key resident's right answer or the pedestrian's first
## reply.
const BASEMENT_ROUND_SPEAKERS := [
	{"key_npc_floor": 1},
	{"street_floor": 1, "npc_index": 0},
	{"street_floor": 1, "npc_index": 1},
	{"street_floor": 1, "npc_index": 2},
	{"street_floor": 1, "npc_index": 3},
]


## One basement round's fixed conversation: {actor_label, turns: [{line, sentence, result}]}; empty for no such round.
static func get_basement_route(round_number: int) -> Dictionary:
	if round_number < 1 or round_number > BASEMENT_ROUND_SPEAKERS.size():
		return {}
	var speaker: Dictionary = BASEMENT_ROUND_SPEAKERS[round_number - 1]
	var turns: Array = []
	var actor_label := ""
	if speaker.has("key_npc_floor"):
		var key_dialogue: Dictionary = KEY_NPC_DIALOGUES_BY_FLOOR.get(int(speaker["key_npc_floor"]), {})
		actor_label = str(key_dialogue.get("actor_label", ""))
		for turn: Dictionary in key_dialogue.get("turns", []):
			turns.append(_basement_turn(turn, _correct_choice(turn)))
	else:
		var npc_index := int(speaker["npc_index"])
		var opening: Dictionary = (REALITY_DIALOGUES_BY_FLOOR.get(int(speaker["street_floor"]), []) as Array)[npc_index]
		actor_label = str(opening.get("speaker", ""))
		turns.append(_basement_turn(opening, _first_choice(opening)))
		for turn: Dictionary in (REALITY_FOLLOWUPS_BY_NPC_INDEX.get(npc_index, {}) as Dictionary).get("turns", []):
			turns.append(_basement_turn(turn, _first_choice(turn)))
	return {"actor_label": actor_label, "turns": turns}


static func _basement_turn(turn: Dictionary, choice: Dictionary) -> Dictionary:
	return {
		"line": str(turn.get("line", "")),
		"sentence": str(choice.get("sentence", "")),
		"result": str(turn.get("result", "")),
	}


static func _correct_choice(turn: Dictionary) -> Dictionary:
	for choice: Dictionary in turn.get("choices", []):
		if bool(choice.get("correct", false)):
			return choice
	return _first_choice(turn)


static func _first_choice(turn: Dictionary) -> Dictionary:
	var choices: Array = turn.get("choices", [])
	return choices[0] if not choices.is_empty() else {}


static func get_language_persona_scenes() -> Array:
	return LANGUAGE_PERSONA_SCENES.duplicate(true)


static func get_authored_critical_corruptions() -> Array:
	return AUTHORED_CRITICAL_CORRUPTIONS.duplicate(true)


static func get_protected_texts() -> Array:
	return PROTECTED_TEXTS.duplicate()


static func get_protected_punctuation() -> Array:
	return PROTECTED_PUNCTUATION.duplicate()


static func get_player_choice_fragments_for_floor(floor_number: int) -> Array:
	var entries: Array = PLAYER_CHOICE_FRAGMENTS_BY_FLOOR.get(floor_number, [])
	return entries.duplicate(true)


static func get_history_revisions() -> Array:
	return HISTORY_REVISIONS.duplicate(true)


static func get_floor_card(floor_number: int) -> Dictionary:
	var card: Dictionary = FLOOR_CARDS.get(floor_number, {})
	return card.duplicate(true)


static func get_key_npc_dialogue_for_floor(floor_number: int) -> Dictionary:
	var dialogue: Dictionary = KEY_NPC_DIALOGUES_BY_FLOOR.get(floor_number, {})
	return dialogue.duplicate(true)


static func get_doll_encounter_for_floor(floor_number: int) -> Dictionary:
	var encounter: Dictionary = DOLL_ENCOUNTERS_BY_FLOOR.get(floor_number, {})
	return encounter.duplicate(true)


static func get_doll_encounter_by_id(doll_id: String) -> Dictionary:
	for floor_number in [1, 2, 3]:
		var encounter: Dictionary = DOLL_ENCOUNTERS_BY_FLOOR.get(floor_number, {})
		if str(encounter.get("doll_id", "")) == doll_id:
			return encounter.duplicate(true)
	return {}


static func get_doll_ids() -> Array[String]:
	var doll_ids: Array[String] = []
	for floor_number in [1, 2, 3]:
		var doll_id := str((DOLL_ENCOUNTERS_BY_FLOOR.get(floor_number, {}) as Dictionary).get("doll_id", ""))
		if not doll_id.is_empty():
			doll_ids.append(doll_id)
	return doll_ids


static func get_floor_card_display(floor_number: int) -> Dictionary:
	var card: Dictionary = FLOOR_CARD_DISPLAY_VARIANTS.get(floor_number, FLOOR_CARDS.get(floor_number, {}))
	return card.duplicate(true)


static func get_menu_label_variants() -> Dictionary:
	return MENU_LABEL_VARIANTS.duplicate(true)


static func get_all_choice_ids() -> Array[String]:
	var ids: Array[String] = []
	for floor_number in [1, 2, 3]:
		for dialogue: Dictionary in get_dialogues_for_floor(floor_number):
			for choice: Dictionary in dialogue.get("choices", []):
				ids.append(str(choice.get("id", "")))
	for archetype_index in range(5):
		var followup: Dictionary = get_followups_for_archetype(archetype_index)
		for turn: Dictionary in followup.get("turns", []):
			for choice: Dictionary in turn.get("choices", []):
				ids.append(str(choice.get("id", "")))
	return ids


static func get_catalog_snapshot() -> Dictionary:
	return {
		"dialogues": REALITY_DIALOGUES_BY_FLOOR.duplicate(true),
		"followups": REALITY_FOLLOWUPS_BY_NPC_INDEX.duplicate(true),
		"persona_scenes": LANGUAGE_PERSONA_SCENES.duplicate(true),
		"critical_corruptions": AUTHORED_CRITICAL_CORRUPTIONS.duplicate(true),
		"protected_texts": PROTECTED_TEXTS.duplicate(),
		"protected_punctuation": PROTECTED_PUNCTUATION.duplicate(),
		"choice_fragments": PLAYER_CHOICE_FRAGMENTS_BY_FLOOR.duplicate(true),
		"history_revisions": HISTORY_REVISIONS.duplicate(true),
		"key_npc_dialogues": KEY_NPC_DIALOGUES_BY_FLOOR.duplicate(true),
		"doll_encounters": DOLL_ENCOUNTERS_BY_FLOOR.duplicate(true),
		"floor_cards": FLOOR_CARDS.duplicate(true),
		"floor_card_display_variants": FLOOR_CARD_DISPLAY_VARIANTS.duplicate(true),
		"menu_labels": MENU_LABEL_VARIANTS.duplicate(true),
	}
