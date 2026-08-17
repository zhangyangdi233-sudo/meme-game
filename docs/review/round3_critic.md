# Round 3 Critic 审查报告(HEAD 1415810)

审查对象:free sentence composer / rule engine / ultimate tasks / doll guide。
方法:全量 diff 精读 + 计划文档(docs/plans/2026-08-17-cowork-rework-plan.md)与研究文档比对 + 36 个测试亲跑 + 4 个独立运行探针(/tmp/probe_full_chain.gd、/tmp/probe_edge_cases.gd、/tmp/probe_ui_edges.gd、/tmp/probe_floor4_instant_ending.gd)。

**结论:有条件放行。** 无 P0(无崩溃、无软锁、36/36 复核通过、主链路真实走通);但 5 条 P1 里 #1(第四层规则兑现不可见+结局时机违规)和 #5(旧主谓宾系统未退役、教程文案指向已废 UI)直接削弱本轮核心需求的达成质量,建议 Round 5 修复循环内闭环后再交 Evaluator。

---

## P1(显著需求/逻辑缺陷,应修)

### P1-1 第四层规则"被遵守"完全不可见:投稿瞬间切结局屏,出口道具永远不显形
- 维度:B 逻辑正确性 / A 需求完整性(R4"句子在另一个世界如同规则一样被遵守")
- 位置:`scripts/meme_game_state.gd:1573-1576`(`_latch_ultimate_tasks_for_current_floor` 中 `ending_unlocked = true`);`scripts/babel_meme_game.gd:3851-3855`(`_render()` 对 `ending_unlocked` 早退进 `_render_ending()`,跳过 `_render_status` → `_sync_ultimate_task_props`)
- 问题:第四层拼出「出口存在」→ 投稿 → `_after_effective_action` → `_render()` → 直接渲染结局屏。实测(probe4):`ending_unlocked` 提交即为 true,下一帧 `EndingScreen` 已存在,而 `FloorFourExitFrame.visible` 仍为 **false** —— "出口开始存在"这一世界侧异变从未被玩家看到,只剩一行 log。README 声称 "the exit frame starts existing" 与实际不符。同时违反计划 §2.4"楼层转场检查时机不变(仅对话结束/场景结束/章节边界)":结局在手机界面中途、一次点击内触发。第三层同任务是边界结算(`_resolve_tower_step`),两层行为不对称。
- 测试为何没抓住:`tests/test_sentence_composer.gd:1370-1373` 直接 `game.floor4_task_complete = true` 绕过了会同时置 `ending_unlocked` 的锁存函数,于是测试里出口框"可见",真实玩法里永远不可见。
- 建议修法:锁存里只置 `floor4_task_complete`,不置 `ending_unlocked`;隐藏结局改在边界兑现(日结 `settle_day_if_needed`,或与显形后的出口框交互时)。让玩家至少经历一次"回到现实层看到出口存在"的渲染循环。
- 验证:复跑 probe4,应看到 exit frame visible=true 且结局延后;补一条"经由锁存的第四层 UI 测试"(不许直接改 flag)。

### P1-2 "可拖拽"未兑现:造句台没有任何拖拽/重排交互
- 维度:A 需求完整性(用户原话"可拖拽且直观")
- 位置:`scripts/babel_meme_game.gd:6440-6520`(`_render_sentence_composer`,bank/answer 全部为普通 Button)
- 问题:实现为 tap-to-place + tap-to-withdraw。tap 优先有依据(研究文档 §1:多邻国网页版原生 tap-only,拖拽靠社区扩展补),**但计划自己把拖拽排序列为本轮范围(§2.3 "拖拽排序(U12-U15)"、研究 U12-U15"增强操作")且用户措辞明确是"可拖拽"**。现状连"重排"都做不到——要调语序只能撤回再追加(append-only),比多邻国实际体验差一档。仓库已有 `DraggableButtonScript`/`DropButtonScript` 基建(旧词库 token 就在用),成本不高。
- 判断:tap 为主可保留(达标依据充分),但拖拽排序为辅是本轮承诺,缺失=偏离,除非用户明确签字接受 tap-only。
- 建议修法:answer 区词块接入既有拖放基建做重排(U12-U15 简化版:按落点 x 计算插入位,`free_sentence_reorder(from,to)` 状态 API 补上);或最低限度先在 Round 5 明确向用户报备取舍。
- 验证:新增 reorder 状态测试 + UI 拖放测试(仓库已有 test_drag_controls 先例)。

### P1-3 字池缺"被":用户原文例句「门可以被打开」拼不出来
- 维度:A 需求完整性
- 位置:`scripts/narrative/pickup_char_pool.gd:14-18`(zh UNIT_POOLS)
- 问题:需求原文(研究文档开头引用)是"拼出『门可以被打开』→ 那扇打不开的门服从规则打开"。zh 字池 30 字无"被",玩家拼不出原文例句;只能拼「门可以打开」。实测(probe2-G):引擎对含"被"的序列容错良好——`["门","可","以","被","打","开"]` → `door|can_open` rule,"被"作 unknown 词被跳过,**加字即可用,零引擎改动**。对照英文池反而有 "be"+"opened"("door can be opened" 实测命中规则),中文玩家待遇不对称。
- 建议修法:zh 池加"被"(总数仍在 20-30 约束附近),埋进任一帖文(如 floor_13 评论"打不开的那种门"改造或新评论),`validate()` 会自动把守;可顺手在 test_rule_engine 加显式断言。
- 验证:test_pickup_char_flow(池完整性)+ 新断言 `parse(门可以被打开)` = rule。

### P1-4 世界侧叙事铺垫缺失:没人"先说过"门打不开/出口不存在
- 维度:A 需求完整性(需求暗含世界先立"打不开"之说,规则再推翻它)
- 位置:`scripts/narrative/language_corruption_content.gd:540-620`(第三层 key NPC「删句员」与 doll encounter 全文无门/入口叙事);`scripts/babel_meme_game.gd:6396-6432`(`_sync_ultimate_task_props`/`_ensure_task_prop_mesh`)
- 问题:计划 §2.4 明确"第三层:key NPC 明说『这扇门是下一层的入口,但打不开』"——该台词不存在;第四层"入口处『出口不存在』"也只剩玩偶浮窗一句话。世界侧的封门道具是一个 **无标签、无碰撞、无交互** 的黑盒(BoxMesh,街心 (0,1.6,-7)),玩家可以直接穿过去,走近按 F 没有任何反应;没有任何线索表明它是"下一层的入口"。"那扇打不开的门"在世界里从未被确立,规则生效的戏剧性(先立后破)失去支点。
- 建议修法:①第三层 key NPC 或 doll encounter 增加一句封门台词(第 4 轮台词重写正好顺路);②封门道具加 StaticBody3D 碰撞 + 靠近时 `_world_prompt` 提示("门。推不动。");③任务完成后开门瞬间加一次世界侧反馈(声音/灯光),而不是仅在下次 `_render_status` 静默换 visible。
- 验证:内容测试断言第三层含门叙事关键词;交互探针靠近门读 world_prompt。

### P1-5 旧主谓宾系统未按计划退役,教程文案指向已废交互
- 维度:A 需求完整性(用户原话"无固定主谓宾结构") / D 一致性
- 位置:`scripts/babel_meme_game.gd:4835-4849`(笔记本仍渲染"句子结构"对象/动作/去向三槽 + "确认组成句子"按钮);`scripts/meme_game_state.gd:35`(LANGUAGE_RECIPE_SLOTS 存活);`scripts/tutorial/tutorial_director.gd:50-64`
- 问题:计划 §2.3 第一条就是"LANGUAGE_RECIPE_SLOTS(固定主谓宾三槽)退役"——未执行。现在同一页笔记本上下并存两套造句系统:上方"自由造句"(无槽),下方"句子结构"(固定三槽),对玩家构成直接矛盾信号。玩偶承担的新手教程(R6)仍念旧系统的词:"把词放进**句槽**。先让它成为一句完整的话。"(focus_target 仍是 "sentence_slots"),而新造句台根本没有槽;且 `submit_free_sentence` 连发 `sentence_composed`+`sentence_published` 两个事件,一次投稿把教程"组句/发布"两步一口气跳过,发布步引导语没有露出机会。
- 判断:保留旧系统可能是零回归压力下的稳妥选择(旧梗/医生对话链依赖它),但"退役"是计划承诺,且教程文案已经错位。至少要做二选一:退役,或明确分区+改写教程步文案(compose 步指向自由造句台,拆开 composed/published 事件时机)。
- 验证:tutorial_director 步骤文案与 focus_target 更新后过 test_tutorial_director;UI 探针确认教程期两步分别露出。

---

## P2(应修的次级缺陷与打磨)

### P2-1 重复投稿同规则会反复宣布"第三层的门开了"
- 维度:B | 位置:`scripts/meme_game_state.gd:1518-1520`
- 问题:`result["floor3_task_completed"] = floor3_task_complete and rule_key=="door|can_open"` 用的是锁存后的**现值**,不是"本次是否新达成"。实测(probe2-D):任务完成后再次投稿门规则,flag 仍为 true → UI 每次都追加"第三层的门开了。"(第四层同理)。
- 修法:提交前先存 `was_complete`,`result = not was_complete and floor3_task_complete and ...`。
- 验证:state 测试断言第二次提交 flag 为 false。

### P2-2 load 后不重扫锁存(防御性缺口)
- 维度:C | 位置:`scripts/meme_game_state.gd:437-470`(load_save_data)
- 问题:实测(probe2-A)正常链路无恙:低层写规则→存→读→抵 3 层,`resolve_floor_transition_at_boundary` 会兑现,**不漏**。但"规则已激活+已在目标层+flag false"的存档(手改/异常写入/未来版本迁移)读入后永远卡门(probe2-B:complete_floor_three 持续返回 incomplete),无自愈路径。load 末尾补一次 `_latch_ultimate_tasks_for_current_floor()` 一行即防御。
- 验证:构造该存档断言 load 后 flag 为 true。

### P2-3 切语言不清空造句台,混语言句子静默变噪声
- 维度:C | 位置:`scripts/meme_game_state.gd:1436-1447` / `babel_meme_game.gd:_render_sentence_composer`
- 问题:zh 放入"门"后切 en:词库按 locale 过滤,但答案区照显"门",提交按当前 locale 解析 → 实测 tier=noise(probe2-F)。不崩溃,但玩家无从理解为何变噪声;bank ghost 判定也失配(en 词库里没有"门"可置灰)。
- 修法:`set_locale` 时清空(或按 locale 过滤)free_sentence_units,并提示一句。

### P2-4 玩偶浮窗层级/重复问题
- 维度:D/UX | 位置:`babel_meme_game.gd:6321`(z_index=40)、`2380-2392`(playtest 面板)
- 问题:①doll z=40 盖在设置窗(z=30)、历史窗(z=32)之上,且设置打开时 playtest 面板会藏、doll 不藏,行为不一致(probe1 实测 settings 打开时 doll 仍可见);②教程期非调试玩家会同时看到两个"玩偶"窗:右上旧 playtest 面板(标题"缝线布偶 / GUIDE")与左下新浮窗显示**同一句**引导词——计划说的是玩偶浮窗"接管"教程文案;③命名不统一:新窗叫"缝线玩偶",全仓库既有实体是"缝线布偶"。结局屏会 free 掉 `_ui_root` 连同玩偶(`_render_ending` 清 canvas),"从头到尾在视线内"在结局屏一刻终止——可接受但应是有意决定。
- 修法:z 降到 28 左右或设置打开时折叠;教程期隐藏 playtest 面板的 guide 行(非 debug);统一叫"缝线布偶"。
- 附:npc_up 现实视图下玩偶可见已实测通过(probe1),该项达标。

### P2-5 "全枚举"声明夸大
- 维度:E | 位置:`tests/test_rule_engine.gd:_test_exhaustive_enumeration`、README/commit 语句
- 问题:枚举空间是"词典词 ≤3 词序列",不是玩家真实输入空间(任意**单位**序列、任意长度)。实测原始单位乱序 `开+打+门` 也命中规则(probe2-G)——不在枚举空间内。规则键封闭性其实由 `SUPPORTED_RULES.has()` 构造性保证,枚举真正证明的是"每条支持规则可达+全空间不崩",README 的"proving the reachable rule set equals the supported table"措辞应收敛,或把枚举下沉到单位级(30 单位 ≤3 长度 ≈ 2.7 万序列,可跑)。

### P2-6 测试缺口清单
- 维度:E
- 无 en/ja 的 `submit_free_sentence` 路径测试(我已探针补测通过:en UI 全链、ja state 全链,probe3);
- 无"现行规则"列表渲染测试(probe3 实测有渲染,含 en 文案"· the door can open");
- 无"无行动时投稿按钮置灰"UI 测试(probe3 实测置灰正确);
- 无否定规则展示测试;
- 第四层 UI 测试绕过锁存(见 P1-1,正是漏掉大问题的缺口);
- 无重复提交去重测试(见 P2-1)。

### P2-7 规则引擎注释与死词
- 维度:D | 位置:`scripts/narrative/rule_engine.gd:100-103`
- 问题:注释"谓语兼作主语的中文单字(如 在/开)已被 continue 规避"失实——"在/开"不在任何 SUBJECT_CANON 里;三语言主/谓映射零交集,该 `continue` 目前是 no-op(留着无害,但注释误导后续维护)。另:PREDICATE_CANON 中 `是/想/stay/want/return_home` 等永远组不成表内规则(全部落 misread)——如果是刻意的"误读词汇",建议注释声明;"门是出口"这类 Baba 核心句式(X is Y)现落 misread,属 MVP 取舍,可接受但值得记录。
- 附:计划 §2.3 承诺的 5 类 MVP 规则只落地 3 类,`door|locked` 否定覆盖与 `voice|silent` 彩蛋静默砍掉("没门"实测 misread),commit message 未说明砍因。

### P2-8 文案与微交互
- 维度:D
- 造句台提示"点亮的字点一下入句"——词库瓦片并没有"点亮"态(点亮的是帖子里的字),表述错位;投稿消耗 1 行动在 UI 无任何告知(拾字有"第一次拾字消耗行动"的先例);
- 否定展示前缀"不再成立：门可以打开"在"从未成立直接否定"时语义不对(probe2-E),可改"不成立：";
- tap 入句时 `_render()` 同步重建让答案瓦片先于飞行字出现(0.18s 双影);`_composer_answer_target` 每 tween 帧全树 `_find_control_by_name`,而既有 `_notebook_flight_target` 走 `_draggable_windows` 字典,建议看齐;
- 折叠按钮 `_toggle_doll_guide_collapsed` 直接写中文"展开/折叠",en/ja 下要等下次全量 render 才被翻译(与既有 `_render_status()` 独立调用路径同类的旧疾,新代码延续了它);
- `_sync_ultimate_task_props` 用 `get_node_or_null("RealityFloor")` 而非成员 `_reality_floor`;道具颜色在创建时固化,不随主题/楼层调色变化;位置尺寸魔数无命名常量(仓库风格整体如此,权重低)。

---

## 六维结论摘要

- **A 需求完整性**:R3 造句核心达标(自由拼装/随时投稿/词库 ghost 不 reflow 全部实测成立);"可拖拽"缺失(P1-2)、"被"字缺失(P1-3)、世界侧铺垫缺失(P1-4)、旧系统未退役(P1-5)。"门是出口"→ misread(door|is 不在表内,MVP 取舍);玩偶 npc_up 可见实测达标(probe1)。
- **B 逻辑正确性**:引擎边角(开门/打开门/你是门/在存/没门/否定任意位置/ja ない/en no)全部实测且行为自洽;最大问题是第四层即时结局吞掉世界兑现(P1-1)与重复宣布(P2-1)。锁存语义(早写晚兑/否定不收回)实测正确。
- **C 边界情况**:0 字拒投、无行动拒投且句子保留、末行动投稿→日结转场完整走通(day 1→2)、JSON 存读后抵层兑现——全部实测通过;缺口是 load 不重扫(P2-2)与切语言残句(P2-3)。`_rebuild_reality_floor` 用 `free()` 立即清子节点,道具同帧重建,无重复创建(实测)。
- **D 代码质量**:整体贴合仓库既有风格(全量重建渲染、内联魔数是仓风);失实注释、节点查找方式、文案错位见 P2-7/P2-8。catalog 双语新增条目质量尚可,"投稿「%s」"模板经 `_compiled_templates` 正则通路可用。
- **E 测试覆盖**:新增两套测试方向正确(枚举思路好),但夸大声明(P2-5)+ 六个缺口(P2-6),其中"绕过锁存"直接漏掉了 P1-1。
- **F 实际运行**:36/36 独立复跑全绿(Builder 主张属实);4 个探针共 60+ 断言全绿;发现性 info 均已归档到上面各条。

## 放行意见

**有条件放行**:P1-1 与 P1-5 建议本轮修复循环内解决(前者是核心奇幻时刻被吞,后者是教程自相矛盾);P1-2/P1-3/P1-4 至少要给出明确取舍记录或低成本补齐(加"被"半小时内可完成)。P2 项可随第 4 轮台词重写与第 5 轮修复循环消化。
