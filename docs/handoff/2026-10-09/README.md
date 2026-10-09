# Aphasia 本机成果交接 · 2026-10-09

本快照面向继续制作的协作者，目标仓库为 `zhangyangdi233-sudo/meme-game`，独立分支为 `codex/chapter1-tunnel-handoff-20261009`，基准提交为 `7951a0e6e5f17523ccdb39d41a801fa6f9d07ee4`。已有本机修改、历史已跟踪项目文件和许可文件一并保留。

## 从哪里开始

1. 用 Godot 4.6.3 打开仓库根 `project.godot`。Windows 原始入口及环境复原说明见 [support/windows_workspace](../../../support/windows_workspace/README.md)。
2. 先读 [GAME_FLOW_MEMORY.md](../../../GAME_FLOW_MEMORY.md) 和 [第一章接入说明](../../chapter1-integration.md)，再查看 [最终交接 Word](Aphasia_本机修改与流程交接说明_20261009.docx) 与 [当前修订流程 Word](《Aphasia》游戏整体流程_当前修订.docx)。
3. 编辑模型从 [source_assets/blender_basement_loop_v2](../../../source_assets/blender_basement_loop_v2/README.md) 开始；游戏加载的 GLB 位于 `assets/chapter1/`。
4. 文本创作成果见 [docs/narrative](../../narrative/README.md)，原企划、原流程及房型草图见 `docs/design_originals/`。文本草稿与运行实现分别保留，不能将尚未接入内容视为已完成玩法。

## 当前实现

黑水白门开场 → 至少 10 秒后敲门 → 听完且靠近按 F → 慢开门并淡黑 → 地下室 CRT 教学五轮 → 每轮完成 NPC 帮助后走过黑隧道，在尽头按 F 开白门 → 全白时换场 → 第五轮后进入空旷十字路口 → 核验三个手机应用权限 → 下一层。

第 1、3、5 轮依次解锁信号瀑布、笔记本、巴别塔。屏幕与手机共享拾词、组句和投稿状态；CRT 有独立 VHS 开关。此次还保留隧道保存继续、设置暂停门过场、字体及 VHS 可读性修订、木质儿童椅导出修复，以及本机 Windows 手部追踪生命周期修复。

正式新 NPC 文本、用户视频和真实摄像头完整体验仍需后续制作或实测。部分 Godot 场景退出时仍有既有资源清理诊断；不能将现有验证描述为零警告。

## 归档范围

| 内容 | 位置与处理 |
| --- | --- |
| 当前游戏源码、场景、着色器、声音、图片、GLB、插件 | 原仓库目录全部保留，包含既有本机修改 |
| 测试、采集和制作工具、已有文档 | 原 `tests/`、`tools/`、`docs/`；已有跟踪的 QA 证据保留 |
| 三份可编辑 Blender 工程、11 类道具资产、当前贴图与制作脚本 | `source_assets/blender_basement_loop_v2/` |
| 五份与游戏资产完全相同的 GLB | 仅保留游戏目录一份，源资产 README 提供位置索引 |
| 根目录启动入口与历史环境说明 | `support/windows_workspace/`，原样保存并解释父目录布局 |
| 当前流程记忆、当前修订流程 Word、最终九页交接 Word | 根目录与本交接目录，已同步定稿 |
| 必要验证 JSON 和十二张代表游戏截图 | 本目录 `evidence/`，保留来源子目录 |
| 企划、原始流程、房型草图、当前文字创作稿 | `docs/design_originals/` 与 `docs/narrative/` |

未归档参考游戏安装和下载内容、Godot/Python runtime、venv、缓存、个人存档/偏好、日志、秘密凭据、临时失败渲染、历史模型 `revisions` 和 `.blend1` 备份。原电脑这些文件未删除。资产/说明目录有 `.gdignore`，避免 Godot 自动导入可编辑源文件和交接图片。

## 验证与可追溯性

[archive_manifest.json](archive_manifest.json) 列出复制来源、仓库路径、大小、SHA-256 和去重映射。`state` 区分准备阶段与收到定稿通知后的最终复制。证据保留原生成时间与本机路径，JSON 中指向的日志并未随仓库上传。

最终验收汇总为 [verification_summary.json](evidence/tunnel_readability_20261009/verification_summary.json)：79 项真实渲染转场检查、76 步真实物理行走及五次隧道中段保存继续、307 项主界面回归、66 项 CRT 曲面屏真实 UV 交互检查。各报告的测试替身、摄像头与退出清理限制保留在原记录和 Word 中。Word 的九页逐页视觉及结构检查见 [final_qa.json](final_qa.json)。

`evidence/tunnel_readability_20261009/tunnel_flow_results.json` 记录五轮白门换场检查；CRT 真实屏幕拾词、组句与提交证据位于 `evidence/basement_readability_20261009`；此前的第一章、X-ray、儿童椅及流程文档验证位于对应来源子目录。

本快照三份 `.blend` 合计约 92.12 MiB，最大为 52.69 MiB；当前没有 100 MiB 以上的待上传文件，使用普通 Git 保存完整文件。GitHub 对超过 50 MiB 的文件发出警告、超过 100 MiB 的文件阻止普通 Git 上传，参见 [GitHub 大文件说明](https://docs.github.com/en/repositories/working-with-files/managing-large-files/about-large-files-on-github)。未引入 LFS 取回依赖。
