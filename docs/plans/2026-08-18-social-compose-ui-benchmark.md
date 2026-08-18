# 社交软件发帖界面 对标 × 本作发布界面落地方案
> 八平台 compose/publish 拆解 · 四维度对比 · Godot 4 可执行规范 · 2026-08-18
> 配套:`atmosphere_ui_camera_benchmark.md`(视觉层)、`sentence_rules.md`(规则语义)、`pickup_feedback_gap.md`(拾字反馈)。本文只谈**"把字变成投稿"这一屏**。

---

## 零、基线:本作现状(读代码得出,作为改造锚点)

| 项 | 事实 | 位置 |
|---|---|---|
| 视口 | `1600×900`,`canvas_items` | `project.godot:21-22` |
| **结构性问题** | **造句和发布被拆在两个屏**:造句台 `_render_sentence_composer()` 挂在**笔记本**里,发布页 `_render_social_publish_page()` 只有一个"整梗"投放格 | `:6520`、`:4510` |
| 造句台 | `ComposerAnswerPanel`(ComposerDropArea)→ `ComposerAnswerFlow`(HFlowContainer,h/v sep 6,min-h 46)→ `ComposerAnswerTile%d`(44×42)+ `ComposerAnswerUnderline`(2px);下方 `ComposerSubmitRow` **只有一个 preview Label,没有按钮** | `:6528-6570` |
| 词库 | `NotebookCharFlow` → `NotebookCharTile%d`(44×40);**已入句的字不 reflow**,原位变 `disabled` + `modulate.a=0.55` 幽灵(多邻国 U4 规则) | `:6578-6607` |
| 投稿按钮 | `NotebookCraftButton`「投稿这句话」56px,在 `NotebookCraftActionBar`(`fixed_action_bar` meta);`disabled = units.is_empty() or not can_spend_action()` | `:4797-4803` |
| 发布页 | `SocialPublishHeader`(44px,"发布新信号" 22px + "DAY %02d" 12px)/ `SocialPublishBlank`(DropButton 64px,收 `kind=="meme"`)/ `SocialPublishOutcomePanel`(资金·污染 22px)/ `SocialPublishButton`「确认发布」56px | `:4510-4604` |
| 拖放协议 | `DraggableButton.set_drag_payload(kind,id,label)` → `{kind,id,label}`;`DropButton.configure_drop_target(kind,id)` 严格等值匹配;`ComposerAnswerTile` 收 `composer_unit`/`composer_reorder` 并 emit `unit_dropped_before(data, index)`(插到本瓦片**之前**);`ComposerDropArea` 收同两种 kind 并**追加到句尾** | `scripts/ui/*.gd` |
| 提交语义 | `submit_free_sentence()`:`money_gain = 1 + floor(n/2) + (2 if rule)`;`pollution_gain = clamp(2 + n + (2 if rule), 2, 12)`;tier ∈ `rule`/`misread`/`noise`;失败 reason ∈ `empty`/`no-actions`;成功后 `free_sentence_units.clear()` | `meme_game_state.gd:1354` |
| 拖拽预览 | `set_drag_preview()` 只造一个 16px `Label`,颜色硬编码 `365B2D` | `draggable_button.gd:20` |
| 测试 | `tests/` 74 个文件,`extends SceneTree` + `_failures: Array[String]` + `quit(0/1)` | `tests/test_drag_controls.gd` |

**一句话诊断**:本作已有完整的 drag-drop 底座和句子状态机,缺的是**把造句台搬进发布页**,并补齐真实社交软件的六件套——计数器、占位符、按钮四态、草稿、可见范围、发布中/已发布反馈。

---

## 一、八平台 compose 拆解

### 1. X / Twitter
**版面(截图描述)**:模态浮层,左上「×」关闭 → 右上「Drafts」;正文区顶格,左侧 40px 圆形头像,右侧多行 placeholder「What's happening?」;正文下方一行蓝字**回复权限**按钮(地球图标 + 文案);底部一条水平媒体栏(图片/GIF/投票/表情/日程/位置),**最右端**是环形计数器 + 分隔竖线 + 「+」加推 + 蓝色胶囊「Post」。
**事实**:默认 280 字符;Premium 分三次抬到 4,000(2023-02)、10,000(2023-04)、25,000(2023-06)。2017-03 起媒体附件与回复中的 @ 不计入。
**回复权限**四档:`Everyone` / `Accounts you follow` / `Only accounts you mention` / `Only verified accounts`,控件在**撰写框内地球图标旁**,**发布后仍可改**(More →「Change who can reply」);限制只挡回复,不挡点赞/转推/投票;被邀请者会在帖子下方看到一行说明。
**编辑窗口**:Premium 专属,**1 小时内最多 5 次**;编辑后带「edited」图标与标签,点进去可看**历史版本**,互动数跨版本累计;线程、回复、推广帖、投票、置顶、第三方发帖、X Pro、订阅者专属帖**不可编辑**;必须**用原发布设备**编辑;可重排与标注媒体。

### 2. Instagram
**版面**:**多步向导**,四屏——① 相册无限流选图(顶部预览框、右上「Next」)② 滤镜/编辑(底部滤镜带,右上「Next」)③ 文案页(左上缩略图 + 右侧多行文案框,下方一列可点行:标记用户 / 添加位置 / 同步到其他平台)④ 右上「Share」。
**事实**:文案上限 2,200 字符;主 CTA 恒在**右上角**,后退用左上「<」;拆解者的结论是"相当无摩擦、设计良好",靠的是**极其普遍的模式**而非创新。
**启示**:向导式适合线性流程,**不适合本作**——核心是反复试错地重排字词,分步会推高试错成本。只借它的**"元数据折叠成一列可点行"**。

### 3. 微博
**版面**:单页大输入框(placeholder「有什么新鲜事想分享给大家?」),下方一排图标行:图片 / 视频 / 话题`#` / `@` / 表情 / 定位 / 更多;左下角是**可见范围**下拉(公开 / 好友圈 / 仅自己可见 / 指定分组),右下角橙色「发送」。
**事实**:2016-11 对全体用户取消 140 字限制,**上限 2,000 字**;超 140 字在信息流里**只显示 140 字 + 「展开全文」折叠**;评论仍限 140 字。
**关键设计**:`#话题#` 与 `@` 是**内联富文本**(输入即高亮成实体),即"把结构塞进自由文本",与 Reddit"结构拆成独立字段"正相反。

### 4. 小红书
**版面**:**封面优先**——第一屏就是九宫格/视频封面选择,封面占据视觉顶部约 1/3;第二屏自上而下:封面缩略条 → **标题输入行(单行,带字数)** → **正文多行框(与标题视觉分离)** → 一行标签推荐胶囊(点即插入 `#tag`)→ 地点行 → 可见范围行;底部固定双按钮「存草稿」+「发布笔记」。
**事实**:正文上限 **1,000 个汉字**(超出需拆帖/转图)。标题字数各渠道说法不一,**未取到权威出处,不作为设计依据**。
**关键设计**:**标签推荐胶囊**——系统按正文实时推荐一排可点标签,点即插入。这是本作"世界推荐你说什么"的最佳原型。

### 5. Reddit
**版面**:两栏。左栏自上而下:社区选择器(带图标下拉)→ **Post 类型 Tab**(Text / Images & Video / Link / Poll)→ **标题单行框(右侧计数 x/300)** → 正文富文本框 → Flair 选择 → 底部行「Save Draft」+ 蓝色「Post」。右栏常驻 **Rules 侧栏**(社区规则逐条列出) + Posting Guidelines。
**事实**:标题 **300 字符,发布后永久不可编辑**;自帖正文 **40,000 字符**(Premium 自 2025-11 起 80,000);评论 10,000;用户名 20;简介 200。
**关键设计**:**Rules 侧栏与撰写区并置**——"你正在写"与"你必须遵守什么"同屏。本作最该抄的一条:**现行世界规则必须与造句台同屏**。

### 6. Threads / Bluesky / Mastodon(三者差异是计数与可见性的教科书)

| | 上限 | 计数方式 | 内容警告 | 可见性 |
|---|---|---|---|---|
| **Threads** | 正文 500 / 文本附件 10,000 / 回复 500 / 简介 150 / 昵称 30 / 话题 100 | 含空格、标点、emoji | 无独立 CW | 依附 Instagram 账号设置 |
| **Bluesky** | **300 graphemes / 3,000 bytes** | AT Protocol schema 里写死 `maxGraphemes: 300`;👨‍👩‍👧‍👦 = 1;CJK = 1 | 有(labels) | Threadgate 控回复 |
| **Mastodon** | 默认 **500**(实例可改) | **链接一律算 23 字符**;@ 只算用户名部分 | **CW 一等公民** | 四档 |

**Mastodon CW**:开启后正文**默认折叠,只显示 CW 文本**,官方类比"邮件主题行 / read more";加 CW 会**自动把附件标为敏感**。
**Mastodon 可见性**(「Visibility and interactions」对话框):`Public` / `Quiet public`(不进实时流与探索)/ `Followers` / `Private mention`(只有被 @ 的人可见)。
**Mastodon 附件**:图片 ≤16MB 最多 4;GIF/MP4 ≤16MB 限 1;视频 ≤99MB 限 1;音频 ≤99MB 限 1;支持描述与焦点。投票最多 4 项、每项 25 字、有效期 5 分钟–7 天。
**grapheme 这一条对本作至关重要**:Bluesky 的 grapheme 语义正是"人眼看到的一个字",直接对应本作的一枚字词瓦片。

### 7. 5ch / 2ch(极简 BBS)
**版面**:等宽字体、无圆角、无图标。三个字段自上而下:**名前**(单行,可空)/ **メール**(单行,可空)/ **本文**(多行 textarea),下面一个方形「書き込む」按钮。**没有**计数器、草稿、可见范围、附件、编辑。
**事实**:名前留空即"名無しさん";`名前#パス` 生成 trip;**メール欄填 `sage`** 可让帖子不上浮——**一个纯文本字段承担了"可见范围"的语义**;发布后系统自动附加 **ID(按日轮换,基于 IP)、レス番号、日时**;有連投規制。
**启示**:5ch 证明**发帖框可以只有三格**,且**"元数据由系统单方面追加、发帖者无权干预"本身就是压迫感来源**——ID 是被安上的,不是选的。恐怖化改造的直接素材。

### 8. Discord
**版面**:底部固定单行输入条,左侧「+」附件,右侧表情/GIF/贴纸;**无标题、无发布按钮**(Enter 即发);拖文件到窗口任意处出现全屏虚线投放遮罩 + 「Upload to #channel」。
**事实**:官方的**无障碍拖放**方案(用于服务器分组/频道/角色):焦点选中 → `Ctrl/Cmd+D` 拿起 → 方向键移动(**绿色插入指示线**)→ `Space`/`Enter` 放下 → `Esc` 取消;配 live region 播报;该实现已开源为 React DND Accessible Backend。
**这套四键手势是本作键盘可达性的现成蓝本。**

---

## 二、维度 1:功能清单交集(平台 × 功能)

| 功能 | X | IG | 微博 | 小红书 | Reddit | Mastodon | 5ch | Discord |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| 发布按钮 | ✅ 右下 | ✅ 右上 | ✅ 右下 | ✅ 底部 | ✅ 底部 | ✅ 右下 | ✅ 表单下 | ⛔ Enter |
| 取消/关闭 | ✅ 左上× | ✅ 左上< | ✅ | ✅ | ✅ | ✅ | ⛔ | ⛔ |
| 字数/字符计数 | ✅ 环形 | ⛔ | ✅ 超限才显 | ✅ | ✅ 300 | ✅ 数字 | ⛔ | ⛔ |
| 草稿 | ✅ Drafts | ✅ 系统询问 | ✅ | ✅ 显式按钮 | ✅ Save Draft | 客户端各异 | ⛔ | ✅ 输入残留 |
| 附件/媒体 | ✅ | ✅ 必需 | ✅ | ✅ 必需 | ✅ | ✅ | ⛔ | ✅ |
| 可见范围/回复权限 | ✅ 4 档 | ⛔ | ✅ 4 档 | ✅ | ⛔(靠社区) | ✅ 4 档 | ⚠️ sage | ⛔ |
| 内容警告 CW | ⚠️ 敏感标记 | ⛔ | ⛔ | ⛔ | ⚠️ NSFW/Spoiler | ✅ 一等公民 | ⛔ | ⚠️ 剧透 \|\| |
| 发布后编辑 | ✅ 1h/5次 | ✅ 文案可改 | ⚠️ 会员 | ✅ | ⚠️ 正文可/标题**不可** | ✅ | ⛔ | ✅ |
| 删除已发布 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ⚠️ 需申请 | ✅ |
| 标题/正文分离 | ⛔ | ⛔ | ⛔ | ✅ | ✅ | ⛔(CW 近似) | ⚠️ 名前 | ⛔ |
| 结构化标签 | 内联 # | 独立字段 | 内联 `#..#` | **推荐胶囊** | Flair 下拉 | 内联 # | ⛔ | ⛔ |
| 规则提示同屏 | ⛔ | ⛔ | ⛔ | ⚠️ 社区公约 | ✅ **Rules 侧栏** | ⛔ | ⚠️ 板规链接 | ⛔ |
| 多步向导 | ⛔ | ✅ 4 步 | ⛔ | ✅ 2 步 | ⛔ | ⛔ | ⛔ | ⛔ |

**八平台全交集(必做)**:① 一个内容输入区 ② 一个发布动作 ③ 发布后世界会有可见变化。**仅此三条。**
**七/八平台高频(应做)**:发布按钮 + 取消 + 附件 + 删除已发布。
**差异化(选做,承担产品性格)**:计数器形态、CW、可见范围、编辑窗口、规则同屏、向导分步。

---

## 三、维度 2:布局惯例

1. **输入区位置**:恒在**视觉重心上半部**,顶格或紧贴头像;高度策略两派——**固定 min-height + 自增长**(X、微博、Mastodon,起始约 3 行)vs **占满剩余空间**(Reddit 正文、5ch)。移动端一律"输入区吃掉键盘之外的全部高度"。
2. **主按钮位置**:**桌面/模态 → 右下角**(X、微博、Mastodon);**移动端向导 → 右上角**(Instagram);**移动端单页 → 底部通栏固定条**(小红书、Reddit 移动版)。本作是竖屏手机隐喻,应取**底部通栏固定条**(与现有 `fixed_action_bar` 一致)。
3. **计数器位置**:**紧邻主按钮左侧**是压倒性惯例(X 环形、Mastodon 数字)。副字段的计数器则**贴在该字段右端**(Reddit 标题 `x/300`)。**渐进披露**:X 在剩余 ≤20 时环形转橙、≤0 转红并显示负数;微博只在超限时才显数字。
4. **占位符文案写法**:三种句式——**疑问句**(「What's happening?」「有什么新鲜事想分享给大家?」)、**祈使句**(「Title」「添加正文」)、**空**(5ch)。共性是**第二人称、现在时、不超过 12 字、不写"请输入"**。
5. **禁用态 vs 启用态**:惯例是**降不透明度 + 去除阴影 + 光标 not-allowed**,而**不是**变灰边框;文案**保持不变**(仍写「Post」而非「无法发布」)。X 的空态按钮是半透明蓝——**保留品牌色的暗示,只削弱可点性**。
6. **错误提示位置**:**就近原则**——字段级错误紧贴该字段下方(Reddit 缺标题);全局错误(网络失败)用**顶部 toast 或按钮上方一行红字**,且**不清空输入**。

---

## 四、维度 3:交互细节

- **草稿自动保存**:Zulip 规范最清晰——**关闭撰写框时自动存**,**至少 3 个字符**才存,**只存本地不跨设备同步**,再次撰写同一会话时**自动回填最近一条**,并支持"存草稿并新开一条"。X/Reddit/小红书是**显式按钮 + 关闭时询问**的双保险。
- **发布中状态**:NN/g 三档阈值——**0.1s** 感觉即时(无需反馈);**1.0s** 思维不中断(轻反馈即可);**10s** 是注意力上限,超出必须给**百分比进度 + 可取消**。**2–10s 用循环 spinner,10s+ 才用百分比条。** 进度条最忌"飞快跑完卡在最后 1%",一旦如此进度反馈收益归零;宁可**起手慢、末端加速**,或**显示步骤数而非百分比**。
- **发布成功反馈**:主流是**乐观 UI**——立即关框、立即把帖子插入信息流,失败再回滚,配 toast + 「View」跳转。Gmail 式 **Undo 窗口(默认 5s,可延到 30s)** 是可逆操作的黄金范式:**用可撤销代替确认弹窗**。
- **撤销/删除已发布**:全平台皆可删且是硬删;5ch 需走削除依赖。**编辑窗口**最值得借鉴——X 的"1 小时 / 5 次 / edited 标签 / 历史版本可查 / 互动数跨版本累计"是一份完整且自带戏剧性的产品契约。
- **拖内容进输入框**:Discord 是标杆——拖到**窗口任意处**都进入投放态,全屏虚线遮罩 + 文案「Upload to #channel」。通用规范(Pencil & Paper):**先建非拖拽的替代路径**(只有拖拽就是可用性阻断);hover 时光标由 pointer 变 grab/grabbing;拖起时原位留**幽灵占位**;投放区**边缘内**给分级反馈并预告将发生什么;**在放下之前就警告不可投放**(错误预防优于错误提示)。

---

## 五、维度 4:可访问性与移动端

- **触控目标**:WCAG 2.2 SC 2.5.8「Target Size (Minimum)」**AA 级要求 24×24 CSS px**,五条例外(间距 / 等效控件 / 行内 / 用户代理决定 / 本质必要);"间距例外"指以目标包围盒中心画 **24px 直径圆**不与其他目标或其圆相交。SC 2.5.5 Enhanced 是 AAA 更严档。**指南明确:无论间距如何都至少满足最小尺寸,关键控件按 Enhanced 做。** 本作瓦片 44×42 / 44×40、按钮 56 高**已达标,不要缩小**。
- **单手可达区**:Hoober 观测 **49% 的人单手持机**,Josh Clark 估算 **75% 的交互由拇指完成**;屏幕分**易达 / 拉伸 / 难达**三区,**高频放易达、低频放难达**,滑动区 **≥45px**。→ **主发布按钮放底部,破坏性动作(清空句子)放顶部**,免费的误触保险。
- **键盘弹出**:本作是游戏内伪 App,不弹系统软键盘,此条降级为——**投放区高度必须在词库展开/收起时保持稳定**,这正是"已入句的字原位变幽灵、永不 reflow"要坚持的原因。
- **无鼠标可达**:照抄 Discord 四键手势(`Ctrl/Cmd+D` 拿起 → 方向键移动 + **绿色插入指示线** → `Space`/`Enter` 放下 → `Esc` 取消)。本作已有"点击即入句"替代路径(`_on_composer_bank_tapped`),补**焦点遍历 + Esc 取消拖拽**即可。

---

## 六、落地方案:《语言污染》发布界面

### 6.1 页面结构(1600×900 内的手机窗口,按竖屏比例分区)

```
SocialPublishPage (VBox, 100%)
├─ PublishHeader          h=44   固定   左「←」 中「投稿」 右「DAY %02d」
├─ PublishScroll          FILL   滚动
│   ├─ WorldRulesPanel    h≈auto 折叠   ◀ Reddit Rules 侧栏 → 本作"现行规则"
│   ├─ ComposerPanel      h≥200  ★核心  ◀ 造句台(从笔记本搬来)
│   │   ├─ ComposerAnswerFlow   HFlow, min-h 92(两行), 空态显 placeholder
│   │   ├─ ComposerAnswerUnderline  2px
│   │   └─ ComposerMetaRow  左:句子预览(15px) 右:UnitCounter(环形)
│   ├─ MetaRow_Audience   h=44   一行可点  ◀ 微博/Mastodon 可见范围
│   ├─ MetaRow_Warning    h=44   一行可点  ◀ Mastodon CW
│   └─ BankPanel          FILL   ◀ 词库(笔记本画布的投影)
│       └─ NotebookCharFlow  已入句字原位变幽灵,永不 reflow
└─ PublishActionBar       h=76   固定   [清空] [存草稿] [ 投稿这句话 ]
```

**尺寸比例**(手机窗口内高度占比):规则区 0–12%(折叠时 6%)/ 造句台 12–42% / 元数据两行 42–52% / 词库 52–92% / 动作条 92–100%。
**层级**:造句台是唯一有 `flash` 色描边的分区;词库用 `surface` 底;规则区用 `muted` 底、字号降一档(14px),**永远可见但永远不抢焦点**——正是 Reddit Rules 侧栏的心理效果。
**核心改动**:把 `_render_sentence_composer()` 从 `_render_notebook_frame_tab()` 移入 `_render_social_publish_page()`;笔记本保留"自由摆放画布"的身份,发布页是"提交口"。**两者靠同一个 `game.free_sentence_units` 状态同步**,不需要新数据结构。

### 6.2 通用功能 → 本作语义映射

| 通用功能 | 本作语义 | 文案 | 说明 |
|---|---|---|---|
| 字符计数 | **句子里的单位数** | `n 个字` | 借 Bluesky grapheme 语义:一枚瓦片 = 1。**软上限 12**(与 `pollution_gain` 的 clamp 上界 12 对齐),≥10 环形转橙,>12 转红但**仍可投**——超限不是禁令,是警告 |
| 可见范围 | **投稿给谁看 / 世界是否遵守** | `谁会遵守这句话` | 四档:`所有人`(默认)/ `只有塔内`/ `只有医生`/ `只有我自己`。**这是本作最狠的一格**:选"只有我自己"仍然会生效,只是没人看见 |
| 内容警告 CW | **规则预告** | `先说这句话会做什么` | 填了就在信息流里折叠正文、只显示预告。抄 Mastodon 的"邮件主题行"心智 |
| 草稿 | **未投稿的句子** | `留到明天` | 存草稿**不消耗行动**;抄 Zulip:≥3 个单位才自动存,离开发布页时静默存 |
| 编辑窗口 | **改口** | `改口(剩 n 次)` | 抄 X:**投稿后 1 天内、最多 5 次**,改口后信息流帖子挂「已改口」标,**污染继续累计不回退**,可查历史版本 |
| 取消 | **清空句子** | `全部拿回来` | 放**顶部**(难达区),需二次确认或提供 5s Undo |
| 附件 | ⛔ 不做 | — | 本作没有图片语义,强行加只会稀释"语言即一切" |
| 类型 Tab | ⛔ 不做 | — | Reddit 式类型切换会打断试错节奏 |

### 6.3 拖拽落点 / 排序 / 删除规范

- **落点判定(已有底座,补齐反馈)**:
  - 落在 `ComposerAnswerTile` 上 → **插到该瓦片之前**(现状,保留);
  - 落在 `ComposerAnswerFlow` 空白 → **追加到句尾**(现状,保留);
  - 落在最后一枚瓦片的**右半侧** → 追加到句尾(**新增**,避免"想放最后却总插到倒数第二")。
- **插入指示线(必须新增)**:抄 Discord 的绿色指示线——在目标间隙画一条 **2px、`flash` 色、高度 = 瓦片高**的竖线,**替代现在完全没有落点预告的状态**。
- **拖起时**:源瓦片保留原位并降到 `alpha 0.35`(幽灵),预览瓦片跟随光标并 `scale 1.08`。**现有 `set_drag_preview` 只造一个裸 Label,应改为复制瓦片样式的 PanelContainer**。
- **不可投放**:`_can_drop_data` 返回 false 时,预览瓦片**转 `muted` 灰 + 描边虚化**——在放下之前就告知(错误预防优于错误提示)。
- **删除单个词**(参考 Material input chip 的尾部删除位 + 各平台 tag 手势),提供**三条冗余路径**:
  1. **点击瓦片** → 拿回词库(现状 `_on_composer_answer_tapped`,保留);
  2. **拖出造句台边界后松手** → 拿回词库(新增,`is_drag_successful()==false` 时判定);
  3. **键盘**:焦点在瓦片上按 `Delete`/`Backspace` → 拿回词库(新增)。
- **键盘拖拽**(照抄 Discord):`Ctrl/Cmd+D` 拿起 → `←/→` 移动插入线 → `Enter`/`Space` 放下 → `Esc` 取消并复位。
- **反悔**:任何删除/清空后,在动作条上方浮 5s 的一行「已拿回『字』 · 撤销」——用可撤销代替确认弹窗(Gmail Undo 范式)。

### 6.4 发布按钮四态

| 态 | 触发条件 | 文案 | 视觉 |
|---|---|---|---|
| **空** | `units.is_empty()` | `投稿这句话` | `alpha 0.45`,禁用,**文案不变**(照惯例) |
| **可发** | `units.size()>0 and can_spend_action()` | `投稿这句话` | `accent` 实底,`flash` 描边 1px |
| **无行动** | `not can_spend_action()` | `今天说完了` | 禁用;**这是唯一改文案的禁用态**,因为原因不在句子上 |
| **发布中** | 提交动画播放期间 | `正在被读取…` | 按钮塌陷成一条 4px 进度条,`_input_locked = true` |
| **已发布** | 提交成功后 0.6s | 按 tier 分三种:`有什么地方遵守了它` / `世界读错了它` / `没有回应,只有噪声` | 进度条化为整条 `flash` 满格,停 1.2s 后跳信息流 |

**发布中时长必须落在 NN/g 的 2–10s 档**:建议 **1.6s**(循环脉冲,不用百分比)。**绝不要做 10s+ 的百分比条**——那是本作最容易滑向"折磨玩家"的地方。

### 6.5 恐怖化改造:污染哪些反馈(以及绝不能污染哪些)

**可以污染(全部随 `pollution` 分级解锁,且全部可逆/可读)**:
1. **计数器说谎**(污染 ≥30%):环形计数显示的数字比实际单位数**少 1**,但预览文本仍然正确。玩家能靠数瓦片自检 → 不阻断。
2. **进度条倒退**(污染 ≥50%):发布中的脉冲条走到 80% 后**退回 40% 再走完**,总时长仍是 1.6s。**只污染观感,不污染时长**。
3. **占位符自己改写**(污染 ≥40%):空态 placeholder 从「……(句子还空着)」漂移成「……(你已经说过了)」。纯文本层,零功能影响。
4. **已发布内容被改写**(污染 ≥60%,**每天最多 1 次**):信息流里某条**旧**投稿的一个单位被替换,并挂上「已改口」标——**复用 6.2 的编辑窗口 UI**,让污染冒充玩家自己的操作。**关键约束:被改写的必须是已发布的旧帖,永远不能改写当前正在编辑的句子**,否则玩家会失去对输入的控制权。
5. **可见范围自己跳档**(污染 ≥70%):从「所有人」跳到「只有我自己」,并在元数据行留一行小字「(它自己改的)」。**必须显式告知**,否则是不可解释的失败。
6. **投稿按钮的 hover 音效降调**(污染 ≥20%):最便宜、最不伤可用性的一档,建议第一个上。

**绝不能污染(可用性红线)**:
- 造句台里**当前**句子的瓦片顺序与内容(玩家的直接操作对象必须绝对可信);
- 「投稿这句话」按钮的**位置与命中区**(不许漂移、不许缩小、不许假禁用);
- 「撤销」与「拿回」路径(逃生通道永远真实);
- 现行规则列表的**内容**(可以污染它的**排版**——抖动、渗墨——但文字必须准确,否则玩家无法推理);
- 行动点数与污染度数值(HUD 是契约)。

**判据一句话**:**污染"世界对你的回应",不污染"你对世界的操作"。**

### 6.6 Godot 4 实现要点

**节点结构**(沿用现有命名习惯,`_find_control_by_name` 可直接取):
```
SocialPublishPage(VBox)
├─ SocialPublishHeader(HBox, min-h 44)
├─ SocialPublishScroll(ScrollContainer, v=AUTO, h=SHOW_NEVER)
│  └─ SocialPublishContent(VBox, sep 8)
│     ├─ ComposerRulesList(VBox)            ← 已有,移到顶部
│     ├─ ComposerAnswerPanel(ComposerDropArea)
│     │  ├─ ComposerAnswerFlow(HFlowContainer, min-h 92)
│     │  │  └─ ComposerAnswerTile%d(ComposerAnswerTile, 44×42)
│     │  ├─ ComposerInsertMarker(ColorRect, 2×42, visible=false)  ★新增
│     │  ├─ ComposerAnswerUnderline(ColorRect, h 2)
│     │  └─ ComposerMetaRow(HBox)
│     │     ├─ ComposerPreviewLabel(Label, FILL)
│     │     └─ ComposerUnitCounter(Control, 28×28, _draw 画环)  ★新增
│     ├─ PublishAudienceRow(Button, flat, min-h 44)               ★新增
│     ├─ PublishWarningRow(Button, flat, min-h 44)                ★新增
│     └─ NotebookCharFlow(HFlowContainer)     ← 已有,移下来
└─ SocialPublishActionBar(PanelContainer, fixed_action_bar)
   ├─ PublishUndoToast(HBox, visible=false)                       ★新增
   └─ PublishActionRow(HBox): [ComposerClearButton] [ComposerDraftButton] [NotebookCraftButton]
```

**拖放协议**(不改协议,只加钩子):
- 沿用 `{kind, id, label}` 三键载荷与 `composer_unit` / `composer_reorder` 两种 kind;
- `ComposerDropArea` 新增 `_can_drop_data` 副作用:命中时 `_update_insert_marker(at_position)`,把 `ComposerInsertMarker` 移到最近间隙并 `show()`;
- 用 `NOTIFICATION_DRAG_END` 统一 `hide()` 指示线、清幽灵态——**别在 `_drop_data` 里清,拖到界外时不会触发**;
- "拖出边界即删除"用 `Control.is_drag_successful()`(或 `Viewport.gui_is_drag_successful()`)在 `NOTIFICATION_DRAG_END` 里判定;
- 若要在 `_drop_data` 里再发起一次拖拽,`force_drag()` **必须 `call_deferred()`**,否则与拖拽生命周期冲突;
- 拖拽预览换成复制瓦片样式的 `PanelContainer`,并**监听预览的 `tree_exiting`** 以捕捉失败投放。

**状态机**(建议新建 `scripts/ui/publish_state_machine.gd`,枚举而非布尔散落):
```
EMPTY ──place──▶ READY ──submit──▶ SENDING ──ok──▶ PUBLISHED ──1.2s──▶ EMPTY
  ▲                 │                  └──fail──▶ READY(保留句子 + 顶部红字)
  └────clear/undo───┘
READY ──no_actions──▶ BLOCKED ──new_day──▶ READY
```
- `SENDING` 期间 `_input_locked = true`(已有机制),动作条按钮全禁用但**不隐藏**;
- 失败(`reason == "empty"` / `"no-actions"`)**绝不清空 `free_sentence_units`**——现有 `submit_free_sentence` 已保证只有成功路径才 `clear()`,继续保持;
- 污染效果挂在**状态进入回调**上(`_on_enter_sending` 里决定进度条是否倒退),与业务逻辑解耦,便于测试时关掉。

### 6.7 验收标准清单(可直接当测试用例)

**结构**
- **AC-01** 发布页存在 `ComposerAnswerFlow`、`NotebookCharFlow`、`ComposerRulesList` 三个节点,且**都在同一屏内**(不需要切页)。
- **AC-02** `ComposerRulesList` 在 `ComposerAnswerPanel` **之上**(索引更小)。
- **AC-03** `SocialPublishActionBar` 带 `fixed_action_bar` meta,且**不随 ScrollContainer 滚动**。
- **AC-04** 笔记本页与发布页读同一个 `game.get_free_sentence_units()`;在任一页增删,另一页重绘后一致。

**拖放**
- **AC-05** 拖 `composer_unit` 到某 `ComposerAnswerTile` → 插入到该瓦片索引**之前**。
- **AC-06** 拖 `composer_reorder` 从 index 2 到 index 5 → 结果索引为 **4**(`from<to` 时 `to-1` 的既有修正)。
- **AC-07** 拖 `kind` 不在 `["composer_unit","composer_reorder"]` 内 → `_can_drop_data` 返回 false 且句子不变。
- **AC-08** 拖拽开始后 `ComposerInsertMarker.visible == true`;`NOTIFICATION_DRAG_END` 后为 `false`(**含拖到界外的情况**)。
- **AC-09** 已入句的字在 `NotebookCharFlow` 中**保持原索引**且 `disabled == true`、`modulate.a ≈ 0.55`(不 reflow)。
- **AC-10** 焦点在答案瓦片上按 `Delete` → 该单位回到词库,句子长度 -1。
- **AC-11** `Ctrl/Cmd+D` → `←/→` → `Enter` 的键盘路径可完成一次重排,`Esc` 可取消且句子不变。

**按钮态**
- **AC-12** `units.is_empty()` 时 `NotebookCraftButton.disabled == true`,文案仍为「投稿这句话」。
- **AC-13** `can_spend_action() == false` 时按钮禁用且文案为「今天说完了」。
- **AC-14** `units.size() > 0 and can_spend_action()` 时按钮可点。
- **AC-15** 点击后进入 `SENDING`,`_input_locked == true`,且 1.6s ± 0.2s 内进入 `PUBLISHED` 或回到 `READY`。
- **AC-16** 提交失败(`submitted == false`)时 `free_sentence_units` **长度不变**。
- **AC-17** 提交成功后 `free_sentence_units.is_empty() == true`,且 `published_memes[0].units` 等于提交前的单位序列。

**计数与元数据**
- **AC-18** `ComposerUnitCounter` 显示值 == `units.size()`(污染 <30% 时);污染 ≥30% 时显示值 == `units.size() - 1`,但 `ComposerPreviewLabel` 文本仍与 `get_free_sentence_text()` 完全一致。
- **AC-19** 单位数 ≥10 时计数环转 `flash` 橙档;>12 转红,但按钮**仍可点**。
- **AC-20** 可见范围默认「所有人」;选「只有我自己」后提交,`submit_free_sentence` 的 tier 与 `money_gain` **不受影响**(可见范围只改叙事表现,不改数值)。

**可访问性**
- **AC-21** 所有可点控件的 `custom_minimum_size` 两轴均 ≥ 44px(瓦片 44×42/44×40、行 44、主按钮 56 均已满足)。
- **AC-22** 破坏性动作(清空)不在底部易达区;主发布按钮在底部固定条。
- **AC-23** 任何删除/清空后出现 5s 的 `PublishUndoToast`,点击可完整还原句子。

**恐怖化(可开关,默认随污染度)**
- **AC-24** 污染 ≥50% 时发布进度条出现一次倒退,但 `SENDING` 总时长与污染 <50% 时**误差 <0.1s**。
- **AC-25** 污染 ≥60% 时被改写的**只能是 `published_memes` 中 index ≥1 的旧记录**,当前 `free_sentence_units` 永不被外部修改(单测直接断言)。
- **AC-26** 任何污染档位下,`NotebookCraftButton` 的 `global_position` 与 `size` 与未污染时一致。
- **AC-27** `ComposerRulesList` 的文本内容在任何污染档位下与 `RuleEngine.rule_display_text()` 的返回值逐字相等(只允许样式污染)。

---

## 七、三个开源参考对比

| | **bluesky-social/social-app** | **mastodon/mastodon** | **peter-kish/gloot** |
|---|---|---|---|
| **定位** | Bluesky 官方客户端(Web/iOS/Android) | 联邦宇宙服务端 + Web 前端 | Godot 4 通用物品栏系统 |
| **协议/许可** | MIT + 软件专利互不侵犯承诺 | **AGPL-3.0**(传染性强) | MIT |
| **体量** | 18k+ ★ / 2.7k fork,TS 93.2% | 50.2k ★ / 7.5k fork | 927 ★ / 43 fork / 1205 commits |
| **技术线** | React Native + Expo;Go 写的 `bskyweb/`;pnpm workspaces;`src/` `modules/` `__tests__/` `__e2e__/` | Rails(REST/页面)+ PostgreSQL + Redis/Sidekiq + Node streaming + React/Redux;`/app` `/lib` `/streaming` | 纯 GDScript addon,Godot **4.4+**,v3.0 为当前稳定版 |
| **可借鉴的功能** | **grapheme 计数**(`maxGraphemes: 300` 写在 lexicon schema 里,前后端同源)、富文本 facet 的 byte 索引、threadgate 回复控制 | **CW 折叠 / 四档可见性 / 投票 / 附件描述与焦点**——四者在同一个 compose 组件里共存的产品级实现;链接一律算 23 字符的计数规则 | `Inventory` + `GridConstraint`/`WeightConstraint`/`ItemCountConstraint` 的**约束式**建模;`InventoryItem` 栈;JSON `Prototree` 定义原型与继承;`CtrlInventory`/`CtrlInventoryGrid`/`CtrlInventoryCapacity`/`CtrlItemSlot` |
| **架构可迁移点** | **"上限写在 schema 里,UI 只是读它"**——本作应把"12 个单位软上限"写进规则引擎侧的常量,而非硬编码在 UI | **可见性是一等公民,不是附加开关**——四档枚举贯穿数据模型到渲染 | **约束与 UI 分离**:`ItemCountConstraint` 就是本作"单位数软上限"的现成形状;`CtrlInventoryCapacity` 是"污染进度条"的形状 |
| **优点** | 生产级、活跃、跨端;计数语义与本作"一枚瓦片 = 1"完全同构 | 功能最全的开源 compose 实现,CW 与可见性有真实产品验证 | 语言、引擎、版本全部与本作一致,可直接读源码抄拖放实现 |
| **缺点** | RN 技术栈与 Godot 零共享代码,只能抄**语义**不能抄**代码**;体量大,定位具体文件成本高 | **AGPL 会传染**——只能读、只能借鉴设计,**不可复制代码**;Rails 栈离 Godot 最远 | 面向"格子物品栏"而非"线性词序列",`GridConstraint` 对本作是过度建模;README 未详述拖放,需读源码 |
| **建议用法** | 抄计数语义 + threadgate 心智,不抄一行代码 | 抄 CW / 可见性的产品契约(纯设计参考,规避 AGPL) | **唯一可直接读代码的参考**,重点看 `Ctrl*` 系列如何在 Godot 4 里组织"拖拽源 / 投放目标 / 预览" |

**补充参考(反面教材)**:`ccrsxx/twitter-clone`(MIT,949 ★ / 235 fork,Next.js + TS + Tailwind + Firestore + SWR/Headless UI/React Hot Toast/Framer Motion)。覆盖发推、图片/GIF、点赞转推回复、删除/收藏/置顶、实时更新、响应式三档布局,但**没有草稿、没有编辑、没有环形计数**,且已于 **2026-02-19 归档**。它恰好印证本报告结论:**"输入框 + 发布按钮"很容易,难的是草稿、计数、编辑窗口这三件"承诺型"功能**——而这三件正是本作恐怖化改造最有价值的抓手。另可参考 `expressobits/inventory-system`(MIT,717 ★,Godot 4,逻辑与 UI 分离、物品即资源、支持多人;主体为 C++ 插件,GDScript-only 团队改造成本高,其 README 本身就把网格 UI 指向 GLoot)。

---

## 来源链接

**X / Twitter**
- [About Edit Post — X Help Center](https://help.x.com/en/using-x/edit-post)
- [About conversations on X(回复权限四档)— X Help Center](https://help.x.com/en/using-x/x-conversations)
- [Character limit — Wikipedia(140/280/4000/10000/25000 沿革)](https://en.wikipedia.org/wiki/Character_limit)

**Instagram**
- [Instagram Flow(发帖流程拆解)— Hana Jimenez / Medium](https://medium.com/@hana.jimenez/instagram-flow-b3a56c2bdee9)

**微博**
- [微博对全体用户取消140字限制 最多可输入2000字 — 央广网](http://tech.cnr.cn/techgd/20161115/t20161115_523266987.shtml)
- [微博将解除140字发布限制:小于2000字都可以 — 新浪科技](http://tech.sina.com.cn/i/2016-01-20/doc-ifxnqriz9944498.shtml)
- [评论的字数上限为140字 — 微博客服](https://kefu.weibo.com/faqdetail?id=21510)

**小红书**
- [小红书笔记可以写多少字?字数限制怎么解除? — 蚁小二](https://xueyuan.yixiaoer.cn/article/29829)
- [最新小红书笔记规范分享 — OST传媒](https://www.ostmcn.com/article-1351.html)

**Reddit**
- [Reddit Character Limits: Titles, Posts, Comments (2026) — wordlimit.ai](https://wordlimit.ai/limits/reddit)
- [Sidebar Widgets(Rules 侧栏)— Reddit Mods](https://mods.reddithelp.com/hc/en-us/articles/360010364372-Sidebar-Widgets)

**Threads / Bluesky / Mastodon**
- [Posting — Mastodon Documentation(CW、四档可见性、附件与投票规格)](https://docs.joinmastodon.org/user/posting/)
- [Threads Character Counter — charactercounter.com](https://charactercounter.com/threads)
- [Bluesky Character Counter: 300 Grapheme Limit Guide — BrandGhost](https://blog.brandghost.ai/posts/bluesky-caption-character-counter/)
- [Threads vs Bluesky vs Mastodon (2026) — socialk.it](https://socialk.it/en/blog/threads-vs-bluesky-vs-mastodon)

**5ch / BBS**
- [5chへの書き込み方や疑問を総まとめ【ID・sageなど】— バルス東京](https://www.balstokyo.com/5ch/howto_kakikomi/)
- [5chの使い方まとめてみた — 5ちゃんねる夫 / note](https://note.com/5ch/n/na92b1d27f222)

**Discord**
- [Accessible Drag and Drop FAQ(Ctrl+D / 方向键 / 绿色指示线 / Esc)— Discord Support](https://support.discord.com/hc/en-us/articles/4408877527703-Accessible-Drag-and-Drop-FAQ)

**交互与可访问性**
- [Understanding SC 2.5.8: Target Size (Minimum) — W3C WAI](https://www.w3.org/WAI/WCAG22/Understanding/target-size-minimum.html)
- [2.5.5 Target Size (AAA) — Deque University](https://dequeuniversity.com/resources/wcag2.1/2.5.5-target-size)
- [The Thumb Zone: Designing For Mobile Users — Smashing Magazine](https://www.smashingmagazine.com/2016/09/the-thumb-zone-designing-for-mobile-users/)
- [Response Time Limits: 0.1s / 1s / 10s — Jakob Nielsen, NN/g](https://www.nngroup.com/articles/response-times-3-important-limits/)
- [Progress Indicators Make a Slow System Less Insufferable — NN/g](https://www.nngroup.com/articles/progress-indicators/)
- [Drag & Drop UX Design Best Practices — Pencil & Paper](https://www.pencilandpaper.io/articles/ux-pattern-drag-and-drop)
- [Drag-and-Drop UX: Guidelines and Best Practices — Smart Interface Design Patterns](https://smart-interface-design-patterns.com/articles/drag-and-drop-ux/)
- [View and edit your message drafts(草稿自动保存规范)— Zulip](https://zulip.com/help/view-and-edit-your-message-drafts)
- [UX for reversible actions: A decision framework — LogRocket](https://blog.logrocket.com/ux-design/ux-reversible-actions-framework/)
- [Chips — Material Design 3](https://m3.material.io/components/chips/guidelines)

**Godot 4 实现**
- [Godot 4.x Drag and Drop(三个虚方法、set_drag_preview、force_drag 的 call_deferred 陷阱)— dev.to](https://dev.to/pdeveloper/godot-4x-drag-and-drop-5g13)
- [Drag and Drop Basics in Godot: A Beginner's Guide — Godot Dev Digest / Medium](https://medium.com/godot-dev-digest/drag-and-drop-basics-in-godot-a-beginners-guide-313277975e06)

**开源参考**
- [bluesky-social/social-app — GitHub](https://github.com/bluesky-social/social-app)
- [mastodon/mastodon — GitHub](https://github.com/mastodon/mastodon)
- [peter-kish/gloot — GitHub](https://github.com/peter-kish/gloot)
- [ccrsxx/twitter-clone(已归档,反面教材)— GitHub](https://github.com/ccrsxx/twitter-clone)
- [expressobits/inventory-system — GitHub](https://github.com/expressobits/inventory-system)
