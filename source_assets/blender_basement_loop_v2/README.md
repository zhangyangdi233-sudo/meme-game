# Aphasia 可编辑地下室与开场源资产

本目录是 2026-10-09 的可编辑资产交接副本。游戏实际加载的模型位于仓库 `assets/chapter1/`；本目录由 `.gdignore` 隔离，不参与 Godot 自动导入。

## 继续制作

- 打开 [Basement_Loop_v2.blend](Basement_Loop_v2.blend)，选择 `Aphasia_Basement_Loop_v2` 场景编辑地下室。
- 打开 [Opening_WhiteDoor_v2.blend](Opening_WhiteDoor_v2.blend) 编辑黑水与 18 米外白光门。
- 在 Blender 的 Preferences → File Paths → Asset Libraries 中添加本目录的 `asset_library`，即可使用 [Basement_All_Props_v2.blend](asset_library/Basement_All_Props_v2.blend) 中的 11 类集合资产。分类信息见 `blender_assets.cats.txt`。
- 贴图已经打包在三份 `.blend` 内；没有外部 Blender Library 链接。保留内嵌贴图即可迁移到其他电脑。`textures_green` 同时保留当前外部 PNG 源稿。

不要为了整理路径而直接重新加载全部贴图或覆盖解包：主文件内部保留了部分同名贴图的不同版本，外部同名 PNG 不一定等于每一份已打包图片。

## 导出物的位置

以下五份导出与原输出目录逐一核对 SHA-256 相同，因此只在游戏资产目录保存一份：

| 模型 | 仓库内文件 |
| --- | --- |
| 带家具地下室 | [Basement_Loop_v2.glb](../../assets/chapter1/Basement_Loop_v2.glb) |
| 纯建筑地下室 | [Basement_Architecture_v2.glb](../../assets/chapter1/Basement_Architecture_v2.glb) |
| 黑水白门 | [Opening_WhiteDoor_v2.glb](../../assets/chapter1/Opening_WhiteDoor_v2.glb) |
| CRT | [crt.glb](../../assets/chapter1/asset_library/crt.glb) |
| 木质儿童椅 | [kids_chair.glb](../../assets/chapter1/asset_library/kids_chair.glb) |

另外九份独立 GLB 保存在本目录的 `asset_library`。所有 14 份 GLB 的纹理和缓冲均内嵌，无外部图片 URI。原始位置与新位置的完整映射及哈希见 [archive_manifest.json](../../docs/handoff/2026-10-09/archive_manifest.json)。

## 约定与版本顺序

游戏最新流程以仓库根 [GAME_FLOW_MEMORY.md](../../GAME_FLOW_MEMORY.md) 和 [第一章接入说明](../../docs/chapter1-integration.md) 为准，包括五轮出口的黑隧道、白门和全白换场。

[asset_contract.json](asset_contract.json) 保留坐标、门轴、碰撞、屏幕和 X-ray 标记约定。`Screen_Video` 为独立 4:3 屏幕，三个 `XRAY_EXIT_GUIDE_*` 标记仅在摄像头 X-ray 框内显示。移动道具时同步检查 `PropCollision_*`，防止残留不可见碰撞。

[ORIGINAL_README.md](ORIGINAL_README.md)、`BUILD_PLAN.md`、原合同和验证报告保留制作时的原文与本机路径。其中早期颜色方案、直接循环出口、三物品门锁等旧叙述，均不能覆盖最新流程。当前美术是绿色墙纸、地毯和局部 CRT 绿光，家具与扶手保持原木；十四张选定预览位于 `previews`。

## 制作脚本的适用范围

`scripts` 是原制作过程的源码留档，不是一键从空场景重建的发行工具。多数 `*_live.py` 依赖历史 Blender 会话、`driver_namespace`、特定执行顺序和 `D:/aphasia` 绝对路径。优先从已交付 `.blend` 继续编辑，执行脚本前逐项检查路径和目标场景。

- `dress_basement_live.py` 依赖旧 `blender_subliminal/asset_library/Basement_Props.blend`。
- `export_basement_live.py` 依赖旧 `props_manifest.json`，会保存模型、重写导出及 Blender 用户偏好。
- `build_crt_assets.py` 依赖旧 `blender_subliminal/textures`。
- `validate_exported_assets.py` 期望原 GLB 布局且会写验证报告；使用本仓库时先按上表调整输入路径。
- `asset_preview_sources.json` 是原缩略图再生成输入，含旧本机路径；资产库自身已包含缩略图。

历史 `revisions`、`.blend1` 备份、缓存和日志保留在原电脑，未纳入该快照。没有删除任何原文件。
