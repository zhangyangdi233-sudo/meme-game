# 闪回 / 侵入性记忆表现技法研究报告
——面向《语言污染》60% 污染值一次性闪回（Godot 4.6）的实现指导

## 0. 摘要与设计立场

调研了 12+ 部游戏与关键电影文本后，核心结论有四条：

1. **闪回不是"插入画面"，而是"抢走当下"。** Mouthwashing 的做法是先冻结画面、音频卡顿，再跳入过去；Signalis 用黑帧+文字卡切碎蒙太奇。最有效的入侵感来自"当前帧被夺走"（冻结），而非"新画面砸进来"（爆闪）。这天然规避 jump scare，也天然符合 WCAG。
2. **本作的叙事核心（同一句话被两个人格占用）对应的电影原型是今敏**：Perfect Blue 里 Mima 四次"在床上醒来"，同一构图反复出现、内容微变，观众失去判定真实层的能力。技法上就是**同构匹配剪辑（match cut on identical composition）+ 保留一个恒定元素**。本作的恒定元素应当是那句话本身——句子钉死在屏幕上，背后的世界（玩偶↔医生）被整体替换。
3. **"语言污染"应污染元数据而非正文。** DDLC 损坏的是说话人名与 UI、Umineko 用文字颜色标记真值（红字）、Fata Morgana 靠隐藏称谓制造归属骗局——它们都不碰"要被读到的那句话"。因此关键句字形永远完好，被污染的是：说话人名牌、引号方向、文字颜色、音源归属。这同时满足"关键句必须可读"的硬约束。
4. **声音先于画面、迟于画面离场。** J-cut（语音在黑帧上先响起）制造"记忆先于画面入侵"；L-cut+反向混响音尾让记忆"拒绝离场"；房间底噪先消失 400ms 是最好的无惊吓预兆——恐怖音频设计共识是"静默比巨响更可怕"。

---

## 1. 案例拆解（游戏）

**Signalis（重点）**：官方光敏警告页自述其过场"在黑、高强度红与亮帧之间快速切换"——即黑帧-红帧-剧照交替的快切蒙太奇；wiki 记载其剪辑直接引用 EVA 剧场版"图像在人物剪影上闪现"的手法。记忆锚点是一张会变脸的拍立得（Ariane↔Alina），文字卡"REMEMBER OUR PROMISE"以红字插帧反复出现；同构房间在不同时空重复、错位。**可迁移**：黑帧当标点、单句文字卡独占一帧、锚点物在两次闪回中"同物不同人"。**需改造**：其红黑快闪频率超过 3 次/秒，必须降频、降红饱和度。

**今敏（Perfect Blue / 妄想代理人，重点，见 §2）**。

**DDLC**：糟蹋的是"容器"——损坏的标题画面、用别人部件拼出来的 Sprite、被删的文件；音乐在关键处**整段消失**，玩家在纯静默中读字。**可迁移**：说话人名牌损坏、静默阅读。

**OMORI**：三层空间（White/Headspace/Black Space）对应回避/退行/直面；Black Space 用 18 个风格互不一致的房间阻止玩家建立预期；真相段落用相册照片逐张推进——**照片=记忆物证，但物证本身被涂改**。**可迁移**：闪回两段用"同一张构图、两套美术风格"的不一致感。

**Silent Hill 系列**：表世界→里世界的**材质剥落式过渡**（世界还在，表皮换了）与收音机白噪（主观听觉信号）。**可迁移**：闪回不换机位只换贴皮；耳鸣作为"进入头内"的听觉标记。

**Mouthwashing**：三时间线，转场公式=**画面冻结→音频结巴→溶解+音效**；靠"船舱布局不对劲"标记幻觉。回到现在用硬切。**可迁移**：整套转场公式，几乎可直接照抄。

**寒蝉/海猫（Sound Novel）**：以声音承担演出——BGM 的骤停与切换即情绪剪辑；海猫**红字=真实、蓝字=推测**，是"文字颜色作为认识论标记"的最成熟范例。**可迁移**：两次闪回给句子两种"真值色"，但都像红字一样斩钉截铁——颜色系统本身说谎。

**沙耶之歌 / 素晴日**：整个感知层被替换（沙耶：世界渲染成血肉；素晴日：多视角互相证伪同一事件）。**可迁移**："视角切换=同一事件的另一渲染"，正是玩偶/医生两版闪回的结构。

**Milk inside a bag of milk**：双色极简，红色专用于不安元素；**文本框边框随情绪消失**；选项本身是侵入性思维。**可迁移**：闪回中对话框装饰剥落，只剩裸句。

**Fata Morgana**：靠**隐藏/错标说话人称谓**完成整部作品级别的叙述性诡计。**可迁移**：名牌是诡计的宿主。

**Paranormasight**：诅咒演出打破 UI 层级（存档界面、截图式惊吓），恐怖感来自"系统层被穿透"。**可迁移**：闪回可短暂污染 HUD（污染值表盘走字错乱 2-3 帧），暗示污染的是"界面所信"。

**梦日记**：无解释的符号房间与突发事件（如红色 FACE 事件）证明：**不给因果解释本身就是恐怖**。闪回结束后不做任何说明，效果最好。

---

## 2. 电影语言（今敏重点）

- **今敏（Every Frame a Painting《Editing Space & Time》）**：核心是**用剪辑点本身撒谎**——(a) 同构匹配剪辑：前后镜头共享形状/构图/动作，只换时空；(b) 场中场：戏中戏台词与现实无缝续接（Double Bind 剧集台词"你是谁"侵入 Mima 现实）；(c) **反复苏醒剪辑**：Perfect Blue 中段 Mima 四次醒来，"醒来"这一传统的真实性信号被用作谎言，观众被训练成不再相信任何一层；(d) 声桥：声音先/后于画面切换。→ 本作直接映射：**句子=恒定元素（相当于"醒来"），每次它出现，归属换人**。
- **穆赫兰道**：同一演员/同一台词在梦与现实两层复现、身份互换；关键道具（蓝盒子）作为层间开关。→ 支持"同句复用、归属互换"的合法性。
- **闪灵**：Danny 的双胞胎/血浪插帧属于**flash cut**（数帧级插入），依赖极短时长制造"我看见了吗"的怀疑。学界（IEEE 恐怖游戏阈下启动实验）证实阈下图像可提升负性情绪唤起，但 WCAG 与可读性约束下，本作应采用**"半阈下帧"：单次 100-150ms、不重复闪烁**，让玩家"确定看见了、但没看清"。
- **今敏《妄想代理人》**：重复的袭击场景每次复述细节都不同——**复述即污染**。第二次闪回不应是第一次的镜像，而是"复述失真版"。

---

## 3. 技法清单表

评分 = 对"本作 60% 污染闪回"的适用度（★~★★★★★，含约束兼容性）。

| # | 技法 | 代表作品 | 心理效果 | Godot 实现要点 | 适用度 |
|---|------|----------|----------|----------------|--------|
| 1 | 冻结帧（当下被夺走） | Mouthwashing；今敏静帧 | 时间失窃感、无声预兆 | `await RenderingServer.frame_post_draw` 后 `get_viewport().get_texture().get_image()` → `ImageTexture.create_from_image` 贴到 CanvasLayer 的 TextureRect；或对承载 3D 的 SubViewport 设 `render_target_update_mode = UPDATE_DISABLED` | ★★★★★ |
| 2 | 硬切黑帧+静默（阅读标点） | Signalis 文字卡；Mouthwashing | 给大脑留出读句时间；否定感 | 全屏 ColorRect(近黑 #050505)，`tween_interval(0.15~0.25)`；黑帧上只留关键句 | ★★★★★ |
| 3 | 同构匹配剪辑（换世界不换构图） | 今敏全部作品；Signalis 同构房间 | 两段记忆共用同一形状→无法判真 | 两张闪回图共用同一 Camera transform/构图模板，仅替换主体（玩偶↔医生）与色温；或同一 3D 机位两套隐藏布景各渲一帧 | ★★★★★ |
| 4 | 字幕归属错乱（污染元数据） | 海猫红字；DDLC 名牌损坏；Fata Morgana 隐名 | 语言污染主题直击：话没变，说话的人变了 | 名牌 Label 独立于正文；换名、换引号「」↔『』、换真值色；正文 RichTextLabel 永不参与 glitch | ★★★★★ |
| 5 | 突然静音+房间底噪消失 | DDLC 抽走 BGM；恐怖音频设计通则 | "世界被拔掉电源"，最强无惊吓预兆 | Ambience/Music 总线 `AudioServer.set_bus_volume_db` 经 `tween_method`+`linear_to_db` 在 400ms 内降至 -60dB | ★★★★★ |
| 6 | J-cut 声音先行 | 今敏声桥；电影剪辑通则 | 记忆先于画面入侵 | 语音 Player（`PROCESS_MODE_ALWAYS`）在黑帧期先播"我只是想让你…" | ★★★★★ |
| 7 | L-cut / 反向音尾残留 | 声桥；reverse reverb 惯用法 | 记忆拒绝离场、余毒 | 语音素材离线预烘焙反向混响尾巴；画面回归后继续播 0.5s | ★★★★ |
| 8 | 重复错位 jump cut | Signalis 循环；模拟恐怖 | 记忆是复读机，且每次复读都错位 | 已有"错位重复"素材：第二段闪回同图偏移 4-8px + 时间轴上句子从半句处重播 | ★★★★ |
| 9 | 色差 chromatic aberration | DDLC/通用 glitch 语法 | 神经层面的"信号劣化" | `hint_screen_texture` 三次采样 RGB 分离，uniform 由 `tween_property("shader_parameter/…")` 0→0.006→0 | ★★★★ |
| 10 | VHS / datamosh | 模拟恐怖（Local 58）；Mouthwashing 质感 | 记忆载体老化=记录不可信 | 已有 VHS shader，只在闪回帧上启用并调高 tracking 噪声；回归帧残留 0.2s | ★★★★ |
| 11 | 耳鸣声（12-14kHz 细正弦） | Silent Hill 收音机的主观化变体 | 镜头进入"头内"的听觉签名 | 专用 AudioStreamPlayer，-30dB 起 `tween` 到 -24dB，回归后 1.5s 淡出；绝不做响度峰值 | ★★★★ |
| 12 | 半阈下帧（100-150ms 单次插帧） | 闪灵 flash cut；IEEE 阈下启动实验 | "我看见了什么？"的事后怀疑 | 用于第 3 张"两人格重叠"帧；单次出现、不闪烁、亮度受控 | ★★★☆ |
| 13 | 胶片烧灼/过曝白 | 今敏《千年女优》、film burn 语法 | 记忆过热、被销毁中 | noise mask + 亮度上抬 shader；峰值亮度压在相对亮度 0.8 以下 | ★★★ |
| 14 | 负片/红帧反转 | 闪灵插帧；Signalis 红帧 | 认知极性瞬间翻转 | `1.0 - color`；红帧必须去饱和(R/(R+G+B)<0.8)且不满屏，规避 WCAG 红闪定义 | ★★☆ |
| 15 | 照片/物件锚点变脸 | Signalis 拍立得；OMORI 相册 | 物证也会背叛 | 本次 2s 闪回装不下；留给后续 80% 污染事件 | ★★★（暂缓） |

---

## 4. 节奏结构：让 2-4 秒被"读完"而不是"吓完"

- **三段式微结构：侵入→重写→残留。** 案例平均节拍：Mouthwashing 转场约 1.5-2s；Signalis 蒙太奇单镜 0.2-0.6s、文字卡独占一拍；今敏的欺骗性剪辑总在"观众刚建立预期"的第 2 次重复时下手。→ 本作最优总长 **3.0-3.5s**（2s 装不下两次归属+一次剥离；4s 以上尾部松弛）。
- **黑帧=标点=阅读时间。** 150-250ms 的近黑帧不是特效，是给玩家读句/换气的排版。Signalis 的文字卡证明：黑底白字独占一帧时，读者会不自觉提高注意力。14 字关键句以舒适速度（≈7-9 字/秒）需要累计 ≥1.8s 可读时间——所以**句子必须跨镜头常驻**，而非每镜重打。
- **防 jump scare 三原则**（恐怖设计文献共识：惊吓=突发高对比刺激；恐惧=预期管理）：(a) 入口用"减法"预告——底噪先死 400ms，玩家脊背发凉但没被吓；(b) 全程音量天花板 ≤ 平时 BGM 峰值 -6dB，无任何 riser 爆点，最响的事件是"彻底安静"；(c) 没有任何元素朝镜头运动——冻结与替换，不扑脸。
- **WCAG 2.2 §2.3 落地**：闪光=一对相反的亮度变化（≥10% 相对亮度且暗侧 <0.8）；任意 1 秒内 ≤3 次；饱和红对切另算红闪。→ 设计规则：**全片硬切 ≤6 个、任意滑动 1s 窗口内明暗对 ≤2**；黑帧用 #050505 而非纯黑、闪回图整体压在中低调，把每次变化的幅度也压小（双保险）；不做红/黑满屏交替。

---

## 5. Godot 4 实现要点

**架构**：Autoload `FlashbackDirector`（状态机+一次性标记写入存档），三层 CanvasLayer：
- `layer=90` FreezeFrame：TextureRect（冻结帧）+ 两张闪回图 TextureRect；
- `layer=95` FX：全屏 ColorRect，shader 用 `uniform sampler2D screen_tex : hint_screen_texture, filter_linear;` 采样 `SCREEN_UV` 做色差/VHS/撕裂——**它只影响绘制顺序在它之下的层**；
- `layer=100` TextSafe：关键句 RichTextLabel + 名牌 Label，**永远在 shader 之上，物理上不可能被污染**。

```gdscript
func trigger_flashback() -> void:
    if _fired: return
    _fired = true
    await RenderingServer.frame_post_draw
    var img := get_viewport().get_texture().get_image()
    freeze_rect.texture = ImageTexture.create_from_image(img)
    freeze_layer.visible = true
    get_tree().paused = true            # 闪回各节点 PROCESS_MODE_ALWAYS
    var t := create_tween()
    t.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
    t.tween_callback(_beat_roomtone_out)      # 见 §6 时间表
    t.tween_interval(0.30)
    t.tween_callback(_beat_black.bind(1))
    # ... 逐拍 chain；并行轨用 t.parallel()
    t.tween_property(fx_mat, "shader_parameter/aberration", 0.006, 0.45)
```

- **音频**：总线 `Music / Ambience / Voice / Tinnitus`。Duck 用 `tween_method(func(v): AudioServer.set_bus_volume_db(bus_idx, linear_to_db(v)), 1.0, 0.001, 0.4)`；所有闪回内 AudioStreamPlayer 设 `PROCESS_MODE_ALWAYS` 以免被 pause 吞掉；反向音尾离线烘焙进 wav，运行时零 DSP。
- **两版语音**：同一句录两轨（玩偶：贴麦、气声、升共振峰；医生：距离感、房间混响、匀速），在逗号处交接；重叠段错开 40ms 做"声音版错位重复"，用等功率交叉淡化避免响度尖峰。
- **闪回图**：用同一构图模板出两张 2D 立绘场景图（性价比最高）；若要 3D，同机位两套布景各渲一次存 ViewportTexture。
- **防闪烁自检**：debug 模式给每次全屏切换打时间戳，滚动 1s 窗口断言 ≤3；把 WCAG 从"审美自觉"变成"单元测试"。
- **一次性触发**：污染值跨越 60 的上升沿触发（`prev < 60 and now >= 60`），标记入存档，读档不重放。

---

## 6. 推荐分镜节拍（主案 3.2s；备选 2.0s 精简）

恒定元素：**关键句"我只是想让你留在安全的地方。"从 t=0.45 起常驻至 t=3.2，字形零污染。**

| 时间 | 画面 | 声音 | 文字层 |
|------|------|------|--------|
| -0.4~0 | 正常游戏画面 | 房间底噪+BGM 0.4s 内降至无声（唯一预兆） | — |
| 0~0.30 | **冻结**当前帧，去饱和 30%，HUD 隐藏 | 全静默；耳鸣 -30dB 淡入 | — |
| 0.30~0.45 | 近黑帧 #1 | **J-cut**：玩偶声起"我只是想让你——" | 名牌【玩偶】淡入 |
| 0.45~1.20 | 闪回 A：玩偶场景（构图模板 X，暖色，VHS 轻） | 玩偶声继续；色差 0→0.004 | 句子前半句显示，引号「」 |
| 1.20~1.35 | 近黑帧 #2（阅读标点） | 声音全部凹陷 150ms（连耳鸣也降） | 句子独占黑屏 |
| 1.35~2.10 | 闪回 B：**同构图 X**，玩偶→医生、暖→冷白，图整体错位 6px | 医生声**从半句处重播**"——让你留在安全的地方。"两声交叠 40ms | 名牌闪变【医生】（仅 1 次变化），引号变『』，句子补全 |
| 2.10~2.25 | 近黑帧 #3 | 静默 | 句子全句+**两个名牌错位叠印**（半阈下帧，唯一一次，150ms） |
| 2.25~2.70 | 回到冻结帧（但保留 4px 错位与残留 VHS 噪） | **L-cut**：句尾反向混响尾巴继续 | 名牌消失，句子留在屏上 |
| 2.70~3.20 | 溶解回实时画面，错位归零 | 底噪 -6dB 回升→2s 内复原；耳鸣 1.5s 淡出 | 句子 0.5s 淡出；解锁输入(2.7s) |

闪烁核查：硬切点 0.30/0.45/1.20/1.35/2.10/2.25，任意 1s 窗口最多 2 对明暗变化 ✓；无饱和红 ✓；无音量尖峰 ✓；句子累计可读 ≥2.3s ✓。

**2.0s 精简案**（若必须压到 2s）：砍掉黑帧 #3 与叠印帧，A/B 各压至 0.55s，回归压至 0.35s；归属剥离改为回归后名牌缺失+句子多留 0.8s。代价：失去"无法归属"的最重一拍，**建议争取 3.2s**。

---

## 7. 安全与可读性核查表

- [ ] 任意滑动 1s 内明暗闪光 ≤3（debug 断言）
- [ ] 无饱和红满屏对切；红色元素 R/(R+G+B)<0.8 或面积受控
- [ ] 峰值响度 ≤ 常规 BGM -6dB；无 riser/stinger；最强事件=静默
- [ ] 关键句在独立顶层 CanvasLayer，任何 shader 采样不到它
- [ ] 句子累计可读时长 ≥1.8s；黑帧期间句子为屏幕唯一元素
- [ ] 一次性触发有存档标记；提供"减少闪烁"选项时自动改用纯黑帧+字幕版

## 8. 来源

**Signalis**：[rose-engine 官方光敏/内容警告](https://rose-engine.org/signalis/SignalisWarnings.html)；[References to other media - SIGNALIS Wiki](https://signalis.wiki.gg/wiki/References_to_other_media)；[Dreaming With Signalis - Punished Backlog](https://punishedbacklog.com/signalis-ending-explained-dream/)；[SIGNALIS Endings Explained - Goomba Stomp](https://goombastomp.com/signalis-endings-explained/)；[Category:Memories - SIGNALIS Wiki](https://signalis.wiki.gg/wiki/Category:Memories)
**今敏/电影**：[Satoshi Kon – Editing Space and Time (Brian Yao)](https://byao321.wordpress.com/2015/02/19/satoshi-kon-editing-space-and-time/)；[Satoshi Kon: Techniques and Utilizations of Edits - Filmtaku](https://otakufilms.wordpress.com/2015/02/18/satoshi-kon-techniques-and-utilizations-of-edits/)；[Every Frame a Painting: Satoshi Kon (Vimeo)](https://vimeo.com/101675469)；[Perfect Blue: the Delusion and the Reality](https://thefluffyblackbird.wordpress.com/2018/01/16/perfect-blue-the-delusion-and-the-reality/)；[Mulholland Drive analysis - Rob Ager](http://www.collativelearning.com/MULHOLLAND%20DRIVE%20ANALYSIS.html)；[The Shining subliminal genius - PopOptiq](https://www.popoptiq.com/the-shining-subliminal-genius-not-cryptic-confession/)；[Flash cut - Wikipedia](https://en.wikipedia.org/wiki/Flash_cut)；[When should Editors use a Flash Cut - BeverlyBoy](https://beverlyboy.com/filmmaking/when-should-editors-use-a-flash-cut/)
**游戏案例**：[How DDLC Breaks Itself - Eledris](https://eledris.com/how-doki-doki-literature-club-breaks-itself/)；[DDLC nonhuman horror - Jenn Olive](https://jenniferolive.wordpress.com/2017/11/23/symbols-glitches-and-gaps-first-thoughts-on-the-nonhuman-horror-of-doki-doki-literature-club/)；[Trauma in OMORI's Environmental Design (SAGE)](https://journals.sagepub.com/doi/10.1177/15554120231162982)；[BLACK SPACE - OMORI Wiki](https://omori.fandom.com/wiki/BLACK_SPACE)；[OMORI GDC Narrative Review (PDF)](https://media.gdcvault.com/gdc2024/GNR/Papers/Douglas+Kuras+-+Game+Narrative+Review+-+OMORI.pdf)；[Mouthwashing, Flashbacks, and Agency - Intermittent Mechanism](https://intermittentmechanism.blog/2025/04/26/mouthwashing-flashbacks-and-agency/)；[Mouthwashing review - Rely on Horror](https://www.relyonhorror.com/latest-news/review-mouthwashing/)；[Otherworld - Silent Hill Wiki](https://silenthill.fandom.com/wiki/Otherworld)；[Psychological Horror in Silent Hill - Rue Morgue](https://rue-morgue.com/shattered-memories-psychological-horror-in-the-silent-hill-franchise/)；[Ryukishi07 与 Sound Novel - The Vault Publication](https://thevaultpublication.com/2021/09/23/ramblings-on-ryukishi07-part-1-the-virgin-visual-novel-vs-the-chad-sound-novel/)；[Perspective in Saya no Uta - Fuwanovel](https://fuwanovel.moe/2015/03/perspective-in-saya-no-uta/)；[Subarashiki Hibi review - gareblogs](https://gareblogs.wordpress.com/2018/07/12/review-subarashiki-hibi-furenzoku-sonzai/)；[Milk inside a bag of milk review - Fuwanovel](https://fuwanovel.moe/2024/08/review-milk-inside-a-bag-of-milk-inside-a-bag-of-milk/)；[The House in Fata Morgana - TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VisualNovel/TheHouseInFataMorgana)；[Paranormasight: The Mermaid's Curse Review - DualShockers](https://www.dualshockers.com/paranormasight-the-mermaids-curse-review/)；[Yume Nikki and the Pathology of Psyche-horror](https://elitegamer.ie/2015/08/03/yume-nikki-pathology-psyche-horror/)
**技法/声音/心理**：[Analog Horror - Aesthetics Wiki](https://aesthetics.fandom.com/wiki/Analog_Horror)；[LOCAL58 and the Birth of Analog Horror - Dread Central](https://www.dreadcentral.com/editorials/534205/local58-and-the-birth-of-analog-horror/)；[Subliminal visual primes in a horror game (IEEE)](https://ieeexplore.ieee.org/document/7344646/)；[Subliminal cut - Morphic](https://morphic.com/ai-glossary/Subliminal-Cut)；[Why Silence Scares More Than Sound - Mowjera](https://mowjera.com/blog/horror-game-sound-design-silence)；[Horror sound design secrets - LBBOnline](https://lbbonline.com/news/horror-sound-designs-secrets-how-audio-experts-craft-bone-chilling-scares)；[Reverse Reverb for Creepiness - HomeBrewAudio](https://www.homebrewaudio.com/11982/the-reverse-reverb-effect-for-creepiness/)；[Balancing Act of Tension in Horror Design - Game Developer](https://www.gamedeveloper.com/design/the-balancing-act-of-tension-in-horror-game-design)；[Jump Scares critical analysis - Ties That Bind Gaming](https://tiesthatbindgaming.com/insights/video-games/jump-scares-in-horror-video-games/)
**规范**：[Understanding SC 2.3.2 Three Flashes - W3C](https://www.w3.org/WAI/WCAG22/Understanding/three-flashes.html)；[Understanding SC 2.3.1 - W3C](https://www.w3.org/TR/UNDERSTANDING-WCAG20/seizure-does-not-violate.html)
**Godot 4**：[hint_screen_texture 全指南 - gtstu](https://gtstu.com/godot-4-shader-tutorial-visual-effects/)；[In-engine screenshots - The Shaggy Dev](https://shaggydev.com/2025/02/05/godot-screenshots/)；[Tween — Godot 4.4 官方文档](https://docs.godotengine.org/en/4.4/classes/class_tween.html)；[VHS and CRT monitor effect - Godot Shaders](https://godotshaders.com/shader/vhs-and-crt-monitor-effect/)；[Just Chromatic Aberration - Godot Shaders](https://godotshaders.com/shader/just-chromatic-aberration/)；[Tween audio volume in autoload - Godot Forum](https://forum.godotengine.org/t/use-tween-to-change-audio-volume-in-an-autoload/40951)；[Godot 4 Tween Tutorial - Coding Quests](https://codingquests.io/blog/godot-4-tween-tutorial-juice)
