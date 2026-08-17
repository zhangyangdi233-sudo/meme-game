# 「拾取汉字 → 收集入笔记本」UI 动效研究报告

**项目背景**:Godot 4.6 中文心理恐怖游戏。玩家在手机瀑布流帖子中点击拾取单个汉字,动画链为:原位起飞 → 放大飞至屏幕中央短暂停留(确认"拿到了") → 缩小飞入左上角可拖拽的笔记本窗口(成为词块),并在帖子原位留下"已拾取"余韵。

---

## 一、经典范式拆解:这条动画链在业界的原型

**1. Coin-fly-to-counter(金币飞入计数器)**。手游最普及的"获得→归位"范式:奖励从产生点沿弧线飞向 HUD 计数器,到达时计数器跳字并弹跳。其核心价值是**空间连续性**——玩家的眼睛被引导着看清"东西去了哪里",从而学会资源的存放位置(参见 Unity 圈的 [coin fly 教程](https://medium.com/@trisledinh/unity-how-to-create-effect-coin-fly-in-less-than-15-minutes-9a2e7f72aff2)、[DOTween 收集动画](https://www.youtube.com/watch?v=TRUOqUGAfLM))。这正对应 Material Design 的 **container transform / shared element** 思想:元素在两个界面位置之间保持同一实体感([Implementing Motion, Google Design](https://medium.com/google-design/implementing-motion-9f2839002016))。

**2. 塞尔达/逆转裁判的"居中定格"**。BotW 获得道具时居中放大展示+短暂定格,逆转裁判则弹出居中证物卡+「~を法廷記録に追加した」横幅+专属确认音([Court Record, Ace Attorney Wiki](https://aceattorney.fandom.com/wiki/Court_record))。这是**叙事性确认**:强迫一个"阅读时刻",保证玩家读到了物品名。但 [BotW 的 UI/UX 分析](https://www.gamedeveloper.com/art/a-ui-ux-analysis-of-zelda-breath-of-the-wilds)指出重要教训:仪式化展示重复几十次后"开始显得沉重、打断心流"——**居中定格必须短、必须可加速/可跳过**。

**3. 原神的分级策略**。普通材料只在屏幕左侧滚动出低调的拾取列表(带稀有度色),仅珍贵物品才触发居中展示([Genshin Impact Mobile, Interface In Game](https://interfaceingame.com/games/genshin-impact-mobile/);拾取音按稀有度分层,见[音效拆解](https://www.daviddumaisaudio.com/item-pickup-sound-design-tutorial-genshin-impact/))。启示:若后期出现批量拾取,不必每个字都走全流程。

**4. Duolingo 词块**。词块从词库点击后位移进答案行,完成时进度条脉冲、音效分层,"一个动作、一个反应"([Duolingo 微交互分析](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682)、[LottieFiles 案例](https://lottiefiles.com/case-studies/duolingo))——它证明"文字块"本身可以作为动画主体,无需图标包装。**A Short Hike** 则示范了轻量拾取反馈如何服务探索循环([设计拆解](https://alexiamandeville.medium.com/game-design-breakdown-a-short-hike-5a7a17d740e5))。

**结论**:本需求 = "coin-fly 的空间连续性" + "逆转裁判式居中确认" 的串联。中央停留回答"我拿到了什么",飞入笔记本回答"它去了哪里",原位灰字回答"哪里已被拿过"。三个问题各由一个阶段负责,不可互相挤占。

---

## 二、动效理论要点

- **时长心理学**([NN/g](https://www.nngroup.com/articles/animation-duration/)、[Val Head](https://valhead.com/2016/05/05/how-fast-should-your-ui-animations-be/)):单段动画合理区间 **100–500ms**;<100ms 无法感知,≥500ms 开始"拖"。常见错误是太长而非太短。移动端状态变化建议 200–300ms,位移越远时长越取上限([Skytskyi 动效指南](https://uxdesign.cc/the-ultimate-guide-to-proper-use-of-animation-in-ux-10bd98614fa9))。注意:总链条可以超过 500ms,但**每一段**都要落在区间内,且停留段是"静止阅读"不算动画负担。
- **Material 缓动数值**([M1 Duration & Easing](https://m1.material.io/motion/duration-easing.html)/[镜像](https://www.mdui.org/en/design/1/motion/duration-easing.html)、[M3](https://m3.material.io/styles/motion/easing-and-duration)):入场用减速曲线 cubic-bezier(0,0,0.2,1)、约 225ms;离场用加速曲线 cubic-bezier(0.4,0,1,1)、约 195ms;标准转场 300ms。**入场 ease-out、离场 ease-in** 是跨平台共识(NN/g 同)。
- **缓动性格**([easings.net](https://easings.net/)):Cubic/Quint/Expo-Out = 干脆、机械;Back-Out = 小过冲、有"落位感";Elastic/Bounce = 弹糖果感,喜剧化。**恐怖题材应默认 Cubic/Quint/Expo,Back 限小幅,禁 Elastic/Bounce**(详见第六节)。
- **弧线 vs 直线**(Skytskyi、Material):元素同时发生**不成比例的位移+缩放**时,直线会显得机械僵硬,应沿弧线运动;弧线也更符合 Disney 第 7 原则 Arcs 的自然抛物感。本需求两段飞行都伴随大幅缩放,**均应走贝塞尔弧线**,且两段弧的弯曲方向一致(如都向上拱),形成连贯"抛-收"轨迹。
- **Disney 12 原则的直接映射**([IxDF](https://ixdf.org/literature/article/ui-animation-how-to-apply-disney-s-12-principles-of-animation-to-ui-design)、[UX Collective](https://uxdesign.cc/disneys-12-principles-of-animation-exemplified-in-ux-design-5cc7e3dc3f75)):Anticipation→点击瞬间原字先微缩 0.92 再起飞;Squash & Stretch→笔记本"接住"时压扁回弹;Follow-through→词块入槽后 5% 过冲;Staging→中央停留时背景压暗聚焦;Secondary action→残影/墨点粒子;Slow in/out→全部缓动非线性。
- **Juice 层叠与克制**("Juice it or lose it" 2012、"The art of screenshake" 2013;摘要见 [egmatic](https://egmatic.com/blog/how-to-make-your-game-feel-good)、[Game feel on the web](https://valdemird.com/blog/game-feel-on-the-web/)):反馈要视觉+听觉+(触觉)多通道叠加;**hitstop 60–90ms** 能凭空卖出"分量";screenshake 要小幅、带微旋转、绝不持续;最强效果留给最稀有事件,否则失去意义。
- **编排**(Skytskyi):一次只让一个主角动。飞行替身是唯一主角;原位灰化、背景压暗都用无位移的透明度/颜色过渡,不与主角抢视线。

---

## 三、动效节拍表(可直接照做)

总时长约 **1.4–1.6s**(首次);重复拾取时 P2 可压到 200ms 或被下一次点击直接快进。

| 阶段 | 时长 | 运动/数值 | Godot 缓动 | 视觉 | 音效 |
|---|---|---|---|---|---|
| **P0 按压确认** | 70–90ms | 原字 scale 1→0.92→1(anticipation);可选全局 hitstop 60ms | TRANS_QUAD / EASE_OUT | 字面轻微下压,像按进纸里 | 干燥的"纸面按下"嗒声(低电平) |
| **P1 起飞→中央** | 320–380ms | 贝塞尔弧线位移;scale 1→2.6–3.0;替身淡入 alpha 0.9→1 | 位移+缩放:TRANS_QUINT / EASE_OUT | **起飞瞬间**原位立即灰化/留空槽(余韵开始);替身可带 1–2 帧字形残影 | 低哑"抽出"摩擦声(纸/布料) |
| **P2 中央定格** | 450–600ms | 静止;入场末端带 ≤8% 过冲落位;可 ±2% 极缓呼吸 | 落位:TRANS_BACK / EASE_OUT(0.12s) | 背景压暗 15–20%(200ms 渐入);字下方一条细下划线展开+极小号"已拾取"注记 | 单个低频确认音:墨滴/闷钟/心跳单拍,不用清脆 chime |
| **P3 缩入笔记本** | 280–340ms | 贝塞尔弧线位移(**每帧追踪**笔记本槽位,支持拖拽中);scale →0.9;末端 alpha→0.85 | TRANS_CUBIC / EASE_IN(离场加速) | 背景亮度同步恢复;可留一条快速淡出的灰色尾迹 | 短促"吸入"嗖声(加低通滤波) |
| **P4 入库受击** | 130–180ms | 笔记本窗口 scale (1.04,0.96)→(1,1);词块在槽内 scale 0→1.05→1 | TRANS_BACK / EASE_OUT | 词块 1 次暗红高亮后归于常态;计数+1 | 图钉/合页"嗒" + 极轻纸响;可加 5ms 手机振动 |
| **P5 长余韵** | 300ms(与 P1 并行) | 无位移 | TRANS_LINEAR(仅颜色) | 帖子原位永久灰字(modulate 0.45)或虚线空槽;鼠标悬停不再响应 | — |

节拍依据:P1/P3 落在 NN/g 大位移 300–400ms 区间;P2 定格 ≈ 逆转/塞尔达确认时长的最小可读值;P4 是 juice 层("接住"的 squash);两段飞行"快—停—快"的对比本身就是 Timing 原则的运用——停留因前后皆快而显得郑重。

### 3.1 轨迹与两段式节拍的设计取舍

- **直线 vs 弧线的观感**:直线位移在"位移+大幅缩放"同时发生时会产生生硬的"PPT 平移感",且视线难以预测终点;弧线让眼睛沿切线自然预判落点,并暗含重量(抛物线是物理直觉)。本链两段都缩放剧烈,必须走弧线。弧的弯曲要**收敛**:P1 上拱约 80–140px(取决于起点距中心的距离),P3 因目标在左上角、行程更短,拱高降到 40–60px——两段同向的浅弧连起来像一次"扬起—收拢"的手势,而两段反向弧会读成两个无关事件。
- **为什么必须两段而不是一段直飞**:一段式 coin-fly 只回答"去了哪",无法保证玩家读清是哪个字——汉字是本作的核心叙事资源,读清字形字义是玩法本身,所以需要逆转裁判式的"阅读时刻"。反过来,只居中展示不飞入,则玩家学不会"字都收进了左上角笔记本"这一空间模型。两段各司其职,砍掉任何一段都损失一类信息。
- **停留时长的弹性**:450–600ms 是"看清一个放大汉字"的下限;若字附带释义浮层,延长到 800ms 并允许点击提前结束。**节奏优先级:可打断 > 精确时长**——定格期间任何输入都应立即触发 P3。
- **连拾合并**:玩家快速连点多个字时,不排队播全流程(总时长会爆炸),采用"toast 合并"策略:新字起飞时,仍在 P2 定格的旧字直接快进入 P3(speed_scale 3.0);多个替身可同时处于 P3 飞行,入库音效做 30ms 错峰避免叠成噪音;若未来出现"整句拾取",改用列表式 stagger(每字延迟 20–25ms 依次起飞,Skytskyi 列表项规范),中央阶段合并为一次整句展示。
- **余韵的双端设计**:余韵要同时留在"来处"与"去处"。来处:原位灰字/空槽是**永久状态**而非动画,它是玩家的进度地图(哪些帖子已榨干);建议灰化再叠加轻微字距塌陷(空槽宽度保留 100%,避免文本重排跳动)。去处:笔记本受击 + 词块短暂高亮是**瞬时状态**,150ms 内归于平静——恐怖氛围里,"收下之后迅速恢复死寂"本身就是一种表达。

---

## 四、Godot 4 节点结构与 Tween 代码建议

### 4.1 场景结构

```
Main (Control, 手机UI根)
├─ PhoneFeed (ScrollContainer → VBox 瀑布流; clip_contents=true)
│    └─ Post → 每个可拾取汉字是独立小 Label(或 RichTextLabel meta)
├─ NotebookWindow (Panel + 自写拖拽; **不要用 OS Window 节点**)
│    └─ WordGrid (GridContainer/FlowContainer 词块)
└─ FlightLayer (CanvasLayer, layer = 100)   ← 飞行替身专用顶层
```

要点:
- **顶层 CanvasLayer**:替身若留在 ScrollContainer 里会被 `clip_contents` 裁剪、被滚动带跑。放入独立 [CanvasLayer](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html)(layer 高于一切 UI)即可全屏自由飞行。简单场景也可用 `ghost.top_level = true`,但 CanvasLayer 同时解决层级遮挡,更稳。
- **坐标换算**:跨 CanvasLayer 时 `global_position` 不同系,需统一到视口坐标:源字用 `label.get_global_transform_with_canvas().origin`(或 Control 的 `get_screen_position()`);Godot 论坛的[同类问题](https://forum.godotengine.org/t/global-positioning-is-a-miracle-to-me-cant-tween-a-collectable-to-the-hud-position/130156)结论一致:跨层必须显式做 canvas transform 换算,不能盲信 global_position。笔记本用 Panel(同一 viewport)则其内部槽位坐标可直接与 FlightLayer 互通。
- **克隆 Label 做替身**:`duplicate()` 源字 Label(或新建 Label 复制 text/font/size),源字瞬间灰化。替身要设 `pivot_offset = size/2` 才能以字心缩放。

### 4.2 Tween 链骨架([Tween 文档](https://docs.godotengine.org/en/stable/classes/class_tween.html);TransitionType 含 SPRING/BACK/ELASTIC 等,默认 TRANS_LINEAR/EASE_IN_OUT,务必显式设置)

```gdscript
# pickup_fx.gd — 挂在 FlightLayer;每次拾取调用 fly_char()
func fly_char(src: Label, notebook: NotebookWindow) -> void:
    var ghost: Label = src.duplicate()
    add_child(ghost)
    var from: Vector2 = src.get_global_transform_with_canvas().origin
    ghost.position = from
    ghost.pivot_offset = ghost.size / 2.0
    src.modulate = Color(0.45, 0.45, 0.45)          # P5 余韵:原位灰化
    src.mouse_filter = Control.MOUSE_FILTER_IGNORE

    var center := get_viewport().get_visible_rect().size * 0.5 - ghost.size * 1.5
    var tw := create_tween()
    _active[ghost] = tw                              # 存引用,供快进/kill

    tw.set_parallel(true)                            # —— P1 起飞
    tw.tween_method(_arc.bind(ghost, from, func(): return center),
        0.0, 1.0, 0.35).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    tw.tween_property(ghost, "scale", Vector2(2.8, 2.8), 0.35)\
        .set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
    tw.tween_property(dimmer, "color:a", 0.18, 0.2)  # 背景压暗

    tw.chain().tween_interval(0.55)                  # —— P2 定格(阅读时刻)

    tw.chain().set_parallel(true)                    # —— P3 缩入笔记本
    tw.tween_method(_arc.bind(ghost, center,
        notebook.get_slot_screen_pos),               # 传函数→每帧取,拖拽中也能追踪
        0.0, 1.0, 0.32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tw.tween_property(ghost, "scale", Vector2(0.9, 0.9), 0.32)\
        .set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
    tw.tween_property(dimmer, "color:a", 0.0, 0.25)

    tw.chain().tween_callback(func():                # —— P4 入库
        ghost.queue_free()
        notebook.add_word_block(src.text)            # 词块 pop-in + 受击
    )

func _arc(t: float, node: Control, from: Vector2, to_getter: Callable) -> void:
    var to: Vector2 = to_getter.call()
    var mid := (from + to) * 0.5 + Vector2(0, -120.0)   # 控制点上拱 → 弧线
    node.position = from.bezier_interpolate(mid, mid, to, t)
```

```gdscript
# notebook_window.gd — 受击 squash(Disney: squash & stretch + follow-through)
func add_word_block(ch: String) -> void:
    var block := preload("res://ui/word_block.tscn").instantiate()
    block.text = ch
    word_grid.add_child(block)
    block.pivot_offset = block.size / 2.0
    block.scale = Vector2.ZERO
    var tw := create_tween()
    tw.tween_property(block, "scale", Vector2.ONE, 0.15)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
    pivot_offset = Vector2(size.x * 0.5, 0.0)        # 以顶边为轴,像被砸了一下
    var tw2 := create_tween()
    tw2.tween_property(self, "scale", Vector2(1.04, 0.96), 0.06)
    tw2.tween_property(self, "scale", Vector2.ONE, 0.12)\
        .set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
```

工程细节:弧线用 `tween_method` + `Vector2.bezier_interpolate`(直线 `tween_property(position)` 会显僵);连拾防重入——同一 Label 起飞后立刻禁点击;快进——保存 tween 引用,玩家再次点击任意处时对在飞替身 `tw.set_speed_scale(3.0)` 或 `kill()` 后直接结算入库(BotW 教训);`bind_node(ghost)` 让替身释放时 tween 自动失效。教程参考:[Coding Quests Godot 4 Tween Juice](https://codingquests.io/blog/godot-4-tween-tutorial-juice)、[跨场景 tween 到屏幕角落](https://forum.godotengine.org/t/how-do-i-tween-an-image-from-its-placed-coordinates-in-my-scene-to-the-corner-of-the-screen/14818)、[Tween cheatsheet](https://freetimedev.itch.io/godot-tween-cheatsheet)。

---

## 五、开源参考项目对比

| 项目 | 定位 | 优点 | 局限 | 本项目用法 |
|---|---|---|---|---|
| [ceceppa/anima](https://github.com/ceceppa/anima) (759★, MIT) | 完整 UI 动画框架:89 种动画(源自 Animate.css)、33 种缓动、CSS 式声明、序列/并行/网格 stagger | 声明式链、支持曲线缓动与相对值、group/grid 交错入场适合"多词块列表出现" | 引入整个插件;部分特性仅限 Godot 4;学习成本 | 若后期 UI 动效多(菜单、词块批量入场)可全面接管 |
| [EvilBunnyMan/TweenFX](https://github.com/EvilBunnyMan/TweenFX) (MIT, Godot 4) | 轻量 juice 函数库:`shake / pop_in / float_bob / snap`,`await TweenFX.pop_in(node).finished` | 单文件级、即插即用、专攻"受击/弹出"类点缀 | 无路径动画、无复杂链 | 直接用于笔记本受击、词块 pop-in;飞行主链仍手写 |
| [gurbsgurbs/tween-composer](https://github.com/gurbsgurbs/tween-composer-godot) | Inspector 内可视化编排可复用 tween | 策划/美术可直接调节拍表数值,免改代码 | 项目新、生态小 | 用于快速迭代 P1–P4 时长与缓动参数 |

结论:**飞行主链用原生 Tween 手写**(依赖弧线 tween_method 与动态目标,库都不擅长);受击/弹出类点缀引 TweenFX 式小函数;若全游戏 UI 动效规模化再考虑 Anima。另有 [GlobalTweens](https://github.com/Rp-ics/Godot-Engine-GlobalTweens) 提供异步全局 tween 工具集可参考其 API 设计。

---

## 六、恐怖氛围适配(不破坏压抑感的 juice)

心理恐怖的 UI 应当"克制而精确"——[Signalis 的 UI 分析](https://steventus.substack.com/p/glancing-signalis-part-1-immersion)证明:极简、贴合世界观的界面反而把玩家按进恐怖本身;[恐怖游戏设计](https://gamedesignskills.com/game-design/horror/)与[叙事式 UI 框架](https://nastyrodent.com/diegetic-and-non-diegetic-ui/)同样主张 UI 尽量伪装成世界内之物(本作的手机+笔记本天然是叙事道具,优势极大)。具体准则:

1. **缓动选机械感,拒绝糖果感**:全链使用 Cubic/Quint/Expo;Back 过冲 ≤8% 且只用于"落位";**禁用 Elastic/Bounce/彩色 confetti**——那是 Duolingo 的语言,不是恐怖的。
2. **低饱和、以暗代亮**:替身不加辉光;P2 聚焦靠"背景压暗 18%"而非给字打光;词块高亮用暗红/纸黄单色一次性闪过。
3. **音效换材质**:纸张摩擦、铅笔、老式打字机、闷心跳,干声少混响、音量低;分层思路借鉴原神(普通字/关键字两级音色)但音色反着来——越关键越低沉,而非越清脆。
4. **粒子=墨与灰**:P4 可溅 4–8 粒向下沉降的墨点/纸屑(重力向下、初速小),绝不上飘星光。
5. **恐怖专属 juice**:P2 定格末尾插 1 帧字形错位/抖动 glitch(暗示"字被系统注视");P0 的 60ms hitstop 让点击本身带一丝"被攥住"的压迫(hitstop 卖分量的原理见 [Game feel on the web](https://valdemird.com/blog/game-feel-on-the-web/));偶发关键剧情字可让笔记本受击时窗口极小幅(±1.5px, 90ms)颤一下——screenshake 三原则:小幅、含微旋转、瞬止。
6. **可访问性**:设置里提供"减少动态效果"(理念同 [prefers-reduced-motion](https://web.dev/learn/accessibility/motion)、[Smashing 指南](https://www.smashingmagazine.com/2020/09/design-reduced-motion-sensitivities/)):开启后替身不飞行,改为原位淡出 300ms + 笔记本词块淡入,信息不丢、运动归零;glitch/颤动禁用;不使用高频闪烁(>3 次/秒);所有动效可被点击快进。

---

## 七、来源总表

**范式**:[BotW UI/UX 分析 (Game Developer)](https://www.gamedeveloper.com/art/a-ui-ux-analysis-of-zelda-breath-of-the-wilds) · [Game UI Database: BotW](https://www.gameuidatabase.com/gameData.php?id=35) · [Ace Attorney Court Record Wiki](https://aceattorney.fandom.com/wiki/Court_record) · [Genshin (Interface In Game)](https://interfaceingame.com/games/genshin-impact-mobile/) · [Genshin 拾取音效拆解](https://www.daviddumaisaudio.com/item-pickup-sound-design-tutorial-genshin-impact/) · [A Short Hike 设计拆解](https://alexiamandeville.medium.com/game-design-breakdown-a-short-hike-5a7a17d740e5) · [Duolingo 微交互](https://medium.com/@Bundu/little-touches-big-impact-the-micro-interactions-on-duolingo-d8377876f682) · [Duolingo × LottieFiles](https://lottiefiles.com/case-studies/duolingo) · [Unity coin fly](https://medium.com/@trisledinh/unity-how-to-create-effect-coin-fly-in-less-than-15-minutes-9a2e7f72aff2)
**理论**:[NN/g 动画时长](https://www.nngroup.com/articles/animation-duration/) · [Material M1 Duration & Easing](https://m1.material.io/motion/duration-easing.html)([镜像](https://www.mdui.org/en/design/1/motion/duration-easing.html)) · [Material M3 Easing & Duration](https://m3.material.io/styles/motion/easing-and-duration) · [Implementing Motion (Naimark)](https://medium.com/google-design/implementing-motion-9f2839002016) · [Skytskyi 动效终极指南](https://uxdesign.cc/the-ultimate-guide-to-proper-use-of-animation-in-ux-10bd98614fa9) · [IxDF: Disney 12 原则×UI](https://ixdf.org/literature/article/ui-animation-how-to-apply-disney-s-12-principles-of-animation-to-ui-design) · [UX Collective: Disney 12 原则](https://uxdesign.cc/disneys-12-principles-of-animation-exemplified-in-ux-design-5cc7e3dc3f75) · [Juice/game feel 综述 (egmatic)](https://egmatic.com/blog/how-to-make-your-game-feel-good) · [Game feel on the web](https://valdemird.com/blog/game-feel-on-the-web/) · [Val Head: How fast](https://valhead.com/2016/05/05/how-fast-should-your-ui-animations-be/) · [easings.net](https://easings.net/)(经典演讲:Jonasson & Purho "Juice it or lose it" 2012;Nijman "The art of screenshake" 2013)
**Godot**:[Tween 类文档](https://docs.godotengine.org/en/stable/classes/class_tween.html) · [CanvasLayer 文档](https://docs.godotengine.org/en/stable/classes/class_canvaslayer.html) · [Coding Quests: Godot 4 Tween Juice](https://codingquests.io/blog/godot-4-tween-tutorial-juice) · [论坛:跨 CanvasLayer tween 收集物](https://forum.godotengine.org/t/global-positioning-is-a-miracle-to-me-cant-tween-a-collectable-to-the-hud-position/130156) · [论坛:tween 到屏幕角落](https://forum.godotengine.org/t/how-do-i-tween-an-image-from-its-placed-coordinates-in-my-scene-to-the-corner-of-the-screen/14818) · [Tween cheatsheet](https://freetimedev.itch.io/godot-tween-cheatsheet) · [anima](https://github.com/ceceppa/anima) · [TweenFX](https://github.com/EvilBunnyMan/TweenFX) · [tween-composer](https://github.com/gurbsgurbs/tween-composer-godot) · [GlobalTweens](https://github.com/Rp-ics/Godot-Engine-GlobalTweens)
**恐怖/可访问性**:[Signalis UI 沉浸分析](https://steventus.substack.com/p/glancing-signalis-part-1-immersion) · [恐怖游戏设计 (GameDesignSkills)](https://gamedesignskills.com/game-design/horror/) · [Diegetic UI 框架](https://nastyrodent.com/diegetic-and-non-diegetic-ui/) · [web.dev 动效无障碍](https://web.dev/learn/accessibility/motion) · [Smashing: Reduced Motion](https://www.smashingmagazine.com/2020/09/design-reduced-motion-sensitivities/)
