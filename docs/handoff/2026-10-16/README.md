# 2026-10-16 交付：手机、CRT 与第二层住宅迷宫

当前发布分支为 `codex/floor-two-maze-mouse-fix-20261016`，包含此前 `codex/chapter1-text-20261013` 与 `codex/chapter1-tunnel-handoff-20261009` 的历史。后续开发以新分支为准，旧提交继续保留在祖先历史中。

## 本轮行为

- 第一回小桌上的实体手机按 F 拾取，所有权和 App 权限分别保存。手机从右侧滑入，裂纹覆盖各 App；笔记本选词、排序与发布在手机内完成，投稿进入信号瀑布。
- NPC 使用固定键盘对白。主角台词通过有效打字推进，NPC 回复按阅读时长自动衔接，取消、失焦与设置不会推进任务或积压旧回调。
- 第五回有 12 台新增厚背 CRT，加上原教学屏共 13 台，静音错峰循环用户提供的视频。首次进入中心后全黑 2 秒、全红 6 秒并播放 CC0 雪花声，黑闪 0.18 秒后恢复；事件标记及时保存，暂停和换场安全。详见 [CRT 说明](../../2026-10-14-crt-revision.md)。
- 第二层保留起伏地形，中央 13×13、8 米格的住宅街区形成约 256 米路线。住宅取代旧杂物与事件模型；寻路人、两个必经转角、绘图人和出口构成不可绕过的任务顺序。取得地图后按实际移动永久记录探索，旧存档落进房屋会恢复到最近合法道路。详见 [设计](../../2026-10-16-floor-two-maze-design.md) 和 [空间实现](../../2026-10-16-floor-two-residential-build.md)。
- 十字路口和第二层白门恢复原单扇门宽 1.12 米、高 2.25 米。可见门叶厚 0.078 米，碰撞厚 0.08 米；门轴、阻挡和过门范围同步居中。旧漂浮画面、测试提示面板与布偶引导不再出现。

完整当前流程见 [GAME_FLOW_MEMORY.md](../../../GAME_FLOW_MEMORY.md)。用户提供的视频已经接入，不能继续使用旧文档中“视频待接入”的说法。

## 克隆后启动与验收

安装 Godot 4.6.3，导入仓库根 `project.godot`，主场景为 `res://scenes/babel_meme_game.tscn`。Windows 启动器副本及工作区目录要求见 [启动说明](../../../support/windows_workspace/README.md)。`Start-FloorTwoPreview.ps1` 使用独立 profile 直接进入第二层并预先取得地图，适合观察空间；完整任务顺序由正常主场景和集成测试验证。

在仓库根运行完整回归：

```powershell
python tools/verify_basement_revision.py --godot 'C:\你的工具目录\Godot_v4.6.3-stable_win64_console.exe'
```

验收器包含 53 个不重复脚本，路径均已检查存在；每项最长 120 秒，自动将 APPDATA/XDG_DATA_HOME 指向 `artifacts/revision-final/isolated-profile`，保存 `results.json` 和逐项日志。可用 `--tests test_mouse_look_input test_crossroads_white_gate test_floor_two_map_flow` 只运行相关检查。

本轮已取得的证据：

- 白门比例、鼠标捕获与末句计时最终修正后，完整回归 **53/53** 通过，包括新增的真实帧对白自动结束检查。报告为 `artifacts/revision-final/results.json`，各项使用隔离存档。
- 实际 CharacterBody3D 沿第二层 33 个路点连续走完约 256 米、4,656 个物理步，使用真实重力和碰撞，无路径点瞬移。
- 正常白门专项用与主游戏相同的半径 0.34 米、高 1.72 米胶囊居中走过打开的门；门平面 z=-101，最终 z=-103.4994，恰好触发一次换层；门旁 x=1 米不误触。
- Windows/OpenGL 隐藏窗口的真实 SubViewport 已分别渲染 CRT、十字路口、第二层与主场景。主场景第二层确认旧 Road 几何不可见；门比例最终截图已更新。
- 最终真实 Windows 窗口鼠标回归 **220 项检查通过**：直接核验 ClipCursor、系统光标位置和捕获 HWND；覆盖模式丢失后无输入自愈、游离事件丢弃、持续转向、手机/设置/弹窗、窗口缩放及失焦不抢焦点。受限沙箱下会出现枚举显示捕获但 ClipCursor 未生效，宿主桌面执行则通过，因此可见预览和此项测试必须在正常桌面权限下运行。命令：`python tools/verify_mouse_capture_window.py --godot <Godot路径>`；最终报告为 `artifacts/mouse-capture-window-20261016/final-host`。
- 对话真实帧回归 **25 项检查通过**：实际 F 与打字事件后等待当前回复结束，覆盖两位第二层 NPC、预览中的重复对话、任务奖励及暂停恢复。末句计时已改用当前文本，消除 RicherTextLabel 延迟更新导致的额外等待，无需继续聊天按钮。原线性对话回归 **146 项检查通过**。

对应脚本包括 `test_basement_crt_anomaly.gd`、`test_crossroads_white_gate.gd`、`test_floor_two_walkthrough.gd`、`test_floor_two_map_flow.gd`、`capture_crossroads_white_gate.gd`、`capture_floor_two_maze.gd` 和 `capture_floor_two_main.gd`。截图脚本需要真实图形后端，不应加 `--headless`。本机证据位于 `artifacts/crt-verification`、`artifacts/white-door-proportion-20261016`、`artifacts/floor-two-maze-20261016` 等目录；它们被 Git 忽略，克隆后可通过保存的脚本重新生成。

真实摄像头识别、Windows 系统键和耳机混音仍需实机体验。部分完整主场景测试退出时有既有 RID/ObjectDB 清理诊断；独立生成器与门专项没有此诊断。实际截图与逻辑通过不等于这些外部设备已经验收。

## 随仓库保存与本机保留

- 运行资产：用户视频转换后的 `assets/video/basement_crt_loop.ogv`（1,045,529 字节）、CC0 `tv_static_diarchangeli.ogg`（583,198 字节）、手机 GLB 和图标；保留 Godot 对应导入设置与 UID。
- 可编辑手机源模型、生成/检查脚本和说明保存在 `source_assets/phone`。`.blend` 为 100,822 字节，运行时使用的 GLB 为 19,644 字节。
- 原始 MP4（3,683,345 字节）仍在原工作区 `D:/aphasia/b5ff65f406555ac661be3f3ea2a68bbc.mp4`；游戏运行使用已入仓的 OGV，不依赖此绝对路径。它是用户提供素材，来源记录没有宣称其具有公开许可证。
- [CC0 声音许可记录](../../../assets/audio/sfx/tv_static_SOURCE.md)、[视频转换记录](../../../assets/video/basement_crt_loop_SOURCE.md)、[地图方案和 Promesa 参考快照](../../references/2026-10-16/README.md) 随仓库保存。官方参考图片、研究用插件代码、额外工具和 Python 环境没有被打包。
- `.godot`、`artifacts`、`outputs`、日志、独立测试/预览 profile、用户存档、虚拟环境和常见凭据文件继续由忽略规则排除。本次新增资源体积较小，保持现有普通 Git 文件存储，不另加 LFS 依赖。
