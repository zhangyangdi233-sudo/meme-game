# Round 2 Critic 报告 — char-level social pickup (HEAD ff1b18b)

审查对象:`ff1b18b feat: char-level social pickup with seeded posts, comments, and flight animation`
方法:全量 diff 精读 + 34 个 gd 测试全部实跑 + 4 个 /tmp 运行时探针(场景实例化、拾取全流程、bbcode 生成、飞行层生命周期、旧存档兼容)。
Godot:4.6.3-stable headless。所有断言均有运行证据(探针输出摘录附文末)。

## 结论:不放行(P0 一项必须修复;P1 两项需修复或用户签字)

要求 1/2/3/5 基本达标(见文末"已验证达标项"),要求 4 的"缩入左上角笔记本窗口 + 笔记本受击 squash"因一个字典键错误在运行时**从未发生**,而新增测试恰好用永真断言盖住了这一点。

---

## P0

### P0-1 `_draggable_windows` 键名错配:飞行动画永远飞不进笔记本窗口,squash 受击是死代码
- 维度:B 逻辑正确性 / A 需求完整性(验收标准 4)
- 文件:`scripts/babel_meme_game.gd:6433`、`scripts/babel_meme_game.gd:6440`
- 问题:窗口注册键是 `"app:notebook"`(`_build_app_window` → `_make_draggable_window(window, "app:%s" % app_id, ...)`,`scripts/babel_meme_game.gd:3570`),而新代码查的是 `_draggable_windows.get("notebook")` → 恒为 null。后果(全部经探针实证):
  1. `_notebook_flight_target()` 在笔记本窗口**打开且可见**时仍返回兜底值 `(84, 64)`;实测窗口在 `(188, 46)`、尺寸 610×736,字形落点在窗口左侧的 HUD 区域,**不在窗口内**;
  2. 拖动窗口后(实测移到 `(488, 246)`)落点仍是 `(84, 64)`——"窗口拖动后取哪个坐标"的答案是:根本没取;
  3. `_squash_notebook_window()` 因 `window == null` 直接 early-return,`_notebook_squash_tween` 恒为 null——计划 §2.2 明确要求的"收字后 squash 受击一次"从未播放,`pickup_landed → _on_pickup_flight_landed` 整条链路是死的。
- 探针输出:
  ```
  PROBE notebook visible=true global=(188.0, 46.0) size=(610.0, 736.0)
  PROBE flight target (open): (84.0, 64.0)
  PROBE squash tween: <null> scale=(1.0, 1.0)
  PROBE moved=true new global=(488.0, 246.0)
  PROBE flight target after move: (84.0, 64.0)
  ```
- 修法:两处改为 `_draggable_windows.get("app:notebook")`;或更稳:直接用 `_app_windows.get("notebook")`(该字典键就是裸 app_id,`scripts/babel_meme_game.gd:3588`),避免再依赖 draggable 键约定。
- 验证:test_pickup_char_flow 增加断言——打开笔记本窗口后 `_notebook_flight_target()` 落在 `window.get_global_rect()` 内;`_move_window_for_test("app:notebook", delta)` 后目标随动;调用 `_squash_notebook_window()` 后 `_notebook_squash_tween != null`。

## P1

### P1-1 新增测试在 P0 点位上"测了个寂寞"
- 维度:E 测试覆盖
- 文件:`tests/test_pickup_char_flow.gd:149`、`tests/test_pickup_char_flow.gd:146-147`
- 问题:
  1. `_assert_true(target.is_finite(), ...)`——`_notebook_flight_target()` 两个分支都返回有限向量,**永真断言**,正是它让 P0-1 溜过;
  2. 只断言 `is_animating()` 为真后立刻 `finish_all_immediately()`,而该方法**不发射** `pickup_landed`(见 `scripts/ui/pickup_flight_layer.gd:71-81`),于是"落地→笔记本 squash"链路零覆盖;
  3. 无 squash 效果断言(scale 变化 / tween 非空);
  4. 测试直接调用 `_on_pickup_unit_meta(...)`,从不通过 `RichTextLabel.meta_clicked` 发射——`meta_clicked.connect`(`scripts/babel_meme_game.gd:6349`)断线不会被发现。
- 修法:按 P0-1 验证方式补断言;补一条自然落地路径(await 至 `is_animating()==false`,断言收到 `pickup_landed` 且 notebook squash tween 启动);至少一条用 `emit_signal("meta_clicked", "门")` 走真信号。
- 验证:先改测试、跑一次确认在未修 P0-1 时红、修后绿(回归防护成立)。

### P1-2 "随机放在帖子里"未实现随机:字→帖为写死的手工分配,每局完全相同
- 维度:A 需求完整性(验收标准 1)
- 文件:`scripts/narrative/pickup_char_pool.gd:110-384`(POST_SEEDS 手工 units/line/comments)
- 判断(用户点名要求给出):**部分满足,需用户签字**。满足的部分——"20-30 个字分布在各帖"“帖文必含该字"(validator + 测试逐条强制,且埋字句/评论是真实自然语句,字确实出现在文本里,玩家点文本里的字拾取);不满足的部分——"随机"。当前没有任何运行时随机/种子变化:每一局、每一天,同一个帖子埋同样的字。辩护:仓库有"零随机、确定性"的强约定(飞行层测试甚至禁 randf),且"帖文必含该字"与"随机放置"天然互斥——随机放置要求模板化生成文案,质量会崩。手工分配是两者权衡下的合理工程选择,但它是对用户原话的**有意偏离**,不该默默通过。
- 修法(若用户要随机感):保留手工文案池,但按 `hash(day, post_id)` 做**确定性轮换**——每天只让每帖 units 的一个子集发光(其余字在其他天发光),既有"今天埋的字不一样"的随机观感,又零 RNG、可测试;或最低成本:向用户说明取舍并取得确认。
- 验证:用户确认;或新增"不同 day 发光集合不同、全池仍然全部可达"的断言。

## P2

### P2-1 拾取消耗当日最后一次行动时,飞行动画被日结黑幕吞掉
- 维度:C 边界情况
- 文件:`scripts/babel_meme_game.gd:6413-6415`(pickup → `_after_effective_action`)、`scripts/babel_meme_game.gd:5970-5975`(spend 动画完成即 `_play_day_transition`)、日结 overlay z=95(`:6002`)> 飞行层 z=90(`:6332`)
- 问题:探针实证——`actions_remaining=1` 时拾字:0.22s 后日结转场变为 visible,而飞行还在半途(`transition visible=true, flight animating=true`),"放大到正中央定格确认"的节拍在黑幕后面播完,玩家看不见。
- 修法:`_finish_action_spend_animation` 里若 `_pickup_flight_layer.is_animating()`,等 `pickup_landed` 再 `_play_day_transition`;或该场景把飞行层 z 提到 96。
- 验证:probe_pickflow.gd H/I/J 段重跑,断言转场可见时 `is_animating()==false`。

### P2-2 每日首拾后 0.22s 输入锁窗口内,后续免费拾取被静默吞掉
- 维度:C 边界情况 / B
- 文件:`scripts/babel_meme_game.gd:6403-6404`(`_on_pickup_unit_meta` 开头 `if _input_locked: return`)、`scripts/babel_meme_game.gd:5944`(spend 动画 `_set_input_locked(true)`)
- 问题:探针实证——首拾触发行动消耗动画锁输入;紧接着点第二个字(玩家宣传语是"之后当天免费"、自然行为就是连点)被无声丢弃:`collected 开 = false`,无 log、无反馈。
- 修法:拾字这类"免费跟拍"动作不该吃全局输入锁——`_on_pickup_unit_meta` 对 `pick_social_char` 的免费路径放行(锁只挡会花行动的操作);或首拾不播 `_play_action_spend_animation` 的锁(只播 HUD 数字动画)。
- 验证:连续两次调用 `_on_pickup_unit_meta`(帧间隔 1),断言两个字都进入 collected。

### P2-3 `_escape_bbcode` 对 "[" 的转义自我践踏,拾取文本一旦含方括号即产出坏 BBCode
- 维度:C 边界情况(用户点名"meta 值含特殊字符")
- 文件:`scripts/babel_meme_game.gd:5128-5129`(旧代码,但被新路径 `_pickup_bbcode:6377` 逐字调用而变得 load-bearing)
- 问题:`replace("[","[lb]").replace("]","[rb]")` 级联:第一步产出的 "]" 被第二步再替换,`"["` → `"[lb[rb]"`(探针实证:`门[b]开[/b]` → `[lb[rb]b[rb]...`)。当前池与文案无方括号,属**潜伏雷**;R2 计划(第 4 轮台词重写)会大改评论文案,踩中即渲染坏。
- 修法:先替 "]" 再替 "[",或经中间占位符;顺手给 `[url=%s]` 的 url 值加同样保护(当前 `matched` 未转义,依赖"池内无特殊字符"这一隐式约定,至少加注释或断言)。
- 验证:单测 `_escape_bbcode("[") == "[lb]"`;含 `[b]` 的文本经 `_pickup_bbcode` 后 RichTextLabel 渲染为字面方括号。

### P2-4 帖子正文本身不参与拾取渲染:字只在附加句和评论里发光,正文里的同字既不发光也不变灰
- 维度:A 需求完整性(验收标准 1 的观感)/ D 一致性
- 文件:`scripts/babel_meme_game.gd:4420`(post_text 为普通 Label 且过 `_corrupt`)vs `:4425-4428`(pickup line)
- 问题:用户的心智模型是"点帖子文本里的字"。实现是往帖详情追加一条"埋字句"+评论,正文未重写、不可交互:floor_13 正文含"出/在/开"等池字但死的,同屏下方同字发光——不一致。计划原文是"帖文重写为必然包含分配到的可拾取字",实际是"帖文旁边加了一句必然包含的话"。判定:验收字面(帖子里有相同的字、点文本拾取)成立,观感打折。
- 修法:正文也走 `_make_pickup_rich_text`(需先解决与 `_corrupt` 的互斥:污染替换会破坏单位匹配——可只在低污染时正文可拾,或正文豁免腐蚀);或最小改动:正文里已拾取的字同步灰化,保持"残留"叙事一致。
- 验证:打开 floor_13 详情,断言正文里的 `门` 与埋字句里的 `门` 状态一致。

### P2-5 英文大小写:句首大写的池词永不可拾
- 维度:C 边界情况(用户点名 "I vs i")
- 文件:`scripts/babel_meme_game.gd:6353-6392`(匹配区分大小写)
- 问题:探针实证 `"Door Open Exit No"` → 零高亮。authored 文案里每个词都保证有小写可拾位(validator 同为大小写敏感,已通过),所以**可达性没破**;但玩家会看到 "The place is still on the map" 里第二个 the 发光、句首 The 死掉,规律难猜。"I" 反向成立:池里是大写 I,小写 i 不存在,幸运闭合。
- 修法:匹配时 `to_lower()` 对比、显示保留原文、meta 用池内规范形;或维持现状但在埋字句写作规范里明文"池词必须出现一次小写形态"(现已隐式满足)。
- 验证:`_pickup_bbcode("The door")` 断言 The 与 door 行为符合所选方案。

### P2-6 日文子串匹配命中语法屈折:「歩いている」里的「いる」可拾
- 维度:C 边界情况 / A(验收标准 3 "日语拾假名/汉字词"的质量)
- 文件:`scripts/babel_meme_game.gd:6367-6369`(ja 无边界判定)
- 问题:探针实证 `でんきを消しても歩いている。` 中补助动词「いる」发光可拾,拾到的却计作本动词"いる(存在)"。同类:任何「〜ている」「〜にある」都会把 いる/ある 变成拾取点。机制不崩(反而多了拾取面),语言上是错的,ja 玩家会觉得诡异(也可辩称恐怖游戏的语言污染观感……但那是巧合不是设计)。
- 修法:ja 增加轻量边界:单位若前一字符是平假名且与单位同文字系统、且该位置处于更长连续假名串中段,则跳过(或简单地:池单位在文本中需两侧为非假名/标点/汉字);或文案侧避免 て形+いる 共现。
- 验证:`_pickup_bbcode("歩いている")` 不高亮 いる;`_pickup_bbcode("そこにいる")` 高亮 いる。

### P2-7 `pick_social_char` 不校验"该字确实出现在该帖"
- 维度:B 逻辑正确性 / D
- 文件:`scripts/meme_game_state.gd:1383-1410`
- 问题:只查池成员与重复,`post_id` 任意值都能拾成功(测试自己就在用 `pick_social_char("floor_13","door","en")` 这种正文里不存在的组合)。`source_post_id` 元数据因此不可信;未来 R3/R4 若按来源帖做叙事回溯会踩坑。
- 修法:状态层调 `PickupCharPoolScript.get_pickup_line/get_comments` 做一次 `contains_pickable_unit` 校验(或至少校验 post_id ∈ POST_SEEDS),不合法返回 `"not-in-post"`;测试改用真实组合。
- 验证:`pick_social_char("floor_13", "灯", "zh")` 应被拒。

### P2-8 词边界/转义逻辑三处重复,漂移即"能点"≠"validator 认为能点"
- 维度:D 代码质量
- 文件:`scripts/babel_meme_game.gd:6386-6399`(`_pickup_word_boundary_ok`/`_is_ascii_word_character`)vs `scripts/narrative/pickup_char_pool.gd:446-471`(`contains_pickable_unit`/`_is_word_character`)
- 问题:UI 点击判定与池 validator 是两份手写的相同算法;任何一侧改动(比如 P2-5/P2-6 的修复)都会让"测试绿"与"实际可点"脱钩——这正是本仓库最该防的一类回归。
- 修法:UI 侧改调 `PickupCharPool` 的静态方法(pool 已是 class_name 全局可见),删掉 babel_meme_game 里的两个私有副本。
- 验证:grep 无重复实现;test_pickup_char_flow 全绿。

### P2-9 <900px 窄屏下笔记本窗口在右侧,与"左上角"验收及 (84,64) 兜底互相矛盾
- 维度:A 需求完整性(验收标准 4)/ C
- 文件:`scripts/babel_meme_game.gd:3690-3704`(窄屏分支统一 TOP_RIGHT,无 notebook 特例)、`:6436`(兜底恒为左上角)
- 问题:宽屏下笔记本确实初始左上(`:3676-3683`,本轮前已有);窄屏下它贴右侧,修好 P0-1 后飞行会正确追踪右侧窗口(违背"左上角"字面但合理),而窗口关闭时的兜底 (84,64) 在窄屏语义错位(飞向空无一物的左上角)。
- 修法:兜底改为"若窗口存在但不可见,用其 rect 中心;完全不存在才用常量";窄屏分支给 notebook 加与宽屏一致的左上特例(或与用户确认窄屏布局豁免)。
- 验证:`_viewport_size()` 模拟 <900 布局跑 P0-1 的断言。

### P2-10 测试还有四个可点名的缺口
- 维度:E 测试覆盖
- 文件:`tests/test_pickup_char_flow.gd`
- 问题:
  1. 无"拾取消耗第 5 行动 → needs_day_settlement → 日结转场"的 UI 级测试(状态级是手动 `needs_day_settlement=true` 触发,绕过了 spend_action 路径);
  2. 无 bbcode 转义测试(P2-3 因此潜伏);
  3. en/ja 评论区渲染零断言(只测了 zh 的 header 与 text0);
  4. en 段依赖"上一步行动动画 0.22s 恰好在几个 process_frame 内解锁"的偶然时序(探针证实目前碰巧解锁;帧率变化即 `_open_social_post` 静默 no-op,断言将测到旧节点)。`_test_flight_layer_determinism` 用源码 grep 禁 randf——能接受但属于占位测试。
- 修法:补 1/2/3;4 改为显式 `while game_root._input_locked: await process_frame`。
- 验证:改后全绿,且人为把解锁时序拉长(如 spend 动画 1s)测试仍绿。

## P3

- P3-1 `_flight_tweens` 自然落地不清理(`scripts/ui/pickup_flight_layer.gd:68`,`_finish_glyph` 不 erase)——每局最多约 74 个死 Tween 引用,量级无害;顺手在 `_finish_glyph` 里 erase。另:`finish_all_immediately` 不发 `pickup_landed` 与自然路径不对称,至少加注释。
- P3-2 笔记本"拾到的字"瓦片是可点击 Button 但无任何 handler(`scripts/babel_meme_game.gd:4813-4821`)——R3 造句前建议 `disabled = true` 或 flat 样式,免得玩家狂点。
- P3-3 死代码:`PickupCharPool.get_post_units`(`:401`)无调用方;`set_meta("pickup_rich_text", true)`(`:6346`)无读取方。删或注明保留意图。
- P3-4 连拾多个字时字形在屏幕中央重叠定格(允许并发飞行,无错峰)——可给第二枚起加 0.12s 起飞延迟。
- P3-5 魔法数散落:`"8b8f84"`(collected 色,`:6358`)、`(56,40)`/`(84,64)`(`:6435-6436`)、squash 0.07/0.09(`:6448-6449`)——仓库风格(如 PickupFlightLayer 顶部 const 区)是提常量。
- P3-6 文案微瑕:station_lit 英文埋字句 "Last night it exists somewhere else."(为埋 exists 牺牲时态,读起来像语法错误而非闹鬼;R2 第 4 轮台词重写时留意);评论区多数帖仅 1 条,计划里"歪楼、断更"的楼层质感偏薄。
- P3-7 zh 池字跨帖发光(如 old_post_today 句中的"回"来自 last_bus 的分配)——非 bug(增加可达面),但意味着 POST_SEEDS 的 units 字段只是"保底声明"而非"该帖唯一发光集",维护者需知情(与 P1-2 的轮换方案相关)。

---

## 已验证达标项(证据)

| 验收 | 结论 | 证据 |
|---|---|---|
| 1. 20-30 字、帖内必含、玩家点文本拾取 | 达标(随机性除外→P1-2;正文交互观感→P2-4) | zh=30/ja=20/en=24 无重复;`validate()` 三语言 ok=[];12 帖全天可见(feed 不按日过滤,仅 `(day-1)*3` 轮换顺序,`babel_meme_game.gd:5406`),所有字 Day1 可达;详情窗有 `SocialDetailScroll`,评论可滚动触达 |
| 2. 评论区+匿名网友 | 达标 | 12 帖 × 3 语言均有 comments(handle/time/text),渲染于 `SocialComment*`;都市传说文风成立 |
| 3. 三语言主谓宾各≥2、可组完整句 | 达标(数据层;造句 UI 属 R3 轮次,合规) | role_word_counts:zh 7/9/8、ja 7/6/9、en 7/9/8(S/V/O),negation 均≥1;「门可以打开」五字全在 floor_13 一帖内可拾;en "door can be opened" 同帖闭环 |
| 4. 放大居中→缩入左上笔记本+squash | **不达标** | P0-1;居中放大/定格/缩小三拍与压暗、零随机本身实现正确(探针:自然落地 `pickup_landed` 两枚均发射、字形释放、backdrop 渐隐) |
| 5. 既有系统不回归 | 达标 | 34/34 测试实跑通过(test_hand_tracking_runtime 为设计内 opt-in skip);旧词签 pick_token/发布/存档/本地化路径未触碰;旧存档(无新字段)load ok、默认值兜底(探针);save 用 `store_var` 无 JSON 类型漂移;`collected_char_units` 混入脏数据不崩(探针);首拾扣 1 行动/当天免费/次日重扣/无行动拒绝(状态测试+探针) |

## 探针清单(可复跑)

- `/tmp/probe_notebook2.gd` — P0-1 三连实证(键错配/落点/拖动/squash)
- `/tmp/probe_pickflow.gd` — 输入锁时序、免费连拾被吞、en 切换渲染、末行动拾取日结与飞行遮挡
- `/tmp/probe_bbcode.gd` — 转义级联缺陷、en 大小写、ja 屈折命中、validate/role 计数/池查重
- `/tmp/probe_flight.gd` — 自然落地信号、字形释放、tween 数组滞留、旧存档兼容、脏数据鲁棒性

复跑:`HOME=/tmp/godot_home /root/work/godot_bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path /root/work/memes-minigame --script /tmp/probe_xxx.gd`
