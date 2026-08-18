# 《语言污染》氛围 / UI / 镜头 对标方案
> 六部对标作品拆解 × 可执行落地清单 · 2026-08-18
> 配套:`horror_atmosphere_plan.md`(机制型恐怖总纲)、`flashback.md`、`dialogue.md`、`sentence_rules.md`。本文只谈**看得见听得见的那一层**——质感、界面、景别与运镜;机制层不重复。

---

## 零、基线:本作现状(读代码得出,作为验收锚点)

| 项 | 事实 | 位置 |
|---|---|---|
| 配色 | 仅两套字典:`PALETTE_1`(bg `B7D957`/surface `FFF1C9`/ink `10140F`/accent `365B2D`/muted `DDEB8A`/flash `9CFF24`)、`POLLUTION_PALETTE_5`(bg `9CFF24`/surface `FFF2B8`/ink `0D1009`/accent `2F6B1F`/muted `D8FF66`/flash `39FF14`) | `babel_meme_game.gd:18-39`,取色统一走 `_theme_color()`:5346 |
| **字体** | **零投入**。全项目无 `.ttf`/`.otf`/`FontFile`/`add_theme_font_override`,`project.godot` 无 `custom_font`;只有 `font_size` override | 全局 grep |
| 脏污层 | `vhs_screen.gdshader` 已含 29.97 场率、480 行扫描、隔行、head-switch、tear、色差、雪花、dropout、`phosphor_tint(0.91,1.0,0.76)`、`black_ink_guard`、vignette。**完整,缺的是分层使用** | `shaders/` |
| 镜头 | 唯一 `Camera3D`,`fov=58` 硬编码;`_animate_world()` 逐帧 `lerp`:`phone_down` 位 `(0,1.45,2.2)`/旋转 `(-54,0,0)`,`npc_up` 贴玩家头顶 `+1.56`。**全项目无一处 Tween/AnimationPlayer 驱动镜头** | `:933`、`:5283` |
| 电影黑边 | 两条 `ColorRect`(`050705`,`z_index=8`),按 `CINEMATIC_ASPECT_RATIO` 算高。**静态,无推入动画** | `:2818` |
| 楼层转场卡 | 3.6s;黑底 + `flash_text` 色 `-5°` 横杠 `scale.x` 0.04→1(0.72s/QUINT);层名 58px、危险 28px、提示 22px | `:6003`、`:6081` |
| 60% 闪回 | `TOTAL_DURATION=3.55`,九拍(freeze/black_gap_a/doll/black_gap_b/doctor/attribution/triple_echo/residue/empty_frames),自带 WCAG 闪烁预算校验 | `pollution_flashback_director.gd` |
| HUD | 左侧抽屉 rail,`z_index=40`,面板 `bg alpha 0.94`/`border alpha 0.22-0.24` | `:2512`、`:7269` |
| 玩偶小窗 | 252px `PanelContainer`,`z_index=25`,位 `(16,552)`,只折叠不关闭 | `:6337` |
| 历史记录 | `RichTextLabel` 17px,自有 `{ins}`/`{del}` 标记转 BBCode | `:3327`、`:3358` |
| 视口 | `1600×900`,`canvas_items`,纹理过滤最近邻 | `project.godot` |

---

## 一、六部作品拆解

### 1.《P.T.》(Kojima Productions, 2014)

**氛围** ①**一条走廊即全部空间**:L 形走廊四扇门(进/出/浴室/永久锁死),没有任何可停留房间——"整间公寓是一条彻底的走廊,没有房间可以环顾、感到安全、藏身或跑进去";玄关的**室内阳台**在建筑逻辑上说不通,只为制造半室外错位。②**每圈只改一处,改的是"理所当然"**:灯突然熄灭、浴室门从关变开——"这些恰好卡在熟悉阈值上的细微变化,让玩家开始质疑每一个细节";时序是照明良好→收音机开始说话→灯全灭→红光加"旋转眼睛"的画;壁龛数字钟长期停在 **23:59**,某圈跳成 **0:00**。③**威胁永远在背后**:角色始终把背暴露给走廊/门/窗/收音机,加 90° 直角"转过去之前看不见那边有什么"。

**UI** ①**零 HUD、零提示、零教程**,玩家只能移动和 zoom——"很少的控制权,但其实一点都没有"。②**叙事载体是收音机不是文本框**:播报一则父亲杀死全家后自杀的新闻,其中一处被含混的声音念成 "umbilical cord"(脐带)——信息从公共广播降级为被篡改的私语,全程无 UI 参与。③**谜面藏在图像碎片**:六块相框拼出 "My voice, can you hear it? This sign, can you read it?"——谜题内容本身就是"你能否读懂界面"。

**镜头** ①固定第一人称、无跑跳,移动极慢,"慢"本身是压强。②**zoom 是唯一构图权**:只能拉近不能退后——被允许的动作只有更靠近你不想看的东西。③门缝/转角/缝隙作默认取景框,画面永远被切掉大半。

**优点**:一条走廊 + 一台收音机 + 一个 zoom 键,资产量近零,靠结构 + 时序 + 减法。
**适配性:高。** 时序法可直接映射楼层重访与瀑布流重发帖。唯一不适配的是"真的零 UI"——本作主题就是界面,只能把 UI **降级为不可信**。

### 2.《死亡搁浅 1 / 2》(Kojima Productions, 2019 / 2025)

**氛围** ①**孤独是设计出来的密度**:小岛不追求地图学准确,在意"环境如何通过玩家与它演化的关系促成自省",配合"压倒性的人类存在缺席"——长时间无对话,是为了让极少数对话变昂贵。②环境叙事绑定在持续消耗的物理量上(时间雨/耐力/货物平衡),天气会**吃掉玩家资产**。③**仪式取代菜单**:配送准备被刻意拉长。代价真实——货物自动分拣无法兼容扁平货物,教程提示在屏上滞留数分钟挡视野。

**UI** ①**半透明 + 点阵衰减**:菜单用"半透明黑底 + 向下淡出的不均匀点阵",像投影而非贴纸。②**全息 = 扁平 + 透视斜切 + 动效**:站酷 HOTPOWER 拆解指出差异化在"全息的立体动态效果",大量元件带**透视斜切**。"死亡搁浅味"的核心不是青色,是**斜切 + 动**。③**字体双轨制**:`Fonts In Use` 记录 **Sackers Gothic Medium** 用于 logo/品牌/章节标题卡与角色介绍卡,**SST Roman** 为主 UI 字(为大段文字可读性),另有 **EX PS Medium Neon** 与被形容为"像 VCR 字体"的 **BO CD Mono**(短文本与数字)。另一份分析给的是 Trajan Pro / Century Gothic / Bank Gothic Light。两份不一致,但共性可靠:**一套宽字距仪式字 + 一套高可读信息字 + 数字单独等宽**。④几何标注:三角与锐角贯穿元件,金色为唯一强调。⑤**Odradek 是"UI 长进世界"的范本**:约 120° 扇形,由扫描线/边缘辉光/远端变暗/物体轮廓四层构成;自定义 UV(U 沿前向轴 0→边缘 1,V 为到原点距离)驱动推进;轮廓用**深度 Sobel 滤波**;地面图标用平面投影匹配俯视正交相机视锥。⑥**反面教材**:DS2 字幕**无大小与不透明度选项**,会淹没在背景里;HUD 绝大部分为蓝色且不可自定义,无任何色盲模式,后期暴风雪中几乎读不出。

**镜头** ①**背影构图**:货物剪影就是状态栏。②过场与游戏几乎无缝,无硬切黑场。③长镜头 + 大地景别,把人压成风景里的一个点,音乐进入是唯一情绪爆发点。

**优点**:把界面语言做成品牌资产;把孤独做成可量化的节奏。
**适配性:高(UI)/ 中(镜头)。** 手机窗口、瀑布流、HUD 可直接吸收半透明 + 斜切 + 等宽数字。第一人称没有"背影",但"把人压成风景里的一个点"可在日结与结局各兑现一次。

### 3.《Milk outside a bag of milk outside a bag of milk》(Nikita Kryukov, 2021)

**氛围** ①**主色板是"血与暗"**:红黑为主,**唯一例外是主角鲜明的水蓝色皮肤**作为"舒缓对比"——一整部只留一个高饱和例外色。②**每个梦境一种画风**,"手机梦像是来自完全另一个游戏"——**风格断裂本身就是转场语言**。③**不谐和音轨作持续压强**:配乐"不谐和噪音"、持续失真,评论者明说通关后"想和这个配乐保持距离"——不是拿来听的,是拿来磨损的。④背景次要细节承担恐怖:角色与家具背后有"渗出"元素,窗外偶尔有巨大的眼睛。

**UI** ①**无阴影线描 + 立绘直接压在背景上**,不做隔离层,人物与环境共享同一层脏。②Milk-chan 用"扭曲的数字化嗓音"——语音是被处理的信号而非配音。③**可用性反面教材**:点击段落"配色太暗、与浅色可选点对比过强"被明确批评——**高对比可交互点必须与低对比氛围底分离**。④开发者自述:"首先是对词与形式的艺术操纵,其次才是游戏"。

**镜头(画面调度)** ①用抽象度而非遮蔽表达不可直视:父亲的死只是"粉色与黑色的斑块"。②完全动画化段落与静止立绘形成节奏对比。③场景切换靠画风硬切,不用淡入淡出。

**优点**:证明"手绘/拼贴 + 单点例外色 + 风格断裂"可在零预算下产生强心理压强。
**适配性:高(方法)/ 低(色板)。** 本作已有绿白高饱和基调,再叠红黑会色相打架——迁移**方法**(单点例外色、风格断裂),不迁移它的颜色。

### 4.《Cosmic Ultramarine》(21st Nostalgia / Game Poetics, 2024)

> 2024-11 上架的抢先体验独立作,尚无深度设计拆解,依据 Steam 商店页/社区页/TapTap/更新日志。

**氛围** ①**漫游取代闯关**:"从更高维度接入超维度",在"由你的数个前世构成的景观"中漫步,**明确无死亡与失败条件**,定位"没有压力的虚拟漫游"——眩晕来自尺度与意象,不来自威胁。②**年代错置的意象堆叠**:从"90 年代网络空间"到"大西洋马尾藻海",遇到宇宙存在、机械僧侣、地球最后一只恐龙;标签同时挂 超现实/迷幻/1990s 美学/可爱/meme。**"可爱"与"宇宙尺度"并置**与本作"meme 瀑布流 + 语言污染"的张力同型。③**色名即氛围纲领**:直接把一个颜色(群青)当世界观锚点——给氛围一个可被念出的颜色名,团队沟通成本立刻下降。

**UI** ①**载体是移动终端**,玩家通过终端界面接入各维度,与本作"手机是唯一入口"同构。②文字是**操作层**而非叙述层(文字游戏 + 视觉小说混合)。③**转场时长是被维护的参数**:官方更新日志专门记录"修复了之前场景转场加载过慢"。

**镜头** ①2D 场景切换为主,靠意象跳跃制造纵深。②无失败状态 → 镜头不承担危险预警职能,可全部用于展示。③终端界面本身是取景框。

**优点**:极低成本达成 97% 好评(395 篇),验证"无威胁超现实漫游"在中文语境成立。
**适配性:中。** 可迁移"终端即世界入口"、"给氛围起颜色名"、"转场时长是可调参数"。不可迁移"无失败状态"——本作有污染与结局分歧。

### 5.《Escape the Backrooms》(Fancy Games + Blackbird / Secret Mode, 2022 EA → 2025 正式)

**氛围** ①**阈限空间四条硬语法**:**无目的性**(人造却不服务任何人类活动)、**空无**(没有人,social meaning 被抽掉)、**均质重复**(无尽相同走廊阻止认知锚定)、**与外界断连**(无窗无出口)。Level 0 的实现就是"无尽的亮黄色墙纸 + 潮湿地毯 + 荧光灯"。②**命名是恐怖的一部分**:Level 0 The Lobby / 1 The Habitable Zone / 2 Pipe Dreams / 3 Electrical Station / 4 Abandoned Office / 5 Terror Hotel / **Level Fun =)** / 6 Lights Out / 7 Thalassophobia / 8 Cave System / **Level 37 The Poolroom** / **Level !** / **Level 94** / **The End**——编号**故意不连续也不总是数字**,打断"我知道自己在第几层"的安全感,比任何贴图都便宜。③**危险的最佳形态是不出现**:GameSpot 6/10 的批评极有参考价值——"liminal space 之于恐怖就像 shoegaze 之于音乐:必须模糊才成立";成年人喜欢"陌生地怀旧却非人的世界"的**空无本身**,本作偏向"走廊里有东西游荡",于是"不够微妙,因而不够令人不安",被追逐的循环"夺走了环境最强的那一面"。

**UI** ①官方美学宣言只有一句:"realistic graphics, **minimal user interfaces**, and dreary ambience"——极简 UI 被写进商店页当卖点。②极简 HUD:手电、体力、少量物品,信息不上屏。③**关卡名卡片是全游戏最"UI"的一刻**,独自承担全部仪式感。

**镜头** ①纯第一人称、无过场,所有演出由灯光与空间承担。②理智系统(需进食,否则精神衰退致死)取代战斗,镜头不需要瞄准。③**单人 vs 多人节奏差异明显**:多人语音把恐惧转化为社交,**单人才保留阈限空间原味**——本作是单人作品,应对标单人节奏。

**优点**:用最便宜的资产(墙纸/地毯/荧光灯)与最贵的命名法,验证阈限空间的可玩化路径。
**适配性:高(空间语法与命名法)/ 低(实体威胁)。** 本作已明确"零 jump scare、零 Area3D 惊吓触发",与 GameSpot 的批评方向一致——**坚持它做对的一半,拒绝它做错的一半**。

### 6.《Disco Elysium》(ZA/UM, 2019)

**氛围** ①**"整个游戏当作一幅画来设计"**:美术总监 Rostov 原话——"等距图像的美妙在于它是平的……本质上就只有这一幅图",因此可用绘画方法**引导视线**:一部分保持干净,另一部分堆满肌理与复杂度。②手绘笔触统一到 UI 层,界面与场景共享同一套油画质感,无材质断层。③色彩分层承担状态:健康(橙)/士气(蓝)是 HUD 里唯一的高饱和。

**UI** ①**对话框放右下不放下三分之一**:Kurvitz 的理由极实用主义——"如果你在用电脑,屏幕右下是你 60% 时间在看的地方",因为系统时钟和通知都在那儿。②**Twitter 是对标物,不是 CRPG**:"Twitter 算是我们的竞争对手,作为写作者你想写得明快";文本"向上翻滚,作为一栏文本来管理";目标是"像 Twitter 一样上瘾和明快的对话引擎"。**这条对本作瀑布流直接命中。**③**字体是世界观**:logo/标题 **Dobra Black**,对话正文 **Sina Nova**,开发博客 **Libre Baskerville**——三套各司其职,无一处默认字体。④**HUD 分工**:左下是双人肖像 + 橙/蓝双条,右下是时钟、当前游戏日、金钱(Real)与手持物图标——**人在左、账在右**。⑤**信息密度靠折叠不靠缩字号**:思绪以彩球浮在角色头顶,点开才展开为对话框。⑥技能颜色编码,选项 hover 变色,检定成功/失败带动画。

**镜头** ①等距固定视角 + 有限缩放,镜头基本不动——"不动"保证每帧都是构图完整的画。②**对话框构图传达权力关系**:漫画家 Kaspar Tamsalu 设计的对话画框,见 Evrart Claire 时玩家被"夹在中间",构图直接说明谁在支配。③**用画框动代替镜头动**:在不能动镜头的视角里,关键节点靠画框推近做"拉近"的替身。

**优点**:唯一把"UI 即世界观"做到极致的作品,且信息密度方案(右下栏 + 上滚 + 折叠 + 颜色编码)可逐条抄。
**适配性:高。** 本作造句台、历史记录、瀑布流、笔记本全是文本密集界面,DE 是六部里**唯一给出完整文本 UI 工程答案**的对标物。

---

## 二、氛围大方向总纲(五条)

必须同时容纳三件互相拉扯的东西:**手机瀑布流(2D、密、亮)**、**第一人称 3D 街区(空间、疏、暗)**、**语言污染主题(文字既是玩法也是病灶)**。

**纲一 · 两个世界共用一套"脏",不共用一套"亮"。** 噪声/颗粒/色差/扫描线是同一套(说明被同一个东西污染),但亮度、饱和、信息密度完全相反:手机过曝且密,街区欠曝且空。
- 正例:同一个 VHS shader 全局施加,手机层 `intensity` 高、街区层低但雾更浓——同一个病,两种症状。
- 反例:街区单做写实雾、手机单做 UI 特效,读起来像两个游戏。`Milk` 的"每梦一画风"能成立是因为**串行**切换;本作玩家每秒都能来回切,风格断裂会被读成 bug。

**纲二 · UI 是被污染的容器,正文永远干净。** 把 `flashback.md` 的硬约束升级为视觉规范:玩家读的那句话永远最高对比、最高可读;被污染的是边框、描边、透明度、扫描线、名牌、时间戳、字号。
- 正例:高污染时对话框边框丢失一段、时间戳变 `--:--`、名牌变 `【　　　】`(闪回导演已有 `EMPTY_SPEAKER_PLATE` 常量),台词一个字不改。
- 反例:把正文做成乱码或降对比。既违反 DS2 无障碍评测暴露的教训,也让玩家把恐怖读成渲染出错。

**纲三 · 每层都有名字,而命名系统会背叛你。** 学 Backrooms 的编号断裂法:楼层是**编号 + 命名 + 危险等级**三段式(本作 `_update_floor_transition_card` 已是这个结构),关键是让它后期**自己出错**。
- 正例:第四层转场卡显示"区域:未记录"(闪回导演已有 `UNREGISTERED_CARD_TEXT`),危险栏空白。
- 反例:每层给一个更长更吓人的名字。恐怖来自**系统失效**,不来自形容词升级。

**纲四 · 孤独靠"减法的时序",不靠"资产的空旷"。** P.T. 的每圈递进、DS 的人类缺席、Backrooms 的空无是同一件事:**先给,再抽走**。
- 正例:25% 抽街道底噪、60% 抽人声层、80% 只剩脚步——玩家能明确说出"这层比上层安静"。
- 反例:一开始就做成安静的。没有对照组的安静只是空,不是孤独。

**纲五 · 仪式只在少数时刻出现,其余退到最小。** 本作的仪式时刻只有六个:楼层转场卡、60% 闪回、日结过场、NPC 对话进出、结局屏、发梗结算。其余时间 HUD 应几乎不存在(现有抽屉式 HUD 方向正确)。
- 正例:发梗结算时黑边推入 + 全息层升起,3 秒内结束,之后 HUD 缩回边缘。
- 反例:给每个按钮都加扫描线和悬浮动效。DS 的教训正在这:提示常驻数分钟挡视野,把仪式感变成噪声。

---

## 三、UI 对标方案

### 3.0 三件地基(否则后面全部打折)

| 地基 | 做法 | 参考 |
|---|---|---|
| **字体三件套** | 建 `assets/fonts/`,`project.godot` 设 `gui/theme/custom_font` 兜底,再分类 override:①**仪式字**(楼层卡/结局屏)宽字距粗黑;②**信息字**(瀑布流/对话/笔记本)高可读几何无衬线;③**等宽数字字**(污染%/资金/时间戳/行动数),否则数值跳动会抖字宽 | DS 的 Sackers Gothic / SST Roman / BO CD Mono 三分工;DE 的 Dobra Black / Sina Nova |
| **全局 Theme 资源** | 现所有样式靠 `_style()`/`_theme_color()` 在代码里现搓;抽出 `Theme` 后换肤单点可控 | DE 的"UI 与场景共享一套质感" |
| **两层叠加层** | `_ui_root` 之上加 `HoloLayer`(layer 60)与 `GrimeLayer`(layer 70),现有 VHS overlay 并入后者 | godotshaders 的 CRT/VHS shader 明确支持"Overlay 模式:CanvasLayer 里的 ColorRect 影响其下所有节点" |

### 3.1 逐组件改造

| 组件 | 字体 | 描边 / 透明度 | 扫描线 / 几何标注 | 动效 | 参考技法 |
|---|---|---|---|---|---|
| **手机 App 窗口** | 标题仪式字 15px + 字距 +2;正文信息字 | 面板 `bg alpha` 0.94→**0.86**;边框改 1px 实线 + 外侧 1px `alpha 0.18` 辉光 | 底部 30% 加**向下淡出点阵**;右上角 8px 直角三角 + 6px 等宽小字(如 `TWR/01`) | 开窗**先出边框 0.10s 再出内容 0.14s(延迟 0.06)**,QUINT/EASE_OUT,关窗反序 | DS 半透明+点阵衰减;DS 三角贯穿 |
| **瀑布流卡片** | 正文信息字,中文行长 ≤22-24 字,超出折行**不缩字号** | 卡片底叠纸纹+网点噪声贴图 `alpha 0.06`,图文区共享同一层脏 | 无扫描线(保持可读) | 入场 stagger:`index*0.035s`,CUBIC/EASE_OUT,位移 12px,8 张后不再累加 | DE 一栏上滚;Milk 立绘与背景共享同一层脏 |
| **拾取高亮 / 例外色** | — | — | — | — | **`flash_text` 全局只用于可拾取字**,其余任何位置禁用(Milk 的单点例外色) |
| **重发帖微变** | 第二次出现时时间戳**降一号并改等宽字**,配图不变 | — | — | — | P.T."细微变化恰好卡在熟悉阈值上" |
| **笔记本造句台** | 字块信息字 20px;已成句部分仪式字 22px(**世界接受的句 ≠ 手里的字**) | 字块 `border alpha` 0.24→**0.42** + 1px 内阴影;ghost 槽位用虚线 + 4px 圆角 | 顶部加**刻度条**(每槽一个 2px 刻度),把造句台读成测量仪器 | 落位 0.06s 的 1px 下沉回弹(比 scale 弹跳克制) | DS 几何标注;DE 标题/正文字分家 |
| **HUD** | 数值必须等宽数字字;标签信息字 13px | rail `border alpha` 0.22→**0.34**,`bg alpha`→**0.55**(更透、边更实) | **只有污染条允许扫描线**(1px 间隔,`alpha` 0.05→0.22 随污染);污染图标右侧 6px 三角指示三档阈值 | 保留现 `_action_spend_tween`;污染跨阈值时 rail 做 0.18s / 1px 横向抖动(SINE) | DE"人在左账在右"→**资金 + 游戏日移到右下常驻小行**(Kurvitz 的 60% 视线位) |
| **历史记录** | 时间戳列等宽字 | 常驻纸纹 `alpha 0.05` + 底部 8px 渐隐(它是"档案") | 改**双栏时间轴**:左 48px 时间戳列 + 右正文列,时间戳列是后期篡改主战场 | 打开时内容上滚 24px / 0.22s CUBIC | DE 文本向上翻滚 |
| **`{ins}`/`{del}` 语义** | — | `{del}` = 删除线 + `alpha 0.55` **保持可读**(不打码);`{ins}` = 下划虚线 + accent 色 | — | — | 纲二:改标记不改正文 |
| **设置菜单** | 全信息字,**不用仪式字** | `bg alpha 0.96`(比其他窗口更实),1px 实线不加辉光,**不进全息层** | 无 | 只做 0.12s `modulate:a` 淡入,**无位移**——没有戏剧性 = 可信 | 全游戏唯一必须绝对可靠的界面(退出按钮在此) |
| **玩偶小窗** | 信息字 + 字距 -0.5 + 行高 1.6(模拟手写感) | `alpha 0.92`,**不半透明**;12px 圆角 + 2px `accent` 描边——**唯一的圆角 = 唯一的温柔** | 无标注、**不显示任何数值** | 常驻**呼吸** `scale` 1.0↔1.008,周期 3.2/2.4/1.8s 三档随污染;≥80% 时描边渐变到 `ink`、圆角收到 4px | DS 的 BB 舱:唯一情绪化元件,有生理反应不报告数据 |

### 3.2 配色与材质方向

**保留** `PALETTE_1` / `POLLUTION_PALETTE_5` 绿白基调不变(已是识别色,且两套间已有"更毒的绿"的递进)。其上加两层:

**A. 死亡搁浅式全息层(`HoloLayer`)** — 新增三个**不进 palette 字典**的色值:`holo_line #A9FFD0`(扫描线,alpha ≤0.22)、`holo_dot #E8FFF2`(点阵,alpha ≤0.10)、`holo_warn #FFC24A`(唯一暖色强调,只用于"你即将失去某样东西",全周目 ≤5 次,对应 DS 的金色唯一强调)。材质关键是**透视斜切**:全息元件加 2-3° `skew` 或 shader 里 `uv.x += uv.y * 0.03`,**而不是靠加青色**——这是站酷拆解点明的"死亡搁浅味"技术核心。点阵用 4×4 tile + `alpha 0.10→0.0` 垂直渐变,贴面板底部 30%。

**B. P.T. 式脏污层(`GrimeLayer`)** — 已有 `vhs_screen.gdshader` 即此层,要补的是**三档强度表**而非新 shader:`intensity` 手机层 `0.42` / 街区层 `0.24` / 闪回·结局 `0.72`,`pollution` uniform 直接接污染值。另补一张静态脏污贴图(污渍/指纹/水痕),`alpha` 0.03→0.14 随污染,**只贴手机窗口边缘 40px 内**——手机是被手摸过的物体,街区不是。`phosphor_tint (0.91,1.0,0.76)` 保持不变,已与绿白基调咬合。

**C. 层级与红线**
```
GrimeLayer (70)  脏污/VHS —— 影响一切,含全息层
HoloLayer  (60)  扫描线/点阵/斜切 —— 只影响"设备类"UI
_ui_root         正文与控件 —— 永远最清晰
3D 世界
```
红线:① **正文永不进入前两层采样**(现有 `black_ink_guard` 即此思路,应扩展为文本保护遮罩);② 全息层不覆盖设置菜单与玩偶小窗;③ 任何新增闪烁 ≤3 次/秒,沿用闪回导演已有的 WCAG 预算。

---

## 四、镜头与运镜方案

**通用前置**:新建 `scripts/ui/camera_director.gd`,用 `await` 串行的 CutsceneDirector 模式(每个动作 `tween_property` 后 `await tween.finished` 再 emit 完成信号)。比 `AnimationPlayer` 更适合本作——所有镜头目标都是运行时算出来的(玩家/NPC 位置),不是预烘关键帧。同时把 `_animate_world()` 的 `lerp` 改成"Director 未接管时才跑",避免两套逻辑抢。

| 时机 | 景别 | 时长 / 缓动 | 第一人称锁定 | Godot 4 做法 |
|---|---|---|---|---|
| **楼层转场卡** | 保持全屏文字卡,但**黑场两端各挂一个镜头动作**:进入前 `fov` 58→52,退出后 52→58——这就是小岛"过场与游戏无缝"的最低成本版,黑场从切断变成转场 | 0.4s + 0.6s,并入现有 3.6s 首尾并行段;QUINT/EASE_IN_OUT | 是(`_set_input_locked` 已有) | `t.tween_property(_camera,"fov",52.0,0.4)` 后 `await t.finished` 再 `_play_day_transition()`;卡片本身改渲进 `SubViewport` → `TextureRect`,即可单独对卡片施加扫描线而不波及其他 UI |
| **60% 闪回** | 结构不动(3.55s/九拍)。补:`freeze` 帧做**极缓慢 1.02 倍推近**贯穿全程——整段闪回里唯一在动的东西,对应 DE 用画框推近代替镜头推近 | 3.55s,**TRANS_LINEAR**(非线性会被察觉) | 是,全程 | 冻结帧已是 `SubViewport` 截图 → `TextureRect`;`tween_property(rect,"scale",Vector2(1.02,1.02),3.55)`,`pivot_offset` 设中心 |
| **日结过场** | **全游戏唯一的第三人称背影**:相机退到玩家背后 2.4m / 高 1.9m / 俯角 8°,角色用现有立绘背面或纯剪影。DS 式"人被压成风景里的一个点",每天只兑现一次 | 1.2s 退 + 1.0s 静 + 0.8s 回 = 3.0s;退 QUART/EASE_OUT,回 QUART/EASE_IN | 是,1.2s 后可跳 | `tween_property(_camera,"global_position",back,1.2)` 并行 `tween_method(_look_at_player,0.0,1.0,1.2)`(避免 `look_at` 万向锁);黑边同步:`_cinematic_top_bar.offset_bottom` 0→`bar_height`,0.5s QUINT——**让静态黑边动起来是本方案性价比最高的一条** |
| **NPC 对话进出** | **注意力收窄而非镜头推近**:`fov` 58→46,高度不变、不做位移(第一人称里更自然且不晕);yaw 用 `lerp_angle` 对准 NPC,pitch 抬到眼线。黑边只推到半高(`bar_height*0.55`)——对话是常规行为不是仪式 | 进 0.35s / 退 0.45s,**进快出慢**;SINE/EASE_OUT | 锁定旋转,但保留 `sin(t*1.1)*0.25°` 呼吸摆动(完全静止会读成卡住) | 走 `CameraDirector`;yaw/pitch 用 `tween_method` 插值后写回 `rotation_degrees`,避免和 `_animate_world()` 抢。**污染态**:≥60% 时退出只回到 56° 并逐次再少 2°——视野被慢慢收走,HUD 无任何提示(P.T. 每圈微变 + 纲四减法) |
| **结局屏** | 极远景 + 极长镜头:从玩家位沿正上方升到 18m、俯角 60°,`fov` 58→72(广角化 = 把人推远),中途不切。六部里唯一值得给 6 秒的镜头 | **6.0s**,SINE/EASE_IN_OUT | 是,前 6s 不可跳 | 三条并行曲线(`global_position`/`rotation_degrees.x`/`fov`);`GrimeLayer` intensity 用 `tween_method` 调 `set_shader_parameter` 在最后 1.5s 从 0.24 升到 0.72;黑边推全高;配乐播五音动机倒放;结局文案在镜头结束后仪式字**上滚入场**,不淡入 |
| **玩偶跟随** | **不用镜头,用"镜头的缺席"** | — | 否 | ①跟随距离随污染三档(1.6/2.6/4.2m),`lerp` 平滑不硬跳;②80% 后偶尔**已在目的地背对玩家**站着,**相机不做任何提示**(P.T."威胁在背后"的反转:这次它在前面且背对你);③一次性"别回头":连续回头 3 次后第 4 次消失,小窗从屏幕外身后方位滑入 40px(BACK/EASE_OUT,0.28s),全周目一次。**硬约束:玩偶系统不得触发任何 `Camera3D` 属性动画**——保证"镜头动 = 有事发生"这条语法不被稀释 |

---

## 五、分阶段落地清单

### P0 —— 纯参数 / 材质 / 字体(1 名程序 + 1 名美术约 1 周)

| # | 目标体验 | 改动位置 | 验收标准 | 量 |
|---|---|---|---|---|
| P0-1 | 界面有出身,不再是引擎默认脸 | 新建 `assets/fonts/`;`project.godot` 设 `custom_font`;三套字分类 override | 三类文字截图可肉眼区分;所有数值用等宽数字,变化时字宽不跳 | 小 |
| P0-2 | 面板像投影而非贴纸 | `_style()`(:7269)`bg alpha` 0.94→0.86、`border alpha` 0.24→0.34,边框改双线 | 三个 App 窗口/笔记本/历史记录一致;**设置菜单不受影响**(保持 0.96) | 小 |
| P0-3 | 黑边会动,过场不再硬切 | `_layout_cinematic_bars()` 旁加 `_animate_cinematic_bars(ratio, duration)` | 三种高度(日结 1.0 / 结局 1.0 / 对话 0.55)可达;推入 0.5s、退出 0.6s | 小 |
| P0-4 | 转场卡两端有镜头呼吸 | `_play_day_transition()` 首尾各挂 `fov` tween(58→52→58) | 总时长仍 3.6s;`test_day_transition.gd` 全绿 | 小 |
| P0-5 | 对话是注意力收窄 | `_animate_world()` 的 `npc_up` 分支改由 `fov` tween 驱动 | 进 0.35s / 退 0.45s;锁定期保留 ±0.25° 呼吸;无眩晕投诉 | 小 |
| P0-6 | 玩偶还活着 | 小窗常驻 `scale` 呼吸 tween(周期 3.2/2.4/1.8s 三档) | 周期随污染切换;`z_index`、折叠不可关闭行为不变 | 小 |
| P0-7 | 例外色只服务一件事 | 全局审计 `flash_text` 用法 | 除拾取高亮外全 UI 无该色值;转场卡横杠改用 `muted` | 小 |
| P0-8 | 脏污分层而非一层盖死 | `vhs_screen.gdshader` 的 `intensity` 按上下文赋值(0.42/0.24/0.72) | 三种上下文截图可区分;`black_ink_guard` 行为不变;闪烁 ≤3 次/秒 | 小 |
| P0-9 | 可读性不被氛围吃掉 | HUD 与对话全量对比度审计 | 全部 ≥4.5:1;污染状态不得仅以颜色传达(须同时有数字)——对应 DS2 无障碍教训 | 小 |

### P1 —— 需新建节点或 shader(约 2 周)

| # | 目标体验 | 改动位置 | 验收标准 | 量 |
|---|---|---|---|---|
| P1-A | **镜头有了导演** | 新建 `camera_director.gd`(await 串行 + 完成信号);`_animate_world()` 加"Director 接管则短路" | 六个时机全走 Director;未激活时行为与现状逐帧一致;新增 `tests/test_camera_director.gd` 覆盖时长与锁定态 | 中 |
| P1-B | **全息层落地** | `CanvasLayer HoloLayer`(60)+ `holo_overlay.gdshader`(扫描线/点阵衰减/`uv.x += uv.y*0.03` 斜切)+ 三个 holo 色常量 | 只作用于设备类 UI(三窗口 + HUD + 造句台);**不**作用于设置菜单与玩偶小窗;`holo_warn` 全周目 ≤5 次 | 中 |
| P1-C | **文本保护遮罩** | 扩展 `black_ink_guard` 思路:正文 Label/RichTextLabel 渲进独立 `SubViewport`,在脏污层之上合成 | 任意污染值下正文对比度 ≥干净态的 90%;`test_flashback_sequence.gd` 的"正文永不被污染"约束仍全绿 | 中 |
| P1-D | **日结背影镜头** | `CameraDirector.play_day_outro()` + 玩家背面剪影 `Sprite3D` | 3.0s(1.2 退/1.0 静/0.8 回);黑边同步全高;每天至多一次;1.2s 后可跳 | 中 |
| P1-E | **历史记录时间轴化** | `_render_history_window()` 改双栏;`{ins}/{del}` 视觉重定义 | `{del}` 保持可读不打码;打开上滚 24px/0.22s;历史相关用例全绿 | 中 |
| P1-F | **污染条即信号** | HUD 污染元件加扫描线 + 三角阈值指示;资金 + 游戏日移右下常驻小行 | 跨阈值抖动 0.18s/1px;右下行不遮挡瀑布流可点区;`test_hud_drawer.gd`、`test_responsive_layout.gd` 全绿 | 中 |

### P2 —— 大改(各自立项,2-4 周)

| # | 目标体验 | 改动位置 | 验收标准 | 量 |
|---|---|---|---|---|
| P2-1 | **结局 6 秒长镜头** | `CameraDirector.play_ending()`:位置/俯角/fov 三曲线 + GrimeLayer intensity 曲线 + 配乐倒放 | 6.0s 不可跳、之后可跳;文案在镜头后上滚入场;无穿模穿地;两种结局各一套参数 | 大 |
| P2-2 | **命名系统自我背叛** | 转场卡三段式接入可失效数据源;第四层用 `UNREGISTERED_CARD_TEXT` + 空白危险栏 | 编号跳号 / 危险等级非字母 / 名字被替换为玩家拼过的句子,三种失效各有确定性触发条件;**零随机**;`test_level_display_names.gd` 扩展覆盖 | 大 |
| P2-3 | **Theme 资源 + 污染换肤** | 抽出全局 `Theme`;`_style()`/`_theme_color()` 全量迁移;按污染档切 Theme 变体 | `test_language_corruption_ui.gd`、`test_social_feed_layout.gd`、`test_responsive_layout.gd`、`test_doll_ui_flow.gd` 零回归 | 大 |
| P2-4 | **手机层"被摸过"材质** | 手机窗口边缘 40px 脏污贴图,`alpha` 0.03→0.14 随污染 | 只作用于手机层;不影响任何可点区域命中判定;高污染下正文对比度仍达 P1-C 标准 | 大 |

**顺序**:P0 全部 → P1-A(是 P1-D / P2-1 的前置) → P1-B/C 并行 → P1-D/E/F → P2 按叙事排期挑选。

**三条不可让步的红线**:① **正文永远干净**——脏污与全息只作用于容器;② **镜头动 = 有事发生**——玩偶跟随、常规移动、菜单开关一律不得驱动 `Camera3D` 属性动画;③ **零随机**——所有镜头与 UI 状态变化由确定性条件触发,可复现、可写测试,与既有"确定性恐怖事件表"路线一致。

---

## 六、来源

**P.T.**
- [P.T (Silent Hills teaser) game analysis — Game Developer](https://www.gamedeveloper.com/design/p-t-silent-hills-teaser-game-analysis)
- [Silent Halls: P.T., Freud, and Psychological Horror — Press Start (Univ. of Glasgow)](https://press-start.gla.ac.uk/press-start/article/view/121)
- [Silent Hills P.T Endless Hallway Horror (Part 3) — Medium](https://medium.com/@cemtuganli/silent-hills-p-t-demo-is-scary-because-part-3-13f712bcf052)
- [Never-ending hallway — Silent Hill Wiki](https://silenthill.fandom.com/wiki/Never-ending_hallway)
- [《寂静岭 P.T.》如何成为了新时代的都市传说？— 篝火营地](https://gouhuo.qq.com/content/detail/0_20200413213753_sOm1Xh5iD)
- [The Limits, Secrets, and Community of Horror Video Game 'P.T.' — PopMatters](https://www.popmatters.com/pt-limits-secrets-community-review)

**死亡搁浅 1 / 2**
- [Death Stranding video game — Fonts In Use](https://fontsinuse.com/uses/67648/death-stranding-video-game)
- [Death Stranding UI/UX Analysis — Nevaeh Li](https://www.nevaehli.com/uiux-analysis/death-stranding)
- [HOTPOWER 总监分享—《死亡搁浅》游戏视觉 UI — 站酷 ZCOOL](https://www.zcool.com.cn/article/ZMTA3MDE2MA==.html)
- [Recreating Death Stranding Odradek Terrain Scanner in Unity — 80.lv](https://80.lv/articles/recreating-death-stranding-odradek-terrain-scanner-in-unity)
- [Death Stranding — Casey Matsumoto(UI Designer portfolio)](https://www.caseymatsumoto.com/death-stranding/)
- [Death Stranding 2: On The Beach accessibility review — Can I Play That?](https://caniplaythat.com/2025/08/15/death-stranding-2-on-the-beach-accessibility-review/)
- [A Design Discussion on Death Stranding — Game Developer](https://www.gamedeveloper.com/design/a-design-discussion-on-death-stranding)
- [Hideo Kojima: Death Stranding 1 & 2 — Reverse Shot](https://reverseshot.org/features/3379/kojima_death_stranding)
- [Death Stranding — Interface In Game](https://interfaceingame.com/games/death-stranding)
- [Game UI Database — Death Stranding 2: On the Beach](https://www.gameuidatabase.com/gameData.php?id=2145)

**Milk outside a bag of milk outside a bag of milk**
- [Milk Outside a Bag of Milk Outside a Bag of Milk — Wikipedia](https://en.wikipedia.org/wiki/Milk_Outside_a_Bag_of_Milk_Outside_a_Bag_of_Milk)
- [Review: Milk outside a bag of milk outside a bag of milk — WD Productions](https://mackerelphones.com/2022/01/05/milk/)
- [Review — WayTooManyGames](https://waytoomany.games/2022/11/15/review-milk-inside-a-bag-of-milk-inside-a-bag-of-milk-milk-outside-a-bag-of-milk-outside-a-bag-of-milk/)
- [Milk inside a bag of milk inside a bag of milk — itch.io(开发者页)](https://nikita-kryukov.itch.io/pmkm)
- [Surreal visual novel 'milk inside a bag of milk' has a sequel now — PC Gamer](https://www.pcgamer.com/surreal-visual-novel-milk-inside-a-bag-of-milk-has-a-sequel-now-milk-outside-a-bag-of-milk/)

**Cosmic Ultramarine**
- [Cosmic Ultramarine — Steam 商店页](https://store.steampowered.com/app/3296760/Cosmic_Ultramarine/)
- [Cosmic Ultramarine — Steam 社区](https://steamcommunity.com/app/3296760)
- [Cosmic Ultramarine — TapTap](https://www.taptap.io/app/33767569)
- [Cosmic Ultramarine — Steambase](https://steambase.io/games/cosmic-ultramarine/info)

**Escape the Backrooms / 阈限空间**
- [Escape the Backrooms — Steam 商店页](https://store.steampowered.com/app/1943950/Escape_the_Backrooms/)
- [Escape the Backrooms — Wikipedia](https://en.wikipedia.org/wiki/Escape_the_Backrooms)
- [Escape the Backrooms Review — GameSpot(Mark Delaney, 6/10)](https://www.gamespot.com/reviews/escape-the-backrooms-review/1900-6418431/)
- [Escape the Backrooms 关卡表 — NamuWiki](https://en.namu.wiki/w/Escape%20the%20Backrooms/%EB%A0%88%EB%B2%A8)
- [The Philosophy of Liminal Spaces: Why "Backrooms" is so Disturbing — Mark Legg](https://agapesophia.substack.com/p/the-philosophy-of-liminal-spaces)
- [Backrooms and the sinister architecture of liminal spaces — Wallpaper*](https://www.wallpaper.com/art/film/backrooms-film-liminal-spaces)

**Disco Elysium**
- [Disco Elysium: Working on UI Design — 80.lv](https://80.lv/articles/disco-elysium-working-on-ui-design)
- [Disco Elysium's Text Box Design Is Inspired By How We Use Computers And… Twitter — Gamer Matters](https://gamermatters.com/disco-elysiums-text-box-design-is-inspired-by-how-we-use-computers-and-twitter/)
- [Why does isometric perspective suit Disco Elysium? — PC Gamer(Aleksander Rostov 访谈)](https://www.pcgamer.com/games/rpg/why-does-isometric-perspective-suit-disco-elysium-you-can-design-the-entire-game-as-if-it-was-a-painting/)
- [Graphic Assets(字体清单)— Disco Elysium Wiki](https://discoelysium.wiki.gg/wiki/Graphic_Assets)
- [Disco Elysium: User Interface — gamepressure](https://www.gamepressure.com/disco-elysium/user-interface/z5e3e8)
- [Disco Framework(UI 复刻框架)— Katy133 / itch.io](https://katy133.itch.io/disco-framework)
- [The Art Of Disco Elysium — MCV/DEVELOP](https://mcvuk.com/business-news/we-knew-immediately-that-we-needed-to-make-a-game-with-a-striking-and-unique-look-to-accompany-the-writing-a-look-that-would-balance-the-mundane-with-the-unfamiliar-and-strange-the-art/)

**Godot 4 实现参考**
- [Godot 4 CutsceneDirector: A Script-Based Alternative to Timelines — Manuel Sanchez](https://manuelsanchezdev.com/blog/godot-cutscenes/)
- [Godot 4 Camera Switcher: Smooth Camera Transitions for Cutscenes — Manuel Sanchez](https://manuelsanchezdev.com/blog/godot-camera-switcher/)
- [VHS and CRT monitor effect — Godot Shaders(CC0,含 Godot 4 迁移说明)](https://godotshaders.com/shader/vhs-and-crt-monitor-effect/)
- [CRT Display Shader (Pixel Mask, Scanlines & Glow) — Godot Shaders](https://godotshaders.com/shader/crt-display-shader-pixel-mask-scanlines-glow-godot-4-4-1/)
- [phantom-camera(Godot 4 相机框架)— GitHub](https://github.com/ramokz/phantom-camera)
