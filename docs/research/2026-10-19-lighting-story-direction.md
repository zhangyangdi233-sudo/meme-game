# CRT 记忆段落：电影布光与叙事研究

日期：2026-10-19。目标是依照用户给出的白光门观感，软化 CRT 顶光，而非改为另一种叙事风格。以下把资料结论与本项目的设计推断分开。

## 一手来源与采用理由

| 来源 | 可用结论 | 本场景的应用（设计推断） |
| --- | --- | --- |
| [ARRI Lighting Handbook](https://www.arri.com/resource/blob/83996/409091c612f371b0c68b41d9dcb636db/arri-lighting-handbook-english-data.pdf)，印刷页5–9、12–17 | 光的软硬取决于发光面积与扩散，不能靠单纯降低强度改变；漫射光仍需控制溢出。主光表现体积，补光控制暗部和情绪。 | 把主光和可见雾束分开；保留壳体的亮面/中间调/暗面，羽化雾束的侧边，不给整个黑场加环境亮度。 |
| [ASC：Terror Through Lighting](https://theasc.com/article/terror-through-lighting/)，Roy H. Wagner 访谈 | 有选择地展示物件、安排阴影和色彩，可以改变观众对安全与未知的判断。布光应服务于镜头的心理意图。 | CRT 是记忆与依靠，白光使它成为视线目标；四周留黑，保留不安。不要用大块亮锥把注意力从电视移走。 |
| [ASC：Lighting Spectre](https://theasc.com/post/the-film-book/lighting-spectre/)，Hoyte van Hoytema 与 David Smith 访谈 | 大面积顶部柔光能保持低照度、低调氛围，又留下可读细节；光源方向与控制比一味增加亮度更重要。 | 顶部仍是唯一主要方向，控制 CRT 塑料外壳高光，少量柔和包裹；不使用均匀正面补光把体积抹平。 |
| [Godot 4.6 体积雾文档](https://docs.godotengine.org/en/4.6/tutorials/3d/volumetric_fog.html#faking-volumetric-fog-using-quads) | Forward+ 支持体积雾；透明 Quad 可跨渲染器近似局部雾，但必须考虑透明排序、进入雾体时的效果及覆盖面积成本。 | 相机只做有限旋转、角色原地固定，柔边片适合这个局部镜头。仍需两个渲染器实测，并避免在 CRT 表面叠一层白纱。 |
| [Godot 4.6 后处理文档](https://docs.godotengine.org/en/4.6/tutorials/3d/environment_and_post_processing.html#glow) | Compatibility 的 Glow 与 Forward+ 实现不同，部分参数不可用。 | 用轻量柔边材质建立基本效果；Glow 只增强亮部，不依赖其模糊范围来隐藏硬边，更不依赖景深。 |

ARRI PDF 存于本机 `D:/aphasia/参考/20261019-cinematic-lighting/arri-lighting-handbook.pdf`，仅供阅读，不是可分发游戏素材。其余链接保留为出处，不复制电影媒体。

## 镜头中的亮度顺序

电视屏幕和机壳首先可辨；顶部方向感其次；空气中的光最后才被察觉。雾束应在侧边、顶端及下端逐渐消失，不能出现三角形硬轮廓、底部圆盖或整块灰板。轻微光晕只在亮区附近出现，字幕仍清楚，黑背景仍黑。

这不是物理摄影棚复原：原始要求是突然隔离到黑场，因此保留这种主观记忆视角，只借鉴扩散、控光和明暗层次。进入时相机缓动、背景瞬切；结束后回到原场景与原坐标，临时灯束不残留。

## 与稳定性的共同约束

[Godot issue 121989](https://github.com/godotengine/godot/issues/121989) 和 [修复 PR 122064](https://github.com/godotengine/godot/pull/122064) 说明旧版 Forward+ 在 mesh layer 改变后可能残留灯光配对。本项目不升级引擎：教学视图使用独立、固定层的视觉副本，避免改变场景原 CRT 的渲染层。美术调整不得再次引入相同的动态层修改路径。

实际参数、方案比较、截图和测试证据由同目录的本轮技术报告补充。
