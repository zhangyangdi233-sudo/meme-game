# Round 1 严格审查报告 — 60% 污染闪回重做(commit ead5a03)

审查者:独立 Critic。只挑错,不改代码。
对象:`feat: rebuild 60% pollution flashback as deterministic eight-beat director`
方法:逐相位对照分镜文档、逐行审读 director/游戏侧接线/测试、headless 实跑全部 33 个 GDScript 测试、音频 `--verify`、WAV 逐拍 RMS 测量、并向 /tmp 写了两个对抗性探针脚本(`probe_flashback.gd`、`probe_offsets.gd`)攻击双重日结、信号路径、null 纹理、重入、布局钉定等点。仓库文件零改动。

---

## 修复清单(按严重度)

### P0 — 必须修(破坏功能或契约)

**无。** 运行时行为与六项验收契约经实测全部成立(见文末"已验证通过项")。以下 P1 均不构成当前功能破坏,但其中两条是与分镜/旧行为的实质偏差,四条是"实现坏掉时测试不会变红"的防护缺口。

---

### P1 — 应修(实质偏差 / 边界或测试缺口)

#### P1-1 [A/B] 医生场错位量被双重应用:实际 24px,分镜承诺 12px
- 位置:`/root/work/memes-minigame/scripts/ui/pollution_flashback_director.gd:262` 与 `:268`
- 问题:`scenery.position.x += DOCTOR_OFFSET_PX`(262 行)之后,`chair_seat.position = Vector2(-140.0 + (DOCTOR_OFFSET_PX if is_doctor else 0.0), 10.0)`(268 行)又加了一次 12px。chair_back/legs/vacancy 全部以 chair_seat.position 为基准派生,于是医生场全部道具相对玩偶场偏移 **24px**。`docs/design/pollution_flashback_storyboard.md:27` 写明"椅子右错 12px";常量名就叫 `DOCTOR_OFFSET_PX = 12.0`,代码自相矛盾。今敏式匹配剪辑的"亚知觉级错位"被放大一倍。
- 建议:删除 268 行的第二次偏移(保留 scenery 根级偏移即可,所有道具自然继承)。
- 验证方式:运行 `/tmp/probe_offsets.gd`(headless,1600x900 布局后取 global rect):`doll chair global x: 660.0 / doctor chair global x: 684.0 / actual offset: 24.0`;vacancy 同样 24.0。

#### P1-2 [B/D] 闪回配色在 build 时烘焙,触发瞬间的污染调色板(PALETTE_5)拿不到 —— 相对旧实现是回归
- 位置:`/root/work/memes-minigame/scripts/babel_meme_game.gd:6075-6081`(仅在 `_build_flashback_overlay` 调一次 `configure_colors`);对照 `:5273` `_active_palette()`
- 问题:`_build_ui` 在开局(pollution=0)执行,`_theme_color` 返回 `PALETTE_1`;闪回触发的那一刻 pollution 恰好 ≥60,`_active_palette()` 已切到 `POLLUTION_PALETTE_5`,但 director 里存的是开局烘焙的旧色。两调色板在 director 用到的 4 个键上全部不同:`flash_text` 9CFF24 vs **39FF14**(荧光绿空方框、未记录卡片的主色)、`surface` FFF1C9 vs FFF2B8、`ink`、`accent`。被删掉的旧实现每个 scramble step 都实时调 `_theme_color("flash_text")`,即旧行为是"活取当前调色板"——本次改动把它变成了陈旧色。分镜 `empty_frames` 一拍写的"荧光绿"对应的正是 PALETTE_5 的 39FF14。
- 建议:在 `_play_pollution_flashback()` 里于 `director.play()` 之前重新 `configure_colors`(必要时 `build_phases()` 重建,或让颜色应用延迟到 play)。若"闪回刻意用污染前的记忆配色"是有意设计,必须写进分镜文档并加测试钉住,否则按回归处理。
- 验证方式:读 `scripts/babel_meme_game.gd:14-34` 两调色板逐键比对;确认 `configure_colors` 唯一调用点在 build 期;确认旧实现(`git show HEAD` 删除行 `_scramble_flashback_words` 内)逐步实时取色。

#### P1-3 [C/F] `_capture_frozen_frame_texture` 无 headless 守卫,每次 play 向 CI 输出喷 2 条引擎 ERROR
- 位置:`/root/work/memes-minigame/scripts/babel_meme_game.gd:6096-6106`
- 问题:headless 下 `viewport_texture.get_image()` 触发 dummy 渲染服务器错误 `ERROR: Parameter "t" is null. at: texture_2d_get (.../dummy/storage/texture_storage.h:106)` 并打印 GDScript 回溯,每次 `_play_pollution_flashback` 两条。null 守卫兜住了崩溃(测试仍过),但仓库自己的既有惯例——`_capture_phone_layer_for_xray`(`:870`)——明确检查 `DisplayServer.get_name().to_lower() == "headless"` 就是为避免这个。新代码违反既有风格且污染每一次 headless 测试输出,真错误会被淹没。
- 建议:照 870 行加同款 headless 早退(返回 null,走既有 ink 底退化路径,行为不变)。
- 验证方式:实跑 `Godot --headless --script res://tests/test_flashback_sequence.gd`,输出中出现 2 组该 ERROR + 回溯,backtrace 指向 `_capture_frozen_frame_texture (babel_meme_game.gd:6103)`。

#### P1-4 [E] 关键句"钉定"断言是永真式,句子被挪走测试也不红
- 位置:`/root/work/memes-minigame/tests/test_flashback_sequence.gd:104`
- 问题:`doll_sentence.position == doctor_sentence.position or doll_sentence.get_combined_minimum_size() == doctor_sentence.get_combined_minimum_size()` —— 两个 Label 文本、字号相同则 `get_combined_minimum_size()` 恒等,or 的右支永真。把医生句挪到屏幕任意位置(破坏"句子不动、世界替换"这一核心分镜不变量),断言照样通过。这是本拍最重要的视觉不变量,目前零保护。
- 建议:改为断言两 Label 的 `offset_left/right/top/bottom` 与 anchors 逐项相等(或布局一帧后 `get_global_rect()` 相等),删掉 or 右支。
- 验证方式:`/tmp/probe_flashback.gd` 复刻该表达式,把第二个 Label 挪到 (500,700) 后表达式仍为 true(输出 `TAUTOLOGY CONFIRMED`)。同时 `/tmp/probe_offsets.gd` 证实当前实现两句 global rect 确实相同(P:(370,768) S:(860,52)),即修断言不会使现状变红。

#### P1-5 [E] 真实玩法唯一会走的完成路径(信号路径)完全未被测试;连接断了 = 永久软锁,套件仍绿
- 位置:`/root/work/memes-minigame/tests/test_flashback_sequence.gd:142-160`(两处都是手动 `game_root._finish_pollution_flashback()`)
- 问题:实机上闪回结束只靠 `_complete_sequence → sequence_finished → _finish_pollution_flashback`。测试从不等待时间线走完,只手动调 finish。若有人删掉/改坏 `babel_meme_game.gd:6082` 的 `sequence_finished.connect(...)`,或 timeline 排布坏到走不到 `_complete_sequence`,游戏将停在全屏覆盖 + `_input_locked=true` 的永久软锁,而全套件仍 33/33 绿。这是本改动最危险的未防护失效模式。
- 建议:测试中加一段:play 后 `await` 至 overlay 自行隐藏(带帧数上限护栏),断言 day==2、`_input_locked==false`、`sequence_finished` 确实发射、且不叠加日过场——全程不手动调 finish。
- 验证方式:`/tmp/probe_flashback.gd` 实测自然完成路径当前是好的(约 3.55s 时间线在 headless 下 4.52s 墙钟走完,day 1→2,一次信号);但把 connect 注释掉的思想实验下,现有套件无任何断言会失败(finish 均为手动直调)。

#### P1-6 [E/B] "双重日结"幂等性——被点名的攻击点——行为正确但测试没钉住
- 位置:`/root/work/memes-minigame/tests/test_flashback_sequence.gd:157-160`
- 问题:信号已 emit 后再手动调一次 `_finish_pollution_flashback` 会怎样?实测答案:`consume_pollution_flashback()` 的 pending 检查(`meme_game_state.gd:808-812`)+ `settle_day_if_needed` 的 `needs_day_settlement` 双闸兜住了,day 不会 +2。但测试的"中途打断"段只断言 overlay 隐藏,**没有断言 day 仍是 2**;若未来有人把 consume 改坏(比如无条件返回 true),现有套件依然全绿。
- 建议:在第二次 finish 后补 `_assert_eq_int(game.day, 2, ...)`;再加"自然完成后又手动 finish 一次"用例(信号+直调双路径叠加)。
- 验证方式:`/tmp/probe_flashback.gd`:自然完成(day=2)后连续两次手动 finish,day 恒为 2;中断场景 settle 一次(day=3)后等 4.2s 无僵尸回调再结一天;双次 play 重启只产生 1 次 `sequence_finished`、只结 1 天(day=4)。行为全部正确——缺的只是回归防护。

---

### P2 — 建议

#### P2-1 [B/D] `_complete_sequence` 只置空 `_timeline` 并发信号,不隐藏自身
- 位置:`/root/work/memes-minigame/scripts/ui/pollution_flashback_director.gd:139-141`
- 问题:收尾隐藏完全依赖信号接收方回调 `stop()`。信号未连接(独立使用/连接被移除)时,全屏覆盖永久滞留。探针实测:standalone director 自然完成后 `visible=true` 留场。
- 建议:`_complete_sequence` 里先自隐(或直接内联 stop 的隐藏部分)再 emit;与 P1-5 联动可把软锁爆炸半径缩成"只剩 input 锁"。
- 验证:`/tmp/probe_flashback.gd` NOTE 行 `standalone director after completion: visible=true`。

#### P2-2 [A/F] 音轨"3.70s 含尾"的尾巴是 150ms 数字静默,且永远不会被听到
- 位置:`/root/work/memes-minigame/tools/generate_audio_assets.py:183`(`build_flashback_samples(3.70)`);`scripts/babel_meme_game.gd:6112-6113`(finish 无条件 `_flashback_audio.stop()`);`docs/design/pollution_flashback_storyboard.md:4,17`
- 问题:实测 3.55-3.70s 段 RMS=0.00000(纯零);时间线 3.55s 完成即 stop,尾段无论如何不可达。"含尾"的文档表述与实际都是死重。
- 建议:要么把合成时长裁到 3.55,要么让自然完成路径不 stop(留尾自然衰减)并只在打断路径 stop;同步修文档。
- 验证:python 解码 WAV 分段 RMS(mono/22050/3.70s,`unheard tail 3.550-3.700 rms=0.00000`)。

#### P2-3 [A] 环境底噪 duck 的时间形状与分镜相反:分镜"保持到 0.34 再 60ms 死",实现从 t=0 就快速死
- 位置:`/root/work/memes-minigame/scripts/babel_meme_game.gd:1437-1438`(0.38s、TRANS_QUINT、EASE_OUT——五次方 ease-out 前段骤降,~0.1s 内基本听不见);对照 `docs/design/pollution_flashback_storyboard.md:23`
- 问题:分镜 freeze 行承诺的"底噪保持到 0.34,随后 60ms 内死掉"只由新 WAV 内部的 room tone 实现(实测 WAV 0-0.34 RMS 0.203、0.36-0.50 衰减到 0.045 ✓);玩家一直在听的循环底噪却在 0.1s 内先消失,"声音先死"的戏剧时点被提前。两层声音的交接没被文档说明。
- 建议:duck 改 EASE_IN(或延迟 0.3s 后 80ms 快降),或在分镜里明确"hold 由闪回音轨承担、循环层立即淡出"。
- 验证:读 tween 参数 + WAV 分段 RMS 测量。

#### P2-4 [E] 三重回声测试只断言"缺的词不在",整行全空也能过
- 位置:`/root/work/memes-minigame/tests/test_flashback_sequence.gd:136-140`
- 问题:`not echo_row.text.contains(缺失段)` 对空字符串行恒真;行文本被清空、或段落 typo 导致整句错乱时不红。
- 建议:补正断言(每行包含另外两段)+ 结构断言 `"".join(SENTENCE_SEGMENTS) == KEY_SENTENCE`、`SECOND_SENTENCE.begins_with(SECOND_SENTENCE_CUT)`(两者当前均为 true,探针已验)。
- 验证:`/tmp/probe_offsets.gd` 输出 `segments join == KEY_SENTENCE: true`、`second cut is prefix of full: true`。

#### P2-5 [B/D] "z_index 最高"的契约表述与现实不符(继承自旧状态,本轮未恶化)
- 位置:`/root/work/memes-minigame/scripts/babel_meme_game.gd:6073`(=100);测试 `test_flashback_sequence.gd:95` 断言消息 "highest visual priority"
- 问题:语言选择 190、手机相机连接 205、相机授权 210、退出确认 220 都高于 100。经查 HEAD~1 这些值全部先于本 commit 存在,且四者均为菜单期覆盖层,闪回期间 `_unhandled_input` 被 `_input_locked` 拦死、设置窗被鼠标遮罩挡住,实际无法同屏——契约在"玩法期可见集合"内成立,但断言消息与验收表述都在过度承诺。
- 建议:测试改为断言"高于所有玩法期覆盖层"(day 95 / action 90——`test_day_transition.gd:45` 已有相对断言),或把闪回提到保留段位并更新文档措辞。
- 验证:grep 全部 `z_index` 赋值 + `git show HEAD~1` 比对 + 读 `_unhandled_input` 的 `_input_locked` 早退(`:610`)。

#### P2-6 [C] 存档若带 `pollution_flashback_pending=true`,载入后无人触发闪回/日结,会卡死(当前不可达,纯防御)
- 位置:`/root/work/memes-minigame/scripts/babel_meme_game.gd:665-721`(`_begin_game_session` 不检查 pending);pending 在存档字段表内(`meme_game_state.gd:231`)
- 问题:pending=true 时 actions=0,而唯一触发点 `_after_effective_action` 需要一次有效行动。实测确认闪回期间无法到达任何存档入口(`_save_progress` 仅 727/3432/3522 三处:回主菜单、设置手动存档、确认退出,全被输入锁/遮罩挡住;窗口叉掉不存档),所以正常游戏产不出这种档;但字段既然序列化了,手改档/未来改动就可能踩中。
- 建议:`_begin_game_session` 末尾若 `game.pollution_flashback_pending` 则直接 `_play_pollution_flashback()`(或静默 consume+settle)。
- 验证:grep `_save_progress()` 调用点 + `_unhandled_input` 输入锁早退 + 无 WM_CLOSE 拦截(grep 无 `NOTIFICATION_WM_CLOSE`)。

#### P2-7 [E] play() 是否按相位表顺序推进,除 freeze 外无测试
- 位置:`/root/work/memes-minigame/tests/test_flashback_sequence.gd:149-150`(只验了开场 freeze 可见)
- 问题:数据层(PHASES 连续性)与表现层(play 的 tween 排布)是两份代码;若 play() 漏排某相位或顺序错乱,数据测试照绿。
- 建议:加一个记录器(连每次 `_show_only_phase` 或轮询各 phase root 可见性)断言 9 相位按 id 顺序各出现一次。
- 验证:审读 play() 与测试覆盖面的差集。

#### P2-8 [D] `accent` 色被 configure 但 director 从未使用
- 位置:`/root/work/memes-minigame/scripts/ui/pollution_flashback_director.gd:46`、`scripts/babel_meme_game.gd:6079`
- 建议:删键,或真的用在某相位(分镜没有要求它)。
- 验证:grep director 内 `accent` 仅默认字典一处。

#### P2-9 [D] `_build_black_gap_a/_build_black_gap_b` 近重复
- 位置:`/root/work/memes-minigame/scripts/ui/pollution_flashback_director.gd:221-241`
- 建议:合并为 `_build_black_gap(phase_id, node_name, with_plate)`。
- 验证:两函数逐行比对,仅差一个 plate。

#### P2-10 [D] 无关文件混入 commit
- 位置:`/root/work/memes-minigame/scripts/narrative/language_corruption_content.gd.uid`
- 问题:编辑器自动生成的 .uid,与闪回无关,混进了本 feature commit。无害但污染 diff。
- 验证:`git show HEAD --stat`。

#### P2-11 [A/E] WCAG 闪烁预算帮助函数不计入入场/出场边界翻转,当前恰好贴着 3 次上限
- 位置:`/root/work/memes-minigame/scripts/ui/pollution_flashback_director.gd:53-67`
- 问题:内部翻转只有 2 次(0.50↓、2.95↑、3.30↓中任意 1s 窗最多 2);但 3.55s 结束瞬间 overlay 消失→亮色日结画面,是真实存在的第 4 次类别切换,落在 [2.95,3.95) 窗内凑满 3 次——仍合规,但余量为零且帮助函数看不见它。未来任何在尾段加一次翻转的改动会"测试绿、现实超"。
- 建议:帮助函数加虚拟出场(与入场)翻转,或在 PHASES 注释里写明"尾窗已满,不得再加翻转"。
- 验证:手算相位表 + 帮助函数逻辑复核;测试与帮助函数当前一致(都只看内部翻转)。

---

## 已验证通过项(实测证据)

| 验收点 | 结论 | 证据 |
| --- | --- | --- |
| 全量测试 | 33/33 通过(复现 commit 声称) | 循环跑 `tests/test_*.gd`,PASS=33 FAIL=0 |
| 音频确定性 | `--verify` 通过;仓库内 WAV sha256 与 `EXPECTED_SHA256` 一致(154a71cb…) | `python3 tools/generate_audio_assets.py --verify`; `sha256sum` |
| 音画对位 | WAV 逐拍 RMS 与分镜一致:底噪 0-0.34 → 死;gap A/B 纯零;布料 0.72-1.40;电话语音 1.64-2.32;耳鸣 2.37 起;门扣 2.60;残响 2.95-3.28 硬切;3.42 保存点击 | WAV 解码分段 RMS 测量 |
| 确定性 | director 无 randf/randi/randomize/shuffle(源码扫描 + 审读);音轨为固定种子 60013 合成 | 测试 `_check_determinism_source` + 人工审读 |
| 双重日结 | 信号自然完成 → day=2;其后 2 次手动 finish day 不变;中断、双 play、4.2s 僵尸回调观察均只结一天、一次信号 | `/tmp/probe_flashback.gd` 全绿 |
| null 纹理退化 | freeze/residue 隐藏 TextureRect、显示 ink 底,无崩溃;未 build_phases 的裸 director play 也安全 | 同上 |
| 契约保留 | 节点名/两方法名/PollutionFlashbackAudio 播放与 duck(`test_audio_runtime.gd:113-122`)/直接日结不叠加三秒过场(探针 + `test_day_transition.gd:115-120`)均在 | 实跑 + 读测试 |
| 关键句 | 两场同句逐字一致且 global rect 完全重合((370,768) 860x52);第二句切断形式正确且是全句前缀 | `/tmp/probe_offsets.gd` |
| 分辨率 | stretch=canvas_items、设计空间恒 1600x900,±430 偏移恒在屏内;`_apply_responsive_layouts_if_needed` 不触碰闪回覆盖层 | project.godot + 布局探针 |
| 暂停 | 全仓无 `paused` 使用,该边界不成立 | grep |
| 恰好 60 的先后顺序 | `change_pollution` 内先楼层请求后闪回检查;楼层切换只在日结边界静默 resolve,与闪回不冲突;所有 `change_pollution` 的 UI 入口都会走 `_after_effective_action` → 闪回即时播放,不存在悬挂 pending 的玩法路径 | 读 `meme_game_state.gd:674-686,800-805` + 6 个调用点核对 |

## 结论

**有条件放行。** 本轮把随机乱字黑屏换成了数据驱动八拍时间线,运行时行为经对抗性实测非常扎实:无 P0,双重日结、重入、打断、null 纹理、headless 全部安全,契约与音画对位均实测成立,33/33 全绿可复现。条件是 Round 2 必须清掉六条 P1:两条产品偏差(24px 双重错位 P1-1、烘焙陈旧调色板 P1-2)直接违背分镜/旧行为,应当即修;headless ERROR 喷射(P1-3)一行守卫的事;三条测试缺口(P1-4 永真式、P1-5 信号路径零覆盖、P1-6 幂等性未钉住)让"实现坏掉测试不红"的窗口敞着——尤其 P1-5,信号连接断裂等于永久软锁而套件全绿,不补上不能算这套时间线"被测试保护"。P2 按性价比自行取舍,P2-1(完成时自隐)与 P1-5 搭配修最划算。
