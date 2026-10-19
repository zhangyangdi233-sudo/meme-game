# 首次 CRT 原生渲染闪退修复

用户在第一回楼梯旁白结束后按 F 进入 CRT 时，默认 Vulkan Forward+ 进程崩溃。正式运行日志先报 `BUG, indexing did not unpair geometries from light`，位置为 `renderer_scene_cull.cpp:835 / :607`，随后 signal 11。正式存档的只读副本显示 `focus_done=true`、`lesson_phase=post`，玩家仍在楼梯中段；没有修改用户的正式存档或首选项。

## 根因和修复

旧教学在开始时给已经进入 World3D 的 CRT 网格增加第 18 层，结束时还原网格层并释放临时聚光灯。Godot 4.6.3 Forward+ 在这种层变化后可能保留过期的灯光/几何配对。官方 [issue #121989](https://github.com/godotengine/godot/issues/121989) 提供相同版本、错误位置和复现步骤；[修复 PR #122064](https://github.com/godotengine/godot/pull/122064) 针对这项引擎问题。

在本机 RTX 4070 Ti、正常 Windows 桌面权限下，未修复的真实首次教程稳定重现同一崩溃，退出码 `-1073741819`。此前 headless 流程和 OpenGL Compatibility 截图都没有覆盖默认 Forward+ 的灯光配对路径，这是本次验收的缺口。

`chapter_crt_focus_controller.gd` 现在为教学创建短时 CRT 镜像：共享原网格和材质，复制每个表面的材质及世界变换，在加入场景树前固定第 18 层。原 CRT 的网格可见层从未改变。结束或取消时立刻隐藏并排队释放镜像和聚光灯，没有用延迟删除或永久保留隐藏灯规避崩溃。镜头、玩家位置、原灯光、教学存档与操作阶段沿用原流程。可见光束已按用户后续反馈取消。

## 可复跑的原生回归

独立入口：

```powershell
python tools/verify_crt_renderer_lifecycle.py --output artifacts/crt-crash-20261019/native
```

如需回放某份第一回地下室存档，可显式提供只读输入副本：

```powershell
python tools/verify_crt_renderer_lifecycle.py --save-copy artifacts/crt-crash-20261019/user-save-readonly.dat --output artifacts/crt-crash-20261019/native
```

可用 `--godot <可执行路径>` 指定引擎，或用 `--renderer forward_plus` / `--renderer gl_compatibility` 单独检查。Windows 必须在正常桌面权限下运行；启动窗口默认隐藏，测试渲染真实 SubViewport。每个渲染器使用输出目录下自己的 AppData，输入存档只读，写档只发生在测试副本。

`tests/test_chapter_crt_renderer_lifecycle.gd` 覆盖普通 Continue 后 F/Tab、新的楼梯触发、原网格层不变、教学取消、保存/继续后恢复旁白、末句恢复、连续三次 F/Tab、再次 Continue 和完整场景清理。每个关键阶段实际渲染数帧后再释放对象。脚本检测到 headless 会明确报错并退出 1，不能作为这项检查的通过证据。

Python 入口依次运行 Forward+/Vulkan 和 Compatibility/OpenGL，检查退出码、成功标记、`BUG, indexing`、脚本/解析错误、着色器编译错误及引擎崩溃标记，并输出 JSON 报告。它独立于默认 headless 套件；既有 ObjectDB/RID 退出清理诊断如出现会保留在日志中，不一律忽略所有 ERROR。

## 证据位置

`artifacts/crt-crash-20261019/` 保存用户原始日志、只读存档副本和 SHA256、修复前 `forward-before.engine.log`、修复后完整 37 项首次操作流程 `forward-after.engine.log`、网格层契约红/绿日志，以及拒绝 headless 的日志和退出码。生成物均处于仓库忽略的 artifacts 中；回归脚本和本说明随仓库保存。

柔光着色器整合后的双渲染器生命周期验收已完成：**Forward+/Vulkan 83 项、Compatibility/OpenGL 83 项全部通过**，两进程均退出 0，报告的错误数组为空。报告为 `native/report.json`，各自 `engine.log` 保留实际显卡和渲染器名称。Compatibility 的既有景深不可用警告仍保留；本次两个原生回归日志无灯光配对、脚本、着色器或退出资源清理错误。正式存档及偏好文件的前后 SHA256 一致。

取消可见光束后的追加回归：Vulkan/OpenGL各84项通过，报告 `artifacts/crt-no-beam-20261019/lifecycle/report.json`。这次主场景退出存在既有RID/TextServer资源清理诊断，日志完整保留；无配对、解析、脚本或崩溃错误。

![真实 Vulkan 楼梯焦点，上方无可见光束](../artifacts/crt-no-beam-20261019/forward_plus/stair-center-production-vhs.png)

![旁白完成并反复退出后，F 正常打开首次操作教学](../artifacts/crt-crash-20261019/native/forward_plus/after-focus-crt.png)
