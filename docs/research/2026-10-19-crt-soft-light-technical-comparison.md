# CRT 灯光研究与最终状态

**2026-10-19 最新用户决定：去掉 CRT 上方可见白光/白雾。** 当前生产实现只保留黑背景中的 CRT 与照亮机壳的 SpotLight3D，不创建任何 beam / QuadMesh 雾光。七句、相机和安全镜像恢复保留。`chapter_crt_soft_beam.gdshader` 文件按要求保留在工程中，但 focus controller 已不再引用它。下文记录上一版柔光研究及验证过程，不能视为当前视觉要求。

当前验收目录：`artifacts/crt-no-beam-20261019/`；复用 `tools/capture_crt_soft_light.gd` 的历史文件名，内容已改为检查上方与暗背景同色、且不存在光束实例。Headless onboarding 159 checks PASS；Forward+ / Compatibility 各 3 个楼梯触发位置画面通过，原光束区域逐像素与背景差值均为 **0.0**（现有画面染色使黑位为 2–3/255，不存在局部发白）。两个原生 renderer 的取消、继续存档、七句结束、CRT F/Tab 和清理生命周期均 PASS，exit 0。最终用户画面为各 renderer 子目录内的 `stair-center-production-vhs.png`。

研究日期：2026-10-19。运行版本：Godot 4.6.3；同时面向 Forward+ 和 Compatibility。本文是项目技术取舍，电影叙事方向另见本轮 lighting story direction 文档。没有复制第三方 shader 或电影图片。

## 现场原因与白门参照

`chapter_crt_focus_controller.gd::_build_beam` 原实现为 32 面 CylinderMesh 锥壳。它已经关闭 top/bottom cap，因此单纯去掉底盖无法解决问题。原 shader 只随 UV.y 上下淡出，横向没有渐变；双面绘制叠加后，轮廓仍是一个明确的灰色锥形物体。

本地白门资产的 `OpeningDoor_LightPlane` 是白色发光平面；`chapter_white_gate.gd` 使用很弱的 OmniLight，光缝关闭投影。它并没有可复用的景深或模糊 shader。因此借鉴的是边缘亮度与黑白对比，而不是套用不存在的全屏模糊。

## 官方能力核对

| 路径 | 4.6 Compatibility | 优点 | 本场景的问题 / 决定 |
| --- | --- | --- | --- |
| FogVolume + 体积雾 | 不支持 | 体积遮挡、视角变化自然 | 只在 Forward+ 可用；放弃作为基础方案 |
| 透明锥壳 + Fresnel 淡边 | 支持 | 任意角度仍有空间轮廓 | 前后表面叠加，尖端、轮廓和几何相交仍像实体；不继续修补 |
| 单张柔边 QuadMesh | 支持，官方明确列为伪体积雾方案 | 少量顶点、无需时域重投影、能准确控制光束边缘 | 视点进入雾片不真实；本段相机原点锁定、只转向，因此适用 |
| Glow / DOF | Glow 支持；DOF 不支持 | Glow 可让高亮扩散 | Glow 会同时影响 CRT；不作为本次去锥体边缘的核心，不对 CRT 做全屏虚焦 |

依据：[Godot 4.6 体积雾文档的 QuadMesh 方法](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html#faking-volumetric-fog-using-quads)、[渲染器功能表](https://docs.godotengine.org/en/4.6/tutorials/rendering/renderers.html)。以上支持范围按 4.6 核对，不能沿用“Compatibility 没有 Glow”的旧结论。

透明物体在不透明物体之后绘制，排序依据节点位置，不是逐三角形排序。采用一张卡片，避免交叉雾片前后排序和亮度重复；保留深度测试，让 CRT 实体正常遮挡光片；`depth_draw_never` 不写入透明片深度，不使用 `depth_test_disabled`。依据：[Godot 透明排序限制](https://docs.godotengine.org/en/4.6/tutorials/3d/3d_rendering_limitations.html#transparency-sorting)、[spatial shader 渲染模式](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html#render-modes)。

## 与电影布光的联系

Stephen H. Burum 的 ASC 讲解把塑形、明暗分离和补光分别讨论；补光决定阴影可见程度和气氛。这支持本场景保留黑背景，用唯一 CRT 与顶光建立注意力中心，而不是把背景提成灰色。这里是本项目的艺术应用，不是电影参数的物理复现。[ASC：Lighting a Set](https://theasc.com/article/lighting-a-set/)

ASC 对 LED 摄影棚的采访说明：离镜头的区域可用负补光控制环境反射；额外光线打到显示面会洗掉黑位。CRT 是实际可读的叙事对象，因此空气光应在接近屏幕前淡出，显示文字与材质维持清晰。虚拟黑背景在这里承担“抑制补光”的构图作用，不伪称为物理负光。[ASC：Lighting for LED Stages](https://theasc.com/article/lighting-for-led-stages/)

## 实施契约

1. 聚光灯继续照亮 CRT 外壳；雾光只是呈现空气中的散射感，不改变 CRT 屏幕 shader。
2. 用 1.5m 宽、沿 apex→target 的 QuadMesh，末端位于 `target.lerp(apex, 0.24)`，在 CRT 屏幕之前结束。局部 Y 轴跟随光轴；局部 Z 面朝本段锁定的相机原点。上端较窄、下端较宽，但横向 Gaussian 密度与边界 smoothstep 共同保证没有硬三角边。
3. 顶端短距离柔化，保留明确的上方来源；下方较长距离消散至零。低密度近白色 additive 材质，无底面、无封闭壳、无阴影、无全局雾。
4. 不修改相机位置、原有转向时间、七句文本、存档阶段或暂停行为。
5. 与崩溃修复共同遵循固定层约束：教学 CRT 镜像在进入树之前设置最终 layer，不切换原 CRT 的 mesh.layers。Godot 4.6 引擎问题由独立 crash 修复处理，此软光改动不触碰其生命周期。

引擎问题依据：[Godot issue #121989](https://github.com/godotengine/godot/issues/121989)、[修复 PR #122064](https://github.com/godotengine/godot/pull/122064)。这里的限制是已复现的引擎灯光配对问题，不是透明光片算法的限制。

## 验证约定

- headless：真实地下室触发后检查单 QuadMesh、有限正交朝向、固定 CRT 层、无投影；暂停/取消/七句结束恢复与专用镜像清理仍通过。
- native：Forward+ 与 Compatibility 分别渲染锁定相机和一个偏侧触发位置；光束必须看得见且边缘连续，屏幕仍清楚，黑背景没有整片抬灰。
- 留存同相机有雾/无雾帧，比较 CRT 屏幕差异和远离光束的背景；这比只检查 shader 字符串更能发现贴片或遮挡问题。
- 原生渲染与 crash agent 串行，保留其真实 Vulkan 基线；不向用户当前窗口注入输入。

## 实测调整与最终结果

第一轮发现同样的 0.07 密度在 Compatibility 明显更暗。`OUTPUT_IS_SRGB` 官方定义指示 Compatibility 的输出颜色空间；GLES3 透明 additive 源码使用源 alpha 混合。对本段黑背景，把最终空气光强转换为 sRGB 后再给 Compatibility 的 alpha，保留 Forward+ 原来的线性密度，解决了视觉差异。这个补偿只针对黑背景隔离镜头，不作为一般彩色场景透明混合算法。[spatial shader 的输出颜色空间](https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html#global-built-ins)、[Godot 4.6 GLES3 additive 实现](https://github.com/godotengine/godot/blob/4.6-stable/drivers/gles3/rasterizer_scene_gles3.cpp#L2948)

第二轮有雾/无雾对照发现屏幕上缘被光片加亮：Forward+ 最大差值 0.0353，Compatibility 0.1412。把雾片终点提前至机壳顶部后，六个样本的整个 CRT 屏幕投影矩形差值都降至 **0.0**；实际 Spotlight 仍照亮机壳，没有改变其强度。

| 最终验证 | 结果 |
| --- | --- |
| 真实地下室 headless 触发、暂停、七句、取消、续播、镜像/灯恢复 | 162 checks PASS；新软光结构检查先 3 fail，后通过 |
| Forward+ / Vulkan，楼梯中/左/右三个触发位置 | 3/3 PASS，shader 编译正常 |
| Compatibility / OpenGL，楼梯中/左/右三个触发位置 | 3/3 PASS，shader 编译正常 |
| 光束横截面峰值，两种 renderer | 均 0.2470588，来源清楚可见 |
| 横截面最大相邻像素亮度差 | 均约 0.0078431，没有硬几何轮廓 |
| CRT 屏幕有雾/无雾差值 | 六个样本均 0.0 |

证据目录：`artifacts/crt-soft-light-20261019/`。各 renderer 内 `stair-center-production-vhs.png` 保留用户实际全局 VHS；`*-soft.png`、`*-without-beam.png` 关闭全局 VHS 供定量比较。`measurements.json` 包含相机、屏幕区域与完整横截面。原生画面已人工查看；相机位置、七句、恢复流程与黑背景保持原要求。

日志没有 shader/脚本错误或 light-pair bug。现有主场景退出时仍报告资源/RID 泄漏，Compatibility 构建菜单时仍报告已有 DOF 不支持警告；本次不改菜单或主相机模块。并行 crash 修复的 83 项双 renderer 生命周期验收由该任务独立记录。

源码与参数为本项目原创；ASC 只保存链接与短评，ARRI PDF 仅在工作区参考目录中阅读，不随游戏分发。
