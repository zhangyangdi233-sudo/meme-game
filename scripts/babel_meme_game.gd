extends Node3D

const MemeGameStateScript = preload("res://scripts/meme_game_state.gd")
const GameLocaleScript = preload("res://scripts/localization/game_locale.gd")
const LanguageCorruptionContentScript = preload("res://scripts/narrative/language_corruption_content.gd")
const DraggableButtonScript = preload("res://framework/ui/draggable_button.gd")
const DropButtonScript = preload("res://framework/ui/drop_button.gd")
const RadialSelectorRingScript = preload("res://framework/ui/radial_selector_ring.gd")
const RealityFloorGeneratorScript = preload("res://scripts/reality_floor_generator.gd")
const RicherTextLabelScript = preload("res://addons/richtext2/richer_text_label.gd")
const HandTrackingReceiverScript = preload("res://framework/integrations/hand_tracking_receiver.gd")
const HandXRayOverlayScript = preload("res://framework/ui/hand_xray_overlay.gd")
const PickupCharPoolScript = preload("res://scripts/narrative/pickup_char_pool.gd")
const RuleEngineScript = preload("res://scripts/narrative/rule_engine.gd")
const EchoQuoteContentScript = preload("res://scripts/narrative/echo_quote_content.gd")
const ComposerAnswerTileScript = preload("res://scripts/ui/composer_answer_tile.gd")
const ComposerDropAreaScript = preload("res://scripts/ui/composer_drop_area.gd")
const CanvasWordTileScript = preload("res://scripts/ui/canvas_word_tile.gd")
const WordPhysicsCanvasScript = preload("res://framework/ui/word_physics_canvas.gd")
const PixelFontThemeScript = preload("res://framework/ui/pixel_font_theme.gd")
const CinematicBarsScript = preload("res://framework/ui/cinematic_bars.gd")
const DraggableWindowManagerScript = preload("res://framework/ui/draggable_window_manager.gd")
const EdgeDrawerScript = preload("res://framework/ui/edge_drawer.gd")
const SettingsHistoryPanelScript = preload("res://scripts/ui/settings_history_panel.gd")
const SocialFeedPanelScript = preload("res://scripts/ui/social_feed_panel.gd")

const PALETTE_1 := {
	"name": "palette_1",
	"bg": "B7D957",
	"surface": "FFF1C9",
	"text": "10140F",
	"ink": "10140F",
	"accent": "365B2D",
	"muted": "DDEB8A",
	"danger_stripe": "10140F",
	"flash_text": "9CFF24",
}
const POLLUTION_PALETTE_5 := {
	"name": "pollution_palette_5",
	"bg": "9CFF24",
	"surface": "FFF2B8",
	"text": "0D1009",
	"ink": "0D1009",
	"accent": "2F6B1F",
	"muted": "D8FF66",
	"danger_stripe": "0D1009",
	"flash_text": "39FF14",
}

const PHONE_DOWN_BACKDROP_PATH := "res://assets/generated/world/phone_down_backdrop.png"
const PLAYER_CHARACTER_PATH := "res://assets/generated/characters/protagonist_operator.png"
const GUIDE_DOLL_CHARACTER_PATH := "res://assets/generated/characters/guide_doll.png"
const NPC_CHARACTER_PATHS := [
	"res://assets/generated/characters/npc_late_arrival.png",
	"res://assets/generated/characters/npc_echo_tenant.png",
	"res://assets/generated/characters/npc_archive_witness.png",
]
const NO_SIGNAL_ICON_PATH := "res://assets/generated/ui/no_signal_icon.png"
const HUD_POLLUTION_ICON_PATH := "res://assets/generated/ui/hud_pollution_icon.png"
const HUD_MONEY_ICON_PATH := "res://assets/generated/ui/hud_money_icon.png"
const HUD_SETTINGS_ICON_PATH := "res://assets/generated/ui/hud_settings_icon.png"
const PHONE_LAUNCHER_WALLPAPER_PATH := "res://assets/generated/1/IMG_4835.PNG"
const SOCIAL_POSTER_SHEET_PATH := "res://assets/generated/social/poster_sheet.png"
const PHONE_AMBIENCE_PATHS := {
	1: "res://assets/generated/audio/babel_phone_signal_floor_1.wav",
	2: "res://assets/generated/audio/babel_phone_signal.wav",
	3: "res://assets/generated/audio/babel_phone_signal_floor_3.wav",
	4: "res://assets/generated/audio/babel_phone_signal_floor_4.wav",
}
const REALITY_AMBIENCE_PATH := "res://assets/generated/audio/babel_reality_liminal.wav"
const POLLUTION_AMBIENCE_PATH := "res://assets/generated/audio/babel_pollution_rot.wav"
const FLASHBACK_AUDIO_PATH := "res://assets/generated/audio/pollution_flashback.wav"
const ACTION_TICK_AUDIO_PATH := "res://assets/generated/audio/action_tick.wav"
# 拾取反馈三件套(依据 docs/research/pickup_feedback_gap_analysis.md 的 P0:jam 基线要求拾取必有音效)。
const PICKUP_PRESS_AUDIO_PATH := "res://assets/generated/audio/pickup_press.wav"
const PICKUP_LAND_AUDIO_PATH := "res://assets/generated/audio/pickup_land.wav"
const NOTEBOOK_HINGE_AUDIO_PATH := "res://assets/generated/audio/notebook_hinge.wav"
const COVER_WATCHER_STINGER_PATH := "res://assets/generated/audio/cover_watcher_stinger.wav"
const SOCIAL_POSTER_COLUMNS := 4
const SOCIAL_POSTER_ROWS := 3
const SOCIAL_POSTER_COUNT := SOCIAL_POSTER_COLUMNS * SOCIAL_POSTER_ROWS
const REALITY_MOVE_SPEED := 3.3
const REALITY_SPRINT_MULTIPLIER := 1.85
const REALITY_ACCELERATION := 14.0
const REALITY_MOUSE_SENSITIVITY := 0.064
const REALITY_TOUCH_SENSITIVITY := 0.082
const REALITY_TRACKPAD_SENSITIVITY := 1.8
const REALITY_INTERACTION_DISTANCE := 2.25
# 跟随玩偶:小体量 + 右后下方偏移,保证不遮挡前方视野与准心。
const DOLL_COMPANION_PIXEL_SIZE := 0.0016
const DOLL_COMPANION_OFFSET := Vector3(0.72, 0.95, 0.55)
# 可拾取字的视觉可供性:脉动频率与字号(配合下划线,构成非颜色依赖的三重提示)。
const PICKABLE_PULSE_FREQ := 0.5
const PICKABLE_FONT_SIZE := 19
# 句子单位软上限(参考 Bluesky 的 grapheme 计数语义;超过只提示不拦截)。
const COMPOSER_SOFT_UNIT_LIMIT := 12
# 点阵字体(Boutique Bitmap 9x9,OFL):三语共用一套字形,字号必须吸附到 9 的整数倍。
const UI_FONT_PATH := "res://assets/fonts/BoutiqueBitmap9x9.ttf"
const UI_FONT_GRID := 9
const UI_FONT_MIN_SIZE := 9
const UI_FONT_MAX_SIZE := 45
const REALITY_FALL_RECOVERY_Y := -3.0
const REALITY_SAFE_INSET := 1.2
const CINEMATIC_ASPECT_RATIO := 2.35
const CINEMATIC_MAX_BAR_RATIO := 0.12
const HUD_RAIL_WIDTH := 158.0
const HUD_RAIL_MAX_HEIGHT := 700.0
const HUD_RAIL_FRAME_MARGIN := 10.0
const HUD_DRAWER_EDGE_HIT_WIDTH := 44.0
const HUD_DRAWER_EDGE_CUE_WIDTH := 5.0
const HUD_DRAWER_OPEN_DURATION := 0.26
const HUD_DRAWER_CLOSE_DURATION := 0.18
const HUD_DRAWER_CLOSE_DELAY := 0.22
const MEME_BANK_MOTION_TRANSITION := Tween.TRANS_QUINT
const MEME_BANK_MOTION_EASE := Tween.EASE_OUT
const MEME_BANK_SCALE_DURATION := 0.28
const MEME_BANK_ALPHA_DURATION := 0.22
const SAVE_PATH := "user://babel_meme_save.dat"
const SAVE_FILE_VERSION := 1
const SOCIAL_CHANNELS := [
	{"id": "discover", "label": "发现"},
	{"id": "following", "label": "关注流"},
]
const SOCIAL_POST_CARDS := [
	{
		"id": "floor_13", "poster_cell": 0, "caption": "旧教学楼昨晚多出一层", "handle": "塔下施工档案",
		"text": "实拍：封闭的教学楼昨晚多出一层，末班电梯停在那里。", "tags": ["巴别塔", "空位"], "rarity": 2,
		"tokens": [
			{"id": "floor", "text": "不存在的十三层", "lexeme_id": "place.unlisted_floor", "grammar_roles": ["object"], "phone_surface": "隐藏楼层", "doctor_surface": "未登记空间", "doll_surface": "不许去的楼上", "tags": ["巴别塔", "空位"], "rarity": 2},
			{"id": "last_lift", "text": "末班电梯", "lexeme_id": "subject.last_lift", "grammar_roles": ["subject"], "phone_surface": "末班电梯账号", "doctor_surface": "反复梦见电梯的患者", "doll_surface": "回家的电梯", "tags": ["日常", "巴别塔"], "rarity": 1},
			{"id": "still_building", "text": "停在", "lexeme_id": "action.stop_at", "grammar_roles": ["action"], "phone_surface": "定位到", "doctor_surface": "持续停留于", "doll_surface": "等在", "tags": ["刷新", "追问"], "rarity": 2},
		],
	},
	{
		"id": "self_call", "poster_cell": 1, "caption": "无信号时收到明天短信", "handle": "无信号通勤",
		"text": "求证：断网后，我收到明天的自己发来的哈吉米。", "tags": ["哈吉米", "刷新", "追问"], "rarity": 3,
		"tokens": [
			{"id": "no_signal", "text": "无信号的短信", "lexeme_id": "object.no_signal_message", "grammar_roles": ["object"], "phone_surface": "离线消息", "doctor_surface": "无来源记录", "doll_surface": "没有声音的纸条", "tags": ["沉默", "空位"], "rarity": 1},
			{"id": "self_call", "text": "明天的我", "lexeme_id": "subject.future_self", "grammar_roles": ["subject"], "phone_surface": "未来账号", "doctor_surface": "预期自我", "doll_surface": "明天醒来的你", "tags": ["追问", "反问"], "rarity": 2},
			{"id": "hajimi", "text": "发来", "lexeme_id": "action.send", "grammar_roles": ["action"], "phone_surface": "推送", "doctor_surface": "投射出", "doll_surface": "塞给我", "tags": ["哈吉米", "刷新"], "rarity": 2},
		],
	},
	{
		"id": "missing_window", "poster_cell": 2, "caption": "塔下每晚少一个窗口", "handle": "塔下夜巡",
		"text": "记录：塔下每到午夜，就少一扇亮着的窗。", "tags": ["巴别塔", "沉默"], "rarity": 2,
		"tokens": [
			{"id": "midnight", "text": "一扇亮窗", "lexeme_id": "subject.lit_window", "grammar_roles": ["subject"], "phone_surface": "在线窗口", "doctor_surface": "视觉对象", "doll_surface": "会眨眼的窗", "tags": ["日常", "刷新"], "rarity": 1},
			{"id": "one_less", "text": "消失在", "lexeme_id": "action.disappear_at", "grammar_roles": ["action"], "phone_surface": "下线于", "doctor_surface": "从知觉中脱落于", "doll_surface": "躲进", "tags": ["沉默", "空位"], "rarity": 2},
			{"id": "under_tower", "text": "塔下", "lexeme_id": "place.tower_base", "grammar_roles": ["object"], "phone_surface": "塔下频道", "doctor_surface": "固定场景", "doll_surface": "我们楼下", "tags": ["巴别塔", "信徒"], "rarity": 1},
		],
	},
	{
		"id": "extra_moon", "poster_cell": 3, "caption": "照片里月亮多了一颗", "handle": "夜空误差簿",
		"text": "对照：昨晚的照片里，月亮比现实多一颗。", "tags": ["信徒", "圣歌", "追问"], "rarity": 2,
		"tokens": [
			{"id": "extra_moon", "text": "一颗月亮", "lexeme_id": "object.extra_moon", "grammar_roles": ["object"], "phone_surface": "第二个月亮", "doctor_surface": "重复圆形", "doll_surface": "小月亮", "tags": ["圣歌", "信徒"], "rarity": 2},
			{"id": "than_reality", "text": "多出", "lexeme_id": "action.appear_extra", "grammar_roles": ["action"], "phone_surface": "自动生成", "doctor_surface": "发生复视", "doll_surface": "偷偷长出", "tags": ["追问", "反问"], "rarity": 2},
			{"id": "last_night", "text": "昨晚的照片", "lexeme_id": "subject.last_night_photo", "grammar_roles": ["subject"], "phone_surface": "昨夜影像", "doctor_surface": "患者图像记录", "doll_surface": "你藏起来的照片", "tags": ["日常"], "rarity": 1},
		],
	},
	{
		"id": "last_bus", "poster_cell": 4, "caption": "最后一班车没有终点", "handle": "末班路线图",
		"text": "旧帖：最后一班车从来没有终点站。", "tags": ["日常", "空位"], "rarity": 2,
		"tokens": [
			{"id": "last_bus", "text": "最后一班车", "lexeme_id": "subject.last_bus", "grammar_roles": ["subject"], "phone_surface": "末班路线", "doctor_surface": "反复交通意象", "doll_surface": "接我们回家的车", "tags": ["日常"], "rarity": 1},
			{"id": "no_terminal", "text": "没有抵达", "lexeme_id": "action.not_arrive", "grammar_roles": ["action"], "phone_surface": "未刷新到", "doctor_surface": "无法到达", "doll_surface": "忘了停在", "tags": ["空位", "沉默"], "rarity": 2},
			{"id": "old_post", "text": "终点", "lexeme_id": "object.terminal", "grammar_roles": ["object"], "phone_surface": "最终页面", "doctor_surface": "结束条件", "doll_surface": "家的门口", "tags": ["刷新", "哈吉米"], "rarity": 1},
		],
	},
	{
		"id": "blackout_broadcast", "poster_cell": 5, "caption": "停电后广播喊了我名字", "handle": "废站收音机",
		"text": "录音：停电以后，废站广播准时报站，然后叫了我的名字。", "tags": ["圣歌", "刷新", "沉默"], "rarity": 3,
		"tokens": [
			{"id": "blackout", "text": "废站广播", "lexeme_id": "subject.dead_station_radio", "grammar_roles": ["subject"], "phone_surface": "离线广播", "doctor_surface": "听觉内容", "doll_surface": "墙里的喇叭", "tags": ["沉默", "空位"], "rarity": 1},
			{"id": "broadcast", "text": "喊出", "lexeme_id": "action.call_out", "grammar_roles": ["action"], "phone_surface": "公开了", "doctor_surface": "重复呼唤", "doll_surface": "学会了", "tags": ["圣歌", "刷新"], "rarity": 2},
			{"id": "dead_station", "text": "我的名字", "lexeme_id": "object.my_name", "grammar_roles": ["object"], "phone_surface": "用户实名", "doctor_surface": "自我称呼", "doll_surface": "我给你的名字", "tags": ["巴别塔", "日常"], "rarity": 2},
		],
	},
	{
		"id": "station_lit", "poster_cell": 6, "caption": "废站台昨晚重新亮灯", "handle": "封站观察员",
		"text": "目击：封了十年的站台，昨晚重新亮灯。", "tags": ["巴别塔", "刷新"], "rarity": 2,
		"tokens": [
			{"id": "ten_years", "text": "封闭站台", "lexeme_id": "subject.closed_platform", "grammar_roles": ["subject"], "phone_surface": "停用站点", "doctor_surface": "封闭场景", "doll_surface": "没人等车的地方", "tags": ["禁问", "沉默"], "rarity": 2},
			{"id": "lit_again", "text": "重新亮起", "lexeme_id": "action.light_again", "grammar_roles": ["action"], "phone_surface": "恢复在线", "doctor_surface": "再次显现", "doll_surface": "又睁开", "tags": ["刷新", "巴别塔"], "rarity": 2},
			{"id": "platform", "text": "十年前的灯", "lexeme_id": "object.old_light", "grammar_roles": ["object"], "phone_surface": "过期指示灯", "doctor_surface": "陈旧光源记忆", "doll_surface": "你忘掉的小灯", "tags": ["日常", "空位"], "rarity": 1},
		],
	},
	{
		"id": "no_shadow", "poster_cell": 7, "caption": "便利店店员没有影子", "handle": "凌晨便利店",
		"text": "路过：店整夜开着，店员却没有影子。", "tags": ["日常", "沉默", "追问"], "rarity": 2,
		"tokens": [
			{"id": "all_night", "text": "便利店员", "lexeme_id": "subject.clerk", "grammar_roles": ["subject"], "phone_surface": "夜班账号", "doctor_surface": "无面孔人物", "doll_surface": "替我们看门的人", "tags": ["日常"], "rarity": 1},
			{"id": "no_shadow", "text": "没有留下", "lexeme_id": "action.leave_none", "grammar_roles": ["action"], "phone_surface": "删除了", "doctor_surface": "未形成", "doll_surface": "不肯带走", "tags": ["沉默", "空位"], "rarity": 2},
			{"id": "clerk", "text": "影子", "lexeme_id": "object.shadow", "grammar_roles": ["object"], "phone_surface": "在线痕迹", "doctor_surface": "自体投影", "doll_surface": "脚下的黑朋友", "tags": ["追问", "反问"], "rarity": 1},
		],
	},
	{
		"id": "future_notice", "poster_cell": 8, "caption": "小区群里出现不存在的住户", "handle": "明日群公告",
		"text": "截图：小区群凌晨多出一个查不到门牌的住户，还发来明天的失踪通知。", "tags": ["刷新", "禁问", "反问"], "rarity": 3,
		"tokens": [
			{"id": "tomorrow", "text": "明天的通知", "lexeme_id": "subject.tomorrow_notice", "grammar_roles": ["subject"], "phone_surface": "预约推送", "doctor_surface": "预期记录", "doll_surface": "明天塞进门缝的纸", "tags": ["刷新", "反问"], "rarity": 2},
			{"id": "missing", "text": "写着", "lexeme_id": "action.write", "grammar_roles": ["action"], "phone_surface": "标记为", "doctor_surface": "诊断为", "doll_surface": "偷偷叫作", "tags": ["禁问", "沉默"], "rarity": 3},
			{"id": "group", "text": "我的失踪", "lexeme_id": "object.my_disappearance", "grammar_roles": ["object"], "phone_surface": "用户离线", "doctor_surface": "对象缺席", "doll_surface": "你不回家", "tags": ["日常"], "rarity": 1},
		],
	},
	{
		"id": "old_post_today", "poster_cell": 9, "caption": "十年前旧帖今天回复我", "handle": "旧帖考古队",
		"text": "考古：十年前的旧帖今天突然回复我，头像是现在的我。", "tags": ["刷新", "哈吉米", "反问"], "rarity": 3,
		"tokens": [
			{"id": "ten_year_post", "text": "十年前的旧帖", "lexeme_id": "subject.old_post", "grammar_roles": ["subject"], "phone_surface": "历史缓存", "doctor_surface": "既往记录", "doll_surface": "以前写给你的信", "tags": ["刷新", "哈吉米"], "rarity": 2},
			{"id": "today_me", "text": "回复了", "lexeme_id": "action.reply", "grammar_roles": ["action"], "phone_surface": "重新推送", "doctor_surface": "回返为", "doll_surface": "开口叫了", "tags": ["日常", "追问"], "rarity": 2},
			{"id": "archaeology", "text": "今天的我", "lexeme_id": "object.today_self", "grammar_roles": ["object"], "phone_surface": "当前账号", "doctor_surface": "现时自我", "doll_surface": "现在陪我的你", "tags": ["信徒", "反问"], "rarity": 1},
		],
	},
	{
		"id": "deleted_road", "poster_cell": 10, "caption": "地图上少了一条回家路", "handle": "绿色路线图",
		"text": "更新：地图删掉了我每天回家的那条路。", "tags": ["空位", "日常", "刷新"], "rarity": 2,
		"tokens": [
			{"id": "deleted", "text": "地图", "lexeme_id": "subject.map", "grammar_roles": ["subject"], "phone_surface": "导航服务", "doctor_surface": "空间图式", "doll_surface": "你画的路线", "tags": ["刷新", "空位"], "rarity": 2},
			{"id": "way_home", "text": "删掉", "lexeme_id": "action.delete", "grammar_roles": ["action"], "phone_surface": "隐藏", "doctor_surface": "压抑", "doll_surface": "擦掉", "tags": ["日常"], "rarity": 1},
			{"id": "this_road", "text": "回家的路", "lexeme_id": "object.way_home", "grammar_roles": ["object"], "phone_surface": "返程路线", "doctor_surface": "退行路径", "doll_surface": "回到我这里的路", "tags": ["追问", "空位"], "rarity": 1},
		],
	},
	{
		"id": "access_record", "poster_cell": 11, "caption": "门禁说我没回家我却在屋里", "handle": "门禁空号",
		"text": "记录：门禁说我没回来，可我一直在屋里。", "tags": ["禁问", "追问", "日常"], "rarity": 2,
		"tokens": [
			{"id": "not_home", "text": "门禁记录", "lexeme_id": "subject.access_log", "grammar_roles": ["subject"], "phone_surface": "门禁系统", "doctor_surface": "行为记录", "doll_surface": "门口那只眼睛", "tags": ["禁问", "追问"], "rarity": 2},
			{"id": "inside", "text": "否认", "lexeme_id": "action.deny", "grammar_roles": ["action"], "phone_surface": "判定异常", "doctor_surface": "否定", "doll_surface": "假装没看见", "tags": ["日常", "反问"], "rarity": 1},
			{"id": "access", "text": "我在屋里", "lexeme_id": "object.inside_home", "grammar_roles": ["object"], "phone_surface": "用户已在家", "doctor_surface": "对象仍在场", "doll_surface": "你一直陪着我", "tags": ["巴别塔", "刷新"], "rarity": 1},
		],
	},
]
const DAY_PLANS := [
	{
		"title": "旧帖被顶上来",
		"trends": ["哈吉米", "追问", "日常"],
		"speaker": "同学",
		"line": "你刚才想说什么？",
		"feed": [
			{"id": "d1_a", "handle": "BABEL_404", "text": "有人说哈吉米只是一个打错的名字，但打错的人已经注销。", "tokens": [
				{"id": "phrase", "text": "打错的人已经注销", "tags": ["哈吉米", "追问"], "rarity": 1},
				{"id": "hajimi", "text": "哈吉米", "tags": ["哈吉米"], "rarity": 1},
				{"id": "wrong", "text": "打错", "tags": ["追问"], "rarity": 1},
			]},
			{"id": "d1_b", "handle": "课桌下的账号", "text": "别急着懂。先把它转出去，懂会在后面补票。", "tokens": [
				{"id": "phrase", "text": "懂会在后面补票", "tags": ["反问", "日常"], "rarity": 1},
				{"id": "understand", "text": "懂", "tags": ["追问"], "rarity": 1},
			]},
		],
	},
	{
		"title": "沉默用户在线",
		"trends": ["空位", "沉默", "哈吉米"],
		"speaker": "塔下信徒",
		"line": "你可以不用那些词，试着直接回答我。",
		"feed": [
			{"id": "d2_a", "handle": "SILENT_ROOT", "text": "那个沉默用户又在线了。在线本身就是发言。", "tokens": [
				{"id": "phrase", "text": "在线本身就是发言", "tags": ["沉默", "空位"], "rarity": 2},
				{"id": "silent", "text": "沉默", "tags": ["沉默"], "rarity": 1},
			]},
			{"id": "d2_b", "handle": "回声管理员", "text": "哈吉米没有解释，哈吉米只返回你发出去的形状。", "tokens": [
				{"id": "phrase", "text": "返回你发出去的形状", "tags": ["哈吉米", "空位"], "rarity": 2},
				{"id": "shape", "text": "形状", "tags": ["空位"], "rarity": 1},
			]},
		],
	},
	{
		"title": "第一层通知",
		"trends": ["巴别塔", "信徒", "刷新"],
		"speaker": "班里的转发者",
		"line": "你在哪一层？别说塔内地址，说你自己的话。",
		"feed": [
			{"id": "d3_a", "handle": "塔讯快报", "text": "第一级台阶确认开放。请用更新后的句式进入。", "tokens": [
				{"id": "phrase", "text": "更新后的句式", "tags": ["巴别塔", "刷新"], "rarity": 2},
				{"id": "tower", "text": "台阶", "tags": ["巴别塔"], "rarity": 1},
			]},
			{"id": "d3_b", "handle": "朝圣二群", "text": "塔不是建筑。塔是大家同时把解释往上挂。", "tokens": [
				{"id": "phrase", "text": "把解释往上挂", "tags": ["巴别塔", "信徒"], "rarity": 3},
				{"id": "hang", "text": "往上挂", "tags": ["信徒"], "rarity": 1},
			]},
		],
	},
	{
		"title": "解释开始回收",
		"trends": ["反问", "禁问", "哈吉米"],
		"speaker": "抄写员",
		"line": "如果不用它，你还剩下什么表达？",
		"feed": [
			{"id": "d4_a", "handle": "付费问答残页", "text": "为什么智者不说话？你为什么需要他说话？", "tokens": [
				{"id": "phrase", "text": "你为什么需要他说话", "tags": ["反问", "禁问"], "rarity": 2},
				{"id": "why", "text": "为什么", "tags": ["追问"], "rarity": 1},
			]},
			{"id": "d4_b", "handle": "旧语言回收站", "text": "普通话的边角被退了回来，剩下的词义按污染分拣。", "tokens": [
				{"id": "phrase", "text": "词义按污染分拣", "tags": ["空位", "禁问"], "rarity": 3},
				{"id": "pollution", "text": "污染", "tags": ["禁问"], "rarity": 1},
			]},
		],
	},
	{
		"title": "圣歌体扩散",
		"trends": ["圣歌", "信徒", "巴别塔"],
		"speaker": "楼梯口合唱者",
		"line": "你能把自己的问题说出来，而不是唱出来吗？",
		"feed": [
			{"id": "d5_a", "handle": "塔间合唱", "text": "塔啊，请把所有人挂成同一个句子。", "tokens": [
				{"id": "phrase", "text": "挂成同一个句子", "tags": ["圣歌", "巴别塔"], "rarity": 3},
				{"id": "chant", "text": "塔啊", "tags": ["圣歌"], "rarity": 1},
			]},
			{"id": "d5_b", "handle": "未命名小组", "text": "哈吉米在副歌里出现三次，第四次必须空着。", "tokens": [
				{"id": "phrase", "text": "第四次必须空着", "tags": ["哈吉米", "空位", "圣歌"], "rarity": 3},
				{"id": "empty", "text": "空着", "tags": ["空位"], "rarity": 1},
			]},
		],
	},
	{
		"title": "没有人在顶上",
		"trends": ["空位", "沉默", "巴别塔"],
		"speaker": "塔顶",
		"line": " ",
		"feed": [
			{"id": "d6_a", "handle": "塔顶直播", "text": "直播间没有画面。弹幕说这就是画面。", "tokens": [
				{"id": "phrase", "text": "这就是画面", "tags": ["空位", "巴别塔"], "rarity": 5},
				{"id": "blank", "text": "没有画面", "tags": ["空位"], "rarity": 3},
			]},
			{"id": "d6_b", "handle": "智者账号", "text": "该用户不存在。不存在是最后一次上线。", "tokens": [
				{"id": "phrase", "text": "不存在是最后一次上线", "tags": ["沉默", "空位"], "rarity": 5},
				{"id": "silence", "text": "不存在", "tags": ["沉默"], "rarity": 3},
			]},
		],
	},
]

var game: MemeGameState = MemeGameStateScript.new()
var _locale = GameLocaleScript.new()
var selected_token_id := ""
var selected_meme_id := ""
var log_text := ""
var _road_scroll := 0.0
var _input_locked := false

var _camera: Camera3D
var _road: Node3D
var _phone_rig: Node3D
var _npc: Node3D
var _reality_player: CharacterBody3D
var _reality_floor
var _reality_built_floor := 0
var _reality_built_day := 0
var _reality_yaw := 0.0
var _reality_pitch := 0.0
var _reality_last_safe_position := Vector3.ZERO
var _reality_mouse_look_enabled := false
var _reality_touch_look_index := -1
var _nearby_reality_actor: Area3D
var _nearby_reality_item: Area3D
var _active_reality_actor: Area3D
var _reality_interaction_active := false
var _canvas: CanvasLayer
var _ui_root: Control
var _texture_cache: Dictionary = {}
var _phone_down_backdrop_image: TextureRect
var _hand_phone_image: TextureRect
var _hand_tracking_receiver
var _hand_xray_overlay: Control
var _second_layer_texture: Texture2D
var _camera_consent_overlay: Control
var _camera_access_toggle: CheckButton
var _camera_consent_source_option: OptionButton
var _camera_computer_button: Button
var _camera_phone_button: Button
var _camera_source_button_group: ButtonGroup
var _camera_status_label: Label
var _camera_consent_copy: Label
var _phone_camera_connection_overlay: Control
var _phone_camera_connection_panel: PanelContainer
var _phone_camera_connection_status_label: Label
var _phone_camera_connection_detail_label: Label
var _phone_camera_connection_retry_button: Button
var _phone_camera_connection_continue_button: Button
var _cinematic_bars: CinematicBars
var _hud_panel: PanelContainer
var _hud_reveal_zone: Control
var _hud_reveal_indicator: ColorRect
var _hud_settings_icon: Button
var _hud_actions_label: Label
var _hud_tooltip: PanelContainer
var _hud_tooltip_label: Label
var _edge_drawer: EdgeDrawer
var _world_prompt: Label
var _desk_log: Label
var _main_menu_layer: Control
var _prologue_overlay: Control
var _prologue_line_label: Label
var _prologue_counter_label: Label
var _prologue_continue_button: Button
var _prologue_index := 0
var _settings_window: PanelContainer
var _settings_history_panel: SettingsHistoryPanel
var _social_feed_panel
var _language_overlay: Control
var _language_overlay_first_run := false
var _view_toggle_button: Button
var _vhs_overlay: Control
var _vhs_scanlines: Array[ColorRect] = []
var _vhs_shader_rect: ColorRect
var _phone_panel: PanelContainer
var _phone_tab: Button
var _phone_content: Control
var _phone_title: Label
var _app_window: PanelContainer
var _app_title: Label
var _app_body: VBoxContainer
var _app_windows: Dictionary = {}
var _app_titles: Dictionary = {}
var _app_bodies: Dictionary = {}
var _publish_panel: PanelContainer
var _publish_blank: DropButton
var _confirm_publish_button: Button
var _meme_bank_tab: Button
var _meme_bank_drag_handle: Label
var _meme_bank_window: Control
var _meme_bank_content: Control
var _bank_list: Control
var _meme_bank_ring: Control
var _meme_bank_focus_label: Label
var _meme_bank_selected_index := 0
var _meme_bank_tween: Tween
var _reality_subtitle_panel: PanelContainer
var _reality_subtitle_label: RichTextLabel
var _reality_choice_row: HBoxContainer
var _reality_intent_preview: RichTextLabel
var _reality_typing_line: RichTextLabel
var _reality_typing_progress: Label
var _reality_continue_button: Button
var _reality_hover_choice_id := ""
var _reality_language_frame: PanelContainer
var _reality_language_slot_row: HBoxContainer
var _reality_language_token_flow: HFlowContainer
var _reality_language_preview: Label
var _reality_language_confirm: Button
var _selected_language_token_id := ""
var _playtest_assist_panel: PanelContainer
var _playtest_assist_label: Label
var _playtest_assist_enabled := OS.is_debug_build() or OS.get_environment("BABEL_PLAYTEST_ASSIST") == "1"
var _flashback_overlay: PollutionFlashbackDirector
var _ui_theme: Theme
var _pickup_press_audio: AudioStreamPlayer
var _pickup_land_audio: AudioStreamPlayer
var _notebook_hinge_audio: AudioStreamPlayer
var _pickup_flight_layer: FlyToTargetLayer
var _notebook_squash_tween: Tween
var _doll_guide_panel: PanelContainer
var _doll_guide_line_label: Label
var _doll_guide_body: VBoxContainer
var _doll_companion: Node3D
var _phone_ambience: AudioStreamPlayer
var _reality_ambience: AudioStreamPlayer
var _pollution_ambience: AudioStreamPlayer
var _flashback_audio: AudioStreamPlayer
var _action_tick_audio: AudioStreamPlayer
var _cover_watcher_stinger: AudioStreamPlayer
var _audio_tween: Tween
var _action_spend_overlay: Control
var _action_spend_blackout: ColorRect
var _action_spend_label: Label
var _action_spend_tween: Tween
var _action_spend_after_actions := -1
var _action_spend_should_settle := false
var _day_transition_overlay: Control
var _day_transition_day_label: Label
var _day_transition_meta_label: Label
var _day_transition_hint_label: Label
var _day_transition_rule: ColorRect
var _day_transition_tween: Tween
var _day_transition_settled := false
var _meme_bank_open := false
var _phone_popup_expanded := true
var _phone_launcher_open := true
var _meme_bank_layout_mode := ""
var _open_app_windows: Dictionary = {}
var _social_screen := "home"
var _social_channel := "discover"
var _social_detail_post_index := 0
var _social_detail_open := false
var _notebook_crafting_tab := "frame"
var _window_manager: DraggableWindowManager
var _last_responsive_layout_size := Vector2.ZERO
var _game_started := false
var _vhs_enabled := true
var _master_volume := 80.0
var _camera_enabled := false
var _camera_source := "computer"
var _camera_session_decided := false
var _camera_tracking_status := "摄像头未启用"
var _camera_ready_source := ""
var _camera_ready_index := -1
var _phone_art_alpha := 0.0
var _save_path := SAVE_PATH


func _ready() -> void:
	var preferences := _locale.load_preferences(_master_volume, _vhs_enabled)
	_master_volume = float(preferences.get("master_volume", _master_volume))
	_vhs_enabled = bool(preferences.get("vhs_enabled", _vhs_enabled))
	_camera_enabled = bool(preferences.get("camera_enabled", false))
	_camera_source = str(preferences.get("camera_source", "computer"))
	_camera_session_decided = false
	_ensure_hand_tracking_receiver()
	_ensure_window_manager()
	_ensure_edge_drawer()
	_apply_master_volume()
	show_main_menu()
	if not _locale.language_selected:
		_build_language_selection_overlay(true)


func _process(delta: float) -> void:
	if _hand_tracking_receiver != null:
		_hand_tracking_receiver.poll()
	if _camera == null:
		return
	if _game_started:
		_ensure_reality_floor_current()
		_refresh_nearby_reality_actor()
		_apply_responsive_layouts_if_needed()
		if _edge_drawer != null:
			_edge_drawer.tick(delta)
		_update_doll_companion(delta)
	_animate_world(delta)


func _exit_tree() -> void:
	if _hand_tracking_receiver != null:
		_hand_tracking_receiver.stop()


func _physics_process(delta: float) -> void:
	if not _game_started or _reality_player == null:
		return
	_update_reality_player(delta)


func _input(event: InputEvent) -> void:
	if _prologue_overlay != null and _prologue_overlay.visible:
		_reality_touch_look_index = -1
		return
	if _input_locked:
		_reality_touch_look_index = -1
		return
	if _edge_drawer != null and _edge_drawer.handle_global_input(event):
		return
	if _handle_reality_touch_look(event):
		return
	if _handle_reality_trackpad_pan(event):
		return
	if _window_manager != null:
		_window_manager.handle_global_input(event)


func _handle_reality_touch_look(event: InputEvent) -> bool:
	var can_touch_look: bool = _game_started and game.view_state == "npc_up" and not _reality_interaction_active
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if not touch.pressed:
			if touch.index == _reality_touch_look_index:
				_reality_touch_look_index = -1
			return false
		if can_touch_look and _reality_touch_look_index < 0:
			_reality_touch_look_index = touch.index
		return false
	if event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if not can_touch_look:
			_reality_touch_look_index = -1
			return false
		if _reality_touch_look_index < 0:
			_reality_touch_look_index = drag.index
		if drag.index != _reality_touch_look_index:
			return false
		var delta: Vector2 = drag.screen_relative
		if delta.is_zero_approx():
			delta = drag.relative
		if not delta.is_zero_approx():
			_apply_reality_look_delta(delta, REALITY_TOUCH_SENSITIVITY)
		get_viewport().set_input_as_handled()
		return true
	return false


func _handle_reality_trackpad_pan(event: InputEvent) -> bool:
	if not event is InputEventPanGesture:
		return false
	var can_trackpad_look: bool = _game_started and game.view_state == "npc_up" and not _reality_interaction_active
	if not can_trackpad_look:
		return false
	var pan := event as InputEventPanGesture
	if pan.delta.is_zero_approx():
		return false
	# macOS reports pan as content-scroll direction, opposite to the fingers.
	_apply_reality_look_delta(-pan.delta, REALITY_TRACKPAD_SENSITIVITY)
	get_viewport().set_input_as_handled()
	return true


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked or not _game_started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _reality_interaction_active and game.conversation_phase == "typing" and event.keycode != KEY_ESCAPE:
			if _advance_typed_reality_character():
				get_viewport().set_input_as_handled()
				return
		if event.is_action_pressed("reality_interact"):
			_try_reality_interaction()
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("reality_phone"):
			_toggle_view_state()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_ESCAPE:
			if _reality_interaction_active:
				_exit_reality_interaction()
			else:
				_set_reality_mouse_look(false)
			get_viewport().set_input_as_handled()
			return
	if game.view_state != "npc_up" or _reality_interaction_active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_set_reality_mouse_look(true)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _reality_mouse_look_enabled:
		var motion := event as InputEventMouseMotion
		_apply_reality_look_delta(motion.relative, REALITY_MOUSE_SENSITIVITY)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and _reality_mouse_look_enabled:
		var drag := event as InputEventScreenDrag
		_apply_reality_look_delta(drag.relative, REALITY_TOUCH_SENSITIVITY)
		get_viewport().set_input_as_handled()


func new_game() -> void:
	var fresh_state: MemeGameState = MemeGameStateScript.new()
	fresh_state.new_run()
	_begin_game_session(fresh_state, {}, true)


func continue_game() -> bool:
	var payload := _load_save_payload()
	if payload.is_empty():
		return false
	var restored_state: MemeGameState = MemeGameStateScript.new()
	var saved_state: Variant = payload.get("game", {})
	if not saved_state is Dictionary or not restored_state.load_save_data(saved_state):
		return false
	_begin_game_session(restored_state, payload.get("world", {}), false)
	return true


func _begin_game_session(session_state: MemeGameState, world_data: Dictionary, show_prologue: bool) -> void:
	_game_started = true
	_phone_art_alpha = 1.0
	_second_layer_texture = null
	game = session_state
	_migrate_social_author_ids()
	selected_token_id = ""
	selected_meme_id = ""
	_meme_bank_open = false
	_phone_popup_expanded = true
	_phone_launcher_open = game.active_app_window.is_empty()
	_meme_bank_layout_mode = ""
	_open_app_windows = {}
	if not game.active_app_window.is_empty():
		_open_app_windows[game.active_app_window] = true
	_social_screen = "home"
	_social_channel = "discover"
	_social_detail_post_index = 0
	_social_detail_open = false
	if _social_feed_panel != null:
		_social_feed_panel.set_detail_post_index(0)
		_social_feed_panel.close_detail()
	_notebook_crafting_tab = "frame"
	_app_windows = {}
	_app_titles = {}
	_app_bodies = {}
	_action_spend_after_actions = -1
	_action_spend_should_settle = false
	_day_transition_settled = false
	_ensure_window_manager()
	_window_manager.clear()
	_last_responsive_layout_size = Vector2.ZERO
	_reality_built_floor = 0
	_reality_built_day = 0
	_reality_yaw = _reality_floor.start_yaw_degrees()
	_reality_pitch = 0.0
	_set_reality_mouse_look(false)
	_nearby_reality_actor = null
	_nearby_reality_item = null
	_active_reality_actor = null
	_reality_interaction_active = false
	_prologue_index = 0
	log_text = "你低头，手机边框从视野下方亮起来。" if show_prologue else "你回到离开时的位置。"
	_build_world()
	_restore_saved_world(world_data)
	_build_ui()
	if not show_prologue:
		_skip_prologue()
	_render()
	_set_reality_mouse_look(game.view_state == "npc_up")
	_sync_audio_state(true)


func show_main_menu() -> void:
	if _game_started:
		if _reality_interaction_active:
			_exit_reality_interaction(false)
		_save_progress()
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)
	_game_started = false
	if _settings_history_panel != null and is_instance_valid(_settings_history_panel):
		_settings_history_panel.close_settings()
	_set_input_locked(false)
	_phone_art_alpha = 0.0
	_phone_launcher_open = false
	_reality_interaction_active = false
	_active_reality_actor = null
	_nearby_reality_actor = null
	_nearby_reality_item = null
	_set_reality_mouse_look(false)
	_build_world()
	_build_main_menu()
	if _locale.language_selected and not _camera_session_decided:
		_build_camera_consent_overlay()
	_sync_audio_state(true)


func _save_progress() -> bool:
	if not _game_started or game == null:
		return false
	var world_data := {
		"player_position": _reality_player.position if _reality_player != null else Vector3.ZERO,
		"yaw": _reality_yaw,
		"pitch": _reality_pitch,
		"social_screen": _social_screen,
		"social_channel": _social_channel,
		"social_detail_post_index": _social_detail_post_index,
	}
	var payload := {
		"version": SAVE_FILE_VERSION,
		"game": game.to_save_data(),
		"world": world_data,
	}
	var file := FileAccess.open(_save_path, FileAccess.WRITE)
	if file == null:
		push_warning("无法写入存档：%s" % _save_path)
		return false
	file.store_var(payload)
	file.flush()
	return true


func _load_save_payload() -> Dictionary:
	if not FileAccess.file_exists(_save_path):
		return {}
	var file := FileAccess.open(_save_path, FileAccess.READ)
	if file == null:
		return {}
	var payload: Variant = file.get_var()
	if not payload is Dictionary or int(payload.get("version", -1)) != SAVE_FILE_VERSION:
		return {}
	if not payload.get("game", {}) is Dictionary or not payload.get("world", {}) is Dictionary:
		return {}
	return payload


func _has_save_progress() -> bool:
	return not _load_save_payload().is_empty()


func _restore_saved_world(world_data: Dictionary) -> void:
	if world_data.is_empty():
		return
	var saved_position: Variant = world_data.get("player_position", Vector3.ZERO)
	if saved_position is Vector3 and _reality_player != null and _reality_floor != null:
		_reality_last_safe_position = _reality_floor.clamp_to_playable_position(saved_position, REALITY_SAFE_INSET)
		_reality_player.position = _reality_last_safe_position
		_reality_player.velocity = Vector3.ZERO
	_reality_yaw = wrapf(float(world_data.get("yaw", 0.0)), -180.0, 180.0)
	_reality_pitch = clampf(float(world_data.get("pitch", 0.0)), -68.0, 72.0)
	_social_screen = str(world_data.get("social_screen", "home"))
	if _social_screen not in ["home", "detail", "publish", "profile"]:
		_social_screen = "home"
	_social_channel = _normalize_social_channel(str(world_data.get("social_channel", "discover")))
	_social_detail_post_index = clampi(int(world_data.get("social_detail_post_index", 0)), 0, maxi(0, SOCIAL_POST_CARDS.size() - 1))
	if _social_feed_panel != null:
		_social_feed_panel.set_detail_post_index(_social_detail_post_index)


func _normalize_social_channel(channel: String) -> String:
	var legacy_channels := {
		"关注": "following",
		"发现": "discover",
		"塔下": "tower_base",
		"附近": "nearby",
	}
	var normalized := str(legacy_channels.get(channel, channel))
	for channel_data in SOCIAL_CHANNELS:
		if str(channel_data.get("id", "")) == normalized:
			return normalized
	return "discover"


func _migrate_social_author_ids() -> void:
	var migrated: Array[String] = []
	for stored_author in game.social_followed_handles:
		var stable_id := str(stored_author)
		for post in SOCIAL_POST_CARDS:
			if str(post.get("handle", "")) == stable_id:
				stable_id = str(post.get("id", stable_id))
				break
		if stable_id not in migrated:
			migrated.append(stable_id)
	game.social_followed_handles = migrated


func set_view_state(value: String) -> void:
	if _input_locked:
		return
	if value == "npc_up" and game.view_state == "phone_down":
		_capture_phone_layer_for_xray()
	if game.set_view_state(value):
		_reality_interaction_active = false
		_active_reality_actor = null
		_nearby_reality_actor = null
		_nearby_reality_item = null
		_reality_hover_choice_id = ""
		game.reset_typed_reality_conversation()
		if value == "npc_up":
			_set_reality_mouse_look(true)
			log_text = "你放下手机，大街重新获得纵深。"
			_meme_bank_open = false
			_phone_launcher_open = false
		else:
			_set_reality_mouse_look(false)
			log_text = "你又低头看向手机。"
			_phone_launcher_open = game.active_app_window.is_empty()
			if not game.active_app_window.is_empty():
				_open_app_windows[game.active_app_window] = true
			if _phone_panel != null:
				_phone_panel.move_to_front()
		_render()
		_sync_audio_state(false)


func _toggle_view_state() -> void:
	if game.view_state == "phone_down":
		set_view_state("npc_up")
	else:
		set_view_state("phone_down")


func _capture_phone_layer_for_xray() -> bool:
	if not _game_started or get_viewport() == null or DisplayServer.get_name().to_lower() == "headless":
		return false
	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		return false
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		return false
	_second_layer_texture = ImageTexture.create_from_image(image)
	if _hand_xray_overlay != null:
		_hand_xray_overlay.set_layer_texture(_second_layer_texture)
	return true


func _set_reality_mouse_look(enabled: bool) -> void:
	_reality_mouse_look_enabled = enabled
	if not enabled or game.view_state != "npc_up":
		_reality_touch_look_index = -1
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if enabled else Input.MOUSE_MODE_VISIBLE)


func _apply_reality_look_delta(relative_motion: Vector2, sensitivity: float) -> void:
	_reality_yaw = wrapf(_reality_yaw - relative_motion.x * sensitivity, -180.0, 180.0)
	_reality_pitch = clampf(_reality_pitch - relative_motion.y * sensitivity, -68.0, 72.0)


func _build_world() -> void:
	if _day_transition_tween != null and _day_transition_tween.is_valid():
		_day_transition_tween.kill()
	_day_transition_tween = null
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	_audio_tween = null
	_hand_xray_overlay = null
	_camera_consent_overlay = null
	_camera_access_toggle = null
	_camera_consent_source_option = null
	_camera_computer_button = null
	_camera_phone_button = null
	_camera_source_button_group = null
	_camera_status_label = null
	_camera_consent_copy = null
	_phone_camera_connection_overlay = null
	_phone_camera_connection_panel = null
	_phone_camera_connection_status_label = null
	_phone_camera_connection_detail_label = null
	_phone_camera_connection_retry_button = null
	_phone_camera_connection_continue_button = null
	for child in get_children():
		remove_child(child)
		child.free()

	_camera = Camera3D.new()
	_camera.name = "Camera3D"
	add_child(_camera)
	_camera.current = true
	_camera.fov = 58.0
	_configure_reality_depth_of_field()
	_ensure_reality_input_map()

	_reality_player = CharacterBody3D.new()
	_reality_player.name = "RealityPlayer"
	_reality_player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	_reality_player.collision_layer = 1
	_reality_player.collision_mask = 1
	add_child(_reality_player)
	var player_collision := CollisionShape3D.new()
	player_collision.name = "PlayerCollision"
	var player_capsule := CapsuleShape3D.new()
	player_capsule.radius = 0.34
	player_capsule.height = 1.72
	player_collision.shape = player_capsule
	player_collision.position.y = 0.88
	_reality_player.add_child(player_collision)

	_reality_floor = RealityFloorGeneratorScript.new()
	_reality_floor.name = "RealityFloor"
	_reality_floor.cover_watcher_appeared.connect(_on_cover_watcher_appeared)
	_reality_floor.cover_watcher_vanished.connect(_on_cover_watcher_vanished)
	add_child(_reality_floor)
	_rebuild_reality_floor()

	_road = Node3D.new()
	_road.name = "Road"
	add_child(_road)
	for index in 3:
		var tile := MeshInstance3D.new()
		tile.name = "RoadTile%d" % index
		var plane := PlaneMesh.new()
		plane.size = Vector2(7.0, 4.0)
		tile.mesh = plane
		tile.position = Vector3(0.0, -0.08, -2.0 - index * 3.8)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = _theme_color("accent").darkened(0.50 - index * 0.08)
		mat.roughness = 0.8
		tile.material_override = mat
		_road.add_child(tile)

	_phone_rig = Node3D.new()
	_phone_rig.name = "PhoneRig"
	add_child(_phone_rig)
	var phone_body := MeshInstance3D.new()
	phone_body.name = "PhoneBody"
	var phone_box := BoxMesh.new()
	phone_box.size = Vector3(1.0, 0.08, 1.65)
	phone_body.mesh = phone_box
	var phone_mat := StandardMaterial3D.new()
	phone_mat.albedo_color = _theme_color("accent")
	phone_body.material_override = phone_mat
	_phone_rig.add_child(phone_body)
	var phone_screen := MeshInstance3D.new()
	phone_screen.name = "PhoneScreen"
	var screen_box := BoxMesh.new()
	screen_box.size = Vector3(0.84, 0.085, 1.35)
	phone_screen.mesh = screen_box
	phone_screen.position = Vector3(0.0, 0.006, 0.0)
	var screen_mat := StandardMaterial3D.new()
	screen_mat.albedo_color = _theme_color("ink")
	screen_mat.emission_enabled = true
	screen_mat.emission = _theme_color("accent")
	screen_mat.emission_energy_multiplier = 0.35
	phone_screen.material_override = screen_mat
	_phone_rig.add_child(phone_screen)

	_npc = Node3D.new()
	_npc.name = "NPC"
	add_child(_npc)
	var npc_body := MeshInstance3D.new()
	npc_body.name = "NPCPlane"
	var npc_quad := QuadMesh.new()
	npc_quad.size = Vector2(1.6, 2.4)
	npc_body.mesh = npc_quad
	npc_body.position = Vector3(0.0, 1.25, -3.2)
	var npc_mat := StandardMaterial3D.new()
	npc_mat.albedo_color = _theme_color("surface")
	npc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	npc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	npc_mat.emission_enabled = true
	npc_mat.emission = _theme_color("muted")
	npc_mat.emission_energy_multiplier = 0.12
	npc_body.material_override = npc_mat
	_npc.add_child(npc_body)

	_canvas = CanvasLayer.new()
	_canvas.name = "CanvasLayer"
	add_child(_canvas)
	_build_audio_players()


func _configure_reality_depth_of_field() -> void:
	if _camera == null:
		return
	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 18.0
	attributes.dof_blur_far_transition = 12.0
	attributes.dof_blur_amount = 0.08
	attributes.dof_blur_near_enabled = false
	_camera.attributes = attributes
	_camera.set_meta("fixed_focus_profile", "near_clear_far_soft")
	_camera.set_meta("focus_distance_m", 18.0)
	_camera.set_meta("far_transition_m", 12.0)


func _ensure_reality_input_map() -> void:
	_set_key_action("reality_forward", [KEY_W, KEY_UP])
	_set_key_action("reality_back", [KEY_S, KEY_DOWN])
	_set_key_action("reality_left", [KEY_A, KEY_LEFT])
	_set_key_action("reality_right", [KEY_D, KEY_RIGHT])
	_set_key_action("reality_sprint", [KEY_SHIFT])
	_set_key_action("reality_interact", [KEY_F])
	_set_key_action("reality_phone", [KEY_TAB])


func _set_key_action(action_name: StringName, keycodes: Array) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	InputMap.action_erase_events(action_name)
	for keycode in keycodes:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = int(keycode)
		InputMap.action_add_event(action_name, key_event)


func _rebuild_reality_floor() -> void:
	if _reality_floor == null or game == null:
		return
	var npc_textures: Array[Texture2D] = []
	for texture_path in NPC_CHARACTER_PATHS:
		var texture := _load_runtime_texture(str(texture_path))
		if texture != null:
			npc_textures.append(texture)
	var key_dialogue: Dictionary = LanguageCorruptionContentScript.get_key_npc_dialogue_for_floor(clampi(game.tower_floor, 1, 3))
	var key_npc_texture: Texture2D = null
	if not npc_textures.is_empty():
		key_npc_texture = npc_textures[posmod(game.tower_floor - 1, npc_textures.size())]
	var actor_textures := {
		"key_npc": key_npc_texture,
		"key_npc_label": str(key_dialogue.get("actor_label", "关键住户")),
		"npcs": npc_textures,
		"doll": _load_runtime_texture(GUIDE_DOLL_CHARACTER_PATH),
		"doll_encounter": LanguageCorruptionContentScript.get_doll_encounter_for_floor(clampi(game.tower_floor, 1, 3)),
	}
	var prerequisite_item: Dictionary = game.get_prerequisite_item_for_floor(game.tower_floor)
	_reality_floor.rebuild(game.tower_floor, _active_palette(), actor_textures, game.day, game.has_seen_cover_watcher(game.tower_floor), prerequisite_item)
	_reality_floor.set_playtest_assist_enabled(_playtest_assist_enabled)
	_reality_floor.sync_collected_items(game.collected_world_item_ids)
	_reality_floor.sync_prerequisite_items(game.revealed_prerequisite_item_ids, game.collected_prerequisite_item_ids)
	_reality_floor.sync_claimed_dolls(game.claimed_doll_ids)
	_reality_built_floor = game.tower_floor
	_reality_built_day = game.day
	_reality_interaction_active = false
	_active_reality_actor = null
	_nearby_reality_actor = null
	_nearby_reality_item = null
	if _reality_player != null:
		_reality_last_safe_position = _reality_floor.start_position()
		_reality_player.position = _reality_last_safe_position
		_reality_player.velocity = Vector3.ZERO
	_reality_yaw = 0.0
	_reality_pitch = 0.0


func _ensure_reality_floor_current() -> void:
	if _reality_floor == null or game == null:
		return
	if _reality_built_floor != game.tower_floor:
		_rebuild_reality_floor()
	elif _reality_built_day != game.day:
		_reality_floor.configure_authored_events(game.day, _active_palette())
		_reality_built_day = game.day


func _room_count_for_floor(floor_number: int) -> int:
	return RealityFloorGeneratorScript.room_count_for_floor(floor_number)


func _npc_count_for_floor(floor_number: int) -> int:
	return RealityFloorGeneratorScript.npc_count_for_floor(floor_number)


func _update_reality_player(delta: float) -> void:
	if _should_recover_reality_player():
		_recover_reality_player()
		return
	var can_walk: bool = game.view_state == "npc_up" and not _reality_interaction_active and not _input_locked
	var input_vector := Vector2.ZERO
	if can_walk:
		input_vector = Input.get_vector("reality_left", "reality_right", "reality_forward", "reality_back")
	var local_direction := Vector3(input_vector.x, 0.0, input_vector.y)
	var world_direction := Basis(Vector3.UP, deg_to_rad(_reality_yaw)) * local_direction
	if world_direction.length_squared() > 0.001:
		world_direction = world_direction.normalized()
	var speed_multiplier := REALITY_SPRINT_MULTIPLIER if can_walk and Input.is_action_pressed("reality_sprint") else 1.0
	var target_velocity := world_direction * REALITY_MOVE_SPEED * speed_multiplier
	var acceleration := REALITY_ACCELERATION * speed_multiplier
	_reality_player.velocity.x = move_toward(_reality_player.velocity.x, target_velocity.x, acceleration * delta)
	_reality_player.velocity.z = move_toward(_reality_player.velocity.z, target_velocity.z, acceleration * delta)
	if not _reality_player.is_on_floor():
		_reality_player.velocity.y -= 18.0 * delta
	else:
		_reality_player.velocity.y = 0.0
	_reality_player.rotation.y = deg_to_rad(_reality_yaw)
	_reality_player.move_and_slide()
	if _should_recover_reality_player():
		_recover_reality_player()
	elif _reality_player.is_on_floor() and _reality_floor != null and _reality_floor.contains_playable_position(_reality_player.position, REALITY_SAFE_INSET):
		_reality_last_safe_position = _reality_player.position


func _should_recover_reality_player() -> bool:
	if _reality_player == null or _reality_floor == null:
		return false
	if _reality_player.position.y < REALITY_FALL_RECOVERY_Y:
		return true
	return not _reality_floor.contains_playable_position(_reality_player.position, -2.0)


func _recover_reality_player() -> void:
	if _reality_player == null or _reality_floor == null:
		return
	var recovery_position := _reality_last_safe_position
	if not _reality_floor.contains_playable_position(recovery_position, REALITY_SAFE_INSET):
		recovery_position = _reality_floor.start_position()
	recovery_position = _reality_floor.clamp_to_playable_position(recovery_position, REALITY_SAFE_INSET)
	recovery_position.y = 0.08
	_reality_player.position = recovery_position
	_reality_player.velocity = Vector3.ZERO


func _refresh_nearby_reality_actor() -> void:
	var previous_actor := _nearby_reality_actor
	var previous_item := _nearby_reality_item
	if game.view_state != "npc_up" or _reality_interaction_active or _reality_floor == null or _reality_player == null:
		_nearby_reality_actor = null
		_nearby_reality_item = null
		if previous_actor != null or previous_item != null:
			_render_world_prompt()
			if _world_prompt != null:
				_world_prompt.visible = false
		return
	var nearest: Area3D = null
	var nearest_kind := ""
	var nearest_distance := REALITY_INTERACTION_DISTANCE
	for actor in _reality_floor.get_interactable_actors():
		var offset: Vector3 = actor.position - _reality_player.position
		offset.y = 0.0
		var distance: float = offset.length()
		if distance <= nearest_distance:
			nearest = actor
			nearest_kind = "actor"
			nearest_distance = distance
	for item in _reality_floor.get_interactable_items():
		var item_offset: Vector3 = item.position - _reality_player.position
		item_offset.y = 0.0
		var item_distance: float = item_offset.length()
		if item_distance <= nearest_distance:
			nearest = item
			nearest_kind = "item"
			nearest_distance = item_distance
	_nearby_reality_actor = nearest if nearest_kind == "actor" else null
	_nearby_reality_item = nearest if nearest_kind == "item" else null
	if previous_actor != _nearby_reality_actor or previous_item != _nearby_reality_item:
		_render_world_prompt()
		if _world_prompt != null:
			_world_prompt.visible = nearest != null


func _try_reality_interaction() -> bool:
	if game.view_state != "npc_up":
		return false
	if _reality_interaction_active:
		_exit_reality_interaction()
		return true
	_refresh_nearby_reality_actor()
	if _nearby_reality_item != null:
		return _collect_nearby_reality_item()
	if _nearby_reality_actor == null:
		return false
	_active_reality_actor = _nearby_reality_actor
	var actor_id := str(_active_reality_actor.get_meta("actor_id", "actor"))
	var actor_type := str(_active_reality_actor.get_meta("actor_type", "npc"))
	var actor_label := _locale.translate(str(_active_reality_actor.get_meta("display_name", "对方")))
	if not game.start_typed_reality_conversation(actor_id, actor_type, actor_label):
		_active_reality_actor = null
		return false
	if actor_type == "doll":
		game.notify_tutorial("guide_found", {"actor_id": actor_id})
	_localize_active_conversation()
	var actor_direction: Vector3 = _active_reality_actor.position - _reality_player.position
	if actor_direction.length_squared() > 0.001:
		_reality_yaw = rad_to_deg(atan2(-actor_direction.x, -actor_direction.z))
		_reality_pitch = -30.0 if actor_type == "doll" else -2.0
	_reality_interaction_active = true
	_reality_hover_choice_id = ""
	_set_reality_mouse_look(false)
	log_text = "你停在%s面前。" % _active_actor_display_name()
	_render()
	_sync_audio_state(false)
	return true


func _localize_active_conversation() -> void:
	game.conversation_actor_label = _locale.translate(game.conversation_actor_label)
	game.conversation_prompt = _locale.translate(game.conversation_prompt)
	game.conversation_result_line = _locale.translate(game.conversation_result_line)
	var localized_choices: Array = []
	for choice in game.conversation_choices:
		var localized_choice: Dictionary = (choice as Dictionary).duplicate(true)
		localized_choice["summary"] = _locale.translate(str(localized_choice.get("summary", "")))
		localized_choice["sentence"] = _locale.translate(str(localized_choice.get("sentence", "")))
		localized_choices.append(localized_choice)
	game.conversation_choices = localized_choices
	game.configure_conversation_locale(_locale.current_locale)


func _collect_nearby_reality_item() -> bool:
	if _nearby_reality_item == null:
		return false
	var item := _nearby_reality_item
	var item_data := {
		"id": str(item.get_meta("item_id", "")),
		"label": str(item.get_meta("display_name", "街区遗物")),
		"effect": str(item.get_meta("item_effect", "")),
		"value": item.get_meta("item_value", 0),
		"description": str(item.get_meta("item_description", "")),
	}
	if not game.collect_world_item(item_data):
		return false
	item.set_meta("collected", true)
	item.visible = false
	item.monitoring = false
	item.monitorable = false
	_nearby_reality_item = null
	if not game.event_log.is_empty():
		log_text = game.event_log[0]
	_render()
	return true


func _exit_reality_interaction(should_render: bool = true) -> void:
	_reality_interaction_active = false
	_active_reality_actor = null
	_reality_hover_choice_id = ""
	_selected_language_token_id = ""
	game.reset_typed_reality_conversation()
	if game.view_state == "npc_up":
		_set_reality_mouse_look(true)
	if should_render:
		_render()
		_sync_audio_state(false)


func _active_actor_display_name() -> String:
	if _active_reality_actor == null:
		return _locale.translate("对方")
	return _locale.translate(str(_active_reality_actor.get_meta("display_name", "对方")))


func _build_audio_players() -> void:
	var initial_floor := 1 if game == null else clampi(int(game.tower_floor), 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	_phone_ambience = _make_audio_player("PhoneRoadAmbience", _phone_music_path_for_floor(initial_floor), true, -60.0)
	_phone_ambience.set_meta("phone_music_floor", initial_floor)
	_reality_ambience = _make_audio_player("RealityRoomAmbience", REALITY_AMBIENCE_PATH, true, -60.0)
	_pollution_ambience = _make_audio_player("PollutionMusicLayer", POLLUTION_AMBIENCE_PATH, true, -60.0)
	_flashback_audio = _make_audio_player("PollutionFlashbackAudio", FLASHBACK_AUDIO_PATH, false, -8.0)
	_pickup_press_audio = _make_audio_player("PickupPressAudio", PICKUP_PRESS_AUDIO_PATH, false, -16.0)
	_pickup_land_audio = _make_audio_player("PickupLandAudio", PICKUP_LAND_AUDIO_PATH, false, -11.0)
	_notebook_hinge_audio = _make_audio_player("NotebookHingeAudio", NOTEBOOK_HINGE_AUDIO_PATH, false, -14.0)
	_action_tick_audio = _make_audio_player("ActionTickAudio", ACTION_TICK_AUDIO_PATH, false, -15.0)
	_cover_watcher_stinger = _make_audio_player("CoverWatcherStinger", COVER_WATCHER_STINGER_PATH, false, -9.0)
	_sync_audio_state(true)


func _on_cover_watcher_appeared(floor_number: int) -> void:
	if game != null:
		game.mark_cover_watcher_seen(floor_number)
	if _cover_watcher_stinger != null and _cover_watcher_stinger.stream != null and is_inside_tree():
		_cover_watcher_stinger.stop()
		_cover_watcher_stinger.play()


func _on_cover_watcher_vanished(_floor_number: int) -> void:
	# The stinger is intentionally allowed to finish after the figure has withdrawn.
	if game != null:
		game.event_log.push_front("掩体后的人影缩了回去。它没有留下脸。")


func _make_audio_player(node_name: String, path: String, looped: bool, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.stream = _load_generated_wav(path, looped)
	player.volume_db = volume_db
	player.set_meta("generated_audio_path", path)
	player.set_meta("looped", looped)
	add_child(player)
	return player


func _load_generated_wav(path: String, looped: bool) -> AudioStreamWAV:
	var stream := AudioStreamWAV.load_from_file(path)
	if stream == null:
		return null
	if looped:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		var channel_count := 2 if stream.stereo else 1
		var bytes_per_sample := 2 if stream.format == AudioStreamWAV.FORMAT_16_BITS else 1
		stream.loop_end = int(stream.data.size() / maxi(1, channel_count * bytes_per_sample))
	return stream


func _phone_music_path_for_floor(floor_number: int) -> String:
	var safe_floor := clampi(floor_number, 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	return str(PHONE_AMBIENCE_PATHS.get(safe_floor, PHONE_AMBIENCE_PATHS[1]))


func _ensure_phone_music_for_floor(floor_number: int) -> void:
	if _phone_ambience == null:
		return
	var safe_floor := clampi(floor_number, 1, MemeGameStateScript.MAX_TOWER_FLOOR)
	var target_path := _phone_music_path_for_floor(safe_floor)
	if str(_phone_ambience.get_meta("generated_audio_path", "")) == target_path:
		_phone_ambience.set_meta("phone_music_floor", safe_floor)
		return
	var phase := 0.0
	if _reality_ambience != null and _reality_ambience.playing:
		phase = _reality_ambience.get_playback_position()
	elif _phone_ambience.playing:
		phase = _phone_ambience.get_playback_position()
	var was_playing := _phone_ambience.playing
	_phone_ambience.stop()
	_phone_ambience.stream = _load_generated_wav(target_path, true)
	_phone_ambience.set_meta("generated_audio_path", target_path)
	_phone_ambience.set_meta("phone_music_floor", safe_floor)
	if is_inside_tree() and was_playing and _phone_ambience.stream != null:
		_phone_ambience.play(phase)


func _sync_audio_state(immediate: bool = false) -> void:
	if _phone_ambience == null or _reality_ambience == null or _pollution_ambience == null:
		return
	if not _game_started or game == null:
		for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
			player.set_meta("target_volume_db", -60.0)
		if is_inside_tree():
			for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
				player.stop()
			if _flashback_audio != null:
				_flashback_audio.stop()
			if _cover_watcher_stinger != null:
				_cover_watcher_stinger.stop()
		return
	_ensure_phone_music_for_floor(int(game.tower_floor))
	var in_phone: bool = game.view_state == "phone_down"
	var phone_target: float = -8.0 if in_phone else -42.0
	var intimate_typing: bool = _reality_interaction_active and game.conversation_phase == "typing"
	var reality_target: float = -26.0 if in_phone else (-7.0 if intimate_typing else -10.0)
	var pollution_target := _pollution_music_target(int(game.pollution))
	_phone_ambience.set_meta("target_volume_db", phone_target)
	_reality_ambience.set_meta("target_volume_db", reality_target)
	_pollution_ambience.set_meta("target_volume_db", pollution_target)
	for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
		player.set_meta("flashback_ducked", false)
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	_audio_tween = null
	if immediate:
		_phone_ambience.volume_db = phone_target
		_reality_ambience.volume_db = reality_target
		_pollution_ambience.volume_db = pollution_target
	if not is_inside_tree():
		return
	for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
		if not player.playing:
			player.play()
	if immediate:
		return
	_audio_tween = create_tween().set_parallel(true)
	_audio_tween.tween_property(_phone_ambience, "volume_db", phone_target, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_audio_tween.tween_property(_reality_ambience, "volume_db", reality_target, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_audio_tween.tween_property(_pollution_ambience, "volume_db", pollution_target, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _pollution_music_target(pollution_value: int) -> float:
	var pollution := clampi(pollution_value, 0, 100)
	if pollution <= 40:
		return -60.0
	if pollution <= 60:
		return remap(float(pollution), 41.0, 60.0, -42.0, -24.0)
	if pollution <= 80:
		return remap(float(pollution), 60.0, 80.0, -24.0, -10.0)
	return remap(float(pollution), 80.0, 100.0, -10.0, -3.0)


func _duck_ambience_for_flashback() -> void:
	if _audio_tween != null and _audio_tween.is_valid():
		_audio_tween.kill()
	_audio_tween = null
	for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
		if player != null:
			player.set_meta("flashback_ducked", true)
	if not is_inside_tree():
		for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
			if player != null:
				player.volume_db = -44.0
		return
	_audio_tween = create_tween().set_parallel(true)
	for player in [_phone_ambience, _reality_ambience, _pollution_ambience]:
		if player != null:
			# 分镜要求:底噪在冻结帧内先保持(约 0.28s),再于 100ms 内死掉,画面随后才切黑。
			_audio_tween.tween_property(player, "volume_db", -44.0, 0.10).set_delay(0.28).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)


func _build_main_menu() -> void:
	if _canvas == null:
		return
	for child in _canvas.get_children():
		child.queue_free()

	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_ui_font_theme(_ui_root)
	_canvas.add_child(_ui_root)

	_main_menu_layer = Control.new()
	_main_menu_layer.name = "MainMenuLayer"
	_main_menu_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui_root.add_child(_main_menu_layer)

	var bg := ColorRect.new()
	bg.name = "MainMenuGreenBackground"
	bg.color = Color("5DAE6B")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_menu_layer.add_child(bg)

	for index in 7:
		var stripe := ColorRect.new()
		stripe.name = "MainMenuPosterStripe%d" % index
		stripe.color = Color(_theme_color("surface"), 0.96 if index % 2 == 0 else 0.0)
		stripe.set_anchors_preset(Control.PRESET_TOP_LEFT)
		stripe.offset_left = 74 + index * 144
		stripe.offset_top = 322
		stripe.offset_right = stripe.offset_left + 122
		stripe.offset_bottom = 430
		_main_menu_layer.add_child(stripe)
		var cut := ColorRect.new()
		cut.name = "MainMenuBlackCut%d" % index
		cut.color = _theme_color("ink")
		cut.set_anchors_preset(Control.PRESET_TOP_LEFT)
		cut.offset_left = stripe.offset_left + 10
		cut.offset_top = 322 + (index % 3) * 18
		cut.offset_right = cut.offset_left + 118
		cut.offset_bottom = cut.offset_top + 22
		cut.rotation = deg_to_rad(-22 + index * 9)
		_main_menu_layer.add_child(cut)

	var title_stack := VBoxContainer.new()
	title_stack.name = "MainMenuTextStack"
	title_stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	title_stack.offset_left = 70
	title_stack.offset_top = 218
	title_stack.offset_right = 1040
	title_stack.offset_bottom = 560
	title_stack.add_theme_constant_override("separation", 18)
	_main_menu_layer.add_child(title_stack)

	var chapter := _label("Cartridge 3", 52, Color(_theme_color("surface"), 0.82))
	chapter.name = "MainMenuChapter"
	title_stack.add_child(chapter)

	var title := _label("HAJIMI", 94, _theme_color("surface"))
	title.name = "MainMenuTitle"
	title.add_theme_color_override("font_shadow_color", _theme_color("ink"))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 0)
	title_stack.add_child(title)

	var subtitle := _label("Die Grenzen meiner Sprache bedeuten die Grenzen meiner Welt.", 28, Color(_theme_color("surface"), 0.78))
	subtitle.name = "MainMenuSubtitle"
	title_stack.add_child(subtitle)

	var buttons := HBoxContainer.new()
	buttons.name = "MainMenuButtons"
	buttons.add_theme_constant_override("separation", 18)
	title_stack.add_child(buttons)

	var continue_button := Button.new()
	continue_button.name = "MainMenuContinueButton"
	continue_button.text = "继续游戏"
	continue_button.custom_minimum_size = Vector2(168, 54)
	continue_button.disabled = not _has_save_progress()
	continue_button.tooltip_text = "回到上次离开的位置" if not continue_button.disabled else "暂无自动存档"
	continue_button.pressed.connect(continue_game, CONNECT_DEFERRED)
	buttons.add_child(continue_button)

	var start_button := Button.new()
	start_button.name = "MainMenuStartButton"
	start_button.text = "新游戏"
	start_button.custom_minimum_size = Vector2(168, 54)
	start_button.pressed.connect(new_game, CONNECT_DEFERRED)
	buttons.add_child(start_button)

	var exit_button := Button.new()
	exit_button.name = "MainMenuExitButton"
	exit_button.text = "退出游戏"
	exit_button.set_meta("skip_localization", true)
	exit_button.custom_minimum_size = Vector2(168, 54)
	exit_button.pressed.connect(_request_quit_game)
	buttons.add_child(exit_button)

	var language_button := Button.new()
	language_button.name = "MainMenuLanguageButton"
	language_button.text = "语言"
	language_button.custom_minimum_size = Vector2(132, 54)
	language_button.pressed.connect(_build_language_selection_overlay.bind(false))
	buttons.add_child(language_button)

	var mark := Control.new()
	mark.name = "MainMenuCornerMark"
	mark.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	mark.offset_left = -150
	mark.offset_top = -126
	mark.offset_right = -56
	mark.offset_bottom = -36
	_main_menu_layer.add_child(mark)
	var mark_circle := ColorRect.new()
	mark_circle.color = _theme_color("surface")
	mark_circle.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark_circle.offset_left = 28
	mark_circle.offset_top = 0
	mark_circle.offset_right = 62
	mark_circle.offset_bottom = 34
	mark.add_child(mark_circle)
	var mark_stem := ColorRect.new()
	mark_stem.color = _theme_color("ink")
	mark_stem.set_anchors_preset(Control.PRESET_TOP_LEFT)
	mark_stem.offset_left = 46
	mark_stem.offset_top = 0
	mark_stem.offset_right = 62
	mark_stem.offset_bottom = 34
	mark.add_child(mark_stem)
	for index in 3:
		var base := ColorRect.new()
		base.color = _theme_color("surface")
		base.set_anchors_preset(Control.PRESET_TOP_LEFT)
		base.offset_left = 20 - index * 2
		base.offset_top = 54 + index * 10
		base.offset_right = 76 + index * 2
		base.offset_bottom = base.offset_top + 4
		mark.add_child(base)

	_apply_ui_theme()
	_refresh_localized_ui()
	_ensure_settings_history_panel()
	_settings_history_panel.build_exit_confirmation_overlay(_ui_root, _settings_history_mount_deps())


func _build_language_selection_overlay(first_run: bool = false) -> void:
	if _ui_root == null:
		return
	if _language_overlay != null and is_instance_valid(_language_overlay):
		_language_overlay.queue_free()
	_language_overlay_first_run = first_run
	_language_overlay = Control.new()
	_language_overlay.name = "LanguageSelectionOverlay"
	_language_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_language_overlay.z_index = 190
	_ui_root.add_child(_language_overlay)

	var blackout := ColorRect.new()
	blackout.name = "LanguageSelectionBackdrop"
	blackout.color = Color(_theme_color("ink"), 0.92)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_language_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_language_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "LanguageSelectionPanel"
	panel.custom_minimum_size = Vector2(620, 390)
	panel.add_theme_stylebox_override("panel", _soft_style(_theme_color("surface"), _theme_color("accent")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var eyebrow := Label.new()
	eyebrow.text = "BABEL PHONE  /  LANGUAGE"
	eyebrow.add_theme_font_size_override("font_size", _ui_font_size(15))
	eyebrow.add_theme_color_override("font_color", _theme_color("accent"))
	box.add_child(eyebrow)
	var title := Label.new()
	title.name = "LanguageSelectionTitle"
	title.text = "选择语言  /  言語を選択  /  CHOOSE LANGUAGE"
	title.add_theme_font_size_override("font_size", _ui_font_size(27))
	title.add_theme_color_override("font_color", _theme_color("ink"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(title)
	var rule := HSeparator.new()
	box.add_child(rule)

	var choices := VBoxContainer.new()
	choices.name = "LanguageSelectionChoices"
	choices.add_theme_constant_override("separation", 10)
	box.add_child(choices)
	for locale_code in GameLocaleScript.SUPPORTED_LOCALES:
		var choice := Button.new()
		choice.name = "LanguageChoice%s" % str(locale_code).to_upper()
		choice.text = _locale.native_language_name(str(locale_code))
		choice.custom_minimum_size = Vector2(500, 58)
		choice.set_meta("skip_localization", true)
		choice.pressed.connect(_on_language_selected.bind(str(locale_code)))
		choices.add_child(choice)

	if not first_run:
		var cancel := Button.new()
		cancel.name = "LanguageSelectionCancel"
		cancel.text = "返回"
		cancel.custom_minimum_size.y = 50
		cancel.pressed.connect(_close_language_selection_overlay)
		box.add_child(cancel)
	_refresh_localized_ui()


func _on_language_selected(locale_code: String) -> void:
	if not _locale.select_language(locale_code):
		return
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)
	_close_language_selection_overlay()
	# 换语言即换字池:清空造句台,避免旧语言的字混进新语言的句子。
	if game != null:
		game.free_sentence_clear()
	if _game_started:
		_render()
	else:
		_build_main_menu()
		if not _camera_session_decided:
			_build_camera_consent_overlay()
	_refresh_localized_ui()


func _close_language_selection_overlay() -> void:
	if _language_overlay_first_run and not _locale.language_selected:
		return
	if _language_overlay != null and is_instance_valid(_language_overlay):
		_language_overlay.queue_free()
	_language_overlay = null
	_language_overlay_first_run = false


func _build_camera_consent_overlay() -> void:
	if _ui_root == null or _camera_session_decided:
		return
	if _camera_consent_overlay != null and is_instance_valid(_camera_consent_overlay):
		_camera_consent_overlay.queue_free()
	_camera_consent_overlay = Control.new()
	_camera_consent_overlay.name = "CameraConsentOverlay"
	_camera_consent_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera_consent_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_camera_consent_overlay.z_index = 210
	_ui_root.add_child(_camera_consent_overlay)

	var blackout := ColorRect.new()
	blackout.name = "CameraConsentBackdrop"
	blackout.color = Color(_theme_color("ink"), 0.94)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	_camera_consent_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_camera_consent_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.name = "CameraConsentPanel"
	panel.custom_minimum_size = Vector2(720, 520)
	panel.add_theme_stylebox_override("panel", _soft_style(_theme_color("surface"), _theme_color("accent")))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)

	var eyebrow := _label("LOCAL VISION  /  FOUR FINGERTIPS", 15, _theme_color("accent"))
	eyebrow.name = "CameraConsentEyebrow"
	box.add_child(eyebrow)
	var title := _label("摄像头与 X-RAY", 30, _theme_color("ink"))
	title.name = "CameraConsentTitle"
	box.add_child(title)
	_camera_consent_copy = _label(
		"用双手拇指与食指的四个指尖框出矩形区域，区域内会显示手机层。视频只在本机用于关键点计算，不写入存档。",
		18,
		_theme_color("ink")
	)
	_camera_consent_copy.name = "CameraConsentPrivacyCopy"
	_camera_consent_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_camera_consent_copy.custom_minimum_size.y = 110
	box.add_child(_camera_consent_copy)
	var source_guidance := _label("默认使用电脑摄像头；手机只作为没有电脑镜头时的备用。", 15, _theme_color("accent"))
	source_guidance.name = "CameraConsentSourceGuidance"
	box.add_child(source_guidance)
	var source_label := _label("摄像头来源", 16, _theme_color("ink"))
	box.add_child(source_label)
	_camera_consent_source_option = OptionButton.new()
	_camera_consent_source_option.name = "CameraConsentSourceOption"
	_camera_consent_source_option.set_meta("skip_localization", true)
	_camera_consent_source_option.custom_minimum_size = Vector2(440, 52)
	_populate_camera_source_option(_camera_consent_source_option)
	_camera_consent_source_option.item_selected.connect(_on_camera_source_selected.bind(_camera_consent_source_option))
	box.add_child(_camera_consent_source_option)
	var previous_choice := _label(
		"上次设置为允许；本次仍需要你确认。" if _camera_enabled else "镜头默认关闭，点击允许后才会启动。",
		15,
		_theme_color("accent")
	)
	previous_choice.name = "CameraConsentPreviousChoice"
	box.add_child(previous_choice)

	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 14)
	box.add_child(actions)
	var allow_button := Button.new()
	allow_button.name = "CameraConsentAllowButton"
	allow_button.text = "允许并打开摄像头"
	allow_button.custom_minimum_size = Vector2(260, 58)
	allow_button.pressed.connect(_resolve_camera_consent.bind(true))
	actions.add_child(allow_button)
	var skip_button := Button.new()
	skip_button.name = "CameraConsentSkipButton"
	skip_button.text = "暂不使用"
	skip_button.custom_minimum_size = Vector2(190, 58)
	skip_button.pressed.connect(_resolve_camera_consent.bind(false))
	actions.add_child(skip_button)
	_apply_ui_theme()
	_refresh_localized_ui()


func _resolve_camera_consent(allowed: bool) -> void:
	_camera_session_decided = true
	_set_camera_enabled(allowed, true)
	if _camera_consent_overlay != null and is_instance_valid(_camera_consent_overlay):
		_camera_consent_overlay.queue_free()
	_camera_consent_overlay = null


func _ensure_hand_tracking_receiver() -> void:
	if _hand_tracking_receiver != null:
		return
	_hand_tracking_receiver = HandTrackingReceiverScript.new()
	_hand_tracking_receiver.camera_source = _camera_source
	_hand_tracking_receiver.frame_received.connect(_on_hand_tracking_frame)
	_hand_tracking_receiver.status_changed.connect(_on_hand_tracking_status_changed)
	_hand_tracking_receiver.source_ready.connect(_on_camera_source_ready)


func _set_camera_enabled(value: bool, persist: bool = true) -> void:
	_camera_enabled = value
	_camera_ready_source = ""
	_camera_ready_index = -1
	_ensure_hand_tracking_receiver()
	_hand_tracking_receiver.camera_source = _camera_source
	if value:
		_hand_tracking_receiver.start(true)
		_camera_tracking_status = _hand_tracking_receiver.get_status()
	else:
		_hand_tracking_receiver.stop()
		_camera_tracking_status = "摄像头未启用"
	if _camera_access_toggle != null:
		_camera_access_toggle.set_pressed_no_signal(value)
	if _hand_xray_overlay != null:
		_hand_xray_overlay.set_tracking_enabled(value)
	_refresh_camera_source_buttons()
	_refresh_camera_status_ui()
	if value and _camera_source == "phone":
		_show_phone_camera_connection_overlay()
	elif not value:
		_hide_phone_camera_connection_overlay()
	_refresh_phone_camera_connection_ui()
	if persist:
		_locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)


func _set_camera_source(value: String, persist: bool = true) -> void:
	var normalized := value if value in ["computer", "phone"] else "computer"
	var changed := _camera_source != normalized
	_camera_source = normalized
	if changed:
		_camera_ready_source = ""
		_camera_ready_index = -1
	_ensure_hand_tracking_receiver()
	_hand_tracking_receiver.camera_source = _camera_source
	if changed and _camera_enabled:
		_hand_tracking_receiver.stop()
		_hand_tracking_receiver.start(true)
		_camera_tracking_status = _hand_tracking_receiver.get_status()
	_sync_camera_source_options()
	_refresh_camera_source_buttons()
	_refresh_camera_status_ui()
	if _camera_source == "computer":
		_hide_phone_camera_connection_overlay()
	elif _camera_enabled:
		_show_phone_camera_connection_overlay()
	_refresh_phone_camera_connection_ui()
	if persist:
		_locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)


func _populate_camera_source_option(option: OptionButton) -> void:
	if option == null:
		return
	option.clear()
	for entry in [
		{"id": "computer", "label": "电脑摄像头（默认）"},
		{"id": "phone", "label": "手机摄像头（备用）"},
	]:
		option.add_item(_locale.translate(str(entry["label"])))
		var item_index := option.item_count - 1
		option.set_item_metadata(item_index, entry["id"])
		if str(entry["id"]) == _camera_source:
			option.select(item_index)


func _sync_camera_source_options() -> void:
	for option in [_camera_consent_source_option]:
		if option == null:
			continue
		for item_index in option.item_count:
			if str(option.get_item_metadata(item_index)) == _camera_source:
				option.select(item_index)
				break


func _refresh_camera_source_option_labels() -> void:
	for option in [_camera_consent_source_option]:
		if option == null or option.item_count < 2:
			continue
		option.set_item_text(0, _locale.translate("电脑摄像头（默认）"))
		option.set_item_text(1, _locale.translate("手机摄像头（备用）"))


func _on_camera_source_selected(index: int, option: OptionButton) -> void:
	if option == null or index < 0 or index >= option.item_count:
		return
	_set_camera_source(str(option.get_item_metadata(index)), true)


func _activate_camera_source(source: String) -> void:
	var normalized := source if source in ["computer", "phone"] else "computer"
	_camera_session_decided = true
	if _camera_enabled:
		_set_camera_enabled(false, false)
	_set_camera_source(normalized, false)
	_set_camera_enabled(true, true)
	if normalized == "phone":
		_show_phone_camera_connection_overlay()
	else:
		_hide_phone_camera_connection_overlay()


func _refresh_camera_source_buttons() -> void:
	if _camera_computer_button != null:
		_camera_computer_button.set_pressed_no_signal(_camera_enabled and _camera_source == "computer")
		_camera_computer_button.set_meta("camera_source_selected", _camera_enabled and _camera_source == "computer")
		_camera_computer_button.set_meta("camera_source_ready", _camera_ready_source == "computer")
	if _camera_phone_button != null:
		_camera_phone_button.set_pressed_no_signal(_camera_enabled and _camera_source == "phone")
		_camera_phone_button.set_meta("camera_source_selected", _camera_enabled and _camera_source == "phone")
		_camera_phone_button.set_meta("camera_source_ready", _camera_ready_source == "phone")


func _on_hand_tracking_frame(hands: Array, _timestamp_msec: int) -> void:
	var frame_locked := false
	if _hand_xray_overlay != null:
		frame_locked = _hand_xray_overlay.ingest_hands(hands, Time.get_ticks_msec())
	var receiver_status: String = str(_hand_tracking_receiver.get_status()) if _hand_tracking_receiver != null else ""
	if frame_locked:
		_camera_tracking_status = "已锁定指尖窗口"
	elif receiver_status in ["摄像头不可用或权限被拒绝", "手部追踪程序发生错误"]:
		_camera_tracking_status = receiver_status
	else:
		_camera_tracking_status = "等待双手四指框选"
	_refresh_camera_status_ui()


func _on_hand_tracking_status_changed(status: String) -> void:
	_camera_tracking_status = status
	if status in ["摄像头不可用或权限被拒绝", "手部追踪程序发生错误", "无法启动手部追踪程序"]:
		_camera_ready_source = ""
		_camera_ready_index = -1
	_refresh_camera_source_buttons()
	_refresh_camera_status_ui()
	_refresh_phone_camera_connection_ui()


func _on_camera_source_ready(source: String, selected_index: int) -> void:
	if source not in ["computer", "phone"]:
		return
	_camera_ready_source = source
	_camera_ready_index = selected_index
	_refresh_camera_source_buttons()
	_refresh_phone_camera_connection_ui()


func _refresh_camera_status_ui() -> void:
	if _camera_status_label != null:
		_camera_status_label.text = _camera_tracking_status
		_set_localized_property(_camera_status_label, "text")


func _build_ui() -> void:
	if _canvas == null:
		return
	for child in _canvas.get_children():
		child.queue_free()

	_ui_root = Control.new()
	_ui_root.name = "UIRoot"
	_ui_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_ui_font_theme(_ui_root)
	_canvas.add_child(_ui_root)

	var vignette := ColorRect.new()
	vignette.color = _theme_color("ink").darkened(0.15)
	vignette.modulate.a = 0.16
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.z_index = 2
	_ui_root.add_child(vignette)

	_build_vhs_overlay()

	_phone_down_backdrop_image = TextureRect.new()
	_phone_down_backdrop_image.name = "PhoneDownBackdropImage"
	_phone_down_backdrop_image.texture = _load_runtime_texture(PHONE_DOWN_BACKDROP_PATH)
	_phone_down_backdrop_image.set_meta("asset_path", PHONE_DOWN_BACKDROP_PATH)
	_phone_down_backdrop_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_phone_down_backdrop_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_phone_down_backdrop_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phone_down_backdrop_image.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_down_backdrop_image.set_meta("walking_bob_amplitude", 2.4)
	_phone_down_backdrop_image.z_index = 1
	_ui_root.add_child(_phone_down_backdrop_image)
	_hand_phone_image = null
	_build_hand_xray_overlay()
	_build_cinematic_bars()

	_build_apple_hud()

	_world_prompt = _label("", 18, _theme_color("surface"))
	_world_prompt.name = "WorldPrompt"
	_world_prompt.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_world_prompt.offset_left = 520
	_world_prompt.offset_top = -162
	_world_prompt.offset_right = -520
	_world_prompt.offset_bottom = -108
	_world_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_world_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_world_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_world_prompt.set_meta("on_dark", true)
	_world_prompt.add_theme_color_override("font_outline_color", Color("050705"))
	_world_prompt.add_theme_constant_override("outline_size", 6)
	_world_prompt.z_index = 10
	_ui_root.add_child(_world_prompt)

	_phone_panel = _panel()
	_phone_panel.name = "PhonePopup"
	_phone_panel.set_meta("phone_shell", true)
	_phone_panel.clip_contents = true
	_phone_panel.z_index = 20
	_ui_root.add_child(_phone_panel)
	_apply_phone_popup_layout(true)

	var phone_shell := VBoxContainer.new()
	phone_shell.name = "PhoneShell"
	phone_shell.add_theme_constant_override("separation", 0)
	_phone_panel.add_child(phone_shell)

	_phone_tab = null

	_phone_content = VBoxContainer.new()
	_phone_content.name = "PhoneContent"
	_phone_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	(_phone_content as VBoxContainer).add_theme_constant_override("separation", 8)
	phone_shell.add_child(_phone_content)

	var phone_header := HBoxContainer.new()
	phone_header.name = "PhoneWindowHeader"
	phone_header.custom_minimum_size.y = 60
	phone_header.mouse_filter = Control.MOUSE_FILTER_STOP
	phone_header.add_theme_constant_override("separation", 8)
	_phone_content.add_child(phone_header)

	_phone_title = _label("BABEL / PHONE", 18, _theme_color("accent"))
	_phone_title.name = "PhoneWindowHandle"
	_phone_title.set_meta("on_dark", true)
	_phone_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_phone_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	phone_header.add_child(_phone_title)
	var phone_signal_icon := TextureRect.new()
	phone_signal_icon.name = "PhoneHomeNoSignalIcon"
	phone_signal_icon.texture = _load_runtime_texture(NO_SIGNAL_ICON_PATH)
	phone_signal_icon.custom_minimum_size = Vector2(22, 22)
	phone_signal_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	phone_signal_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	phone_signal_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_header.add_child(phone_signal_icon)
	var phone_signal := _label("无信号", 13, _theme_color("accent"))
	phone_signal.set_meta("on_dark", true)
	phone_signal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_header.add_child(phone_signal)
	var phone_close := Button.new()
	phone_close.name = "PhoneHomeCloseButton"
	phone_close.text = "X"
	phone_close.set_meta("dark_window_close_button", true)
	phone_close.custom_minimum_size = Vector2(56, 56)
	phone_close.pressed.connect(set_view_state.bind("npc_up"))
	phone_header.add_child(phone_close)
	_make_draggable_window(_phone_panel, "phone", phone_header)
	_make_draggable_window(_phone_panel, "phone", _phone_title)

	var phone_screen := _panel()
	phone_screen.name = "PhoneScreenPanel"
	phone_screen.set_meta("phone_surface", true)
	phone_screen.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_phone_content.add_child(phone_screen)
	var launcher_wallpaper := TextureRect.new()
	launcher_wallpaper.name = "PhoneLauncherWallpaper"
	launcher_wallpaper.texture = _load_runtime_texture(PHONE_LAUNCHER_WALLPAPER_PATH)
	launcher_wallpaper.set_meta("asset_path", PHONE_LAUNCHER_WALLPAPER_PATH)
	launcher_wallpaper.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	launcher_wallpaper.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	launcher_wallpaper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	launcher_wallpaper.modulate = Color(1.0, 1.0, 1.0, 0.78)
	phone_screen.add_child(launcher_wallpaper)
	var launcher_tint := ColorRect.new()
	launcher_tint.name = "PhoneLauncherTint"
	launcher_tint.color = Color(_theme_color("ink"), 0.42)
	launcher_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_screen.add_child(launcher_tint)
	var screen_box := VBoxContainer.new()
	screen_box.name = "PhoneLauncherScreen"
	screen_box.add_theme_constant_override("separation", 14)
	phone_screen.add_child(screen_box)
	var launcher_eyebrow := _label("NO SIGNAL  /  APP LAUNCHER", 12, _theme_color("muted"))
	launcher_eyebrow.name = "PhoneLauncherEyebrow"
	launcher_eyebrow.set_meta("on_dark", true)
	screen_box.add_child(launcher_eyebrow)
	var launcher_title := _label("选择一个窗口", 25, _theme_color("surface"))
	launcher_title.name = "PhoneLauncherTitle"
	launcher_title.set_meta("on_dark", true)
	screen_box.add_child(launcher_title)
	var launcher_rule := ColorRect.new()
	launcher_rule.name = "PhoneLauncherRule"
	launcher_rule.color = _theme_color("muted")
	launcher_rule.custom_minimum_size.y = 4
	screen_box.add_child(launcher_rule)
	var app_grid := GridContainer.new()
	app_grid.name = "PhoneAppGrid"
	app_grid.columns = 2
	app_grid.add_theme_constant_override("h_separation", 10)
	app_grid.add_theme_constant_override("v_separation", 10)
	screen_box.add_child(app_grid)
	for app in [
		{"id": "babel", "label": "塔\n楼层档案"},
		{"id": "social", "label": "帖\n信号瀑布"},
		{"id": "notebook", "label": "本\n语言工坊"},
	]:
		var button := Button.new()
		button.name = "PhoneAppIcon%s" % str(app["id"]).capitalize()
		button.text = app["label"]
		button.set_meta("phone_app_icon", true)
		button.custom_minimum_size = Vector2(156, 126)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_app_pressed.bind(app["id"]))
		app_grid.add_child(button)
	var launcher_note := _label("每个 App 会在手机旁打开独立窗口。", 13, _theme_color("surface"))
	launcher_note.name = "PhoneLauncherNote"
	launcher_note.set_meta("on_dark", true)
	launcher_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	screen_box.add_child(launcher_note)
	var launcher_spacer := Control.new()
	launcher_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen_box.add_child(launcher_spacer)
	var launcher_indicator_wrap := CenterContainer.new()
	launcher_indicator_wrap.name = "PhoneLauncherIndicatorWrap"
	launcher_indicator_wrap.custom_minimum_size.y = 14
	screen_box.add_child(launcher_indicator_wrap)
	var launcher_indicator := ColorRect.new()
	launcher_indicator.name = "PhoneLauncherIndicator"
	launcher_indicator.color = _theme_color("ink")
	launcher_indicator.custom_minimum_size = Vector2(88, 4)
	launcher_indicator_wrap.add_child(launcher_indicator)

	_view_toggle_button = Button.new()
	_view_toggle_button.name = "PhoneViewToggleButton"
	_view_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_view_toggle_button.offset_left = 470
	_view_toggle_button.offset_top = -92
	_view_toggle_button.offset_right = 596
	_view_toggle_button.offset_bottom = -36
	_view_toggle_button.custom_minimum_size = Vector2(126, 56)
	_view_toggle_button.z_index = 42
	_view_toggle_button.pressed.connect(_toggle_view_state)
	_ui_root.add_child(_view_toggle_button)

	_ensure_social_feed_panel()
	_social_feed_panel.mount(_ui_root, _social_feed_mount_deps())
	_app_windows["social"] = _social_feed_panel.get_app_window()
	_app_titles["social"] = _social_feed_panel.get_app_title() as Label
	_app_bodies["social"] = _social_feed_panel.get_app_body() as VBoxContainer
	_build_app_window("babel", "巴别塔 App", "BabelAppWindow", -1032.0, 96.0, -592.0, 676.0)
	_build_app_window("notebook", "笔记本 App", "NotebookAppWindow", -968.0, 152.0, -528.0, 732.0)

	_reality_intent_preview = RicherTextLabelScript.new()
	_install_rich_text_effect(_reality_intent_preview, "curspull")
	_reality_intent_preview.name = "RealityIntentPreview"
	_reality_intent_preview.bbcode_enabled = true
	_reality_intent_preview.fit_content = false
	_reality_intent_preview.scroll_active = false
	_reality_intent_preview.set_meta("on_dark", true)
	_reality_intent_preview.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reality_intent_preview.offset_left = 310
	_reality_intent_preview.offset_top = -360
	_reality_intent_preview.offset_right = -250
	_reality_intent_preview.offset_bottom = -286
	_reality_intent_preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reality_intent_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reality_intent_preview.add_theme_font_size_override("normal_font_size", _ui_font_size(28))
	_reality_intent_preview.add_theme_color_override("default_color", _theme_color("surface"))
	_reality_intent_preview.add_theme_color_override("font_outline_color", Color("050705"))
	_reality_intent_preview.add_theme_constant_override("outline_size", 8)
	_reality_intent_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reality_intent_preview.z_index = 14
	_ui_root.add_child(_reality_intent_preview)

	_reality_choice_row = HBoxContainer.new()
	_reality_choice_row.name = "RealityResponseChoices"
	_reality_choice_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reality_choice_row.offset_left = 350
	_reality_choice_row.offset_top = -270
	_reality_choice_row.offset_right = -290
	_reality_choice_row.offset_bottom = -206
	_reality_choice_row.add_theme_constant_override("separation", 14)
	_reality_choice_row.clip_contents = true
	_reality_choice_row.z_index = 15
	_ui_root.add_child(_reality_choice_row)

	_reality_typing_line = RicherTextLabelScript.new()
	_install_rich_text_effect(_reality_typing_line, "curspull")
	_install_rich_text_effect(_reality_typing_line, "cuss")
	_reality_typing_line.name = "RealityTypingLine"
	_reality_typing_line.bbcode_enabled = true
	_reality_typing_line.fit_content = false
	_reality_typing_line.scroll_active = false
	_reality_typing_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reality_typing_line.offset_left = 280
	_reality_typing_line.offset_top = -300
	_reality_typing_line.offset_right = -220
	_reality_typing_line.offset_bottom = -206
	_reality_typing_line.add_theme_font_size_override("normal_font_size", _ui_font_size(30))
	_reality_typing_line.add_theme_color_override("default_color", _theme_color("surface"))
	_reality_typing_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reality_typing_line.z_index = 15
	_ui_root.add_child(_reality_typing_line)

	_reality_typing_progress = _label("", 14, _theme_color("muted"))
	_reality_typing_progress.name = "RealityTypingProgress"
	_reality_typing_progress.set_meta("on_dark", true)
	_reality_typing_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reality_typing_progress.offset_left = 520
	_reality_typing_progress.offset_top = -210
	_reality_typing_progress.offset_right = -460
	_reality_typing_progress.offset_bottom = -184
	_reality_typing_progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reality_typing_progress.z_index = 15
	_ui_root.add_child(_reality_typing_progress)

	_reality_subtitle_panel = PanelContainer.new()
	_reality_subtitle_panel.name = "RealitySubtitlePanel"
	_reality_subtitle_panel.set_meta("movie_subtitle", true)
	_reality_subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reality_subtitle_panel.offset_left = 360
	_reality_subtitle_panel.offset_top = -178
	_reality_subtitle_panel.offset_right = -300
	_reality_subtitle_panel.offset_bottom = -104
	_reality_subtitle_panel.z_index = 14
	_ui_root.add_child(_reality_subtitle_panel)
	var subtitle_box := HBoxContainer.new()
	subtitle_box.add_theme_constant_override("separation", 12)
	_reality_subtitle_panel.add_child(subtitle_box)
	_reality_subtitle_label = RicherTextLabelScript.new()
	_install_rich_text_effect(_reality_subtitle_label, "curspull")
	_reality_subtitle_label.name = "RealitySubtitleLabel"
	_reality_subtitle_label.bbcode_enabled = true
	_reality_subtitle_label.fit_content = false
	_reality_subtitle_label.scroll_active = false
	_reality_subtitle_label.set_meta("on_dark", true)
	_reality_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reality_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reality_subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reality_subtitle_label.add_theme_font_size_override("normal_font_size", _ui_font_size(20))
	_reality_subtitle_label.add_theme_color_override("default_color", _theme_color("surface"))
	_reality_subtitle_label.add_theme_color_override("font_outline_color", Color("050705"))
	_reality_subtitle_label.add_theme_constant_override("outline_size", 6)
	subtitle_box.add_child(_reality_subtitle_label)
	_reality_continue_button = Button.new()
	_reality_continue_button.name = "RealityConversationContinue"
	_reality_continue_button.text = "结束"
	_reality_continue_button.custom_minimum_size = Vector2(92, 48)
	_reality_continue_button.pressed.connect(_on_reality_continue_pressed)
	subtitle_box.add_child(_reality_continue_button)
	_build_reality_language_composer()

	_meme_bank_window = Control.new()
	_meme_bank_window.name = "MemeBankPopup"
	_meme_bank_window.set_meta("meme_bank_popup", true)
	_meme_bank_window.set_meta("radial_meme_bank", true)
	_meme_bank_window.mouse_filter = Control.MOUSE_FILTER_PASS
	_meme_bank_window.z_index = 18
	_ui_root.add_child(_meme_bank_window)
	_apply_meme_bank_popup_layout("peek")

	_meme_bank_ring = RadialSelectorRingScript.new()
	_meme_bank_ring.name = "MemeBankRadialRing"
	_meme_bank_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meme_bank_ring.set_palette(_theme_color("surface"), Color(_theme_color("muted"), 0.88), _theme_color("accent"))
	_meme_bank_ring.selection_changed.connect(_on_meme_ring_selection_changed)
	_meme_bank_window.add_child(_meme_bank_ring)
	_bank_list = _meme_bank_ring

	_meme_bank_tab = Button.new()
	_meme_bank_tab.name = "MemeBankTab"
	_meme_bank_tab.text = "梗"
	_meme_bank_tab.set_meta("meme_bank_tab", true)
	_meme_bank_tab.set_meta("radial_center_button", true)
	_meme_bank_tab.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	_meme_bank_tab.offset_left = -142.0
	_meme_bank_tab.offset_top = -58.0
	_meme_bank_tab.offset_right = -22.0
	_meme_bank_tab.offset_bottom = 58.0
	_meme_bank_tab.custom_minimum_size = Vector2(120, 116)
	_meme_bank_tab.pressed.connect(_toggle_meme_bank)
	_meme_bank_window.add_child(_meme_bank_tab)

	_meme_bank_drag_handle = _label("≡", 24, _theme_color("accent"))
	_meme_bank_drag_handle.name = "MemeBankDragHandle"
	_meme_bank_drag_handle.tooltip_text = "拖动梗仓库"
	_meme_bank_drag_handle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meme_bank_drag_handle.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meme_bank_drag_handle.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_meme_bank_drag_handle.offset_left = -70.0
	_meme_bank_drag_handle.offset_top = 14.0
	_meme_bank_drag_handle.offset_right = -26.0
	_meme_bank_drag_handle.offset_bottom = 58.0
	_meme_bank_drag_handle.custom_minimum_size = Vector2(44, 44)
	_meme_bank_window.add_child(_meme_bank_drag_handle)
	_make_draggable_window(_meme_bank_window, "bank", _meme_bank_drag_handle)

	_meme_bank_content = Control.new()
	_meme_bank_content.name = "MemeBankContent"
	_meme_bank_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meme_bank_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	_meme_bank_window.add_child(_meme_bank_content)
	_meme_bank_focus_label = _label("还没有完整梗", 16, _theme_color("accent"))
	_meme_bank_focus_label.name = "MemeBankFocusLabel"
	_meme_bank_focus_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_meme_bank_focus_label.offset_left = 24.0
	_meme_bank_focus_label.offset_top = -92.0
	_meme_bank_focus_label.offset_right = 286.0
	_meme_bank_focus_label.offset_bottom = -26.0
	_meme_bank_focus_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_meme_bank_focus_label.max_lines_visible = 1
	_meme_bank_focus_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_meme_bank_focus_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_meme_bank_content.add_child(_meme_bank_focus_label)

	_desk_log = _label("", 16, _theme_color("accent"))
	_desk_log.name = "DeskLog"
	_desk_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_desk_log.offset_left = 282
	_desk_log.offset_top = -146
	_desk_log.offset_right = 820
	_desk_log.offset_bottom = -112
	_desk_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ui_root.add_child(_desk_log)
	_build_playtest_assist_panel()

	_build_action_spend_overlay()
	_build_settings_window()
	_build_phone_camera_connection_overlay()
	_build_history_window()
	_build_day_transition_overlay()
	_build_pickup_flight_layer()
	_build_doll_guide_overlay()
	_build_flashback_overlay()
	_build_prologue_overlay()
	_apply_responsive_layouts_if_needed(true)


func _build_reality_language_composer() -> void:
	_reality_language_frame = _panel()
	_reality_language_frame.name = "RealityLanguagePuzzleFrame"
	_reality_language_frame.set_meta("soft_panel", true)
	_reality_language_frame.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_reality_language_frame.offset_left = 300.0
	_reality_language_frame.offset_top = -520.0
	_reality_language_frame.offset_right = -240.0
	_reality_language_frame.offset_bottom = -190.0
	_reality_language_frame.z_index = 16
	_reality_language_frame.visible = false
	_ui_root.add_child(_reality_language_frame)

	var composer_box := VBoxContainer.new()
	composer_box.name = "RealityLanguagePuzzleContent"
	composer_box.add_theme_constant_override("separation", 10)
	_reality_language_frame.add_child(composer_box)

	var heading := _label("把发布过的词重新说给医生", 20, _theme_color("ink"))
	heading.name = "RealityLanguagePuzzleHeading"
	composer_box.add_child(heading)
	var hint := _label("同一个词到了这里会换一种说法。拖拽词块，或先点词块再点句槽。", 14, _theme_color("accent"))
	hint.name = "RealityLanguagePuzzleHint"
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	composer_box.add_child(hint)

	_reality_language_token_flow = HFlowContainer.new()
	_reality_language_token_flow.name = "RealityLanguageTokenFlow"
	_reality_language_token_flow.custom_minimum_size.y = 76.0
	_reality_language_token_flow.add_theme_constant_override("h_separation", 8)
	_reality_language_token_flow.add_theme_constant_override("v_separation", 8)
	composer_box.add_child(_reality_language_token_flow)

	_reality_language_slot_row = HBoxContainer.new()
	_reality_language_slot_row.name = "RealityLanguageSlots"
	_reality_language_slot_row.add_theme_constant_override("separation", 8)
	composer_box.add_child(_reality_language_slot_row)

	_reality_language_preview = _label("", 16, _theme_color("ink"))
	_reality_language_preview.name = "RealityLanguagePreview"
	_reality_language_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	composer_box.add_child(_reality_language_preview)

	_reality_language_confirm = Button.new()
	_reality_language_confirm.name = "RealityLanguageConfirm"
	_reality_language_confirm.text = "对医生说出口"
	_reality_language_confirm.custom_minimum_size.y = 54.0
	_reality_language_confirm.pressed.connect(_on_confirm_doctor_sentence_pressed)
	composer_box.add_child(_reality_language_confirm)


func _build_playtest_assist_panel() -> void:
	_playtest_assist_panel = _panel()
	_playtest_assist_panel.name = "PlaytestAssistPanel"
	_playtest_assist_panel.set_meta("dark_rail", true)
	_playtest_assist_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_playtest_assist_panel.offset_left = -474.0
	_playtest_assist_panel.offset_top = 24.0
	_playtest_assist_panel.offset_right = -24.0
	_playtest_assist_panel.offset_bottom = 178.0
	_playtest_assist_panel.z_index = 44
	_playtest_assist_panel.visible = true
	_ui_root.add_child(_playtest_assist_panel)
	var assist_box := VBoxContainer.new()
	assist_box.add_theme_constant_override("separation", 6)
	_playtest_assist_panel.add_child(assist_box)
	var title := _label("缝线布偶 / GUIDE", 13, _theme_color("muted"))
	title.set_meta("on_dark", true)
	assist_box.add_child(title)
	_playtest_assist_label = _label("", 15, _theme_color("surface"))
	_playtest_assist_label.name = "PlaytestAssistLabel"
	_playtest_assist_label.set_meta("on_dark", true)
	_playtest_assist_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_playtest_assist_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	assist_box.add_child(_playtest_assist_label)


func _build_hand_xray_overlay() -> void:
	_hand_xray_overlay = HandXRayOverlayScript.new()
	_hand_xray_overlay.name = "HandXRayOverlay"
	_hand_xray_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hand_xray_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_xray_overlay.z_index = 9
	_ui_root.add_child(_hand_xray_overlay)
	var initial_texture: Texture2D = _second_layer_texture
	if initial_texture == null and _phone_down_backdrop_image != null:
		initial_texture = _phone_down_backdrop_image.texture
	_hand_xray_overlay.set_layer_texture(initial_texture)
	_hand_xray_overlay.set_tracking_enabled(_camera_enabled)


func _build_prologue_overlay() -> void:
	_prologue_overlay = Control.new()
	_prologue_overlay.name = "PrologueOverlay"
	_prologue_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_prologue_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_prologue_overlay.z_index = 80
	_ui_root.add_child(_prologue_overlay)

	var black := ColorRect.new()
	black.name = "PrologueBlack"
	black.color = Color("060806")
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_STOP
	_prologue_overlay.add_child(black)

	var signal_rule := ColorRect.new()
	signal_rule.name = "PrologueSignalRule"
	signal_rule.color = _theme_color("flash_text")
	signal_rule.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	signal_rule.offset_left = 78
	signal_rule.offset_right = 90
	_prologue_overlay.add_child(signal_rule)

	var copy_column := VBoxContainer.new()
	copy_column.name = "PrologueCopyColumn"
	copy_column.set_anchors_preset(Control.PRESET_CENTER)
	copy_column.offset_left = -540
	copy_column.offset_top = -210
	copy_column.offset_right = 540
	copy_column.offset_bottom = 230
	copy_column.add_theme_constant_override("separation", 22)
	_prologue_overlay.add_child(copy_column)

	var signal_header := _label("NO SIGNAL  /  DAY 01  /  PRIVATE FREQUENCY", 15, _theme_color("flash_text"))
	signal_header.name = "PrologueSignalHeader"
	signal_header.set_meta("on_dark", true)
	copy_column.add_child(signal_header)

	_prologue_counter_label = _label("", 14, _theme_color("muted"))
	_prologue_counter_label.name = "PrologueCounter"
	_prologue_counter_label.set_meta("on_dark", true)
	copy_column.add_child(_prologue_counter_label)

	_prologue_line_label = _label("", 34, _theme_color("surface"))
	_prologue_line_label.name = "PrologueLine"
	_prologue_line_label.custom_minimum_size.y = 190
	_prologue_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_prologue_line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prologue_line_label.set_meta("on_dark", true)
	copy_column.add_child(_prologue_line_label)

	_prologue_continue_button = Button.new()
	_prologue_continue_button.name = "PrologueContinueButton"
	_prologue_continue_button.custom_minimum_size = Vector2(190, 56)
	_prologue_continue_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	_prologue_continue_button.pressed.connect(_advance_prologue)
	copy_column.add_child(_prologue_continue_button)
	_render_prologue_line()


func _render_prologue_line() -> void:
	if _prologue_line_label == null or MemeGameStateScript.PROLOGUE_LINES.is_empty():
		return
	_prologue_index = clampi(_prologue_index, 0, MemeGameStateScript.PROLOGUE_LINES.size() - 1)
	_prologue_line_label.text = str(MemeGameStateScript.PROLOGUE_LINES[_prologue_index])
	_prologue_counter_label.text = "TRANSMISSION %02d / %02d" % [_prologue_index + 1, MemeGameStateScript.PROLOGUE_LINES.size()]
	_prologue_continue_button.text = "进入第一天" if _prologue_index == MemeGameStateScript.PROLOGUE_LINES.size() - 1 else "继续"


func _advance_prologue() -> void:
	if _prologue_overlay == null or not _prologue_overlay.visible:
		return
	if _prologue_index < MemeGameStateScript.PROLOGUE_LINES.size() - 1:
		_prologue_index += 1
		_render_prologue_line()
		return
	_prologue_overlay.visible = false
	_sync_audio_state(false)


func _skip_prologue() -> void:
	if _prologue_overlay == null:
		return
	_prologue_index = MemeGameStateScript.PROLOGUE_LINES.size() - 1
	_prologue_overlay.visible = false
	_sync_audio_state(false)


func _build_apple_hud() -> void:
	_hud_panel = _panel()
	_hud_panel.name = "InternationalHUDRail"
	_hud_panel.set_meta("dark_rail", true)
	_hud_panel.set_meta("drawer_state", "collapsed")
	_hud_panel.set_meta("slide_direction", "left_to_right")
	_hud_panel.set_meta("open_duration", HUD_DRAWER_OPEN_DURATION)
	_hud_panel.set_meta("close_duration", HUD_DRAWER_CLOSE_DURATION)
	_hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_panel.offset_left = 0.0
	_hud_panel.offset_top = 0.0
	_hud_panel.offset_right = HUD_RAIL_WIDTH
	_hud_panel.offset_bottom = HUD_RAIL_MAX_HEIGHT
	_hud_panel.z_index = 40
	_hud_panel.clip_contents = true
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_panel.add_theme_stylebox_override("panel", _style(_theme_color("ink"), Color(_theme_color("muted"), 0.22)))
	_ui_root.add_child(_hud_panel)

	_hud_reveal_zone = Control.new()
	_hud_reveal_zone.name = "HUDRevealZone"
	_hud_reveal_zone.set_meta("hover_reveals", true)
	_hud_reveal_zone.set_meta("touch_reveals", true)
	_hud_reveal_zone.set_meta("touch_target_width", HUD_DRAWER_EDGE_HIT_WIDTH)
	_hud_reveal_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_hud_reveal_zone.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_hud_reveal_zone.tooltip_text = "打开状态栏"
	_hud_reveal_zone.z_index = 39
	_ui_root.add_child(_hud_reveal_zone)

	_hud_reveal_indicator = ColorRect.new()
	_hud_reveal_indicator.name = "HUDRevealIndicator"
	_hud_reveal_indicator.color = _theme_color("muted")
	_hud_reveal_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_reveal_indicator.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_hud_reveal_indicator.offset_left = 0.0
	_hud_reveal_indicator.offset_top = -46.0
	_hud_reveal_indicator.offset_right = HUD_DRAWER_EDGE_CUE_WIDTH
	_hud_reveal_indicator.offset_bottom = 46.0
	_hud_reveal_indicator.set_meta("edge_cue", true)
	_hud_reveal_zone.add_child(_hud_reveal_indicator)

	var center := CenterContainer.new()
	center.name = "InternationalHUDCenter"
	_hud_panel.add_child(center)

	var box := VBoxContainer.new()
	box.name = "InternationalHUDStack"
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_add_hud_icon(box, "HUDPollutionIcon", "pollution", HUD_POLLUTION_ICON_PATH)
	_add_hud_icon(box, "HUDMoneyIcon", "money", HUD_MONEY_ICON_PATH)

	var action_divider := ColorRect.new()
	action_divider.color = _theme_color("muted")
	action_divider.modulate.a = 0.42
	action_divider.custom_minimum_size.y = 1
	box.add_child(action_divider)

	var action_spacer := Control.new()
	action_spacer.custom_minimum_size.y = 6
	box.add_child(action_spacer)

	_hud_actions_label = _label("", 18, _theme_color("muted"))
	_hud_actions_label.name = "HUDActionsLabel"
	_hud_actions_label.set_meta("action_animation_mode", "inline_pulse")
	_hud_actions_label.set_meta("hud_action_label", true)
	_hud_actions_label.custom_minimum_size = Vector2(118, 64)
	_hud_actions_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_hud_actions_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_actions_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_hud_actions_label)

	var settings_spacer := Control.new()
	settings_spacer.custom_minimum_size.y = 10
	box.add_child(settings_spacer)
	_hud_settings_icon = _add_hud_icon(box, "HUDSettingsIcon", "settings", HUD_SETTINGS_ICON_PATH)
	_hud_settings_icon.pressed.connect(_toggle_settings_window)

	_hud_tooltip = _panel()
	_hud_tooltip.name = "HUDTooltip"
	_hud_tooltip.set_meta("tooltip_panel", true)
	_hud_tooltip.visible = false
	_hud_tooltip.z_index = 45
	_hud_tooltip.add_theme_stylebox_override("panel", _style(_theme_color("muted"), _theme_color("accent")))
	_ui_root.add_child(_hud_tooltip)
	_hud_tooltip_label = _label("", 19, _theme_color("ink"))
	_hud_tooltip_label.name = "HUDTooltipLabel"
	_hud_tooltip.add_child(_hud_tooltip_label)
	_ensure_edge_drawer()
	_edge_drawer.configure(
		HUD_RAIL_WIDTH,
		HUD_DRAWER_OPEN_DURATION,
		HUD_DRAWER_CLOSE_DURATION,
		HUD_DRAWER_CLOSE_DELAY
	)
	_edge_drawer.attach(_hud_panel, _hud_reveal_zone)
	_edge_drawer.add_companion(_hud_tooltip)
	_sync_edge_drawer_enabled()
	_layout_hud_rail()


func _add_hud_icon(parent: VBoxContainer, node_name: String, kind: String, texture_path: String) -> Button:
	var icon := Button.new()
	icon.name = node_name
	icon.set_meta("hud_icon", true)
	icon.text = ""
	icon.icon = _load_runtime_texture(texture_path)
	icon.custom_minimum_size = Vector2(60, 60)
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.focus_mode = Control.FOCUS_ALL
	icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	icon.pressed.connect(_show_hud_tooltip.bind(kind, icon))
	icon.mouse_entered.connect(_show_hud_tooltip.bind(kind, icon))
	icon.mouse_exited.connect(_hide_hud_tooltip)
	parent.add_child(icon)
	return icon


func _show_hud_tooltip(kind: String, source: Control) -> void:
	if _hud_tooltip == null or _hud_tooltip_label == null or source == null:
		return
	match kind:
		"pollution":
			_hud_tooltip_label.text = "污染 %d%%" % game.pollution
		"money":
			_hud_tooltip_label.text = "资金 %d" % game.money
		"settings":
			_hud_tooltip_label.text = "设置"
		_:
			_hud_tooltip_label.text = ""
	_hud_tooltip.position = source.global_position + Vector2(118, 18)
	_hud_tooltip.visible = true


func _hide_hud_tooltip() -> void:
	if _hud_tooltip != null:
		_hud_tooltip.visible = false
	if _edge_drawer != null:
		_edge_drawer.schedule_close()


func _is_hud_drawer_expanded() -> bool:
	_ensure_edge_drawer()
	return _edge_drawer.is_expanded()


func _set_hud_drawer_expanded(expanded: bool, animate: bool = true) -> void:
	_ensure_edge_drawer()
	_edge_drawer.set_expanded(expanded, animate)


func _hud_drawer_x(expanded: bool) -> float:
	_ensure_edge_drawer()
	return _edge_drawer.panel_x(expanded)


func _update_hud_drawer_auto_close(delta: float) -> void:
	if _edge_drawer != null:
		_edge_drawer.tick(delta)


func _handle_hud_drawer_global_input(event: InputEvent) -> bool:
	if _edge_drawer == null:
		return false
	return _edge_drawer.handle_global_input(event)


func _ensure_edge_drawer() -> void:
	if _edge_drawer != null:
		return
	_edge_drawer = EdgeDrawerScript.new()
	_edge_drawer.name = "EdgeDrawer"
	add_child(_edge_drawer)


func _sync_edge_drawer_enabled() -> void:
	if _edge_drawer != null:
		_edge_drawer.enabled = _game_started and not _input_locked


func _add_hud_metric(parent: VBoxContainer, label_text: String, value_name: String) -> Label:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var key := _label(label_text, 13, _theme_color("accent"))
	key.custom_minimum_size.x = 70
	row.add_child(key)
	var value := _label("", 17, _theme_color("ink"))
	value.name = value_name
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return value


func _build_vhs_overlay() -> void:
	_vhs_scanlines.clear()
	_vhs_overlay = Control.new()
	_vhs_overlay.name = "VHSOverlay"
	_vhs_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vhs_overlay.visible = _vhs_enabled
	_vhs_overlay.z_index = 3
	_ui_root.add_child(_vhs_overlay)

	var back_buffer := BackBufferCopy.new()
	back_buffer.name = "VHSBackBufferCopy"
	back_buffer.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	_vhs_overlay.add_child(back_buffer)

	_vhs_shader_rect = ColorRect.new()
	_vhs_shader_rect.name = "VHSDynamicFilter"
	_vhs_shader_rect.color = Color.WHITE
	_vhs_shader_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vhs_shader_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/vhs_screen.gdshader") as Shader
	shader_material.set_shader_parameter("intensity", 0.62)
	shader_material.set_shader_parameter("pollution", 0.0)
	_vhs_shader_rect.material = shader_material
	_vhs_overlay.add_child(_vhs_shader_rect)


func _build_cinematic_bars() -> void:
	_cinematic_bars = CinematicBarsScript.new()
	_cinematic_bars.name = "CinematicBars"
	_ui_root.add_child(_cinematic_bars)
	_cinematic_bars.bar_color = Color("050705")
	_cinematic_bars.configure(CINEMATIC_ASPECT_RATIO, CINEMATIC_MAX_BAR_RATIO)
	_cinematic_bars.relayout(_viewport_size())


func _layout_hud_rail() -> void:
	if _hud_panel == null:
		return
	var viewport_size := _viewport_size()
	var uses_cinematic_frame: bool = _game_started and game != null and game.view_state == "npc_up"
	var frame_inset := 0.0
	if uses_cinematic_frame and _cinematic_bars != null:
		frame_inset = _cinematic_bars.bar_height(viewport_size)
	var top_limit := frame_inset + HUD_RAIL_FRAME_MARGIN
	var bottom_limit := viewport_size.y - frame_inset - HUD_RAIL_FRAME_MARGIN
	var available_height := maxf(1.0, bottom_limit - top_limit)
	var rail_height := minf(HUD_RAIL_MAX_HEIGHT, available_height)
	var center_y := (top_limit + bottom_limit) * 0.5
	var rail_x := _edge_drawer.layout_panel_x() if _edge_drawer != null else _hud_drawer_x(_is_hud_drawer_expanded())
	var desired_top := center_y - rail_height * 0.5
	var desired_bottom := center_y + rail_height * 0.5
	var clamped_top := maxf(top_limit, desired_top)
	var clamped_bottom := minf(bottom_limit, desired_bottom)
	if clamped_bottom - clamped_top > available_height:
		clamped_top = top_limit
		clamped_bottom = bottom_limit
	_hud_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_hud_panel.offset_left = 0.0
	_hud_panel.offset_top = clamped_top
	_hud_panel.offset_right = HUD_RAIL_WIDTH
	_hud_panel.offset_bottom = clamped_bottom
	_hud_panel.position.x = rail_x
	_hud_panel.set_meta("cinematic_safe_top", top_limit)
	_hud_panel.set_meta("cinematic_safe_bottom", bottom_limit)
	_hud_panel.set_meta("collapsed_x", _hud_drawer_x(false))
	_hud_panel.set_meta("expanded_x", _hud_drawer_x(true))
	if _hud_reveal_zone != null:
		_hud_reveal_zone.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_hud_reveal_zone.offset_left = 0.0
		_hud_reveal_zone.offset_top = center_y - rail_height * 0.5
		_hud_reveal_zone.offset_right = HUD_DRAWER_EDGE_HIT_WIDTH
		_hud_reveal_zone.offset_bottom = center_y + rail_height * 0.5
	if _window_manager != null:
		_window_manager.set_window_min_x("bank", _hud_panel.get_global_rect().end.x + 12.0)


func _build_settings_window() -> void:
	_ensure_settings_history_panel()
	_settings_history_panel.mount(_ui_root, _settings_history_mount_deps())
	_settings_window = _settings_history_panel.get_settings_window() as PanelContainer
	_inject_settings_camera_block()
	_layout_settings_window()
	_settings_history_panel.refresh_menu_labels(game.pollution, game.autoplay_enabled)
	_settings_history_panel.build_exit_confirmation_overlay(_ui_root)
	if _edge_drawer != null and _settings_window != null:
		_edge_drawer.add_exclusion(_settings_window)


func _build_phone_camera_connection_overlay() -> void:
	if _ui_root == null:
		return
	_phone_camera_connection_overlay = Control.new()
	_phone_camera_connection_overlay.name = "PhoneCameraConnectionOverlay"
	_phone_camera_connection_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_phone_camera_connection_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_phone_camera_connection_overlay.z_index = 205
	_phone_camera_connection_overlay.visible = false
	_ui_root.add_child(_phone_camera_connection_overlay)

	var blackout := ColorRect.new()
	blackout.name = "PhoneCameraConnectionBackdrop"
	blackout.color = Color(0.01, 0.025, 0.015, 0.82)
	blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	blackout.mouse_filter = Control.MOUSE_FILTER_STOP
	_phone_camera_connection_overlay.add_child(blackout)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24.0
	center.offset_top = 24.0
	center.offset_right = -24.0
	center.offset_bottom = -24.0
	_phone_camera_connection_overlay.add_child(center)

	_phone_camera_connection_panel = _panel()
	_phone_camera_connection_panel.name = "PhoneCameraConnectionPanel"
	_phone_camera_connection_panel.custom_minimum_size = Vector2(680.0, 460.0)
	center.add_child(_phone_camera_connection_panel)

	var box := VBoxContainer.new()
	box.name = "PhoneCameraConnectionContent"
	box.add_theme_constant_override("separation", 14)
	_phone_camera_connection_panel.add_child(box)

	var eyebrow := _label("REMOTE LENS  /  LOCAL PROCESSING", 14, _theme_color("accent"))
	eyebrow.name = "PhoneCameraConnectionEyebrow"
	box.add_child(eyebrow)
	var title := _label("手机镜头连接", 30, _theme_color("ink"))
	title.name = "PhoneCameraConnectionTitle"
	box.add_child(title)

	_phone_camera_connection_status_label = _label("正在寻找手机镜头…", 21, _theme_color("accent"))
	_phone_camera_connection_status_label.name = "PhoneCameraConnectionStatus"
	box.add_child(_phone_camera_connection_status_label)
	_phone_camera_connection_detail_label = _label("", 16, _theme_color("ink"))
	_phone_camera_connection_detail_label.name = "PhoneCameraConnectionDetail"
	_phone_camera_connection_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_phone_camera_connection_detail_label.custom_minimum_size.y = 128.0
	box.add_child(_phone_camera_connection_detail_label)

	var privacy_note := _label("画面只交给本机 MediaPipe 计算关键点；游戏不保存视频。", 14, _theme_color("accent"))
	privacy_note.name = "PhoneCameraConnectionPrivacyNote"
	privacy_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(privacy_note)

	var actions := HBoxContainer.new()
	actions.name = "PhoneCameraConnectionActions"
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 10)
	box.add_child(actions)
	_phone_camera_connection_retry_button = Button.new()
	_phone_camera_connection_retry_button.name = "PhoneCameraConnectionRetryButton"
	_phone_camera_connection_retry_button.text = "重新扫描手机镜头"
	_phone_camera_connection_retry_button.custom_minimum_size = Vector2(210.0, 54.0)
	_phone_camera_connection_retry_button.pressed.connect(_retry_phone_camera_connection)
	actions.add_child(_phone_camera_connection_retry_button)
	_phone_camera_connection_continue_button = Button.new()
	_phone_camera_connection_continue_button.name = "PhoneCameraConnectionContinueButton"
	_phone_camera_connection_continue_button.text = "继续游戏"
	_phone_camera_connection_continue_button.custom_minimum_size = Vector2(150.0, 54.0)
	_phone_camera_connection_continue_button.pressed.connect(_hide_phone_camera_connection_overlay)
	actions.add_child(_phone_camera_connection_continue_button)
	var disable_button := Button.new()
	disable_button.name = "PhoneCameraConnectionDisableButton"
	disable_button.text = "关闭摄像头"
	disable_button.custom_minimum_size = Vector2(150.0, 54.0)
	disable_button.pressed.connect(_disable_phone_camera_from_connection)
	actions.add_child(disable_button)

	_refresh_phone_camera_connection_ui()
	if _camera_enabled and _camera_source == "phone":
		_show_phone_camera_connection_overlay()


func _show_phone_camera_connection_overlay() -> void:
	if _phone_camera_connection_overlay == null or not is_instance_valid(_phone_camera_connection_overlay):
		return
	_phone_camera_connection_overlay.visible = true
	_phone_camera_connection_overlay.move_to_front()
	_refresh_phone_camera_connection_ui()


func _hide_phone_camera_connection_overlay() -> void:
	if _phone_camera_connection_overlay != null and is_instance_valid(_phone_camera_connection_overlay):
		_phone_camera_connection_overlay.visible = false


func _retry_phone_camera_connection() -> void:
	_activate_camera_source("phone")


func _disable_phone_camera_from_connection() -> void:
	_set_camera_enabled(false, true)
	_hide_phone_camera_connection_overlay()


func _refresh_phone_camera_connection_ui() -> void:
	if _phone_camera_connection_overlay == null or _phone_camera_connection_status_label == null or _phone_camera_connection_detail_label == null:
		return
	var state := "off"
	var status_text := "手机镜头未启用"
	var detail_text := "返回设置，点击“连接手机摄像头并开启 X-ray”后再试。"
	if _camera_enabled and _camera_source == "phone":
		if _camera_ready_source == "phone":
			state = "ready"
			status_text = "手机镜头已连入"
			detail_text = "已从系统摄像头编号 %d 收到画面。放下游戏内手机，用双手拇指与食指的四个指尖框出矩形。" % _camera_ready_index
		elif _camera_tracking_has_error():
			state = "error"
			status_text = "手机镜头连接失败"
			detail_text = "没有收到手机画面：%s。请解锁手机，确认系统摄像头权限，再重新扫描。" % _camera_tracking_status
		else:
			state = "searching"
			status_text = "正在寻找手机镜头…"
			detail_text = "当前测试版会在系统摄像头列表中寻找 Continuity Camera 或虚拟摄像头。请先解锁手机，并允许电脑把它作为摄像头。"
	_phone_camera_connection_overlay.set_meta("connection_state", state)
	_phone_camera_connection_overlay.set_meta("camera_source", _camera_source)
	_phone_camera_connection_overlay.set_meta("selected_index", _camera_ready_index)
	_phone_camera_connection_status_label.text = status_text
	_phone_camera_connection_detail_label.text = detail_text
	_set_localized_property(_phone_camera_connection_status_label, "text")
	_set_localized_property(_phone_camera_connection_detail_label, "text")
	if _phone_camera_connection_panel != null:
		var border_color := _theme_color("muted")
		if state == "ready":
			border_color = _theme_color("accent")
		elif state == "error":
			border_color = Color("9f493f")
		_phone_camera_connection_panel.add_theme_stylebox_override(
			"panel",
			_soft_style(_theme_color("surface"), border_color)
		)
	if _phone_camera_connection_retry_button != null:
		_phone_camera_connection_retry_button.disabled = not _camera_enabled or _camera_source != "phone"
	if _phone_camera_connection_continue_button != null:
		_phone_camera_connection_continue_button.text = "进入 X-ray 玩法" if state == "ready" else "继续游戏"
		_set_localized_property(_phone_camera_connection_continue_button, "text")


func _camera_tracking_has_error() -> bool:
	return _camera_tracking_status in [
		"手部追踪端口不可用",
		"手部追踪数据版本不匹配",
		"缺少手部追踪程序",
		"缺少手部追踪模型",
		"缺少 MediaPipe 环境",
		"无法启动手部追踪程序",
		"摄像头不可用或权限被拒绝",
		"手部追踪程序发生错误",
	]


func _layout_settings_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.layout_settings(_viewport_size())


func _ensure_settings_history_panel() -> void:
	if _settings_history_panel != null and is_instance_valid(_settings_history_panel):
		return
	_settings_history_panel = SettingsHistoryPanelScript.new()
	_settings_history_panel.name = "SettingsHistoryPanel"
	add_child(_settings_history_panel)
	_connect_settings_history_panel_signals()


func _settings_history_mount_deps() -> Dictionary:
	_ensure_window_manager()
	var locales: Array = []
	for locale_code in GameLocaleScript.SUPPORTED_LOCALES:
		locales.append({
			"code": str(locale_code),
			"name": _locale.native_language_name(str(locale_code)),
		})
	return {
		"panel_factory": _panel,
		"label_factory": _label,
		"soft_style": _soft_style,
		"theme_color": _theme_color,
		"ui_font_size": _ui_font_size,
		"register_draggable": _window_manager.register,
		"master_volume": _master_volume,
		"vhs_enabled": _vhs_enabled,
		"autoplay_enabled": game != null and game.autoplay_enabled,
		"locales": locales,
		"current_locale": _locale.current_locale if _locale != null else "",
	}


func _connect_settings_history_panel_signals() -> void:
	var panel := _settings_history_panel
	if panel == null:
		return
	if not panel.volume_changed.is_connected(_on_volume_changed):
		panel.volume_changed.connect(_on_volume_changed)
	if not panel.vhs_toggled.is_connected(_on_vhs_toggled):
		panel.vhs_toggled.connect(_on_vhs_toggled)
	if not panel.autoplay_toggled.is_connected(_on_autoplay_toggled):
		panel.autoplay_toggled.connect(_on_autoplay_toggled)
	if not panel.language_selected.is_connected(_on_settings_language_selected):
		panel.language_selected.connect(_on_settings_language_selected)
	if not panel.manual_save_pressed.is_connected(_on_manual_save_pressed):
		panel.manual_save_pressed.connect(_on_manual_save_pressed)
	if not panel.return_main_menu_pressed.is_connected(_on_return_main_menu_pressed):
		panel.return_main_menu_pressed.connect(_on_return_main_menu_pressed)
	if not panel.exit_game_requested.is_connected(_request_quit_game):
		panel.exit_game_requested.connect(_request_quit_game)
	if not panel.exit_confirmed.is_connected(_confirm_quit_game):
		panel.exit_confirmed.connect(_confirm_quit_game)
	if not panel.history_toggle_requested.is_connected(_toggle_history_window):
		panel.history_toggle_requested.connect(_toggle_history_window)
	if not panel.settings_open_changed.is_connected(_on_settings_open_changed):
		panel.settings_open_changed.connect(_on_settings_open_changed)


func _ensure_social_feed_panel() -> void:
	if _social_feed_panel != null and is_instance_valid(_social_feed_panel):
		return
	_social_feed_panel = SocialFeedPanelScript.new()
	_social_feed_panel.name = "SocialFeedPanel"
	add_child(_social_feed_panel)
	_connect_social_feed_panel_signals()


func _social_feed_mount_deps() -> Dictionary:
	_ensure_window_manager()
	return {
		"panel_factory": _panel,
		"label_factory": _label,
		"style_fn": _style,
		"theme_color": _theme_color,
		"ui_font_size": _ui_font_size,
		"register_draggable": _window_manager.register,
		"load_texture": _load_runtime_texture,
		"poster_texture": _social_poster_texture,
		"channels": SOCIAL_CHANNELS,
		"no_signal_icon_path": NO_SIGNAL_ICON_PATH,
		"poster_sheet_path": SOCIAL_POSTER_SHEET_PATH,
		"poster_sheet_count": SOCIAL_POSTER_COUNT,
		"visible_post_indices": _social_visible_post_indices,
		"post_for_index": _social_post_for_index,
		"is_following": func(author_id: String) -> bool: return game != null and game.is_social_following(author_id),
		"like_text": _social_like_text,
		"caption_text": _social_caption,
		"corrupt_text": _corrupt,
		"floor_label": _social_floor_label,
		"translate": func(text: String) -> String: return _locale.translate(text),
		"pickup_rich_text": _make_pickup_rich_text,
		"author_id": _social_author_id,
		"pickup_line": func(post_id: String, locale: String) -> String: return PickupCharPoolScript.get_pickup_line(post_id, locale),
		"pickup_comments": func(post_id: String, locale: String) -> Array: return PickupCharPoolScript.get_comments(post_id, locale),
		"player_echo_quote": func() -> String: return game.get_player_echo_quote(_locale.current_locale) if game != null else "",
		"echo_comment_handle": func() -> String: return EchoQuoteContentScript.anon_handle(_locale.current_locale),
		"game_day": func() -> int: return game.day if game != null else 0,
		"current_locale": func() -> String: return _locale.current_locale,
		"publish_result": _social_publish_result,
		"free_sentence_units": func() -> Array: return game.get_free_sentence_units() if game != null else [],
		"render_publish_sentence_area": _render_publish_sentence_area,
		"completed_memes_count": func() -> int: return game.completed_memes.size() if game != null else 0,
		"pollution": func() -> int: return game.pollution if game != null else 0,
		"player_character_path": PLAYER_CHARACTER_PATH,
		"composer_soft_unit_limit": COMPOSER_SOFT_UNIT_LIMIT,
		"input_locked": func() -> bool: return _input_locked,
	}


func _connect_social_feed_panel_signals() -> void:
	var panel = _social_feed_panel
	if panel == null:
		return
	if not panel.channel_pressed.is_connected(_on_social_channel_pressed):
		panel.channel_pressed.connect(_on_social_channel_pressed)
	if not panel.screen_requested.is_connected(_set_social_screen):
		panel.screen_requested.connect(_set_social_screen)
	if not panel.card_clicked.is_connected(_open_social_post):
		panel.card_clicked.connect(_open_social_post)
	if not panel.like_pressed.is_connected(_on_social_like_pressed):
		panel.like_pressed.connect(_on_social_like_pressed)
	if not panel.follow_pressed.is_connected(_on_social_follow_pressed):
		panel.follow_pressed.connect(_on_social_follow_pressed)
	if not panel.close_requested.is_connected(_close_app_window.bind("social")):
		panel.close_requested.connect(_close_app_window.bind("social"))
	if not panel.detail_close_requested.is_connected(_close_social_detail_window):
		panel.detail_close_requested.connect(_close_social_detail_window)
	if not panel.publish_confirm_requested.is_connected(_on_confirm_dialogue_pressed):
		panel.publish_confirm_requested.connect(_on_confirm_dialogue_pressed)


func _inject_settings_camera_block() -> void:
	var slot := _settings_history_panel.get_camera_slot() if _settings_history_panel != null else null
	if slot == null or slot.get_child_count() > 0:
		return
	var camera_rule := HSeparator.new()
	slot.add_child(camera_rule)
	_camera_access_toggle = CheckButton.new()
	_camera_access_toggle.name = "SettingsCameraAccessToggle"
	_camera_access_toggle.text = "允许访问摄像头"
	_camera_access_toggle.button_pressed = _camera_enabled
	_camera_access_toggle.custom_minimum_size.y = 48
	_camera_access_toggle.set_meta("privacy_control", true)
	_camera_access_toggle.toggled.connect(_on_camera_access_toggled)
	slot.add_child(_camera_access_toggle)
	var camera_source_label := _label("摄像头来源", 15, _theme_color("ink"))
	camera_source_label.name = "SettingsCameraSourceLabel"
	slot.add_child(camera_source_label)
	_camera_source_button_group = ButtonGroup.new()
	_camera_source_button_group.allow_unpress = false
	_camera_computer_button = Button.new()
	_camera_computer_button.name = "SettingsOpenComputerCameraButton"
	_camera_computer_button.text = "打开电脑摄像头并开启 X-ray"
	_camera_computer_button.tooltip_text = "只会选择电脑内置或 USB 摄像头。"
	_camera_computer_button.toggle_mode = true
	_camera_computer_button.button_group = _camera_source_button_group
	_camera_computer_button.set_meta("camera_source_id", "computer")
	_camera_computer_button.custom_minimum_size.y = 52
	_camera_computer_button.pressed.connect(_activate_camera_source.bind("computer"))
	slot.add_child(_camera_computer_button)
	_camera_phone_button = Button.new()
	_camera_phone_button.name = "SettingsConnectPhoneCameraButton"
	_camera_phone_button.text = "连接手机摄像头并开启 X-ray"
	_camera_phone_button.tooltip_text = "只会选择手机连续互通或虚拟摄像头。"
	_camera_phone_button.toggle_mode = true
	_camera_phone_button.button_group = _camera_source_button_group
	_camera_phone_button.set_meta("camera_source_id", "phone")
	_camera_phone_button.custom_minimum_size.y = 52
	_camera_phone_button.pressed.connect(_activate_camera_source.bind("phone"))
	slot.add_child(_camera_phone_button)
	_refresh_camera_source_buttons()
	var phone_fallback_note := _label("手机备用会优先寻找连续互通相机或虚拟摄像头。", 13, _theme_color("ink"))
	phone_fallback_note.name = "SettingsPhoneCameraFallbackNote"
	phone_fallback_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(phone_fallback_note)
	var camera_privacy := _label("镜头仅在启用时由本地 MediaPipe 读取。", 13, _theme_color("ink"))
	camera_privacy.name = "SettingsCameraPrivacyNote"
	camera_privacy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(camera_privacy)
	_camera_status_label = _label(_camera_tracking_status, 14, _theme_color("accent"))
	_camera_status_label.name = "SettingsCameraStatus"
	_camera_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	slot.add_child(_camera_status_label)


func _build_history_window() -> void:
	_ensure_settings_history_panel()
	_settings_history_panel.mount(_ui_root, _settings_history_mount_deps())
	_render_history_window()


func _toggle_history_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.toggle(game.get_history_entries())


func _close_history_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.close()


func _render_history_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.refresh_history(game.get_history_entries())


func _refresh_settings_menu_labels() -> void:
	if _settings_history_panel != null and game != null:
		_settings_history_panel.refresh_menu_labels(game.pollution, game.autoplay_enabled)


func _on_autoplay_toggled(value: bool) -> void:
	game.autoplay_enabled = value


func _settings_is_open() -> bool:
	return _settings_history_panel != null and is_instance_valid(_settings_history_panel) and _settings_history_panel.is_settings_open()


func _toggle_settings_window() -> void:
	if _settings_history_panel == null:
		return
	_settings_history_panel.toggle_settings()


func _close_settings_window() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.close_settings()


func _on_settings_open_changed(_open: bool) -> void:
	_hide_hud_tooltip()
	_update_visibility()


func _on_volume_changed(value: float) -> void:
	_master_volume = value
	_apply_master_volume()


func _apply_master_volume() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0:
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(0.001, _master_volume / 100.0)))


func _on_settings_language_selected(locale_code: String) -> void:
	if locale_code.is_empty():
		return
	if _reality_interaction_active:
		_exit_reality_interaction(false)
	if not _locale.select_language(locale_code):
		return
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)
	# 换语言即换字池:清空造句台,避免旧语言的字混进新语言的句子。
	if game != null:
		game.free_sentence_clear()
	_render()
	_refresh_localized_ui()
	_refresh_camera_source_option_labels()


func _on_manual_save_pressed() -> void:
	var progress_saved := _save_progress()
	var preferences_saved := _locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)
	if _settings_history_panel != null:
		_settings_history_panel.set_save_status(
			"已保存当前进度与设置。" if progress_saved and preferences_saved else "保存失败，请检查本地写入权限。"
		)
	_refresh_localized_ui()


func _on_return_main_menu_pressed() -> void:
	call_deferred("show_main_menu")


func _on_vhs_toggled(value: bool) -> void:
	_vhs_enabled = value
	if _vhs_overlay != null:
		_vhs_overlay.visible = value


func _on_camera_access_toggled(value: bool) -> void:
	_camera_session_decided = true
	_set_camera_enabled(value, true)


func _request_quit_game() -> void:
	game.exit_prompt_seen = true
	if _settings_history_panel != null:
		_settings_history_panel.request_quit()


func _cancel_quit_game() -> void:
	if _settings_history_panel != null:
		_settings_history_panel.cancel_quit()


func _confirm_quit_game() -> void:
	if _game_started:
		_save_progress()
	_locale.save_preferences(_master_volume, _vhs_enabled, _camera_enabled, _camera_source)
	get_tree().quit()


func _quit_game() -> void:
	_request_quit_game()


func _build_app_window(app_id: String, title: String, node_name: String, left: float, top: float, right: float, bottom: float) -> void:
	var window := _panel()
	window.name = node_name
	window.clip_contents = true
	window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_apply_app_window_layout(window, app_id, left, top, right, bottom)
	window.z_index = 10
	_ui_root.add_child(window)

	var app_box := VBoxContainer.new()
	app_box.add_theme_constant_override("separation", 8)
	window.add_child(app_box)

	var title_label := _label(title, 21, _theme_color("accent"))
	title_label.name = "%sHandle" % node_name
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close_button := Button.new()
	close_button.name = "%sCloseButton" % node_name
	close_button.text = "X"
	close_button.set_meta("window_close_button", true)
	close_button.custom_minimum_size = Vector2(56, 56)
	close_button.pressed.connect(_close_app_window.bind(app_id))
	var title_bar := HBoxContainer.new()
	title_bar.name = "%sTitleBar" % node_name
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	title_bar.custom_minimum_size.y = 56
	title_bar.add_theme_constant_override("separation", 8)
	app_box.add_child(title_bar)
	title_bar.add_child(title_label)
	_make_draggable_window(window, "app:%s" % app_id, title_bar)
	_make_draggable_window(window, "app:%s" % app_id, title_label)
	title_bar.add_child(close_button)

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 8)
	if app_id == "notebook":
		body.name = "NotebookAppBody"
		body.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_box.add_child(body)
	else:
		var app_scroll := ScrollContainer.new()
		app_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
		app_box.add_child(app_scroll)
		app_scroll.add_child(body)

	_app_windows[app_id] = window
	_app_titles[app_id] = title_label
	_app_bodies[app_id] = body


func _apply_app_window_layout(window: Control, app_id: String, left: float, top: float, right: float, bottom: float) -> void:
	var viewport_size := _viewport_size()
	if viewport_size.x >= 900.0:
		if app_id == "notebook":
			window.set_anchors_preset(Control.PRESET_TOP_LEFT)
			var notebook_left := 188.0 if _hud_panel != null else 44.0
			window.offset_left = notebook_left
			window.offset_top = 46.0
			window.offset_right = notebook_left + minf(610.0, viewport_size.x * 0.42)
			window.offset_bottom = minf(782.0, viewport_size.y - 34.0)
			return
		window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		window.offset_left = left
		window.offset_top = top
		window.offset_right = right
		window.offset_bottom = bottom
		return
	window.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	var safe_left := 12.0
	if _hud_panel != null:
		safe_left = maxf(safe_left, _hud_panel.offset_right + 10.0)
	var right_margin := 12.0
	var available_width := maxf(220.0, viewport_size.x - safe_left - right_margin)
	var original_width := right - left
	var target_width := minf(original_width, available_width)
	var top_margin := clampf(top, 12.0, 72.0)
	window.offset_right = -right_margin
	window.offset_left = window.offset_right - target_width
	window.offset_top = top_margin
	window.offset_bottom = viewport_size.y - 8.0


func _apply_phone_popup_layout(expanded: bool) -> void:
	if _phone_panel == null:
		return
	var viewport_size := _viewport_size()
	_phone_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	if expanded:
		var safe_left := 176.0
		if _hud_panel != null:
			safe_left = _hud_panel.offset_right + 18.0
		var max_height := minf(824.0, viewport_size.y - 32.0)
		var max_width := minf(480.0, viewport_size.x - safe_left - 28.0)
		var phone_width := maxf(286.0, minf(max_width, max_height / 1.72))
		var phone_height := phone_width * 1.72
		_phone_panel.offset_right = -24
		_phone_panel.offset_bottom = -18
		if viewport_size.x < 720.0:
			_phone_panel.offset_right = -8
			_phone_panel.offset_bottom = -8
		_phone_panel.offset_left = _phone_panel.offset_right - phone_width
		_phone_panel.offset_top = _phone_panel.offset_bottom - phone_height
	else:
		_phone_panel.offset_top = -306
		_phone_panel.offset_left = -112
		_phone_panel.offset_right = -12
		_phone_panel.offset_bottom = -94


func _apply_meme_bank_popup_layout(mode: String) -> void:
	if _meme_bank_window == null:
		return
	var viewport_size := _viewport_size()
	if mode == "open":
		_meme_bank_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		var ring_size := minf(680.0, maxf(430.0, minf(viewport_size.x * 0.48, viewport_size.y - 54.0)))
		_meme_bank_window.offset_left = -ring_size
		_meme_bank_window.offset_top = -ring_size * 0.5
		_meme_bank_window.offset_right = 18.0
		_meme_bank_window.offset_bottom = ring_size * 0.5
	elif mode == "collapsed":
		_meme_bank_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_meme_bank_window.offset_left = -144.0
		_meme_bank_window.offset_top = -66.0
		_meme_bank_window.offset_right = -12.0
		_meme_bank_window.offset_bottom = 66.0
	else:
		_meme_bank_window.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		_meme_bank_window.offset_left = -1.0
		_meme_bank_window.offset_top = -1.0
		_meme_bank_window.offset_right = 0.0
		_meme_bank_window.offset_bottom = 0.0


func _apply_reality_layout() -> void:
	var viewport_size := _viewport_size()
	var hud_right := 0.0
	if _hud_panel != null:
		hud_right = _hud_panel.offset_right
	var compact := viewport_size.x < 760.0
	var safe_left := maxf(18.0, hud_right + (12.0 if compact else 48.0))
	var right_margin := 18.0 if compact else 150.0
	var content_left := safe_left + (4.0 if compact else 80.0)
	var content_right := -right_margin
	if _reality_intent_preview != null:
		_reality_intent_preview.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_reality_intent_preview.offset_left = content_left
		_reality_intent_preview.offset_top = -354.0
		_reality_intent_preview.offset_right = content_right
		_reality_intent_preview.offset_bottom = -282.0
	if _reality_choice_row != null:
		_reality_choice_row.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_reality_choice_row.offset_left = content_left
		_reality_choice_row.offset_top = -272.0
		_reality_choice_row.offset_right = content_right
		_reality_choice_row.offset_bottom = -208.0
	if _reality_typing_line != null:
		_reality_typing_line.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_reality_typing_line.offset_left = content_left
		_reality_typing_line.offset_top = -300.0
		_reality_typing_line.offset_right = content_right
		_reality_typing_line.offset_bottom = -208.0
	if _reality_typing_progress != null:
		_reality_typing_progress.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_reality_typing_progress.offset_left = content_left
		_reality_typing_progress.offset_top = -208.0
		_reality_typing_progress.offset_right = content_right
		_reality_typing_progress.offset_bottom = -182.0
	if _reality_subtitle_panel != null:
		_reality_subtitle_panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		_reality_subtitle_panel.offset_left = content_left
		_reality_subtitle_panel.offset_top = -178.0
		_reality_subtitle_panel.offset_right = content_right
		_reality_subtitle_panel.offset_bottom = -104.0


func _apply_view_toggle_layout() -> void:
	if _view_toggle_button == null:
		return
	var viewport_size := _viewport_size()
	_view_toggle_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	if viewport_size.x >= 760.0:
		_view_toggle_button.offset_left = 470.0
		_view_toggle_button.offset_top = -92.0
		_view_toggle_button.offset_right = 596.0
		_view_toggle_button.offset_bottom = -36.0
		return
	var safe_left := 12.0
	if _hud_panel != null:
		safe_left = _hud_panel.offset_right + 12.0
	var safe_right := viewport_size.x - 12.0
	var available_width := maxf(126.0, safe_right - safe_left)
	var button_width := minf(220.0, available_width)
	var button_left := safe_left + (available_width - button_width) * 0.5
	_view_toggle_button.offset_left = button_left
	_view_toggle_button.offset_top = -76.0
	_view_toggle_button.offset_right = button_left + button_width
	_view_toggle_button.offset_bottom = -20.0


func _apply_responsive_layouts_if_needed(force: bool = false) -> void:
	var viewport_size := _viewport_size()
	if not force and viewport_size == _last_responsive_layout_size:
		return
	_last_responsive_layout_size = viewport_size
	if _phone_panel != null and game != null:
		_apply_phone_popup_layout(game.view_state == "phone_down")
	if _meme_bank_window != null:
		var show_meme_bank := _should_show_meme_bank()
		var desired_bank_layout := "open" if _meme_bank_open else ("collapsed" if show_meme_bank else "peek")
		_meme_bank_layout_mode = desired_bank_layout
		_apply_meme_bank_popup_layout(desired_bank_layout)
	if _social_feed_panel != null:
		var social_safe_left := 12.0
		if _hud_panel != null:
			social_safe_left = maxf(social_safe_left, _hud_panel.offset_right + 10.0)
		_social_feed_panel.layout_detail(viewport_size, social_safe_left)
		_social_feed_panel.layout_window(viewport_size, social_safe_left)
	_apply_reality_layout()
	_apply_view_toggle_layout()
	_layout_settings_window()
	if _cinematic_bars != null:
		_cinematic_bars.relayout(_viewport_size())
	_layout_hud_rail()


func _render() -> void:
	if game.ending_unlocked:
		_render_ending()
		_refresh_localized_ui()
		return
	_ensure_reality_floor_current()
	if _reality_floor != null:
		_reality_floor.sync_prerequisite_items(game.revealed_prerequisite_item_ids, game.collected_prerequisite_item_ids)
		_reality_floor.sync_claimed_dolls(game.claimed_doll_ids)
	_render_status()
	_render_world_prompt()
	_render_app()
	_render_publish()
	_render_bank()
	_render_reality()
	_update_visibility()
	_apply_world_theme()
	_apply_ui_theme()
	_refresh_localized_ui()


func _render_status() -> void:
	if _hud_actions_label != null:
		_hud_actions_label.text = _action_text(game.actions_remaining)
	if _desk_log != null:
		_desk_log.text = log_text
	_refresh_settings_menu_labels()
	if _settings_history_panel != null and _settings_history_panel.is_open():
		_render_history_window()
	_render_playtest_assist()
	_update_doll_guide()
	_sync_ultimate_task_props()


func _render_playtest_assist() -> void:
	if _playtest_assist_panel == null or _playtest_assist_label == null:
		return
	var step: Dictionary = game.get_tutorial_step()
	var tutorial_complete := bool(step.get("is_complete", false))
	# 引导台词由常驻玩偶小窗承担;本面板只在纯测试辅助开启时出现,不再双显同一句。
	# 引导只由左下角的缝线布偶小窗承担;本面板仅在显式开启测试辅助时出现。
	_playtest_assist_panel.visible = _game_started and not _settings_is_open() and _playtest_assist_enabled
	if not _playtest_assist_panel.visible:
		return
	var lines: Array[String] = []
	if not _playtest_assist_enabled:
		_playtest_assist_label.text = "\n".join(lines)
		return
	lines.append(str(step.get("test_instruction", "测试提示：继续探索。")))
	var floor_number := clampi(game.tower_floor, 1, 4)
	if floor_number <= 3:
		var progress: Dictionary = game.get_key_clue_progress(floor_number)
		var item: Dictionary = game.get_prerequisite_item_for_floor(floor_number)
		var item_id := str(item.get("id", ""))
		var clue_state := "已答对" if bool(progress.get("solved", false)) else "未完成"
		var item_state := "已拾取" if item_id in game.collected_prerequisite_item_ids else ("已显形" if item_id in game.revealed_prerequisite_item_ids else "未显形")
		lines.append("本层测试：关键 NPC %s / 前置物 %s" % [clue_state, item_state])
		if bool(progress.get("solved", false)) and item_id not in game.collected_prerequisite_item_ids:
			lines.append("目标：%s。%s" % [str(item.get("label", "前置物")), str(item.get("location_hint", "跟随荧光测试标记。"))])
	var collected_count := game.collected_prerequisite_item_ids.size()
	lines.append("隐藏层测试：前置物 %d/3 · 污染 %d/80 · 第三层结束检查" % [collected_count, game.pollution])
	_playtest_assist_label.text = "\n".join(lines)


func _action_text(actions: int) -> String:
	return "今日行动\n%s" % _action_pips(actions)


func _action_pips(actions: int) -> String:
	var pips := ""
	for index in game.max_actions_per_day:
		if index > 0:
			pips += " "
		pips += "●" if index < actions else "○"
	return pips


func _render_world_prompt() -> void:
	var plan := _day_plan()
	if game.view_state == "phone_down":
		_world_prompt.text = "DAY %d. %s\n路面在脚下滑动。手机 App 的窗口浮在屏幕旁边。" % [game.day, plan["title"]]
	elif _reality_interaction_active:
		_world_prompt.text = "%s：%s" % [_active_actor_display_name(), _corrupt(game.conversation_prompt)]
	elif _nearby_reality_item != null:
		_world_prompt.text = "F  拾取 · %s\n%s" % [
			str(_nearby_reality_item.get_meta("display_name", "街区遗物")),
			str(_nearby_reality_item.get_meta("item_description", "信号已经写入。")),
		]
	elif _nearby_reality_actor != null:
		_world_prompt.text = "F  交谈 · %s" % str(_nearby_reality_actor.get_meta("display_name", "对方"))
	else:
		_world_prompt.text = ""


func _render_app() -> void:
	for app_id in ["social", "babel", "notebook"]:
		if not _app_bodies.has(app_id):
			continue
		_app_body = _app_bodies[app_id] as VBoxContainer
		_app_title = _app_titles[app_id] as Label
		match app_id:
			"babel":
				_app_title.text = "巴别塔 App"
				_render_babel_app()
			"notebook":
				_app_title.text = "笔记本 App"
				_render_notebook_app()
			"social":
				_app_title.text = "社交媒体 App"
				_publish_blank = null
				_confirm_publish_button = null
				if _social_feed_panel != null:
					_social_feed_panel.render_app(_social_screen, _social_channel)
					_confirm_publish_button = _social_feed_panel.get_confirm_publish_button()
	if _social_feed_panel != null:
		_social_feed_panel.render_companion()


func _render_babel_app() -> void:
	_clear(_app_body)
	var displayed_floor := clampi(game.tower_floor, 1, 4)
	var floor_heading := _locale.level_display_name(displayed_floor)
	var heading := _label(floor_heading, 24, _theme_color("ink"))
	heading.name = "BabelFloorHeading"
	_app_body.add_child(heading)
	var floor_card: Dictionary = LanguageCorruptionContentScript.get_floor_card_display(displayed_floor)
	var floor_field_names := {"危险": "Danger", "提示": "Hint"}
	for field_name in ["危险", "提示"]:
		var card_line := _label("%s：%s" % [field_name, str(floor_card.get(field_name, ""))], 16, _theme_color("ink"))
		card_line.name = "BabelFloor%sLabel" % floor_field_names[field_name]
		card_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_app_body.add_child(card_line)
	_app_body.add_child(_label("资金 %d  /  通过发布完整表达获得" % game.money, 16, _theme_color("accent")))
	_app_body.add_child(_label("污染 %d%%  /  发布与现实表达会推进污染" % game.pollution, 16, _theme_color("accent")))
	for item in game.event_log:
		_app_body.add_child(_label(str(item), 15, _theme_color("accent")))


func _social_visible_post_indices() -> Array[int]:
	var result: Array[int] = []
	for post_index in SOCIAL_POST_CARDS.size():
		if _social_channel == "following":
			var post := _social_post_for_index(post_index)
			if not game.is_social_following(_social_author_id(post)):
				continue
		result.append(post_index)
	return result


func _social_like_text(post: Dictionary, post_index: int) -> String:
	var liked := game.is_social_post_liked(str(post.get("id", "")))
	var stable_index := int(post.get("card_index", post_index))
	var count := 64 + (stable_index * 31) % 120 + (1 if liked else 0)
	return "%s %d" % ["♥" if liked else "♡", count]


func _social_floor_label() -> String:
	var floor_number := 1 if game == null else clampi(game.tower_floor, 1, 4)
	return _locale.level_display_name(floor_number)


func _social_caption(post: Dictionary, _post_index: int) -> String:
	return _locale.translate(str(post.get("caption", "未命名信号")))


func _social_publish_result() -> Dictionary:
	var placed_meme := _placed_meme()
	if game == null:
		return {}
	if not placed_meme.is_empty():
		return game.get_publish_result(placed_meme)
	return game.last_publish_result


## ============ 发布页的句子撰写区(接收笔记本画布拖来的字)============

func _render_publish_sentence_area(composer_box: VBoxContainer, placed_units: Array) -> void:
	var answer_panel := ComposerDropAreaScript.new()
	answer_panel.name = "ComposerAnswerPanel"
	answer_panel.custom_minimum_size.y = 92
	answer_panel.add_theme_stylebox_override("panel", _soft_style(_theme_color("surface"), _theme_color("accent")))
	answer_panel.unit_dropped.connect(_on_composer_area_drop)
	composer_box.add_child(answer_panel)
	var answer_box := VBoxContainer.new()
	answer_box.add_theme_constant_override("separation", 4)
	answer_panel.add_child(answer_box)
	var answer_flow := HFlowContainer.new()
	answer_flow.name = "ComposerAnswerFlow"
	answer_flow.add_theme_constant_override("h_separation", 6)
	answer_flow.add_theme_constant_override("v_separation", 6)
	answer_flow.custom_minimum_size.y = 46
	answer_box.add_child(answer_flow)
	if placed_units.is_empty():
		var placeholder := _label("……(句子还空着)", 14, _theme_color("muted"))
		placeholder.name = "ComposerAnswerPlaceholder"
		answer_flow.add_child(placeholder)
	for unit_index in placed_units.size():
		var placed_tile := ComposerAnswerTileScript.new()
		placed_tile.name = "ComposerAnswerTile%d" % unit_index
		placed_tile.text = str(placed_units[unit_index])
		placed_tile.focus_mode = Control.FOCUS_NONE
		placed_tile.custom_minimum_size = Vector2(44, 42)
		placed_tile.set_meta("skip_localization", true)
		placed_tile.configure_answer_tile(unit_index, str(placed_units[unit_index]))
		placed_tile.pressed.connect(_on_composer_answer_tapped.bind(unit_index))
		placed_tile.unit_dropped_before.connect(_on_composer_tile_drop)
		_apply_composer_tile_theme(placed_tile, false)
		answer_flow.add_child(placed_tile)
	var answer_rule := ColorRect.new()
	answer_rule.name = "ComposerAnswerUnderline"
	answer_rule.color = Color(_theme_color("accent"), 0.8)
	answer_rule.custom_minimum_size.y = 2.0
	answer_box.add_child(answer_rule)

	var preview_label := _label(game.get_free_sentence_text(_locale.current_locale), 15, _theme_color("ink"))
	preview_label.name = "ComposerPreviewLabel"
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.set_meta("skip_localization", true)
	composer_box.add_child(preview_label)

	var post_button := Button.new()
	post_button.name = "SocialPublishPostButton"
	post_button.custom_minimum_size.y = 52
	if placed_units.is_empty():
		post_button.text = "先放入一个字"
		post_button.disabled = true
	elif not game.can_spend_action():
		post_button.text = "今天不能再投稿"
		post_button.disabled = true
	else:
		post_button.text = "投稿"
		post_button.disabled = false
		post_button.add_theme_stylebox_override("normal", _style(_theme_color("accent"), _theme_color("ink")))
		post_button.add_theme_color_override("font_color", _theme_color("surface"))
	post_button.pressed.connect(_on_composer_submit_pressed)
	composer_box.add_child(post_button)


func _set_social_screen(screen: String) -> void:
	if _input_locked:
		return
	_social_screen = screen
	_social_detail_open = false
	if _social_feed_panel != null:
		_social_feed_panel.close_detail()
	_social_channel = "discover"
	if screen == "publish":
		_meme_bank_open = true
	_render()


func _on_social_channel_pressed(channel: String) -> void:
	if _input_locked:
		return
	_social_channel = channel
	if channel == "tower_base":
		_social_screen = "home"
		_social_detail_post_index = 0
		_social_detail_open = true
		if _social_feed_panel != null:
			_social_feed_panel.open_detail(0)
	else:
		_social_screen = "home"
		_social_detail_open = false
		if _social_feed_panel != null:
			_social_feed_panel.close_detail()
	_render()


func _on_social_follow_pressed(author_id: String) -> void:
	if _input_locked:
		return
	var followed := game.toggle_social_follow(author_id)
	var display_handle := _social_author_display(author_id)
	log_text = "已关注 @%s。" % display_handle if followed else "已取消关注 @%s。" % display_handle
	_render()


func _on_social_like_pressed(post_id: String) -> void:
	if _input_locked:
		return
	var liked := game.toggle_social_like(post_id)
	log_text = "已保存这条信号。" if liked else "已取消保存。"
	_render()


func _open_social_post(post_index: int) -> void:
	if _input_locked:
		return
	if _social_feed_panel != null:
		_social_feed_panel.open_detail(post_index)
	_social_detail_post_index = post_index
	_social_detail_open = true
	game.notify_tutorial("post_opened", {"post_index": post_index})
	_render()


func _render_notebook_app() -> void:
	_clear(_app_body)

	var notebook_page := VBoxContainer.new()
	notebook_page.name = "NotebookCraftPage"
	notebook_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_page.add_theme_constant_override("separation", 8)
	_app_body.add_child(notebook_page)

	var notebook_header := VBoxContainer.new()
	notebook_header.name = "NotebookSentenceHeader"
	notebook_header.add_theme_constant_override("separation", 3)
	notebook_page.add_child(notebook_header)
	notebook_header.add_child(_label("完整句子", 24, _theme_color("ink")))
	var header_hint := _label("从帖子拾取原词，再按语法位置组成手机世界会使用的句子。", 14, _theme_color("accent"))
	header_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_header.add_child(header_hint)
	var tab_rule := ColorRect.new()
	tab_rule.name = "NotebookSentenceRule"
	tab_rule.color = _theme_color("accent")
	tab_rule.custom_minimum_size.y = 3.0
	notebook_page.add_child(tab_rule)

	var notebook_scroll := ScrollContainer.new()
	notebook_scroll.name = "NotebookCraftScroll"
	notebook_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notebook_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	notebook_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	notebook_page.add_child(notebook_scroll)

	var notebook_content := VBoxContainer.new()
	notebook_content.name = "NotebookCraftContent"
	notebook_content.add_theme_constant_override("separation", 10)
	notebook_scroll.add_child(notebook_content)

	_render_notebook_frame_tab(notebook_content)

	var action_bar := _panel()
	action_bar.name = "NotebookCraftActionBar"
	action_bar.set_meta("fixed_action_bar", true)
	notebook_page.add_child(action_bar)
	var action_box := VBoxContainer.new()
	action_box.add_theme_constant_override("separation", 6)
	action_bar.add_child(action_box)
	var craft := Button.new()
	craft.name = "NotebookCraftButton"
	craft.text = "投稿这句话"
	craft.custom_minimum_size.y = 56
	craft.disabled = game.get_free_sentence_units().is_empty() or not game.can_spend_action()
	craft.pressed.connect(_on_composer_submit_pressed)
	action_box.add_child(craft)


func _render_notebook_frame_tab(notebook_content: VBoxContainer) -> void:
	_render_sentence_composer(notebook_content)



func _render_notebook_fusion_tab(notebook_content: VBoxContainer) -> void:
	notebook_content.add_child(_label("旧梗融合", 18, _theme_color("accent")))
	var fusion_hint := _label("用滚轮或双指滑动右侧梗环挑选完整梗，再拖入两个槽位；也可以点击梗后再点槽位。", 14, _theme_color("accent"))
	fusion_hint.name = "NotebookFusionRingHint"
	fusion_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(fusion_hint)
	var fusion_row := HBoxContainer.new()
	fusion_row.name = "NotebookFusionSlots"
	fusion_row.add_theme_constant_override("separation", 8)
	notebook_content.add_child(fusion_row)
	for fusion_slot_id in ["left", "right"]:
		var fusion_slot = DropButtonScript.new()
		fusion_slot.name = "FusionSlot%s" % fusion_slot_id.capitalize()
		fusion_slot.text = _fusion_slot_text(fusion_slot_id)
		fusion_slot.custom_minimum_size = Vector2(150, 58)
		fusion_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		fusion_slot.configure_drop_target("meme", fusion_slot_id)
		fusion_slot.dropped.connect(_on_fusion_meme_dropped)
		fusion_slot.pressed.connect(_on_fusion_slot_pressed.bind(fusion_slot_id))
		fusion_row.add_child(fusion_slot)
	var warning := _label("融合会保留两侧文字，并立即增加污染。发布前会显示资金与污染变化。", 14, _theme_color("accent"))
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(warning)


func _set_notebook_crafting_tab(tab_id: String) -> void:
	if _input_locked or tab_id not in ["frame", "fusion"]:
		return
	_notebook_crafting_tab = tab_id
	if tab_id == "fusion":
		_meme_bank_open = true
	_render()


func _render_publish() -> void:
	if _publish_blank == null or _confirm_publish_button == null:
		return
	var meme := _placed_meme()
	_publish_blank.text = "发布空格：%s" % (meme.get("title", "等待完整梗") if not meme.is_empty() else "等待完整梗")
	_confirm_publish_button.disabled = meme.is_empty() or not game.can_spend_action()


func _render_bank() -> void:
	if _meme_bank_tab != null:
		if _meme_bank_open:
			_meme_bank_tab.text = "×"
			_meme_bank_tab.set_meta("meme_bank_peek", false)
			_meme_bank_tab.custom_minimum_size = Vector2(88, 88)
		elif _should_show_meme_bank():
			_meme_bank_tab.text = "梗 %d" % game.completed_memes.size()
			_meme_bank_tab.set_meta("meme_bank_peek", false)
			_meme_bank_tab.custom_minimum_size = Vector2(104, 88)
		else:
			_meme_bank_tab.text = ""
			_meme_bank_tab.set_meta("meme_bank_peek", true)
			_meme_bank_tab.custom_minimum_size = Vector2.ZERO
	if _meme_bank_ring != null:
		_meme_bank_ring.set_palette(_theme_color("surface"), Color(_theme_color("muted"), 0.88), _theme_color("accent"))
	_clear(_bank_list)
	if game.completed_memes.is_empty():
		if _meme_bank_focus_label != null:
			_meme_bank_focus_label.text = "还没有完整梗。"
		return
	_meme_bank_selected_index = clampi(_meme_bank_selected_index, 0, game.completed_memes.size() - 1)
	if not selected_meme_id.is_empty():
		for index in game.completed_memes.size():
			if str(game.completed_memes[index].get("id", "")) == selected_meme_id:
				_meme_bank_selected_index = index
				break
	for index in game.completed_memes.size():
		var meme: Dictionary = game.completed_memes[index]
		var btn = DraggableButtonScript.new()
		btn.name = "MemeRingItem_%s" % str(meme.get("id", index))
		btn.set_meta("radial_meme_item", true)
		btn.set_meta("meme_index", index)
		btn.custom_minimum_size = Vector2(134, 54)
		btn.text = "%s\n%s" % [meme["title"], _corrupt(str(meme["text"]))]
		btn.set_drag_payload("meme", str(meme["id"]), str(meme["title"]))
		btn.pressed.connect(_on_meme_pressed.bind(str(meme["id"])))
		btn.gui_input.connect(_on_meme_ring_item_gui_input.bind(btn))
		_bank_list.add_child(btn)
	_meme_bank_ring.set_selected_index(_meme_bank_selected_index)
	_on_meme_ring_selection_changed(_meme_bank_selected_index)


func _on_meme_ring_selection_changed(index: int) -> void:
	if game == null or game.completed_memes.is_empty():
		return
	_meme_bank_selected_index = clampi(index, 0, game.completed_memes.size() - 1)
	var meme: Dictionary = game.completed_memes[_meme_bank_selected_index]
	selected_meme_id = str(meme.get("id", ""))
	if _meme_bank_focus_label != null:
		_meme_bank_focus_label.text = "%d/%d  ·  %s" % [_meme_bank_selected_index + 1, game.completed_memes.size(), str(meme.get("title", meme.get("text", "完整梗")))]
	_render_publish()


func _on_meme_ring_item_gui_input(event: InputEvent, source_button: Control) -> void:
	if _meme_bank_ring != null and _meme_bank_ring.handle_navigation_event(event):
		source_button.accept_event()


func _render_reality() -> void:
	if _reality_subtitle_label == null:
		return
	_clear(_reality_choice_row)
	_render_reality_language_composer()
	var plan := _day_plan()
	var actor_name := _active_actor_display_name()
	var npc_line: String = game.conversation_prompt if _reality_interaction_active and not game.conversation_prompt.is_empty() else str(plan["line"])
	var phase := str(game.conversation_phase)
	var subtitle := "%s：%s" % [actor_name, npc_line]
	if not game.conversation_feedback.is_empty():
		subtitle += "\n" + str(game.conversation_feedback)
	_set_dialogue_text(_reality_subtitle_label, subtitle)

	var choosing := _reality_interaction_active and phase == "choosing"
	var typing := _reality_interaction_active and phase == "typing"
	var result := _reality_interaction_active and phase == "result"
	_reality_choice_row.visible = choosing
	_reality_typing_line.visible = typing
	_reality_typing_progress.visible = typing
	_reality_continue_button.visible = _reality_interaction_active
	if result and game.conversation_can_continue:
		_reality_continue_button.text = "继续交谈"
	elif result:
		_reality_continue_button.text = "结束"
	else:
		_reality_continue_button.text = "离开"
	if result and game.conversation_actor_type == "doctor" and not game.last_polluted_sentence.is_empty():
		_set_dialogue_text(_reality_subtitle_label, "%s：%s\n你说：%s\n理解度：%d%%" % [
			actor_name,
			game.conversation_feedback,
			game.last_polluted_sentence,
			game.npc_understanding,
		])
	if choosing:
		for choice in game.get_typed_reality_choices():
			var choice_id := str(choice.get("id", ""))
			var button := Button.new()
			button.name = "RealityChoice%s" % choice_id.to_pascal_case()
			button.text = str(choice.get("summary", "回应"))
			if _playtest_assist_enabled and game.conversation_actor_type == "key_npc" and bool(choice.get("correct", false)):
				button.text = "✓ TEST  %s" % button.text
			button.custom_minimum_size = Vector2(96 if _viewport_size().x < 760.0 else 164, 56)
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.clip_text = true
			button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			if _viewport_size().x < 760.0:
				button.add_theme_font_size_override("font_size", _ui_font_size(13))
			button.set_meta("reality_response_choice", true)
			button.disabled = bool(choice.get("locked", false))
			if button.disabled:
				button.tooltip_text = "这部分还听不清。"
			button.mouse_entered.connect(_on_reality_choice_hovered.bind(choice_id))
			button.mouse_exited.connect(_on_reality_choice_unhovered.bind(choice_id))
			if not button.disabled:
				button.pressed.connect(_on_reality_choice_selected.bind(choice_id))
			_reality_choice_row.add_child(button)
		if _reality_hover_choice_id.is_empty():
			_set_dialogue_text(_reality_intent_preview, "")
		else:
			_set_dialogue_text(_reality_intent_preview, game.preview_typed_reality_choice(_reality_hover_choice_id))
	_reality_intent_preview.visible = choosing and not _reality_hover_choice_id.is_empty()

	if typing:
		_set_richer_bbcode(_reality_typing_line, _typed_reality_bbcode())
		_reality_typing_progress.text = "任意键  %d / %d" % [game.conversation_reveal_index, game.get_typed_reality_unit_count()]
	else:
		_set_richer_bbcode(_reality_typing_line, "")
		_reality_typing_progress.text = ""


func _render_reality_language_composer() -> void:
	if _reality_language_frame == null or _reality_language_token_flow == null or _reality_language_slot_row == null:
		return
	_clear(_reality_language_token_flow)
	_clear(_reality_language_slot_row)
	var composing := _reality_interaction_active and game.conversation_phase == "composing" and game.conversation_mode == "lexeme"
	_reality_language_frame.visible = composing
	if not composing:
		return

	var options: Array = game.get_language_token_options("doctor")
	if options.is_empty():
		var empty_label := _label("还没有能带到医生面前的词。先在手机里发布一句完整的话。", 14, _theme_color("accent"))
		empty_label.name = "RealityLanguageEmptyState"
		empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_reality_language_token_flow.add_child(empty_label)
	for option_value in options:
		var option: Dictionary = option_value as Dictionary
		var token_id := str(option.get("id", ""))
		var button = DraggableButtonScript.new()
		button.name = "RealityLanguageToken_%s" % token_id
		button.text = str(option.get("display_text", option.get("text", "")))
		button.tooltip_text = "原词：%s\n手机里：%s" % [
			str(option.get("text", "")),
			str(option.get("phone_surface", option.get("text", ""))),
		]
		button.custom_minimum_size = Vector2(128.0, 48.0)
		button.clip_text = true
		button.set_drag_payload("language_token", token_id, button.text)
		button.pressed.connect(_on_language_token_pressed.bind(token_id))
		_reality_language_token_flow.add_child(button)

	for slot_value in game.get_craft_slots():
		var slot: Dictionary = slot_value as Dictionary
		var slot_id := str(slot.get("id", ""))
		var drop_slot = DropButtonScript.new()
		drop_slot.name = "RealityLanguageSlot%s" % slot_id.capitalize()
		drop_slot.text = "%s\n%s" % [
			str(slot.get("label", slot_id)),
			_language_slot_text(slot_id, str(slot.get("placeholder", "等待词语")), "doctor"),
		]
		drop_slot.custom_minimum_size = Vector2(150.0, 62.0)
		drop_slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drop_slot.configure_drop_target("language_token", slot_id)
		drop_slot.dropped.connect(_on_language_token_dropped)
		drop_slot.pressed.connect(_on_language_slot_pressed.bind(slot_id))
		_reality_language_slot_row.add_child(drop_slot)

	var preview: Dictionary = game.get_language_sentence_preview("doctor")
	if bool(preview.get("valid", false)):
		_reality_language_preview.text = "原句：%s\n医生语言：%s" % [
			str(preview.get("clean_sentence", "")),
			str(preview.get("world_sentence", "")),
		]
	else:
		_reality_language_preview.text = "句子尚未完整。需要对象、动作和去向。"
	_reality_language_confirm.disabled = not bool(preview.get("valid", false)) or not game.can_spend_action()


func _typed_reality_bbcode() -> String:
	var normal_color := _theme_color("surface").to_html(false)
	var pending_color := Color("777B72").to_html(false)
	var corrupted_color := Color("FF3B30").to_html(false)
	var parts: Array[String] = []
	for unit in game.conversation_revealed_units:
		var color := corrupted_color if bool(unit.get("corrupted", false)) else normal_color
		var display := _escape_bbcode(str(unit.get("display", "")))
		if bool(unit.get("corrupted", false)):
			parts.append("[color=#%s][cuss]%s[][]" % [color, display])
		else:
			parts.append("[color=#%s]%s[]" % [color, display])
	var suffix := game.get_typed_reality_unrevealed_suffix()
	if not suffix.is_empty():
		parts.append("[color=#%s]%s[]" % [pending_color, _escape_bbcode(suffix)])
	return "[curspull pull=0.18]%s[]" % "".join(parts)


func _set_dialogue_text(label: RichTextLabel, value: String) -> void:
	if value.is_empty():
		_set_richer_bbcode(label, "")
		return
	_set_richer_bbcode(label, "[curspull pull=0.12]%s[]" % _escape_bbcode(_locale.translate(value)))


func _set_richer_bbcode(label: RichTextLabel, value: String) -> void:
	label.call("set_bbcode", value)


func _install_rich_text_effect(label: RichTextLabel, effect_name: String) -> void:
	label.call("_install_effect", effect_name)


func _escape_bbcode(value: String) -> String:
	# 先把左括号替换成不含括号的哨兵,避免替换级联("[" 变成 "[lb[rb]")。
	var sentinel := String.chr(1)
	return value.replace("[", sentinel).replace("]", "[rb]").replace(sentinel, "[lb]")


func _on_reality_choice_hovered(choice_id: String) -> void:
	_reality_hover_choice_id = choice_id
	if _reality_intent_preview != null:
		var preview := game.preview_typed_reality_choice(choice_id)
		_set_dialogue_text(_reality_intent_preview, preview)
		_reality_intent_preview.visible = not preview.is_empty()


func _on_reality_choice_unhovered(choice_id: String) -> void:
	if _reality_hover_choice_id != choice_id:
		return
	_reality_hover_choice_id = ""
	if _reality_intent_preview != null:
		_set_dialogue_text(_reality_intent_preview, "")
		_reality_intent_preview.visible = false


func _on_reality_choice_selected(choice_id: String) -> void:
	if _input_locked:
		return
	if game.select_typed_reality_choice(choice_id):
		_reality_hover_choice_id = ""
		_render()
		_sync_audio_state(false)


func _on_reality_continue_pressed() -> void:
	if _input_locked:
		return
	if game.conversation_phase == "result" and game.continue_typed_reality_conversation():
		_localize_active_conversation()
		_reality_hover_choice_id = ""
		_render()
		_sync_audio_state(false)
		return
	_exit_reality_interaction()


func _advance_typed_reality_character() -> bool:
	if _input_locked or not _reality_interaction_active:
		return false
	var actions_before := int(game.actions_remaining)
	var result: Dictionary = game.advance_typed_reality_character()
	if not bool(result.get("advanced", false)):
		return false
	if bool(result.get("locked_out", false)):
		_reality_interaction_active = false
		_active_reality_actor = null
		_nearby_reality_actor = null
		_nearby_reality_item = null
		_set_reality_mouse_look(true)
	if bool(result.get("action_spent", false)):
		_after_effective_action(actions_before)
	else:
		_render()
	if game.conversation_actor_type == "doll" and _reality_floor != null:
		_reality_floor.sync_claimed_dolls(game.claimed_doll_ids)
	return true


func _update_visibility() -> void:
	var in_phone: bool = game.view_state == "phone_down"
	# 手机始终留在画面上:打开 App 只是弹出对应窗口,不会让手机消失。
	var show_phone_home := in_phone
	if _phone_popup_expanded != show_phone_home:
		_phone_popup_expanded = show_phone_home
		_apply_phone_popup_layout(show_phone_home)
	_phone_panel.visible = _game_started and show_phone_home
	if _phone_tab != null:
		_phone_tab.visible = false
	_phone_content.visible = show_phone_home
	if in_phone and not game.active_app_window.is_empty():
		_open_app_windows[game.active_app_window] = true
	for app_id in _app_windows.keys():
		var app_window := _app_windows[app_id] as Control
		if app_window != null:
			app_window.visible = in_phone and bool(_open_app_windows.get(app_id, false))
	if _social_feed_panel != null:
		_social_feed_panel.update_visibility(in_phone, bool(_open_app_windows.get("social", false)))
	if _publish_panel != null:
		_publish_panel.visible = false
	var show_meme_bank := _should_show_meme_bank()
	var peek_meme_bank := _should_peek_meme_bank()
	_meme_bank_window.visible = show_meme_bank or peek_meme_bank
	if not show_meme_bank:
		_meme_bank_open = false
	var desired_bank_layout := "open" if _meme_bank_open else ("collapsed" if show_meme_bank else "peek")
	if _meme_bank_layout_mode != desired_bank_layout:
		_meme_bank_layout_mode = desired_bank_layout
		_apply_meme_bank_popup_layout(desired_bank_layout)
	if _meme_bank_content != null:
		_meme_bank_content.visible = show_meme_bank and _meme_bank_open
	if _meme_bank_ring != null:
		_meme_bank_ring.visible = show_meme_bank and _meme_bank_open
	if _meme_bank_drag_handle != null:
		_meme_bank_drag_handle.visible = show_meme_bank and _meme_bank_open
	_avoid_meme_bank_overlaps()
	if _phone_down_backdrop_image != null:
		_phone_down_backdrop_image.visible = in_phone or _phone_art_alpha > 0.03
	if _hand_phone_image != null:
		_hand_phone_image.visible = in_phone or _phone_art_alpha > 0.03
	if _hand_xray_overlay != null:
		_hand_xray_overlay.visible = _camera_enabled and _game_started and not in_phone
	if _view_toggle_button != null:
		_view_toggle_button.visible = _game_started and not _settings_is_open() and (in_phone or not _reality_interaction_active)
		_view_toggle_button.text = "放下手机" if in_phone else "拿起手机"
	if _settings_window != null:
		_settings_window.visible = _settings_is_open() and _game_started
	if _desk_log != null:
		_desk_log.visible = in_phone
	if _vhs_overlay != null:
		_vhs_overlay.visible = _vhs_enabled and _game_started
	if _world_prompt != null:
		_world_prompt.visible = (not in_phone) and (not _reality_interaction_active) and (_nearby_reality_actor != null or _nearby_reality_item != null)
	var interaction_visible := (not in_phone) and _reality_interaction_active
	if _reality_subtitle_panel != null:
		_reality_subtitle_panel.visible = interaction_visible
	if _reality_choice_row != null:
		_reality_choice_row.visible = interaction_visible and game.conversation_phase == "choosing"
	if _reality_intent_preview != null:
		_reality_intent_preview.visible = interaction_visible and game.conversation_phase == "choosing" and not _reality_hover_choice_id.is_empty()
	if _reality_typing_line != null:
		_reality_typing_line.visible = interaction_visible and game.conversation_phase == "typing"
	if _reality_typing_progress != null:
		_reality_typing_progress.visible = interaction_visible and game.conversation_phase == "typing"
	if _reality_language_frame != null:
		_reality_language_frame.visible = interaction_visible and game.conversation_phase == "composing" and game.conversation_mode == "lexeme"
	if _playtest_assist_panel != null:
		# 可见性判定与 _render_playtest_assist 保持同一公式:引导台词由玩偶小窗独占,
		# 本面板只在测试辅助开启、或(教程未完成且玩偶窗缺席)时出现。
		var tutorial_step: Dictionary = game.get_tutorial_step()
		_playtest_assist_panel.visible = _game_started and not _settings_is_open() and _playtest_assist_enabled
	if _reality_floor != null:
		_reality_floor.visible = not in_phone
	if _reality_player != null:
		_reality_player.visible = not in_phone
	if _npc != null:
		_npc.visible = false
	if _phone_rig != null:
		_phone_rig.visible = false
	if _cinematic_bars != null:
		_cinematic_bars.set_bars_visible(_game_started and not in_phone)
	_layout_hud_rail()


func _animate_world(delta: float) -> void:
	if not _game_started:
		if _camera != null:
			_camera.position = _camera.position.lerp(Vector3(0.0, 1.54, 2.55), minf(1.0, delta * 3.0))
			_camera.rotation_degrees = _camera.rotation_degrees.lerp(Vector3(-18.0, 0.0, 0.0), minf(1.0, delta * 3.0))
		_animate_vhs(delta)
		return
	var phone_target := Vector3(0.0, 0.15, -1.15) if game.view_state == "phone_down" else Vector3(1.45, -0.8, -1.0)
	var camera_target_pos := Vector3(0.0, 1.45, 2.2)
	var camera_target_rot := Vector3(-54.0, 0.0, 0.0)
	if game.view_state == "npc_up" and _reality_player != null:
		camera_target_pos = _reality_player.position + Vector3(0.0, 1.56, 0.0)
		camera_target_rot = Vector3(_reality_pitch, _reality_yaw, 0.0)
	var camera_lerp := minf(1.0, delta * (7.0 if game.view_state == "npc_up" else 5.0))
	_camera.position = _camera.position.lerp(camera_target_pos, camera_lerp)
	var current_rotation := _camera.rotation_degrees
	current_rotation.x = lerpf(current_rotation.x, camera_target_rot.x, camera_lerp)
	current_rotation.y = rad_to_deg(lerp_angle(deg_to_rad(current_rotation.y), deg_to_rad(camera_target_rot.y), camera_lerp))
	current_rotation.z = lerpf(current_rotation.z, 0.0, camera_lerp)
	_camera.rotation_degrees = current_rotation
	_camera.fov = 58.0
	if _phone_rig != null:
		_phone_rig.position = _phone_rig.position.lerp(phone_target, minf(1.0, delta * 6.0))
		_phone_rig.rotation_degrees = Vector3(68.0, 0.0, 0.0)
	var target_alpha := 1.0 if game.view_state == "phone_down" else 0.0
	_phone_art_alpha = lerpf(_phone_art_alpha, target_alpha, minf(1.0, delta * 3.4))
	_road_scroll += delta * 1.4
	if _phone_down_backdrop_image != null:
		_phone_down_backdrop_image.visible = game.view_state == "phone_down" or _phone_art_alpha > 0.03
		_phone_down_backdrop_image.modulate.a = _phone_art_alpha
		var viewport_size := _viewport_size()
		var bob := sin(_road_scroll * 2.2) * 2.4
		var sway := sin(_road_scroll * 1.1) * 1.1
		_phone_down_backdrop_image.pivot_offset = viewport_size * 0.5
		_phone_down_backdrop_image.scale = Vector2(1.012, 1.012)
		var settled_position := Vector2(-viewport_size.x * 0.006 + sway, -viewport_size.y * 0.006 + bob)
		_phone_down_backdrop_image.position = Vector2(settled_position.x, lerpf(70.0, settled_position.y, _phone_art_alpha))
	if _road != null:
		for index in _road.get_child_count():
			var tile := _road.get_child(index) as Node3D
			tile.position.z = -2.0 - index * 3.8 + fmod(_road_scroll, 3.8)
	if game.view_state == "npc_up" and _reality_floor != null and _reality_player != null:
		_reality_floor.update_authored_events(delta, _reality_player.global_position, -_camera.global_basis.z)
	_animate_vhs(delta)


func _animate_vhs(delta: float) -> void:
	if _vhs_overlay == null or not _vhs_enabled:
		return
	_vhs_overlay.modulate.a = 1.0
	if _vhs_shader_rect != null and _vhs_shader_rect.material is ShaderMaterial:
		var material := _vhs_shader_rect.material as ShaderMaterial
		material.set_shader_parameter("pollution", clampf(float(game.pollution) / 100.0, 0.0, 1.0))
		material.set_shader_parameter("intensity", 0.58 + minf(0.22, float(game.pollution) * 0.0022))


func _active_palette() -> Dictionary:
	if game != null and game.pollution >= MemeGameStateScript.POLLUTION_FLASHBACK_THRESHOLD:
		return POLLUTION_PALETTE_5
	return PALETTE_1


func _theme_color(key: String) -> Color:
	var palette := _active_palette()
	return Color(str(palette.get(key, PALETTE_1.get(key, "FFF1C9"))))


func _viewport_size() -> Vector2:
	if get_viewport() != null:
		return get_viewport().get_visible_rect().size
	return Vector2(
		float(ProjectSettings.get_setting("display/window/size/viewport_width", 1600)),
		float(ProjectSettings.get_setting("display/window/size/viewport_height", 900))
	)


func _load_runtime_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var image := Image.new()
	if FileAccess.file_exists(path):
		var bytes := FileAccess.get_file_as_bytes(path)
		var err := image.load_png_from_buffer(bytes)
		if err != OK:
			err = image.load_jpg_from_buffer(bytes)
		if err != OK:
			err = image.load_webp_from_buffer(bytes)
		if err != OK:
			return null
		var texture := ImageTexture.create_from_image(image)
		_texture_cache[path] = texture
		return texture
	if FileAccess.file_exists("%s.import" % path):
		var resource := load(path)
		if resource is Texture2D:
			_texture_cache[path] = resource
			return resource
	return null


func _social_poster_texture_path(post_index: int) -> String:
	return SOCIAL_POSTER_SHEET_PATH


func _social_poster_texture(post_index: int) -> Texture2D:
	var cell_index := posmod(post_index, SOCIAL_POSTER_COUNT)
	var cache_key := "%s#cell-%d" % [SOCIAL_POSTER_SHEET_PATH, cell_index]
	if _texture_cache.has(cache_key):
		return _texture_cache[cache_key]
	var sheet := _load_runtime_texture(SOCIAL_POSTER_SHEET_PATH)
	if sheet == null:
		return null
	var cell_size := Vector2(
		floorf(float(sheet.get_width()) / SOCIAL_POSTER_COLUMNS),
		floorf(float(sheet.get_height()) / SOCIAL_POSTER_ROWS)
	)
	var atlas := AtlasTexture.new()
	atlas.atlas = sheet
	var row := floori(float(cell_index) / SOCIAL_POSTER_COLUMNS)
	atlas.region = Rect2(
		Vector2(cell_index % SOCIAL_POSTER_COLUMNS, row) * cell_size,
		cell_size
	)
	_texture_cache[cache_key] = atlas
	return atlas


func _social_post_for_index(post_index: int) -> Dictionary:
	if SOCIAL_POST_CARDS.is_empty():
		return {}
	var day_offset := 0 if game == null else maxi(0, game.day - 1) * 3
	var card_index := posmod(post_index + day_offset, SOCIAL_POST_CARDS.size())
	var post: Dictionary = (SOCIAL_POST_CARDS[card_index] as Dictionary).duplicate(true)
	post["card_index"] = card_index
	var candidate_tokens: Array = []
	for token_data in post.get("tokens", []):
		var token: Dictionary = (token_data as Dictionary).duplicate(true)
		var source_text := str(token.get("text", ""))
		token["text"] = _locale.translate(source_text)
		token["source_text"] = source_text
		token["content_locale"] = _locale.current_locale
		token["source_card_id"] = str(post.get("id", ""))
		token["lexeme_id"] = str(token.get("lexeme_id", "%s.%s" % [post.get("id", "post"), token.get("id", "token")]))
		for surface_field in ["phone_surface", "doctor_surface", "doll_surface"]:
			token[surface_field] = _locale.translate(str(token.get(surface_field, source_text)))
		candidate_tokens.append(token)
	var prepared_tokens: Array = []
	var current_day := 1 if game == null else game.day
	var pickup_indices := _social_pickup_post_indices(current_day)
	if post_index in pickup_indices and not candidate_tokens.is_empty():
		prepared_tokens = candidate_tokens.duplicate(true)
	post["tokens"] = prepared_tokens
	post["pickup_available"] = not prepared_tokens.is_empty()
	return post


func _social_author_id(post: Dictionary) -> String:
	return str(post.get("id", post.get("handle", "unknown-author")))


func _social_author_display(author_id: String) -> String:
	for post in SOCIAL_POST_CARDS:
		if str(post.get("id", "")) == author_id:
			return _locale.translate(str(post.get("handle", author_id)))
	return author_id


func _social_pickable_units(text: String) -> Array[String]:
	return _locale.pickable_units(text)


func _social_pickup_post_indices(day_number: int) -> Array[int]:
	var indices: Array[int] = []
	if SOCIAL_POST_CARDS.is_empty():
		return indices
	var pickup_post_count := mini(SOCIAL_POST_CARDS.size(), 2 + posmod(maxi(1, day_number) - 1, 4))
	var start_index := posmod((maxi(1, day_number) - 1) * 5, SOCIAL_POST_CARDS.size())
	for offset in pickup_post_count:
		indices.append(posmod(start_index + offset * 5, SOCIAL_POST_CARDS.size()))
	return indices


func _is_pickable_social_character(character: String) -> bool:
	return not character.is_empty() and not " \t\r\n，。！？；：、,.!?;:（）()【】[]《》<>“”\"'—-…".contains(character)


func _toggle_meme_bank() -> void:
	if _input_locked:
		return
	if not _should_show_meme_bank():
		log_text = "梗仓库只在发布页或笔记本中出现。"
		_render_status()
		return
	_meme_bank_open = not _meme_bank_open
	if _meme_bank_open and _meme_bank_window != null:
		_meme_bank_window.move_to_front()
	_render()
	_play_meme_bank_motion(_meme_bank_open)


func _play_meme_bank_motion(opening: bool) -> void:
	if _meme_bank_window == null or not _meme_bank_window.visible:
		return
	var profile := _meme_bank_motion_profile(opening)
	if _meme_bank_tween != null and _meme_bank_tween.is_valid():
		_meme_bank_tween.kill()
	_meme_bank_window.pivot_offset = _meme_bank_window.size * 0.5
	_meme_bank_window.scale = profile["start_scale"]
	_meme_bank_window.modulate = Color(1.0, 1.0, 1.0, float(profile["start_alpha"]))
	_meme_bank_window.set_meta("motion_easing", "easeOutQuint")
	_meme_bank_window.set_meta("motion_phase", profile["phase"])
	_meme_bank_window.set_meta("motion_transition", profile["transition"])
	_meme_bank_window.set_meta("motion_ease", profile["ease"])
	var motion_tween := create_tween().set_parallel(true)
	_meme_bank_tween = motion_tween
	motion_tween.tween_property(_meme_bank_window, "scale", profile["target_scale"], float(profile["scale_duration"])) \
		.set_trans(int(profile["transition"])).set_ease(int(profile["ease"]))
	motion_tween.tween_property(_meme_bank_window, "modulate", Color(1.0, 1.0, 1.0, float(profile["target_alpha"])), float(profile["alpha_duration"])) \
		.set_trans(int(profile["transition"])).set_ease(int(profile["ease"]))
	motion_tween.finished.connect(_finish_meme_bank_motion.bind(opening, motion_tween), CONNECT_ONE_SHOT)


func _finish_meme_bank_motion(opening: bool, completed_tween: Tween) -> void:
	if completed_tween != _meme_bank_tween or _meme_bank_window == null:
		return
	_meme_bank_window.scale = Vector2.ONE
	_meme_bank_window.modulate.a = 1.0
	_meme_bank_window.set_meta("motion_phase", "open" if opening else "closed")


func _meme_bank_motion_profile(opening: bool) -> Dictionary:
	return {
		"phase": "opening" if opening else "closing",
		"transition": MEME_BANK_MOTION_TRANSITION,
		"ease": MEME_BANK_MOTION_EASE,
		"scale_duration": MEME_BANK_SCALE_DURATION,
		"alpha_duration": MEME_BANK_ALPHA_DURATION,
		"start_scale": Vector2.ONE * (0.84 if opening else 1.10),
		"start_alpha": 0.18 if opening else 0.72,
		"target_scale": Vector2.ONE,
		"target_alpha": 1.0,
		"properties": ["scale", "modulate:a"],
		"interrupts_previous": true,
	}


func _close_app_window(app_id: String) -> void:
	if _input_locked:
		return
	_open_app_windows[app_id] = false
	if app_id == "social":
		_social_detail_open = false
		if _social_feed_panel != null:
			_social_feed_panel.close_detail()
	if game.active_app_window == app_id:
		game.active_app_window = ""
		for candidate in ["social", "babel", "notebook"]:
			if bool(_open_app_windows.get(candidate, false)):
				game.active_app = candidate
				game.active_app_window = candidate
				break
	var any_open := false
	for open_value in _open_app_windows.values():
		if bool(open_value):
			any_open = true
			break
	_phone_launcher_open = not any_open
	log_text = "关闭 %s 窗口。" % app_id
	_render()


func _open_phone_launcher() -> void:
	if _input_locked:
		return
	game.set_view_state("phone_down")
	_set_reality_mouse_look(false)
	_phone_launcher_open = true
	if _phone_panel != null:
		_phone_panel.move_to_front()
	log_text = "展开手机主页。"
	_render()


func _close_social_detail_window() -> void:
	if _input_locked:
		return
	if _social_feed_panel != null:
		_social_feed_panel.close_detail()
	_social_detail_open = false
	if _social_channel == "tower_base":
		_social_channel = "discover"
	log_text = "关闭社交详情。"
	_render()


func _ensure_window_manager() -> void:
	if _window_manager != null:
		return
	_window_manager = DraggableWindowManagerScript.new()
	_window_manager.name = "DraggableWindowManager"
	add_child(_window_manager)
	_window_manager.set_clamp_bounds(
		-1.0e6,
		DraggableWindowManager.DEFAULT_VISIBLE_EDGE,
		DraggableWindowManager.DEFAULT_BOTTOM_INSET
	)
	_sync_window_manager_enabled()
	_window_manager.window_drag_released.connect(_on_window_drag_released)


func _sync_window_manager_enabled() -> void:
	if _window_manager != null:
		_window_manager.enabled = not _input_locked
	_sync_edge_drawer_enabled()


func _on_window_drag_released(window_id: String) -> void:
	if window_id == "bank":
		_avoid_meme_bank_overlaps()


func _move_window_for_test(window_id: String, delta: Vector2) -> bool:
	_ensure_window_manager()
	return _window_manager.move_window(window_id, delta)


func _window_position_for_test(window_id: String) -> Vector2:
	_ensure_window_manager()
	return _window_manager.get_window_position(window_id)


func _make_draggable_window(window: Control, window_id: String, handle: Control) -> void:
	_ensure_window_manager()
	_window_manager.register(window, window_id, handle)


func _should_show_meme_bank() -> bool:
	# 梗圆环已退役:造句改用笔记本画布 + 发布页拖放,不再需要环形选择器。
	return false


func _should_peek_meme_bank() -> bool:
	return false


func _avoid_meme_bank_overlaps() -> void:
	if _meme_bank_window == null or not _meme_bank_window.visible:
		return
	# The ring deliberately owns the right edge; preserving that anchor makes
	# scroll navigation spatially predictable even when the notebook moves.
	if _meme_bank_ring != null:
		return
	var targets := _meme_bank_overlap_targets()
	if not _meme_bank_conflicts_at(_meme_bank_window.global_position, targets):
		return
	var bank_rect := _meme_bank_window.get_global_rect()
	var viewport_size := _viewport_size()
	var margin := 12.0
	var min_x := margin
	if _hud_panel != null and _hud_panel.visible:
		min_x = maxf(min_x, _hud_panel.get_global_rect().end.x + margin)
	var max_x := maxf(min_x, viewport_size.x - bank_rect.size.x - margin)
	var max_y := maxf(margin, viewport_size.y - bank_rect.size.y - margin)
	var current := _meme_bank_window.global_position
	var candidates: Array[Vector2] = []
	for target in targets:
		if target == null or not target.is_visible_in_tree():
			continue
		var target_rect := target.get_global_rect()
		if not Rect2(current, bank_rect.size).intersects(target_rect):
			continue
		candidates.append(Vector2(target_rect.position.x - bank_rect.size.x - margin, current.y))
		candidates.append(Vector2(target_rect.end.x + margin, current.y))
		candidates.append(Vector2(current.x, target_rect.position.y - bank_rect.size.y - margin))
		candidates.append(Vector2(current.x, target_rect.end.y + margin))
	candidates.append(Vector2(min_x, current.y))
	candidates.append(Vector2(max_x, current.y))
	for candidate in candidates:
		var clamped := Vector2(
			clampf(candidate.x, min_x, max_x),
			clampf(candidate.y, margin, max_y)
		)
		if not _meme_bank_conflicts_at(clamped, targets):
			_meme_bank_window.global_position = clamped
			return


func _meme_bank_overlap_targets() -> Array[Control]:
	var targets: Array[Control] = []
	for app_id in _app_windows.keys():
		var app_window := _app_windows[app_id] as Control
		if app_window != null and app_window.is_visible_in_tree():
			targets.append(app_window)
	if _view_toggle_button != null and _view_toggle_button.is_visible_in_tree():
		targets.append(_view_toggle_button)
	if _hud_actions_label != null and _hud_actions_label.is_visible_in_tree():
		targets.append(_hud_actions_label)
	for node_name in ["SocialBottomNav", "SocialHomeIndicator"]:
		var social_control := _find_control_by_name(_ui_root, node_name)
		if social_control != null and social_control.is_visible_in_tree():
			targets.append(social_control)
	return targets


func _find_control_by_name(node: Node, node_name: String) -> Control:
	if node == null:
		return null
	if node.name == node_name and node is Control:
		return node as Control
	for child in node.get_children():
		var found := _find_control_by_name(child, node_name)
		if found != null:
			return found
	return null


func _meme_bank_conflicts_at(position: Vector2, targets: Array[Control]) -> bool:
	if _meme_bank_window == null:
		return false
	var rect := Rect2(position, _meme_bank_window.get_global_rect().size)
	for target in targets:
		if target == null or not target.is_visible_in_tree():
			continue
		if rect.intersects(target.get_global_rect()):
			return true
	return false


func _apply_world_theme() -> void:
	if _reality_floor != null:
		_reality_floor.apply_palette(_active_palette())
	if _road != null:
		for index in _road.get_child_count():
			var tile := _road.get_child(index) as MeshInstance3D
			if tile == null:
				continue
			var mat := tile.material_override as StandardMaterial3D
			if mat != null:
				mat.albedo_color = Color.WHITE if mat.albedo_texture != null else _theme_color("accent").darkened(0.50 - index * 0.08)
	if _phone_rig != null:
		var phone_body := _phone_rig.get_node_or_null("PhoneBody") as MeshInstance3D
		if phone_body != null and phone_body.material_override is StandardMaterial3D:
			(phone_body.material_override as StandardMaterial3D).albedo_color = _theme_color("accent")
		var phone_screen := _phone_rig.get_node_or_null("PhoneScreen") as MeshInstance3D
		if phone_screen != null and phone_screen.material_override is StandardMaterial3D:
			var mat := phone_screen.material_override as StandardMaterial3D
			mat.albedo_color = _theme_color("ink")
			mat.emission = _theme_color("accent")
	if _npc != null:
		var npc_body := _npc.get_node_or_null("NPCPlane") as MeshInstance3D
		if npc_body != null and npc_body.material_override is StandardMaterial3D:
			var mat := npc_body.material_override as StandardMaterial3D
			mat.albedo_color = Color.WHITE if mat.albedo_texture != null else _theme_color("surface")
			mat.emission = _theme_color("muted")
func _apply_ui_theme(node: Node = null) -> void:
	if node == null:
		node = _ui_root
	if node == null:
		return
	if node is Label and not node.has_meta("flashback_text") and not node.has_meta("action_overlay_text"):
		if node.has_meta("hud_action_label"):
			(node as Label).add_theme_color_override("font_color", _theme_color("muted"))
		elif node.has_meta("on_dark"):
			(node as Label).add_theme_color_override("font_color", _theme_color("surface"))
		else:
			(node as Label).add_theme_color_override("font_color", _theme_color("ink"))
	elif node is Button:
		var button := node as Button
		if button.has_meta("hud_icon"):
			var empty := StyleBoxEmpty.new()
			button.add_theme_stylebox_override("normal", empty)
			button.add_theme_stylebox_override("hover", _style(Color(_theme_color("muted"), 0.18), Color(_theme_color("muted"), 0.20)))
			button.add_theme_stylebox_override("pressed", _style(Color(_theme_color("muted"), 0.32), Color(_theme_color("muted"), 0.32)))
		elif button.has_meta("phone_app_icon"):
			button.add_theme_color_override("font_color", _theme_color("surface"))
			button.add_theme_color_override("font_hover_color", _theme_color("ink"))
			button.add_theme_color_override("font_pressed_color", _theme_color("ink"))
			button.add_theme_font_size_override("font_size", _ui_font_size(18))
			button.add_theme_stylebox_override("normal", _launcher_app_style(_theme_color("ink"), _theme_color("muted")))
			button.add_theme_stylebox_override("hover", _launcher_app_style(_theme_color("muted"), _theme_color("ink")))
			button.add_theme_stylebox_override("pressed", _launcher_app_style(_theme_color("bg"), _theme_color("ink")))
		elif button.has_meta("dark_window_close_button"):
			button.add_theme_color_override("font_color", _theme_color("surface"))
			button.add_theme_color_override("font_hover_color", _theme_color("ink"))
			button.add_theme_color_override("font_pressed_color", _theme_color("ink"))
			button.add_theme_stylebox_override("normal", _window_close_style(Color(_theme_color("ink"), 0.0), _theme_color("muted")))
			button.add_theme_stylebox_override("hover", _window_close_style(_theme_color("muted"), _theme_color("surface")))
			button.add_theme_stylebox_override("pressed", _window_close_style(_theme_color("surface"), _theme_color("surface")))
		elif button.has_meta("window_close_button"):
			button.add_theme_color_override("font_color", _theme_color("ink"))
			button.add_theme_color_override("font_hover_color", _theme_color("surface"))
			button.add_theme_color_override("font_pressed_color", _theme_color("surface"))
			button.add_theme_stylebox_override("normal", _window_close_style(Color(_theme_color("surface"), 0.0), _theme_color("accent")))
			button.add_theme_stylebox_override("hover", _window_close_style(_theme_color("ink"), _theme_color("ink")))
			button.add_theme_stylebox_override("pressed", _window_close_style(_theme_color("accent"), _theme_color("ink")))
		elif button.has_meta("notebook_browser_tab"):
			var tab_active := bool(button.get_meta("active_tab", false))
			button.add_theme_color_override("font_color", _theme_color("surface") if tab_active else _theme_color("ink"))
			button.add_theme_color_override("font_hover_color", _theme_color("ink"))
			button.add_theme_stylebox_override("normal", _style(_theme_color("ink") if tab_active else Color(_theme_color("surface"), 0.72), _theme_color("accent")))
			button.add_theme_stylebox_override("hover", _style(_theme_color("muted"), _theme_color("ink")))
			button.add_theme_stylebox_override("pressed", _style(_theme_color("accent"), _theme_color("ink")))
		elif button.has_meta("radial_center_button"):
			button.add_theme_color_override("font_color", _theme_color("surface"))
			button.add_theme_color_override("font_hover_color", _theme_color("ink"))
			button.add_theme_stylebox_override("normal", _circle_style(Color(_theme_color("ink"), 0.92), _theme_color("muted")))
			button.add_theme_stylebox_override("hover", _circle_style(_theme_color("muted"), _theme_color("ink")))
			button.add_theme_stylebox_override("pressed", _circle_style(_theme_color("accent"), _theme_color("surface")))
		elif button.has_meta("meme_bank_tab") and bool(button.get_meta("meme_bank_peek", false)):
			button.add_theme_color_override("font_color", _theme_color("muted"))
			button.add_theme_color_override("font_hover_color", _theme_color("surface"))
			button.add_theme_color_override("font_pressed_color", _theme_color("surface"))
			button.add_theme_stylebox_override("normal", _file_corner_style(Color(_theme_color("ink"), 0.72), Color(_theme_color("muted"), 0.28)))
			button.add_theme_stylebox_override("hover", _file_corner_style(Color(_theme_color("ink"), 0.88), Color(_theme_color("muted"), 0.46)))
			button.add_theme_stylebox_override("pressed", _file_corner_style(_theme_color("ink"), _theme_color("muted")))
		elif button.has_meta("meme_bank_tab") and not _meme_bank_open:
			button.add_theme_color_override("font_color", _theme_color("muted"))
			button.add_theme_color_override("font_hover_color", _theme_color("surface"))
			button.add_theme_color_override("font_pressed_color", _theme_color("surface"))
			button.add_theme_stylebox_override("normal", _style(Color(_theme_color("ink"), 0.78), Color(_theme_color("muted"), 0.24)))
			button.add_theme_stylebox_override("hover", _style(Color(_theme_color("ink"), 0.92), Color(_theme_color("muted"), 0.42)))
			button.add_theme_stylebox_override("pressed", _style(_theme_color("ink"), _theme_color("muted")))
		elif button.has_meta("flat_phone_button"):
			var flat := StyleBoxEmpty.new()
			button.add_theme_color_override("font_color", _theme_color("ink"))
			button.add_theme_color_override("font_hover_color", _theme_color("accent"))
			button.add_theme_color_override("font_pressed_color", _theme_color("ink"))
			button.add_theme_stylebox_override("normal", flat)
			button.add_theme_stylebox_override("hover", _flat_button_state_style(Color(_theme_color("muted"), 0.24)))
			button.add_theme_stylebox_override("pressed", _flat_button_state_style(Color(_theme_color("muted"), 0.40)))
		else:
			button.add_theme_color_override("font_color", _theme_color("ink"))
			button.add_theme_color_override("font_hover_color", _theme_color("ink"))
			button.add_theme_color_override("font_pressed_color", _theme_color("surface"))
			button.add_theme_color_override("font_disabled_color", _theme_color("accent").lightened(0.22))
			button.add_theme_stylebox_override("normal", _style(_theme_color("surface"), _theme_color("accent")))
			button.add_theme_stylebox_override("hover", _style(_theme_color("muted"), _theme_color("ink")))
			button.add_theme_stylebox_override("pressed", _style(_theme_color("accent"), _theme_color("ink")))
			button.add_theme_stylebox_override("disabled", _style(_theme_color("surface").darkened(0.10), _theme_color("accent").lightened(0.20)))
	elif node is PanelContainer:
		if node.has_meta("phone_shell"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _phone_shell_style())
		elif node.has_meta("movie_subtitle"):
			(node as PanelContainer).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		elif node.has_meta("portrait_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _reward_card_style(_theme_color("ink"), _theme_color("muted")))
		elif node.has_meta("phone_surface"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _phone_surface_style())
		elif node.has_meta("social_card"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _social_card_style())
		elif node.has_meta("poster_frame"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _poster_frame_style())
		elif node.has_meta("detail_dark_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _detail_dark_style())
		elif node.has_meta("social_feed_dark"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _social_feed_dark_style())
		elif node.has_meta("meme_bank_popup") and not _meme_bank_open:
			(node as PanelContainer).add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		elif node.has_meta("dark_rail"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _style(_theme_color("ink"), Color(_theme_color("muted"), 0.22)))
		elif node.has_meta("tooltip_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _style(_theme_color("muted"), _theme_color("accent")))
		elif node.has_meta("soft_panel"):
			(node as PanelContainer).add_theme_stylebox_override("panel", _soft_style(_theme_color("surface"), _theme_color("accent")))
		else:
			(node as PanelContainer).add_theme_stylebox_override("panel", _style(_theme_color("surface"), _theme_color("accent")))
	elif node is LineEdit:
		var edit := node as LineEdit
		edit.add_theme_color_override("font_color", _theme_color("ink"))
		edit.add_theme_color_override("font_placeholder_color", _theme_color("accent"))
		edit.add_theme_stylebox_override("normal", _style(_theme_color("surface"), _theme_color("accent")))
	for child in node.get_children():
		_apply_ui_theme(child)


func _build_action_spend_overlay() -> void:
	_action_spend_overlay = Control.new()
	_action_spend_overlay.name = "ActionSpendOverlay"
	_action_spend_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_action_spend_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_action_spend_overlay.visible = false
	_action_spend_overlay.z_index = 90
	_ui_root.add_child(_action_spend_overlay)

	_action_spend_blackout = null

	_action_spend_label = Label.new()
	_action_spend_label.name = "ActionSpendLabel"
	_action_spend_label.set_meta("action_overlay_text", false)
	_action_spend_label.set_meta("action_animation_mode", "inline_pulse")
	_action_spend_label.visible = false
	_action_spend_label.add_theme_font_size_override("font_size", _ui_font_size(20))
	_action_spend_label.add_theme_color_override("font_color", _theme_color("muted"))
	_action_spend_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_spend_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_action_spend_overlay.add_child(_action_spend_label)


func _play_action_spend_animation(before_actions: int, after_actions: int) -> void:
	if _hud_actions_label == null:
		return
	if _action_tick_audio != null and _action_tick_audio.stream != null and _action_tick_audio.is_inside_tree():
		_action_tick_audio.play()
	if _action_spend_tween != null and _action_spend_tween.is_valid():
		_action_spend_tween.kill()
	_action_spend_after_actions = after_actions
	_action_spend_should_settle = game.needs_day_settlement
	_hud_actions_label.text = _action_text(before_actions)
	_hud_actions_label.scale = Vector2.ONE
	_hud_actions_label.pivot_offset = _hud_actions_label.size * 0.5
	if _action_spend_overlay != null:
		_action_spend_overlay.visible = false
	_set_input_locked(true)

	_action_spend_tween = create_tween()
	_action_spend_tween.tween_property(_hud_actions_label, "scale", Vector2(1.07, 1.07), 0.08).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	_action_spend_tween.tween_callback(_set_action_spend_center_text.bind(after_actions))
	_action_spend_tween.tween_property(_hud_actions_label, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_action_spend_tween.tween_callback(_finish_action_spend_animation)


func _set_action_spend_center_text(after_actions: int) -> void:
	if _hud_actions_label != null:
		_hud_actions_label.text = _action_text(after_actions)
	if _action_spend_label != null:
		_action_spend_label.text = _action_text(after_actions)


func _finish_action_spend_animation() -> void:
	if _action_spend_tween != null and _action_spend_tween.is_valid():
		_action_spend_tween.kill()
	_action_spend_tween = null
	if _action_spend_overlay != null:
		_action_spend_overlay.visible = false
	if _action_spend_label != null:
		_action_spend_label.scale = Vector2.ONE
	if _hud_actions_label != null:
		_hud_actions_label.scale = Vector2.ONE
	var should_transition := _action_spend_should_settle
	_action_spend_should_settle = false
	if should_transition:
		_action_spend_after_actions = -1
		_play_day_transition()
		return
	_set_input_locked(false)
	_sync_audio_state(false)
	_render()
	if _hud_actions_label != null and _action_spend_after_actions >= 0:
		_hud_actions_label.text = _action_text(_action_spend_after_actions)
	_action_spend_after_actions = -1


func _action_spend_start_position() -> Vector2:
	if _hud_actions_label == null:
		return Vector2(28, 320)
	return _hud_actions_label.global_position


func _action_spend_center_position() -> Vector2:
	var viewport_size := _viewport_size()
	var label_size := _action_spend_label.custom_minimum_size if _action_spend_label != null else Vector2(620, 92)
	return (viewport_size - label_size) * 0.5


func _build_day_transition_overlay() -> void:
	_day_transition_overlay = Control.new()
	_day_transition_overlay.name = "DayTransitionOverlay"
	_day_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_day_transition_overlay.visible = false
	_day_transition_overlay.z_index = 95
	_day_transition_overlay.set_meta("duration_seconds", 3.6)
	_ui_root.add_child(_day_transition_overlay)

	var background := ColorRect.new()
	background.name = "DayTransitionBlack"
	background.color = Color("050705")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_transition_overlay.add_child(background)

	_day_transition_rule = ColorRect.new()
	_day_transition_rule.name = "DayTransitionRule"
	_day_transition_rule.color = _theme_color("flash_text")
	_day_transition_rule.set_anchors_preset(Control.PRESET_CENTER)
	_day_transition_rule.offset_left = -620
	_day_transition_rule.offset_top = -8
	_day_transition_rule.offset_right = 620
	_day_transition_rule.offset_bottom = 8
	_day_transition_rule.pivot_offset = Vector2(620, 8)
	_day_transition_rule.rotation = deg_to_rad(-5.0)
	_day_transition_overlay.add_child(_day_transition_rule)

	_day_transition_day_label = _label("第一层", 58, _theme_color("surface"))
	_day_transition_day_label.name = "FloorTransitionAreaLabel"
	_day_transition_day_label.set_meta("on_dark", true)
	_day_transition_day_label.set_anchors_preset(Control.PRESET_CENTER)
	_day_transition_day_label.offset_left = -520
	_day_transition_day_label.offset_top = -190
	_day_transition_day_label.offset_right = 520
	_day_transition_day_label.offset_bottom = -70
	_day_transition_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_transition_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_transition_day_label.pivot_offset = Vector2(520, 70)
	_day_transition_overlay.add_child(_day_transition_day_label)

	_day_transition_meta_label = _label("危险：B", 28, _theme_color("flash_text"))
	_day_transition_meta_label.name = "FloorTransitionDangerLabel"
	_day_transition_meta_label.set_meta("on_dark", true)
	_day_transition_meta_label.set_anchors_preset(Control.PRESET_CENTER)
	_day_transition_meta_label.offset_left = -440
	_day_transition_meta_label.offset_top = -16
	_day_transition_meta_label.offset_right = 440
	_day_transition_meta_label.offset_bottom = 42
	_day_transition_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_transition_meta_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_transition_overlay.add_child(_day_transition_meta_label)

	_day_transition_hint_label = _label("提示：《游戏与现实》", 22, _theme_color("muted"))
	_day_transition_hint_label.name = "FloorTransitionHintLabel"
	_day_transition_hint_label.set_meta("on_dark", true)
	_day_transition_hint_label.set_anchors_preset(Control.PRESET_CENTER)
	_day_transition_hint_label.offset_left = -520
	_day_transition_hint_label.offset_top = 62
	_day_transition_hint_label.offset_right = 520
	_day_transition_hint_label.offset_bottom = 132
	_day_transition_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_transition_hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_transition_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_day_transition_overlay.add_child(_day_transition_hint_label)


func _update_floor_transition_card(floor_number: int) -> void:
	var displayed_floor := clampi(floor_number, 1, 4)
	var card: Dictionary = LanguageCorruptionContentScript.get_floor_card_display(displayed_floor)
	_day_transition_day_label.text = _locale.level_display_name(displayed_floor)
	_day_transition_meta_label.text = "危险：%s" % str(card.get("危险", ""))
	_day_transition_hint_label.text = "提示：%s" % str(card.get("提示", ""))


func _play_day_transition() -> void:
	if _day_transition_overlay == null:
		_settle_day_and_present_rewards()
		_set_input_locked(false)
		_render()
		return
	if _day_transition_tween != null and _day_transition_tween.is_valid():
		_day_transition_tween.kill()
	_day_transition_settled = false
	_set_input_locked(true)
	_day_transition_overlay.visible = true
	_day_transition_overlay.modulate = Color(1, 1, 1, 0)
	_update_floor_transition_card(game.tower_floor)
	_day_transition_day_label.scale = Vector2(0.86, 0.86)
	_day_transition_rule.scale = Vector2(0.04, 1.0)
	if not is_inside_tree():
		return
	_day_transition_tween = create_tween()
	_day_transition_tween.set_parallel(true)
	_day_transition_tween.tween_property(_day_transition_overlay, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_day_transition_tween.tween_property(_day_transition_rule, "scale:x", 1.0, 0.72).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_day_transition_tween.set_parallel(false)
	_day_transition_tween.tween_property(_day_transition_day_label, "scale", Vector2.ONE, 0.58).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_day_transition_tween.tween_interval(0.55)
	_day_transition_tween.tween_callback(_commit_day_transition_settlement)
	_day_transition_tween.tween_interval(0.95)
	_day_transition_tween.tween_property(_day_transition_overlay, "modulate:a", 0.0, 0.80).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_day_transition_tween.tween_callback(_finish_day_transition)


func _commit_day_transition_settlement() -> void:
	if _day_transition_settled:
		return
	_day_transition_settled = true
	if _settle_day_and_present_rewards():
		selected_token_id = ""
		selected_meme_id = ""
		if not game.event_log.is_empty():
			log_text = game.event_log[0]
	_update_floor_transition_card(game.tower_floor)


func _finish_day_transition() -> void:
	if _day_transition_tween != null and _day_transition_tween.is_valid():
		_day_transition_tween.kill()
	_day_transition_tween = null
	if not _day_transition_settled:
		_commit_day_transition_settlement()
	if _day_transition_overlay != null:
		_day_transition_overlay.visible = false
		_day_transition_overlay.modulate = Color.WHITE
	_set_input_locked(false)
	_sync_audio_state(false)
	_render()


func _build_flashback_overlay() -> void:
	_flashback_overlay = PollutionFlashbackDirector.new()
	_flashback_overlay.name = "PollutionFlashbackOverlay"
	_flashback_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flashback_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flashback_overlay.visible = false
	_flashback_overlay.z_index = 100
	_ui_root.add_child(_flashback_overlay)
	_flashback_overlay.configure_colors({
		"ink": _theme_color("ink"),
		"surface": _theme_color("surface"),
		"flash_text": _theme_color("flash_text"),
	})
	_flashback_overlay.build_phases()
	_flashback_overlay.sequence_finished.connect(_finish_pollution_flashback)


func _play_pollution_flashback() -> void:
	if _flashback_overlay == null:
		return
	_set_input_locked(true)
	# 配色以触发瞬间的活跃调色板为准(60% 时已是污染调色板),再重建相位节点。
	_flashback_overlay.configure_colors({
		"ink": _theme_color("ink"),
		"surface": _theme_color("surface"),
		"flash_text": _theme_color("flash_text"),
	})
	_flashback_overlay.build_phases()
	var frozen_texture := _capture_frozen_frame_texture()
	_duck_ambience_for_flashback()
	if _flashback_audio != null and _flashback_audio.stream != null and _flashback_audio.is_inside_tree():
		_flashback_audio.play()
	_flashback_overlay.play(frozen_texture)


func _capture_frozen_frame_texture() -> Texture2D:
	var viewport := get_viewport()
	if viewport == null or DisplayServer.get_name().to_lower() == "headless":
		return null
	var viewport_texture := viewport.get_texture()
	if viewport_texture == null:
		return null
	var frozen_image := viewport_texture.get_image()
	if frozen_image == null or frozen_image.is_empty():
		return null
	return ImageTexture.create_from_image(frozen_image)


func _finish_pollution_flashback() -> void:
	if _flashback_overlay != null:
		_flashback_overlay.stop()
	if _flashback_audio != null:
		_flashback_audio.stop()
	_set_input_locked(false)
	var should_settle := game.consume_pollution_flashback()
	if should_settle and _settle_day_and_present_rewards():
		selected_token_id = ""
		selected_meme_id = ""
		log_text = "黑屏之后，已经是第二天。"
		if not game.event_log.is_empty():
			log_text = "%s\n%s" % [log_text, game.event_log[0]]
	_sync_audio_state(false)
	_render()


func _set_input_locked(value: bool) -> void:
	_input_locked = value
	_sync_window_manager_enabled()
	if _flashback_overlay != null:
		_flashback_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if value else Control.MOUSE_FILTER_IGNORE
	if _action_spend_overlay != null:
		_action_spend_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if value and _action_spend_overlay.visible else Control.MOUSE_FILTER_IGNORE
	if _day_transition_overlay != null:
		_day_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP if value and _day_transition_overlay.visible else Control.MOUSE_FILTER_IGNORE


func _render_ending() -> void:
	if _canvas == null:
		_build_world()
	for child in _canvas.get_children():
		_canvas.remove_child(child)
		child.free()
	var screen := Control.new()
	screen.name = "EndingScreen"
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.set_meta("empty_tower", true)
	_canvas.add_child(screen)
	var bg := ColorRect.new()
	bg.name = "EndingBlack"
	bg.color = _theme_color("ink")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.add_child(bg)
	var rule := ColorRect.new()
	rule.name = "EndingSignalRule"
	rule.color = _theme_color("flash_text")
	rule.set_anchors_preset(Control.PRESET_CENTER)
	rule.offset_left = -610
	rule.offset_right = 610
	rule.offset_top = 18
	rule.offset_bottom = 24
	rule.rotation = deg_to_rad(-4.0)
	screen.add_child(rule)
	var system_line := _label("FLOOR 05  /  NO SIGNAL  /  WISDOM USER NOT FOUND", 16, _theme_color("flash_text"))
	system_line.name = "EndingSystemLine"
	system_line.set_anchors_preset(Control.PRESET_TOP_WIDE)
	system_line.offset_left = 56
	system_line.offset_top = 42
	system_line.offset_right = -56
	system_line.offset_bottom = 78
	system_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	system_line.set_meta("on_dark", true)
	screen.add_child(system_line)
	var center := VBoxContainer.new()
	center.name = "EndingContent"
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.offset_left = -500
	center.offset_right = 500
	center.offset_top = -248
	center.offset_bottom = 260
	center.add_theme_constant_override("separation", 18)
	screen.add_child(center)
	var title := _label("塔顶没有人", 54, _theme_color("surface"))
	title.name = "EndingTitle"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_meta("on_dark", true)
	center.add_child(title)
	var body_text := "\n".join(MemeGameStateScript.EPILOGUE_LINES)
	var body := _label(body_text, 22, _theme_color("muted"))
	body.name = "EndingBody"
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.set_meta("on_dark", true)
	center.add_child(body)

	if game.ending_language_choice.is_empty():
		var prompt := _label("你还能留下一个声音。", 20, _theme_color("surface"))
		prompt.name = "EndingLanguagePrompt"
		prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		prompt.set_meta("on_dark", true)
		center.add_child(prompt)
		var choices := HBoxContainer.new()
		choices.name = "EndingLanguageChoices"
		choices.alignment = BoxContainer.ALIGNMENT_CENTER
		choices.add_theme_constant_override("separation", 14)
		center.add_child(choices)
		for choice in game.get_ending_language_choices():
			var button := Button.new()
			var choice_id := str(choice.get("id", ""))
			button.name = "EndingLanguageChoice_%s" % choice_id
			button.text = str(choice.get("label", ""))
			button.custom_minimum_size = Vector2(172, 58)
			button.pressed.connect(_on_ending_language_selected.bind(choice_id), CONNECT_DEFERRED)
			choices.add_child(button)
	else:
		var result := _label("你最后说：\n\n%s\n\n发射机把这个声音送回楼下。\n没有人回答。也许所有人都已经同时说完了。\n（这算是语言结束了吗？）\n指示灯没有提供选项。" % game.get_ending_language_output(), 27, _theme_color("surface"))
		result.name = "EndingLanguageResult"
		result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		result.set_meta("on_dark", true)
		center.add_child(result)

	var residue := _label("关系残留 %d / 100  ·  %s" % [game.relationship_residue, game.get_relationship_state_label()], 16, _theme_color("muted"))
	residue.name = "EndingResidue"
	residue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	residue.set_meta("on_dark", true)
	center.add_child(residue)
	var restart := Button.new()
	restart.name = "EndingRestartButton"
	restart.text = "重开"
	restart.custom_minimum_size = Vector2(172, 54)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restart.pressed.connect(new_game, CONNECT_DEFERRED)
	center.add_child(restart)


func _on_ending_language_selected(choice_id: String) -> void:
	if game.choose_ending_language(choice_id):
		_render_ending()


func _on_app_pressed(app_id: String) -> void:
	if _input_locked:
		return
	game.set_view_state("phone_down")
	_set_reality_mouse_look(false)
	game.set_active_app(app_id)
	if app_id == "social":
		game.notify_tutorial("social_opened")
	elif app_id == "notebook":
		game.notify_tutorial("notebook_opened")
	_open_app_windows[app_id] = true
	_phone_launcher_open = false
	if app_id == "notebook":
		_meme_bank_open = true
	if _app_windows.has(app_id):
		var window := _app_windows[app_id] as Control
		if window != null:
			window.move_to_front()
	log_text = "打开 %s。" % app_id
	_render()


## ============ 玩偶全程引导(常驻小窗,承担教程与楼层任务提示)============

func _build_doll_guide_overlay() -> void:
	_doll_guide_panel = PanelContainer.new()
	_doll_guide_panel.name = "DollGuideOverlay"
	# 低于设置窗(30)与各弹层;高于普通应用窗口。
	_doll_guide_panel.z_index = 25
	_doll_guide_panel.custom_minimum_size = Vector2(252, 0)
	_ui_root.add_child(_doll_guide_panel)
	var guide_box := VBoxContainer.new()
	guide_box.add_theme_constant_override("separation", 4)
	_doll_guide_panel.add_child(guide_box)
	var header := HBoxContainer.new()
	header.name = "DollGuideHeader"
	header.add_theme_constant_override("separation", 6)
	guide_box.add_child(header)
	var portrait := TextureRect.new()
	portrait.name = "DollGuidePortrait"
	portrait.texture = _load_runtime_texture(GUIDE_DOLL_CHARACTER_PATH)
	portrait.custom_minimum_size = Vector2(52, 52)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	header.add_child(portrait)
	var title := _label("缝线布偶", 15, _theme_color("accent"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var collapse := Button.new()
	collapse.name = "DollGuideCollapseButton"
	collapse.text = "折叠"
	collapse.custom_minimum_size = Vector2(58, 34)
	collapse.focus_mode = Control.FOCUS_NONE
	collapse.pressed.connect(_toggle_doll_guide_collapsed)
	header.add_child(collapse)
	_doll_guide_body = VBoxContainer.new()
	_doll_guide_body.name = "DollGuideBody"
	guide_box.add_child(_doll_guide_body)
	_doll_guide_line_label = _label("", 14, _theme_color("ink"))
	_doll_guide_line_label.name = "DollGuideLine"
	_doll_guide_line_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_doll_guide_line_label.custom_minimum_size = Vector2(236, 0)
	_doll_guide_body.add_child(_doll_guide_line_label)
	# 常驻画面左下角:玩家视觉的余光位置,不挡中心视野。
	_doll_guide_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT, true)
	_doll_guide_panel.offset_left = 16.0
	_doll_guide_panel.offset_bottom = -16.0
	_doll_guide_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_make_draggable_window(_doll_guide_panel, "doll_guide", header)
	# 玩偶从头到尾在玩家视线内:没有关闭按钮,只能折叠或拖动。
	_doll_guide_panel.visible = false


func _toggle_doll_guide_collapsed() -> void:
	if _doll_guide_body == null or _doll_guide_panel == null or not is_instance_valid(_doll_guide_panel) or not is_instance_valid(_doll_guide_body):
		return
	_doll_guide_body.visible = not _doll_guide_body.visible
	var collapse_button := _find_control_by_name(_doll_guide_panel, "DollGuideCollapseButton") as Button
	if collapse_button != null:
		collapse_button.text = "折叠" if _doll_guide_body.visible else "展开"


func _update_doll_guide() -> void:
	if _doll_guide_panel == null or not is_instance_valid(_doll_guide_panel):
		_doll_guide_panel = null
		return
	# 派蒙式退避:玩家与 NPC 对话/交互时,玩偶(连同气泡窗)一起隐身,不抢戏。
	_doll_guide_panel.visible = _game_started and game != null and not _reality_interaction_active
	if not _doll_guide_panel.visible or _doll_guide_line_label == null or not is_instance_valid(_doll_guide_line_label):
		return
	_doll_guide_line_label.text = _doll_guide_current_line()


## ============ 玩偶伙伴:常驻画面左下角,和它的头像引导小窗合为一体 ============

## 3D 跟随体已退役(在第一人称视角里几乎看不见,还会挡视线);
## 玩偶改为始终待在屏幕左下角的引导小窗里,对话时整体隐身。
func _update_doll_companion(_delta: float) -> void:
	if _doll_companion != null and is_instance_valid(_doll_companion):
		_doll_companion.queue_free()
	_doll_companion = null


func _doll_guide_current_line() -> String:
	var step: Dictionary = game.get_tutorial_step()
	if not bool(step.get("is_complete", false)):
		var line := str(step.get("guide_line", ""))
		# 一步一步教:多次数步骤显示进度(如 拾取三个字 1/3)。
		var required_count := int(step.get("required_count", 0))
		if required_count > 1:
			line += "(%d/%d)" % [clampi(int(step.get("event_count", 0)), 0, required_count), required_count]
		return line
	if game.tower_floor == 3 and not game.floor3_task_complete:
		return "门在等一句话。去笔记本里拼给它。"
	if game.tower_floor == 3 and game.floor3_task_complete:
		return "门记得这句话。"
	if game.tower_floor == 4 and not game.floor4_task_complete:
		return "出口还不存在。让它存在。"
	if game.tower_floor == 4 and game.floor4_task_complete:
		return "出口存在了。这里不会记下我们。"
	return str(step.get("guide_line", "你已经会自己走了。至少现在是。"))


## ============ 终极任务的世界侧道具(第三层封门 / 第四层出口)============

func _sync_ultimate_task_props() -> void:
	if game == null:
		return
	var floor_root := get_node_or_null("RealityFloor")
	if floor_root == null:
		return
	if game.tower_floor == 3:
		var sealed_door := _ensure_task_prop_body(floor_root, "FloorThreeSealedDoor", Vector3(2.6, 3.2, 0.34), Vector3(0.0, 1.6, -7.0))
		var open_frame := _ensure_task_prop_mesh(floor_root, "FloorThreeDoorOpenFrame", Vector3(2.8, 3.4, 0.08), Vector3(0.0, 1.7, -7.0), true)
		if sealed_door != null:
			sealed_door.visible = not game.floor3_task_complete
			var door_shape := sealed_door.get_node_or_null("DoorCollision") as CollisionShape3D
			if door_shape != null:
				# 门开之后不再阻挡通行。
				door_shape.disabled = game.floor3_task_complete
		if open_frame != null:
			open_frame.visible = game.floor3_task_complete
	elif game.tower_floor == 4:
		var exit_frame := _ensure_task_prop_mesh(floor_root, "FloorFourExitFrame", Vector3(2.8, 3.4, 0.08), Vector3(0.0, 1.7, -6.0), true)
		if exit_frame != null:
			exit_frame.visible = game.floor4_task_complete


## 有碰撞的封门:StaticBody3D + 网格 + 碰撞盒,玩家在门开前无法穿过。
func _ensure_task_prop_body(floor_root: Node, node_name: String, body_size: Vector3, body_position: Vector3) -> StaticBody3D:
	var existing := floor_root.get_node_or_null(node_name) as StaticBody3D
	if existing != null:
		return existing
	var body := StaticBody3D.new()
	body.name = node_name
	body.position = body_position
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "DoorMesh"
	var box := BoxMesh.new()
	box.size = body_size
	var material := StandardMaterial3D.new()
	material.albedo_color = _theme_color("ink")
	box.material = material
	mesh_instance.mesh = box
	body.add_child(mesh_instance)
	var collision := CollisionShape3D.new()
	collision.name = "DoorCollision"
	var shape := BoxShape3D.new()
	shape.size = body_size
	collision.shape = shape
	body.add_child(collision)
	floor_root.add_child(body)
	return body


func _ensure_task_prop_mesh(floor_root: Node, node_name: String, mesh_size: Vector3, mesh_position: Vector3, emissive: bool) -> MeshInstance3D:
	var existing := floor_root.get_node_or_null(node_name) as MeshInstance3D
	if existing != null:
		return existing
	var prop := MeshInstance3D.new()
	prop.name = node_name
	var box := BoxMesh.new()
	box.size = mesh_size
	var material := StandardMaterial3D.new()
	if emissive:
		material.albedo_color = _theme_color("flash_text")
		material.emission_enabled = true
		material.emission = _theme_color("flash_text")
		material.emission_energy_multiplier = 1.4
	else:
		material.albedo_color = _theme_color("ink")
	box.material = material
	prop.mesh = box
	prop.position = mesh_position
	floor_root.add_child(prop)
	return prop


## ============ 自由造句台(多邻国式:tap 入句、tap 撤回、随时投稿)============

## 多邻国 U1 质感:圆角约为高度 1/4、浅底细描边、底部厚边模拟浮起阴影;
## 按下时下沉 2px(上边距+2/下边距-2,底厚边收薄);ghost 为凹陷灰。
func _composer_tile_style(kind: String) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(10)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 5.0
	style.content_margin_bottom = 7.0
	match kind:
		"pressed":
			style.bg_color = _theme_color("surface").darkened(0.05)
			style.border_color = Color(_theme_color("accent"), 0.9)
			style.set_border_width_all(1)
			style.content_margin_top = 7.0
			style.content_margin_bottom = 5.0
		"ghost":
			style.bg_color = Color(_theme_color("muted"), 0.30)
			style.border_color = Color(_theme_color("accent"), 0.22)
			style.set_border_width_all(1)
		_:
			style.bg_color = _theme_color("surface")
			style.border_color = Color(_theme_color("accent"), 0.55)
			style.set_border_width_all(1)
			style.border_width_bottom = 3
	return style


func _apply_composer_tile_theme(tile: Button, is_ghost: bool) -> void:
	if is_ghost:
		tile.add_theme_stylebox_override("normal", _composer_tile_style("ghost"))
		tile.add_theme_stylebox_override("disabled", _composer_tile_style("ghost"))
		return
	tile.add_theme_stylebox_override("normal", _composer_tile_style("normal"))
	tile.add_theme_stylebox_override("hover", _composer_tile_style("normal"))
	tile.add_theme_stylebox_override("pressed", _composer_tile_style("pressed"))

func _render_sentence_composer(notebook_content: VBoxContainer) -> void:
	notebook_content.add_child(_label("拾到的字", 18, _theme_color("accent")))
	var canvas_hint := _label("字被拾取后一直留在这里。可以随意拖动摆放,也可以拖进发布页的句子里。", 13, _theme_color("muted"))
	canvas_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook_content.add_child(canvas_hint)

	var canvas_frame := _panel()
	canvas_frame.name = "NotebookCanvasFrame"
	notebook_content.add_child(canvas_frame)
	var canvas := WordPhysicsCanvasScript.new()
	canvas.name = "NotebookWordCanvas"
	canvas.custom_minimum_size = MemeGameStateScript.CHAR_CANVAS_SIZE
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas_frame.add_child(canvas)
	canvas.tile_settled.connect(_on_canvas_tile_moved)
	canvas.tile_dropped_outside.connect(_on_canvas_tile_dropped_outside)
	canvas.tile_tapped.connect(_on_composer_bank_tapped)

	var locale_code: String = _locale.current_locale
	var collected_units: Array[String] = game.get_collected_char_units(locale_code)
	var placed_units: Array = game.get_free_sentence_units()
	if collected_units.is_empty():
		var empty_hint := _label("还没有拾到字。帖子里发亮的字可以点。", 13, _theme_color("muted"))
		empty_hint.name = "NotebookCharEmptyHint"
		empty_hint.position = Vector2(10.0, 10.0)
		canvas.add_child(empty_hint)
	for unit in collected_units:
		var is_ghost := str(unit) in placed_units
		canvas.add_tile(
			str(unit),
			game.get_char_canvas_position(str(unit), locale_code),
			_theme_color("ink"),
			_composer_tile_style("ghost" if is_ghost else "normal"),
			is_ghost
		)

	var active_rules: Array = game.get_world_rules()
	if not active_rules.is_empty():
		notebook_content.add_child(_label("现行规则", 18, _theme_color("accent")))
		var rules_box := VBoxContainer.new()
		rules_box.name = "ComposerRulesList"
		rules_box.add_theme_constant_override("separation", 3)
		notebook_content.add_child(rules_box)
		for rule in active_rules:
			var rule_text := RuleEngineScript.rule_display_text(str(rule.get("key", "")), bool(rule.get("negated", false)), locale_code)
			var rule_label := _label("· %s" % rule_text, 14, _theme_color("accent"))
			rule_label.set_meta("skip_localization", true)
			rules_box.add_child(rule_label)


func _on_canvas_tile_moved(unit: String, tile_position: Vector2) -> void:
	game.set_char_canvas_position(unit, tile_position, _locale.current_locale)


## 把字从笔记本画布拖到发布页的句子区:命中即入句,未命中则飞回画布原位。
func _on_canvas_tile_dropped_outside(unit: String, release_global: Vector2) -> void:
	var answer_panel := _find_control_by_name(_ui_root, "ComposerAnswerPanel")
	var dropped_into_sentence := false
	if answer_panel != null and is_instance_valid(answer_panel) and answer_panel.is_visible_in_tree():
		if answer_panel.get_global_rect().has_point(release_global):
			dropped_into_sentence = game.free_sentence_place(unit, _locale.current_locale)
	if dropped_into_sentence:
		log_text = "字进入了句子。"
	_render()


func _on_composer_bank_tapped(unit: String) -> void:
	if _input_locked:
		return
	if game.free_sentence_place(unit, _locale.current_locale):
		if _pickup_flight_layer != null:
			_pickup_flight_layer.play_place_flight(unit, get_viewport().get_mouse_position(), _composer_answer_target, _theme_color("accent"))
		log_text = "字进入了句子。"
		_render()


func _on_composer_answer_tapped(unit_index: int) -> void:
	if _input_locked:
		return
	if game.free_sentence_remove(unit_index):
		_render()


func _on_composer_area_drop(data: Dictionary) -> void:
	_handle_composer_drop(data, game.get_free_sentence_units().size())


func _on_composer_tile_drop(data: Dictionary, before_index: int) -> void:
	_handle_composer_drop(data, before_index)


func _handle_composer_drop(data: Dictionary, target_index: int) -> void:
	if _input_locked:
		return
	match str(data.get("kind", "")):
		"composer_unit":
			if game.free_sentence_place_at(str(data.get("id", "")), target_index, _locale.current_locale):
				log_text = "字进入了句子。"
				_render()
		"composer_reorder":
			var from_index := int(str(data.get("id", "-1")))
			var to_index := target_index
			if from_index < to_index:
				to_index -= 1
			if game.free_sentence_move(from_index, to_index):
				_render()


func _composer_answer_target() -> Vector2:
	var answer_flow := _find_control_by_name(_ui_root, "ComposerAnswerFlow")
	if answer_flow != null and is_instance_valid(answer_flow):
		return answer_flow.get_global_position() + Vector2(answer_flow.size.x * 0.5, 20.0)
	return _notebook_flight_target()


func _on_composer_submit_pressed() -> void:
	if _input_locked:
		return
	var actions_before: int = int(game.actions_remaining)
	var submit_result: Dictionary = game.submit_free_sentence(_locale.current_locale)
	if not bool(submit_result.get("submitted", false)):
		match str(submit_result.get("reason", "")):
			"empty":
				log_text = "句子还空着。"
			"no-actions":
				log_text = "今天没有行动了。明天第一次拾字会重新消耗行动。"
			_:
				log_text = "投稿没有发出去。"
		_render_status()
		return
	match str(submit_result.get("tier", "")):
		"rule":
			log_text = "投稿已发出。有什么地方遵守了它。"
		"misread":
			log_text = "投稿已发出。世界读错了它。"
		_:
			log_text = "投稿已发出。没有回应,只有噪声。"
	if bool(submit_result.get("floor3_task_completed", false)):
		log_text += "\n" + "第三层的门开了。"
	if bool(submit_result.get("floor4_task_completed", false)):
		log_text += "\n" + "出口开始存在。"
	_after_effective_action(actions_before)


func _build_pickup_flight_layer() -> void:
	_pickup_flight_layer = FlyToTargetLayer.new()
	_pickup_flight_layer.name = "PickupFlightLayer"
	_pickup_flight_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	# 高于日结过场(95),低于闪回(100):日结黑幕不吞掉仍在飞行的字。
	_pickup_flight_layer.z_index = 97
	_ui_root.add_child(_pickup_flight_layer)
	_pickup_flight_layer.flight_landed.connect(_on_pickup_flight_landed)


## 拾字时把笔记本窗口召回左上角初始位置并打开,让玩家看见字飞进去。
func _ensure_notebook_window_home() -> void:
	_open_app_windows["notebook"] = true
	var window := _notebook_window_control()
	if window == null:
		return
	_apply_app_window_layout(window, "notebook", -968.0, 152.0, -528.0, 732.0)
	window.visible = game != null and game.view_state == "phone_down"


func _make_pickup_rich_text(node_name: String, source_text: String, post_id: String) -> RichTextLabel:
	var rich := RichTextLabel.new()
	rich.name = node_name
	rich.bbcode_enabled = true
	rich.fit_content = true
	rich.scroll_active = false
	rich.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rich.add_theme_font_size_override("normal_font_size", _ui_font_size(16))
	rich.add_theme_color_override("default_color", _theme_color("surface"))
	rich.set_meta("pickup_rich_text", true)
	rich.text = _pickup_bbcode(source_text)
	rich.meta_clicked.connect(_on_pickup_unit_meta.bind(post_id))
	return rich


## 把文本中属于字池的单位包成可点击的 [url];已拾取的单位渲染为灰色余韵。
func _pickup_bbcode(source_text: String) -> String:
	var locale_code: String = _locale.current_locale
	var units: Array = game.get_pickup_unit_pool(locale_code) if game != null else PickupCharPoolScript.get_unit_pool(locale_code)
	units.sort_custom(func(left, right): return str(left).length() > str(right).length())
	var pickable_color := _theme_color("flash_text").to_html(false)
	var collected_color := "8b8f84"
	var result := ""
	var index := 0
	var text_length := source_text.length()
	while index < text_length:
		var matched := ""
		var matched_display := ""
		for unit_value in units:
			var unit := str(unit_value)
			if unit.is_empty() or index + unit.length() > text_length:
				continue
			var slice := source_text.substr(index, unit.length())
			if locale_code == "en":
				# 英文大小写不敏感(句首大写也可拾),但要求完整单词边界。
				if slice.to_lower() != unit.to_lower():
					continue
				if not _pickup_word_boundary_ok(source_text, index, unit.length()):
					continue
			elif slice != unit:
				continue
			matched = unit
			matched_display = slice
			break
		if matched.is_empty():
			result += _escape_bbcode(source_text.substr(index, 1))
			index += 1
			continue
		if game != null and game.is_social_char_collected(matched, locale_code):
			# 已拾取:灰、无下划线、无脉动 —— 与可拾取形成三重差异(色/线/动)。
			result += "[color=#%s]%s[/color]" % [collected_color, _escape_bbcode(matched_display)]
		else:
			# 可拾取的多重可供性:颜色 + 下划线 + 缓慢脉动 + 略大字号,
			# 不只靠颜色(色觉障碍与低对比屏幕下同样可辨)。
			result += "[color=#%s][url=%s][u][pulse freq=%.1f color=#ffffff55 ease=-2.0][font_size=%d]%s[/font_size][/pulse][/u][/url][/color]" % [
				pickable_color, matched, PICKABLE_PULSE_FREQ, PICKABLE_FONT_SIZE, _escape_bbcode(matched_display),
			]
		index += matched.length()
	return result


func _pickup_word_boundary_ok(text: String, start_index: int, unit_length: int) -> bool:
	if start_index > 0 and PickupCharPoolScript.is_word_character(text.substr(start_index - 1, 1)):
		return false
	var after_index := start_index + unit_length
	if after_index < text.length() and PickupCharPoolScript.is_word_character(text.substr(after_index, 1)):
		return false
	return true


func _on_pickup_unit_meta(meta: Variant, post_id: String) -> void:
	if _input_locked:
		return
	var unit := str(meta)
	var actions_before: int = int(game.actions_remaining)
	var origin: Vector2 = get_viewport().get_mouse_position()
	var pick_result: Dictionary = game.pick_social_char(post_id, unit, _locale.current_locale)
	if bool(pick_result.get("picked", false)):
		log_text = "一个字进入了笔记本。"
		_play_ui_sound(_pickup_press_audio)
		_ensure_notebook_window_home()
		if _pickup_flight_layer != null:
			_pickup_flight_layer.play_hold_flight(unit, origin, _notebook_flight_target, _theme_color("flash_text"))
		if bool(pick_result.get("action_spent", false)):
			_after_effective_action(actions_before)
		else:
			_render()
		return
	match str(pick_result.get("reason", "")):
		"duplicate":
			log_text = "这个字已经在笔记本里了。"
		"no-actions":
			log_text = "今天没有行动了。明天第一次拾字会重新消耗行动。"
		_:
			log_text = "这个字没有进入笔记本。"
	_render_status()


func _on_pickup_flight_landed(_unit: String) -> void:
	_play_ui_sound(_pickup_land_audio)
	_play_ui_sound(_notebook_hinge_audio)
	_squash_notebook_window()


## 短促 UI 音效:重复触发时从头播放,不叠加成噪音。
func _play_ui_sound(player: AudioStreamPlayer) -> void:
	if player == null or not is_instance_valid(player) or player.stream == null or not player.is_inside_tree():
		return
	player.stop()
	player.play()


func _notebook_window_control() -> Control:
	var window := _app_windows.get("notebook") as Control
	if window != null and is_instance_valid(window):
		return window
	return null


func _notebook_flight_target() -> Vector2:
	var window := _notebook_window_control()
	if window != null and window.visible:
		return window.get_global_position() + Vector2(56.0, 40.0)
	return Vector2(84.0, 64.0)


func _squash_notebook_window() -> void:
	var window := _notebook_window_control()
	if window == null or not window.visible:
		return
	if _notebook_squash_tween != null and _notebook_squash_tween.is_valid():
		_notebook_squash_tween.kill()
	window.pivot_offset = window.size * 0.5
	window.scale = Vector2.ONE
	_notebook_squash_tween = create_tween()
	_notebook_squash_tween.tween_property(window, "scale", Vector2(1.05, 0.96), 0.07).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_notebook_squash_tween.tween_property(window, "scale", Vector2.ONE, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_token_pressed(post_id: String, token: Dictionary) -> void:
	if _input_locked:
		return
	var actions_before: int = int(game.actions_remaining)
	var localized_token := token.duplicate(true)
	localized_token["source_text"] = str(token.get("source_text", token.get("text", "")))
	localized_token["text"] = _locale.translate(str(token.get("text", "")))
	localized_token["content_locale"] = _locale.current_locale
	if game.pick_token(post_id, localized_token):
		selected_token_id = "%s-%s-%d" % [post_id, token.get("id", "token"), game.day]
		log_text = "拾取：%s" % localized_token["text"]
		_after_effective_action(actions_before)
	else:
		log_text = "这个词没有进入笔记本。"
		_render()


func _on_note_token_pressed(token_id: String) -> void:
	if _input_locked:
		return
	selected_token_id = token_id
	log_text = "选中词语。"
	_render()


func _on_slot_token_dropped(data: Dictionary, slot_id: String) -> void:
	if _input_locked:
		return
	var token_id := str(data.get("id", ""))
	if token_id.is_empty():
		return
	selected_token_id = token_id
	game.place_token_in_slot(slot_id, token_id)
	log_text = "词语已拖入槽位。"
	_render()


func _on_slot_pressed(slot_id: String) -> void:
	if _input_locked:
		return
	if selected_token_id.is_empty():
		log_text = "先选一个词语。"
	else:
		game.place_token_in_slot(slot_id, selected_token_id)
		log_text = "词语已放入槽位。"
	_render()


func _on_language_token_pressed(token_id: String) -> void:
	if _input_locked:
		return
	_selected_language_token_id = token_id
	log_text = "选中了一个带到医生面前的词。"
	_render()


func _on_language_token_dropped(data: Dictionary, slot_id: String) -> void:
	if _input_locked:
		return
	var token_id := str(data.get("id", ""))
	if token_id.is_empty():
		return
	_selected_language_token_id = token_id
	if game.place_language_token(slot_id, token_id, "doctor"):
		log_text = "词已经进入医生句槽。"
	else:
		log_text = "这个词不能放在句子的这个位置。"
	_render()


func _on_language_slot_pressed(slot_id: String) -> void:
	if _input_locked:
		return
	if _selected_language_token_id.is_empty():
		log_text = "先选择一个词。"
	elif game.place_language_token(slot_id, _selected_language_token_id, "doctor"):
		log_text = "词已经进入医生句槽。"
	else:
		log_text = "这个词不能放在句子的这个位置。"
	_render()


func _on_confirm_doctor_sentence_pressed() -> void:
	if _input_locked:
		return
	var actions_before := int(game.actions_remaining)
	if game.confirm_doctor_sentence():
		_selected_language_token_id = ""
		log_text = "同一句话到了医生那里，已经不是原来的样子。"
		_after_effective_action(actions_before)
	else:
		log_text = "句子还不完整，或者这些词还没有在手机里发布。"
		_render()


func _on_confirm_craft_pressed() -> void:
	if _input_locked:
		return
	var actions_before: int = int(game.actions_remaining)
	if game.confirm_craft():
		selected_meme_id = str(game.completed_memes[0]["id"])
		log_text = "完整句子已经写好：%s" % game.completed_memes[0]["title"]
		_after_effective_action(actions_before)
	else:
		log_text = "需要分别填入对象、动作和去向。"
		_render()


func _on_fusion_meme_dropped(data: Dictionary, slot_id: String) -> void:
	if _input_locked:
		return
	var meme_id := str(data.get("id", ""))
	if game.place_meme_in_fusion_slot(slot_id, meme_id):
		selected_meme_id = meme_id
		log_text = "旧梗已放入融合槽。"
	else:
		log_text = "两个融合槽必须放入不同的完整梗。"
	_render()


func _on_fusion_slot_pressed(slot_id: String) -> void:
	if _input_locked:
		return
	if selected_meme_id.is_empty():
		log_text = "先从融合列表选择一个完整梗。"
	elif game.place_meme_in_fusion_slot(slot_id, selected_meme_id):
		log_text = "旧梗已放入融合槽。"
	else:
		log_text = "两个融合槽不能使用同一个梗。"
	_render()


func _on_confirm_fusion_pressed() -> void:
	if _input_locked:
		return
	var actions_before := int(game.actions_remaining)
	if game.confirm_meme_fusion():
		selected_meme_id = str(game.completed_memes[0].get("id", ""))
		log_text = "融合完成：%s" % str(game.completed_memes[0].get("title", "复合梗"))
		_after_effective_action(actions_before)
	else:
		log_text = "需要两个不同且尚未融合过的完整梗。"
		_render()


func _on_meme_pressed(meme_id: String) -> void:
	if _input_locked:
		return
	selected_meme_id = meme_id
	log_text = "选中完整梗。"
	_render()


func _on_dialogue_blank_pressed() -> void:
	if _input_locked:
		return
	if selected_meme_id.is_empty():
		log_text = "空格还在等一个完整梗。"
	else:
		game.place_meme_in_blank("blank_1", selected_meme_id)
		log_text = "梗已经塞进手机发布空格。"
	_render()


func _on_dialogue_meme_dropped(data: Dictionary, blank_id: String) -> void:
	if _input_locked:
		return
	var meme_id := str(data.get("id", ""))
	if meme_id.is_empty():
		return
	selected_meme_id = meme_id
	game.place_meme_in_blank(blank_id, meme_id)
	log_text = "完整梗已拖进发布空格。"
	_render()


func _on_confirm_dialogue_pressed() -> void:
	if _input_locked:
		return
	var actions_before: int = int(game.actions_remaining)
	if game.confirm_dialogue():
		selected_meme_id = ""
		log_text = "句子发出去了。资金到账，污染留下。"
		_after_effective_action(actions_before)
	else:
		log_text = "发布空格里还没有完整梗。"
		_render()


func _after_effective_action(actions_before: int = -1) -> void:
	if game.pollution_flashback_pending:
		_play_pollution_flashback()
		return
	if actions_before >= 0 and game.actions_remaining < actions_before:
		_render()
		if _hud_actions_label != null:
			_hud_actions_label.text = _action_text(actions_before)
		_play_action_spend_animation(actions_before, game.actions_remaining)
		return
	if _settle_day_and_present_rewards():
		selected_token_id = ""
		selected_meme_id = ""
		if not game.event_log.is_empty():
			log_text = game.event_log[0]
	_render()


func _settle_day_and_present_rewards() -> bool:
	if not game.settle_day_if_needed():
		return false
	_reality_interaction_active = false
	_active_reality_actor = null
	_nearby_reality_actor = null
	_nearby_reality_item = null
	_reality_hover_choice_id = ""
	selected_token_id = ""
	selected_meme_id = ""
	_sync_audio_state(false)
	return true


func _day_plan() -> Dictionary:
	return DAY_PLANS[mini(game.day, DAY_PLANS.size()) - 1]


func _slot_text(slot_id: String, placeholder: String) -> String:
	if game.draft_slots.has(slot_id):
		var token_id := str(game.draft_slots[slot_id])
		for token in game.notebook_tokens:
			if str(token["id"]) == token_id:
				return str(token["text"])
	return placeholder


func _language_slot_text(slot_id: String, placeholder: String, world: String) -> String:
	var token_id := str(game.language_sentence_slots.get(slot_id, ""))
	if token_id.is_empty():
		return placeholder
	for option_value in game.get_language_token_options(world):
		var option: Dictionary = option_value as Dictionary
		if str(option.get("id", "")) == token_id:
			return str(option.get("display_text", option.get("text", placeholder)))
	return placeholder


func _craft_preview_text() -> String:
	var preview: Dictionary = game.get_craft_sentence_preview("phone")
	if bool(preview.get("valid", false)):
		return str(preview.get("world_sentence", preview.get("clean_sentence", "")))
	return "等待对象、动作和去向"


func _fusion_slot_text(slot_id: String) -> String:
	var meme_id := str(game.fusion_slots.get(slot_id, ""))
	if meme_id.is_empty():
		return "旧梗 A" if slot_id == "left" else "旧梗 B"
	for meme in game.completed_memes:
		if str(meme.get("id", "")) == meme_id:
			return str(meme.get("title", meme.get("text", "完整梗")))
	return "等待完整梗"


func _placed_meme() -> Dictionary:
	if game.dialogue_blanks.has("blank_1"):
		var meme_id := str(game.dialogue_blanks["blank_1"])
		for meme in game.completed_memes:
			if str(meme["id"]) == meme_id:
				return meme
	return {}


func _corrupt(text: String) -> String:
	text = _locale.translate(text)
	if game.pollution < 35:
		return text
	var replacements := [_locale.translate("哈吉米"), "□", _locale.translate("沉默"), "……"]
	if _locale.current_locale == "en":
		return _corrupt_english_words(text, replacements)
	var result := ""
	for index in text.length():
		var ch := text.substr(index, 1)
		if index % maxi(2, 8 - int(game.pollution / 14)) == 0 and ch != " ":
			result += replacements[(index + game.day) % replacements.size()]
		else:
			result += ch
	return result


func _corrupt_english_words(text: String, replacements: Array) -> String:
	var word_regex := RegEx.new()
	word_regex.compile("(\\S+)(\\s*)")
	var units := word_regex.search_all(text)
	if units.is_empty():
		return text
	var result := ""
	var interval := maxi(2, 8 - int(game.pollution / 14))
	for index in units.size():
		var unit := units[index] as RegExMatch
		var word := unit.get_string(1)
		var spacing := unit.get_string(2)
		if index % interval == 0:
			word = str(replacements[(index + game.day) % replacements.size()])
		result += word + spacing
	return result


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(_theme_color("surface"), _theme_color("accent")))
	return panel


func _wrap(node: Control) -> PanelContainer:
	var panel := _panel()
	panel.add_child(node)
	return panel


## ============ 点阵字体主题:全局统一字形,字号吸附到点阵网格 ============

func _ensure_ui_font_theme() -> Theme:
	if _ui_theme != null:
		return _ui_theme
	_ui_theme = PixelFontThemeScript.build(UI_FONT_PATH, UI_FONT_GRID)
	return _ui_theme


## 把任意字号吸附到点阵网格(9 的整数倍),保证像素笔画等宽。
func _ui_font_size(requested_size: int) -> int:
	return PixelFontThemeScript.snap_size(requested_size, UI_FONT_GRID, UI_FONT_MIN_SIZE, UI_FONT_MAX_SIZE)


func _apply_ui_font_theme(target: Control) -> void:
	PixelFontThemeScript.apply(target, _ensure_ui_font_theme())


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	_set_localized_property(label, "text")
	label.add_theme_font_size_override("font_size", _ui_font_size(size))
	label.add_theme_color_override("font_color", color)
	return label


func _refresh_localized_ui() -> void:
	if _ui_root == null or not is_instance_valid(_ui_root):
		return
	_localize_control_tree(_ui_root)


func _localize_control_tree(node: Node) -> void:
	if node is Control and not bool(node.get_meta("skip_localization", false)):
		var control := node as Control
		if control is Label or control is Button:
			_set_localized_property(control, "text")
		if control is LineEdit:
			_set_localized_property(control, "placeholder_text")
		_set_localized_property(control, "tooltip_text")
	for child in node.get_children():
		_localize_control_tree(child)


func _set_localized_property(control: Control, property_name: String) -> void:
	if control == null:
		return
	# 拾取单位与字瓦片属于语言素材,不参与界面翻译。
	if control.has_meta("skip_localization"):
		return
	var current_text := str(control.get(property_name))
	if current_text.is_empty():
		return
	var source_meta := "locale_source_%s" % property_name
	var last_meta := "locale_last_%s" % property_name
	var source_text := str(control.get_meta(source_meta, ""))
	var last_text := str(control.get_meta(last_meta, ""))
	if source_text.is_empty() or current_text != last_text:
		source_text = current_text
		control.set_meta(source_meta, source_text)
	var localized_text := _locale.translate(source_text)
	control.set(property_name, localized_text)
	control.set_meta(last_meta, localized_text)


func _style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(10)
	return style


func _soft_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(bg, 0.94)
	style.border_color = Color(border, 0.24)
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(16)
	return style


func _circle_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(60)
	style.set_content_margin_all(12)
	return style


func _phone_shell_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color("ink")
	style.border_color = _theme_color("ink")
	style.set_border_width_all(6)
	style.set_corner_radius_all(24)
	style.set_content_margin_all(6)
	return style


func _phone_surface_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color("surface")
	style.border_color = _theme_color("surface")
	style.set_border_width_all(0)
	style.set_corner_radius_all(16)
	style.set_content_margin_all(10)
	return style


func _launcher_app_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	return style


func _window_close_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(4)
	return style


func _reward_card_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	return style


func _social_feed_dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color("ink")
	style.border_color = Color(_theme_color("muted"), 0.18)
	style.set_border_width_all(0)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(6)
	return style


func _social_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color("surface")
	style.border_color = Color(_theme_color("muted"), 0.62)
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	return style


func _poster_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color("muted")
	style.border_color = Color(_theme_color("ink"), 0.65)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(0)
	return style


func _detail_dark_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = _theme_color("ink")
	style.border_color = _theme_color("ink")
	style.set_border_width_all(0)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(10)
	return style


func _flat_button_state_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = Color(bg, 0.0)
	style.set_border_width_all(0)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(4)
	return style


func _file_corner_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.set_content_margin_all(6)
	return style


func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
