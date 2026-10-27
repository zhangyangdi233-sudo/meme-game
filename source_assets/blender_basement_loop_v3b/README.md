# 第一章地下室 质感版 v3b（梦核方向）

制作日期：2026-10-27。状态：**源资产与试导出已交付，尚未接入游戏**；游戏仍加载 `assets/chapter1/Basement_Loop_v2.glb`。接入步骤与参数见 [docs/2026-10-27-basement-v3b-dreamcore-plan.md](../../docs/2026-10-27-basement-v3b-dreamcore-plan.md)。

## 方向

用户在 2026-10-27 明确：地下室要做成梦核式的空旷、昏暗、物件很少的房间，**在原有 v2 模型上细化质感，不新增陈设，不表现住过的痕迹**。因此本版没有新家具或杂物；唯一新物件是用户要求保留并用大量胶带封死的楼梯下的门。

## 改动清单

| 层面 | 内容 |
| --- | --- |
| 材质 | 以 v2 的绿色墙纸、苔绿地毯、赭色天花贴图为底色，叠加周期性 4D 噪声（环面映射，天然无缝）烘焙出 2K 法线 + 1K 粗糙度：纸纹、地毯圈绒、天花颗粒、哑光漆橘皮纹。新材质 `V3B_Wallpaper`、`V3B_Carpet`、`V3B_PopcornCeiling`、`V3B_PaintSatin` 以**对象级**材质槽赋给房壳、天花、地毯件和油漆件，网格级旧材质未动。 |
| UV | 上述对象改为按米盒投影：墙纸 1.6 m 一铺（接缝 0.533 m）、地毯与天花 1 m、油漆 0.5 m。导出后 Godot 不再需要 triplanar。 |
| 微几何 | 踏步前缘 12 mm 圆角；踢脚线、门套、门板 4–5 mm 倒角；栏杆、扶手、灯球、门把平滑；`Stair_Stringer_East` 楼梯侧板沿踏步前缘线封住阶梯侧面与平台下空洞（含 `-colonly`）；楼梯井开口东边从 x=−1.69 改为 −1.48（原由运行时 `_repair_stairwell()` 现场重箱，现烘进模型，含碰撞），并加 `Stair_OpeningFascia` 饰边。 |
| 胶带门 | `StairCloset_Door`（平门扇，无凸板）、`StairCloset_Knob`、`StairCloset_Tape`（38 条交叠的胶带：七成灰色布基胶带、三成棕色封箱胶带，密封锁边、铰链边、门头和门底，另有五条贯穿门扇的长斜条）、锚点 `StairClosetDoorAnchor`（extras：`event=sealed_door_knock`）。门不可交互；砸门事件与 CC0 音效候选见方案文档 §3。 |
| 标记 | 空物体 `AssetVersion_v3b`（extras：`material_override=skip`、`stairwell_repair=baked`），供 `basement_atmosphere.gd` 识别后跳过材质覆盖与楼梯井重箱。 |
| 预览灯光 | 主灯 28 W、后灯 7 W、CRT 3.5 W，关闭 `71_Preview_Only` 补光，黑色世界 + 体积雾 0.010，AgX 中高对比，曝光 −0.1。仅用于 Blender 预览；游戏灯光另设。 |

没有改动：平面布局、门轴、锚点、`XRAY_EXIT_GUIDE_*`、`Screen_Video`、全部现有家具与道具。合同节点全部保留，可用 `tools/inspect_basement_assets.gd` 复核。

## 目录

- `Basement_Loop_v3b.blend`：Blender 5.2.3 LTS 保存（5.x 格式，4.x 打不开），贴图已打包。
- `textures/`：烘焙出的 11 张 PNG（与 .blend 内打包的一致）。
- `export/Basement_Loop_v3b.glb`：试导出（与 v2 相同导出参数），41.7 MB，其中 38.8 MB 是贴图；进 `assets/chapter1` 前应把三张 2K 法线降到 1K 或改 JPEG，见方案 §2.1。
- `previews/`：对照渲染（`v2_` 原样、`light_` 只改灯光、`v3b_` 材质 + 灯光）。完整三栏对照页在 `D:/aphasia/outputs/basement_v3b_20261027/地下室质感版对照页.html`。
- `scripts/refine_basement_v3b.py`：从 v2 源文件一键生成本版（烘焙、材质、UV、倒角、封条门、灯光、渲染），可重复执行；`scripts/export_basement_v3b.py`：导出 GLB；`scripts/make_v3b_page.py`：生成对照页。

## 重新生成

```powershell
& 'D:\steam\steamapps\common\Blender\blender.exe' --background 'D:\aphasia\meme-game\source_assets\blender_basement_loop_v2\Basement_Loop_v2.blend' --python 'D:\aphasia\meme-game\source_assets\blender_basement_loop_v3b\scripts\refine_basement_v3b.py' -- --out 'D:\aphasia\outputs\basement_v3b_20261027' --tag v3b --render views --samples 128
```

参数：`--materials/--geometry/--lighting/--stringer 0|1`、`--main-w --rear-w --crt-w --haze --exposure`、`--bake 2048`、`--only <camera,...>`。脚本会先把源文件中停在编辑模式的网格切回物体模式。

## 待用户确认的事项

亮度档位（28 W 档或更暗的 15 W 档）、胶带门样式与第 4 轮砸门 / 第 5 轮撕开胶带的安排、进游戏时是否去掉运行时生成的杂物、传送门先做手框视窗还是可走穿门洞。确认后再做 §2 的接入。
