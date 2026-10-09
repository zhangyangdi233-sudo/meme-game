# 第一章接入与运行

更新：2026-10-10。当前路线为黑水白门开场、五轮地下室、空旷十字路口、第二层。最新说明和验证资料汇入 [2026-10-10 合并交接目录](handoff/2026-10-10/)；[2026-10-09](handoff/2026-10-09/README.md) 及更早文档保留作历史。旧隧道、三 App、资金与每日行动预算不再是当前流程。

## 启动与游玩

本机普通启动使用 `D:/aphasia/Start-Aphasia.ps1`，独立开发验证使用：

~~~powershell
& 'D:\aphasia\Start-Chapter1-Dev.ps1'
~~~

开发启动器使用 Godot 4.6.3 和 `--chapter1-dev`，将存档与偏好隔离到 `D:/aphasia/outputs/chapter1_development/profile`，日志写入同目录上一级的 `chapter1_latest.log`。在主菜单选择新游戏开始；其他电脑配置见 [Windows 启动说明](../support/windows_workspace/README.md)。

| 操作 | 入口 |
| --- | --- |
| 移动与转向 | WASD/方向键、鼠标；点击世界恢复鼠标视角 |
| 交互 | 靠近目标按 F |
| 手机、退出 CRT | Tab；开场不能打开手机 |
| 设置 | Esc/F10，包括开门与 CRT 镜头期间 |
| 返回主菜单 | 设置底部按钮，取消当前声音和过场 |
| 开发面板 | F9，仅开发模式；显示时释放鼠标 |

Win/Alt-Tab 失焦释放鼠标。设置暂停开场计时、敲门、门和 CRT 镜头，关闭后继续；返回主菜单不留下旧场景推进回调。

1. **开场。** 全黑 2 秒，初始门距 29.5 米，正常步速约 8–9 秒路程。有效计时到 6.5 秒开始敲门，计时包含最初黑场。完整录音约 6.243 秒；听完并靠近后按 F，镜头随慢开门向内推进，经短淡黑进入地下室。无需自行穿门。
2. **每轮教程。** 从楼梯顶安全平台进入，跨过入口后身后门锁住。下楼，在 CRT 内拾字、组句、投稿；退出屏幕，靠近本轮 NPC，点击“交付本轮投稿”。必须是本轮成功的非空自由组句投稿，已有字可以反复用。
3. **普通出口。** 交付后靠近左后方门按 F，门开时镜头持续推进。前四轮门后衔接下一轮入口；第五轮使用真实十字路口场景的 portal 视图，进入十字路口。循环不再生成 12 米隧道、白光门或白闪，也不使用开场淡黑。
4. **手机与远门。** 第 1、3 轮分别解锁信号瀑布和笔记本；第 2、4、5 轮没有新增 App，但仍须交付。十字路口无人，远门检查五轮完成与两款 App 权限，按 F 开门并穿过后进入第二层。
5. **后续推进。** 资金与每日行动限制已移除；污染在后台影响语言、规则和楼层，玩家界面不显示数值。有效交互完成时检查推进。到达新楼层显示约 2.6 秒无衬线大标题，世界画面保留。

五轮沿用护灯人、迟到者、回声住户、抄写员、无名信徒的贴图与原对话。章节角色 `basement_npc_01…05`、任务 `basement_help_01…05` 与原 `source_actor_id/type` 分开；正式新任务正文仍待接入。护灯人对话中的第一层隐藏线索可独立显形和领取，不完成教程，也不授予 App。

## 正式任务与流程 API

主场景提供 `notify_chapter1(event_id, payload)`，返回 `{accepted, progress, transition}`。阶段状态由 [basement_loop_director.gd](../scripts/progression/basement_loop_director.gd) 校验，宿主实现位于 [babel_meme_game.gd](../scripts/babel_meme_game.gd)。

| 事件 | 参数与可信发送时机 |
| --- | --- |
| `narration_completed` | `{"sequence_id": "chapter1_opening"}`；只记录旁白完成，不解锁开场白门 |
| `opening_knock_completed` | 同上；由开场世界在完整敲门结束后发送 |
| `opening_door_opened` | 开场门过场到达房间切换回调后发送，进入地下室 |
| `entrance_threshold_crossed` | `{"round_token": captured_round_token}`；越过本轮安全入口后发送 |
| `npc_help_completed` | 当前 NPC、任务及捕获的令牌；正式任务系统确认完成后发送 |
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

手机两款 App 初始锁定；CRT 第一轮即提供教学功能。手机入口、恢复窗口和编辑回调均检查权限。靠近屏幕才可进入，镜头约 0.8 秒推进、0.65 秒退回；镜头移动时不接受屏幕操作。设置取消屏内按下/拖拽状态，不误触按钮；返回主菜单或换场先恢复控件再释放会话。

正文和可拾字使用相同继承字号。CRT 内容基准 36px，字距增加 1px、行距 6px；字块按文字实际宽度配置碰撞。字块拖放由 [word_physics_canvas.gd](../scripts/ui/word_physics_canvas.gd) 处理，松手后恢复物理；坐标按实际画布保存，重绘与 CRT/手机尺寸变化后保持可用。滚轮加快，底部投稿按钮保留在显示范围内。

中、英、日设置可实时切换；全局 VHS 与 CRT 局部 VHS 分开保存。局部效果使用屏幕材质纹理，不采样整屏。资源栏、巴别塔 App、自动播放和历史入口已退役。

## 灯光、房间异常与 X-ray

[basement_atmosphere.gd](../scripts/world/basement_atmosphere.gd) 集中处理本轮运行时修补、家具、墙纸、地毯、灯具、开关和钟。顶部轮次常量从 0 计数：

| 常量/轮次 | 行为 |
| --- | --- |
| 第 1 轮 | 正常灯光和单钟 |
| `FLICKER_VISIT = 1` | 第 2 轮入屋后闪灯约 3.6 秒，随后恢复 |
| `BLACKOUT_VISIT = 2` | 第 3 轮入屋后停电，墙上开关按 F 可恢复；CRT 绿光保留 |
| `CLOCK_WALL_VISIT = 3` | 第 4 轮 CRT 附近出现 18 个钟 |
| `BROKEN_CLOCK_VISIT = 4` | 第 5 轮半钟，缺失手写数字仅在 X-ray 框内显示 |

操作开关会结束当前轮自动灯光异常。出口小桌的花瓶/书由 `decoration_seed` 与轮次决定，同一存档保持一致。脚步组件为 [carpet_footsteps.gd](../scripts/world/carpet_footsteps.gd)，按实际移动距离播放地毯录音。

三个出口箭头 `XRAY_EXIT_GUIDE_01…03` 和缺失钟数字使用第 20 渲染层，普通相机排除该层。[chapter_xray_view.gd](../scripts/world/chapter_xray_view.gd) 同步主相机，将内容送入现有双手框选窗口。需要有效摄像头手势；失手、关闭摄像头、手机/设置、门过场和离开地下室均隐藏，载入后重新获取手势。普通摄像头画面不能直接显示提示。

## 源资产与本地视频

原 Blender 保存在 [source_assets/blender_basement_loop_v2](../source_assets/blender_basement_loop_v2/README.md)：`Basement_Loop_v2.blend`、`Opening_WhiteDoor_v2.blend` 和独立集合资产可继续编辑。游戏实际加载 [assets/chapter1](../assets/chapter1/) 中的 GLB。本轮楼梯顶修补、家具调整、异常与门距由运行时代码处理，未回写原 Blender；源文件中的旧门距或旧流程说明不能覆盖当前实现。

更换 GLB 时保留 [asset_contract.json](../assets/chapter1/asset_contract.json) 约定的门轴、锚点、碰撞、独立屏幕与 X-ray 标记，移动物件时同步检查碰撞。保留已确认长方形房型、左侧楼梯、隔墙右通道和左后方出口。正常画面没有地面红色路线。

`ChapterVideoScreen` 绑定独立 4:3 屏幕和 0–1 UV；接口见 [chapter_video_screen.gd](../scripts/world/chapter_video_screen.gd)：

~~~gdscript
video_screen.set_stream(user_video_stream) # VideoStream；绑定不自动播放
video_screen.play()
~~~

`stop()` 或自然结束恢复教学画面，没有会话时恢复绿色待机。`power_off()` 停止播放、黑屏并熄灭局部绿光；`power_on()` 恢复教学/待机，不自动播放。`set_standby_color(color)` 配置待机色。信号包括 `power_changed(powered_on)`、`playback_finished`、`playback_failed(reason)` 和 `playback_stopped`；空资源播放返回 false，并报告 `no_stream`。目前没有用户视频，不能据合成测试声称真实解码已验证。

敲门录音来源与公有领域许可保存在 [opening_door_knock.LICENSE.txt](../assets/audio/sfx/opening_door_knock.LICENSE.txt)；地毯脚步来源、CC0 许可和剪辑记录保存在 [assets/audio/foley](../assets/audio/foley/)。文字主稿及任务动机笔记在 [docs/narrative](narrative/README.md)，原企划、流程 Word 和草图在 [docs/design_originals](design_originals/)。

## 存档与验证边界

状态版本保持 5。`chapter1_progress` 保存阶段、轮次、敲门完成、入口锁定、任务完成、两款 App、转换令牌和陈设种子。旧权限只依据连续有效任务迁移；隐藏物品使用独立字段。旧活动 babel 窗口转为 social，旧资金与行动限制清理，旧隧道存档恢复到安全入口。已听完敲门不重播，未听完则重新开始当前开场计时。

主菜单调用 `start_chapter1_game()`；`new_game()` 保留给旧路线测试与预览，不能用它代表普通新游戏。没有 `chapter1_progress` 的旧存档继续原塔层路线。

主要验证入口为状态与权限 `test_revision_progression.gd`，UI `test_ui_revision_regressions.gd`，拖字与重绘 `test_word_physics_canvas.gd`/`test_notebook_canvas_reload.gd`，五轮投稿交付 `test_chapter_terminal_flow.gd`，普通门连接 `test_chapter_tunnel_flow.gd`，开场 `test_opening_door_flow.gd`，镜头 `test_chapter_camera_revision.gd`。部分文件沿用历史名称，旧每日预算断言不是当前规格。

最新执行清单与渲染证据见 [合并交接目录](handoff/2026-10-10/)，不沿用旧截图哈希宣称本轮验证。真实摄像头、用户视频解码、Windows 系统键和耳机混音仍需实机体验；部分主场景自动化退出仍有 RID/ObjectDB 清理诊断。
