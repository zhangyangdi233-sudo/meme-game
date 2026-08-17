# 研究报告:多邻国式造句 UI × "句子成为世界规则"机制
> 项目背景:Godot 4.6 中文心理恐怖游戏。玩家在手机"瀑布流"贴文中逐字拾取汉字(日/英版拾取假名词/单词)存入笔记本,在完全仿多邻国的拖拽造句界面自由拼句并"投稿",投稿句成为 3D 现实层的世界规则(如拼出"门可以被打开"→ 那扇打不开的门服从规则打开)。
> 本报告 = 交互验收清单 + 开源项目对比 + 规则引擎选型 + Godot 实现方案。日期:2026-08-17。

---

## 0. 摘要(结论先行)

1. **多邻国官方 word bank 本质是 tap-to-place 优先、拖拽为辅**:网页版原生只有点击,社区甚至专门做了扩展 [duolingo-word-bank-dnd](https://github.com/blmage/duolingo-word-bank-dnd) 来"补上"拖拽;移动端才有拖拽。因此本作应以"点击词块飞入答案区"为主交互、拖拽排序为增强,开发量最小且手感最接近原版。
2. **最佳参考实现是 [jamsch/react-native-duo-drag-drop](https://github.com/jamsch/react-native-duo-drag-drop)**:它的"offset 数组"数据模型(-1=在词库,≥0=答案区第 n 位)+ 词库固定占位(ghost)+ 答案区 reflow,可直接翻译成 GDScript。
3. **规则引擎推荐方案 (a)+(b) 混合**:受控词库仅 20-30 字,句子空间有限、可枚举——用"词典最大匹配分词 → 主语×谓语×极性 槽匹配"作主干,少量正则模板处理特殊剧情句;语义嵌入(方案 c)在此前提下是负资产,只可作可选容错层。这正是 Baba Is You(封闭词表+全量重算)与《文字游戏》(预设汉字操作)共同验证过的路线。
4. **Baba Is You 的两条工程金律**可直接移植:规则是数据不是代码(存成 `主语-谓词` 规范式,世界侧查表);词块变动才重解析(脏标记),解析结果全量重建、不做增量。

---

## 1. 主题一:多邻国式造句 UI

### 1.1 交互细节清单(编号,可直接作验收标准)

依据:对多邻国 iOS/Web 版的逐帧观察、[blmage 扩展对官方 DOM 行为的逆向描述](https://github.com/blmage/duolingo-word-bank-dnd)、[jamsch 组件](https://github.com/jamsch/react-native-duo-drag-drop)的参数默认值、[微交互分析文章](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682)、[60fps.design 的 Duolingo 动效库](https://60fps.design/apps/duolingo)、[Duolingo 官方写作教学博文](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-writing-skills/) 与 [Duolingo Wiki 练习类型页](https://duolingo.fandom.com/wiki/Exercise)。

**A. 词库(Word Bank)区**
- U1 词块为圆角矩形(圆角约为高度的 1/4),白底、细描边、底部 2px 阴影边("按钮浮起"感);按下时阴影消失、词块下沉 2px。
- U2 词库使用居中对齐的自动换行流式布局;词块间隙约 4-8px、行高约为词块高的 1.2 倍(jamsch 默认:wordHeight 45、wordGap 4、lineHeight=1.2×wordHeight)。
- U3 词块宽度由文本实测宽+左右 padding 决定,不等宽;中文版一字一块时可近似等宽。
- U4 **词库槽位永不 reflow**:词块被取走后,原位留下同尺寸灰色凹陷占位(ghost/placeholder),其余词块不移动——玩家凭空间记忆找词。
- U5 词库中的词块顺序在题目生成时打乱,之后固定不变。

**B. tap-to-place(主操作)**
- U6 点击词库词块:词块本体变为灰色 ghost,同时一个浮动副本从原位**飞行**到答案区末尾(官方称 flying words 动画;blmage 扩展甚至提供"Tone down word animation"选项弱化它)。
- U7 飞行时长约 0.15-0.30s,ease-out;落点提前计算(答案区先插入隐形占位再飞)。
- U8 落地瞬间有轻微 pop(scale 1.0→1.05→1.0)或下沉回弹;整个过程不阻塞连续快速点击(可同时有多个词块在飞)。
- U9 点击词块时朗读该词(TTS;blmage 扩展有"Do not play TTS when adding words"开关,证明原生默认播放)。本作可换成"角色低声念字"——恐怖化改造点。
- U10 点击答案区中的词块 = 撤销:词块从答案区**飞回**词库原 ghost 位,ghost 复原为实体;答案区其余词块 reflow 补位。
- U11 撤销不限次数、无惩罚;可逐个拆到空。

**C. 拖拽(增强操作,移动端行为)**
- U12 长按/按住并移动即进入拖拽:原位留 ghost,指尖处显示放大约 1.05-1.1 倍、带阴影的预览。
- U13 拖入答案区时,按落点 x/y 实时计算插入序号,已有词块**让位**(reflow 动画约 0.1-0.2s);拖拽可用于答案区内重新排序。
- U14 拖到无效区域松手:词块动画飞回原位(不是瞬移)。
- U15 tap 与 drag 共存判定:位移 < 阈值(约 8-10px)且时长短 → 视为 tap。

**D. 答案区**
- U16 答案区为 1-3 条带下划线的横线(像作业本);词块沿线排列,满行自动换行到下一条线(jamsch 用 renderLines 自绘线条)。
- U17 答案区永远保持"无空洞":任何移除/插入都触发全体 reflow 平滑动画。
- U18 **没有语法槽位**:不存在"主语槽/谓语槽",任何词能放任何位置、任意顺序、任意数量——自由度完全交给玩家(这正是本作需要的"自由拼装")。

**E. 提交与反馈**
- U19 提交按钮(本作:"投稿")在答案区为空时置灰禁用;≥1 词块即点亮。
- U20 原版:答对→绿色横幅从底部弹出+清脆"叮"声;答错→红色横幅+低沉"boing"声(微交互文章原话:"cute chirps for correct answers, playful boings for mistakes"),并配 confetti/进度条脉冲等强化。本作改造:投稿后不判对错,改为"发送中→已投稿"的社交 App 式反馈,再由 3D 世界的异变充当"判定动画"。
- U21 每次点击、落位、撤销、提交各有独立短音效;音效与视觉信号成对出现(可达性原则)。
- U22 触觉:移动端 tap 落位有轻震动(Godot 手机端可用 `Input.vibrate_handheld(20)`,PC 略)。

**F. 本作特化验收项**
- U23 词库来源是玩家拾取的字(笔记本),数量 20-30,支持滚动或分页;未拾取的字不出现。
- U24 "随时可结束":投稿无长度/语法门槛,单字也可投稿;投稿后词块是否消耗(一次性)需设计决策——建议不消耗,鼓励实验。

### 1.2 开源实现研读(word bank 组件)

- **[jamsch/react-native-duo-drag-drop](https://github.com/jamsch/react-native-duo-drag-drop)**(最完整):数据模型是 `words: string[]` + `offsets: number[]`,-1 表示在词库、非负表示答案区序号;`getWords()` 返回 `{answered, bank}`;`setOffsets()` 可编程驱动全体词块动画归位。动画用 reanimated worklet(withTiming/withSpring),暴露 `animatedStyleWorklet(style, isGestureActive)` 自定义拖拽中样式;`renderPlaceholder` 渲染灰色占位(绝对定位),`renderLines` 自绘答案线;手势层 pan+tap 双识别。**可借鉴:offset 单数组模型让"撤销/重排/编程复位"都变成改数组+统一补间,非常适合翻成 GDScript。**
- **[blmage/duolingo-word-bank-dnd](https://github.com/blmage/duolingo-word-bank-dnd)**(浏览器扩展):证明官方网页版 word bank 原生 tap-only;扩展补拖拽与键盘操作(方向键选词、Ctrl+方向移动、Delete 删除),并有 flying words 动画开关、TTS 开关。**可借鉴:键盘无障碍方案;以及"tap 为主"的产品判断依据。**
- **[RafaelGoulartB/duolingo-drag-and-drop](https://github.com/RafaelGoulartB/duolingo-drag-and-drop)**(React Native + Expo,教程级):结构简单,适合快速理解两堆(bank/answer)状态切换的最小实现。
- **[Unolingo(ChinmayMhatre)](https://github.com/ChinmayMhatre/Unolingo)**([文章](https://dev.to/chinmaymhatre/the-duolingo-drag-and-drop-quiz-component-1g60)):react-dnd + Tailwind 的网页实现,展示纯 DOM 方案的拖放事件绑定。

### 1.3 Godot 4 实现要点

两条技术路线:
1. **内建拖放协议**:`Control._get_drag_data()` 返回携带 `{token, from}` 的数据并 `set_drag_preview()`;目标区 `_can_drop_data()` 校验、`_drop_data()` 落位;`NOTIFICATION_DRAG_END` 里处理"拖到虚空取消→ghost 复原"。参考 [Godot Control 文档](https://docs.godotengine.org/en/stable/classes/class_control.html)、[入门文章](https://medium.com/godot-dev-digest/drag-and-drop-basics-in-godot-a-beginners-guide-313277975e06)、[dev.to 教程](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13)。局限:预览节点样式受限、无法做"松手飞回"补间(drag 结束即瞬移),也不覆盖 tap。
2. **自绘状态机(推荐)**:tap 与 drag 都自己管——`gui_input` 里做"位移阈值"判定(U15);飞行动画用 `create_tween()` 补间浮动副本的 `global_position`(参考 [Tween 文档](https://docs.godotengine.org/en/stable/classes/class_tween.html)、[Godot 4 Tween juice 教程](https://codingquests.io/blog/godot-4-tween-tutorial-juice))。布局用 [HFlowContainer](https://docs.godotengine.org/en/stable/classes/class_hflowcontainer.html) 自动换行 reflow。**关键坑:容器每帧接管子节点位置,不能直接对容器内节点做位置补间**——解法是"占位+飞行层"模式:目标容器先插入透明占位 Control,`await get_tree().process_frame` 拿到布局后的 `global_position` 作为落点,浮动副本在顶层 FlyLayer 补间过去,到位后删副本、占位变实体。词库侧因 U4 根本不 reflow,直接用固定 BankSlot(每槽常驻,内容切换 实体/ghost 两态),天然规避该坑。

---

## 2. 主题二:"句子成为世界规则"

### 2.1 Baba Is You:规则解析的标准答案

来源:[Arvi Teikari GDC 2020《Reading the Rules of Baba Is You》讲稿 PDF](https://media.gdcvault.com/gdc2020/presentations/Reading%20the%20rules_Teikari_Arvi.pdf)([GDC Vault 视频](https://gdcvault.com/play/1026628/Reading-the-Rules-of-Baba)、[Game Developer 报道](https://www.gamedeveloper.com/design/video-understanding-the-rules-of-i-baba-is-you-i-))、[设计访谈](https://www.gamedeveloper.com/design/designing-i-baba-is-you-i-s-delightfully-innovative-rule-writing-system)、[JS 复刻拆解文](https://michaelzanggl.com/articles/baba-is-you/)、[Keke AI 竞赛框架源码](https://github.com/MasterMilkX/KekeCompetition)。

- **规则三元组**:Object(哪个对象)- Verb(如何作用)- Quality(什么效果),即 `BABA IS YOU`。
- **解析三步**(GDC):① 找候选句起点,沿"左→右、上→下"扫出 ≥3 词序列;② 校验词类顺序合法性(`YOU ROCK` 这类被剔除);③ 转成游戏逻辑格式并做冲突消解(`BABA IS NOT YOU` 覆盖 `BABA IS YOU`)。
- **语法迭代了至少 5 版**:AND 连接、条件词 ON/NEAR/FACING、前缀词 LONELY、可多层嵌套的 NOT。Teikari 承认"追求完美解析是徒劳",最难的是同格堆叠词块(整个系统曾假设一格一词,重写代价极大)。**教训:语法每加一个词类,解析复杂度超线性上升——本作第一版语法应锁死在"主语+(否定)+谓语"。**
- **性能策略**:仅当词块移动/变化时才重解析(脏标记变量);[JS 复刻](https://michaelzanggl.com/articles/baba-is-you/) 与 [Keke_JS 模拟器](https://raw.githubusercontent.com/MasterMilkX/KekeCompetition/main/Keke_JS/js/simulation.js) 都采用**全量重算**而非增量:清空规则表→重扫→重派发属性。
- **Keke_JS 源码细节**(MIT,读自 simulation.js `interpretRules()`):以所有 `IS` 词块为锚点,查其左右/上下邻格是否为词,命中即生成规范式字符串 `"baba-is-you"` 存入 `state.rules`;随后 `transformation()` 处理名词→名词的变形规则,属性规则由各查询函数(`rules.includes("you")` → 汇入 players 数组等)派发到实体分组。**可借鉴:规则=规范式字符串集合 + 属性派发表,世界侧只问"某名词是否具有某属性"。**
- JS 复刻另给出实体行为挂钩:`onBeforeLand`(STOP 拦截移动)/`onAfterLand`(触发效果),PUSH 用递归推动实现;撤销用时间线数组。

### 2.2 "玩家语言改变世界"的同类游戏

- **《文字游戏》(Word Game,Team9,2022,重点)**:[Steam 页](https://store.steampowered.com/app/1109570/Word_Game/?l=schinese) 明言"字不只是字,同时也是物件、人物与场景",玩家操控主角"我",通过**删字**("没有门"删掉"没"→门真的出现——与本作"门可以被打开"的案例完全同构!)、**推字、拆字、组字**颠覆句义解谜,多结局。[GameLook 报道](http://www.gamelook.com.cn/2022/01/470690/) 称其 Steam 好评 94%、全程无图只有汉字;[机核文章](https://www.gcores.com/articles/194312) 记录团队起点是"蚕宝宝会结茧(节俭)"的谐音谜语、黑底白字美学与关卡编辑器生态([indienova 访谈](https://indienova.com/indie-game-news/interview-team9-word-game/) 亦可参照)。**对本作启示:①"改一个字=改一条世界事实"的心智模型已被中文玩家验证接受;② 否定词(没/不)是最强的单字算子,应进玩家词库;③ 汉字可拆合是中文版独有资源(恐怖向:拾到"门"+"人"可组"闪"?)。**
- **Scribblenauts / Super Scribblenauts**:输入名词即召唤对象、[形容词可叠加修改属性("绿色冰箱"、"巨大飞行紫色章鱼")](https://en.wikipedia.org/wiki/Super_Scribblenauts);本质是**数万词条→预制对象+属性标签**的巨型查表([词库分析](https://lil.law.harvard.edu/blog/2010/03/19/why-is-scribblenauts-so-cool/)、[百科](https://scribblenauts.fandom.com/wiki/Scribblenauts_(video_game)))。启示:自由输入的代价是海量内容;本作反其道行之——**词库由关卡投放,拾取即授权**,内容量可控。
- **Typoman**:[推字母拼词即时改变环境](https://en.wikipedia.org/wiki/Typoman)(拼 RAIN 降雨、OPEN 开门),含反义词消解谜题([评测](https://techraptor.net/gaming/reviews/typoman-revised-review-words-hurt))。启示:**词生效瞬间要有夸张的世界反馈**,玩家才能建立因果。
- **Chants of Sennaar**:观察语境→[笔记本里给字形配图验证→翻译解锁区域](https://roomescapeartist.com/2023/11/18/focus-entertainment-chants-sennaar-review/)([评测](https://gameluster.com/chants-of-sennaar-review-quintetlingo/))。启示:**笔记本既是词库也是"理解进度条"**,本作拾字笔记本可仿其"未确认词义→确认"两态。
- **补充参照**:[OneShot](https://en.wikipedia.org/wiki/OneShot)(meta:游戏外操作改变游戏内世界)与 [The Stanley Parable](https://en.wikipedia.org/wiki/The_Stanley_Parable)(叙述规则与玩家行为互相改写)——为"投稿句改写现实层"的叙事包装(系统弹窗、伪 App 通知)提供 meta 手法参照。

### 2.3 规则引擎三方案对比(前提:词库受控 20-30 字)

关键前提带来的两个决定性优势:① 输入天然已"分词到字"(词块即 token),只需把连续字合并成词典词——用[正向/逆向最大匹配](https://www.52nlp.cn/maximum-matching-method-of-chinese-word-segmentation)([算法详解](https://www.cnblogs.com/zongfa/p/15141087.html)、[知乎实现](https://zhuanlan.zhihu.com/p/103392455))即可,词典仅几十条,歧义可穷举测试;② 句子空间有限(30 字、句长≤8 → 可离线枚举全部可达句做回归测试/敏感词审查)。

| 方案 | 做法 | 优点 | 缺点 | 结论 |
|---|---|---|---|---|
| (a) 关键词槽匹配 | 最大匹配合词后,在词包中抽取:主语(实体词表)×谓语(谓词词表,含同义组 开/打开)×极性(不/没) | 确定性、可调试、可作弊表全枚举;对语序宽容(中文"门被打开可以"也能容);零依赖、离线 | 语义表达力=词表×词表,新规则要配内容;长句多主语需消歧策略 | **主干,采用** |
| (b) 模板/正则 | 有序模板如 `门(可以)?被?(打开|开)`;或对整句做精确匹配 | 可锁定剧情关键句(唯一解谜句、成就句);可表达语序敏感的特例 | 模板爆炸、对自由语序脆弱;维护痛苦 | **辅助层:仅剧情句+修饰语提取** |
| (c) 语义嵌入 | 句向量相似度(如 [paraphrase-multilingual-MiniLM-L12-v2](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2),先例:[Semantle](https://en.wikipedia.org/wiki/Semantle) 用 word2vec 距离做玩法) | 容错强、三语言一套;"接近但不中"可量化 | Godot 需 GDExtension/ONNX 集成;结果不可解释,恐怖游戏的规则判定必须可预期;20-30 字前提下毫无必要 | **不作核心**;至多离线预计算全部可达句向量,做"相近规则提示"彩蛋 |

**推荐架构(a 主 b 辅)+ 三层响应设计**(心理恐怖特化):
1. 完全命中 → 规则生效,世界异变;
2. 主语命中、谓语不在表 → 世界"误读"你的句子(恐怖素材:门微微颤动但不开、贴文区出现嘲讽回帖);
3. 无法解析 → 世界以噪声回应(雪花屏、已投稿句被"网友"改字转发)。
这样"任何投稿都有反馈",自由拼装不会落空,同时把解析失败转化为恐怖氛围资产。

### 2.4 规则数据模型(借鉴 Baba 系)

```gdscript
class_name Rule
var subject: StringName    # 规范实体 id:&"door"(同义字表映射:门/大门→door)
var predicate: StringName  # 规范谓词:&"can_open"(打开/开→can_open)
var negated: bool          # 不/没
var source_text: String    # 原句(笔记本回放、"转发"演出用)
```
- 规范式字符串 `"door|can_open|+"` 作字典键去重——同 Keke_JS 的 `"baba-is-you"`。
- 冲突策略学 Baba:同主谓的新规则覆盖旧规则、`negated` 优先(`BABA IS NOT YOU` 覆盖正例);全部现行规则列表展示在笔记本(=Baba 把规则铺在关卡里的"规则可见性"原则)。
- 重算策略:投稿即全量重派发(规则条数 <几十,无性能问题);世界对象只暴露 `RuleBroker.is_active(&"door", &"can_open")` 查询——同 R-033 Godot 克隆的 `ifRuleActive(名词,"is",属性)` 查询形态。

---

## 3. 开源项目对比表

**规则/世界侧(4 个)**

| 项目 | 功能 | 架构 | 技术线 | 优点 | 缺点 | 对本作可借鉴 |
|---|---|---|---|---|---|---|
| [MasterMilkX/KekeCompetition (Keke_JS)](https://github.com/MasterMilkX/KekeCompetition) | Baba 完整模拟器+AI 竞赛框架 | `interpretRules()`:IS 锚点扫邻格→规范式字符串规则表→属性派发到实体分组;每步全量重算 | JS + Node,MIT | 解析器极简清晰(≈百行);MIT 可自由抄 | 网格前提,与自由句无关的部分需剥离 | 规则规范式+属性派发表+全量重算,三件套直接移植 |
| [michaelzanggl JS 复刻](https://michaelzanggl.com/articles/baba-is-you/)([文章+代码](https://dev.to/michi/puzzle-classic-baba-is-you-recreated-in-javascript-behind-the-code-f7f)) | Baba 核心玩法复刻+详解文 | 三维数组关卡;名词起点双轴扫描,IS 处切分、AND 丢弃、两侧叉积;onBeforeLand/onAfterLand 行为钩子 | 原生 JS | 唯一配长文讲解的实现;钩子模式优雅 | 无许可证说明;工程性一般 | 行为钩子→本作 3D 对象的 `RuleReceiver`(规则生效前/后回调) |
| [R-033/babaisyou-godot](https://github.com/R-033/babaisyou-godot) | Godot 移植 Baba | 单体 main.gd(2144 行):worldRulesStatic/Dynamic 双表+适用性缓存,`checkTheRules()` 统一重算,`ifRuleActive(名词,"is",属性,tile)` 查询 | Godot 3 GDScript,GPL-3.0 | 展示了 GDScript 里规则表+查询接口的写法 | Godot 3、单文件巨石;GPL 传染需只借思路 | 静态/动态规则分表 + 布尔查询 API 的接口设计 |
| [Jakz/abab-is-me](https://github.com/Jakz/abab-is-me) | Baba 开源引擎(读原版关卡格式) | C++11+SDL2,已支持三词规则 | C++ | 关卡格式逆向资料 | 完成度低、平台特化 | 参考价值最低,仅证明三词规则是合理 MVP 边界 |

**造句 UI 侧(3 个)**:jamsch/react-native-duo-drag-drop(offset 模型+worklet 动画,首选参考)、blmage/duolingo-word-bank-dnd(官方行为逆向+键盘无障碍)、Unolingo(react-dnd 网页最小实现)——详见 1.2 节。

---

## 4. Godot 4 实现建议

**节点结构**

```
PhoneUI (CanvasLayer)
└─ SentenceComposer (Control)                 # 造句界面根
   ├─ AnswerArea (PanelContainer)
   │   └─ AnswerFlow (HFlowContainer)         # 实体词块 + 透明占位(飞行目标)
   ├─ WordBank (PanelContainer > ScrollContainer)
   │   └─ BankFlow (HFlowContainer)
   │       └─ BankSlot ×N (Control)           # 常驻槽:实体态/ghost 态(灰色凹陷)
   ├─ FlyLayer (Control, mouse_filter=IGNORE) # 顶层飞行动画层
   ├─ SubmitButton ("投稿", disabled 绑定答案区非空)
   └─ SFX (AudioStreamPlayer ×4: pick/place/undo/submit)

Autoload:
├─ Notebook       # 已拾取字集(存档),信号 word_collected(ch)
├─ RuleParser     # 最大匹配合词 + 槽抽取 → Rule / null
└─ RuleBroker     # 现行规则表;is_active(subj,pred);信号 rule_activated/rule_overridden/rule_rejected(tier)
```

**数据与信号流**

```
瀑布流贴文点字 → Notebook.word_collected
打开造句界面 → ComposerModel(bank:Array[StringName], answer:Array[StringName])  # 仿 jamsch 的 offset 思路
BankSlot.tap → model.place(i) → View:槽变 ghost;AnswerFlow 插透明占位
             → await process_frame 取占位 global_position
             → FlyLayer 生成副本 tween(0.2s, TRANS_QUAD/EASE_OUT + 落地 TRANS_BACK scale)
             → 到位:占位实体化,play(place), 低语念字
AnswerTile.tap → 反向飞回 ghost 槽;AnswerFlow reflow(其余占位补间)
SubmitButton.pressed → RuleParser.parse(model.answer)
   ├─ Rule → RuleBroker.apply(rule) → rule_activated → 3D 层 RuleReceiver(按 subject 注册)响应(door.open())
   ├─ 半命中 → rule_rejected(tier=MISREAD) → 恐怖"误读"演出
   └─ 不可解析 → rule_rejected(tier=NOISE) → 噪声演出
投稿句写回 Notebook 时间线("我的帖子"),规则列表可在笔记本查看
```

**实现备忘**:① 拖拽若用内建协议,记得 `_get_drag_data` 里同时把 BankSlot 置 ghost,并在 `NOTIFICATION_DRAG_END && !is_drag_successful()` 时飞回复原;② 三语适配:中文一字一块、日文按假名词/汉字词一块、英文一词一块,tile 宽度用 `get_theme_font().get_string_size()` 实测;词块字符串一律走 token id,不做字面比较;③ 音效对 U21 一一映射;手机端补 `Input.vibrate_handheld()`;④ HFlowContainer 的 reflow 自带瞬移,想要平滑需给子节点挂"记录上帧位置→下帧从旧位置 tween 到新位置"的小脚本(FLIP 技巧)。

---

## 5. 风险与待决问题

1. 多主语/多谓语句("门和灯可以打开")第一版建议只取首个命中,后续再学 Baba 加 AND——其语法迭代史证明每个新词类都远比想象贵。
2. 规则的持续性(永久/出章节失效/被"网友删帖"收回)是叙事系统耦合点,需早定,影响 RuleBroker 存档结构。
3. 《文字游戏》证明拆合字在中文成立,但日/英版没有等价物——拆字玩法若做,须设计为中文版独占彩蛋而非主线依赖。
4. 敏感组合审查:词库虽受控,仍应离线枚举全部可达句人工过一遍(空间约 30^n,限句长后可行)。

## 6. 来源链接汇总

**多邻国/UI**:[jamsch 组件](https://github.com/jamsch/react-native-duo-drag-drop) · [blmage 扩展](https://github.com/blmage/duolingo-word-bank-dnd)([Chrome 商店页](https://chromewebstore.google.com/detail/duolingo-word-bank-dnd/dfpfeeojcakkdfiglfcccdlhdfejcmkg)) · [RafaelGoulartB](https://github.com/RafaelGoulartB/duolingo-drag-and-drop) · [Unolingo 文章](https://dev.to/chinmaymhatre/the-duolingo-drag-and-drop-quiz-component-1g60) · [微交互分析](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682) · [60fps.design Duolingo](https://60fps.design/apps/duolingo)([Substack](https://60fpsdesign.substack.com/p/fun-in-every-frame)) · [官方写作博文](https://blog.duolingo.com/covering-all-the-bases-duolingos-approach-to-writing-skills/) · [官方美术风格博文](https://blog.duolingo.com/shape-language-duolingos-art-style/) · [Duolingo Wiki 练习](https://duolingo.fandom.com/wiki/Exercise) · [duolingoguides](https://duolingoguides.com/duolingo-sentence-assembly/)
**Godot**:[Control](https://docs.godotengine.org/en/stable/classes/class_control.html) · [Tween](https://docs.godotengine.org/en/stable/classes/class_tween.html) · [HFlowContainer](https://docs.godotengine.org/en/stable/classes/class_hflowcontainer.html) · [容器教程](https://docs.godotengine.org/en/stable/tutorials/ui/gui_containers.html) · [拖放入门](https://medium.com/godot-dev-digest/drag-and-drop-basics-in-godot-a-beginners-guide-313277975e06) · [dev.to 拖放](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13) · [Tween juice](https://codingquests.io/blog/godot-4-tween-tutorial-juice)
**Baba Is You**:[GDC 讲稿 PDF](https://media.gdcvault.com/gdc2020/presentations/Reading%20the%20rules_Teikari_Arvi.pdf) · [GDC Vault](https://gdcvault.com/play/1026628/Reading-the-Rules-of-Baba) · [Game Developer 视频报道](https://www.gamedeveloper.com/design/video-understanding-the-rules-of-i-baba-is-you-i-) · [设计访谈](https://www.gamedeveloper.com/design/designing-i-baba-is-you-i-s-delightfully-innovative-rule-writing-system) · [JS 复刻详解](https://michaelzanggl.com/articles/baba-is-you/) · [KekeCompetition](https://github.com/MasterMilkX/KekeCompetition)([官网](http://keke-ai-competition.com/)) · [R-033 Godot 移植](https://github.com/R-033/babaisyou-godot) · [mkskelet/baba-is-fake](https://github.com/mkskelet/baba-is-fake) · [Jakz/abab-is-me](https://github.com/Jakz/abab-is-me) · [GitHub topic: baba-is-you](https://github.com/topics/baba-is-you)
**语言改变世界的游戏**:[《文字游戏》Steam](https://store.steampowered.com/app/1109570/Word_Game/?l=schinese) · [GameLook 报道](http://www.gamelook.com.cn/2022/01/470690/) · [机核](https://www.gcores.com/articles/194312) · [indienova 访谈](https://indienova.com/indie-game-news/interview-team9-word-game/)(后两者部分内容因反爬未全文抓取) · [Super Scribblenauts](https://en.wikipedia.org/wiki/Super_Scribblenauts) · [Scribblenauts 词库讨论](https://lil.law.harvard.edu/blog/2010/03/19/why-is-scribblenauts-so-cool/) · [Typoman](https://en.wikipedia.org/wiki/Typoman)([评测](https://techraptor.net/gaming/reviews/typoman-revised-review-words-hurt)) · [Chants of Sennaar 评测 1](https://roomescapeartist.com/2023/11/18/focus-entertainment-chants-sennaar-review/)/[2](https://gameluster.com/chants-of-sennaar-review-quintetlingo/) · [OneShot](https://en.wikipedia.org/wiki/OneShot) · [The Stanley Parable](https://en.wikipedia.org/wiki/The_Stanley_Parable)
**规则引擎/NLP**:[最大匹配分词(52nlp)](https://www.52nlp.cn/maximum-matching-method-of-chinese-word-segmentation) · [博客园详解](https://www.cnblogs.com/zongfa/p/15141087.html) · [知乎实现](https://zhuanlan.zhihu.com/p/103392455) · [IF 文本解析器](https://en.wikipedia.org/wiki/Text_parser) · [Emily Short 论 parser](https://emshort.blog/2010/06/07/so-do-we-need-this-parser-thing-anyway/) · [Semantle](https://en.wikipedia.org/wiki/Semantle)([复刻](https://github.com/memgonzales/semantle-word-embeddings)) · [multilingual-MiniLM](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2)
