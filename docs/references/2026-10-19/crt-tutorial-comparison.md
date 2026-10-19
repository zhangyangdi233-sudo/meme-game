# 首次地下室 CRT 引导研究

2026-10-19，Godot 4.6.3。此目录保存小型阅读参考，不作为插件安装目录；工程实现使用项目内独立状态机，不直接复制这些外部代码。

| 参考 | 核实与适配 | 结论 |
| --- | --- | --- |
| [Godot Tours](https://github.com/GameDev-One/godot-tours) | GDQuest 2023 MIT；已固定提交 c2dbcffa86d6aa17d538a421e3586add9b25d8b8，保存 LICENSE、README、highlight 与 task 两个小文件。高亮实时取得 Control 的矩形，避免窗口布局变化后指错目标；任务与呈现分离。插件依赖编辑器界面，不是游戏运行时框架。 | 借鉴矩形跟踪和任务门控设计，不安装编辑器插件。下载来源和 SHA256 在 manifest.json。 |
| [Godot Camera3D](https://docs.godotengine.org/en/4.6/classes/class_camera3d.html)、[SpotLight3D](https://docs.godotengine.org/en/4.6/classes/class_spotlight3d.html)、[Tween](https://docs.godotengine.org/en/4.6/classes/class_tween.html) | 官方原生 API 支持相机 cull_mask / environment、定向白聚光和可暂停插值。项目已用世界 CRT 网格与 SubViewport UV 输入，无须重建一套屏幕。 | 选用第18可见层隔离 CRT；保留19/20层给本轮 X-ray。暂存相机环境、原灯状态、CRT层，退出精确恢复。 |
| [HardCount 教程开发日志](https://badmilkrobot.itch.io/hardcount/devlog/1698486/hardcount-dev-log-3-better-tutorials) | 作者公开介绍 TutorialManager 状态机与一次性任务提示；未核实可下载源码和许可证。 | 仅作玩法设计对照；没有把其代码或媒体导入工程，也不称其为开源。 |

拒绝仅压暗场景材质：发光墙、屏幕和全局环境可能漏出，恢复容易覆盖原材质。也不复制 CRT 到另一个临时世界：会形成视频材质所有权和位置的双份状态。采用原 CRT 的独立可见层及原位相机转向，位置保持在真实楼梯触发点。

楼梯触发从 asset_contract 的 x 区间和 top_y/bottom_y 中点计算，使用前后位置跨平面检测。只在第一回有效，保存独立 crt_tutorial 进度；未结束演出读档恢复到原触发位置和当前句，已完成不重复。新状态与 stitched_guide_onboarding 旧系统互不复用。

终端引导保留原有四个共享 Control 和真实 Ray→UV→SubViewport 输入。叠加层只放行目标矩形，回调还由 session 内的实际输入事务与阶段门控复核，杜绝只有灰色视觉却能点击的情况。依次为目标帖子、三个拾取单位、真实拖拽组句、发布；取消屏幕保留阶段，重新进入恢复。

七句中文使用用户原文；字幕与音节声复用 chapter_opening_narration / chapter_narration_blips。没有下载或声称提供真人配音。
