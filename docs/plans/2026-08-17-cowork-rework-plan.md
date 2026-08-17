# 2026-08-17 重构方案:闪回重做 / 台词去AI味 / 多邻国造句 / 句子规则引擎 / 拾取升级 / 终极任务

> 本方案综合四份深度研究(见 `docs/research/2026-08-17-*.md`),对照现有代码逐条落地。
> 配套研究:`flashback_deep_research.md`(闪回)、`dialogue_deep_research.md`(台词)、`sentence_rules_deep_research.md`(造句+规则)、`pickup_anim_deep_research.md`(拾取动效)。

---

## 0. 需求清单(两条消息合并)

| # | 需求 | 状态 |
|---|---|---|
| R1 | 重做 60% 污染闪回(现状:随机乱字黑屏跳切,过于简陋) | 本轮实现 |
| R2 | 台词去 AI 味(玩偶/医生/主角/NPC/论坛全部声部) | 第 4 轮 |
| R3 | 多邻国式自由造句:可拖拽、无固定主谓宾、随时投稿 | 第 3 轮 |
| R4 | 投稿句成为另一个世界的规则(门可以打开→门真的开) | 第 3 轮 |
| R5 | 第三层到达后有终极任务,完成才解锁结局;第四层同理,完成终极任务才进隐藏结局 | 第 3 轮 |
| R6 | 玩偶全程在玩家视线内,承担引导与新手教程 | 第 3 轮 |
| R7 | 瀑布流升级:20-30 个可拾取字藏在帖文里(帖文必含该字)、帖子加匿名评论区、拾取动画(放大居中→缩入左上角笔记本) | 第 2 轮 |
| R8 | 三语言各保证可组完整句,主谓宾词至少各 2 | 第 2 轮 |
| R9 | 每轮结束推送 GitHub;Builder/Critic/Evaluator 循环审查直到通过 | 持续 |

---

## 1. 同类开源项目对比(结论)

### 1.1 造句 UI(多邻国 word bank)

| 项目 | 技术线 | 优点 | 缺点 | 借鉴 |
|---|---|---|---|---|
| [jamsch/react-native-duo-drag-drop](https://github.com/jamsch/react-native-duo-drag-drop) | RN + reanimated | offset 单数组模型(-1=词库/≥0=答案位),撤销/重排/复位=改数组+统一补间 | RN 专用 | **数据模型直接翻成 GDScript** |
| [blmage/duolingo-word-bank-dnd](https://github.com/blmage/duolingo-word-bank-dnd) | 浏览器扩展 | 逆向证明官方 word bank 是 tap 优先、拖拽为辅 | 非组件 | 产品判断依据 + 键盘无障碍 |
| [Unolingo](https://github.com/ChinmayMhatre/Unolingo) | react-dnd | 最小两堆状态实现 | 教程级 | 快速理解 bank/answer 切换 |

**结论:tap-to-place 为主交互(点击字块飞入答案区),拖拽排序为辅;词库槽位永不 reflow(取走后留灰色 ghost);答案区 HFlowContainer 自动换行、永远无空洞。**

### 1.2 规则引擎(句子改变世界)

| 项目 | 技术线 | 优点 | 缺点 | 借鉴 |
|---|---|---|---|---|
| [Keke_JS / KekeCompetition](https://github.com/MasterMilkX/KekeCompetition) | JS,MIT | Baba 规则解析器约百行:规范式字符串规则表 + 属性派发 + 全量重算 | 网格前提 | **规则=数据、查表生效、脏了全重算,三件套移植** |
| [michaelzanggl JS 复刻](https://michaelzanggl.com/articles/baba-is-you/) | JS | onBeforeLand/onAfterLand 行为钩子 | 无 License | RuleReceiver 回调设计 |
| [R-033/babaisyou-godot](https://github.com/R-033/babaisyou-godot) | Godot 3,GPL | `ifRuleActive(名词,is,属性)` 查询接口形态 | GPL 只借思路 | 布尔查询 API |
| 《文字游戏》(Team9,非开源但机制同构) | — | "没有门"删"没"→门出现,中文玩家已验证的心智模型 | — | 否定词(不/没)入词库,作最强单字算子 |

**结论:受控词库(20-30 字)下用「词典最大匹配合词 → 主语×谓语×极性槽匹配」作主干(方案 a),少量正则模板处理剧情关键句(方案 b);语义嵌入不做。任何投稿都有三层反馈:命中→世界异变 / 误读→世界颤动嘲讽 / 噪声→雪花与改字转发,解析失败转化为恐怖演出。**

### 1.3 闪回表现(心理恐怖/视觉小说)

核心结论(详见研究报告):

- 范式取 **Mouthwashing 公式**:冻结当下→声音先死→硬切,天然防 jump scare;
- 叙事原型取 **今敏(Perfect Blue)同构匹配剪辑**:关键句恒定钉在屏上,背后世界(玩偶↔医生)整体替换——"不是台词变化,而是归属变化";
- **语言污染只污染元数据**:说话者名牌、引号「」↔『』、颜色;正文字形零污染且放最顶层,shader 采样不到;
- Signalis 式黑帧+文字卡可用但降频:黑帧是 150-250ms 的"阅读标点",不是频闪;
- 声音:底噪先死 400ms 作预兆,全程峰值 ≤BGM-6dB,最响的事件是静默;
- WCAG 2.2:任意 1 秒内全屏明暗切换 ≤3 次,写成单元测试断言。

### 1.4 拾取动效

节拍:按压 70-90ms → 弧线放大飞居中 320-380ms(QUINT/OUT)→ 居中定格 450-600ms(确认"拿到了什么")→ 加速缩入笔记本 280-340ms(CUBIC/IN)→ 笔记本 squash 受击 130-180ms → 帖内原字永久变灰。总长约 1.5s,连拾合并快进。飞行替身放专用顶层 CanvasLayer(躲开 ScrollContainer 裁剪),跨窗口坐标用 `get_global_transform_with_canvas()`,落点每帧读取以支持笔记本被拖走时追踪。缓动只用 Cubic/Quint/Expo,禁 Elastic/Bounce,聚焦靠压暗不靠发光——恐怖氛围适配。

---

## 2. 落地设计(对照现有代码)

### 2.1 R1 闪回重做(本轮)

现状:`_play_pollution_flashback()` 用 randf 乱撒 8 个词条 12 步跳动,与 `docs/design/pollution_flashback_storyboard.md` 的分镜完全脱节。

新实现:新建 `scripts/ui/pollution_flashback_director.gd`,数据驱动时间线(移除全部随机):

```
P0 0.00-0.50 冻结:viewport 截帧作静止背景,底噪 400ms 先死(音频预兆),画面完全不动
P1 0.50-0.70 黑帧(200ms 静默,只留一个空白说话者框)
P2 0.70-1.45 玩偶场:米白儿童椅构图(空位 motif),名牌「玩偶」,关键句完整打出:
              我只是想让你留在安全的地方。
P3 1.45-1.62 黑帧 170ms(阅读标点)
P4 1.62-2.37 医生场:同一构图右错 12px,名牌『医生』,同一句话(字形完全一致,引号体系互换)
P5 2.37-2.57 归属剥离:{del}玩偶{/del}{ins}医生{/ins} 独帧叠印(≥160ms,可读不可读之间)
P6 2.57-2.95 三张同构图垂直错位,各缺一个不同的词(我只是想让你/留在/安全的地方。)
P7 2.95-3.30 带残噪返回冻结帧,HUD 污染值已是 60;无名名牌显示第二共享句:
              你不需要再听见那个声音。(最后一字被切断)
P8 3.30-3.55 荧光绿空方框×3(中间一格缺一条边)→ 一帧「区域:未记录」(~120ms)→ 黑,结束
```

- 三层结构:Layer90 冻结帧 / Layer95 特效(撕裂、错位,hint_screen_texture)/ Layer100 文字安全层(关键句物理上不被 shader 采样);
- 关键句用作者预写污染版,正文字形零随机;
- 新音轨 `pollution_flashback_v2.wav`:布料摩擦、单次门扣(尾音反向)、电话带宽语音占位、低频房间声、编排静默,由 `tools/generate_audio_assets.py` 确定性合成(遵守仓库"无外部采样"约定);
- 新测试 `tests/test_flashback_sequence.gd`:断言相位顺序与时长、关键句完整存在、任意滚动 1s 窗口内明暗切换 ≤3、无随机 API 调用、结束后正常进入日结与退出可用。

### 2.2 R7/R8 瀑布流拾取升级(第 2 轮)

- 每层定义 `PICKABLE_CHAR_POOL`(zh:20-30 个单字;ja:假名/汉字词;en:单词),保证主/谓/宾各 ≥2,且覆盖规则引擎所需字(门/可/以/打/开/出/口/存/在/不/没/灯/亮…);
- 帖文重写为**必然包含**分配到的可拾取字;帖内可拾取字渲染为可点击高亮(RichTextLabel meta 或逐字 Label);
- 每帖新增 `comments: []`(匿名网友楼层,含时间戳、歪楼、断更,如月车站式格式,营造都市传说感);
- 拾取动画按 1.4 节节拍实现(`scripts/ui/pickup_flight_layer.gd`);帖内原字永久变灰(存档记录);
- 笔记本窗口保持初始左上角(现状已是),收字后 squash 受击一次。

### 2.3 R3/R4 造句 + 规则引擎(第 3 轮)

- 状态层:`LANGUAGE_RECIPE_SLOTS`(固定主谓宾三槽)退役,新增自由序列 `free_sentence: Array[token_id]`,API:place(index)/remove(index)/reorder/submit;≥1 字即可投稿(U19/U24);
- UI 层:`scripts/ui/sentence_composer.gd`——BankSlot 常驻双态(实体/ghost,U4)、tap 飞入(U6-U8)、tap 撤销飞回(U10-U11)、拖拽排序(U12-U15)、答案区下划线书写线(U16-U18);
- 规则层:`scripts/narrative/rule_engine.gd`(RefCounted、纯函数、可测):
  `parse(units) → {subject, predicate, negated} | MISREAD | NOISE`;
  规范式 `"door|can_open|+"` 存入 `state.world_rules`;世界侧只问 `is_rule_active("door","can_open")`;
- MVP 规则集(本轮 5 类):`door|can_open`(第三层门)、`exit|exists`(第四层出口)、`light|lit`(路灯亮起)、`door|locked` 的否定覆盖(不/没 极性)、`voice|silent`(闪回残响静默,彩蛋);同主谓新规则覆盖旧规则,negated 优先(Baba 冲突消解);
- 现行规则列表在笔记本可见(Baba"规则可见性"原则)。

### 2.4 R5 终极任务(第 3 轮)

- 第三层:key NPC 明说"这扇门是下一层的入口,但打不开"→ 玩家须拾字拼出「门可以打开」类句子并投稿 → 门开 → `floor3_task_complete=true`;`complete_floor_three()` 增加该前置,未完成不触发普通结局;
- 第四层:入口处"出口不存在"→ 玩家须拼出「出口存在」→ `floor4_task_complete=true` 才进入隐藏结局;
- 楼层转场检查时机不变(仅对话结束/场景结束/章节边界,遵守原规格 §3.5)。

### 2.5 R6 玩偶全程引导(第 3 轮)

- 新增常驻小窗 `DollGuideOverlay`(缝线玩偶立绘 + 一句话提示),手机视图与现实视图都可见、可拖拽、不可关闭(只可折叠);
- 接管 `tutorial_director.gd` 的当前步骤文案,玩偶声线输出(按台词声线卡);
- 保留 3D 层实体玩偶发现与三选一(Meme Frame 唯一来源不变)。

### 2.6 R2 台词去 AI 味(第 4 轮)

- 依据声线卡(玩偶 3-9 字短句/句号代替叹号/绝不用抽象词;医生 15-25 字完美语法/量化/人称降级;主角四级污染梯度)重写:`REALITY_DIALOGUES_BY_FLOOR`、`REALITY_FOLLOWUPS_BY_NPC_INDEX`、`DOCTOR_DIALOGUES_BY_FLOOR`、玩偶三选一、key NPC 两问、PROLOGUE/EPILOGUE、瀑布流帖文与评论;
- 负面清单执法:删点题癖/"不是A而是B"/三连排比/情绪命名/总结升华;
- 两组共享句原文保留(规格 §七);
- ja/en 目录(`state_catalog.gd`/`ui_catalog.gd`/`language_bridge_catalog.gd`)同步重译,`test_localization.gd` 保持全绿。

---

## 3. 轮次计划与验证

| 轮 | 内容 | 验证 |
|---|---|---|
| 1(本轮) | 研究报告 + 本方案入库;闪回重做 + 新音轨 + 新测试 | 全量测试 + 闪回时序断言 + WCAG 断言 |
| 2 | 拾取升级(字池/评论区/拾取动画/变灰) | 新增 test_pickup_flow + test_char_pool(主谓宾≥2×3 语言) |
| 3 | 自由造句 + 规则引擎 + 终极任务 + 玩偶引导 | test_rule_engine(全枚举可达句)+ test_ultimate_tasks + 现有全量 |
| 4 | 台词全量重写 + 三语目录 | test_localization + 声线规则抽查脚本 |
| 5 | Critic/Evaluator 循环修复 | 六维审查报告 + 修复清单闭环 + 渲染截图取证 |

每轮结束 push 到 `main`。审查采用三角色:**Builder**(主线程实现)/ **Critic**(独立子智能体,只挑错不改码,产出六维修复清单:需求完整性、逻辑正确性、边界情况、代码质量、测试覆盖、实际运行结果)/ **Evaluator**(独立子智能体,对照本表 R1-R9 判定是否真正完成,给出验证依据)。循环直到 Critic 无 P0/P1 且 Evaluator 判定通过。
