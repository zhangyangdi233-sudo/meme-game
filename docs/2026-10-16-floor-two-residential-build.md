# 第二层住宅迷宫：空间与资产实现

对应 [设计约定](2026-10-16-floor-two-maze-design.md) 的 `legacy:2`，即五回地下室和十字路口之后的第二层。第一章地下室及十字路口建筑没有被此模块替换。

## 资产与视觉

用途为第一人称近距离行走的住宅街区；以 1.56m 眼高观察，房屋沿 8m 网格排列，楼高按 3.6/6.8/10/13.2m 变化。近景有较低房屋和穿屋门厅，中景转角遮挡后续路线，远景较高屋顶形成层次。门窗使用凹槽背面、实体窗框、窗台、细百叶与屋檐；主体有静态盒碰撞，窗框等装饰不增加碰撞。

参考是 [Promesa 官方截图](https://store.steampowered.com/app/1345370/Promesa/)中的 06 夜色坡地、01 窄巷和 09 围合住宅。已实际查看的原图、官方来源 URL 和视觉分析位于 `D:/aphasia/参考/Promesa-20261016`。游戏内使用原创程序几何与 128×128 最近邻纹理，没有打包官方截图、贴图或原作代码。灰白粉刷、蓝色夜光、暗窗洞、少量暖窗光取代旧绿色发光地面和散落杂物。出口视觉复用项目既有 `Opening_WhiteDoor_v2.glb`，第二层单独调整门漆亮度，没有修改十字路口门材质。

建筑直接以 Godot mesh 与 MultiMesh 构建，无外部建模器依赖，也没有角色动画或绑定。实际渲染统计见 `artifacts/floor-two-maze-20261016/capture.json`：包含保留地形共 **78,650 三角形、157 个 MeshInstance3D**；**5,706 个非碰撞细件合为 6 个 MultiMesh 材质批次**；37 个材质资源包含复用门自身的材质。此统计是几何/批次统计，不冒充帧率基准。

## 路线与单一数据源

`scripts/world/floor_two_maze_layout.gd` 的 `data()` / `build()` / `get_data()` 返回版本 1 的布局。无采样参数时位置仅用于 XZ 平面；世界生成器使用原地形高度采样后，通过 `get_floor_two_map_layout()` 返回实际脚下高度。

- `bounds=Rect2(-52,-52,104,104)`，13×13、每格 8m；123 个住宅占格、46 个通行格。
- 原有 252×264m 不规则盘状地形、13 个丘陵、原三角碰撞全部保留。只有地面材质改变。
- 主路折点为 `(1,11) → (1,7) → (5,7) → (5,3) → (9,3) → (9,9) → (11,9) → (11,1)`；最短长度为 256m，带一个短支路和领取地图后的回环。
- 南端出生点 `(-40,40)`；寻路人位于格 `(1,9)`，绘图人位于 `(7,3)`；两个转角为 `(1,7)` 与 `(5,7)`；出口位于 `(11,1)`。
- 所有外圈格都是连续住宅。BFS 检查证明移除任一 NPC 所在格或任一必经转角格，入口与出口就不连通，不能从外围或回环抄近路。
- NPC 偏离巷格中心 1.02m，中央通路仍空出。两处穿屋门厅净宽 2.8m；实际侧墙来自 `passage_blocking_rects()`，同时通过 `blocking_rects:Array[Rect2]` 交给地图的 2m 精细网格，避免地图把门厅墙内显示为道路。

生成器公开 `floor_two_probe(world_point)`（别名 `floor2_probe`），返回 `inside / walkable / cell / cell_key / checkpoint / ground_height`。转角标识固定为 `turn_1 / turn_2`。旧存档恢复调用 `clamp_to_playable_position()` 时，落点会移到最近的实际通道，并保留地形高度；不会恢复进住宅或门厅侧墙。

第二层只有三个交互区域：`floor2_wayfinder`、`floor2_cartographer` 的 actor_type 为 `npc`，以及 actor_id/type 均为 `floor2_exit` 的门。地图任务、对白、耳语、存档与 F 换层由主流程接线。旧布偶、普通/关键 NPC、前置物品、18 件杂物、独立屏风与吊灯、按天刷新的 EXIT 标牌/幻影和窥视者模型在第二层均不会创建；跨日也不会复活。第三层及第四层原事件继续保留。

## 验证与截图

所有命令使用 Godot 4.6.3，APPDATA/XDG_DATA_HOME 指向 `artifacts/floor-two-maze-20261016` 下的独立 profile，不使用用户存档。

- `--headless --script res://tests/test_floor_two_maze.gd`：**938 项检查，0 失败**；包含 BFS 必经点、原地形支持、主路每 0.5m 角色胶囊清空、全部住宅边界碰撞、门厅地图墙与碰撞一致、旧存档恢复、只保留两 NPC 和出口、跨日无旧事件、调色不覆盖专用材质。
- `--headless --script res://tests/test_authored_horror_events.gd`：通过。第二层改为事件禁用断言，原事件机制继续在第三层已有日程中验证。
- `--headless --script res://tests/test_reality_world.gd`：通过。主场景的第二层旧散房断言已更新为住宅迷宫；保留其余世界断言。此主场景测试退出时仍出现 CanvasItem/Font/Texture 资源清理诊断，独立生成器测试没有该诊断。
- `--rendering-method gl_compatibility --script res://tests/capture_floor_two_maze.gd`：Windows/NVIDIA OpenGL 实际渲染，隐藏主窗口、独立 SubViewport，无额外验收补光；已逐图检查入口、NPC 门厅、两个转角、后半段巷道、回环、白门和全景。
- `--rendering-method gl_compatibility --script res://tests/capture_floor_two_main.gd`：真实 `babel_meme_game.tscn` 接入通过，`main-capture.json` 确认 `visible_legacy_nodes=[]`。它保留真实 VHS、黑边和 UI；Compatibility 会提示既有景深仅支持 Forward+/Mobile，退出资源诊断与上述主场景测试相同。

主要截图在 `artifacts/floor-two-maze-20261016/`：`entrance.png`、`first-turn.png`、`cartographer-room.png`、`white-exit.png`、`overview.png`；生产场景对应 `main-entrance.png`、`main-first-turn.png`、`main-white-exit.png`。专项日志与 renderer/几何统计 JSON 同目录。
