# 「拾取字→飞入笔记本」现状 vs 最佳实践差距分析与改进方案

**范围**:Godot 4.6 心理恐怖游戏既有拾取反馈系统(有测试保护)的差距分析,非从零设计。姊妹篇 `pickup_anim.md` 是设计期研究;本篇以**可读源码的开源实现 + 商业标杆**为参照,只谈"现状缺什么、怎么补"。

## 一、现状快照(基线)

动画链五个挂点(对应 `pickup_flight_layer.gd`):**HOOK_PRESS**(RichTextLabel meta 点击回调)→ **PH_ASCEND**(贝塞尔弧线放大 ×2.6 飞至屏幕中央)→ **PH_HOLD**(背景压暗 0.38、定格 0.5s)→ **PH_DIVE**(弧线加速缩小 ×0.55 飞入左上角笔记本)→ **PH_IMPACT**(笔记本 squash 1.05/0.96 回弹)。工程底座已达标:z=97 专用飞行层躲开滚动裁剪、目标点每帧读取支持笔记本拖拽中追踪、已拾取字全局唯一并永久灰化、缓动仅 QUINT/CUBIC、全程零随机。

## 二、开源同类实现拆解(均读过源码/结构)

| 项目 | 功能 | 架构 | 技术线 | 优点 | 缺点 |
|---|---|---|---|---|---|
| [guladam/deck_builder_tutorial](https://github.com/guladam/deck_builder_tutorial)(Godot 4 杀戮尖塔式) | 卡牌抽取/打出/弃牌飞行、悬停反馈 | 每张卡一个 Control + **状态机**(base/clicked/dragging/released/aiming),`card_ui.gd` 暴露 `animate_to_position()` | `create_tween()` + `TRANS_CIRC/EASE_OUT` 直线 tween global_position;状态用 StyleBox 切换;全局 `Shaker` 单例做震屏 | 状态机让"可被打断的动画"天然可测;动画入口单一 | 直线飞行无弧线;无定格阅读时刻;juice 靠样式切换偏朴素 |
| [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework)(框架级,Godot 3) | 手牌/桌面/牌堆间全部移动动画 | 巨型 `CardTemplate.gd`:按目标容器分派 `_add_tween_position/scale/rotation`,状态 `MOVING_TO_CONTAINER` 等 | 位移 TRANS_CUBIC/EASE_OUT、全局位移 TRANS_BACK、旋转 TRANS_BACK;**两段式 fancy move**(先中间点再落位);`reorganize_self()` 飞行中重算目标 | 动态重定目标、两段式节拍与本作同构,验证了我们的设计;时长惯例 0.25–0.3s | 单文件过重难移植;Godot 3 旧 Tween API |
| [grymmjack/godot-coindash](https://github.com/grymmjack/godot-coindash)(jam 级 juice 化 Coin Dash,[itch](https://grymmjack.itch.io/coin-dash)) | 金币拾取反馈 | `coin.gd` 自持动画,拾取即禁碰撞 | `TRANS_QUAD` 并行 scale→3 + alpha→0(0.3s)+ **必配拾取音效** | 说明 jam 基线:哪怕原地消失也**必须有声音** | 无飞向 HUD、无粒子;原地蒸发无空间连续性 |
| [ceceppa/anima](https://github.com/ceceppa/anima)(759★ MIT) | 声明式 UI 动画框架:89 种动画、33 缓动、stagger/grid | Autoload + 链式声明(`anima_keyframes`、序列/并行) | CSS 式 keyframes、曲线缓动、网格错峰 | 未来"整句/批量拾取"的 stagger 现成;声明式利于调参 | 无路径弧线与动态目标,飞行主链仍需手写;引入整个插件 |
| [EvilBunnyMan/TweenFX](https://github.com/EvilBunnyMan/TweenFX)(175★ MIT,Godot 4;另有镜像 [Killbot4/TweenFX](https://github.com/Killbot4/TweenFX)) | 单调用 juice 函数:`shake/pop_in/float_bob/snap`,可 await | Autoload 静态函数库 | 每个效果一个短 tween 封装 | 受击/弹出类点缀即插即用,适合笔记本徽标脉冲 | 无路径/无编排,不覆盖主链 |
| [xxidbr9/balatro-effect-recreate](https://github.com/xxidbr9/balatro-effect-recreate) + [r2d2meuleu/balatro](https://github.com/r2d2meuleu/balatro)(Balatro 复刻) | 卡牌悬停扭动、鱼眼/箔面等 | 场景极小,效果全走 shader(`fish-eyes/color-distort/fire-number.gdshader` 等) | **shader 层做 juice**,与 tween 解耦 | 展示"材质层反馈"路线:不动节点也能出质感 | 无收集/飞行逻辑;仅氛围件 |

**架构对照结论**:①我们的"每帧读取目标"与 db0 的 `reorganize_self()` 同级,两段式节拍被框架级实现背书,底座不落后;②guladam 的状态机启示——飞行替身应有**显式相位枚举 + 可中断 API**,而非一条不可打断的 tween 链;③coindash 说明**无音效即低于 jam 基线**(我们目前正是零音效);④anima/TweenFX 证明点缀类效果应封装成单调用函数,避免主链膨胀。

## 三、商业标杆逐帧参考

- **逆转裁判「证物加入法庭记录」**([Court Record](https://aceattorney.fandom.com/wiki/Court_record)):证物卡居中弹出+横幅文字"~を法廷記録に追加した"+专属确认音,**点击即跳过**。启示:居中定格要同时回答"是什么/去了哪"(文字注记),且必须可跳过——我们的 PH_HOLD 只有放大的字,**无注记、无确认音、不可打断**。
- **原神拾取横幅**([Interface In Game](https://interfaceingame.com/games/genshin-impact-mobile/)、[音效拆解](https://www.daviddumaisaudio.com/item-pickup-sound-design-tutorial-genshin-impact/)):普通材料仅左侧滚动列表+按稀有度分层音效,珍品才居中展示。启示:**分级反馈**——若未来有"关键剧情字",普通字可走短链,珍字才走全仪式;音效按重要度分层(恐怖题材反着来:越关键越低沉)。
- **Chants of Sennaar 笔记本收词**([玩家/开发者讨论](https://steamcommunity.com/app/1931770/discussions/0/4143942360095589829/)):字形先以"草图/猜测"态躺在笔记本,页级校验通过后统一转为"誊清"态;个人笔记自由填写。启示:**收集≠理解**,笔记本内可留两态(未组词=铅笔灰,已组词=墨黑),"组词成功"是第二次仪式,比拾取本身更值得铺张。
- **Duolingo 词块**([微交互分析](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682)、[LottieFiles 案例](https://lottiefiles.com/case-studies/duolingo)):词块本体做动画主体、一次动作一个反应、连续操作音高递进。启示:我们词块主体化已达标;**连拾的听觉序列感**缺失(可做逐次降半音的恐怖化变体)。
- **Baba Is You 规则形成**([Gamedeveloper 访谈](https://www.gamedeveloper.com/design/designing-i-baba-is-you-i-s-delightfully-innovative-rule-writing-system)、[Wikipedia](https://en.wikipedia.org/wiki/Baba_Is_You)):反馈以**状态对比**为主——成规则的词亮、闲置词暗,规则成立瞬间轻微闪动。启示:高价值反馈可以几乎零运动;笔记本里"能与新字组词的旧字"在入库瞬间短促点亮,是运动量最小、信息量最大的一招。
- 另:[BotW UI 分析](https://www.gamedeveloper.com/art/a-ui-ux-analysis-of-zelda-breath-of-the-wilds)的教训——获得仪式重复几十次后拖垮心流,**可跳过是硬需求**(我们每天多次拾取,0.5s 定格 × N 会累积)。

## 四、差距分析(候选项评分)

**现状已达标项**:空间连续性(两段弧线,db0 两段式 fancy move 同构)、阅读时刻(定格,逆转裁判范式)、余韵(永久灰化,进度地图)、动态目标追踪(框架级)、层级工程(z=97 专用层)、恐怖缓动纪律(QUINT/CUBIC、零随机)。两处参数值得复核:压暗 0.38 深于常规约定(15–20%),恐怖题材可接受,但深压暗对"连拾时 dim 被多条 tween 反复拉扯"极敏感,必须做防闪(见 P0-4);定格 0.5s 处于"看清一个放大汉字"的下限,单次合理,但不可打断时 N 次累积即 BotW 式仪式疲劳(见 P0-2)。

缺失项如下(价值/成本 ★1–5,恐怖适配:高=贴合压抑感/中=需改造/低=有风险):

| 候选项 | 价值 | 成本 | 恐怖适配 | 判定 |
|---|---|---|---|---|
| 音效层(纸声/墨滴/低频) | ★★★★★ | ★ | 高(材质声即氛围) | **P0**——当前零音效,低于 jam 基线 |
| 可跳过/加速 | ★★★★★ | ★ | 高(尊重节奏=不出戏) | **P0**(BotW/逆转教训) |
| 源位 anticipation(帖内字先缩) | ★★★★ | ★★ | 高("按进纸里") | **P0**,CharFXTransform 已确认可行 |
| 连拾队列错峰/合并 | ★★★★ | ★★ | 高(防中央区堵车) | **P0**(含 dim 引用计数防闪烁) |
| 到达中央的字义/组词注记 | ★★★★★ | ★★★ | 高(解读=玩法) | **P1**(需组词表数据接口) |
| 飞行拖尾/残影/墨点 | ★★★ | ★★ | 高(灰墨下沉;禁星光) | **P1** |
| reduced-motion | ★★★ | ★★ | 高(闪烁/运动本就要克制) | **P1**([指南](https://gameaccessibilityguidelines.com/full-list/):提供关闭动效选项) |
| 拾取计数徽标 | ★★★ | ★ | 中(需纸质化) | **P1** |
| 笔记本翻页反馈 | ★★ | ★★★ | 中(纸声可、白闪危险) | **P2** |
| 触觉(移动端) | ★★ | ★ | 高(8ms 微振=攥住感) | **P2** |
| 定格末字形 glitch | ★★ | ★ | 高(仅关键字;光敏安全) | **P2** |
| 连拾降半音音序 | ★★ | ★ | 高(反 Duolingo) | **P2** |

## 五、改进方案

所有新增效果必须遵守现有纪律:零随机(残影用固定间隔、粒子用固定 seed)、缓动仅 QUINT/CUBIC(过冲仅限已有 squash)、暗色低饱和。

### P0(必做,低成本高感知)

1. **音效三件套**。挂点:PH_ASCEND 起飞帧(纸张抽出摩擦声,干、低电平)、PH_HOLD 进入帧(墨滴/闷钟单拍低频确认音)、PH_IMPACT(合页"嗒"+极轻纸响)。要点:独立 `UI_Pickup` 总线便于全局衰减;`AudioStreamPlayer` 常驻飞行层复用。验收:三挂点各有声;连拾时 IMPACT 声错峰 ≥30ms 不叠噪;设置可整体静音。
2. **可跳过/加速**。挂点:飞行层 `_gui_input` 全局监听。要点:保存各替身 tween 引用;任意点击→处于 PH_HOLD 的替身立即进入 PH_DIVE,处于飞行段的 `set_speed_scale(3.0)`;参照 guladam 状态机,给替身加相位枚举 + `skip()`,并发 `phase_changed` 信号供测试断言。验收:连点 10 字总耗时 <(单字全程 ×3);字必达笔记本、全局唯一计数不变,**现有测试保护全绿**。
3. **源位 anticipation**。挂点:HOOK_PRESS,ghost 生成之前。要点:对被点字施加自定义 RichTextEffect,用 [CharFXTransform.transform](https://docs.godotengine.org/en/stable/classes/class_charfxtransform.html)(Transform2D,[官方定义](https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/CharFXTransform.xml)可"driving the position and rotation")做 1→0.92→1、80ms 的字心缩放——glyph 级变换**不回流布局**;备选 60ms hitstop(`Engine.time_scale=0.05` + `create_timer(..., ignore_time_scale)`,注意[计时器坑](https://forum.godotengine.org/t/engine-time-scale-doesnt-work-with-timers/74824))。验收:点击→起飞间有可感知"按下";RichTextLabel 不跳版;reduced-motion 下自动禁用。
4. **连拾错峰/合并 + dim 防闪**。挂点:PH_HOLD/PH_DIVE 调度层。要点:新字起飞时旧字(若在 HOLD)强制快进;多替身并行 DIVE;150ms 窗口内多次 IMPACT 合并为一次 squash+计数 N;**压暗层用引用计数**(进入 HOLD +1、离开 -1,归零才恢复),杜绝多 tween 抢 `color:a` 闪烁——0.38 的深压暗一旦闪烁极其刺眼。验收:快速连点 5 字无中央堆叠、dim 全程单调、squash ≤2 次。

### P1(应做)

5. **中央字义注记**。挂点:PH_HOLD 进入后 100ms。要点:字下细下划线 200ms 展开(QUINT_OUT)+ 小号注记(可组词数,如"可组:2",关键字显专属标记);数据走组词表查询接口,查无则优雅不显示。验收:注记 ≤250ms 出现;跳过时随替身即时消失。
6. **墨迹拖尾**。挂点:PH_DIVE。要点:每 0.05s 复制一个替身残影(固定间隔,零随机),`modulate.a` 0.35→0、300ms、灰黑色,残影不接输入;或 CPUParticles2D 4–6 粒墨点、重力向下、固定 seed。验收:不遮挡笔记本文字;reduced-motion 关闭;同屏 ≤3 替身时帧率无感知下降。
7. **reduced-motion 设置**。挂点:飞行层入口分支。要点:开启后替身不飞——原位 300ms 淡出 + 笔记本词块淡入,音效保留,dim 保留浅版(0.15);glitch/拖尾/anticipation 全禁;符合[无障碍指南](https://gameaccessibilityguidelines.com/full-list/)"可关闭动效/避免闪烁"。验收:该模式下计数、灰化、词块、行动消耗全部正确,测试套双模式跑通。
8. **计数徽标 + 行动消耗联动**。挂点:PH_IMPACT。要点:笔记本页角计数 label 脉冲(1→1.15→1,CUBIC,120ms,TweenFX 式封装);当日首拾时行动点图标同步暗红脉冲一次,把"消耗 1 行动"显性化。验收:徽标数=全局已拾集合大小;首拾/后续免费的视觉区分可肉眼辨认。

### P2(彩蛋)

9. **翻页微反馈**:关键字入库时页面纹理位移 8px + 纸声(不做白闪,光敏安全);10. **定格末 glitch**:仅关键剧情字,1 帧 offset ±2px 字形错位,频率远低于 3Hz;11. **触觉**:移动端 `Input.vibrate_handheld(8)` 于 PH_IMPACT;12. **降半音连拾音序**:确认音逐次降半音、5 层封顶复位;13. **笔记本内组词点亮**(Baba 式):新字入库瞬间,可与其组词的旧词块 150ms 微亮一次——运动量最小、信息量最大的候补,验证组词表接口后可升 P1。

**落地顺序与测试策略**:P0-1/2 一天内可完成且感知最强;P0-3 依赖自定义 RichTextEffect,先做 spike 验证 meta 区间与 effect 作用区间对齐(BBCode 标签需包住单字);P1-5 依赖组词数据接口,与玩法侧对齐后再动。测试侧:为替身相位枚举补 `phase_changed` 信号断言(拾取一次应依序发出 PRESS→ASCEND→HOLD→DIVE→IMPACT);跳过路径断言"任意时刻 skip 后最终状态与完整播放一致"(计数、灰化、词块);reduced-motion 与正常模式做参数化双跑;连拾 5 字压力用例断言 dim 单调、IMPACT 合并次数 ≤2。所有新效果走既有零随机纪律,动画时长集中到常量表便于回归比对。

## 六、来源

**开源实现**:[guladam/deck_builder_tutorial](https://github.com/guladam/deck_builder_tutorial) · [card_ui.gd 源码](https://raw.githubusercontent.com/guladam/deck_builder_tutorial/main/scenes/card_ui/card_ui.gd) · [DeepWiki 架构页](https://deepwiki.com/guladam/deck_builder_tutorial) · [db0/godot-card-game-framework](https://github.com/db0/godot-card-game-framework) · [CardTemplate.gd 源码](https://raw.githubusercontent.com/db0/godot-card-game-framework/main/src/core/CardTemplate.gd) · [grymmjack/godot-coindash](https://github.com/grymmjack/godot-coindash) · [Coin Dash! (itch)](https://grymmjack.itch.io/coin-dash) · [ceceppa/anima](https://github.com/ceceppa/anima) · [EvilBunnyMan/TweenFX](https://github.com/EvilBunnyMan/TweenFX) · [Killbot4/TweenFX](https://github.com/Killbot4/TweenFX) · [xxidbr9/balatro-effect-recreate](https://github.com/xxidbr9/balatro-effect-recreate) · [r2d2meuleu/balatro](https://github.com/r2d2meuleu/balatro) · [stormtoy/card_fan_demo](https://github.com/stormtoy/card_fan_demo) · [DesirePathGames/Slay-The-Robot](https://github.com/DesirePathGames/Slay-The-Robot) · [Houtamelo/spire_tween](https://github.com/Houtamelo/spire_tween) · [Balatro Card Hover shader](https://godotshaders.com/shader/balatro-card-hover/)
**商业标杆**:[Ace Attorney Court Record](https://aceattorney.fandom.com/wiki/Court_record) · [Genshin (Interface In Game)](https://interfaceingame.com/games/genshin-impact-mobile/) · [Genshin 拾取音效拆解](https://www.daviddumaisaudio.com/item-pickup-sound-design-tutorial-genshin-impact/) · [Chants of Sennaar 校验讨论](https://steamcommunity.com/app/1931770/discussions/0/4143942360095589829/) · [Chants of Sennaar 评析](https://blog.chordian.net/2024/09/15/chants-of-sennaar/) · [Duolingo 微交互](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682) · [Duolingo × LottieFiles](https://lottiefiles.com/case-studies/duolingo) · [Baba Is You 规则系统访谈](https://www.gamedeveloper.com/design/designing-i-baba-is-you-i-s-delightfully-innovative-rule-writing-system) · [Baba Is You (Wikipedia)](https://en.wikipedia.org/wiki/Baba_Is_You) · [BotW UI/UX 分析](https://www.gamedeveloper.com/art/a-ui-ux-analysis-of-zelda-breath-of-the-wilds)
**引擎/技术**:[CharFXTransform 文档](https://docs.godotengine.org/en/stable/classes/class_charfxtransform.html) · [CharFXTransform.xml(引擎源)](https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/CharFXTransform.xml) · [Tween 文档](https://docs.godotengine.org/en/stable/classes/class_tween.html) · [time_scale 与 Timer](https://forum.godotengine.org/t/engine-time-scale-doesnt-work-with-timers/74824) · [time_scale 豁免提案](https://github.com/godotengine/godot-proposals/issues/9068) · [Godot 4 Tween Juice 教程](https://codingquests.io/blog/godot-4-tween-tutorial-juice)
**无障碍**:[Game Accessibility Guidelines 全列表](https://gameaccessibilityguidelines.com/full-list/) · [web.dev 动效无障碍](https://web.dev/learn/accessibility/motion) · [Smashing: Reduced Motion](https://www.smashingmagazine.com/2020/09/design-reduced-motion-sensitivities/)
