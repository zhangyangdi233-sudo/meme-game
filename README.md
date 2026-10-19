# Aphasia / Babel Meme Game

Godot 4.6 心理恐怖游戏。玩家在重复的地下室中拾字、组句、投稿，再把本轮投稿交给 NPC；语言规则和房间异常逐渐改变体验。

**当前说明更新于 2026-10-19。** 以 [本轮实现与测试入口](docs/2026-10-19-xray-onboarding.md) 和 [当前流程](GAME_FLOW_MEMORY.md) 为准。本轮扩建第二层住宅迷宫、接入手指 X-ray 双层地图与隐道、支持边走边看手机，新增首次地下室 CRT 教学，修复三语对白与末句结束按钮、NPC 受光投影。白门中文原稿和角色名“埃弥亣 / エミダー”保留，直接对应日语与英文。[2026-10-16 交接](docs/handoff/2026-10-16/README.md) 及更早文档作为历史资料。

## 后续工作分支

当前发布分支为 `codex/floor-two-maze-mouse-fix-20261016`，承接 `codex/chapter1-text-20261013` 的 `a5ad585`、`codex/chapter1-tunnel-handoff-20261009` 的 `42a6c78` 及后续修改。第一章内容以 2026-10-13 版为基准；后续以新分支为准，历史提交继续保留。

Windows 本机工程为 `D:\aphasia\meme-game`，双击父目录的 `启动游戏.cmd` 即启动此工程。项目协作约定见 [AGENTS.md](AGENTS.md)。

首次CRT按F闪退、取消上方光束、居中放大的操作引导和厚毛毯脚步音效的修订及真实渲染验证见 [本轮修订](docs/2026-10-19-crt-lighting-audio-followup.md)。

当晚最新修订：第二层改为无 NPC 的地图入场解锁与住宅隐道；加入红字纸条，调整 CRT 提示安全区和规则投稿反馈，清理路口横杆灯与假门。见 [当前结果、研究与测试证据](docs/2026-10-19-floor-two-final-revision.md)。

直接测试第二层：双击 `D:\aphasia\启动第二章.cmd`。进入独立测试存档的教学起点；标题结束后，镜头和移动短暂固定，手机自动滑出，地图图标由灰变亮解锁。第二层已移除全部 NPC，原寻路人位置留下红字纸条，靠近按 F 阅读，关闭后消失。WASD 行走，Tab 收放手机，手机外按住右键转向，Esc 设置摄像头和语言。

## 当前玩法

1. 开场全黑 2 秒，之后显出黑水、29.5 米外的白光门与第一句旁白。鼠标或触摸板每点击一次推进一句，原稿第 28 条出现时才敲门；第 27 条是音效说明，不显示为字幕。第 30 条再点击后结束旁白，中文和日语均遵循相同顺序。旁白与完整敲门录音均结束后，靠近按 F，镜头随门开启向内推进，经短淡黑进入地下室。
2. 地下室共五轮。首次先在小桌上按 F 拾取实体手机。每轮在真实 CRT 屏幕内浏览帖子、拾字、组句、投稿，然后退出屏幕，与当前 NPC 完成固定键盘对白并自然交付本轮投稿。主角台词通过打字推进，无回答选项；已有字可以反复使用。
3. 第 1 轮解锁手机“信号瀑布”，第 3 轮解锁“笔记本”。第 2、4、5 轮仍需交付，第 5 轮不再授予新 App。
4. 交付后靠近左后方普通出口门按 F。门开时镜头持续推进，前四轮衔接下一轮楼梯入口；第五轮门内呈现真实十字路口视图，并进入该空间。循环没有黑隧道、白光门或白闪。
5. 空旷十字路口的远门核验五轮完成与两款 App 权限，开门穿过后进入第二层。到达新楼层显示约 2.6 秒的大号无衬线标题，仍能看见世界画面。
6. 第二层保留起伏地形，高低住宅组成25×25格、主路约720米的迷宫。地图在入场演出后自动解锁，实时标记位置并保存已探索区域。两处隐道外观与旁边住宅相同，实际可穿行；用双手围框依次发现这两处住宅隐道和 X-ray 独有的白光出口，随后靠近出口按 F 进入第三层。此场景与第二回地下室不同。

资金、每日行动限制、巴别塔 App、资源栏、自动播放和历史入口已移除。污染继续在后台影响语言和后续楼层，玩家界面不显示数值；后续推进在有效交互完成时检查。旧版隐藏物品与应用权限分别保存，不互相替代。

手机从右侧滑入，裂纹覆盖各 App 内容。笔记本字块松手后继续参与物理模拟，选词条可排序并直接发布；发布句子进入信号瀑布。CRT 与手机共享字库、句子、规则和保存位置。设置支持中、英、日切换，全局 VHS 与 CRT 局部 VHS 独立控制。

## 房间变化

| 轮次 | 当前异常 |
| --- | --- |
| 1 | 正常灯光、单个墙钟 |
| 2 | 入口锁住 2.5 秒后，耳语与闪灯持续 8 秒，然后停止声音、恢复亮灯 |
| 3 | 进屋后停电，可在墙上开关按 F 重新开灯；CRT 绿光保留 |
| 4 | CRT 附近出现 18 个钟组成的钟墙 |
| 5 | 半边墙钟及 X-ray 隐藏数字；13 台厚背 CRT 错峰循环用户视频。首次走到中心：全黑 2 秒、全红 6 秒并播放 CC0 雪花声，黑闪 0.18 秒后恢复，保存后不重复 |

每轮出口小桌出现花瓶或书，随每局种子变化，同一存档保持一致。三个 X-ray 出口箭头继续保留，普通画面不可见。

## 启动与操作

主场景为 `res://scenes/babel_meme_game.tscn`。在 Godot 4.6.3 导入仓库根的 `project.godot`，或在本机 PowerShell 运行：

~~~powershell
& 'D:\aphasia\Start-Aphasia.ps1'
# 独立开发存档，F9 显示开发面板：
& 'D:\aphasia\Start-Chapter1-Dev.ps1'
# 直接体验第二层，使用独立预览存档并播放地图解锁演出：
& 'D:\aphasia\Start-FloorTwoPreview.ps1'
~~~

WASD/方向键移动，鼠标转向，F 交互，拾取手机后 Tab 开关手机或退出 CRT，Esc/F10 打开设置；NPC 主角台词用键盘推进。设置、弹窗、失焦与过场暂停相关交互和探索；返回主菜单取消当前流程。Win/Alt-Tab 失焦释放鼠标，返回后点击游戏恢复视角。CRT 需靠近才能进入，进出均有缓动镜头。启动器副本、其他电脑配置和预览说明见 [Windows 启动说明](support/windows_workspace/README.md)。

## 继续制作

| 工作 | 入口 |
| --- | --- |
| 五轮状态、权限与旧存档 | [meme_game_state.gd](scripts/meme_game_state.gd)、[basement_loop_director.gd](scripts/progression/basement_loop_director.gd) |
| 场景、门和十字路口连接 | [chapter_world.gd](scripts/world/chapter_world.gd)、[chapter_door_transition.gd](scripts/world/chapter_door_transition.gd) |
| 灯、钟、陈设和材质修补 | [basement_atmosphere.gd](scripts/world/basement_atmosphere.gd) |
| UI、CRT 和字词物理 | [babel_meme_game.gd](scripts/babel_meme_game.gd)、[chapter_terminal_session.gd](scripts/ui/chapter_terminal_session.gd)、[word_physics_canvas.gd](scripts/ui/word_physics_canvas.gd) |
| 正式任务与视频接入 API | [第一章接入说明](docs/chapter1-integration.md) |
| 第二层布局、地图与任务 | [第二层设计](docs/2026-10-16-floor-two-maze-design.md)、[空间实现](docs/2026-10-16-floor-two-residential-build.md) |
| 第五回视频与红屏事件 | [CRT 说明](docs/2026-10-14-crt-revision.md) |
| 可编辑 Blender 源文件 | [source_assets/blender_basement_loop_v2](source_assets/blender_basement_loop_v2/README.md) |
| 当前中文修改稿与回填定位 | [docs/text_review/2026-10-13](docs/text_review/2026-10-13/)；保留编号，仅修改中文 |
| 历史文字创作与接入笔记 | [docs/narrative](docs/narrative/README.md) |
| 原企划、流程原稿与房型草图 | [docs/design_originals](docs/design_originals/) |

原 Blender、GLB、旧文档和文字稿均保留。本轮房间修补、住宅迷宫和异常由运行时代码生成；游戏画面不能视为已经回写到 Blender 的版本。[手机源模型](source_assets/phone/README.md) 可独立重建。换模型时保留门轴、碰撞、锚点、独立 4:3 屏幕 UV 和 X-ray 标记，并同步 [资产合同](assets/chapter1/asset_contract.json)。五轮沿用已有角色贴图和对话，正式新任务正文仍待接入；用户视频已接入第五回全部 13 台 CRT。

## 验证和声音来源

本轮验收入口、结果边界与资源来源见 [2026-10-16 交付说明](docs/handoff/2026-10-16/README.md)。`tools/verify_basement_revision.py` 包含 52 个回归脚本，自动隔离存档并将日志写入被 Git 忽略的 `artifacts/revision-final/`。其中 tunnel 测试文件名是历史名称，当前验证普通门接续。

~~~powershell
# 在克隆仓库根执行，Godot 参数替换为本机安装路径：
python tools/verify_basement_revision.py --godot 'C:\你的工具目录\Godot_v4.6.3-stable_win64_console.exe'
~~~

用户视频已通过 Godot 实际解码、循环与暂停验证。真实摄像头识别、Windows 系统键和耳机混音仍需实机体验；部分主场景测试退出时仍有 RID/ObjectDB 清理诊断。第一章保留两款 App，地图是第二层入场演出解锁的第三款，不能套用旧版巴别塔 App 的规格。

背景乐保留本地合成的 96 秒循环，生成与校验入口为 `tools/generate_music_stems.py`；本轮播放音量降低 5 dB。地毯脚步按用户最终选择恢复为A原实录（Mihacappy，CC0），普通行走约0.59秒一步，来源和许可见 [assets/audio/foley](assets/audio/foley/)，敲门许可见 [opening_door_knock.LICENSE.txt](assets/audio/sfx/opening_door_knock.LICENSE.txt)。研究出处见 [reference-research.md](docs/handoff/2026-10-10/reference-research.md)。RichTextLabel2 插件的 MIT 许可保存在 [addons/richtext2/LICENSE](addons/richtext2/LICENSE)。

第五回雪花声的 CC0 来源见 [tv_static_SOURCE.md](assets/audio/sfx/tv_static_SOURCE.md)，用户视频的转换记录见 [basement_crt_loop_SOURCE.md](assets/video/basement_crt_loop_SOURCE.md)。[地图方案比较与 Promesa 视觉分析](docs/references/2026-10-16/README.md) 已随仓库保存；官方参考图片、研究用插件源码、用户存档与本机工具不在发布内容中。
