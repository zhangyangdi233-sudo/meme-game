# 第一章接入与运行

更新：2026-10-14。当前路线为黑水白门开场、五轮地下室、空旷十字路口、第二层。地下室现需拾取实体手机，NPC直接进入单线对话，主角通过键盘打字说出台词。[2026-10-10 合并交接目录](handoff/2026-10-10/) 记录此前验证；[2026-10-09](handoff/2026-10-09/README.md) 及更早文档保留作历史。旧隧道、三 App、资金与每日行动预算不再是当前流程。

## 启动与游玩

当前 Mac 本机普通启动使用父目录的 `开始第一章.command`，实际加载此 `第一章-20261009` 工程。Windows 原环境普通启动使用 `D:/aphasia/Start-Aphasia.ps1`，独立开发验证使用：

~~~powershell
& 'D:\aphasia\Start-Chapter1-Dev.ps1'
~~~

开发启动器使用 Godot 4.6.3 和 `--chapter1-dev`，将存档与偏好隔离到 `D:/aphasia/outputs/chapter1_development/profile`，日志写入同目录上一级的 `chapter1_latest.log`。在主菜单选择新游戏开始；其他电脑配置见 [Windows 启动说明](../support/windows_workspace/README.md)。

| 操作 | 入口 |
| --- | --- |
| 开场旁白 | 鼠标左键或触摸板点击，每次推进一句；不自动播放 |
| 移动与转向 | WASD/方向键、鼠标；点击世界恢复鼠标视角 |
| 交互 | 靠近目标按 F |
| 手机、退出 CRT | 拾取手机后点击屏幕右侧突起或按 Tab 开合；CRT 内 Tab 退出 |
| NPC 对话 | F 直接交谈，轮到主角时用键盘打字；NPC 回复按阅读时间自动续句，最后自动结束，无继续或离开按钮 |
| 设置 | Esc/F10，包括开门与 CRT 镜头期间 |
| 返回主菜单 | 设置底部按钮，取消当前声音和过场 |
| 开发面板 | F9，仅开发模式；显示时释放鼠标 |

Win/Alt-Tab 失焦释放鼠标。设置暂停开场计时、敲门、门和 CRT 镜头，关闭后继续；返回主菜单不留下旧场景推进回调。

NPC 回复按显示文本长度保留阅读时间，中、英、日和混合文本都按实际文字计算。设置、弹窗、失焦与过场冻结剩余时间；退出对话或重建场景取消旧播放状态。主角台词仍需键盘逐字推进。当前 NPC 没有独立配音音轨，因此自动推进使用文本阅读时间，不受环境音乐影响。

1. **开场。** 全黑 2 秒后显示黑水、29.5 米外白门与第一句旁白。鼠标左键或触摸板点击一次推进一句，阅读期间暂停移动、转向和手机操作。采用用户原稿编号：1 至 26 不响敲门；27 是音效说明，不显示成字幕；26 后点击进入 28，出现“看来你潜意识已经准备好了”时开始约 6.243 秒的完整敲门。继续点击 29、30，从 30 再点击结束旁白。旁白和录音都结束后，玩家可走近白门按 F，镜头随慢开门向内推进，经短淡黑进入地下室。无需自行穿门。
2. **每轮教程。** 从楼梯顶安全平台进入，跨过入口后身后门锁住。首次在小桌上找到实体手机并靠近按 F 拾取；未拾取时没有手机UI。CRT 从第一轮即可拾字、组句、投稿。退出屏幕后靠近本轮 NPC 按 F 直接交谈，用键盘逐步说完主角台词，完整对话结束时自然交付。必须已有本轮成功的非空自由组句投稿；未投稿会提示返回电脑，已有字可以反复用。
3. **普通出口。** 交付后靠近左后方门按 F，门开时镜头持续推进。前四轮门后衔接下一轮入口；第五轮使用真实十字路口场景的 portal 视图，进入十字路口。循环不再生成 12 米隧道、白光门或白闪，也不使用开场淡黑。
4. **手机与远门。** 手机收起时保留屏幕右侧突起，点击后从右边滑入。主页只显示信号瀑布和笔记本，两者分别在第 1、3 轮交付后解锁；所有 App 页面在手机屏幕内切换，关闭页面可回到手机主页。第 2、4、5 轮没有新增 App，但仍须交付。十字路口无人，远门检查五轮完成与两款 App 权限，按 F 开门并穿过后进入第二层。
5. **后续推进。** 资金与每日行动限制已移除；污染在后台影响语言、规则和楼层，玩家界面不显示数值。有效交互完成时检查推进。到达新楼层显示约 2.6 秒无衬线大标题，世界画面保留。

五轮沿用护灯人、迟到者、回声住户、抄写员、无名信徒的贴图与原对话，每轮使用固定的一条剧情路线。章节角色 `basement_npc_01…05`、任务 `basement_help_01…05` 与原 `source_actor_id/type` 分开；正式新任务正文仍待接入。护灯人完整对话使第一层隐藏线索显形并自然领取，隐藏线索本身不完成教程，也不授予 App。

第一次主角发言时，台词下方显示中、英、日对应的键盘提示；`dialogue_typing_hint_seen` 随游戏存档保留，新游戏重置。字母、数字、空格及已提交的 Unicode 输入各推进一个当前语言的台词单位，无需照抄原句。方向键、修饰键、快捷键和长按重复不推进；设置或失焦时暂停。污染仍可改变显示文字，但理解失败不会切断固定的后续剧情。医生同样使用固定键盘台词，优先说出最新投稿，无投稿时使用固定回应。

## 正式任务与流程 API

主场景提供 `notify_chapter1(event_id, payload)`，返回 `{accepted, progress, transition}`。阶段状态由 [basement_loop_director.gd](../scripts/progression/basement_loop_director.gd) 校验，宿主实现位于 [babel_meme_game.gd](../scripts/babel_meme_game.gd)。

| 事件 | 参数与可信发送时机 |
| --- | --- |
| `opening_narration_advanced` | `{"sequence_id": "chapter1_opening", "from_line": 当前编号}`；每次点击推进一句，26 跳到 28，30 后完成旁白 |
| `narration_completed` | `{"sequence_id": "chapter1_opening"}`；受信兼容事件，记录旁白完成；仍需敲门完成才能开门 |
| `opening_knock_completed` | 同上；由开场世界在完整敲门结束后发送 |
| `opening_door_opened` | 开场门过场到达房间切换回调后发送，进入地下室 |
| `entrance_threshold_crossed` | `{"round_token": captured_round_token}`；越过本轮安全入口后发送 |
| `phone_collected` | 当前 `round_token`；靠近地下室小桌上的实体手机按 F 后发送，只记录手机所有权，不授予 App |
| `basement_whisper_started` | 当前 `round_token`；仅第二轮入口已锁、耳语开始时接受一次，立即持久化 `basement_whisper_played` |
| `npc_help_completed` | 当前 NPC、任务及捕获的令牌；本轮已有有效投稿且单线对话完整结束后发送 |
| `basement_exit_requested` | 当前令牌；已完成任务且普通出口门过场完成时提交 |
| `crossroads_gate_requested` | 由十字路口远门通过检查后发送，进入塔层 |

任务开始时捕获身份和令牌，完成时提交原值，避免异步回调误用新轮次：

~~~gdscript
main.notify_chapter1("npc_help_completed", {
    "npc_id": captured_npc_id,
    "task_id": captured_task_id,
    "round_token": captured_round_token,
})
~~~

错误阶段、错误 NPC/任务、过期令牌和重复完成均被拒绝。玩家实际交付入口还检查 `has_current_chapter_submission()`；草稿、旧轮投稿和普通交谈不能替代交付。门口按 F 只启动过场，不能直接跳过完成检查。

奖励映射保存在 `reward_config.task_app_unlocks`，当前仅第 1 轮 social、第 3 轮 notebook；远门要求两款 App 与五个任务。旧 `basement_tunnel_entered`/`exit_tunnel_entered` 只用于兼容，不能恢复已取消的隧道步骤。

## CRT、输入与字词

[chapter_terminal_session.gd](../scripts/ui/chapter_terminal_session.gd) 将社交、笔记本、社交详情和拾字动画层临时移入 1600×1200 的 SubViewport；[chapter_terminal.gd](../scripts/world/chapter_terminal.gd) 根据真实屏幕三角形 UV 转发点击、滚动、拖拽和键盘输入。信号瀑布与笔记本同屏显示，退出时恢复原控件实例、父节点和布局。两端没有独立副本词库。

手机由 [phone_dock.gd](../scripts/ui/phone_dock.gd) 提供右侧收纳、展开和内部页面切换；`chapter1_progress.phone_collected` 控制是否拥有手机。拾取后两款 App 仍初始锁定；CRT 第一轮即提供教学功能。手机入口、恢复窗口和编辑回调均检查权限。靠近屏幕才可进入，镜头约 0.8 秒推进、0.65 秒退回；镜头移动时不接受屏幕操作。设置取消屏内按下/拖拽状态，不误触按钮；返回主菜单或换场先恢复控件再释放会话。

正文和可拾字使用相同继承字号。CRT 内容基准 36px，字距增加 1px、行距 6px；字块按文字实际宽度配置碰撞。字块拖放由 [word_physics_canvas.gd](../scripts/ui/word_physics_canvas.gd) 处理，松手后恢复物理；坐标按实际画布保存，重绘与 CRT/手机尺寸变化后保持可用。滚轮加快，底部投稿按钮保留在显示范围内。

中、英、日设置可实时切换；全局 VHS 与 CRT 局部 VHS 分开保存。局部效果使用屏幕材质纹理，不采样整屏。资源栏、巴别塔 App、自动播放和历史入口已退役。

## 灯光、房间异常与 X-ray

[basement_atmosphere.gd](../scripts/world/basement_atmosphere.gd) 集中处理本轮运行时修补、家具、墙纸、地毯、灯具、开关和钟。顶部轮次常量从 0 计数：

| 常量/轮次 | 行为 |
| --- | --- |
| 第 1 轮 | 正常灯光和单钟 |
| `FLICKER_VISIT = 1` | 第 2 轮入口锁住 2.5 秒后，D 耳语与闪灯同步持续 8 秒，随后声音停止、亮灯恢复 |
| `BLACKOUT_VISIT = 2` | 第 3 轮入屋后停电，墙上开关按 F 可恢复；CRT 绿光保留 |
| `CLOCK_WALL_VISIT = 3` | 第 4 轮 CRT 附近出现 18 个钟 |
| `BROKEN_CLOCK_VISIT = 4` | 第 5 轮半钟，缺失手写数字仅在 X-ray 框内显示；新增 12 台厚背 CRT（8 台下沉、4 台嵌墙），与主教学屏共 13 路同视频错峰循环；首次到房间中心触发 2 秒全黑、6 秒全红与雪花声，黑闪 0.18 秒后恢复 |

第二、三轮操作开关会结束当前轮自动灯光异常；第五轮 CRT 事件期间开关不改变原灯光状态。第五轮在入口锁定后进入房间局部原点水平半径 0.65 米时触发，开始即保存 `basement_crt_event_played`，读档或再次经过不重播。暂停冻结视频、事件时钟和雪花声，换场恢复灯光与屏幕。位置、时序与验证见 [第五回 CRT 说明](2026-10-14-crt-revision.md)。出口小桌的花瓶/书由 `decoration_seed` 与轮次决定，同一存档保持一致。脚步组件为 [carpet_footsteps.gd](../scripts/world/carpet_footsteps.gd)，按实际移动距离播放地毯录音。

三个出口箭头 `XRAY_EXIT_GUIDE_01…03` 和缺失钟数字使用第 20 渲染层，普通相机排除该层。[chapter_xray_view.gd](../scripts/world/chapter_xray_view.gd) 同步主相机，将内容送入现有双手框选窗口。需要有效摄像头手势；失手、关闭摄像头、手机/设置、门过场和离开地下室均隐藏，载入后重新获取手势。普通摄像头画面不能直接显示提示。

## 源资产与本地视频

原 Blender 保存在 [source_assets/blender_basement_loop_v2](../source_assets/blender_basement_loop_v2/README.md)：`Basement_Loop_v2.blend`、`Opening_WhiteDoor_v2.blend` 和独立集合资产可继续编辑。游戏实际加载 [assets/chapter1](../assets/chapter1/) 中的 GLB。本轮楼梯顶修补、家具调整、异常与门距由运行时代码处理，未回写原 Blender；源文件中的旧门距或旧流程说明不能覆盖当前实现。

更换 GLB 时保留 [asset_contract.json](../assets/chapter1/asset_contract.json) 约定的门轴、锚点、碰撞、独立屏幕与 X-ray 标记，移动物件时同步检查碰撞。保留已确认长方形房型、左侧楼梯、隔墙右通道和左后方出口。正常画面没有地面红色路线。

`ChapterVideoScreen` 绑定独立 4:3 屏幕和 0–1 UV；接口见 [chapter_video_screen.gd](../scripts/world/chapter_video_screen.gd)：

~~~gdscript
video_screen.set_stream(user_video_stream) # VideoStream；绑定不自动播放
video_screen.play()
~~~

`stop()` 或未启用循环时自然结束恢复教学画面，没有会话时恢复绿色待机。`power_off()` 停止播放、黑屏并熄灭局部绿光；`power_on()` 恢复教学/待机，不自动播放。`set_standby_color(color)` 配置待机色。信号包括 `power_changed(powered_on)`、`playback_finished`、`playback_failed(reason)` 和 `playback_stopped`；空资源播放返回 false，并报告 `no_stream`。

第五回已接入用户提供的 `D:/aphasia/b5ff65f406555ac661be3f3ea2a68bbc.mp4`，保留原件，游戏使用完整静音转换文件 [basement_crt_loop.ogv](../assets/video/basement_crt_loop.ogv)。13 路播放采用 1.73 秒间隔的不同起点循环；主教学 CRT 在打开教学 GUI 时让出显示面，退出后恢复视频。Godot 4.6.3 已验证真实 Theora 解码、偏移、循环和暂停，并完成正常/黑屏/红屏/恢复的场景截图。红屏六秒使用 DiArchangeli 的 CC0 电视雪花声，来源和 SHA-256 见 [声音许可记录](../assets/audio/sfx/tv_static_SOURCE.md)；完整说明见 [第五回 CRT 说明](2026-10-14-crt-revision.md)。

敲门录音来源与公有领域许可保存在 [opening_door_knock.LICENSE.txt](../assets/audio/sfx/opening_door_knock.LICENSE.txt)；地毯脚步来源、CC0 许可和剪辑记录保存在 [assets/audio/foley](../assets/audio/foley/)。文字主稿及任务动机笔记在 [docs/narrative](narrative/README.md)，原企划、流程 Word 和草图在 [docs/design_originals](design_originals/)。

## 2026-10-13 旁白与耳语接入

开场旁白使用用户选定的 03 六个单音，音高保持原样；[chapter_narration_blips.gd](../scripts/audio/chapter_narration_blips.gd) 按约 130ms 的基础字节奏播放、标点停顿。整句显示与单击推进规则不变。每帧刷新不重播，换句、隐藏、设置、失焦或退树会丢弃当前句剩余声音。两种声音都走 Master 音量。

第二轮地下室使用 D 原始六单音重排成精确 8 秒 WAV，PCM16 / 44.1kHz，无损导入、不循环。耳语在耳边播放，音量为 -11dB；灯光继续沿用已有闪烁模式。主机在手机、设置、失焦、CRT、门过场统一冻结音频和闪灯时间。开关可提前取消；正常结束恢复亮灯。`basement_whisper_played` 在开始时自动保存，读取已触发存档不重播，旧存档缺失字段按未触发处理。门内下一房间预览不会开始事件。

资源及来源见 [assets/audio/dialogue](../assets/audio/dialogue/README.md)。接入前两份可回溯源码备份及逐文件哈希位于外层工作区 `本地备份/2026-10-13-旁白耳语接入前/`。普通角色对白的女性/中性新音色仍处于试听阶段。

本轮 Godot 4.6.3 headless 验证通过：`test_chapter_narration_blips.gd`、`test_basement_atmosphere.gd`、`test_basement_loop_director.gd`、`test_opening_door_flow.gd`、`test_chapter_world.gd` 和新增 `test_chapter_voice_integration.gd`（生产主场景/GLB，36 项检查）。最后一项覆盖实际入口跨越、事件转发、开始自动存档、手机/设置/失焦/CRT 暂停、自然结束、主菜单退出与 Continue 不重播。测试保存路径隔离到 `/private/tmp`。`test_chapter_world` 首次并发运行敲门结束时间断言失败，串行复测通过；不是手动完整通关或耳机混音验收。日志仍有本机 CA 证书和部分主场景退出资源诊断；资产导入成功，但沙盒不允许保存 Godot 安装目录中的编辑器个人设置。

## 存档与验证边界

状态版本保持 5。`chapter1_progress` 保存阶段、轮次、旁白编号 `opening_line_number`、旁白与敲门完成状态、入口锁定、任务完成、手机拾取状态 `phone_collected`、两款 App、转换令牌和陈设种子。首次键盘提示状态 `dialogue_typing_hint_seen` 保存于游戏状态。继续游戏恢复当前旁白编号。已听完敲门不重播，未听完且已到 28 则黑场结束后重播录音；1 至 26 不因载入或等待自动响起。没有旁白编号的旧存档在敲门已完成时兼容为旁白已完成。旧权限只依据连续有效任务迁移；隐藏物品使用独立字段。旧活动 babel 窗口转为 social，旧资金与行动限制清理，旧隧道存档恢复到安全入口。

主菜单调用 `start_chapter1_game()`；`new_game()` 保留给旧路线测试与预览，不能用它代表普通新游戏。没有 `chapter1_progress` 的旧存档继续原塔层路线。

主要验证入口为状态与权限 `test_revision_progression.gd`，UI `test_ui_revision_regressions.gd`，拖字与重绘 `test_word_physics_canvas.gd`/`test_notebook_canvas_reload.gd`，五轮投稿交付 `test_chapter_terminal_flow.gd`，单线键盘对话 `test_linear_dialogue_flow.gd`，实体手机 `test_chapter_tutorial_world.gd`，普通门连接 `test_chapter_tunnel_flow.gd`，开场 `test_opening_door_flow.gd`，镜头 `test_chapter_camera_revision.gd`。部分文件沿用历史名称，旧每日预算断言不是当前规格。

历史合并清单与渲染证据见 [合并交接目录](handoff/2026-10-10/)，不沿用旧截图哈希宣称本轮验证。2026-10-14 用户视频真实解码、13 路错峰循环、中心事件与存档回归已验证，命令及本轮截图见 [第五回 CRT 说明](2026-10-14-crt-revision.md)。真实摄像头、Windows 系统键和耳机混音仍需实机体验；部分主场景自动化退出仍有 RID/ObjectDB 清理诊断。
