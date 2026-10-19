# 第二层入场、地图授权与纸条：方案比较

日期：2026-10-19。按用户最新截图修订：第二层取消全部 NPC，标题结束后手机自动出现、地图图标由灰渐亮；原入口 NPC 位置改为红字纸条。隐道改为完整住宅外观，见 [住宅隐道研究](2026-10-19-xray-house-passages.md)。

## 参考与取舍

| 方法 / 一手来源 | 架构、适用点 | 优点 | 本项目成本 / 结论 |
| --- | --- | --- | --- |
| [Godot 4.6 Tween](https://docs.godotengine.org/en/4.6/classes/class_tween.html) | 节点绑定的属性插值、回调序列 | 手机现有滑入已经使用 Tween；可直接沿用缓动 | 单靠延迟回调容易在退出/读档后继续执行。仅保留现有手机位置 Tween，授权时序交给独立控制器 |
| [Godot 暂停与 process mode](https://docs.godotengine.org/en/4.6/tutorials/scripting/pausing_games.html)、[输入传播](https://docs.godotengine.org/en/4.6/tutorials/inputs/inputevent.html) | SceneTree 全局暂停，或按节点分离处理/输入 | 官方机制可区分 UI 和世界 | 本项目音频、手追、CRT 共享主场景；采用已有输入门控固定玩家，演出更新显式接收 paused，不全局停树 |
| [Godot State Charts](https://github.com/derkork/godot-statecharts)、[Godot Asset Library](https://godotengine.org/asset-library/asset/1778) | Godot 4，节点/信号/guard/延迟转移；MIT | 状态与表现分离、暂停行为明确、复杂分支可视化 | 此处只有滑入→灰态停留→亮起→释放四段，完整插件过重。采用相同职责划分的小控制器与保存状态，不引入插件运行依赖 |
| [GDQuest Godot Tours](https://www.gdquest.com/library/gdtour_get_to_know_godot_editor/) | 编辑器内分步高亮与输入限制 | 清晰聚焦目标；项目此前已保存 MIT 源码参考 | 它依赖 EditorInterface，不能直接当游戏运行时新手引导。借鉴聚焦单个图标，沿用真实手机控件 |
| [ExpressoBits Inventory System](https://github.com/expressobits/inventory-system) | 物品 Resource、库存节点与 UI 分离，支持多人；MIT | 通用库存、容器与保存边界清晰 | 单张阅读后消失的纸条不需要完整库存系统。用独立 Area3D + 阅读 Control + note_read 保存位；字体/纸条视觉来源由[纸条研究](2026-10-19-note-inspection.md)记录 |

以上工程取舍是针对本游戏的判断，不是参考项目作者的结论。没有复制第三方运行时代码。State Charts 阅读样本固定提交 `76d226a3efac66a72aea825382b320c94808f409`，README、LICENSE、state_chart.gd、transition.gd 和 SHA256 清单在 `D:/aphasia/参考/20261019-floor-two-arrival/`。GDQuest 的旧参考仍保留；不安装编辑器插件或新 MCP。

## 实施边界与顺序

1. 先完成本轮 CRT 安全区提示、规则放大反馈/现行规则卡片、黄色路口装饰清理，保留其验证。
2. 两处 X-ray 隐道使用邻屋同一建造配方，仅普通视觉层可见；实际通路始终无阻挡。普通地图记录住宅占地，X-ray 地图记录真实路。
3. 标题结束后锁定移动/转向，打开手机主页。0.52 秒滑入后保留灰图标，再缓动亮起；完成时授予地图并保存，恢复操作，手机留在主页。首次新存档/未授权旧档均走该流程，旧已获图档不重复。
4. 地图演出不以 NPC、走路检查点或污染值授权。设置/失焦暂停进度；菜单/重建取消，未完成则下次重新演出，不提前授予。原探索迷雾和 X-ray 三阶段发现顺序保留。
5. 入口纸条在原寻路人位置，F 打开时固定玩家；原文始终为红色手写“墙不再是墙，路不再是路”。关闭后保存 note_read 并隐藏世界纸条，重进/读档不复现。纸条不额外阻塞地图或出口任务。
6. 用隔离存档验证：标题先后顺序、真实灰亮图标、移动锁/恢复、取消/继续、旧状态迁移、无第二层 NPC、纸条真实 F 输入与关闭、隐道胶囊通行、地图两视图/出口仍一致。原生 Vulkan 截图检查最终画面。
