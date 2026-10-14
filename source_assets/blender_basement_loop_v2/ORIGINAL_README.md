# Aphasia 地下室循环 v2

这是按用户确认草图制作的新房型：左侧楼梯入口 → 前方 TV 区 → 右侧通道 → 隔墙后 NPC 区 → 左后方地面出口。净房间约 **6.4 × 8.4 m**，主顶高 **2.75 m**；楼梯平台高 **2.70 m**，楼梯井单独留出净空。

## 打开模型

- [地下室 Blender 源文件](D:/aphasia/outputs/blender_basement_loop_v2/Basement_Loop_v2.blend)：打开后选择场景 `Aphasia_Basement_Loop_v2`。房壳、门、楼梯、灯、家具分开保留。
- [带家具的地下室 GLB](D:/aphasia/outputs/blender_basement_loop_v2/Basement_Loop_v2.glb)：用于游戏接入，含独立门轴、视频屏幕和碰撞代理。
- [纯建筑 GLB](D:/aphasia/outputs/blender_basement_loop_v2/Basement_Architecture_v2.glb)：去掉家具与道具碰撞，保留建筑、门、固定灯具及游戏锚点，适合重新摆设。
- [黑水与白光门 Blender 源文件](D:/aphasia/outputs/blender_basement_loop_v2/Opening_WhiteDoor_v2.blend) / [开场 GLB](D:/aphasia/outputs/blender_basement_loop_v2/Opening_WhiteDoor_v2.glb)：门距离为 **18 m**，门扇和饰板随 `OpeningDoorPivot` 运动，门框及光缝固定。
- [接口与坐标约定](D:/aphasia/outputs/blender_basement_loop_v2/asset_contract.json)：游戏导入、门、锚点及流程的统一依据。

旧版留在 `D:/aphasia/outputs/blender_subliminal`。新草图房型没有覆盖旧版。源文件中可能同时保留参考场景及资产库场景，编辑地下室时认准 `Aphasia_Basement_Loop_v2`。

## 在 Blender 里拖拽资产

主线程已将资产库以 **Aphasia Basement v2** 注册到当前 Blender，11 类资产均已生成缩略图。把任意编辑器切换为 **Asset Browser / 资产浏览器**，在左上角资产库下拉框选这个名称，再打开 `Basement` 目录，直接将资产拖入 3D 视图。

资产库文件：[Basement_All_Props_v2.blend](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/Basement_All_Props_v2.blend)。如果在另一台电脑使用，可在 Blender 的 Preferences → File Paths → Asset Libraries 添加文件夹 `D:/aphasia/outputs/blender_basement_loop_v2/asset_library`；复制到其他位置后添加新位置即可。

每项资产使用米制，底部为 Z=0，正面朝 Blender -Y。移动整件道具时选择其总根节点或集合实例。需要编辑内部零件时，可对集合实例执行 **Make Instances Real / 使实例独立化**，再选择具体网格。场景中的道具可以独立增减；资产库源文件保留为再次拖拽的模板。

**最新美术方向（2026-10-07）：** 按用户三张参考图改为绿色纹理墙纸、微绿室内灯和 CRT 局部绿光。桌椅、电视柜、画框、扶手保持原木，儿童椅也已改木质；木纹与贴纸保留。楼梯顶门边灯已排除。电视角两面墙、完整顶棚都显示，交付预览按室内第一人称视角检查；Blender 工作视角保留用户当前的编辑状态。此前的绿色家具/纯白扶手试稿已放弃，不作为后续方向。

红色地面动线已取消。新的出口提示是 **3 个墙面手绘红箭头**，位于集合 `12_XRay_Hidden_Marks`，根节点 `XRAY_EXIT_GUIDE_01` 至 `03`。它们在 Blender 普通显示与渲染中隐藏，但包含在主 GLB / 建筑 GLB 内，并带 `xray_only=true`，由游戏的摄像头 X-ray 窗口专门显示。普通相机必须排除该层，不能直接把这些导入网格全部显示。具体位置及规则在 `asset_contract.json` 的 `xray_exit_guides` 中。

| 目录 | 资产 | 单独 GLB | 说明 |
|---|---|---|---|
| Furniture | 木电视柜 | [console.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/console.glb) | 标准资产约 1.95 × 0.50 × 0.78 m；地下室中已加深以承托斜放 CRT |
| Furniture | Windsor 木椅 | [chair.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/chair.glb) | 独立椅背、座面与椅脚 |
| Furniture | 窄边桌 | [side_table.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/side_table.glb) | 适合后区或墙边 |
| Furniture | 儿童木桌 | [kids_table.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/kids_table.glb) | 低矮桌面 |
| Furniture | 木质儿童椅 | [kids_chair.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/kids_chair.glb) | 与儿童桌分开拖拽；依用户修订恢复木纹材质 |
| Electronics and Details | 90 年代 CRT 电视 | [crt.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/crt.glb) | 约 0.65 × 0.54 × 0.55 m；独立曲面视频屏幕 |
| Electronics and Details | 墙壁开关 | [switch.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/switch.glb) | 背面朝 +Y，安装时贴墙 |
| Electronics and Details | 纸箱 | [box.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/box.glb) | 封箱胶带、接缝与空白标签 |
| Electronics and Details | 木相框 | [frame.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/frame.glb) | 图面可单独替换；使用项目已有原创图片 |
| Electronics and Details | VHS 磁带叠 | [vhs.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/vhs.glb) | 空白标签，不含剧情文字 |
| Doors | 可开白门 | [white_door.glb](D:/aphasia/outputs/blender_basement_loop_v2/asset_library/white_door.glb) | 独立门轴带动门扇及饰板；门框固定，原点在门框底部中央 |

这些 GLB 的纹理均嵌在文件内部，复制模型时不依赖旁边另放 PNG。家具与杂物的独立资产不带游戏碰撞；可开白门带 3 个固定门框碰撞，门扇碰撞由运行时控制。主地下室另提供简单道具碰撞代理，移动或移除柜椅后应同步处理对应 `PropCollision_*`，避免留下看不见的阻挡。

## 给 CRT 放入自己的视频

屏幕是独立的 **`Screen_Video`** 网格，画面比例 **4:3**，UV 覆盖完整 0–1。场景中的名字带 `Prop_CRT_TV_` 前缀，单独 CRT 中保留基础名称。外壳、按钮、喇叭、线缆均与画面分开。

Godot 接口为 **VideoStreamPlayer → SubViewport → unshaded 材质**。现有接入组件是 [chapter_video_screen.gd](D:/aphasia/meme-game/scripts/world/chapter_video_screen.gd)：先 `bind_screen(mesh)`，再 `set_stream(stream)`，最后按任务事件调用 `play()`。当前默认显示绿色氛围待机屏，待机、视频播放和明确关机由组件区分；没有替用户填入正式视频，也不默认播放视频。正式视频可先使用 Godot 原生支持的 **`.ogv`（Theora）**，建议保持 4:3，避免拉伸。

当前 Blender 的 `APH3_CRT_Green_Standby` 导出为绿色发光 PBR 材质；游戏组件会覆盖为真正 unshaded 的待机/视频材质。电视照到房间的光由单独灯控制，屏幕亮度与场景照明分开调节。

## 第一章当前流程

完整记忆见 [GAME_FLOW_MEMORY.md](D:/aphasia/GAME_FLOW_MEMORY.md)，它更新了旧流程文档中本章入口的冲突内容：

**黑水与白光门 → 至少 10 秒后敲门，听完靠近按 F → 整扇门缓慢开启、淡黑 → 地下室新手教程 5 轮 → 无 NPC 的原有十字路口 → 检查 3 个手机应用解锁权限，开远门 → 下一层。**

进入地下室后，身后的入口门关闭锁定。每轮一位 NPC，完成帮助任务后才可从另一扇门离开；前四轮离开回到楼梯顶部，第五轮完成后离开直接进入十字路口。原十字路口的 NPC 全部迁入地下室各轮。新版开场依据用户在“修复游戏鼠标视角控制”聊天中的后续修改，不能在听完敲门前或仅靠近门就跳过；正式 NPC 文案尚未填入，稳定 ID 和视频接口留给后续内容。

第 1、3、5 轮分别解锁手机的信号瀑布、笔记本、巴别塔应用。前期瀑布流与拾词在 CRT 显示屏内完成，屏幕端从初始即可使用任务所需功能；解锁后的手机应用可离开 CRT 使用，并共享同一词库和任务数据。CRT 局部 VHS 效果提供可保存的设置开关。最新玩法已接入并完成专项验证，记录为 [CRT 教学验收](D:/aphasia/outputs/basement_integration_audit/chapter_terminal_verification.json)。

本地游戏项目在 `D:/aphasia/meme-game`；独立聊天 **Aphasia 第一章地下室循环与3D资源接入** 负责运行接入与流程验收。模型文件本身不负责执行门锁、NPC 任务或存档逻辑。

## 运行本地流程原型

运行 [Start-Chapter1-Dev.ps1](D:/aphasia/Start-Chapter1-Dev.ps1)，在主菜单选新游戏。启动器使用独立的开发存档目录。WASD 移动，鼠标转向；靠近 CRT / NPC / 门按 F。电视内点击“退出屏幕”或按 Tab 回到行走，行走时 Tab 打开手机。Esc 或 F10 打开设置，其中“CRT 屏幕 VHS”只控制屏幕效果；F9 收起开发面板。五轮可以通过实际拾词、投稿与NPC交付完成，不需要开发按钮。完整操作、正式事件接入方式和验证限制见 [第一章接入说明](D:/aphasia/meme-game/docs/chapter1-integration.md)。

原地下室接入已在本地 Godot 通过五轮自动实走、11 次保存继续：[行走验证记录](D:/aphasia/outputs/basement_integration_audit/chapter1_walk_results.json)。最新 CRT 验收另有302项主流程检查和62项真实屏幕渲染交互检查，覆盖五轮交付、应用权限和三次保存继续。NPC沿用已有角色与对话，新任务正文及用户视频仍待内容稿；主场景退出资源清理诊断保留在报告中，未进行真实摄像头或用户视频解码验证。

调研交付：[心理恐怖氛围方案](D:/aphasia/参考/basement_loop_research/psychological_horror_direction.md)、[开源功能与架构比较](D:/aphasia/参考/basement_loop_research/open_source_comparison.md)、[本地 Subliminal 核对记录](D:/aphasia/参考/basement_loop_research/local_observations/OBSERVATION_NOTES.md)。

## 检查与后续编辑

[静态验证报告](D:/aphasia/outputs/blender_basement_loop_v2/asset_validation.md) / [详细数据与哈希](D:/aphasia/outputs/blender_basement_loop_v2/asset_validation.json) 检查实际导出的节点、层级、碰撞命名、屏幕 UV/法线、纹理嵌入和文件体量；游戏运行测试由接入线程另行完成。

楼梯当前采用适合第一人称的平滑坡碰撞，可见踏步鼻端比坡面高约 12.5–18.8 cm。以后如果出现玩家腿脚或需要足部 IK，应另外实现贴合踏面的逻辑。门和主要通道按半径 0.34 m、高 1.72 m 的当前玩家胶囊检查，摆入新物件时请保留这些通行空间。

![当前地下室视角：绿色墙纸、原木家具和扶手](D:/aphasia/outputs/blender_basement_loop_v2/previews/07_Reference_Green_Stairs.png)

![当前电视区：完整墙面、顶棚与绿色电视光](D:/aphasia/outputs/blender_basement_loop_v2/previews/06_Reference_Green_CRT.png)
