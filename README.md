# Aphasia / Babel Meme Game

Godot 4.6 心理恐怖游戏。玩家在重复的地下室中拾字、组句、投稿，再把本轮投稿交给 NPC；语言规则和房间异常逐渐改变体验。

**当前说明更新于 2026-10-10。** 以 [合并交接目录](docs/handoff/2026-10-10/)、[当前流程](GAME_FLOW_MEMORY.md) 和 [第一章接入说明](docs/chapter1-integration.md) 为准。[2026-10-09 交接](docs/handoff/2026-10-09/README.md) 与更早文档保留作历史资料，其中隧道、三款 App、资金和每日行动的描述已被取代。

## 当前玩法

1. 开场全黑 2 秒，之后显出黑水和较暗的白光门。初始门距为 29.5 米，正常步速约 8–9 秒路程；开场有效计时到 6.5 秒时开始敲门，完整录音约 6.243 秒。听完并靠近后按 F，镜头随门开启向内推进，经短淡黑进入地下室。
2. 地下室共五轮。每轮下楼，在真实 CRT 屏幕内浏览帖子、拾字、组句、投稿，然后退出屏幕，向当前 NPC 交付本轮成功投稿。已有字可以反复使用。
3. 第 1 轮解锁手机“信号瀑布”，第 3 轮解锁“笔记本”。第 2、4、5 轮仍需交付，第 5 轮不再授予新 App。
4. 交付后靠近左后方普通出口门按 F。门开时镜头持续推进，前四轮衔接下一轮楼梯入口；第五轮门内呈现真实十字路口视图，并进入该空间。循环没有黑隧道、白光门或白闪。
5. 空旷十字路口的远门核验五轮完成与两款 App 权限，开门穿过后进入第二层。到达新楼层显示约 2.6 秒的大号无衬线标题，仍能看见世界画面。

资金、每日行动限制、巴别塔 App、资源栏、自动播放和历史入口已移除。污染继续在后台影响语言和后续楼层，玩家界面不显示数值；后续推进在有效交互完成时检查。旧版隐藏物品与应用权限分别保存，不互相替代。

笔记本字块松手后从当前位置继续参与物理模拟；CRT 与手机共享字库、句子、规则和保存位置。拾字高亮与正文同字号，滚轮已加快。设置支持中、英、日切换，全局 VHS 与 CRT 局部 VHS 独立控制。

## 房间变化

| 轮次 | 当前异常 |
| --- | --- |
| 1 | 正常灯光、单个墙钟 |
| 2 | 进屋后短暂闪灯约 3.6 秒，然后恢复 |
| 3 | 进屋后停电，可在墙上开关按 F 重新开灯；CRT 绿光保留 |
| 4 | CRT 附近出现 18 个钟组成的钟墙 |
| 5 | 墙钟缺半边，缺失的手写数字只在手势 X-ray 窗口内显示 |

每轮出口小桌出现花瓶或书，随每局种子变化，同一存档保持一致。三个 X-ray 出口箭头继续保留，普通画面不可见。

## 启动与操作

主场景为 `res://scenes/babel_meme_game.tscn`。在 Godot 4.6.3 导入仓库根的 `project.godot`，或在本机 PowerShell 运行：

~~~powershell
& 'D:\aphasia\Start-Aphasia.ps1'
# 独立开发存档，F9 显示开发面板：
& 'D:\aphasia\Start-Chapter1-Dev.ps1'
~~~

WASD/方向键移动，鼠标转向，F 交互，Tab 开关手机或退出 CRT，Esc/F10 打开设置。设置暂停开场计时、敲门及门/CRT 镜头；返回主菜单取消当前流程。Win/Alt-Tab 失焦释放鼠标，返回后点击游戏恢复视角。CRT 需靠近才能进入，进出均有缓动镜头。其他电脑配置见 [Windows 启动说明](support/windows_workspace/README.md)。

## 继续制作

| 工作 | 入口 |
| --- | --- |
| 五轮状态、权限与旧存档 | [meme_game_state.gd](scripts/meme_game_state.gd)、[basement_loop_director.gd](scripts/progression/basement_loop_director.gd) |
| 场景、门和十字路口连接 | [chapter_world.gd](scripts/world/chapter_world.gd)、[chapter_door_transition.gd](scripts/world/chapter_door_transition.gd) |
| 灯、钟、陈设和材质修补 | [basement_atmosphere.gd](scripts/world/basement_atmosphere.gd) |
| UI、CRT 和字词物理 | [babel_meme_game.gd](scripts/babel_meme_game.gd)、[chapter_terminal_session.gd](scripts/ui/chapter_terminal_session.gd)、[word_physics_canvas.gd](scripts/ui/word_physics_canvas.gd) |
| 正式任务与视频接入 API | [第一章接入说明](docs/chapter1-integration.md) |
| 可编辑 Blender 源文件 | [source_assets/blender_basement_loop_v2](source_assets/blender_basement_loop_v2/README.md) |
| 文字主稿与接入笔记 | [docs/narrative](docs/narrative/README.md) |
| 原企划、流程原稿与房型草图 | [docs/design_originals](docs/design_originals/) |

原 Blender、GLB、旧文档和文字稿均保留。本轮房间修补、陈设和异常由运行时代码生成；游戏画面不能视为已经回写到 Blender 的版本。换模型时保留门轴、碰撞、锚点、独立 4:3 屏幕 UV 和 X-ray 标记，并同步 [资产合同](assets/chapter1/asset_contract.json)。五轮沿用已有角色贴图和对话，正式新任务正文与用户视频仍待接入。

## 验证和声音来源

当前验证记录与渲染证据汇入 [2026-10-10 交接目录](docs/handoff/2026-10-10/)。主要回归入口为 `test_revision_progression.gd`、`test_ui_revision_regressions.gd`、`test_notebook_canvas_reload.gd`、`test_word_physics_canvas.gd`、`test_chapter_terminal_flow.gd`、`test_chapter_tunnel_flow.gd` 和 `test_opening_door_flow.gd`；其中 tunnel 测试文件名是历史名称，当前验证普通门接续。

~~~powershell
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --log-file 'D:\aphasia\meme-game\artifacts\revision_progression.log' --script res://tests/test_revision_progression.gd
~~~

真实摄像头识别、用户视频解码、Windows 系统键和耳机混音仍需实机体验；部分主场景测试退出时仍有 RID/ObjectDB 清理诊断。旧测试中的每日预算或三 App 断言不能作为现行规格。

背景乐保留本地合成的 96 秒循环，生成与校验入口为 `tools/generate_music_stems.py`；本轮播放音量降低 5 dB。新增地毯实录脚步来源和许可见 [assets/audio/foley](assets/audio/foley/)，敲门许可见 [opening_door_knock.LICENSE.txt](assets/audio/sfx/opening_door_knock.LICENSE.txt)。研究出处见 [reference-research.md](docs/handoff/2026-10-10/reference-research.md)。RichTextLabel2 插件的 MIT 许可保存在 [addons/richtext2/LICENSE](addons/richtext2/LICENSE)。
