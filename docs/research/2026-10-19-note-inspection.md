# 第二层纸条阅读：实现前研究与接入约定

日期：2026-10-19。目标：原寻路人位置留下小纸条，F 查看中文红色手写原件“墙不再是墙，路不再是路”；关闭阅读后才由主流程记入存档并移除世界纸条。

## 官方资料与取舍

| 路线 | 依据 | 本项目取舍 |
|---|---|---|
| 2D 全屏阅读层 + 世界纸条 | [Godot Control 输入、尺寸与焦点](https://docs.godotengine.org/en/stable/classes/class_control.html) | 采用。阅读尺寸可按视口保证；全局 F / Enter / Esc 只由 main 路由，避免开启键再次关闭、暂停冲突或鼠标模式改变。 |
| 原位 3D 放大、旋转查看 | [官方 GUI in 3D 示例](https://github.com/godotengine/godot-demo-projects/tree/master/viewport/gui_in_3d) | 不引入。该方案还需射线/UV 输入转发、相机隔离与近裁面管理；本次仅阅读两行纸条，不需要转动物件。仅参考结构，未复制示例代码或资产。 |
| 世界 / 阅读层共享纸面绘制 | [SubViewport 作为纹理](https://docs.godotengine.org/en/stable/tutorials/shaders/using_viewport_as_texture.html) | 采用：同一原创 Control 画纸与字体；世界用一次更新的 1024×640 SubViewport 纹理，阅读层直接按实际尺寸绘制，避免低分辨率字被放大。 |

世界纸材质采用普通受光材质、roughness=1、emission=false；`Area3D` 仅提供可交互区域，不生成阻挡玩家的 StaticBody。纸面很小，不添加灯、飘浮图标、桌子或杂物。角色碰撞与地点由现有世界生成器决定。阅读遮罩只负责显示与 `closed` 信号，存档权威仍在 Journey / main。

## 字体比较与许可

- [Ma Shan Zheng 上游](https://github.com/googlefonts/mashanzheng)：粗细变化明显的毛笔楷体，更接近本次不安的红墨手写原件；选择这一字体，仅加载于纸条原件。
- [LXGW WenKai 上游](https://github.com/lxgw/LxgwWenKai)：基于 Klee One 的开源中文字体，笔形端正、正文可读性好，但本次两行警句更适合 Ma Shan Zheng 的笔势。未下载未使用其字体文件。
- 两者官方仓库均提供 OFL 1.1；本次采用的 [Ma Shan Zheng OFL 正文](https://raw.githubusercontent.com/googlefonts/mashanzheng/master/OFL.txt) 允许字体随软件嵌入和分发，需附版权和许可，不可单独出售字体。原字体未修改、未改名、未子集化。
- 下载来自 `google/fonts` 的固定提交 `406197b91ff39a93061c2c2eeaee67ddf2ae1f0d`，文件 `ofl/mashanzheng/MaShanZheng-Regular.ttf`，5,857,936 bytes，SHA-256 `6D2546BB189C732A8CA29AF9E22457B152387D158AA459E4AC2CE1E51788B7FB`。
- 本地参考快照：`D:/aphasia/参考/20261019-note-inspection/`（字体、OFL、上游 README、METADATA、manifest）。游戏分发：`assets/fonts/MaShanZheng-Regular.ttf` 与 `MaShanZheng-OFL.txt`。没有导入完整第三方工程或图片。

## 已授权设计与模块边界

1. `scripts/world/floor_two_note.gd`：`Area3D.new()` 自动建立 `actor_type=floor2_note`、`actor_id=floor2_note`，调用者把 position 设到原寻路人 XZ 的地形采样点。小纸在局部 y 约 0.035，形状和读取区域独立，不阻挡走路。
2. `scripts/ui/floor_two_note_view.gd`：`open(locale)`、`close()`、`cancel()`、`active`、`closed`。close 只在当前打开时发一次 closed；cancel 用于菜单/重建清理，只隐藏而不误报“已读”。不自行读取全局按键，不更改 Input.mouse_mode、不请求 OS 焦点。按钮调用 close，main 把 F / Enter / Esc 路由至 close。
3. `scripts/ui/floor_two_note_paper.gd`：两处共用的原创旧纸纹理/折痕与手写内容。中文原件不随语言改变：`墙不再是墙，` 换行 `路不再是路`。EN / JA 仅在阅读层下方显示小号译文。
4. root 集成世界 actor、main F 路由和移动冻结；dialogue 集成 Journey 的 note_read。新模块不自行保存、不自行改变任务阶段。

## 验证计划

- 先观察缺模块的行为测试失败，再实现：actor 元数据、受光无自发光、无阻挡体、中文字符覆盖、三语原文不变、尺寸适配、重复 close 只发一次、cancel 不发已读。
- 原生隐藏窗口实际渲染中文、英文、日文阅读界面和世界纸条，检查红字、笔画、边界与翻译。headless 只证明状态/布局，不能替代截图。
- 集成侧再验证 F 打开不立即关闭、打开时停止移动/其他 UI、读完才永久消失，Continue 不复生，未读取消不误消失。

## 验证结果

- `tests/test_floor_two_note.gd`：先因缺少两个模块失败（`red.log`），实现后 **82 checks PASS**，最终 headless 日志没有 warning 或 error。覆盖中文全部 11 个字符逐字字形、3 语言 × 3 分辨率布局、受光纸材质、关闭单次信号和取消不记已读。
- `tools/capture_floor_two_note.py`：Windows 正常桌面权限、隐藏窗口、隔离 APPDATA，实际 main 第二层世界、实际 F 输入进入阅读。Forward+ / Vulkan 与 Compatibility / OpenGL 均 exit 0；无脚本、着色器或崩溃错误。Compatibility 仅保留引擎已有的 DOF 不支持提示。
- 成品人工检查：1600×900 时原文手写字号 105 px，800×600 时 75 px；原文两行完整、红色明显，EN / JA 译文不替换原件。地面纸片随场景变暗，未产生额外光源。
- 成品截图：`artifacts/floor-two-note-20261019/{forward_plus,gl_compatibility}/world-note.png`、`inspect-zh.png`、`inspect-en.png`、`inspect-ja.png`、`inspect-zh-800x600.png`；逐渲染器摘要 `capture.json`，总结果 `native-report.json`。
- 首轮截图在楼层标题尚未结束时冻结相机，因此发现标题可覆盖阅读内容的边界；已报告主流程 owner，原图保留在各渲染器 `arrival-overlap-baseline/`。最终截图使用已完成地图介绍的隔离状态，并正常等待入场标题 2.9 秒结束，没有在截图代码里强制隐藏标题。
- `main` / Journey 的存档、交互冻结和继续后不复生由集成测试负责，本模块测试不伪造这一覆盖。

复跑（在 repo 根目录，headless 需显式设置隔离 `APPDATA` / `XDG_DATA_HOME`）：

```powershell
& 'D:/aphasia/tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe' --headless --path . --script res://tests/test_floor_two_note.gd
& 'C:/Users/15340/AppData/Local/Programs/Python/Python314/python.exe' tools/capture_floor_two_note.py
```
