# 地下室拾取手机

`phone_pickup.blend` 是可编辑源文件，`build_phone.py` 可重新构建并导出 `assets/chapter1/phone_pickup.glb`。

外形参考用户指定的本地《Endless Monday: Dreams and Deadlines》手机：深灰紫窄边框、宽听筒凹口、米白屏幕。网格与材质在本工程重新制作，没有导入参考游戏的纹理或网格。屏幕小裂纹、两款应用图标由游戏 UI 绘制。

- 220 个三角形，10 个网格，5 个纯色材质，无外部纹理。
- 尺寸约 0.076 × 0.01018 × 0.155 米；原点在中心，屏幕朝 +Y，手机顶部朝 -Z。
- 实体由 `ChapterWorld` 放置在第一地下室楼梯附近的桌面；F 拾取后隐藏，所有权随进度保存。

模型正面、透视和重新导入预览，以及检查结果保存在 `D:/aphasia/outputs/phone_revision_20261014/`。
