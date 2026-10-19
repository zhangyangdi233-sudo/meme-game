# 首次地下室与 CRT 教学交付

本轮只增加第一回地下室的一次性楼梯旁白和首次 CRT 操作教学。第五回 13 路视频/红屏事件、五回 NPC 交付与手机应用解锁仍使用各自原有状态。

## 楼梯演出

`chapter_crt_focus_controller.gd` 从 `chapter_world.gd` 的真实楼梯契约取得中段跨越检测：本资产局部 x 范围为 -3.14 至 -1.85，中段 z=0.5，楼梯脚下高度约 1.35m。由前后位置跨平面触发，只有第一回有效。

触发时保留玩家实际坐标与原相机姿态，冻结残余速度。背景立即切为黑色；相机在原位置用 0.8 秒 SINE 曲线看向 CRT，同时轻收视场至 34°。原 CRT 外壳、喇叭、按钮与屏幕使用临时第 18 可见层；同一 World3D 的原灯状态暂存并熄灭。新的顶部白 SpotLight 与原创透明锥束均只在教学层显示。透明锥束使 Compatibility 渲染器也能看见空气中的白光，而非只有表面受光。

每次真实鼠标点击或触摸推进一句，字幕与已有 `chapter_narration_blips.gd` 的 03 音节播放组件复用。没有新增或声称提供完整真人录音。七句中文严格保持用户原文和顺序：

1. 这个对你来说不陌生
2. 你之前可喜欢盯着这个发呆了
3. 现在被你遗忘也是情有可原
4. 但是现在这个东西对你来说……
5. 很有意思……是吧
6. 去看看这个老家伙吧
7. 你现在只能依靠它咯！

末句后再点击，立即恢复原房间、原灯光与 CRT 可见层，去掉白光及锥束；用 0.65 秒恢复原朝向和视场。全过程玩家没有被传送到电视前。设置、失焦与其它模态暂停镜头和旁白，不推进句数。退出/重建会恢复临时显示状态；未完成的存档保留当前句与原相机/玩家位置，继续时恢复演出；完成后不再触发。世界交互提示在演出期间隐藏。

## 终端操作教学

`chapter_crt_terminal_tutorial.gd` 属于 `chapter_terminal_session.gd`，继续借用原社交、详情、笔记本和拾字飞行动画 Control。教程没有复制库存或另建发布系统。遮罩位于实际 1600×1200 CRT SubViewport，目标矩形既是可见高亮也是命中测试的放行区域；其它控件变灰、按钮禁用。

阶段依次为 `post → collect → compose → publish → complete`：只打开 `floor_13` 原帖，点击三个实际可拾取单位，真实拖入原句子栏，最后点击原发布按钮。中文为“门 / 打 / 开”，英文为“door / can / open”，日文为“ドア / は / ひらく”，发布结果分别为“门打开”“door can open”“ドアはひらく”。日文原帖为“屋上のドアはひらく。だれも出ない。”，助词 `は` 正式列入原有可拾字池和 `particle` 词典；仍须从真实帖文点击获得，不直接加入库存。三语都形成正向 `door|can_open`，具有当前 `basement_help_01` 与访问 token，满足 NPC 使用的 `has_current_chapter_submission()` 条件。教程内容及七句 EN/JA 在独立内容模块，不改共享翻译目录。

遮罩不是唯一门控：原 UI 回调先经过 session 的 `tutorial_allows`，成功后调用 `tutorial_commit`。只有实际屏幕 Ray→UV→SubViewport 输入事务内的成功动作能推进。点字不能替代拖拽，未完成三个拖拽不能发布；直接调用主场景拾字/打开帖回调也不能越过教学。完成后恢复正常内容；手机应用权限仍由原 NPC 交付决定。

Tab 可以退出，并保留拾取/拖拽阶段。普通保存/继续后再次按 F 进入 CRT，会恢复同一帖子及剩余步骤。持住字块时按 Tab 不会把取消用的合成释放误记成放字。语言切换只重新开始当前未完成的操作教学，已经获得的各语言库存不删除。原场景已完成的教学不会重复。英文详情作者栏做了限定宽度并在退出后恢复，避免长标题把评论里的目标词撑到屏幕外。

新进度保存在 `game.chapter1_progress.crt_tutorial`，由独立 `chapter_crt_tutorial_state.gd` 正常化，包括损坏类型、重复证据、未知单位和不完整发布证据的处理。它与旧 `stitched_guide_onboarding` 无关。

## 验证与画面

- `tests/test_chapter_crt_onboarding.gd`：46 项，真实 GLB 楼梯/CRT、各灯恢复、暂停、读档续句、完整回转、已完成不重播、原文及三语言真实字池、损坏存档类型。
- `tests/test_chapter_crt_terminal_onboarding.gd`：ZH/EN/JA 各 37 项通过；每种语言从空教学开始，真实 F 事件路由、屏幕 UV 点击、RichText hover 定位与点击、三个物理字块拖拽、发布；含普通保存/继续、Tab 中断及持字取消。新增自然句、正向规则、真实三单位、任务/token 与 NPC 投稿资格断言。没有用 `meta_clicked.emit` 或拾字回调来代替点击。
- 原 `test_chapter_terminal_session.gd`：56 项通过。原 `test_chapter_terminal_flow.gd`：426 项通过，保留五回 NPC 交付和三次继续；该广域测试明确从已完成首次教学的独立应用 fixture 开始，首次教学由上面的专项覆盖。
- 实际截图使用 NVIDIA RTX 4070 Ti、OpenGL Compatibility、隐藏原生窗口和真实 SubViewport；中文完整输入和渲染验收通过。所有测试使用 `artifacts/crt-onboarding-20261019/profile*` 隔离存档，未写玩家正式存档。
- 主场景测试退出仍出现原有 RID/ObjectDB 资源清理诊断；Compatibility 的景深不可用警告也保留在渲染日志。验收依据为无脚本/解析错误、断言通过及真实画面，不将退出诊断隐去。
- 日文审查先在未修改词池时运行新断言，确实复现旧“ドアひらくない”产生否定规则；修正后的三语实测全部通过。`test_rule_engine.gd` 另行通过。
- 额外旧 `test_pickup_char_flow.gd` 与 `test_sentence_composer.gd` 初跑分别暴露 13 / 6 个过时断言。已用只读 `git show HEAD` 核对基线 `851818dafe78fda3537c5c4f08284e15fb9c53d4`：此前 `spend_action()` 已不耗点、`can_spend_action()` 恒真、投稿 `money_gain=0`、第二层污染不推进、笔记本保持手机内嵌。因此仅更新测试合同，未为旧测试回改生产逻辑，也未删除测试。现分别 **133 / 80 项通过**，覆盖零行动/零余额仍可投稿、跨日拾字不收费、不强制日结、字池词典与三语种子、内嵌笔记本飞行目标、第二层必须完成 Xray 发现后走显式出口，以及进入第三层兑现此前投稿的正向门规则。

日志和图片位于 `artifacts/crt-onboarding-20261019/`：`focus.log`、`terminal-zh.log`、`terminal-en.log`、`terminal-ja.log`、`legacy-flow.log`、`session.log`、`render-zh.engine.log`。日文修复的失败基线为 `terminal-ja-positive-red.log`；额外检查为 `rule-engine.log`、`pickup-char-flow.log`、`sentence-composer.log`。两个旧测试的初跑失败保留在 `pickup-char-flow-precontract.log` / `sentence-composer-precontract.log`；提交基线的只读合同摘录为 `legacy-test-contract-baseline.txt`。

![黑背景中的 CRT 与顶部白光](../artifacts/crt-onboarding-20261019/zh-stair-01-black-crt.png)

![恢复原地下室](../artifacts/crt-onboarding-20261019/zh-stair-02-restored.png)

![唯一高亮帖子](../artifacts/crt-onboarding-20261019/zh-terminal-01-single-post-screen.png)

![三字拾取](../artifacts/crt-onboarding-20261019/zh-terminal-02-three-words-screen.png)

![真实组句后才开放发布](../artifacts/crt-onboarding-20261019/zh-terminal-04-publish-screen.png)

运行专项的 PowerShell 入口（先创建隔离目录）：

```powershell
$env:APPDATA = 'D:\aphasia\meme-game\artifacts\crt-onboarding-20261019\profile'
$env:XDG_DATA_HOME = $env:APPDATA
New-Item -ItemType Directory -Force -Path $env:APPDATA | Out-Null
$env:CRT_TEST_LOCALE = 'zh' # 也可 en / ja
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --log-file 'D:\aphasia\meme-game\artifacts\crt-onboarding-20261019\manual.engine.log' --script res://tests/test_chapter_crt_terminal_onboarding.gd
```

真实渲染时去掉 `--headless`，增加 `--rendering-method gl_compatibility --rendering-driver opengl3`；脚本把原生窗口隐藏，只渲染测试 SubViewport 并保存截图。不要与 Windows 鼠标捕获原生窗口回归同时运行。

## 参考与许可

[方案对比](references/2026-10-19/crt-tutorial-comparison.md)、[固定提交及 SHA256 清单](references/2026-10-19/crt-tutorial-manifest.json)、[Godot Tours MIT 许可](references/2026-10-19/godot-tours-LICENSE.txt)。原始四个小型参考文件下载在 `D:/aphasia/参考/20261019-crt-tutorial`，只用于阅读，未安装编辑器插件或复制其代码到运行时。itch 参考没有确认开源许可，未导入代码或媒体。
