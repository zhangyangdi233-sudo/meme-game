class_name MemeGameState
extends RefCounted

const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const LanguageBridgeScript = preload("res://scripts/narrative/language_bridge.gd")
const TutorialDirectorScript = preload("res://scripts/tutorial/tutorial_director.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const MAX_TOWER_FLOOR := 4
const POLLUTION_FLOOR_THRESHOLDS := {1: 25, 2: 60, 3: 80}
const PREREQUISITE_ITEMS := {
	1: {
		"id": "artifact_named_lamp_tag",
		"label": "写着“小月亮”的旧名牌",
		"location_hint": "沿主路往前走，在右侧第一盏不亮的路灯脚边。",
	},
	2: {
		"id": "artifact_reversed_tape",
		"label": "两面都录着同一句话的磁带",
		"location_hint": "在与你醒来位置相反的低坡上，贴着一栋亮窗房子的门前。",
	},
	3: {
		"id": "artifact_missing_subject_page",
		"label": "缺少主语的病历页",
		"location_hint": "沿中央通道走过第三排立柱，夹在左侧那扇假窗下面。",
	},
}
const HISTORY_FIELD_NAMES := [
	"lineId", "originalSpeaker", "currentSpeaker", "originalText",
	"displayText", "revisionStage", "revisionMarkup",
]
const POLLUTION_FLASHBACK_THRESHOLD := 60
const BASE_ACTIONS_PER_DAY := 5
const LANGUAGE_RECIPE_SLOTS := [
	{"id": "subject", "label": "谁 / 什么", "placeholder": "放入主语", "accepted_role": "subject"},
	{"id": "action", "label": "发生了什么", "placeholder": "放入动作", "accepted_role": "action"},
	{"id": "object", "label": "对谁 / 在哪里", "placeholder": "放入落点", "accepted_role": "object"},
]
const DOCTOR_DIALOGUES_BY_FLOOR := {
	1: {"line": "把你刚才放进手机的句子再说一遍。不要替它解释。", "result": "医生记下的句子和你记得的并不相同。"},
	2: {"line": "你从屏幕里带回了哪些词？按你认为原本的顺序说。", "result": "医生在每个词旁边写下另一种用途。"},
	3: {"line": "请只使用仍属于你的词，描述你现在在哪里。", "result": "医生停笔。病历上的主语比你先消失。"},
	4: {"line": "这些词没有来源。你还坚持它们是你选的吗？", "result": "没有人替这句话登记说话者。"},
}
const REALITY_DIALOGUES_BY_FLOOR := {
	1: [
		{"line": "你也在等那班已经经过、但谁都没看见的车吗？", "result": "迟到者看了一眼空荡荡的站牌，像是在替它保守秘密。", "choices": [
			{"id": "f1n0_wait", "summary": "一起等", "sentence": "我没有看见那班车，但我可以陪你再等一会儿。"},
			{"id": "f1n0_time", "summary": "核对时间", "sentence": "站牌上的时间没有变，也许车还没有真正经过。"},
			{"id": "f1n0_leave", "summary": "先离开", "sentence": "如果下一班也没有声音，我们就沿着路走回去。"},
		]},
		{"line": "楼上的水管昨晚喊了我的名字。你住哪一户？", "result": "回声住户把钥匙攥紧了一点，管道在墙里轻轻敲了三下。", "choices": [
			{"id": "f1n1_home", "summary": "说出住处", "sentence": "我住在路尽头那扇总是关不严的门后面。"},
			{"id": "f1n1_pipe", "summary": "问水管", "sentence": "也许水管只是记住了你每天回家的脚步声。"},
			{"id": "f1n1_name", "summary": "确认名字", "sentence": "它喊的是你的名字，还是住在这里的每一个名字？"},
		]},
		{"line": "我把门牌抄了三遍，每一遍都少一个人。你能替我数吗？", "result": "抄写员没有递出纸，只把空着的第四行折进掌心。", "choices": [
			{"id": "f1n2_count", "summary": "重新数", "sentence": "我们从第一扇门开始，名字和门牌分开数。"},
			{"id": "f1n2_blank", "summary": "保留空行", "sentence": "少掉的人也许需要一个空位置，而不是另一个名字。"},
			{"id": "f1n2_stop", "summary": "停止抄写", "sentence": "先别写第四遍，纸可能正在学习怎样删掉人。"},
		]},
		{"line": "你刚才抬头了吗？塔上掉下来一片像收据的云。", "result": "无名信徒把那片不存在的纸塞进口袋，动作十分熟练。", "choices": [
			{"id": "f1n3_sky", "summary": "描述天空", "sentence": "我只看见绿色的天，云上没有刻度，也没有日期。"},
			{"id": "f1n3_receipt", "summary": "索要收据", "sentence": "如果它真是收据，上面应该写着是谁买下了这座塔。"},
			{"id": "f1n3_ground", "summary": "看着地面", "sentence": "我没有抬头，我怕地面趁机换掉回去的方向。"},
		]},
		{"line": "我在十年前的帖子里看见今天的你。那是你吗？", "result": "旧帖目击者没有展示截图，屏幕却自行亮了一瞬。", "choices": [
			{"id": "f1n4_yes", "summary": "承认", "sentence": "如果照片里的我正在等今天，那个人也可以算是我。"},
			{"id": "f1n4_no", "summary": "否认", "sentence": "十年前我不在这里，帖子也不该记得我的脸。"},
			{"id": "f1n4_reply", "summary": "留下回复", "sentence": "请替我回复一句，让过去不要继续往前翻页。"},
		]},
	],
	2: [
		{"line": "先说上一层留下的那句话，再告诉我你为什么迟到。顺序不能反。", "result": "迟到者认真听完规定的部分，剩下的话被风带到很远。", "choices": [
			{"id": "f2n0_order", "summary": "照顺序说", "sentence": "我会先念完屏幕教我的那句，然后说明路口为什么没有放我过去。"},
			{"id": "f2n0_reason", "summary": "先说理由", "sentence": "我迟到是因为那条路反复把我送回同一块路牌。"},
			{"id": "f2n0_refuse", "summary": "拒绝顺序", "sentence": "如果原因只能排在旧话后面，它就不再是我的原因。"},
		]},
		{"line": "这层每户都要保管一句旧话。我家的那句半夜会自己换位置。", "result": "回声住户点了点头，像是刚完成一次例行点名。", "choices": [
			{"id": "f2n1_lock", "summary": "锁住它", "sentence": "把那句话写在门背后，也许它就找不到新的房间。"},
			{"id": "f2n1_follow", "summary": "记录移动", "sentence": "今晚记下它每次换位置的时间，不要改动其中的字。"},
			{"id": "f2n1_return", "summary": "送回楼下", "sentence": "旧话来自上一层，我们可以沿楼梯把它送回原处。"},
		]},
		{"line": "登记表说你已经回答过了。可我这里还是空白。", "result": "抄写员在空白处盖章，印泥发出一声很轻的叹息。", "choices": [
			{"id": "f2n2_again", "summary": "再回答", "sentence": "我可以再说一次，但请保留这次说话留下的空白。"},
			{"id": "f2n2_record", "summary": "质疑记录", "sentence": "表格记住的是动作，不一定记住了我真正说过什么。"},
			{"id": "f2n2_stamp", "summary": "请求盖章", "sentence": "请先证明这里曾经空着，再把我的句子写进去。"},
		]},
		{"line": "我们不再问你叫什么。我们只核对手机替你说过哪一句话。", "result": "无名信徒在听见屏幕用词时微笑，在听见其余内容时闭上眼睛。", "choices": [
			{"id": "f2n3_name", "summary": "坚持名字", "sentence": "那句话跟着我，但我的名字仍然应该先于它出现。"},
			{"id": "f2n3_legacy", "summary": "出示旧句", "sentence": "我带着上一层最响的句子，它比我更容易被认出来。"},
			{"id": "f2n3_none", "summary": "声称空手", "sentence": "我想试着什么都不携带，只用今天剩下的词站在这里。"},
		]},
	],
	3: [
		{"line": "请提交一句未被使用过的自己。重复部分将退回上一窗口。", "result": "迟到者撕下回执，纸的背面印着同一张回执。", "choices": [
			{"id": "f3n0_submit", "summary": "提交原句", "sentence": "这句话只在现在出现，请不要替它补上以前的编号。"},
			{"id": "f3n0_copy", "summary": "承认重复", "sentence": "我借用了旧句子的结构，但其中的犹豫是今天才有的。"},
			{"id": "f3n0_window", "summary": "寻找窗口", "sentence": "上一窗口已经封死，我只能把退件留在这里。"},
		]},
		{"line": "你所在的住处已被归类为比喻。实体住址需要另行申请。", "result": "回声住户把申请表对折，折痕恰好穿过自己的地址。", "choices": [
			{"id": "f3n1_actual", "summary": "申报实体", "sentence": "我的房间有墙和门，也有一盏会在凌晨熄灭的灯。"},
			{"id": "f3n1_metaphor", "summary": "接受比喻", "sentence": "如果住处只是比喻，请注明我究竟被比作了什么。"},
			{"id": "f3n1_nohome", "summary": "撤销地址", "sentence": "取消我的地址吧，这样回去的时候就不会再次走错。"},
		]},
		{"line": "缺失人员栏不能留空。请填写一个仍然存在的人。", "result": "抄写员将答案归档，抽屉里传来某个人翻身的声音。", "choices": [
			{"id": "f3n2_self", "summary": "填写自己", "sentence": "先写我的名字，至少此刻我还站在表格外面。"},
			{"id": "f3n2_missing", "summary": "保留缺失", "sentence": "缺失不是空白，它是一个人离开后留下的准确形状。"},
			{"id": "f3n2_drawer", "summary": "询问抽屉", "sentence": "请打开抽屉，里面的人也许知道自己是否仍然存在。"},
		]},
	],
	4: [
		{"line": "我们唱到你的名字时，请不要回答。回答会破坏和声。", "result": "合唱没有停下，只在主角应该出现的位置稍微变调。", "choices": [
			{"id": "f4n0_silence", "summary": "保持沉默", "sentence": "我会让名字从我身边经过，不把它认领回来。"},
			{"id": "f4n0_answer", "summary": "打断合唱", "sentence": "那是我的名字，它不该只作为你们旋律里的一个音。"},
			{"id": "f4n0_hum", "summary": "轻声跟唱", "sentence": "我只跟着最后一个音，不唱名字，也不唱塔。"},
		]},
		{"line": "圣歌需要一个空位。大家一致认为那个位置很像你。", "result": "无名信徒向旁边挪开半步，空位却仍然跟着主角。", "choices": [
			{"id": "f4n1_enter", "summary": "站进空位", "sentence": "我可以站在那里，但不会把沉默假装成赞同。"},
			{"id": "f4n1_decline", "summary": "拒绝位置", "sentence": "像我不等于属于我，请把那个位置继续空着。"},
			{"id": "f4n1_ask", "summary": "询问缺席者", "sentence": "这个空位原来属于谁，你们为什么不再唱那个人？"},
		]},
	],
}
const REALITY_FOLLOWUPS_BY_NPC_INDEX := {
	0: {
		"turns": [
			{"line": "站牌忽然显示“无信号”。可这条街从来没有接入过线路。你还要等吗？", "result": "迟到者把手机举向塔影，屏幕上的叉号短暂变成一扇门。", "choices": [
				{"id": "late_signal_wait", "summary": "继续等候", "sentence": "再等一班吧；没有线路，不等于没有人正试着抵达。"},
				{"id": "late_signal_tower", "summary": "追查塔影", "sentence": "信号也许不是从天上消失，而是被塔一层层收走了。"},
				{"id": "late_signal_walk", "summary": "沿路步行", "sentence": "我们顺着屏幕留下的标记走，看看旧句子把终点改到了哪里。"},
			]},
			{"line": "车终于来了。报站器只念上一层留下的梗，不再念地名。你在哪里下车？", "result": "迟到者在没有地名的一站按铃。车门打开，塔的影子没有跟下来。", "choices": [
				{"id": "late_stop_today", "summary": "旧句之后", "sentence": "等它念完屏幕借来的话，我要在第一个属于今天的停顿下车。"},
				{"id": "late_stop_silence", "summary": "沉默站点", "sentence": "没有报站声的地方就是我的站，至少那里还没有被命名。"},
				{"id": "late_stop_own", "summary": "留在车上", "sentence": "我先不下车，直到有人用自己的话说出一个方向。"},
			]},
		],
		"interrupt": "报站声被污染成连续的旧梗。迟到者捂住听筒，车还没有来，谈话先驶远了。",
	},
	1: {
		"turns": [
			{"line": "墙里的回声开始替我们回答，而且每次都比原话多一句屏幕里的旧话。要把哪一句留下？", "result": "回声住户贴近墙面，听见自己的声音从更高一层缓慢返回。", "choices": [
				{"id": "echo_keep_original", "summary": "留下原话", "sentence": "只留下我们刚才说的句子，旧话可以经过，但不要冒充回声。"},
				{"id": "echo_mark_legacy", "summary": "标记旧话", "sentence": "把多出来的旧话标上来源，让它不能假装今天才出生。"},
				{"id": "echo_close_pipe", "summary": "关闭管道", "sentence": "先关掉这段管道，沉默也比被替写的回答更诚实。"},
			]},
			{"line": "水龙头流出一串陌生口音。住户说这就是语言污染的味道。你怎么确认还是水？", "result": "回声住户接住一滴无声的水。它没有复述任何人，钥匙终于松开。", "choices": [
				{"id": "echo_check_reflection", "summary": "观察倒影", "sentence": "如果倒影还会被波纹打断，它至少没有完全变成一句口号。"},
				{"id": "echo_try_name", "summary": "尝试命名", "sentence": "先叫它水一次；如果它立刻要求复读，我们就换一个杯子。"},
				{"id": "echo_leave_nameless", "summary": "保持无名", "sentence": "不急着命名，让它在语言找到之前先作为液体留下。"},
			]},
		],
		"interrupt": "管道抢先说完所有答案。回声住户关上阀门，墙里仍有人继续这场谈话。",
	},
	2: {
		"turns": [
			{"line": "档案柜要求给你的每句话填写“词语来源”。原创一栏已经被涂黑。你填什么？", "result": "抄写员把表格转过来，背面密密麻麻都是尚未发生的引用。", "choices": [
				{"id": "copy_source_now", "summary": "填写此刻", "sentence": "来源写此刻；这句话也许借过词，但犹豫是我自己的。"},
				{"id": "copy_refuse_source", "summary": "拒绝来源", "sentence": "我不替活着的话伪造祖先，请把这一栏保持空白。"},
				{"id": "copy_mark_pollution", "summary": "登记污染", "sentence": "标注语言污染；相似不一定是继承，也可能是感染。"},
			]},
			{"line": "盖章机说，未被塔收录的句子不算存在。抄写员把印章递给你。", "result": "抄写员收回没有落下的印章，把你的句子夹进两页制度之间。", "choices": [
				{"id": "copy_no_stamp", "summary": "不盖印章", "sentence": "存在不该由塔批准；让这句话带着空白离开档案。"},
				{"id": "copy_edge_stamp", "summary": "盖在边缘", "sentence": "只盖在纸的边缘，证明制度碰过它，却没有拥有它。"},
				{"id": "copy_rewrite_rule", "summary": "改写条款", "sentence": "先把条款改成“说出即存在”，再决定是否需要印章。"},
			]},
		],
		"interrupt": "盖章机吞掉了句子的主语。抄写员拉下断电杆，本次登记以空白中止。",
	},
	3: {
		"turns": [
			{"line": "塔里的发射机没有接线，信徒却说每晚都能收到圣歌。你认为声音从哪里来？", "result": "无名信徒仰头辨认那段旋律，塔窗一层接一层地亮错顺序。", "choices": [
				{"id": "believer_crowd", "summary": "来自人群", "sentence": "也许是人群在塔下互相复述，最后忘了第一句话属于谁。"},
				{"id": "believer_legacy", "summary": "来自旧帖", "sentence": "旧帖里的句子会自己寻找嗓子，圣歌只是它们同时借到人的时刻。"},
				{"id": "believer_static", "summary": "来自静电", "sentence": "没有信号时，静电也会被当成启示；先别急着跪下。"},
			]},
			{"line": "信徒请你献出一句不会污染别人的话，作为进入上层的圣歌。", "result": "无名信徒没有唱你的句子，只把它安静地留在门外。塔门第一次自己开了。", "choices": [
				{"id": "believer_question", "summary": "保留疑问", "sentence": "我只能献出一个问题：我们是否允许别人不回答。"},
				{"id": "believer_names", "summary": "归还名字", "sentence": "把每个人的名字还给本人，不把它们编进共同的副歌。"},
				{"id": "believer_pause", "summary": "献出停顿", "sentence": "我献出一句话结束后的停顿，让下一人有地方开口。"},
			]},
		],
		"interrupt": "圣歌突然只剩同一个梗。无名信徒停止合唱，塔门在污染扩散前合上。",
	},
	4: {
		"turns": [
			{"line": "旧帖显示这里“信号满格”，可所有回复都写着十年后发送。你要点开哪一条？", "result": "旧帖目击者滑动屏幕，日期栏像坏掉的电梯一样上下跳动。", "choices": [
				{"id": "post_earliest", "summary": "最早回复", "sentence": "打开最早的一条，看看是谁先把未来误认成了旧记录。"},
				{"id": "post_unsent", "summary": "未发回复", "sentence": "打开那条尚未发送的，也许它还来得及换一种说法。"},
				{"id": "post_close", "summary": "关闭帖子", "sentence": "先关掉帖子；无信号时，时间不该假装自己已经上传。"},
			]},
			{"line": "最后一条回复只剩三个被划掉的词。帖子问：这句话原本是谁说的？", "result": "旧帖目击者没有截屏。三个词自行保存，却把说话者留成空白。", "choices": [
				{"id": "post_leave_exist", "summary": "留下存在", "sentence": "留下“存在”；过去需要知道我们没有只活成引用。"},
				{"id": "post_leave_signal", "summary": "留下无信号", "sentence": "留下“无信号”；让未来明白沉默也可能是线路断了。"},
				{"id": "post_leave_nothing", "summary": "什么不留", "sentence": "什么都不留；过去不该提前继承我们尚未说完的话。"},
			]},
		],
		"interrupt": "帖子开始自动复制你尚未说出的词。旧帖目击者拔掉电源，屏幕仍亮在中断处。",
	},
}
const REALITY_CORRUPTION_GLYPHS := ["■", "▦", "∴", "//", "□", "▧", "≠", "…"]
const PROTECTED_PUNCTUATION := ["，", "。", "！", "？", "；", "：", "、", "…", ",", ".", "!", "?", ";", ":", "\"", "'", "（", "）", "(", ")"]
const ENDING_LANGUAGE_CHOICES := [
	{"id": "blank", "label": "空白", "output": "（空白）"},
	{"id": "blocks", "label": "■■■■", "output": "■ ■ ■ ■"},
	{"id": "hajimi", "label": "哈吉米", "output": "哈吉米"},
	{"id": "silence", "label": "沉默", "output": "……"},
]
const PROLOGUE_LINES := [
	"（先确认一件事。你手里拿着什么？）",
	"一部没有信号的手机。它在我醒来以前就亮着。",
	"（你在等谁的消息？）",
	"不。我在等路面停止向后移动。它每退一步，塔就多出一层。",
	"城市广播说今天一切正常。广播重复了七次，正常因此变成一个可疑的词。",
	"（从哪里开始？）",
	"从三个词开始。先让它们组成一句完整的话，再看这句话到了另一个世界会变成什么。",
]
const EPILOGUE_LINES := [
	"所有被发布过的句子都说智者住在这里。这里没有智者。",
	"塔顶只有一台没有接线的发射机。指示灯按照你的呼吸闪烁。",
	"（它在发送什么？）",
	"你把耳朵贴近外壳。里面传来整座城市的声音，每个人都在准确重复别人。",
	"你想说一句普通的话。每一层却先替你开口。",
]
const SAVE_DATA_VERSION := 5
const SAVE_FIELD_NAMES := [
	"day", "pollution", "tower_floor",
	"ending_unlocked", "ending_language_choice", "ending_route", "formal_floor_three_complete",
	"pending_floor_transition", "autoplay_enabled", "exit_prompt_seen",
	"money", "actions_remaining", "max_actions_per_day",
	"needs_day_settlement", "day_ended_reason", "pollution_flashback_seen", "pollution_flashback_pending",
	"view_state", "phone_visible", "phone_open", "active_app", "active_app_window",
	"notebook_tokens", "draft_slots", "completed_memes", "owned_meme_frames", "owned_meme_frame_ids",
	"claimed_doll_ids", "doll_choice_results",
	"fusion_slots", "fused_meme_pairs", "dialogue_blanks", "published_memes", "last_publish_result",
	"event_log", "social_followed_handles", "social_liked_post_ids", "collected_world_item_ids",
	"cover_watcher_seen_floors",
	"revealed_prerequisite_item_ids", "collected_prerequisite_item_ids", "key_clue_progress",
	"history_entries",
	"language_sentence_slots", "sentence_records", "tutorial_progress",
	"collected_char_units", "last_char_pick_day",
	"last_clean_sentence", "last_polluted_sentence",
	"npc_understanding", "reality_phase", "relationship_residue", "last_relationship_residue_gain",
	"last_relationship_money_loss", "reality_dialogue_count",
]

var day: int = 1
var pollution: int = 0
var tower_floor: int = 1
var ending_unlocked: bool = false
var ending_language_choice: String = ""
var ending_route: String = ""
var formal_floor_three_complete: bool = false
var pending_floor_transition: int = 0
var autoplay_enabled: bool = false
var exit_prompt_seen: bool = false
var money: int = 18
var actions_remaining: int = 5
var max_actions_per_day: int = 5
var needs_day_settlement: bool = false
var day_ended_reason: String = ""
var pollution_flashback_seen: bool = false
var pollution_flashback_pending: bool = false

var view_state: String = "phone_down"
var phone_visible: bool = true
var phone_open: bool = true
var active_app: String = "social"
var active_app_window: String = "social"

var notebook_tokens: Array = []
var draft_slots: Dictionary = {}
var completed_memes: Array = []
var owned_meme_frames: int = 0
var owned_meme_frame_ids: Array[String] = []
var claimed_doll_ids: Array[String] = []
var doll_choice_results: Dictionary = {}
var fusion_slots: Dictionary = {}
var fused_meme_pairs: Array[String] = []
var dialogue_blanks: Dictionary = {}
var published_memes: Array = []
var last_publish_result: Dictionary = {}
var event_log: Array[String] = []
var social_followed_handles: Array[String] = []
var social_liked_post_ids: Array[String] = []

var collected_world_item_ids: Array[String] = []
var cover_watcher_seen_floors: Array[int] = []
var revealed_prerequisite_item_ids: Array[String] = []
var collected_prerequisite_item_ids: Array[String] = []
var key_clue_progress: Dictionary = {}
var history_entries: Array = []

var language_sentence_slots: Dictionary = {}
var sentence_records: Array = []
var tutorial_progress: Dictionary = {}
var collected_char_units: Array = []
var last_char_pick_day: int = 0
var last_clean_sentence: String = ""
var last_polluted_sentence: String = ""
var npc_understanding: int = 100
var reality_phase: String = "npc_speaking"
var relationship_residue: int = 0
var last_relationship_residue_gain: int = 0
var last_relationship_money_loss: int = 0
var reality_dialogue_count: int = 0
var conversation_phase: String = "idle"
var conversation_actor_id: String = ""
var conversation_actor_type: String = "npc"
var conversation_actor_label: String = ""
var conversation_prompt: String = ""
var conversation_result_line: String = ""
var conversation_choices: Array = []
var conversation_selected_choice_id: String = ""
var conversation_clean_sentence: String = ""
var conversation_revealed_units: Array = []
var conversation_reveal_index: int = 0
var conversation_attempts: int = 0
var conversation_understood: bool = false
var conversation_understanding_rolls: Array[int] = []
var conversation_feedback: String = ""
var conversation_locale: String = "zh"
var conversation_clean_units: Array[String] = []
var conversation_mode: String = "authored"
var conversation_world: String = "reality"
var conversation_selected_token_ids: Array[String] = []
var conversation_turns: Array = []
var conversation_turn_index: int = 0
var conversation_history: Array = []
var conversation_can_continue: bool = false
var conversation_completed: bool = false
var conversation_interrupted: bool = false
var conversation_interrupt_line: String = ""
var conversation_action_spent: bool = false
var conversation_reward: Dictionary = {}


func new_run() -> void:
	day = 1
	pollution = 0
	tower_floor = 1
	ending_unlocked = false
	ending_language_choice = ""
	ending_route = ""
	formal_floor_three_complete = false
	pending_floor_transition = 0
	autoplay_enabled = false
	exit_prompt_seen = false
	money = 18
	max_actions_per_day = BASE_ACTIONS_PER_DAY
	actions_remaining = max_actions_per_day
	needs_day_settlement = false
	day_ended_reason = ""
	pollution_flashback_seen = false
	pollution_flashback_pending = false
	view_state = "phone_down"
	phone_visible = true
	phone_open = true
	active_app = "social"
	active_app_window = "social"
	notebook_tokens = []
	draft_slots = {}
	completed_memes = []
	owned_meme_frames = 0
	owned_meme_frame_ids = []
	claimed_doll_ids = []
	doll_choice_results = {}
	fusion_slots = {}
	fused_meme_pairs = []
	dialogue_blanks = {}
	published_memes = []
	last_publish_result = {}
	event_log = []
	social_followed_handles = []
	social_liked_post_ids = []
	collected_world_item_ids = []
	cover_watcher_seen_floors = []
	revealed_prerequisite_item_ids = []
	collected_prerequisite_item_ids = []
	key_clue_progress = {}
	history_entries = []
	language_sentence_slots = {}
	sentence_records = []
	collected_char_units = []
	last_char_pick_day = 0
	tutorial_progress = TutorialDirectorScript.initial_progress()
	last_clean_sentence = ""
	last_polluted_sentence = ""
	npc_understanding = 100
	reality_phase = "npc_speaking"
	relationship_residue = 0
	last_relationship_residue_gain = 0
	last_relationship_money_loss = 0
	reality_dialogue_count = 0
	reset_typed_reality_conversation()


func notify_tutorial(event_id: String, payload: Dictionary = {}) -> Dictionary:
	tutorial_progress = TutorialDirectorScript.notify(tutorial_progress, StringName(event_id), payload)
	return get_tutorial_step()


func get_tutorial_step() -> Dictionary:
	return TutorialDirectorScript.current_step(tutorial_progress)


func skip_tutorial() -> void:
	tutorial_progress = TutorialDirectorScript.skip(tutorial_progress)


func replay_tutorial() -> void:
	tutorial_progress = TutorialDirectorScript.replay(tutorial_progress)


func to_save_data() -> Dictionary:
	var state_data := {}
	for field_name in SAVE_FIELD_NAMES:
		var value: Variant = get(field_name)
		state_data[field_name] = value.duplicate(true) if value is Array or value is Dictionary else value
	return {
		"version": SAVE_DATA_VERSION,
		"state": state_data,
	}


func load_save_data(save_data: Dictionary) -> bool:
	var loaded_version := int(save_data.get("version", -1))
	if loaded_version not in [1, 2, 3, 4, SAVE_DATA_VERSION]:
		return false
	var state_data: Variant = save_data.get("state", {})
	if not state_data is Dictionary:
		return false
	var saved_floor := int((state_data as Dictionary).get("tower_floor", 1))
	new_run()
	for field_name in SAVE_FIELD_NAMES:
		if not state_data.has(field_name):
			continue
		var value: Variant = state_data[field_name]
		set(field_name, value.duplicate(true) if value is Array or value is Dictionary else value)
	day = maxi(1, day)
	tower_floor = clampi(tower_floor, 1, MAX_TOWER_FLOOR)
	max_actions_per_day = maxi(1, max_actions_per_day)
	actions_remaining = clampi(actions_remaining, 0, max_actions_per_day)
	pollution = clampi(pollution, 0, 100)
	if loaded_version < 4 and saved_floor >= 4:
		tower_floor = 3
		ending_unlocked = false
		ending_route = ""
		formal_floor_three_complete = false
		pending_floor_transition = 0
	if loaded_version < 4 and saved_floor < 4:
		_migrate_legacy_hidden_route_data(state_data as Dictionary)
	var normalized_watcher_floors: Array[int] = []
	for floor_value in cover_watcher_seen_floors:
		var floor_number := clampi(int(floor_value), 1, MAX_TOWER_FLOOR)
		if floor_number not in normalized_watcher_floors:
			normalized_watcher_floors.append(floor_number)
	cover_watcher_seen_floors = normalized_watcher_floors
	_normalize_removed_shop_state()
	_normalize_doll_state()
	_normalize_language_bridge_state(loaded_version)
	tutorial_progress = TutorialDirectorScript.normalize_progress(tutorial_progress)
	if view_state != "phone_down" and view_state != "npc_up":
		view_state = "phone_down"
	reset_typed_reality_conversation()
	return true


func _normalize_language_bridge_state(loaded_version: int) -> void:
	var normalized_tokens: Array = []
	for token_index in notebook_tokens.size():
		var token_value: Variant = notebook_tokens[token_index]
		if token_value is Dictionary:
			var token: Dictionary = (token_value as Dictionary).duplicate(true)
			if not token.get("grammar_roles", null) is Array or (token.get("grammar_roles", []) as Array).is_empty():
				token["grammar_roles"] = [str(LANGUAGE_RECIPE_SLOTS[token_index % LANGUAGE_RECIPE_SLOTS.size()].get("accepted_role", "subject"))]
			if str(token.get("lexeme_id", "")).is_empty():
				token["lexeme_id"] = str(token.get("id", "token-%d" % token_index))
			normalized_tokens.append(LanguageBridgeScript.normalized_token(token))
	notebook_tokens = normalized_tokens
	if loaded_version <= 4:
		language_sentence_slots.clear()
		reality_phase = "npc_speaking"
	var filtered_log: Array[String] = []
	for entry in event_log:
		var text := str(entry)
		if not text.contains("遗产规则"):
			filtered_log.append(text)
	event_log = filtered_log


func _migrate_legacy_hidden_route_data(state_data: Dictionary) -> void:
	var legacy_fragments: Array = state_data.get("collected_echo_fragment_ids", [])
	var legacy_fragment_ids := ["echo_room_name", "echo_safe_place", "echo_blank_voice"]
	var item_ids := get_prerequisite_item_ids()
	for index in legacy_fragment_ids.size():
		if legacy_fragment_ids[index] not in legacy_fragments:
			continue
		var item_id := str(item_ids[index])
		if item_id not in revealed_prerequisite_item_ids:
			revealed_prerequisite_item_ids.append(item_id)
		if item_id not in collected_prerequisite_item_ids:
			collected_prerequisite_item_ids.append(item_id)
		if item_id not in collected_world_item_ids:
			collected_world_item_ids.append(item_id)
	var legacy_keys: Array = state_data.get("completed_dialogue_key_ids", [])
	var legacy_key_to_floor := {
		"dialogue_key_name": 1,
		"dialogue_key_source": 2,
		"dialogue_key_voice": 3,
	}
	for legacy_key in legacy_keys:
		var floor_number := int(legacy_key_to_floor.get(str(legacy_key), 0))
		if floor_number == 0:
			continue
		var item_id := str(item_ids[floor_number - 1])
		if item_id not in revealed_prerequisite_item_ids:
			revealed_prerequisite_item_ids.append(item_id)


func _normalize_removed_shop_state() -> void:
	if active_app == "shop":
		active_app = "social"
	if active_app_window == "shop":
		active_app_window = "social" if phone_open else ""


func _normalize_doll_state() -> void:
	var known_doll_ids: Array[String] = LanguageCorruptionContentScript.get_doll_ids()
	var normalized_claims: Array[String] = []
	for doll_id in claimed_doll_ids:
		var normalized_id := str(doll_id)
		if normalized_id in known_doll_ids and normalized_id not in normalized_claims:
			normalized_claims.append(normalized_id)
	claimed_doll_ids = normalized_claims

	var normalized_results := {}
	for doll_id in claimed_doll_ids:
		var result: Variant = doll_choice_results.get(doll_id, {})
		if not result is Dictionary:
			continue
		var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_by_id(doll_id)
		var choice_id := str((result as Dictionary).get("choice_id", ""))
		var choice: Dictionary = _doll_choice_by_id(encounter, choice_id)
		if choice.is_empty():
			continue
		normalized_results[doll_id] = {
			"choice_id": choice_id,
			"day": maxi(1, int((result as Dictionary).get("day", 1))),
			"floor": clampi(int((result as Dictionary).get("floor", 1)), 1, 3),
		}
	doll_choice_results = normalized_results

	var normalized_frame_ids: Array[String] = []
	for frame_id in owned_meme_frame_ids:
		var normalized_id := str(frame_id).strip_edges()
		if not normalized_id.is_empty():
			normalized_frame_ids.append(normalized_id)
	owned_meme_frame_ids = normalized_frame_ids
	owned_meme_frames = maxi(0, owned_meme_frames)
	while owned_meme_frame_ids.size() < owned_meme_frames:
		owned_meme_frame_ids.append("legacy_frame_%d" % (owned_meme_frame_ids.size() + 1))
	if owned_meme_frame_ids.size() > owned_meme_frames:
		owned_meme_frames = owned_meme_frame_ids.size()


func set_phone_open(value: bool) -> void:
	phone_open = value
	phone_visible = value
	if not value:
		active_app_window = ""


func set_view_state(value: String) -> bool:
	if value != "phone_down" and value != "npc_up":
		return false
	view_state = value
	if view_state == "phone_down":
		phone_visible = true
		phone_open = true
		if active_app_window.is_empty():
			active_app_window = active_app
	else:
		phone_visible = false
		phone_open = false
		active_app_window = ""
		reset_reality_phase_for_day()
	return true


func is_world_item_collected(item_id: String) -> bool:
	return item_id in collected_world_item_ids


func get_prerequisite_item_ids() -> Array[String]:
	var ids: Array[String] = []
	for floor_number in [1, 2, 3]:
		ids.append(str((PREREQUISITE_ITEMS[floor_number] as Dictionary).get("id", "")))
	return ids


func get_prerequisite_item_for_floor(floor_number: int) -> Dictionary:
	return (PREREQUISITE_ITEMS.get(floor_number, {}) as Dictionary).duplicate(true)


func get_key_clue_progress(floor_number: int) -> Dictionary:
	return (key_clue_progress.get(str(clampi(floor_number, 1, 3)), {}) as Dictionary).duplicate(true)


func reveal_prerequisite_item_for_floor(floor_number: int) -> bool:
	var item := get_prerequisite_item_for_floor(floor_number)
	var item_id := str(item.get("id", ""))
	if item_id.is_empty() or item_id in revealed_prerequisite_item_ids:
		return false
	revealed_prerequisite_item_ids.append(item_id)
	event_log.push_front(str(item.get("location_hint", "这一层有一件东西正等着被找到。")))
	return true


func is_prerequisite_item_revealed(item_id: String) -> bool:
	return item_id in revealed_prerequisite_item_ids


func collect_prerequisite_item(item_id: String) -> bool:
	var normalized_id := item_id.strip_edges()
	if normalized_id not in get_prerequisite_item_ids():
		return false
	if normalized_id not in revealed_prerequisite_item_ids or normalized_id in collected_prerequisite_item_ids:
		return false
	collected_prerequisite_item_ids.append(normalized_id)
	if normalized_id not in collected_world_item_ids:
		collected_world_item_ids.append(normalized_id)
	event_log.push_front("你收起了这一层不该留下的东西。")
	return true


func is_hidden_layer_unlocked() -> bool:
	return _contains_all_ids(collected_prerequisite_item_ids, get_prerequisite_item_ids())


func record_history_line(line_data: Dictionary) -> bool:
	var line_id := str(line_data.get("lineId", "")).strip_edges()
	if line_id.is_empty():
		return false
	var normalized := {}
	for field_name in HISTORY_FIELD_NAMES:
		normalized[field_name] = line_data.get(field_name, 0 if field_name == "revisionStage" else "")
	normalized["lineId"] = line_id
	normalized["revisionStage"] = clampi(int(normalized["revisionStage"]), 0, 3)
	for index in history_entries.size():
		if str(history_entries[index].get("lineId", "")) == line_id:
			history_entries[index] = normalized
			return true
	history_entries.append(normalized)
	return true


func get_history_entries() -> Array:
	return history_entries.duplicate(true)


func complete_floor_three() -> String:
	if tower_floor != 3:
		return ""
	formal_floor_three_complete = true
	if pollution >= int(POLLUTION_FLOOR_THRESHOLDS[3]) and is_hidden_layer_unlocked():
		tower_floor = 4
		pending_floor_transition = 0
		ending_route = "hidden"
		ending_unlocked = false
		event_log.push_front("第四层没有登记记录。")
		return "hidden-floor"
	ending_route = "normal"
	ending_unlocked = true
	pending_floor_transition = 0
	return "normal-ending"


func request_floor_transition_for_pollution() -> int:
	if pending_floor_transition > tower_floor:
		return pending_floor_transition
	if tower_floor == 1 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[1]):
		pending_floor_transition = 2
	elif tower_floor == 2 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[2]):
		pending_floor_transition = 3
	return pending_floor_transition


func resolve_floor_transition_at_boundary() -> int:
	request_floor_transition_for_pollution()
	if pending_floor_transition != tower_floor + 1 or pending_floor_transition > 3:
		return tower_floor
	tower_floor = pending_floor_transition
	pending_floor_transition = 0
	event_log.push_front("你抵达了第 %d 层。" % tower_floor)
	return tower_floor


func has_seen_cover_watcher(floor_number: int) -> bool:
	return clampi(floor_number, 1, MAX_TOWER_FLOOR) in cover_watcher_seen_floors


func mark_cover_watcher_seen(floor_number: int) -> bool:
	var safe_floor := clampi(floor_number, 1, MAX_TOWER_FLOOR)
	if safe_floor in cover_watcher_seen_floors:
		return false
	cover_watcher_seen_floors.append(safe_floor)
	return true


func collect_world_item(item_data: Dictionary) -> bool:
	var item_id := str(item_data.get("id", "")).strip_edges()
	return collect_prerequisite_item(item_id)


func get_ending_language_choices() -> Array:
	return ENDING_LANGUAGE_CHOICES.duplicate(true)


func choose_ending_language(choice_id: String) -> bool:
	if not ending_unlocked or not ending_language_choice.is_empty():
		return false
	for choice in ENDING_LANGUAGE_CHOICES:
		if str(choice.get("id", "")) == choice_id:
			ending_language_choice = choice_id
			return true
	return false


func get_ending_language_output() -> String:
	for choice in ENDING_LANGUAGE_CHOICES:
		if str(choice.get("id", "")) == ending_language_choice:
			return str(choice.get("output", ""))
	return ""


func set_active_app(app_id: String) -> void:
	active_app = app_id
	if view_state == "phone_down":
		active_app_window = app_id


func spend_action(action_type: String) -> bool:
	if actions_remaining <= 0:
		actions_remaining = 0
		needs_day_settlement = true
		day_ended_reason = "actions-depleted"
		return false
	actions_remaining = maxi(0, actions_remaining - 1)
	if actions_remaining == 0:
		needs_day_settlement = true
		day_ended_reason = action_type
	return true


func can_spend_action() -> bool:
	return actions_remaining > 0


func is_social_following(handle: String) -> bool:
	return handle in social_followed_handles


func toggle_social_follow(handle: String) -> bool:
	var normalized := handle.strip_edges()
	if normalized.is_empty():
		return false
	if normalized in social_followed_handles:
		social_followed_handles.erase(normalized)
		return false
	social_followed_handles.append(normalized)
	return true


func is_social_post_liked(post_id: String) -> bool:
	return post_id in social_liked_post_ids


func toggle_social_like(post_id: String) -> bool:
	var normalized := post_id.strip_edges()
	if normalized.is_empty():
		return false
	if normalized in social_liked_post_ids:
		social_liked_post_ids.erase(normalized)
		return false
	social_liked_post_ids.append(normalized)
	return true


func check_pollution_flashback(previous_pollution: int) -> bool:
	if pollution_flashback_seen:
		return false
	if previous_pollution >= POLLUTION_FLASHBACK_THRESHOLD:
		return false
	if pollution < POLLUTION_FLASHBACK_THRESHOLD:
		return false
	pollution_flashback_seen = true
	pollution_flashback_pending = true
	actions_remaining = 0
	needs_day_settlement = true
	day_ended_reason = "pollution-flashback"
	return true


func change_pollution(amount: int) -> int:
	var previous_pollution := pollution
	pollution = clampi(pollution + amount, 0, 100)
	request_floor_transition_for_pollution()
	check_pollution_flashback(previous_pollution)
	return pollution - previous_pollution


func consume_pollution_flashback() -> bool:
	if not pollution_flashback_pending:
		return false
	pollution_flashback_pending = false
	return true


func begin_reality_player_turn() -> bool:
	if reality_phase == "reality_result":
		return false
	reality_phase = "player_composing"
	return true


func reset_reality_phase_for_day() -> void:
	reality_phase = "npc_speaking"


func start_typed_reality_conversation(actor_id: String, actor_type: String, actor_label: String) -> bool:
	if not can_spend_action():
		return false
	conversation_actor_id = actor_id
	conversation_actor_type = actor_type if actor_type in ["npc", "key_npc", "doll", "doctor"] else "npc"
	conversation_actor_label = actor_label
	conversation_mode = "lexeme" if conversation_actor_type == "doctor" else "authored"
	conversation_world = "doctor" if conversation_actor_type == "doctor" else "reality"
	conversation_selected_token_ids = []
	language_sentence_slots.clear()
	var dialogue := _reality_dialogue_for_actor(actor_id, conversation_actor_type)
	conversation_turns = [{
		"line": str(dialogue.get("line", "你打算说什么？")),
		"result": str(dialogue.get("result", "%s移开了视线。" % actor_label)),
		"choices": (dialogue.get("choices", []) as Array).duplicate(true),
	}]
	for followup in dialogue.get("continuation_turns", []):
		conversation_turns.append((followup as Dictionary).duplicate(true))
	conversation_turn_index = 0
	conversation_history = []
	conversation_can_continue = false
	conversation_completed = false
	conversation_interrupted = false
	conversation_interrupt_line = str(dialogue.get("interrupt", ""))
	conversation_action_spent = false
	conversation_reward = {}
	conversation_attempts = 0
	conversation_locale = "zh"
	_load_typed_reality_turn(0)
	conversation_phase = "composing" if conversation_mode == "lexeme" else "choosing"
	if conversation_mode == "lexeme":
		reality_phase = "player_composing"
	return true


func reset_typed_reality_conversation() -> void:
	conversation_phase = "idle"
	conversation_actor_id = ""
	conversation_actor_type = "npc"
	conversation_actor_label = ""
	conversation_prompt = ""
	conversation_result_line = ""
	conversation_prompt = ""
	conversation_result_line = ""
	conversation_choices = []
	conversation_selected_choice_id = ""
	conversation_clean_sentence = ""
	conversation_revealed_units = []
	conversation_reveal_index = 0
	conversation_attempts = 0
	conversation_understood = false
	conversation_understanding_rolls = []
	conversation_feedback = ""
	conversation_locale = "zh"
	conversation_clean_units = []
	conversation_mode = "authored"
	conversation_world = "reality"
	conversation_selected_token_ids = []
	conversation_turns = []
	conversation_turn_index = 0
	conversation_history = []
	conversation_can_continue = false
	conversation_completed = false
	conversation_interrupted = false
	conversation_interrupt_line = ""
	conversation_action_spent = false
	conversation_reward = {}


func get_typed_reality_choices() -> Array:
	return conversation_choices.duplicate(true)


func get_typed_reality_progress() -> Dictionary:
	return {
		"phase": conversation_phase,
		"turn_index": conversation_turn_index,
		"turn_number": conversation_turn_index + 1 if not conversation_turns.is_empty() else 0,
		"total_turns": conversation_turns.size(),
		"can_continue": conversation_can_continue,
		"completed": conversation_completed,
		"interrupted": conversation_interrupted,
		"action_spent": conversation_action_spent,
		"history_count": conversation_history.size(),
		"reward": conversation_reward.duplicate(true),
	}


func get_typed_reality_history() -> Array:
	return conversation_history.duplicate(true)


func continue_typed_reality_conversation() -> bool:
	if conversation_phase != "result" or not conversation_can_continue:
		return false
	var next_turn := conversation_turn_index + 1
	if next_turn >= conversation_turns.size():
		return false
	conversation_can_continue = false
	_load_typed_reality_turn(next_turn)
	conversation_phase = "choosing"
	return true


func _load_typed_reality_turn(turn_index: int) -> void:
	if turn_index < 0 or turn_index >= conversation_turns.size():
		return
	var turn: Dictionary = conversation_turns[turn_index]
	conversation_turn_index = turn_index
	conversation_prompt = str(turn.get("line", "你打算说什么？"))
	conversation_result_line = str(turn.get("result", "%s移开了视线。" % conversation_actor_label))
	conversation_choices = (turn.get("choices", []) as Array).duplicate(true)
	if conversation_actor_type == "doll":
		for choice_index in conversation_choices.size():
			var choice: Dictionary = (conversation_choices[choice_index] as Dictionary).duplicate(true)
			choice["locked"] = _doll_choice_is_locked(choice)
			if bool(choice["locked"]) and not str(choice.get("locked_summary", "")).is_empty():
				choice["summary"] = str(choice.get("locked_summary", ""))
			conversation_choices[choice_index] = choice
	conversation_selected_choice_id = ""
	conversation_clean_sentence = ""
	conversation_revealed_units = []
	conversation_reveal_index = 0
	conversation_understood = false
	conversation_understanding_rolls = []
	conversation_feedback = ""
	conversation_clean_units = []


func configure_conversation_locale(locale_code: String, _unused_legacy_texts: Array[String] = []) -> void:
	conversation_locale = locale_code if locale_code in ["zh", "ja", "en"] else "zh"
	if not conversation_clean_sentence.is_empty():
		conversation_clean_units = _conversation_units(conversation_clean_sentence)


func _reality_dialogue_for_actor(actor_id: String, actor_type: String) -> Dictionary:
	var floor_number := clampi(tower_floor, 1, 3)
	if actor_type == "doctor":
		var doctor_dialogue: Dictionary = DOCTOR_DIALOGUES_BY_FLOOR.get(clampi(tower_floor, 1, 4), DOCTOR_DIALOGUES_BY_FLOOR[1])
		return {
			"line": str(doctor_dialogue.get("line", "用你从屏幕里带回来的词说一句完整的话。")),
			"result": str(doctor_dialogue.get("result", "医生把句子写了下来。")),
			"choices": [],
		}
	if actor_type == "doll":
		var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_by_id(actor_id)
		if encounter.is_empty():
			encounter = LanguageCorruptionContentScript.get_doll_encounter_for_floor(floor_number)
		var doll_turns: Array = encounter.get("turns", [])
		if doll_turns.is_empty():
			return {"line": "布偶的缝线动了一下。", "result": "它没有留下任何东西。", "choices": []}
		var first_doll_turn: Dictionary = (doll_turns[0] as Dictionary).duplicate(true)
		first_doll_turn["continuation_turns"] = doll_turns.slice(1).duplicate(true)
		return first_doll_turn
	if actor_type == "key_npc":
		var key_dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(floor_number)
		var key_turns: Array = key_dialogue.get("turns", [])
		if key_turns.is_empty():
			return {"line": "你来得太早了。", "result": "对方没有再开口。", "choices": []}
		var first_turn: Dictionary = (key_turns[0] as Dictionary).duplicate(true)
		first_turn["continuation_turns"] = key_turns.slice(1).duplicate(true)
		return first_turn
	var entries: Array = LanguageCorruptionContentScript.get_dialogues_for_floor(floor_number)
	var actor_index := _reality_actor_index(actor_id)
	if entries.is_empty():
		return {"line_id": "fallback", "speaker": "", "line": "你打算说什么？", "result": "对方没有马上回答。", "choices": []}
	var dialogue: Dictionary = (entries[actor_index % entries.size()] as Dictionary).duplicate(true)
	var arc: Dictionary = LanguageCorruptionContentScript.get_followups_for_archetype(actor_index)
	dialogue["continuation_turns"] = (arc.get("turns", []) as Array).duplicate(true)
	dialogue["interrupt"] = str(arc.get("interrupt", ""))
	return dialogue


func _reality_actor_index(actor_id: String) -> int:
	for index in 8:
		if actor_id.ends_with("npc%d" % index):
			return index
	return 0


func preview_typed_reality_choice(choice_id: String) -> String:
	for choice in conversation_choices:
		if str(choice.get("id", "")) == choice_id:
			if bool(choice.get("locked", false)):
				return ""
			return str(choice.get("sentence", "")).strip_edges()
	return ""


func select_typed_reality_choice(choice_id: String) -> bool:
	if conversation_phase != "choosing":
		return false
	for choice: Dictionary in conversation_choices:
		if str(choice.get("id", "")) == choice_id and bool(choice.get("locked", false)):
			return false
	var sentence := preview_typed_reality_choice(choice_id)
	if sentence.is_empty():
		return false
	conversation_selected_choice_id = choice_id
	conversation_clean_sentence = sentence
	conversation_clean_units = _conversation_units(sentence)
	conversation_revealed_units = []
	conversation_reveal_index = 0
	conversation_understood = false
	conversation_understanding_rolls = []
	conversation_phase = "typing"
	return true


func advance_typed_reality_character() -> Dictionary:
	var result := {
		"advanced": false,
		"completed": false,
		"action_spent": false,
		"understood": false,
		"locked_out": false,
		"conversation_completed": false,
		"can_continue": false,
		"interrupted": false,
		"reward": {},
	}
	if conversation_phase != "typing":
		return result
	if conversation_reveal_index >= conversation_clean_units.size():
		return result
	var clean_character := conversation_clean_units[conversation_reveal_index]
	var roll := _conversation_roll("character", conversation_reveal_index, 0)
	var garble_percent := mini(pollution, 65)
	var corrupted := roll < garble_percent and clean_character not in PROTECTED_PUNCTUATION
	var display_character := clean_character
	if corrupted:
		display_character = _conversation_corruption_text(roll, conversation_reveal_index)
	conversation_revealed_units.append({
		"clean": clean_character,
		"display": display_character,
		"corrupted": corrupted,
		"roll": roll,
	})
	conversation_reveal_index += 1
	result["advanced"] = true
	if conversation_reveal_index < conversation_clean_units.size():
		return result

	result["completed"] = true
	var is_key_npc_final_turn := conversation_actor_type == "key_npc" and conversation_turn_index + 1 >= conversation_turns.size()
	var is_claimed_doll_repeat := conversation_actor_type == "doll" and is_doll_claimed(conversation_actor_id)
	var should_spend_now := conversation_actor_type != "doll" and (conversation_actor_type != "key_npc" or is_key_npc_final_turn) and not is_claimed_doll_repeat
	if not conversation_action_spent and should_spend_now:
		if not spend_action("typed-reality-dialogue"):
			conversation_phase = "result"
			conversation_interrupted = true
			conversation_feedback = "今天已经没有能说出口的行动。"
			result["locked_out"] = true
			result["interrupted"] = true
			return result
		conversation_action_spent = true
		result["action_spent"] = true
		reality_dialogue_count += 1
	conversation_attempts += 1
	last_clean_sentence = conversation_clean_sentence
	last_polluted_sentence = get_typed_reality_spoken_sentence()
	var understood := true
	if conversation_actor_type in ["key_npc", "doll"]:
		conversation_understanding_rolls = []
		npc_understanding = 100
	else:
		understood = _resolve_typed_reality_understanding()
	conversation_understood = understood
	result["understood"] = understood
	if not understood:
		last_relationship_residue_gain = clampi(1 + int(pollution / 18.0), 1, 14)
		relationship_residue = clampi(relationship_residue + last_relationship_residue_gain, 0, 100)
	conversation_feedback = conversation_result_line
	conversation_history.append({
		"turn_index": conversation_turn_index,
		"prompt": conversation_prompt,
		"choice_id": conversation_selected_choice_id,
		"clean_sentence": conversation_clean_sentence,
		"spoken_sentence": last_polluted_sentence,
		"understood": understood,
		"understanding_rolls": conversation_understanding_rolls.duplicate(),
		"result": conversation_result_line,
	})
	conversation_phase = "result"
	if not understood:
		conversation_can_continue = false
		conversation_interrupted = true
		if not conversation_interrupt_line.is_empty():
			conversation_feedback += "\n" + conversation_interrupt_line
		result["interrupted"] = true
		return result

	if conversation_turn_index + 1 < conversation_turns.size():
		conversation_can_continue = true
		result["can_continue"] = true
		return result

	conversation_can_continue = false
	conversation_completed = true
	result["conversation_completed"] = true
	if conversation_actor_type == "key_npc":
		conversation_reward = _resolve_key_npc_clue_attempt()
		result["reward"] = conversation_reward.duplicate(true)
		conversation_feedback += "\n" + str(conversation_reward.get("feedback", ""))
	elif conversation_actor_type == "doll":
		conversation_reward = _resolve_doll_choice_attempt()
		result["reward"] = conversation_reward.duplicate(true)
		conversation_feedback += "\n" + str(conversation_reward.get("feedback", ""))
	return result


func _resolve_key_npc_clue_attempt() -> Dictionary:
	var floor_number := clampi(tower_floor, 1, 3)
	var key_dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(floor_number)
	var turns: Array = key_dialogue.get("turns", [])
	var selected_ids: Array[String] = []
	for history_entry: Dictionary in conversation_history:
		selected_ids.append(str(history_entry.get("choice_id", "")))
	var correct_count := 0
	for turn_index in mini(turns.size(), selected_ids.size()):
		var turn: Dictionary = turns[turn_index]
		for choice: Dictionary in turn.get("choices", []):
			if bool(choice.get("correct", false)) and str(choice.get("id", "")) == selected_ids[turn_index]:
				correct_count += 1
				break
	var solved := turns.size() == 2 and correct_count == turns.size()
	var progress_key := str(floor_number)
	var previous: Dictionary = (key_clue_progress.get(progress_key, {}) as Dictionary).duplicate(true)
	var progress := {
		"attempts": int(previous.get("attempts", 0)) + 1,
		"correct_answers": correct_count,
		"last_answers": selected_ids.duplicate(),
		"solved": bool(previous.get("solved", false)) or solved,
	}
	key_clue_progress[progress_key] = progress
	var item := get_prerequisite_item_for_floor(floor_number)
	var item_id := str(item.get("id", ""))
	var newly_revealed := false
	var feedback := str(key_dialogue.get("failure_line", "对方没有说出地点。"))
	if solved:
		newly_revealed = reveal_prerequisite_item_for_floor(floor_number)
		feedback = "%s\n%s" % [
			str(key_dialogue.get("success_line", "对方终于说出了地点。")),
			str(item.get("location_hint", "这一层有一件东西正等着被找到。")),
		]
	return {
		"kind": "prerequisite_clue",
		"floor": floor_number,
		"item_id": item_id,
		"correct_answers": correct_count,
		"solved": solved,
		"newly_revealed": newly_revealed,
		"feedback": feedback,
	}


func is_doll_claimed(doll_id: String) -> bool:
	return doll_id in claimed_doll_ids


func get_doll_choice_result(doll_id: String) -> Dictionary:
	return (doll_choice_results.get(doll_id, {}) as Dictionary).duplicate(true)


func _doll_choice_by_id(encounter: Dictionary, choice_id: String) -> Dictionary:
	for turn: Dictionary in encounter.get("turns", []):
		for choice: Dictionary in turn.get("choices", []):
			if str(choice.get("id", "")) == choice_id:
				return choice.duplicate(true)
	return {}


func _doll_choice_is_locked(choice: Dictionary) -> bool:
	var minimum_pollution := int(choice.get("required_pollution_min", 0))
	var maximum_pollution := int(choice.get("required_pollution_max", 100))
	return pollution < minimum_pollution or pollution > maximum_pollution


func _resolve_doll_choice_attempt() -> Dictionary:
	var encounter: Dictionary = LanguageCorruptionContentScript.get_doll_encounter_by_id(conversation_actor_id)
	var choice: Dictionary = _doll_choice_by_id(encounter, conversation_selected_choice_id)
	var reward := {
		"kind": "guide_tutorial",
		"doll_id": conversation_actor_id,
		"choice_id": conversation_selected_choice_id,
		"guided": false,
		"duplicate": false,
		"locked": false,
		"feedback": "布偶把缝线朝向了下一步。",
	}
	if encounter.is_empty() or choice.is_empty():
		return reward
	if is_doll_claimed(conversation_actor_id):
		reward["duplicate"] = true
		reward["feedback"] = str(encounter.get("repeat_line", "布偶重复了一遍刚才的方向。"))
		return reward
	if _doll_choice_is_locked(choice):
		reward["locked"] = true
		reward["feedback"] = "那一段话还没有长到你能听见的位置。"
		return reward

	var result_record := {
		"choice_id": conversation_selected_choice_id,
		"day": day,
		"floor": clampi(tower_floor, 1, 3),
	}
	claimed_doll_ids.append(conversation_actor_id)
	doll_choice_results[conversation_actor_id] = result_record
	reward["guided"] = true
	reward["feedback"] = str(choice.get("guide_feedback", "它让你先照做，理由可以晚一点再问。"))
	event_log.push_front("缝线布偶指向了下一步。")
	notify_tutorial("guide_found", {"doll_id": conversation_actor_id})
	return reward


func get_typed_reality_spoken_sentence() -> String:
	var pieces: Array[String] = []
	for unit in conversation_revealed_units:
		pieces.append(str(unit.get("display", "")))
	return "".join(pieces)


func get_typed_reality_unrevealed_suffix() -> String:
	if conversation_clean_units.is_empty() or conversation_reveal_index >= conversation_clean_units.size():
		return ""
	var suffix := ""
	for index in range(conversation_reveal_index, conversation_clean_units.size()):
		suffix += conversation_clean_units[index]
	return suffix


func get_typed_reality_unit_count() -> int:
	return conversation_clean_units.size()


func _conversation_units(sentence: String) -> Array[String]:
	return GameLocaleScript.split_dialogue_units(sentence, conversation_locale)


func _conversation_corruption_text(roll: int, character_index: int) -> String:
	if not completed_memes.is_empty() and posmod(roll + character_index, 3) == 0:
		var meme_index := posmod(roll + conversation_attempts + character_index, completed_memes.size())
		var meme: Dictionary = completed_memes[meme_index]
		var meme_text := str(meme.get("title", meme.get("text", ""))).strip_edges()
		if not meme_text.is_empty():
			return meme_text.substr(0, mini(4, meme_text.length()))
	return REALITY_CORRUPTION_GLYPHS[posmod(roll + character_index, REALITY_CORRUPTION_GLYPHS.size())]


func _resolve_typed_reality_understanding() -> bool:
	conversation_understanding_rolls = []
	var base_clear_chance := clampi(100 - pollution, 5, 96)
	var check_count := 1
	var understood := false
	for check_index in check_count:
		var roll := _conversation_roll("understanding", 0, check_index)
		conversation_understanding_rolls.append(roll)
		if roll < base_clear_chance:
			understood = true
	npc_understanding = base_clear_chance
	return understood


func _conversation_roll(channel: String, character_index: int, check_index: int) -> int:
	var key := "%s|%s|%d|%d|%d|%d|%s" % [
		conversation_actor_id,
		conversation_selected_choice_id,
		day,
		conversation_attempts,
		character_index,
		check_index,
		channel,
	]
	return posmod(int(hash(key)), 100)


func settle_day_if_needed() -> bool:
	if not needs_day_settlement:
		return false
	_resolve_tower_step()
	day += 1
	actions_remaining = max_actions_per_day
	needs_day_settlement = false
	day_ended_reason = ""
	pollution_flashback_pending = false
	draft_slots.clear()
	fusion_slots.clear()
	dialogue_blanks.clear()
	language_sentence_slots.clear()
	reset_reality_phase_for_day()
	reset_typed_reality_conversation()
	return true


func pick_token(post_id: String, token: Dictionary) -> bool:
	var content_locale := str(token.get("content_locale", "zh"))
	var picked_text := str(token.get("text", "")).strip_edges()
	if picked_text.is_empty():
		return false
	var note := {
		"id": "%s-%s-%d" % [post_id, token.get("id", "token"), day],
		"text": picked_text,
		"lexeme_id": str(token.get("lexeme_id", token.get("id", "token"))),
		"grammar_roles": (token.get("grammar_roles", [str(token.get("grammar_role", "subject"))]) as Array).duplicate(),
		"phone_surface": str(token.get("phone_surface", picked_text)),
		"doctor_surface": str(token.get("doctor_surface", picked_text)),
		"doll_surface": str(token.get("doll_surface", picked_text)),
		"source_text": str(token.get("source_text", token.get("text", ""))),
		"content_locale": content_locale,
		"source_post_id": post_id,
		"tags": token.get("tags", []),
		"rarity": int(token.get("rarity", 1)),
		"picked_day": day,
		"source_card_id": str(token.get("source_card_id", "")),
		"pollution_stage": 0,
		"used_worlds": [],
	}
	note = LanguageBridgeScript.normalized_token(note)
	for existing in notebook_tokens:
		if existing.get("id", "") == note["id"]:
			return false
	if not spend_action("pick-token"):
		return false
	notebook_tokens.append(note)
	notify_tutorial("collect_word", {"token_id": str(note.get("id", ""))})
	return true


func get_pickup_unit_pool(locale_code: String = "zh") -> Array:
	return PickupCharPoolScript.get_unit_pool(locale_code)


func is_social_char_collected(unit: String, locale_code: String = "zh") -> bool:
	for entry in collected_char_units:
		if entry is Dictionary and str((entry as Dictionary).get("unit", "")) == unit and str((entry as Dictionary).get("locale", "zh")) == locale_code:
			return true
	return false


func get_collected_char_units(locale_code: String = "zh") -> Array[String]:
	var result: Array[String] = []
	for entry in collected_char_units:
		if entry is Dictionary and str((entry as Dictionary).get("locale", "zh")) == locale_code:
			var unit := str((entry as Dictionary).get("unit", ""))
			if not unit.is_empty() and unit not in result:
				result.append(unit)
	return result


## 拾取帖文中的单个语言单位(中文单字/日文单词/英文单词)。
## 计费规则:每天第一次拾字消耗 1 行动,相当于刷一次手机;当天后续拾字免费。
func pick_social_char(post_id: String, unit: String, locale_code: String = "zh") -> Dictionary:
	var result := {"picked": false, "reason": "", "action_spent": false}
	var normalized_unit := unit.strip_edges()
	if normalized_unit.is_empty() or not PickupCharPoolScript.is_unit_in_pool(normalized_unit, locale_code):
		result["reason"] = "not-in-pool"
		return result
	if is_social_char_collected(normalized_unit, locale_code):
		result["reason"] = "duplicate"
		return result
	var needs_action := last_char_pick_day != day
	if needs_action:
		if not can_spend_action():
			result["reason"] = "no-actions"
			return result
		if not spend_action("pick-char"):
			result["reason"] = "no-actions"
			return result
		result["action_spent"] = true
	collected_char_units.append({
		"unit": normalized_unit,
		"locale": locale_code,
		"source_post_id": post_id,
		"day": day,
	})
	last_char_pick_day = day
	result["picked"] = true
	notify_tutorial("collect_word", {"token_id": "char-%s-%s" % [locale_code, normalized_unit]})
	return result


func get_craft_slots() -> Array:
	return LANGUAGE_RECIPE_SLOTS.duplicate(true)


func get_craft_sentence_preview(world: String = "phone") -> Dictionary:
	return LanguageBridgeScript.compose_sentence(draft_slots, notebook_tokens, world, conversation_locale)


func place_token_in_slot(slot_id: String, token_id: String) -> bool:
	var token := _find_token(token_id)
	if token.is_empty():
		return false
	var accepted_role := ""
	for slot: Dictionary in LANGUAGE_RECIPE_SLOTS:
		if str(slot.get("id", "")) == slot_id:
			accepted_role = str(slot.get("accepted_role", ""))
			break
	if accepted_role.is_empty():
		return false
	var token_roles: Array = token.get("grammar_roles", [])
	if accepted_role not in token_roles:
		return false
	draft_slots[slot_id] = token_id
	return true


func confirm_craft() -> bool:
	var validation: Dictionary = LanguageBridgeScript.validate_recipe(draft_slots, notebook_tokens)
	if not bool(validation.get("valid", false)):
		return false
	var composition: Dictionary = LanguageBridgeScript.compose_sentence(draft_slots, notebook_tokens, "phone", conversation_locale)
	if not bool(composition.get("valid", false)):
		return false
	if not spend_action("craft-meme"):
		return false
	var token_ids: Array = composition.get("token_ids", [])
	var tags: Array = []
	var rarity_total := 0
	for token_id_value in token_ids:
		var token := _find_token(str(token_id_value))
		tags.append_array(token.get("tags", []))
		rarity_total += int(token.get("rarity", 1))
	tags = _unique(tags)
	var sentence_text := str(composition.get("world_sentence", composition.get("clean_sentence", "")))
	var meme := {
		"id": "meme-%d-%d" % [day, completed_memes.size() + 1],
		"title": "句子「%s」" % sentence_text,
		"text": sentence_text,
		"clean_text": str(composition.get("clean_sentence", sentence_text)),
		"token_ids": token_ids.duplicate(),
		"lexeme_ids": (composition.get("lexeme_ids", []) as Array).duplicate(),
		"tags": tags,
		"rarity": _meme_rarity_from_tags(tags),
		"pollution_bias": maxi(1, rarity_total - token_ids.size()),
		"fusion_level": 0,
		"unit_count": token_ids.size(),
		"created_day": day,
	}
	completed_memes.push_front(meme)
	draft_slots.clear()
	notify_tutorial("sentence_composed", {"meme_id": str(meme.get("id", ""))})
	return true


func place_meme_in_fusion_slot(slot_id: String, meme_id: String) -> bool:
	if slot_id != "left" and slot_id != "right":
		return false
	if _find_completed_meme_index(meme_id) < 0:
		return false
	var other_slot := "right" if slot_id == "left" else "left"
	if str(fusion_slots.get(other_slot, "")) == meme_id:
		return false
	fusion_slots[slot_id] = meme_id
	return true


func confirm_meme_fusion() -> bool:
	var left_id := str(fusion_slots.get("left", ""))
	var right_id := str(fusion_slots.get("right", ""))
	if left_id.is_empty() or right_id.is_empty() or left_id == right_id:
		return false
	var left_index := _find_completed_meme_index(left_id)
	var right_index := _find_completed_meme_index(right_id)
	if left_index < 0 or right_index < 0:
		return false
	var pair_ids: Array[String] = [left_id, right_id]
	pair_ids.sort()
	var pair_key := "%s+%s" % [pair_ids[0], pair_ids[1]]
	if pair_key in fused_meme_pairs:
		return false
	if not spend_action("fuse-memes"):
		return false
	var left: Dictionary = completed_memes[left_index]
	var right: Dictionary = completed_memes[right_index]
	var fusion_level := mini(3, maxi(int(left.get("fusion_level", 0)), int(right.get("fusion_level", 0))) + 1)
	var tags: Array = _unique((left.get("tags", []) as Array) + (right.get("tags", []) as Array))
	var left_text := str(left.get("text", ""))
	var right_text := str(right.get("text", ""))
	var fused_text := "%s%s" % [left_text, right_text]
	var meme := {
		"id": "fusion-%d-%d" % [day, completed_memes.size() + 1],
		"title": "复合「%s」" % fused_text,
		"text": fused_text,
		"tags": tags,
		"rarity": clampi(maxi(int(left.get("rarity", 1)), int(right.get("rarity", 1))) + 1, 1, 5),
		"pollution_bias": int(left.get("pollution_bias", 0)) + int(right.get("pollution_bias", 0)) + 6 + fusion_level * 2,
		"fusion_level": fusion_level,
		"unit_count": maxi(2, int(left.get("unit_count", 1)) + int(right.get("unit_count", 1))),
		"fused_from": pair_ids,
		"created_day": day,
	}
	completed_memes.push_front(meme)
	fused_meme_pairs.append(pair_key)
	fusion_slots.clear()
	change_pollution(3 + fusion_level * 2)
	event_log.push_front("两个旧梗粘在一起。新梗更响，也更脏。")
	return true


func place_meme_in_blank(blank_id: String, meme_id: String) -> bool:
	dialogue_blanks[blank_id] = meme_id
	return true


func confirm_dialogue() -> bool:
	var meme := _get_first_placed_meme()
	if meme.is_empty():
		return false
	var publish_result := get_publish_result(meme)
	if not spend_action("confirm-dialogue"):
		return false
	last_publish_result = publish_result.duplicate(true)
	money += int(publish_result.get("money_gain", 0))
	change_pollution(int(publish_result.get("pollution_gain", 0)))
	var record: Dictionary = meme.duplicate(true)
	record["floor"] = tower_floor
	record["money_gain"] = int(publish_result.get("money_gain", 0))
	record["pollution_gain"] = int(publish_result.get("pollution_gain", 0))
	record["published_day"] = day
	published_memes.push_front(record)
	var published_token_ids: Array = record.get("token_ids", [])
	if not published_token_ids.is_empty():
		notebook_tokens = LanguageBridgeScript.mark_tokens_used(notebook_tokens, published_token_ids, "phone")
	dialogue_blanks.clear()
	event_log.push_front("发布完成：资金 +%d，污染 +%d%%。" % [
		int(publish_result.get("money_gain", 0)),
		int(publish_result.get("pollution_gain", 0)),
	])
	notify_tutorial("sentence_published", {"meme_id": str(record.get("id", ""))})
	return true


func get_language_token_options(world: String = "doctor") -> Array:
	var result: Array = []
	for token_value in notebook_tokens:
		if not token_value is Dictionary:
			continue
		var token: Dictionary = token_value
		var used_worlds: Array = token.get("used_worlds", [])
		if world == "doctor" and "phone" not in used_worlds:
			continue
		var option := token.duplicate(true)
		option["display_text"] = LanguageBridgeScript.token_surface(token, world)
		result.append(option)
	return result


func place_language_token(slot_id: String, token_id: String, world: String = "doctor") -> bool:
	var token := _find_token(token_id)
	if token.is_empty():
		return false
	var is_available := false
	for option: Dictionary in get_language_token_options(world):
		if str(option.get("id", "")) == token_id:
			is_available = true
			break
	if not is_available:
		return false
	var accepted_role := ""
	for slot: Dictionary in LANGUAGE_RECIPE_SLOTS:
		if str(slot.get("id", "")) == slot_id:
			accepted_role = str(slot.get("accepted_role", ""))
			break
	if accepted_role.is_empty():
		return false
	var token_roles: Array = token.get("grammar_roles", [])
	if accepted_role not in token_roles:
		return false
	language_sentence_slots[slot_id] = token_id
	conversation_selected_token_ids = []
	for recipe_slot: Dictionary in LANGUAGE_RECIPE_SLOTS:
		var selected_id := str(language_sentence_slots.get(str(recipe_slot.get("id", "")), ""))
		if not selected_id.is_empty():
			conversation_selected_token_ids.append(selected_id)
	return true


func clear_language_sentence() -> void:
	language_sentence_slots.clear()
	conversation_selected_token_ids.clear()


func get_language_sentence_preview(world: String = "doctor") -> Dictionary:
	return LanguageBridgeScript.compose_sentence(language_sentence_slots, notebook_tokens, world, conversation_locale)


func confirm_doctor_sentence() -> bool:
	if conversation_mode != "lexeme" or conversation_phase != "composing":
		return false
	var composition := get_language_sentence_preview("doctor")
	if not bool(composition.get("valid", false)):
		return false
	if not spend_action("doctor-dialogue"):
		return false

	var token_ids: Array = composition.get("token_ids", [])
	var doctor_sentence := str(composition.get("world_sentence", ""))
	last_clean_sentence = str(composition.get("clean_sentence", doctor_sentence))
	last_polluted_sentence = pollute_reality_sentence(doctor_sentence, pollution)
	notebook_tokens = LanguageBridgeScript.mark_tokens_used(notebook_tokens, token_ids, "doctor")
	var shifted_token_count := _token_count_with_world_shift(token_ids, "doctor")
	var distortion_penalty := 10 if last_polluted_sentence != doctor_sentence else 0
	npc_understanding = clampi(100 - int(round(float(pollution) * 0.45)) - shifted_token_count * 7 - distortion_penalty, 0, 100)
	reality_dialogue_count += 1
	last_relationship_residue_gain = maxi(0, int(ceil(float(maxi(0, 80 - npc_understanding)) / 12.0)))
	relationship_residue = clampi(relationship_residue + last_relationship_residue_gain, 0, 100)
	last_relationship_money_loss = 0
	change_pollution(clampi(2 + shifted_token_count, 2, 8))
	conversation_clean_sentence = last_clean_sentence
	conversation_revealed_units = []
	for index in last_polluted_sentence.length():
		var clean_unit := last_clean_sentence.substr(index, 1) if index < last_clean_sentence.length() else ""
		var display_unit := last_polluted_sentence.substr(index, 1)
		conversation_revealed_units.append({"clean": clean_unit, "display": display_unit, "corrupted": clean_unit != display_unit, "roll": -1})
	conversation_reveal_index = conversation_revealed_units.size()
	conversation_clean_units = _conversation_units(last_clean_sentence)
	conversation_understood = npc_understanding >= 45
	conversation_action_spent = true
	conversation_completed = true
	conversation_feedback = conversation_result_line
	conversation_phase = "result"
	reality_phase = "reality_result"
	var record := {
		"id": "sentence-%d-%d" % [day, sentence_records.size() + 1],
		"world": "doctor",
		"floor": tower_floor,
		"day": day,
		"token_ids": token_ids.duplicate(),
		"lexeme_ids": (composition.get("lexeme_ids", []) as Array).duplicate(),
		"clean_sentence": last_clean_sentence,
		"world_sentence": doctor_sentence,
		"spoken_sentence": last_polluted_sentence,
		"pollution": pollution,
		"understanding": npc_understanding,
	}
	sentence_records.append(record)
	conversation_history.append(record.duplicate(true))
	clear_language_sentence()
	notify_tutorial("doctor_spoken", {"sentence_id": str(record.get("id", ""))})
	return true


func confirm_reality_dialogue() -> bool:
	return confirm_doctor_sentence()


func get_relationship_state_label() -> String:
	if relationship_residue < 20:
		return "仍能认出你"
	if relationship_residue < 45:
		return "句子留下裂痕"
	if relationship_residue < 70:
		return "只剩熟悉的语气"
	return "彼此已无法确认"


func pollute_reality_sentence(sentence: String, pollution_value: int, _unused_rules: Array = []) -> String:
	if pollution_value < 35:
		return sentence
	var markers := ["■", "□", "▦", "∴", "//", "≠", "…"]
	var step := maxi(2, 9 - int(pollution_value / 12))
	var result := ""
	for index in sentence.length():
		var ch := sentence.substr(index, 1)
		if ch == " ":
			result += ch
		elif index % step == 0:
			result += markers[(index + day) % markers.size()]
		else:
			result += ch
	return result


func _get_first_placed_meme() -> Dictionary:
	for meme_id in dialogue_blanks.values():
		for meme in completed_memes:
			if str(meme.get("id", "")) == str(meme_id):
				return meme
	return {}


func _find_token_text(token_id: String) -> String:
	return str(_find_token(token_id).get("text", ""))


func _find_token(token_id: String) -> Dictionary:
	for token_value in notebook_tokens:
		if token_value is Dictionary and str((token_value as Dictionary).get("id", "")) == token_id:
			return (token_value as Dictionary).duplicate(true)
	return {}


func _find_token_tags(token_id: String) -> Array:
	return (_find_token(token_id).get("tags", []) as Array).duplicate()


func _find_token_rarity(token_id: String) -> int:
	return int(_find_token(token_id).get("rarity", 1))


func _token_count_with_world_shift(token_ids: Array, world: String) -> int:
	var shifted := 0
	for token_id_value in token_ids:
		var token := _find_token(str(token_id_value))
		if not token.is_empty() and LanguageBridgeScript.token_surface(token, world) != str(token.get("text", "")):
			shifted += 1
	return shifted


func get_gameplay_metrics() -> Dictionary:
	return {"money": money, "pollution": pollution}


func get_publish_result(meme: Dictionary) -> Dictionary:
	if meme.is_empty():
		return {}
	var rarity := clampi(int(meme.get("rarity", 1)), 1, 5)
	var fusion_level := clampi(int(meme.get("fusion_level", 0)), 0, 3)
	var pollution_bias := maxi(0, int(meme.get("pollution_bias", 0)))
	return {
		"money_gain": 2 + rarity * 2 + fusion_level,
		"pollution_gain": clampi(2 + rarity + fusion_level * 2 + pollution_bias, 1, 30),
	}


func _resolve_tower_step() -> void:
	resolve_floor_transition_at_boundary()
	if tower_floor == 3 and pollution >= int(POLLUTION_FLOOR_THRESHOLDS[3]) and not formal_floor_three_complete:
		complete_floor_three()


func _find_completed_meme_index(meme_id: String) -> int:
	for index in completed_memes.size():
		if str(completed_memes[index].get("id", "")) == meme_id:
			return index
	return -1


func _meme_rarity_from_tags(tags: Array) -> int:
	return clampi(1 + int(floor(float(tags.size()) / 2.0)), 1, 5)


func _intersect(left: Array, right: Array) -> Array:
	var result: Array = []
	for value in left:
		if value in right and value not in result:
			result.append(value)
	return result


func _contains_all_ids(values: Array, required_ids: Array) -> bool:
	for required_id in required_ids:
		if required_id not in values:
			return false
	return true


func _unique(values: Array) -> Array:
	var result: Array = []
	for value in values:
		if value not in result:
			result.append(value)
	return result


func _first_pickable_character(value: String, locale_code: String = "zh") -> String:
	if locale_code == "en":
		var word_regex := RegEx.new()
		word_regex.compile("[A-Za-z0-9']+")
		var match_result := word_regex.search(value)
		return match_result.get_string() if match_result != null else ""
	var ignored := " \t\r\n　，。！？；：、,.!?;:（）()【】[]《》<>〈〉「」『』〔〕“”\"'—-…・"
	if locale_code == "ja":
		var start := 0
		var end := value.length()
		while start < end and ignored.contains(value.substr(start, 1)):
			start += 1
		while end > start and ignored.contains(value.substr(end - 1, 1)):
			end -= 1
		return value.substr(start, end - start)
	for index in value.length():
		var character := value.substr(index, 1)
		if not ignored.contains(character):
			return character
	return ""
