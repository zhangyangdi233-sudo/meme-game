# Round 3 Evaluator 判定(HEAD 325c815)

评定对象:Round 3 = 提交 1415810(feat)+ 325c815(fix)。对照用户最初目标与 docs/review/round3_critic.md / round3_fixes.md。
方法:git 核对 + 36 测试全量亲跑 + 7 个独立探针(/tmp/eval_p11_chain.gd、eval_p12_drag.gd、eval_p13_bei.gd、eval_p14_door.gd、eval_p15_tutorial.gd、eval_p15_confirm.gd、eval_p2_batch.gd),全部为本人在 HEAD 上实际运行所得。

**判定:带条件完成。** 五项最初目标全部实证达标或大部分达标;发现 1 条本人实锤的残留缺陷(发行版教程期玩偶/playtest 双窗未真正消除,根因一行,详见 §3.5),另有若干已记录在案的搁置项。无回归,无崩溃,主链路(含用户原文例句)端到端真实走通。

---

## 1. 仓库状态与测试

- `git log`:HEAD=325c815「fix: apply round-3 critic fixes…」,其前 1415810「feat: free sentence composer…」,与任务书一致;`git status --porcelain` 干净。
- **36/36 测试亲跑全绿**(逐文件 exit=0;含新增 tests/test_rule_engine.gd、tests/test_sentence_composer.gd 与全部 34 个旧测试)。`test_hand_tracking_runtime` 为设计内跳过打印,与前两轮行为一致。Builder「Full suite: 36/36」主张属实,零回归成立。

## 2. Critic P1 逐条核验(修复落点 + 探针实证)

### P1-1 第四层规则兑现不可见 → 已修(实证)
- 落点:`scripts/meme_game_state.gd:1596-1604`(锁存只置 `floor4_task_complete`,注释明示不立即解锁)+ `:1952-1959`(`_resolve_tower_step` 在日结边界才置 `ending_unlocked`,并压入「出口承认了你。」)。
- 探针 eval_p11(UI 全链,不改任何任务/结局旗标):第四层隐藏路线下真实拾字(station_lit 出/口/在/存)→ tap 入句 → `_on_composer_submit_pressed` 投稿 → **FloorFourExitFrame.visible=true、ending_unlocked=false、无 EndingScreen**、event log 见「出口开始存在。」、玩偶改口「出口存在了。…」;耗尽最后行动 → `_settle_day_and_present_rewards` → ending_unlocked=true、「出口承认了你。」、下一次 `_render` 才出 EndingScreen。**PASS(全部 20 断言)**。
- 仓内测试也已改走真实路径且不再绕过锁存(tests/test_sentence_composer.gd:125-138 状态链、:297-315 UI 链)。日结属计划 §2.4 允许的边界,时机合规。

### P1-2 可拖拽缺失 → 已修(实证)
- 落点:状态 API `scripts/meme_game_state.gd:1462-1479`(`free_sentence_place_at` 越界钳制、查重、需已拾取;`free_sentence_move` 钳制);UI `scripts/ui/composer_answer_tile.gd`(class ComposerAnswerTile **extends DraggableButton**,payload=composer_reorder,drop=插到本瓦片前)、`scripts/ui/composer_drop_area.gd`(class ComposerDropArea,面板空白=句尾)、词库瓦片为 DraggableButton 且携 composer_unit payload(`babel_meme_game.gd:6562-6575`)、统一落点处理 `:6617-6631`(reorder 的 from<to 减一修正正确)。
- 探针 eval_p12:插中/插头/越界钳制/重复拒插/未拾取拒插/头尾重排/非法 from 拒绝、三类节点类型断言、bank 与 answer 瓦片 `_get_drag_data` payload 断言、`_can_drop_data` 接受两类拒绝异类、三次模拟落点语义(拖到瓦片前=前插,拖到空白=句尾)。**PASS**。tap 为主 + 拖拽为辅,符合 critic 判断基准。

### P1-3 字池缺「被」→ 已修(实证)
- 落点:`scripts/narrative/pickup_char_pool.gd:17`(的→被,池仍 30 字)、`:57`(词典收 被/particle)、`:206-210`(extra_moon 评论文案改「…才被印上的。」并埋 没+被);diff 核对本轮对该文件改动仅此交换。
- 探针 eval_p13:`parse(门可以被打开)` → tier=rule、key=door|can_open;被 在池、的 已移出;埋帖文本确含字;三语言 `validate()` 全过;**真实拾取六字(含 extra_moon 拾「被」)→ 拼出用户原句「门可以被打开」→ 第三层投稿 → 规则生效 + 门任务完成**。**PASS**。仓内显式断言在 tests/test_rule_engine.gd:57-58。

### P1-4 世界侧门叙事缺失 → 已修(实证)
- 落点:`scripts/meme_game_state.gd:1194-1196`(第三层 key NPC 对话尾部,任务未完成时追加「这扇门是下一层的入口。它现在还打不开。」)+ EN/JA 词条 `state_catalog.gd:12,443`;封门 `babel_meme_game.gd:6437-6460`(StaticBody3D+BoxShape3D 碰撞盒)、开关 `:6422-6427`(门开后 `DoorCollision.disabled=true` 且门体隐藏、开门框显形)。
- 探针 eval_p14:真实对话 API 走完两问 → 反馈尾部含门叙事;**答错路径同样含**(前立更稳);任务完成后不再追加;UI 层门开前碰撞阻挡→投稿门规则后碰撞解除+门体退场+门框显形;`complete_floor_three` 门规则前拒绝、后放行。**PASS**。

### P1-5 旧系统未退役 + 教程指向已废 UI → 部分修复(含 1 条实锤残留)
- 已修并实证:教程两步文案改造句台措辞(`tutorial_director.gd:54`「把拾到的字点进句子…」、`:62`「把这句话投稿出去…」,无「句槽」);玩偶小窗为引导词唯一出口的**意图**落在 `babel_meme_game.gd:3898-3900`;玩偶窗题「缝线布偶」(`:6353`)统一、z=25 低于设置窗 30(`:6336`)、结局屏释放后 `_update/_toggle` 不崩(探针过)。
- **残留缺陷(CONFIRMED,探针 eval_p15_confirm)**:`_update_visibility()` 里另一处旧公式 `babel_meme_game.gd:5260-5262`(`_playtest_assist_enabled or not is_complete`,无 doll_guide_active 条件)在每次 `_render()` 末尾**覆盖** `_render_playtest_assist` 刚设的隐藏——发行版形态(playtest 辅助关)教程期稳态下**两窗同显**:第 1 步两窗同句「先找到我。别急着相信我。」;第 2 步起玩偶正常推进、playtest 面板**冻结在陈旧的第 1 步台词**(因其自身函数按新条件早退、从不再刷文案);教程完成后消失。测试与 Builder 自验均在 debug build(`_playtest_assist_enabled` 默认 true,面板合法显示测试提示)故未暴露。round3_fixes.md「playtest 面板不再双显同句」在发行版形态不成立。修复约一行(5262 补 doll_guide_active 条件或删该重复写)。
- 已记录搁置(理由核实属实):旧三槽退役延至 Round 4,契约 tests/test_main_scene.gd:126(NotebookCraftButton)确实存在;compose 步 focus_target 仍 "sentence_slots"、test_instruction 仍提「句槽」(仅 debug 文案);`submit_free_sentence` 仍连发 composed+published(`meme_game_state.gd:1559-1560`),造句台一次投稿两步连跳,发布步引导语无露出机会——critic 给的二选一中 Builder 只做了文案半支。

## 3. P2 抽查(3 条)+ 搁置复核

- **P2-1 重复投稿去重:PASS**(探针 eval_p2:三层/四层第二次同规则投稿 `floorX_task_completed`=false,event log 无重复门开行;落点 `meme_game_state.gd:1552-1556` before/after 旗标)。
- **P2-2 读档重扫:PASS**(探针:构造「规则激活+在三层+旗标 false」异常档,load 后自愈为 true;落点 `:478` load 尾 `_latch_ultimate_tasks_for_current_floor()`)。
- **P2-3 切语言清空:PASS**(探针:zh 入「门」→ `_on_language_selected("en")` → 造句台清空;两个入口 `babel_meme_game.gd:1668/3442` 均在)。
- 其余声明抽核:P2-5/2-6 新测试属实(120 全排列 test_rule_engine.gd:103-111、30×30 原始对拼 :113+、两字句「开门」:60-61、en/ja 提交 test_sentence_composer.gd:151-159、无行动置灰 :255-264、规则列表渲染 :289-295、碰撞断言 :273-288、边界解锁 :125-138);P2-7 失实注释已改写、否定前缀改「已被否定：」(diff 核对)。
- 搁置 3 条(入句瓦片先于飞行字/每帧全树查找仅 0.18s/全量重建渲染与仓风一致)理由成立、风险低,接受。
- 小瑕疵(不阻塞):ui_catalog.gd:46,574 残留两条无引用的「缝线玩偶」死词条;P2-4 的「双显消除」子项与 §2.5 残留为同一缺陷。

## 4. 对照最初目标

| 目标 | 判定 | 证据 |
|---|---|---|
| 1. 多邻国式造句:可拖拽且直观、无固定结构、自由拼装、随时投稿 | **达标** | 拖拽+tap 双路径(§2.2 探针);composer 无语法槽;≥1 单位随时投稿、空句/无行动拒投且句子保留(测试+探针);词库 ghost 不 reflow(仓测)。注:旧三槽仍并存于同页下方(搁置在案,教程已不再指向它) |
| 2. 投稿句在另一世界如同规则被遵守(门例句) | **达标** | 用户原句「门可以被打开」六字全链真实走通:拾字→拼句→投稿→门规则→封门碰撞解除+门框显形(§2.3/§2.4);世界先立「打不开」之说(key NPC 台词);rule/misread/noise 三层响应保每帖有回应 |
| 3. 第三层+第四层终极任务门槛 | **达标** | 第三层:门规则前 `complete_floor_three`=incomplete、后=normal-ending(探针);第四层:exit|exists 锁存→出口显形→日结边界才入隐藏结局(§2.1 全链探针);早写晚兑、否定不收回、重复不重报均实证 |
| 4. 玩偶全程可见、承担引导与教程 | **大部分达标** | 常驻、可拖、仅可折叠、无关闭钮,教程台词+楼层任务提示全程供词(探针);**残留**:发行版教程期 playtest 旧面板未真正退位,双窗同显/陈旧台词(§2.5);结局屏上玩偶随 canvas 释放(记录在案的取舍,已防崩) |
| 5. 零回归 | **达标** | 36/36 亲跑全绿(34 旧 + 2 新) |

## 5. Round 2 悬置项「随机放在帖子里」

**本轮无变化,如实记录。** POST_SEEDS 仍为 const 确定性埋点表(帖 id→固定单位),Round 3 对 pickup_char_pool.gd 的全部改动仅为 的→被 交换与对应文案(git diff 核对);pickup/rule 相关脚本无任何 randi/randf/shuffle。「随机」语义仍以「设计者预埋、玩家视角不可预期」的确定性方案代偿,与 Round 2 评定时的状态一致,悬置状态延续。

## 6. 放行意见

**带条件完成,可交付下一轮。** 条件(建议纳入 Round 4/5 修复循环,均小改):
1. `babel_meme_game.gd:5262` 旧可见性公式补 `doll_guide_active` 条件(或移除该重复写),消除发行版教程期双窗+陈旧台词(本轮唯一实锤残留,约一行);建议补一条 `_playtest_assist_enabled=false` 形态下的教程期 UI 测试防回归。
2. Round 4 兑现旧三槽退役承诺时,一并处理 focus_target="sentence_slots"、compose 步 test_instruction 的「句槽」措辞,并考虑拆开 composed/published 事件时机让发布步引导语有露出机会。
3. 顺手清理 ui_catalog.gd 两条「缝线玩偶」死词条。
