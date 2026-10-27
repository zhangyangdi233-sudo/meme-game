# 《Aphasia》第一章地下室：质感版（v3b）、五轮变化、传送门/X-ray 方案

日期：2026-10-27。状态：**方案稿，等你拍板后再动仓库**。本文只引用本机已核验的文件与已下载的参考；调研笔记在 `D:\aphasia\参考\research_notes\地下室建模细化与传送门方案\`，参考代码在 `D:\aphasia\参考\20261027-portal-xray-window\`。

## 0. 一句话结论

- 地下室不再加物件。质感靠三件事：**材质（2K 烘焙的法线/粗糙度 + 米制 UV）、微几何（倒角、楼梯侧板、楼梯井开口修正）、灯光（一盏昏黄绿灯 + 薄雾 + 低曝光）**。这些已在 `Basement_Loop_v3b.blend` 做完，渲染图见对照页。
- 进游戏最关键的一步不是建模，而是让运行时**不再用 256px 的程序贴图覆盖墙纸和地毯**（`basement_atmosphere.gd` 的 `_apply_surface_materials`），否则 Blender 里做的质感到游戏里全部被盖掉。
- 楼梯下的门保留，改成**用大量胶带封死、不可交互**；第 4 轮玩家走近时从门内砸门（音效用 CC0 素材，候选清单另附）。
- 小红书视频的效果（高斯泼溅传送门）在 Godot 里**部分可行**：推荐先做"手框视窗看到另一版地下室"（复用现有 X-ray 视口，零新依赖），再做"可走穿的门洞"，最后才考虑 3DGS 窗口（gdgs 插件，MIT）。整屏 3DGS 世界不建议。

## 1. 质感版 v3b 做了什么（不新增物件）

| 层面 | 具体改动 | 对象 / 文件 |
| --- | --- | --- |
| 材质 | 以你原有的绿色墙纸、苔绿地毯、赭色天花贴图为底色，叠加**周期性 4D 噪声**烘焙出无缝的 2K 法线 + 1K 粗糙度（纸纹、地毯圈绒、天花颗粒、哑光漆橘皮纹），导出后 Godot 直接读图 | `V3B_Wallpaper`、`V3B_Carpet`、`V3B_PopcornCeiling`、`V3B_PaintSatin`；贴图在 `outputs/basement_v3b_20261027/textures/` |
| UV | 房壳、天花、地毯、楼梯、踢脚线、门套全部改成**按米投影**（墙纸 1.6 m 一铺、地毯/天花 1 m、油漆 0.5 m），不同尺寸的墙块不再拉伸，也不再依赖运行时 triplanar | 21 面墙、6 块天花、34 块地毯件、89 个油漆件 |
| 微几何 | 楼梯踏步前缘 12 mm 圆角，油漆踢脚/门套/门板 4–5 mm 倒角，栏杆与扶手平滑；**楼梯侧板**沿踏步前缘线封住阶梯侧面与平台下的空洞；**楼梯井开口**东边从 x=−1.69 改到 −1.48（原来由运行时 `_repair_stairwell` 现场重箱），并补一条开口饰边 | `Stair_Stringer_East`（+碰撞）、`Stair_OpeningFascia`、130 个对象的倒角/平滑 |
| 胶带门 | 平台下的门：平门扇、黄铜把手、**38 条交叠的胶带**（灰色布基胶带为主、少量棕色封箱胶带，密封四边并贯穿门扇），无交互；留一个锚点给砸门事件 | `StairCloset_Door`、`StairCloset_Knob`、`StairCloset_Tape`、`StairClosetDoorAnchor` |
| 标记 | 新增空物体 `AssetVersion_v3b`（extras：`material_override=skip`、`stairwell_repair=baked`），运行时据此跳过旧补丁 | 在 `80_Game_Anchors` 集合 |
| 预览灯光 | 主灯 28 W、后灯 7 W、CRT 3.5 W，关掉所有补光，黑色世界 + 体积雾 0.010，AgX 中高对比，曝光 −0.1 | 仅 Blender 预览；游戏灯光见 §2 |

没有动：平面布局、门轴、锚点、X-ray 标记、CRT 屏幕、现有家具与箱子；没有贴纸条、涂鸦、污渍。

## 2. 进游戏：需要改的代码与参数

### 2.1 导出与资产

1. `Basement_Loop_v3b.blend` 放入 `source_assets/blender_basement_loop_v3b/`，用与 v2 相同参数导出 `assets/chapter1/Basement_Loop_v3b.glb`。已试导出并校验：合同节点、运行时依赖的节点名、`AssetVersion_v3b` 标记、胶带门与楼梯侧板碰撞全部在；54k 三角形。目前 41.7 MB，其中 38.8 MB 是贴图（三张 2K 法线 PNG 各 8.7 MB）。进仓库前二选一：法线降到 1K PNG（约 20 MB），或 2K 法线改 JPEG 质量 92（约 16 MB，Godot 导入后都会做 VRAM 压缩，显存占用一样）；另可清掉仍被少数对象引用的 v2 旧地毯贴图（6 MB）。
2. `asset_contract.json` 的 `game_model` 指向 v3b；`chapter_world.gd` 的 `MODEL_PATHS.basement` 同步。
3. Godot 导入设置：贴图 VRAM 压缩 + mipmaps（法线图勾选 normal map），各向异性 4×。

### 2.2 `basement_atmosphere.gd`（运行时修补）

| 函数 | v3b 处理 | 原因 |
| --- | --- | --- |
| `_apply_surface_materials()` | 发现 `AssetVersion_v3b` 时**跳过** | 它用 256×256 程序贴图覆盖所有 `Wall_*/Stairwell_*/Carpet*`，是现在画面"平、糊、重复"的主因 |
| `_repair_stairwell()` | 跳过 | 开口修正已烘进模型；重箱会把天花换成无 UV 的 BoxMesh |
| `_bind_fixture_lights()` | 保留，改参数（见 2.3） | 灯泡内置光源、开关逻辑都要留 |
| `_build_wall_wear()` | **建议关闭**（梦核要干净） | 它在五面墙上生成划痕/污迹网格，属于"住过的痕迹" |
| `_dress_furniture()` / `_stack_boxes()` / `_dress_exit_table()` | 建议精简：保留桌子、两把椅子、手机；去掉堆箱、油漆罐、散书、桌面纸笔杯 | 物件越少越像参考图 01；花瓶/书二选一可留作每轮差异 |
| `_build_clocks()`、CRT 异常 | 不动 | 是现有五轮设计的一部分 |

### 2.3 灯光与环境（Forward+；括号内为 gl_compatibility 回退）

| 项 | 现值 | 建议 | 说明 |
| --- | --- | --- | --- |
| 主灯 OmniLight3D | energy 0.66，range 6，attenuation 0.8 | energy 0.55，range 5.2，attenuation 1.4，color #D9E3B8，shadow on，light_size 0.12 | 更快衰减，角落自然变暗；绿白偏暖 |
| 后灯 | 0.48 / 4.7 | 0.28 / 4.0，同色 | NPC 区更暗，只剩轮廓 |
| CRT 绿光 | 0.47 / 2.65 | 0.42 / 2.4，#3FFF59 | 保持"唯一冷光源"的对比 |
| Environment.ambient | 当前由场景决定 | ambient_light_energy 0.03（纯黑太假，留一点） | （兼容模式同） |
| SSAO | — | 开，radius 1.0，intensity 2.5，detail 0.6 | 踢脚线、楼梯下、家具脚下的接触阴影（兼容模式不可用 → 用 LightmapGI 烘 AO 或在贴图里预烘） |
| SSIL | — | 开，radius 2.0，intensity 1.2 | 墙纸把绿色"染"到天花，参考图 01 的感觉 |
| 体积雾 | — | 开，density 0.012，albedo #9FB58A，length 24，光源 volumetric_fog_energy 0.6 | 梦核的"空气感"；（兼容模式不可用 → 用远景雾 depth fog 代替） |
| 辉光 | 可能已有 | 低：intensity 0.35，threshold 1.1，只让灯泡与 CRT 发光 | 避免糊成一片 |
| Tonemap | — | AgX，exposure 0.9，white 1.0 | Godot 4.3+ 自带 AgX，与 Blender 预览一致 |
| 调整层 | — | 轻微去饱和 −8%，对比 +5% | 现在的绿太"纯" |
| 全局 VHS | 已有 | 保留，噪点略减 | 暗部噪点会吃掉材质细节 |

可选：对房壳烘一次 **LightmapGI**（导入时生成 UV2，只烘间接光，直接光仍用动态灯，灯光开关异常不受影响），兼容模式下这是唯一能得到角落压暗的办法。

### 2.4 验证

1. `tools/inspect_basement_assets.gd` 读新 GLB：节点、碰撞、锚点。
2. `python tools/verify_basement_revision.py --godot <Godot_v4.6.3-stable_win64_console.exe>`：全部回归（含 `test_basement_atmosphere`、`test_basement_wall_wear`、`test_chapter_asset_binding`）。`test_basement_wall_wear` 若关闭磨损需同步改期望。
3. `outputs/ingame_loops_20261027/capture_loops.gd`（修正版截图工具，已能抓到五轮）对比抓图：第 1、3、5 轮各 5 个机位 + X-ray。
4. 真机 10 分钟游玩：开关、CRT、手机、出口门、五轮循环。

## 3. 五轮变化与胶带门事件

现有五轮（不动）：1 正常 → 2 耳语 + 闪灯 → 3 停电找开关 → 4 钟墙 → 5 半钟 + X-ray 数字 + CRT 红屏。在这个骨架上，胶带门与"少而准"的静态差异建议如下：

| 轮 | 胶带门 | 建议的静态差异（每轮只改一处） | 声音 |
| --- | --- | --- | --- |
| 1 | 胶带完好，无事 | 基准房间 | 现有 |
| 2 | 无事 | 闪灯结束后主灯只恢复到 85% 亮度（房间从此一直更暗一点） | 现有耳语 |
| 3 | 无事（黑暗中不可见） | 停电恢复后，隔墙上的画框消失，只剩挂钩的影子 | 现有 |
| 4 | **砸门**：玩家走到距门锚点 2.6 m 内（或正视门 2 秒）触发；门内传出 4 下闷响（0.42 s 间隔，第 4 下更弱、延后 1.1 s），门板每下抖 1.5 cm；播完存档 `basement_door_knock_played`，不重播 | 钟墙（现有）；钟声可在砸门后全部停摆 2 秒 | 新增 CC0 砸门音效，AudioStreamPlayer3D 挂在锚点，低通 900 Hz 模拟门后 |
| 5 | 几条胶带被撕开、卷边垂下（静态网格切换）；**X-ray 框内**门缝是黑的、比普通画面开 3 cm | 半钟（现有）+ CRT 事件（现有） | CRT 事件（现有） |

音效候选（已下载到 `D:phasia\参考61027-sealed-door-knock-sfx\`，全部 Freesound **CC0 1.0**，页面许可已逐一核对，无需署名；文件为官方 HQ MP3 预览，许可清单与 SHA256 见该目录 `sources-manifest.json`、`README.md`）：

| 文件 | 时长 | 适用 |
| --- | --- | --- |
| `shelbyshark-444700-door-pound-other-room-hq.mp3` | 4.57 s | **首选**：作者录的就是"另一间房里砸门"，自带闷感 |
| `shelbyshark-444701-series-of-door-pounding-hq.mp3` | 6.98 s | 近距离连续砸门，剪 3–6 下、加低通做"门内" |
| `mrh4hn-426618-heavy-door-pounding-hq.mp3` | 2.28 s | 重击单声，可叠在第一下上 |
| `sumixiv-848072-door-rattle-wood-hq.mp3`、`castironcarousel-216875-locked-doorknob-rattle-hq.mp3` | 2–3 s | 砸门后门把被拧动的余响（可选） |
| `perspektywa_tn-844081-door-creak-dry-hq.mp3` | 6.55 s | 第 5 轮胶带撕开时的慢吱呀（可选） |

Pixabay 的候选页面被 Cloudflare 拦截，无法核对许可，未采用。

实现要点：门事件写进 `basement_atmosphere.gd` 的 `update_visit()`（已有每帧 `player_local` 与轮次判断），新增常量 `KNOCK_VISIT = 3`（0 起算 = 第 4 轮）、`KNOCK_RADIUS = 2.6`；存档字段走 `basement_loop_director.gd` 的 `dispatch("basement_door_knock_started")`，与耳语字段同一套白名单。音效文件进 `assets/audio/sfx/`，许可记录同 `tv_static_SOURCE.md` 的格式。

## 4. 传送门 / 手势 X-ray 视窗

### 4.1 视频溯源（调研笔记 `gaussian_splat_portal_source.md`）

- 原作：World Labs 设计师 Ian Curtis（@XRarchitect）2026-10-19 发布的 WebGPU 演示"Portal jumping through gaussian splat worlds"；小红书与 B 站都是搬运，**没有公开源码**。最接近的开源复刻：Simam Digital `splat-portals`（MIT，three.js + Spark，WebGL2，2026-10-22）。
- 原理：每个世界一套 3DGS 场景；门内视角 = 把主相机按"门 A→门 B"的刚体变换镜像到另一世界，离屏渲染成贴图；门面用屏幕坐标采样这张贴图；穿门时切换当前世界。
- Godot 侧：没有内置 3DGS。唯一插件级实现 **gdgs**（ReconWorldLab，MIT，Godot 4.3+，Compute 后端仅 Forward+，Raster 后端 beta 可跑 Compatibility，支持 .ply/.splat/.sog/.glb）；无人公布 RTX 4070 Ti 上 1–3M splat 的帧率；RTX 4070 + 4K 显存超限的 issue 存在。采集流水线最低成本：Scaniverse（手机）→ splat-transform → SuperSplat 清理 → gdgs。

### 4.2 Godot 4.6 可用的三条路线（调研笔记 `godot_portal_implementations.md`，只列打开过源码的）

| 路线 | 代表实现 | 优点 | 缺点 / 风险 | 与本项目的关系 |
| --- | --- | --- | --- | --- |
| A. SubViewport + 出口相机 + `SCREEN_UV` 贴图 | Donitzo（CC0）、VojtaStruhar "Portals 3D"（MIT，功能最全：近平面推进、门体加厚、穿门网格裁切、视口分辨率策略）、TheNullbean world-portal（MIT，3 KB，"把另一间房放在远处"） | 与现有 `chapter_xray_view.gd` 同构；Forward+/兼容模式都能跑；可走穿 | 每个可见门把场景再画一遍；没有真正的斜切近裁剪，用"把 near 推到门框"近似；不嵌套 | **推荐** |
| B. Stencil（Godot 4.5+） | Joshiii03（无许可证）、ScatteredComet（MIT，C#，WIP） | 不用第二视口 | 官方标为实验性；**只能在透明 pass 读 stencil**；兼容模式修复仍在进行（里程碑 4.8）；无 GDScript 成熟实现 | 不采用 |
| C. 3DGS 窗口 | gdgs 的 `GaussianSplatNode` 放进 A 路线的视口里 | 最接近原视频"门内是真实采集的空间" | 需先拍摄/训练一个 splat；Compute 后端仅 Forward+；无法动态重打光；与五轮灯光异常冲突 | 作为第三阶段的加分项 |

### 4.3 推荐路线与阶段

**阶段 A：手框"视窗"看到另一版地下室（1–2 天，零新依赖）**
- `chapter_xray_view.gd` 已经是"复制主相机 + 改 cull_mask 的 SubViewport"。加一个 `ViewMode.LAYER_SWAP`：子相机位姿不变，只把 cull_mask 换成"陈设 B"的渲染层集合。于是手框里看到的是同一个房间的**另一版**：例如胶带门是开的、椅子朝墙、钟全停。所有"另一版"只是同一场景里多放的几个 mesh，用 render layer 区分，没有传送、没有第二世界。
- 这正好接在第 5 轮已有的"X-ray 才能看到的数字"之上，叙事上把手势框变成"看见被污染之前/之后的房间"。

**阶段 B：隔墙通道做成可走穿的门洞（3–4 天）**
- v3b 已把通道做成门洞（门头梁 + 门套）。在门洞放一张 1.55×2.12 m 的 `QuadMesh`，材质用 `SCREEN_UV` 贴图（Donitzo/VojtaStruhar 的 shader，CC0/MIT），贴图来自第二个 `chapter_xray_view.gd` 实例：子相机 = 主相机经"门 A→门 B"变换（`b.global_transform * rotY(π) * a.affine_inverse() * main_camera.global_transform`），`near` 推到门框四角投影的最小距离 −0.05。
- 门后世界用 TheNullbean 的做法：**把另一版地下室实例放到 100 m 外**（同一 World3D，灯光独立），门洞 `Area3D` 检测头部越过门平面即把玩家刚体换位到 B，再立刻 `update_view()`。这样"第 N 轮出门 → 下一轮进门"可以不黑屏、不淡出，直接走进下一版房间。
- 预算：子视口按 0.6 比例渲染，只在门洞可见且 < 11 m 时 `UPDATE_ALWAYS`；1440p 下多一次场景绘制，4070 Ti 没问题，兼容模式要把阴影关掉。

**阶段 C：3DGS 窗口（可选，1 周 + 采集）**
- 在阶段 A 的子视口里改 `own_world_3d = true`，放 gdgs `GaussianSplatNode`，手框里看到的是真实拍摄的某个房间（例如你自己家的地下室/楼道）。只在 Forward+ 开启，兼容模式回落到阶段 A。先用 gdgs 自带示例测帧率再决定。

### 4.4 需要先回答的问题

1. 手框里看到的"另一版"应该是什么：被污染前的干净房间？还是污染后的（门开、字满墙）？
2. 第 N 轮→第 N+1 轮的切换是否要做成"直接走进去"（阶段 B），还是保留现在的门过场？
3. 3DGS 想采集什么空间，有没有可拍摄的真实地下室？

## 5. 玩法加深与新手教程（待第二轮调研回来补全）

（占位：五轮内每轮只教一个动词；拾字→拼句→投稿的三步各自对应一个房间变化；语言污染如何"回答"玩家。）

## 6. NPC 去留（待补）

（占位：P.T. 式循环里"无人"的价值；替代方案：CRT 里的声音、只在 X-ray 里出现的人影、手机里的对话。）

## 7. 现在需要你定的事

1. 质感版 v3b 的方向（对照页里的"材质+灯光"列）是否 OK；灯光亮度是偏暗一档还是再暗。
2. 胶带门事件放第 4 轮、走近触发，是否同意；第 5 轮撕开胶带 + X-ray 门缝是否要。
3. 运行时杂物（堆箱、油漆罐、散书、桌面纸笔杯、墙面磨损）是否按"梦核"精简。
4. 传送门先做阶段 A（手框视窗）还是直接做阶段 B（可走穿门洞）。
