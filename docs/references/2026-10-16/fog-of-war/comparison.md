# Godot 手机地图与战争迷雾方案比较

研究日期：2026-10-16。目标工程使用 Godot 4.6.3；本报告记录实施前的检索、源码阅读与方案比较，下载代码没有执行。后续工程实现与验证见 [实施记录](../../../2026-10-16-floor-two-maze-design.md)。查询覆盖 Godot 官方 Asset Library / Asset Store、GitHub 和 itch.io；以下功能以固定提交中的代码为准，不以搜索摘要或宣传语代替验证。

**建议采用：持久探索网格 + 手机 `Control._draw()` 地图。** 地图状态从第二层布局数据取得，玩家世界 X/Z 坐标映射到方格；保存已探索格，界面按状态绘制房间、走廊、门和当前位置。需要柔和边缘时再由同一网格生成小尺寸 `ImageTexture`。四个开源方案里，Hex Strategy Map 的状态与渲染分离最值得借鉴，TABmk 的图像揭雾最适合作为备选实现参考。没有发现一个现成插件比这条组合路线更贴合“单人、3D 室内、手机内地图、持续探索与存档”的全部需求。

## 已核实的四个开源方案

| 方案与固定版本 | 技术路线与实际功能 | 许可 | 对本工程的优点 | 适配成本与限制 |
|---|---|---|---|---|
| [TABmk / godot-4-fog-of-war](https://github.com/TABmk/godot-4-fog-of-war/tree/e98acd3ccab1d8913d4e5ff0ee5a052c096a4007)，提交 `e98acd3ccab1d8913d4e5ff0ee5a052c096a4007`，2023-12-09；`project.godot` 标记 **4.2 / Forward Plus** | GDScript 创建黑色 `Image`，用光斑图片 `blend_rect()` 累积揭开区域，再 `ImageTexture.update()`；`Sprite2D` Multiply 混合显示。更新有移动输入检查和 0.01 秒默认间隔。已经揭开的区域在本次运行中保留。 | [MIT，2023 TAB_mk](https://github.com/TABmk/godot-4-fog-of-war/blob/e98acd3ccab1d8913d4e5ff0ee5a052c096a4007/LICENSE) | 代码短，适合理解“记住走过的区域”；可以改为手机地图低分辨率遮罩，无需再渲染 3D。 | 当前接口依赖 `CharacterBody2D` 与示例 `get_input()`；没有墙体视线、楼层隔离或存档。输入检查不能代替实际坐标变化检查。每次仍上传整张纹理，默认 1000×1000 RGBA8 是约 4 MB 像素数据。适合作为图像算法参考，不宜原样接入。 |
| [87PizzaStudios / godot_light_fow](https://github.com/87PizzaStudios/godot_light_fow/tree/7864881d8a886cf6a5d806b357ba7b9d635ec890)，提交 `7864881d8a886cf6a5d806b357ba7b9d635ec890`，2023-08-01；`project.godot` 标记 **4.1** | 把 `PointLight2D`、`LightOccluder2D` 复制到 `SubViewport`；shader 将亮度转为透明度。`persistent_reveal` 使用上一遮罩与当前光照的最小 alpha；支持多灯、遮挡与可滚动雾贴图。`on_light_moved()` 从 viewport 读回 `Image` 并新建纹理。 | [MIT，2020 Heartbeast Studios](https://github.com/87PizzaStudios/godot_light_fow/blob/7864881d8a886cf6a5d806b357ba7b9d635ec890/LICENSE)；版权行按仓库原文保留 | 遮挡语义比圆形揭雾完整，适合确实需要 2D 光照驱动可见性的游戏。 | 3D 墙体必须另投影为 2D 遮挡器并保持同步；存在额外 viewport、读回和纹理分配工作。运行内持久揭雾不等于磁盘存档，源码没有成品存档接口。手机小图只显示探索记录时，整套灯光复制成本偏高。 |
| [mujtaba-io / godot-3d-minimap](https://github.com/mujtaba-io/godot-3d-minimap/tree/06e82872fb76b05dd39e18c15e6387bce36bab88)，提交 `06e82872fb76b05dd39e18c15e6387bce36bab88`，2024-12-13；`project.godot` 标记 **4.3 / GL Compatibility** | 顶视 `Camera3D` 经 `RenderingServer.viewport_attach_camera()` 绑定到 256×256 `SubViewport`，复用同一 3D 场景。示例 viewport 为 `UPDATE_ALWAYS`。**这是小地图示例，未实现战争迷雾或探索存档。** | [MIT，2024 Mujtaba](https://github.com/mujtaba-io/godot-3d-minimap/blob/06e82872fb76b05dd39e18c15e6387bce36bab88/LICENSE) | 可直接观察 3D 物体，布局不需另手绘；若以后要真实俯视画面，可参考相机绑定。 | 仍需独立探索网格和遮罩。室内屋顶、楼板、动态物体可能遮住地图或泄露未探索内容；需专用剔除层/地图几何。手机隐藏时也应停更新。README 的“disable fog”指环境雾，不是探索迷雾。 |
| [JavierIslas / hex-strategy-map-free](https://github.com/JavierIslas/hex-strategy-map-free/tree/c55fe2f02805e28675d1b274830afb7b2ec22e7a)，提交 `c55fe2f02805e28675d1b274830afb7b2ec22e7a`，2026-10-07；`plugin.cfg` **2.1.0**；官方条目要求 **Godot 4.6+** | GDScript `RefCounted` 状态：HIDDEN / EXPLORED / VISIBLE，按玩家保存格状态；半径揭示、LOS、增量 `fog_changed` 信号。绘制独立，既有节点渲染也有 `_draw()` 批量层；可选 shader 雾边。`HexCell.serialize()` 保存 explored 状态。 | [MIT，2026 Javier Islas](https://github.com/JavierIslas/hex-strategy-map-free/blob/c55fe2f02805e28675d1b274830afb7b2ec22e7a/LICENSE) | 已证明“探索状态与表现分离”的接口结构；状态改变才重绘、探索记录可序列化，最贴近我们的存档需求。 | 绑定六边形、多人和策略玩法，直接移植会引入不需要的坐标/框架。应借鉴状态模型，改为第二层方格或房间拓扑。免费仓库有基础序列化，**完整 SaveManager 与 HexMiniMap 列在 Pro 版，不能当作已下载免费功能**。 |

版本备注：Godot [旧 Asset Library 条目](https://godotengine.org/asset-library/asset/5136)仍显示 Hex **2.0.0-Free**；[Asset Store](https://store.godotengine.org/asset/javier-islas/hex-strategy-map/)也列该发行版本。本报告检查的 GitHub 固定提交内 `plugin.cfg` 为 **2.1.0**，二者不能混写。上述 4.1/4.2/4.3 是各示例工程声明，不表示我们已经在 4.6.3 执行兼容验证。

## 源码核查入口

- TABmk：[图像创建、累积 blend 与更新循环](https://github.com/TABmk/godot-4-fog-of-war/blob/e98acd3ccab1d8913d4e5ff0ee5a052c096a4007/game.gd)，[工程版本](https://github.com/TABmk/godot-4-fog-of-war/blob/e98acd3ccab1d8913d4e5ff0ee5a052c096a4007/project.godot)。
- Light FOW：[复制灯光/遮挡与读回](https://github.com/87PizzaStudios/godot_light_fow/blob/7864881d8a886cf6a5d806b357ba7b9d635ec890/fow/fow_light.gd)，[持久遮罩 shader](https://github.com/87PizzaStudios/godot_light_fow/blob/7864881d8a886cf6a5d806b357ba7b9d635ec890/fow/convert_light_mask.gdshader)，[工程版本](https://github.com/87PizzaStudios/godot_light_fow/blob/7864881d8a886cf6a5d806b357ba7b9d635ec890/project.godot)。
- 3D Minimap：[相机绑定](https://github.com/mujtaba-io/godot-3d-minimap/blob/06e82872fb76b05dd39e18c15e6387bce36bab88/MinimapSystem/MinimapSystem.gd)，[256×256 与更新模式](https://github.com/mujtaba-io/godot-3d-minimap/blob/06e82872fb76b05dd39e18c15e6387bce36bab88/MinimapSystem/MinimapSystem.tscn)，[工程版本](https://github.com/mujtaba-io/godot-3d-minimap/blob/06e82872fb76b05dd39e18c15e6387bce36bab88/project.godot)。
- Hex：[揭示/LOS/状态变化](https://github.com/JavierIslas/hex-strategy-map-free/blob/c55fe2f02805e28675d1b274830afb7b2ec22e7a/addons/hex_strategy_map/fog_of_war.gd)，[探索状态序列化](https://github.com/JavierIslas/hex-strategy-map-free/blob/c55fe2f02805e28675d1b274830afb7b2ec22e7a/addons/hex_strategy_map/hex_cell.gd)，[按需批量绘制](https://github.com/JavierIslas/hex-strategy-map-free/blob/c55fe2f02805e28675d1b274830afb7b2ec22e7a/addons/hex_strategy_map/batch_hex_layer.gd)，[版本声明](https://github.com/JavierIslas/hex-strategy-map-free/blob/c55fe2f02805e28675d1b274830afb7b2ec22e7a/addons/hex_strategy_map/plugin.cfg)。特别注意：`FogOfWar.serialize()` 本身仅保存当前 visible 集；历史 explored 在 `HexCell`，要连同 `HexGrid` 保存，单存 fog 对象会漏掉历史探索。

## itch.io 与未采用项

[Flunch 的 Fog of War for Godot 4](https://flunch1314.itch.io/fog-of-war-godot-4-plugin)页面声明 4.x、开发环境 4.6、版本 0.3.0，提供 LOS、持续探索与渐退记忆模式。但源代码在付费 ZIP 内，采用商业 EULA，禁止把插件源码作为独立素材或仓库再分发。它不是 MIT 开源方案；没有购买或下载其付费包/可执行演示。其功能宣传也未经过本次源码复核。

[AntonWedemeier / Godot-FogOfWar](https://github.com/AntonWedemeier/Godot-FogOfWar)检索到 Godot 3.0.6 的反馈 viewport 方案，但本次仓库页面未确认明确 LICENSE，且版本较旧，未列入四个可复用开源候选，也未下载。公开可见代码不自动等于可复用许可。

## 对第二层手机地图的具体建议

以下是结合本工程需求的工程判断，不是上述项目承诺的现成功能。

1. **同一份布局驱动世界和地图。** 第二层建设数据提供 `map_id/layout_revision`、XZ 原点、网格大小、格距、通路、墙与门。3D 碰撞和手机地图均从这里派生，避免另画一张与可行走区域不一致的地图。楼层/独立区域必须用不同键；不把不同高度但相同 XZ 的空间混在一起。
2. **先实现持续探索。** 存档保存已探索格的 `PackedByteArray` 或位图，玩家当前格/朝向是临时状态。若玩法确实需要“过去见过但现在不可见”，再加 VISIBLE 临时集；读档重新计算当前可见区域，不把动态敌人或未发现出口提前画出来。
3. **以实际位置变化揭示。** 用世界坐标变换到地图局部坐标，再计算格子。玩家进入新格或跨过规定距离才更新；地图关闭时仍记录正常探索，设置暂停、失焦暂停、门过场与预览场景不记录。瞬移/换楼层要直接更新目的地，不能在起终点间画穿墙直线。
4. **揭示范围服从室内遮挡。** 小圆形范围容易穿墙泄露相邻房间。可先用相邻可通行格/房间连接图限制揭示；需要真实视线时再对布局网格做短程 LOS。关闭的门、不同房间和未到达出口应有明确规则。无需把整套 2D 灯光/遮挡器复制进手机。
5. **用 Control 绘制探索地图。** 背景层只在探索、门状态、界面尺寸变化时 `queue_redraw()`；玩家箭头独立更新，避免每帧重绘所有格。官方文档明确支持 `Control` 自绘，且缓存绘制命令；这也避免“一格一个节点”的数量成本。[Godot 4.6 自绘文档](https://docs.godotengine.org/en/4.6/tutorials/2d/custom_drawing_in_2d.html)。
6. **有视觉需要再增加纹理。** 例如 128×128 的单通道探索遮罩；只有揭示变化时更新，`ImageTexture.update()` 复用纹理，不每次 `create_from_image()`。64×64 byte 网格仅 4096 字节、128×128 byte 网格 16384 字节（只算原始状态，不算容器/存档开销）。软边 shader 是表现层，不负责唯一的存档状态。[Image API](https://docs.godotengine.org/en/4.6/classes/class_image.html)、[ImageTexture.update](https://docs.godotengine.org/en/4.6/classes/class_imagetexture.html#class-imagetexture-method-update)。
7. **持久化要带布局版本。** 保存 map_id、revision、宽高和探索数据，加载时校验长度/版本。旧存档无此字段视为尚未探索，已发布内容和任务进度不受影响；第二层布局修改需显式迁移或重置地图探索。复用原游戏存档，不额外制造一个不同步的存档文件。

若后续确实需要真实俯视画面，可采用低分辨率、专用地图剔除层的 Camera3D + SubViewport 作为底图，仍由上述探索网格遮罩。手机隐藏时设 `UPDATE_DISABLED`，显示时按需要更新；不要照搬示例的永久 `UPDATE_ALWAYS`。官方列出了这些更新模式：[SubViewport 4.6](https://docs.godotengine.org/en/4.6/classes/class_subviewport.html)。这条替代路线适合动态立体地形必须被看到的情况，本轮室内探索小图暂无必要。

## 实施前后应验证的行为

- 玩家世界坐标、地图箭头、走廊与门位置一致，边界与负坐标不越界；暂停与门预览不会揭图。
- 新区域随移动出现，地图关闭后重新打开仍在；未探索的房间、出口和标记不泄露。
- 同一地图保存/Continue 保留探索，第二层与其他楼层记录隔离，新游戏重置，旧存档默认合理。
- 手机开关和应用切换不吞掉原有 Tab/Esc 操作，中文/英文/日文只翻译地图 UI。
- 栅格方案的状态层可 headless 测试；布局与标记需要实际渲染检查。若采用 shader/SubViewport，还要用实际图形后端验证，不能把 headless 通过当成渲染验收。

## 已保存的源码参考

- `TABmk-godot-4-fog-of-war/`：MIT LICENSE、README、工程声明、主算法和示例脚本/场景，共 6 个文件。
- `JavierIslas-hex-strategy-map-free/`：MIT LICENSE、README、版本、FOW 状态、网格/单元、批绘制与 shader，共 11 个文件。
- [download-manifest.json](download-manifest.json)：17 个下载文件，共 64,293 字节；逐文件记录固定 commit URL、相对路径、字节数和 SHA-256，下载后 17/17 校验一致。

这些是**选定源码快照，不是完整可运行项目**；没有下载全部图片/依赖，没有导入 Godot，也没有执行插件。若后续复制或改编 MIT 代码，随分发保留对应版权声明与许可证；独立实现状态模型无需声称使用了整套插件。两套参考中也存在通用全局类名，不能不经整理直接一起导入正式工程。

## 仓库快照说明

本文件保留研究结论。上述源码目录和 17 个下载文件仍位于原工作区参考目录，不随本游戏分发；仓库仅保存比较文档、下载清单与 [许可原文](../licenses/)。清单中的相对路径用于标识原下载资料，并非本仓库文件。
