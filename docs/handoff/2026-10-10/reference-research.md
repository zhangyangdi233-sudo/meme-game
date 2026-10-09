# 视觉与声音研究记录

查阅日期：2026-10-10。用于本轮实现与以后微调。下列时长是 Aphasia 自身的设计参数，不是对其他游戏逐帧测得的数据。

## 楼层标题

[PEAK 官方介绍](https://landfall.se/peak)将旅程分成不同生态区；[Custom Biome Intros 作者说明](https://thunderstore.io/c/peak/p/catcraze777/Custom_Biome_Intros/)直接说明原游戏存在“生态区标题 + 天数副标题”的进区文本结构。可借用的是到达后短暂标明场所的层级，不必另开一个地图 App。

[GRYPH FRONTIER 的武陵官方图文与 PV](https://prtimes.jp/main/html/rd/p/000000026.000126152.html)强调城市与自然、光影与雾的整体场景；[终末地官方影像页](https://endfield.hypergryph.com/video)提供原始宣传片入口。结合用户提出的武陵入城与 Boss 开始大字方向，本版采用世界画面保留、中央大号无衬线楼层名、小号编号、短暂淡入淡出。先让玩家看见空间，再读到名字。

本轮网页资料不能确认武陵入城动画的精确字体名称和逐帧曲线，因此不把自定的 2.6 秒动画标成“原作复刻”。未下载或复用游戏字体、片段、音乐。

## 开门与循环

[P.T. 设计研究者的第一手访谈](https://harveyhayman.com/Shadows-of-them)记录了逐圈分析走廊的制作方法，核心是重复空间建立记忆，再改变局部条件。对本项目的设计推论是：保持入口与出口的视角连续，变化发生在同一套房型里，玩家才容易察觉灯和钟的异常。

早期生化危机的慢开门节奏作为用户指定方向；本版门扇打开与镜头推进在同一段时间内发生。开场允许淡黑落入地下室，地下室之间通过普通门接续，不使用旧白闪或 12 米隧道。检查重点是门内最后一帧、下一入口第一帧的位置和朝向，而不是单独看门扇是否转动。

## 墙面 灯光 与钟

房型仍以已确认草图为准。旧参考目录 `D:/aphasia/参考/basement_loop_research/local_observations` 保留 Subliminal 实机观察；用户本轮 10–13 图决定钟的圆形轮廓、半钟手写数字与重复铺墙方向。

墙纸保留绿色和细密纹理，磨损分成低对比底色、局部潮痕裂纹、细小法线起伏三层；地毯用织物颗粒、粗糙度与法线组合。采用按米计算的三平面投射避免不同墙块 UV 拉伸；新增钟面和贴纸单独映射，不改 CRT 的 0–1 UV。技术依据：[Godot BaseMaterial3D 官方文档](https://docs.godotengine.org/en/stable/classes/class_basematerial3d.html)。

灯罩材质呈现发光面，点光源绑定在同一个灯具上、靠近灯泡；移动灯具时二者一起移动。CRT 保留独立近距离绿色反光。运行时发光材质本身不等于已计算全局照明，绑定光源用于实际照亮环境。

## 地毯脚步

检索并比较了 [Kenney RPG Audio](https://kenney.nl/assets/rpg-audio) 与 [Mihacappy 的 steps_carpet.wav](https://freesound.org/people/Mihacappy/sounds/848210/)。后者明确是地毯实录，发布页标为 CC0，因此用于本版。

采用公开 Ogg 预览，不冒充无损原件；剪成四个 0.48 秒片段，转单声道、调整增益并淡化首尾。每实际移动约 0.86 米轮换一次，静止、悬空、屏幕镜头动画和传送均不响。来源、剪辑位置与许可同存 `assets/audio/foley/`，再生成脚本为 `tools/prepare_carpet_foley.py`。
