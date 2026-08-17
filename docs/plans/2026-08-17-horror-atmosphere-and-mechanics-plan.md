# 《语言污染》氛围与玩法修改计划
> 心理恐怖氛围技法 deep research × 本作全系统落地方案 · 2026-08-17
> 配套前期研究:`dialogue.md`(台词规范)、`flashback.md`(闪回技法)、`sentence_rules.md`(造句 UI/规则引擎)、`pickup_anim.md`。本文假定读者未参与前期讨论,所有改动均标注挂载系统。
> 系统代号:**A1** 瀑布流 / **A2** 逐字拾取 / **A3** 造句台 / **A4** 投稿三层响应 / **A5** 发梗(资金+污染) / **B1** 3D 街区与换层 / **B2** NPC 三轮对话 / **B3** key NPC 二问 / **B4** 缝线玩偶 / **B5** faceless watcher / **B6** 确定性恐怖事件表 / **C** 语言规则引擎(规范表+否定算子) / **D1** 60% 闪回 / **D2** VHS shader / **D3** 96s 配乐 / **D4** 历史篡改 / **D5** 菜单污染 / **D6** 退出仪式。

---

## 一、心理恐怖氛围技法拆解(案例 → 可迁移原则)

1. **Silent Hill 2 —— 遮蔽即威胁,威胁做成信号。** 雾起源于 PS2 绘制距离的机能限制,却让"看不见的"永远比可见怪物可怕;室内反向操作:一片漆黑只给手电一小圈光。收音机白噪把威胁转译成主观听觉信号——雷达不指示方位、只指示"存在",玩家在静电里自己吓自己;设计拆解还指出其开场刻意用慢:缓慢的环境音轨、几乎贴地的机位,"什么都不扔给你"地积累压强。人体模型敌人"先观察你的移动、再动手",反转了敌人=冲上来的预设。→ 原则:①能力不足处用遮蔽补;②威胁尽量以"信号"而非"实体"出现;③敌意的最高形态是"它在看你"。(Tech4Gamers;GameDeveloper 设计拆解;SH2 声音研究)
2. **Signalis —— 重复+微变,归属模糊。**"Remember our promise" 红字文字卡反复插帧;角色成对出现、同构房间跨时空复用;正文不标说话人,玩家失去"这句是谁说的"的判定权。剪辑师承 EVA:碎片图像并置而非线性叙事。→ 原则:同一素材第 N 次出现时改一处;删掉归属元数据比改正文更瘆人。(The Artifice;Punished Backlog)
3. **Anatomy(Kitty Horrorshow)—— 宿主敌意化,崩溃即章节。** 磁带监听是伪真实框架;游戏**故意崩溃并要求重启**,每次重启 VHS 降解更深、房子更敌意("每个房间都是嘴");结尾直接问责玩家:"你的职责是听,你却处处撬动。"→ 原则:承载游戏的容器(界面、空间、进程)本身可以背叛玩家;玩家的正常操作可被追认为罪。(Game Studies 学刊;Slate 访谈)
4. **IMSCARED(2012,GameJolt 免费起家)—— 文件系统是延伸的游戏空间。** 在游戏文件夹生成 heart.txt 等文件,必须去读/删才能推进;假崩溃、假报错都是谜题。病毒式传播恰因"它敢碰玩家的电脑"。(Wikipedia)
5. **DDLC —— 糖水层先行,污染打在容器上。** 可爱建立安全感后,损坏的是 sprite、名牌、UI、整段消失的音乐——正文反而完好;捡词写诗小游戏与本作 A2 同构;删除 monika.chr 是正解。(Bloody Disgusting craft 拆解)
6. **OneShot —— 第四面墙外皆谜面,但每招只用一次。** 读取系统用户名、往 Documents 写信、要求挪窗口/看壁纸;关闭游戏=让 Niko 睡着,有叙事后果。(Wikipedia)
7. **还愿 Devotion —— 同一空间跨年代重复。** 同一公寓的多个年代版本,靠陈设差异讲衰败;暖光"照不满角落";恐怖寄生在日常物(手、符纸、药)上;"设计诚实":骗角色不骗玩家操作。(Bulletpoints Monthly;VICE)
8. **Mouthwashing —— 冻结→音频结巴→溶解的入侵公式**;不可靠叙述靠空间布局错位而非台词宣布(详见 flashback.md)。(Intermittent Mechanism)
9. **Paranormasight —— 诅咒=可学习的行为规则。**"背对它离开的人死"——玩家要推理触发条件并**反用**(打火机破坏"黑暗"前提);"重来"由 Storyteller 收编进叙事。→ 与本作规则引擎天然同构:恐怖规则应可学习、可利用、可被规则反制。(RPG Site;Square Enix Blog)
10. **SIMULACRA —— 复刻真实手机 UI 再越界。** 每个 app=一种社会空间(私聊=亲密,邮件=职务,社媒=人设);信息门控用"文件损坏"叙事化;熟悉界面的轻微失常即恐怖。(GameDeveloper Deep Dive)
11. **寒蝉 —— 日常部越可爱,转折越狠;BGM 骤停即演出**;部与部之间重复+微变的轮回结构。(Rely on Horror;RPG Site)
12. **Needy Streamer Overload —— 发帖数值化的先例。** 粉丝数×精神黑暗度双轨(≈本作资金×污染);评论流既是奖励也是压力源,骚扰评论混在夸赞里。(SukeBancho;Rolling Stone India)
13. **The Exit 8 —— 异常审查:环境越一致,最小偏差越像冒犯。** 一条干净、乏味的日本地下通道无限循环,规则只有一句"有异常就回头,没异常就前进";设计分析指出其刻意**不**堆细节——空旷本身是机制,把玩家训练成强迫性审视者,于是"最小的变化都像对你安全感的人身冒犯"。判断错误=退回原点,惩罚温和但令人脊背发凉。(Ludonode Studios;mssv)
14. **Eternal Darkness —— 理智值驱动假系统效果。** 理智条走低不扣血也不锁技能,而是触发"理智效果":假音量条自己下拉、假"是否删除所有存档"确认框(无论选什么都演给你看"已删除")、假蓝屏、战斗中假"请重新连接手柄"——系统层被穿透的开山作;全部由理智值(≈本作污染值)阈值驱动,且每种效果玩家一般只遇到一次。(TechNews IIT)
15. **Hellblade —— 威胁的可信度本身是设计物。**"腐烂到头删档"是谎言,但玩家全程当真。(PCGamesN;ComicBook)
16. **Undertale —— 进程记忆。** Flowey 记得你的 reload 并嘲讽;"But nobody came" 用一行空战斗文本完成背叛。(Undertale Wiki: SAVE)
17. **Buddy Simulator 1984 / KinitoPET —— 亲密数据反用。** 伙伴学习并复用你输入的词、你的名字,亲昵一步步变越界。(Steam/TV Tropes;Steam Guide/NamuWiki)
18. **Stories Untold —— 输入即现实。** 你在文字冒险里打的字,发生在你身处的房间。(Rely on Horror;Adventure Gamers)
19. **Jam/itch 路线经验(Kitty Horrorshow 训言)。** lo-fi 的"糙、坏、错"自带不祥——她的原话:大制作里"哪怕内容可怖,画面之美本身就在安抚玩家",而低保真强迫玩家的脑补去填缝;"地点没有结局,你走进去、游荡、感受、发现,走到你受够了为止";拒绝 jump scare,偏爱 dread scare——"让玩家不得不去做他不想做的事,方向盘在他自己手里"。IMSCARED(个人开发者 Ivan Zanotti 的免费小品靠"敢碰玩家电脑"病毒式传播)、Anatomy(20-30 分钟体量、itch 免费+Patreon)、Exit 8(一条走廊做成现象级)共同验证:**小体量恐怖靠系统与克制取胜,而非资产量;每个大招一生只用一次。**(Slate;itch 页面;Wikipedia)

**共性提炼(五条总纲,后文提案的公理层)**
- **T1 恐怖=预期落差的管理**:先用重复建立模式(Exit 8 的走廊、寒蝉的日常部、Devotion 的公寓),再在模式内做单点偏移;偏移越小、越晚被发现,后劲越大。
- **T2 减法>加法**:抽掉声音(DDLC 静默读诗)、抽掉视野(SH2 雾)、抽掉反馈可信度(Hellblade)比添加怪物有效;玩家失去的每一样"理所当然",都变成悬在头顶的东西。
- **T3 背叛要打在容器上,不打在正文上**:DDLC 糟蹋名牌与 sprite、Signalis 抹掉说话人、Anatomy 糟蹋"游戏进程"本身——被读的那句话永远完好,读它的环境全面失守。这与本作 flashback.md 的硬约束完全一致。
- **T4 玩家自己的行为是最贵的恐怖素材**:你打的字(Stories Untold)、你的用户名(OneShot)、你教它的话(Buddy Simulator)、你的 reload(Undertale)、你发的帖(NSO)——素材成本为零,情感成本最高。本作的投稿/拾取/规则系统天然坐在金矿上。
- **T5 恐怖规则必须可学习**:Paranormasight 的诅咒有明确触发条件所以才能"反用";Exit 8 的二元规则 10 秒内可教会。不可学习的随机惊吓只消耗信任——本作"确定性事件表"路线是对的,所有新增恐怖必须保持确定性。

---

## 二、机制型恐怖清单("恐怖来自系统而非贴图")

| # | 机制 | 出处(1-2) | 本作挂点 |
|---|---|---|---|
| M1 | UI 敌意化:菜单/按钮说谎 | Pony Island;DDLC | D5 菜单污染(已有,扩展) |
| M2 | 进程/存档被注视:记得 reload、退出方式 | Undertale;Eternal Darkness 假删档 | D6 退出仪式 |
| M3 | 玩家生成内容反噬:你写的被引用、变味、收编 | Buddy Simulator 1984;NSO 评论流 | A1/A4/A5(本作最大金矿) |
| M4 | NPC 复读玩家的话(换主语/换语气) | Buddy Simulator;Stories Untold | B2/B3 |
| M5 | 伪系统弹窗/假崩溃(一次性) | Eternal Darkness;IMSCARED;Anatomy 重启 | D5 一次性事件 |
| M6 | 可信度衰减:系统反馈不再可信 | Hellblade 删档谎言;Pony Island | A4 三层响应/C 规范表 UI |
| M7 | 文件系统入侵(读/写玩家侧文件) | IMSCARED heart.txt;OneShot Documents 信 | P2 彩蛋(需平台合规) |
| M8 | 异常审查:找不同=表态/签约 | The Exit 8;Devotion 跨年代公寓 | B1 换层/B6 事件表 |
| M9 | 行为规则诅咒(不许回头类) | Paranormasight | B4 玩偶/B5 watcher |
| M10 | 观察者效应反转:你不动世界动;你看它它看你 | SH2 人体模型;IMSCARED | D2 VHS/B5 |
| M11 | 静默作为威胁:抽掉声音而非加声音 | 恐怖声设计共识;DDLC 音乐整段消失 | D3 配乐/B1 环境声 |
| M12 | 重复+微变 | Signalis;Exit 8;寒蝉轮回 | A1 帖子/B1 街区 |
| M13 | 亲密数据反用(名字/习惯/历史) | OneShot 用户名;KinitoPET | E 命名权主题/D4 历史 |

---

## 三、逐系统提案全表(每条挂机制编号)

**A1 瀑布流**:①投稿后 T+1 日起"网友"回帖引用玩家句子:先正确夸赞→隔日错引一字→最终以医生语气当"病历引文"收编(M3+M12,三段文案表驱动);②同一条都市传说帖隔数日重发,配图相同但一处细节变化,评论区有人问"这帖是不是发过"(M12/M8);③某帖浏览数=玩家打开手机的真实次数;深夜时段"在线:2"(M2/M10);④watcher 事件后出现一张"路人随手拍"帖,构图恰是玩家刚才站位(M9/M10,挂 B5)。
**A2 逐字拾取**:①被拾取的字在原帖留下空位,评论区抱怨"怎么缺字"——世界注意到提取行为(M3);②高污染时个别发光字"不愿被拾取":第一次点击飞向评论区,需二次点击(M1,复用 pickup_anim 飞行轨迹);③笔记本里的字夜间自行换位一次(M12,日结时结算)。
**A3 造句台**:①念字低语在污染≥60% 后由玩偶声换医生声,同字两读(声部争夺可听化,挂 dialogue.md 三声部);②词库出现一个玩家从未拾取的灰色字块(无来源、点击无 TTS),是"世界自写规则"的前奏(M3/M13);③高污染时撤销后词块回到**错误的 ghost 槽位**,背叛 U4 空间记忆规则(M1/M8,参数级改动)。
**A4 投稿三层响应**:①"世界误读"升级为"复读":把玩家句子原样贴回瀑布流、署名玩家账号、但玩家没发过(M3/M4);②少量投稿显示"无响应",实际 2-3 游戏日后延迟生效——玩家的因果归因被破坏(M6);③三层响应的判定说明文案逐渐从确定句变为概率句("大概会生效")(M6)。
**A5 发梗**:发出去的梗被"网友"二创后回流瀑布流,二创版携带更高污染且不可拾取——玩家自己的话变成都市传说原料,资金收益同时上升:**赚钱=喂养污染的闭环可视化**(M3,NSO 双轨先例)。
**B1 街区**:①雾密度=f(污染)且玩家凝视同一方向>4s 时缓慢增浓(SH2 遮蔽+M10);②环境声随污染做减法:25% 抽街道底噪层,60% 抽 NPC 人声层,80% 只剩双脚步——然后玩偶脚步多出一步(M11+Milk 数步法);③换层楼梯间改造成「规则走廊」——见 P1-A(M8)。
**B2 NPC 对话**:①第三轮对话按查表引用玩家已生效规则并换主语:「门可以打开」→「你也可以被打开」(M4,从 C 规范表取句,模板插槽);②打字显影中途出现 {del} 划掉重打(复用 D4 标记语法到实时对话,M1);③污染乱码优先侵蚀**人称代词**(呼应命名权主题 E)。
**B3 key NPC 二问**:第二问反转为 NPC 问玩家,答案选项只能从笔记本已拾取字里出——玩家被迫用被污染的词汇回答(M4/M13,"语言的界限即世界的界限"落地为交互)。
**B4 玩偶**:①跟随距离=f(污染) 三档:亲密/标准/远;80% 后偶尔"先到"目的地背对等你(M9/M10,SH2 人体模型式);②引导气泡词汇逐步混入医生语域词(挂 dialogue.md 语域表,E 主题推进);③一次性事件:玩家连续回头看它 3 次,第 4 次它消失,气泡从屏幕"身后"方位弹出:「别回头了。」(M9,Paranormasight 反用,一生一次)。
**B5 faceless watcher**:事件本体不变,增加跨世界回声:见 A1-④(M10 闭环:现实层被看→手机层看到自己被看)。
**B6 确定性事件表**:事件表与规则引擎联动:拼出「灯亮」后灯灭事件从表中移除(玩家真实获得安全感),但 EXIT 缺字母事件升级——缺的字母恰是玩家最近拾取的字(安全感回收,M8/M12;确定性保持,不引入随机)。
**C 规则引擎**:①「世界自写规则」——见 P1-B(M3 终极形态);②被误读过的词,后续在规范表 UI 中成功率显示为「??%」(M6);③否定算子获得新用途:可废除世界写的规则(教学:用系统对抗系统,为第三层封门与第四层日结边界做玩法铺垫)。
**D1 闪回**:第三层起,若玩家重看历史里的闪回记录,八拍素材中第 5 帧被"错误的记忆"替换——同构图、归属名牌互换(严格遵守 flashback.md"污染元数据不污染正文"原则,M12/M13)。
**D2 VHS**:tracking 错位只在玩家静止≥3s 时发生;移动即恢复——"你不动,世界才动"(M10,参数联动 idle timer)。
**D3 配乐**:五音动机随污染逐层缺音:25% 缺一音,60% 缺二音,80% 只剩二音+底噪;日结界面播放完整五音的**倒放**(M11/M12,确定性,零新增素材)。
**D4 历史篡改**:玩家重读对话历史时,自己当时的选择被 {ins} 改成没选过的那项——只改玩家侧,NPC 侧完好(M13/M6,Mouthwashing 式不可靠记忆)。
**D5 菜单污染**:新增一次性伪弹窗:「检测到未知输入法。」按钮:「好的」/「好的」(M5/M1,全游戏仅一次,不阻断操作,WCAG 可读)。
**D6 退出仪式**:①第二次启动起,标题画面记得上次退出方式;②若上次强杀进程,本次启动瀑布流首帖:「昨晚有人没说再见。」(M2,Undertale/OneShot 式,一次性文案)。

---

## 四、修改计划(P0 → P1 → P2)

### P0 氛围地基(纯参数/文案/音画,先做,全部小工作量)
| 编号 | 改动(挂载) | 目标体验 | 素材需求 | 验收标准 | 量 | 依据 |
|---|---|---|---|---|---|---|
| P0-1 | 污染驱动声音减法(D3+B1-②) | 越危险越安静,静默成为威胁读数 | 无新音频,现有 96s 分轨开关表 | 25/60/80% 各抽指定轨;80% 场景实测仅脚步+底噪;玩偶多余脚步在 80% 后每 90-120s 至多 1 次 | 小 | M11;SH2 声研究;DDLC 音乐消失 |
| P0-2 | 瀑布流重发帖+细节变异(A1-②) | "我是不是见过这帖"的既视感 | 3 组帖子的 A/B 版文案与配图(各 1 处差异)+2 条评论 | 同帖间隔≥2 游戏日重发;差异仅 1 处;无任何系统提示,只有评论区暗示 | 小 | M12;Exit 8;Devotion |
| P0-3 | 评论区错引玩家句(A1-①) | 自己的话在别人嘴里变味 | 引用模板文案 3 段式×5 套(夸赞/错一字/病历化) | 投稿后 T+1/T+3/T+5 日各出现一阶;错引仅 1 字;病历阶必须用 dialogue.md 临床语域 | 小 | M3;Buddy Simulator;NSO |
| P0-4 | NPC 第三轮引用规则句(B2-①) | 世界在用你的话说你 | 换主语模板 6 条(主语槽×规范表查询) | 仅当规范表非空触发;引用句与原句差异仅主语;每 NPC 至多一次 | 小 | M4;Buddy Simulator;Stories Untold |
| P0-5 | 玩偶距离参数+"先到"(B4-①) | 伙伴逐渐陌生 | 无新素材,3 档距离参数+1 个预置点位表 | 距离随污染档切换平滑;"先到"仅 80% 后、每层至多 1 次、背对玩家 | 小 | M9/M10;SH2 人体模型 |
| P0-6 | VHS 静止触发(D2) | 你不动,世界动 | 无 | idle≥3s 渐入 tracking 错位,移动 0.5s 内恢复;闪烁频率≤3 次/s(光敏合规) | 小 | M10;Anatomy VHS 降解 |
| P0-7 | 一次性伪弹窗+退出记忆(D5+D6) | 系统层被穿透的一瞬 | 弹窗文案 1 条、首帖文案 1 条 | 全周目各仅 1 次;弹窗不阻断输入;强杀检测经由启动标志位;正常退出不触发 | 小 | M5/M2;Eternal Darkness;Undertale |
| P0-8 | 造句台声部切换+撤销错位(A3-①③) | 最安全的界面开始不可靠 | 医生声线念字音频(复用现有 TTS 管线换参),无新 UI | 污染≥60% 后念字换声且同字两读可辨;撤销回错槽仅在污染≥60% 触发、每题至多 1 次、不影响成句判定 | 小 | M1/T3;DDLC 容器污染;Buddy Simulator 亲密声反转 |

P0 的心理链条:P0-1/P0-6 先把"世界会退让"的体感建立起来(减法+观察者效应),P0-2/P0-3 在手机层建立"重复+微变"的模式认知,P0-4/P0-5/P0-8 让三个最亲密的系统(对话、玩偶、造句台)各自失守一小步,P0-7 收口在系统层。全程零 jump scare、零随机、零新增大型资产,一名程序+一名文案约一至两周可全部落地。

### P1 机制新招(系统级新交互,二选二皆做则先 A 后 B)
**P1-A 「规则走廊」——换层即签约(B1-③ × C × B6,量:中)**
- 目标体验:Exit 8 式异常审查嫁接到规则引擎:楼梯间墙上挂着玩家全部已生效规则的标语牌;某次换层,其中一张被改了一个字(如「门可以打开」→「门可以打开你」)。走过=默认接受,**该改动真实写回规范表**;转身退回=拒绝,但 B6 事件表当日追加一次补偿事件(灯灭)。
- 具体改动:楼梯间场景加标语牌预制体(文本渲染自规范表);换层流程插入审查节点;规范表写回接口复用投稿管线;拒绝分支挂事件表。
- 素材需求:标语牌 1 个预制体+污损材质 1 套;被改字规则生成表(每条规则预写 1 个"恶意变体",人工审校,禁止程序随机换字)。
- 验收标准:①标语牌内容与规范表实时一致;②改动后规则在现实层立即可验证(门的行为真变);③拒绝路径补偿事件当日必发;④每周目审查节点≤3 次;⑤变体句全部过 dialogue.md 负面清单。
- 依据:M8(Exit 8"最小偏差=冒犯");Baba Is You 规则即数据(sentence_rules.md);M6。
**P1-B 「世界自写规则」——笔记本长出别人的字(C-① × A2/A3,量:中)**
- 目标体验:第三层封门任务开始后,每个游戏日笔记本出现 1 条灰色字迹的新规则(玩家没拼过,如「名字可以被借走」),状态=已生效;废除需消耗否定算子+拾取对应汉字——玩家第一次主动"用系统打系统"。
- 具体改动:规范表加 author 字段(player/world);world 规则由日结流程按剧本表注入;笔记本 UI 灰字渲染+废除交互(拖否定算子到该行);A3 词库同步出现对应灰色字块(提案 A3-②)。
- 素材需求:world 规则剧本表 4-6 条(每条附现实层效果与废除所需字);灰字样式;废除音效 1 个(现有素材反转可用)。
- 验收标准:①world 规则必须有可观察的现实层效果;②废除后效果立即消失且该行保留 {del} 划痕(D4 语法);③不废除不阻断主线,但第四层日结边界结算时未废除数影响隐藏结局判词;④每日至多 1 条,总量≤6。
- 依据:M3 终极形态;OneShot 往你家写信;IMSCARED heart.txt;Anatomy"宿主问责玩家"。

### P2 高级/彩蛋(低频大招,每个一生一次)
| 编号 | 改动(挂载) | 目标体验 | 素材/验收要点 | 量 | 依据 |
|---|---|---|---|---|---|
| P2-1 | watcher 照片帖(B5×A1-④) | 被看的证据出现在手机里 | 事件时截屏玩家站位渲染图或 4 张预制图;事件后 1 游戏日内出帖,仅 1 次;评论区 3 条 | 中 | M10;SIMULACRA 熟悉 UI 越界 |
| P2-2 | 隐藏结局边界强化(C×D3×D4) | 终局前世界开始退潮 | 日结边界前 96s 配乐倒放;历史记录逐条自我 {del} 但保持可读(WCAG);零新素材 | 中 | M11/M12;Signalis 蒙太奇 |
| P2-3 | 「笔记本.txt」导出彩蛋(A2×E) | 游戏把你的语言还给你 | 通关后**游戏内按钮**导出玩家全部拼句到用户目录,末行多出一句非玩家写的话;明确按钮触发,不偷写桌面(平台合规) | 小 | M7/M13;IMSCARED;OneShot Documents |
| P2-4 | 玩偶「别回头」事件(B4-③) | 跟随者规则反转 | 回头计数 3 次阈值;第 4 次消失+身后方位气泡;全周目 1 次;之后玩偶恢复正常且不再解释 | 小 | M9;Paranormasight;梦日记"不解释即恐怖" |

**执行顺序与总原则**:P0 全部→P1-A→P1-B→P2 任选。三条铁律:①每个第四面墙/伪系统大招全周目只用一次(OneShot/ED 教训:重复即失效);②一切"背叛"只碰元数据与容器,永不碰正在被读的正文(flashback.md 硬约束,对应总纲 T3);③零随机——所有恐怖事件确定性触发,可复现、可验收(Exit 8/B6 既有路线,对应 T5)。

**反模式清单(禁止事项,评审时逐条对照)**
1. 禁止 jump scare 与突发巨响:本作全部恐怖预算花在 dread 上(Kitty Horrorshow 训言;SH2 慢开场)。
2. 禁止欺骗玩家的**操作**:假弹窗不得吞输入,伪崩溃不得真丢进度——骗感知不骗操作,即 Devotion 的"设计诚实";Hellblade 的删档谎言之所以成立,正因它从未真删。
3. 禁止程序随机改字:所有"被改的句子/错引"必须出自人工审校的变体表,并通过 dialogue.md 去 AI 味负面清单——错一个字是恐怖,错得没道理是 bug。
4. 禁止解释:任何恐怖事件发生后,系统、NPC、玩偶都不得点破(梦日记原则;dialogue.md 铁律 1"污染禁止被角色宣布")。
5. 禁止连发:同类恐怖事件之间至少间隔一个完整的"安全循环"(一次正常投稿或一次日结),模式重建期就是下一次偏移的蓄力期(T1)。
6. 光敏与可读性红线不动:闪烁≤3 次/s、关键句永远可读、{del}{ins} 保持 WCAG 对比度——已有约束覆盖全部新增项。

**测玩验证指标(P0 完成后跑 5 人小样)**
- 错引察觉率:P0-3 的"一字之差"应有 40-70% 玩家在第二阶自行发现(全员秒发现=太糙,无人发现=太隐);
- 静默压强:80% 污染场景中,玩家平均移动速度应显著下降、回头频次上升(录屏统计),证明减法在生效;
- 归因追问:测玩后访谈"你觉得哪些是 bug?"——理想答案是把 P0-6/P0-8 列为"不确定是不是故意的"(可信度衰减起效的标志,M6);
- 规则走廊(P1-A)表态率:接受/拒绝应接近对半,且 80% 以上玩家能复述"走过去=同意"的规则(T5 可学习性验收)。

---

## 五、来源链接
**SH2**:[Tech4Gamers 雾](https://tech4gamers.com/how-silent-hill-2-uses-subtle-horror-with-its-fog/) · [GameDeveloper 设计拆解](https://www.gamedeveloper.com/design/designing-horror-in-silent-hill-2) · [SH2 声音研究(ResearchGate)](https://www.researchgate.net/publication/398025419_The_Sound_of_Silent_Hill_2_An_Exploration_of_the_2001_Original_and_2024_remake) · [Gaming the Mind](https://gamingthemind.org/2025/04/22/trapped-in-the-fog-restraint-and-mental-health-in-silent-hill-2/)
**Signalis**:[The Artifice](https://the-artifice.com/signalis/) · [Punished Backlog](https://punishedbacklog.com/signalis-ending-explained-dream/) · [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/Signalis)
**Anatomy/Kitty Horrorshow**:[Game Studies 学刊](https://gamestudies.org/2403/articles/leblanc) · [Slate 访谈](https://slate.com/culture/2016/06/the-indie-horror-video-games-of-kitty-horrorshow.html) · [itch 页面](https://kittyhorrorshow.itch.io/anatomy) · [A House of Teeth](https://medium.com/@videodante/a-house-of-teeth-on-anatomy-b5139ed2f6a0)
**IMSCARED**:[Wikipedia](https://en.wikipedia.org/wiki/Imscared) · [Files Wiki](https://imscared.fandom.com/wiki/Files)
**DDLC**:[Bloody Disgusting craft 拆解](https://bloody-disgusting.com/editorials/3559587/craft-fourth-wall-breaking-anxiety-doki-doki-literature-club/) · [Simply Put Psych](https://simplyputpsych.co.uk/gaming-psych/inside-the-minds-of-doki-doki-literature-club)
**OneShot**:[Wikipedia](https://en.wikipedia.org/wiki/OneShot) · [机制分析](https://melamonica98.wixsite.com/climbingthebookcase/post/fourth-wall-breaking-and-choices-analysis-of-game-mechanics-in-oneshot)
**Devotion**:[Bulletpoints Monthly](https://bulletpointsmonthly.com/2019/10/08/devotion-delusion-and-design-honesty) · [VICE](https://www.vice.com/en/article/devotion-review-horror-red-candle-games/) · [BJoCS 论文](https://bjocs.site/index.php/bjocs/article/view/195)
**Mouthwashing**:[Intermittent Mechanism](https://intermittentmechanism.blog/2025/04/26/mouthwashing-flashbacks-and-agency/) · [Wikipedia](https://en.wikipedia.org/wiki/Mouthwashing_(video_game))
**Paranormasight**:[RPG Site 评测](https://www.rpgsite.net/review/13874-paranormasight-the-seven-mysteries-of-honjo-review) · [Square Enix Blog](https://www.square-enix-games.com/en_GB/news/paranormasight-seven-mysteries-honjo-revisited-pt2) · [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VisualNovel/ParanormasightTheSevenMysteriesOfHonjo)
**SIMULACRA**:[GameDeveloper Deep Dive](https://www.gamedeveloper.com/design/deep-dive-turning-phone-ux-into-game-mechanics-in-horror-game-i-simulacra-2-i-)
**寒蝉**:[Rely on Horror](https://www.relyonhorror.com/reviews/review-higurashi-when-they-cry-chapter-1-onikakushi/) · [RPG Site](https://www.rpgsite.net/review/9927-higurashi-when-they-cry-review)
**NSO**:[SukeBancho](https://sukebancho.medium.com/needy-streamer-overload-internet-overdose-171f29f0bc26) · [Rolling Stone India](https://rollingstoneindia.com/needy-streamer-overload-gaming-anime-psychological-horror-review/) · [Gameplay Wiki](https://needy-streamer-overload.fandom.com/wiki/Gameplay)
**Exit 8**:[Ludonode 分析](https://ludonodestudios.medium.com/the-art-of-the-loop-what-the-exit-8-teaches-us-about-liminal-horror-and-anomaly-design-a52b5c4f1385) · [mssv](https://mssv.net/2023/12/19/the-exit-8/)
**Eternal Darkness**:[TechNews IIT](https://www.technewsiit.com/sanity-effects-eternal-darkness-sanitys-requiem/) · [Sanity Effects Wiki](https://eternaldarkness.fandom.com/wiki/Sanity_Effects) · [Everything is Scary](https://www.everythingisscary.com/play/2015/6/4/is-this-real-the-4th-wall-and-eternal-darkness-sanitys-requiem)
**Hellblade**:[PCGamesN](https://www.pcgamesn.com/hellblade-senuas-sacrifice/hellblade-permadeath-fake) · [ComicBook](https://comicbook.com/gaming/news/hellblade-senuas-sacrifice-permadeath-is-a-lie/)
**Undertale**:[SAVE Wiki](https://undertale.fandom.com/wiki/SAVE)
**Buddy Simulator 1984**:[Steam](https://store.steampowered.com/app/1269950/Buddy_Simulator_1984/) · [TV Tropes](https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/BuddySimulator1984) · [itch](https://notasailorstudios.itch.io/buddy-simulator-1984)
**KinitoPET**:[Steam Guide](https://steamcommunity.com/sharedfiles/filedetails/?id=3234942105) · [NamuWiki](https://en.namu.wiki/w/KinitoPET)
**Stories Untold**:[Rely on Horror](https://www.relyonhorror.com/reviews/review-stories-untold/) · [Adventure Gamers](https://adventuregamers.com/games/stories-untold) · [itch(The House Abandon)](https://jonnocode.itch.io/the-house-abandon)
**Pony Island/Inscryption**:[Wikipedia](https://en.wikipedia.org/wiki/Pony_Island) · [Problem Machine](https://problemmachine.wordpress.com/tag/pony-island/) · [PC Gamer](https://www.pcgamer.com/inscryption-announced-a-deckbuilding-horror-roguelike-from-the-pony-island-dev/)
**声音/静默设计**:[Wayline](https://www.wayline.io/blog/silence-is-scary-sound-design-horror-games) · [Game Audio Medium](https://medium.com/@GameAudio/the-art-of-fear-the-psychology-of-sound-design-in-horror-games-d85b9854c3b0) · [Mowjera](https://mowjera.com/blog/horror-game-sound-design-silence)
**Jam/itch 恐怖**:[Dread Central LD53 十佳](https://www.dreadcentral.com/editorials/492704/delivery-service-10-horror-highlights-from-ludum-dare-53-game-jam/) · [itch Horror×Ludum Dare 标签](https://itch.io/games/tag-horror/tag-ludum-dare)
**第四面墙综述**:[WhatCulture](https://whatculture.com/gaming/10-video-game-fourth-wall-breaks-no-one-saw-coming?page=9) · [Fandom 综述](https://www.fandom.com/articles/when-horror-games-break-the-fourth-wall)
