# CRT 展示、F 交互闪退与厚毛毯脚步修订

本轮基于 `848710c`，继续在 1016 分支修改。用户正式存档和设置没有改动。

## 顶部光束

最初将双面透明锥壳改为柔边光片。用户在 16:47 的截图中进一步明确取消上方白光，当前版本不再创建任何光束或雾光几何，只保留黑背景中的清晰 CRT。临时 SpotLight 仅照亮电视本身，七句旁白与原场景恢复流程不变。

此前研究的柔光 shader 文件保留，但当前教学不加载它。CRT 的教学视觉副本仍采用固定可见层，不修改原场景模型层。

[电影布光与叙事研究](research/2026-10-19-lighting-story-direction.md) 比较 ARRI 的扩散/控光原则与 ASC 的低调照明、选择性展示、顶部柔光案例；[技术方案比较](research/2026-10-19-crt-soft-light-technical-comparison.md) 对照体积雾、锥壳、QuadMesh 与 Glow/DOF 的功能、成本和适用范围。参考只用于研究，新的 shader 为本项目编写。

## 居中的教学文字

首次 CRT 操作提示从底部的 24 号字改为屏幕正中间的 64 号字。中、英、日共用居中锚点与自动换行，并加深色描边。文字本身不拦截鼠标，原来高亮帖子、拾字、拖拽和发布的输入门控保持不变。

## CRT 闪退

用户日志与原生 Vulkan 复现均先报告 light/geometry unpair 错误，再以 `-1073741819` 退出。根因是 Godot 4.6.3 的运行时 mesh layer 变化与临时灯释放组合；旧 headless/GL 教程验收没有覆盖默认 Forward+ 的这一问题。

教学现在用入树前固定第18层的 CRT 视觉副本，保留原模型层。取消或完成时释放全部临时模型与灯光，恢复原相机和房间。没有更换引擎或强迫用户切换渲染器。[根因、官方问题与可复跑测试](2026-10-19-crt-renderer-crash.md)。

## 地毯脚步

**最终选择已更新**：用户比较新下载的实录后明确选择A原实录。当前游戏恢复Mihacappy的CC0录音，保留A主体音色，仅修剪前后空白与切口；普通走路改为0.5909秒一步，冲刺保留0.3112秒。四段实际长度0.28秒。素材许可、三份新下载备选和验证见[实录筛选记录](research/2026-10-19-carpet-walking-sources.md)。以下B/C描述是此前迭代记录，已不在游戏中使用。

旧脚步按最强能量选取实录片段，突出低频撞击，某段有明显次击；低通后摩擦细节更少。0.48 秒片段又在 0.26/0.14 秒步行/跑步触发中被重复截尾。

此前按“脚踩在厚重的毛毯上的声音”制作的 C 版使用四个原创的 0.235 秒落脚变体，以脚掌压实厚绒毛的中低频重量为主，降低纤维摩擦。平滑起落，不使用旧撞击采样。音量仍为 -20 dB，步行/跑步接触间隔约 0.409/0.311 秒，播放中的片段不重启；最低播放音高下时长约 0.242 秒，跑步也留有约 69 毫秒间隔。原 CC0 参考录音保留但不再载入。新的素材可从固定随机种子重新生成，许可与命令见 [foley 说明](../assets/audio/foley/LICENSE.md)。

`artifacts/carpet-audio-20261019/C-thick-blanket-walk.wav` 为历史C版连续步行试听，`BC-walk-equal-rms.wav` / `BC-sprint-equal-rms.wav` 提供上一版软纤维与当前厚毛毯版的同响度对比。四段的 180–550 Hz 能量占比约 79–91%，650 Hz 以上约 3%；客观检查不能代替用户设备上的主观听感确认。

## 验证

- 后续取消光束：focus 159项通过；Vulkan/OpenGL 各3个真实视角，上方原光束区域与周围黑背景像素差为0。两种渲染器的继续/取消/读档/反复F与Tab生命周期各84项通过，报告：`artifacts/crt-no-beam-20261019/lifecycle/report.json`。
- 居中64号字及最终语义分行：默认Vulkan下，中英日完整首次教学各37项通过，保存实际截图；报告：`artifacts/crt-guide-center-20261019/report.json`。仍有既有退出资源清理诊断，无脚本/解析错误或崩溃。
- 厚毛毯C版：生成器逐字节复现、四段PCM频带/尾音检查、脚步27项、音频运行和终端session56项通过。三组集成报告另存为 `artifacts/revision-final/results-20261019-final-guidance-blanket.json`。
- 以下为较早的闪退与柔光修订记录，柔光现已按用户后续要求取消。
- 默认 Forward+/Vulkan：修前实际崩溃；修后完整首次教程37项通过。
- Vulkan 与 OpenGL 原生生命周期各83项通过，包括 Continue、首次楼梯、取消/读档、七句结束、反复 F/Tab 进出、释放场景；无原灯光配对错误或崩溃。报告：`artifacts/crt-crash-20261019/native/report.json`。
- 8组相关 headless 集成测试全部通过，覆盖 focus、真实CRT教学、session、脚步、音频运行、第一章集成、旁白音频；报告：`artifacts/revision-final/results-20261019-crt-light-audio.json`。
- 脚步27项行为检查、四个PCM的频带/尾音检查和生成器逐字节复现通过。Python 使用已有 `D:/aphasia/tools/hand-tracking-venv/Scripts/python.exe`，不增加游戏运行依赖。
- 原生图保存于 `artifacts/crt-soft-light-20261019/`；生产VHS开启的截图与关闭VHS的测量帧分开。最后的参数与像素检查见技术方案文档。

原生测试直接向游戏输入入口送入 F/Tab 事件，验证实际GPU与游戏流程；不是操作系统键盘路由测试。Compatibility 仍有现有的景深不可用警告；部分 headless 主场景退出仍有既有 RID/ObjectDB 清理诊断，日志保留这些信息。
