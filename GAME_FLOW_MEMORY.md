# Aphasia 当前游戏流程记忆

更新：2026-10-10（Asia/Tokyo）。本文件与 [合并交接目录](/D:/aphasia/meme-game/docs/handoff/2026-10-10/) 记录当前实现。[2026-10-09 交接](/D:/aphasia/meme-game/docs/handoff/2026-10-09/README.md)、旧 Word 与源资产附带说明保留作历史；冲突时以本版为准。原文件未删除。

## 主流程

全黑 2 秒 → 黑水与 29.5 米外白光门 → 开场有效计时到 6.5 秒开始敲门 → 听完约 6.243 秒录音且靠近后按 F → 慢开门、镜头向内推进、短淡黑 → 五轮地下室教程 → 空旷十字路口 → 远门 → 第二层。

门距对应正常步速约 8–9 秒路程；敲门计时包含最初黑场，打开设置会暂停。听完敲门才可开门，不由接近门、旁白或穿过门口直接跳过。已听完的存档不重播；未听完的存档重新开始开场计时。

地下室每轮从楼梯顶安全平台进入，越过入口后身后门关闭并锁住。下楼经 TV 区、右侧通道到后方 NPC，完成当前帮助任务后才能从左后方地面层出口离开。普通出口门开时镜头持续推进，前四轮衔接下一轮楼梯入口；第五轮门内显示真实十字路口视图，随后进入十字路口。循环已取消旧黑隧道、循环白光门和白闪；短淡黑只用于开场。

| 轮次 | 沿用角色 | 手机解锁 |
| --- | --- | --- |
| 1 | 护灯人 | 信号瀑布（social） |
| 2 | 迟到者 | 无新增 App |
| 3 | 回声住户 | 笔记本（notebook） |
| 4 | 抄写员 | 无新增 App |
| 5 | 无名信徒 | 完成后通往十字路口 |

五轮都必须交付本轮成功投稿。十字路口无人，保留原空间与远门；远门核验五轮完成和两款 App 权限。巴别塔 App 已取消。手机权限、五轮任务和三个隐藏结局物品分别保存，不能互相冒充通关条件。

## CRT、字词和后台规则

靠近 CRT 按 F，在真实屏幕内浏览、拾字、组句、投稿；退出屏幕后向当前 NPC 交付。CRT 教学端从第一轮提供信号瀑布和笔记本，手机对应应用在第 1、3 轮交付后解锁。两端共享词库、句子、规则与任务记录，已拾字可反复使用。草稿、旧轮投稿和普通对话不能代替本轮投稿。

资金与每日行动限制已移除，后续楼层也不恢复预算。污染仍在后台影响语言和楼层，在有效交互完成时检查推进；玩家 UI 不显示数值。资源栏、自动播放、历史入口已取消。新楼层到达时显示约 2.6 秒无衬线大标题，世界画面保留。

拾字高亮跟正文同字号。笔记本字块松手后从落点继续掉落、碰撞；重绘保留坐标，切换较小画布时按实际边界收进。CRT 交互距离缩小，进退镜头缓动；中、英、日设置切换保留。CRT 局部 VHS 与全局 VHS 独立设置。

CRT 保留独立 4:3 屏幕网格、0–1 UV 和视频接口，区分教学、绿色待机、播放、关机。当前没有用户视频，不把待机效果描述成已接入剧情视频。

## 房型、美术与异常

房型依据 [原草图](/D:/aphasia/meme-game/docs/design_originals/basement_layout_sketch.jpg)：长方形地下室，楼梯贴左侧；TV 在前区，隔墙右侧留通道，NPC 在后区，出口位于左后方地面层。外部循环由游戏逻辑连接，保留已确认平面布局。

家具、电视柜、画框和扶手以原木为主；绿色用于细纹墙纸、地毯、微绿灯光和 CRT 局部光。原红色动线已取消。当前运行时修补楼梯顶开口与穿插面，校正 NPC 脚底和水平朝向，调整家具比例与位置，增加杂物及墙纸、地毯质感。原 Blender 文件保留，本轮修改没有回写源模型。

| 轮次 | 异常与操作 |
| --- | --- |
| 1 | 正常灯光和一个墙钟 |
| 2 | 进屋后短暂闪灯约 3.6 秒，再自行恢复；操作开关可终止异常 |
| 3 | 进屋后停电，在墙上开关按 F 可重新开灯；CRT 绿光保留 |
| 4 | CRT 附近出现 18 个钟的钟墙 |
| 5 | 半边墙钟；缺失的手写数字只在有效手势 X-ray 框内显示 |
| 每轮 | 出口小桌放花瓶或书；每局种子决定，同一存档稳定 |

三个手绘出口箭头 `XRAY_EXIT_GUIDE_01` 至 `03` 保留，均标记 `xray_only=true`。箭头与缺失钟数字在普通画面不可见；需要摄像头手势形成 X-ray 窗口。失去有效手势、关闭摄像头、打开手机或设置、门过场、离开地下室时隐藏。不能用全屏叠加替代局部 X-ray。

## 操作、保存和制作入口

WASD/方向键移动，鼠标转向，F 交互，Tab 开关手机或退出 CRT，Esc/F10 设置。Win/Alt-Tab 失焦释放鼠标，返回后点击游戏恢复视角。设置暂停开场、敲门和镜头；返回主菜单取消当前流程。开发模式 F9 显示面板，使用独立存档。

旧活动 babel 窗口迁回信号瀑布，旧资金与行动限制清理，旧隧道存档回安全入口。保留并校验已完成任务、已获两款 App、隐藏物品与污染；不能仅伪造单个权限跳关。

- 正式任务事件、视频 API、存档边界：[第一章接入说明](/D:/aphasia/meme-game/docs/chapter1-integration.md)。
- 游戏工程：[project.godot](/D:/aphasia/meme-game/project.godot)；启动器：[Start-Aphasia.ps1](/D:/aphasia/Start-Aphasia.ps1)、[Start-Chapter1-Dev.ps1](/D:/aphasia/Start-Chapter1-Dev.ps1)。
- 状态与权限：[basement_loop_director.gd](/D:/aphasia/meme-game/scripts/progression/basement_loop_director.gd)、[meme_game_state.gd](/D:/aphasia/meme-game/scripts/meme_game_state.gd)。
- 场景和循环：[chapter_world.gd](/D:/aphasia/meme-game/scripts/world/chapter_world.gd)、[chapter_door_transition.gd](/D:/aphasia/meme-game/scripts/world/chapter_door_transition.gd)。
- 灯、钟、材质、家具及异常轮次：[basement_atmosphere.gd](/D:/aphasia/meme-game/scripts/world/basement_atmosphere.gd)。
- 可编辑源资产：[source_assets/blender_basement_loop_v2](/D:/aphasia/meme-game/source_assets/blender_basement_loop_v2/README.md)；游戏加载的 GLB 与合同：[assets/chapter1](/D:/aphasia/meme-game/assets/chapter1/)。
- 文字主稿与接入笔记：[docs/narrative](/D:/aphasia/meme-game/docs/narrative/README.md)；原企划和流程 Word：[docs/design_originals](/D:/aphasia/meme-game/docs/design_originals/)。
- 最新合并说明、证据和研究出处：[2026-10-10 交接目录](/D:/aphasia/meme-game/docs/handoff/2026-10-10/)；更早截图、哈希与测试报告作为历史保留。

五轮沿用已有角色贴图和对话，功能任务与角色来源分开；正式新任务正文和用户视频仍待接入。真实摄像头、视频解码、Windows 系统键及耳机混音需要实机体验；部分自动化退出仍有资源清理诊断。禁止批量删除，单次只允许删除一个明确路径的文件。
