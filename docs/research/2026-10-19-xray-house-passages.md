# 第二层住宅隐道：资料比较与实施约定

2026-10-19。依据用户截图 `180753.png`（不要独立灰挡墙和白角框）与 `180817.png`（采用周围带门窗、抹灰墙、深色屋檐的住宅外观）。

## 比较实际实现

| 方案、原始依据 | 架构和能力 | 本项目取舍 | 许可核实 |
| --- | --- | --- | --- |
| Godot 4.6 [VisualInstance3D.layers](https://docs.godotengine.org/en/4.6/classes/class_visualinstance3d.html#class-visualinstance3d-property-layers) 与 [Camera3D.cull_mask](https://docs.godotengine.org/en/4.6/classes/class_camera3d.html#class-camera3d-property-cull-mask) | 相机按视觉层选择对象；渲染层独立于物理碰撞。官方同时说明 GI 可能跨视觉层，需要明确禁用特殊对象的 GI。 | 采用。保留现有普通相机与手框内 X-ray 相机；视觉层入树前固定，通路始终无碰撞，不创建第二套地形或瞬移门。 | 官方 API 文档作引用；本次不复制引擎代码。 |
| Donitzo [Godot Simple Portal System](https://github.com/Donitzo/godot-simple-portal-system)，[portal.gd](https://github.com/Donitzo/godot-simple-portal-system/blob/567a0620658f81c5404a596e615680394d38de15/src/scripts/portal.gd)，[collision_disable_area.gd](https://github.com/Donitzo/godot-simple-portal-system/blob/567a0620658f81c5404a596e615680394d38de15/src/scripts/collision_disable_area.gd) | 门后 SubViewport 相机有独立 cull mask；实际跨门另行处理位置/方向。碰撞区域通过每层引用计数、离开延迟来关开角色 mask，支持重叠门户。 | 相机与物理分离的结构值得参考；动态 mask、区域进入/离开、延迟恢复对本隐道均多余。玩家失去手势时若恢复碰撞可能困在房屋内，故不采用碰撞切换或传送。 | 已直接读取作者 [LICENSE](https://github.com/Donitzo/godot-simple-portal-system/blob/567a0620658f81c5404a596e615680394d38de15/LICENSE)：CC0 1.0；不是根据转载标签判断。未复制代码。 |
| Michael Watt / Watt Interactive [X-ray Vision Effect](https://godotshaders.com/shader/x-ray-vision-effect/) | 作者提供 `depth_test_disable`、双 pass、可选辉光/条纹的穿墙显示材质，强调是实验示例。 | 适合让对象轮廓透过墙显示；本需求要去除完整屋体后看见真实道路，且普通外观不能带提示描边，所以不采用。旧 Godot 语法也不能直接作为 4.6 实现。 | 作者页面及代码头明确 MIT，已归档原页面；不复制 shader。 |

另核实 MrEliptik [godot_experiments](https://github.com/MrEliptik/godot_experiments) 的 README 确有 X-ray 材质实验，根 [LICENSE](https://github.com/MrEliptik/godot_experiments/blob/4baec7290110ec2e0241daa3739154d5b14c8b59/LICENSE) 为 MIT；当前提交未找到对应可读取的实验源码，因此不把它作为技术结论依据，不推断缺失实现。

下载仅限必要 README、许可、两份 CC0 脚本及官方/作者网页，位于 `D:/aphasia/参考/20261019-xray-house-passages`；`sources.json` 记录固定 commit、原 URL、文件大小和 SHA-256。Donitzo 固定提交 `567a0620658f81c5404a596e615680394d38de15`。无第三方运行资源进入游戏。

## 选定设计

1. 两个旧 `XrayIntroFacade` / `HiddenPathFacade` 保留 ID、坐标单元和观察顺序，替换为完整 8×8m 住宅；不再生成薄墙或白角框。
2. 与普通房屋共用住宅配方和建造函数：相同抹灰材料、深色门窗、石基、窗台、百叶/窗格、楼层腰线、檐口和深色屋顶。高度遵守同一固定街区公式。隐道住宅不另造简化图标式外形。
3. 特殊房屋全部表面与细节只属于 `NORMAL_ONLY_LAYER`。普通/特殊住宅细节批次按父对象、材质和层隔离，避免屋顶或窗户混入共享批次而在 X-ray 中残留。固定碰撞保持空，地面始终是原不规则地形。白门的 X-ray 专属层与隐形实体分隔不变。
4. 布局 `xray_differences[].rect` 扩为整屋占地，`kind` 为 `false_residence`，`residence` 保存共用住宅配方。`normal_blocking_rects` 因此遮住整户；真实 `rows` / `blocking_rects` 保持可走通路。地图栅格化无需新增另一套算法。
5. `observation_point` 移到南侧入口门面前 0.14m、当地地面以上 1.45m，观察距离仍 9m。消除特殊可见提示，不改变真实空间证据 API。
6. 真实地图拓扑未变，因此保留 `version=2` 和原真实碰撞指纹，不因外观改造清空旧存档的探索记录。普通感知地图在现场重新构造，不需要改保存格式。

## 验证计划

- 在原生普通/X-ray 相同机位比较两户，普通画面有完整住宅，X-ray 中无任何门窗/屋檐残留。
- 用正式角色尺寸胶囊与真实地形、重力、`move_and_slide()` 从屋前连续进入并走出，再反向穿回；途中切换相机 mask，确认位置无跳变、碰撞形状集合不变。
- 验证整屋各地图子格：普通显示房屋、真图显示通路；邻居仍是实体房屋；白门仍只在 X-ray 可见。
- 运行现有迷宫、地图、X-ray 几何及集成回归；新增测试不写用户存档。

## 已完成证据

- `test_xray_house_passages`：75 checks，两个真实尺寸胶囊往返共 625 个移动物理帧，全部 grounded；最大单帧位移 0.076m，没有传送/恢复跳变。途中普通/X-ray 相机层反复切换，物理形状集合保持原样。每户完整16个地图子格均验证普通为房屋、真图为道路。
- `test_exploration_map_state`：82 checks；`test_floor_two_maze`：3425 checks；`test_floor_two_xray_maze`：81 checks；`test_reality_world`：通过。后两套相关 fixture 已按最新无 NPC 流程设置演出完成授权、纸条与出口。
- 正式主场景 `test_floor_two_walkthrough`：103 checks、91/91 路点、13,238 物理步，完整 720m 路线可走；脚底保持地形支持。该次运行还记录了主代理新增手机解锁演出的 finished Tween 错误，已另行交给主代理修复，几何测试没有忽略或隐瞒该日志。
- `tools/capture_xray_house_passages.gd`：原生 Compatibility 成功，`artifacts/xray-house-passages-20261019/render` 保存两户普通/X-ray 同机位照片及白色出口对照。已逐张肉眼检查：完整门窗屋体融入两侧住宅；X-ray 中无屋檐/门窗残片；普通视野无真正白出口、X-ray 中白出口仍可见。

碰撞、逐点位置与测试日志在 `artifacts/xray-house-passages-20261019`；本轮未改主状态、主UI、NPC生成或白门实现。

主代理最终复验：手机 finished Tween 恢复逻辑已修正；walkthrough 改为先等真实标题与解锁完成再走路（不跳过演出）。最终104项、91/91路点、13,113物理步通过，日志 `artifacts/walkthrough-final-20261019/engine.log`，不再有 Tween 错误。
