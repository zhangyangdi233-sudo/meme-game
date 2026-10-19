# 2026-10-19 迷宫扩大与 Xray 双层比较

目的：第二层由 13×13 扩到 25×25、每格约 8m，保留 Promesa 式住宅与起伏地面，加入环路、死路和渐进式 Xray 教学。研究先于实现；下列外部代码只阅读，不执行、不打包进游戏。下载来源、固定 commit、逐文件 SHA256、字节数见 [源码清单](2026-10-19-maze-xray-source-manifest.json)。17 个最小文本文件共 63,551 字节；本地原文保留在 `D:/aphasia/参考/20261019-maze-xray`。

## 功能、架构、技术与取舍

| 参考 | 功能与架构 | 优点 | 限制及本项目选择 |
|---|---|---|---|
| [Terkwood/maze](https://github.com/Terkwood/maze/tree/e3a81507b7eaa832a5b53700123a2bce0df397fc) | Godot 3.2 / Spatial；每格四方向 bitmask，递归 DFS 雕刻，逐墙实例化 StaticBody | 能直接看到 3D 墙与迷宫边的对应；bitmask 容易检查连通 | 完美迷宫无环，生成与场景耦合，旧 Godot API，按格重复放墙；不移植控制器与实例化架构。借鉴“边与碰撞对应”的检查思想 |
| [DeybisMelendez/maze-generator-godot](https://github.com/DeybisMelendez/maze-generator-godot/tree/18e20a6c9eba27f918747c2274572a10d9b7bc30)；[官方资产库](https://godotengine.org/asset-library/asset/387) | Godot 3.1 TileMap、显式栈 DFS，奇数尺寸栅格，墙/路/边界 tile | 小、易读，25×25 栅格直接适用；栈避免深度递归 | 数据直接存在 TileMap；没有任务检查点、环路、地形和 3D 净空；仓库已归档。不直接加入插件 |
| [GMG 源码](https://github.com/MarcioMed07/GMG/tree/ac9cc9993a33aad63e9046fbc6c747c53b96e022)；[作者 itch 页面](https://marcymed.itch.io/gmg) | Godot 3 多算法演示，Cell 数据和 DepthFirst/Prim/AldousBroder/Flood 算法拆分，由 Maze/Panel 驱动 | 可比较 DFS 长通道与 Prim 分枝；算法与格子对象分离值得参考 | 与演示 UI/TileMap 仍强耦合，没有剧情先后约束。仅借鉴分层，不复制代码 |
| [Jamis Buck / Theseus](https://github.com/jamis/theseus/tree/eff25e2d02da00bb9515690b83008ec05e852317) | Ruby 的纯迷宫数据、算法、solver、renderer；mask、braid、稀疏化、不同网格 | mask 可对应地形裁角；braid 提供可控环路，数据与渲染解耦 | Ruby 与项目无关；通用算法不会保证三段教学顺序。采用固定布局、显式有限回环的设计，不增加运行依赖 |
| [Awertol 3D Maze Generator](https://awertoll.itch.io/maze-generator) | 作者说明 Godot 4 / DFS，9×9、29×29、49×49 可玩示例 | 与第一人称尺度接近，说明较大格数可作为体验比较对象 | 页面标 MIT/CC0，但未提供可核验的源码链接/逐资产清单；不下载二进制、不将其作为可复用代码依据 |
| [Design-Centric Maze Generation，FDG 2019](https://pcgworkshop.com/archive/kim2019designcentric.pdf) | 将解路径的拓扑属性作为设计输入，再构建候选迷宫 | 支持先确定教学主路，再评价支路/转角的思路 | 属研究论文、非可直接加入的 Godot 模块；论文保留作者版权，不把论文插图或代码当 MIT 素材 |

[KidsCanCode 的开发者教程](https://kidscancode.org/blog/2018/08/godot3_procgen1/)说明 DFS 生成树、两点间只有一条路径；[Jamis Buck 的算法回顾](https://weblog.jamisbuck.org/2011/2/7/maze-generation-algorithm-recap)便于比较走廊与分枝风格。我们需要住宅街区中的重复辨路，也需要教学必经点，因此不直接采用全随机 DFS/Prim，选择原创固定主路 + 手工支路 + 局部 braid。评价采用最短路长度、圈数 E−V+1、分岔、死路与必经割点，不把格数增加本身当作复杂度达标。

## 许可证核对

- Terkwood 固定 commit 的 `LICENSE` 是 MIT，版权行是 2021 Terkwood；Deybis 的是 MIT，2019 Deybis Melendez。源文件保留原文。
- GMG 的 itch 与仓库均标 MIT，但实际 LICENSE 的版权行保留 `[year] [fullname]` 模板占位。研究可读，生产不复制其代码；不把占位行补写成虚构作者许可。
- Theseus 没有独立 LICENSE，`README.rdoc` License 段是作者 public-domain 声明，未冒称为 MIT 或 CC0。保留完整 README 作为许可来源。
- 作者网页、Godot 文档和论文只作设计依据；Promesa 官方图像仍仅作气氛参考。本实现写原创数据和几何。

## 选定实现与接口

1. `floor_two_maze_layout.gd` 是唯一真布局，版本 2，25×25，8m，200×200m 外接框。现有 terrain 是 112×118m 半径加不规则扰动的圆盘，不能把外接地图元数据当作完整矩形地面；道路裁角并留地形安全边距，住宅只包围有效道路，不在悬空角落堆房。
2. 固定主程目标 650–800m；按用户后续确认，入口约16m的首位NPC完成对白即给予地图。保留两转角作为路线结构，之后解读普通假墙，再走隐道，最终发现白门。全局至少 5 个局部环与 8 个死路，所有主路/支路都连通；局部环不能绕过教学割点。用固定 ASCII 数据重现，不每次随机。
3. 保留现有 `rows`、`blocking_rects`、`buildings`、`spawn`、`npcs`、`turn_points`、`exit_position`、`primary_route`。`rows + blocking_rects` 永远描述物理世界。增加 `normal_rows + normal_blocking_rects` 描述普通感知图，不可用于人物碰撞。
4. 增加 `xray_differences`（id、observation_id、kind、rect、height、normal_visible、xray_visible、solid、observation_point、max_observe_distance）及 `xray_targets`（id、position、max_distance、required_previous）。`xray_intro`、`hidden_path`、`exit` 顺序观察并持久记录；地图仍由 NPC 对话解锁，观察出口后近距离 F 即可，不强迫同时保持手势按键。
5. 共同住宅层 `1`，普通假立面 `1<<18`，Xray 实墙和真白门 `1<<19`。普通假墙无碰撞；Xray 墙一直有碰撞。摄像机掩码切换可见性，绝不切换 `CollisionShape3D.disabled`。3D target 元数据供主场景在追踪手框覆盖、实际距离和遮挡满足时记录。
6. 普通手机地图不标真出口；感知障碍与真碰撞区别交给地图状态层处理。隐藏路正面设置原创淡色门框/不协调窗线索，避免要求玩家盲撞所有墙。

Godot 官方 [VisualInstance3D.layers](https://docs.godotengine.org/en/4.6/classes/class_visualinstance3d.html)、[Camera3D.cull_mask](https://docs.godotengine.org/en/4.6/classes/class_camera3d.html)适合共享 World3D 的双可见层。现有 detail MultiMesh 必须按材质和可见层分别批次；否则隐藏门窗会混入共享层。[Light3D](https://docs.godotengine.org/en/4.6/classes/class_light3d.html)说明 GI/体积雾会忽略部分光照掩码，故出口相关灯禁烘焙、间接光与体积雾贡献，仅照 Xray 几何；差异 mesh 禁 GI，以防正常视图漏光。

## 实施验收

- 图论测试：外界不可绕行、入口到出口路径显著长于旧 256m、环/死路数量、教学点不可绕过、地图 NPC 足够早。
- 场景测试：物理胶囊逐段净空、假墙无 shape、隐墙 shape 始终存在、层切换前后相同碰撞结果、出口所有 mesh/light 都不在普通层。
- 实走测试：实际 0.34m 半径/1.72m 高 CharacterBody3D，正常重力连续 move_and_slide；记录所有路线点/最小高度/卡住，不逐点瞬移。
- 集成由主代理负责：手框/距离/遮挡判定、真实手机地图、不提前泄露出口、旧存档安全恢复、未追踪手指不触发观察。

## 实际结果与证据

固定布局版本 2：176 个连通路格、217 栋临街住宅、7 个环路、12 条死路、24 个分岔；主线 720m，最短到出口路线 656m。地图由入口约16m的首位NPC在完成对白后授予，原80m处的绘图人只提供X-ray提示；无需先走转角或完成第二位NPC对白。入口、两个转角、两位NPC和两处假墙都是主路必经点。三块靠圆盘边缘的住宅用浅进深地块，所有房屋含檐口四角距真实地形边界至少 0.5m。

真实 `CharacterBody3D` 连续行走使用原 0.34m 半径、1.72m 高胶囊和重力：91/91 路点、13,113 个 1/60s 物理步、218.55 模拟秒；所有步有实际地面支撑，无卡住、瞬移恢复或穿墙。逐点记录在 `artifacts/maze-xray-20261019/walkthrough.json`。

新增薄墙栅格化回归先出现 9 个失败，再修复为通过。薄于 2m 的轴归到其中心所在一格，厚轴仍按格中心取样，避免把 2.8m NPC 门洞全部堵成墙；栅格算法版本进入存档布局指纹。普通地图能显示假墙，Xray 地图能显示固定实体隔墙，碰撞不随显示改变。

| 验证 | 结果 |
|---|---:|
| `test_floor_two_journey` | 47 checks / 0 failures |
| `test_floor_two_maze` | 3,425 checks / 0 failures |
| `test_floor_two_xray_maze` | 144 checks / 0 failures |
| `test_floor_two_walkthrough` | 103 checks / 0 failures |
| `test_floor_two_map_flow` | 71 checks / 0 failures |
| `test_exploration_map_state` | 82 checks / 0 failures |
| `test_floor_two_phone_xray_flow` | 25 checks / 0 failures |

独立 Windows / Vulkan Forward+ 隐藏窗口捕获 13 张实际世界图：`artifacts/maze-xray-20261019/render/`。`xray-intro`、`hidden-path`、`solid-partition`、`white-exit` 各有 normal / xray 对照；使用场景原灯光，没有验收补光。已查看图片确认普通门不发白光、Xray 才出现白门，假墙消失后道路连通，实体隔墙不影响其四米旁路。住宅细节使用 6 个材质 MultiMesh 批次、20,953 个细节盒，全场含地形 264,314 三角面。真实摄像头未在自动测试中开启，手势测试明确使用合成 landmark 输入。

部分完整主场景测试仍打印既有的退出 RID / ObjectDB 清理诊断；断言均通过，无脚本/解析错误。研究、验证日志和预览使用隔离存档，未修改用户正式存档。

## NPC 灯光只读核对

实际生成楼层 1–4 的灯与 NPC 位置记录在 `artifacts/maze-xray-20261019/npc-light-audit.json`。所有楼层的 `RealityKeyLight` 都启用投影。第二层共 8 盏 Light3D：1 盏投影月光、6 盏无投影的低能量窗户微光、1 盏能量为 0 的 Xray 白门灯。两位 NPC 的通道内目前没有独立头顶点光或聚光灯，不能把月光投影描述为“NPC 顶灯已经开启阴影”。

地下室 `chapter_world.gd` 创建的 Main / Rear 灯都设置 `shadow_enabled = true`，`basement_atmosphere.gd` 将它们重挂到可见灯泡后仍保持 true。CRT 贴屏微光和门缝光是独立效果。其他楼层有部分旧的 ThresholdLight / WarmPool / SuspenseLight 使用无阴影设置；运行时枚举未发现这些无投影灯位于 NPC 上方（审计候选范围：水平 4m 内、垂直高于脚底 2.2m、在光源范围内）。本次审计没有修改其他楼层灯光。
