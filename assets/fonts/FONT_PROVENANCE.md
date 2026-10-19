# 字体来源与许可

| 文件 | 字体 | 作者 | 许可 | 用途 |
|---|---|---|---|---|
| `BoutiqueBitmap9x9.ttf` | Boutique Bitmap 9x9 | scott0107000 | SIL Open Font License 1.1(全文见 `BoutiqueBitmap9x9-OFL.txt`) | 全局 UI 与对话字体 |
| `MaShanZheng-Regular.ttf` | Ma Shan Zheng | The Ma Shan Zheng Project Authors | SIL Open Font License 1.1（全文见 `MaShanZheng-OFL.txt`） | 第二层纸条中文红色手写原件；不替换全局字体 |

Ma Shan Zheng 来自 [Google Fonts 固定版本](https://github.com/google/fonts/tree/406197b91ff39a93061c2c2eeaee67ddf2ae1f0d/ofl/mashanzheng)，原文件未修改。SHA-256：`6D2546BB189C732A8CA29AF9E22457B152387D158AA459E4AC2CE1E51788B7FB`。选型、许可核对和本地参考清单见 [纸条研究](../../docs/research/2026-10-19-note-inspection.md)。

选择理由(依据 `docs/plans/2026-08-18-atmosphere-ui-camera-benchmark.md`):

- 研究指出本作最大的氛围短板是**没有任何自定义字体**,而对标作品普遍把字体当世界观载体;
- 9×9 点阵与「中式旧公共空间/旧登记系统」的方向一致,也贴合 P.T. 与模拟恐怖的公共信息屏质感;
- 单文件 2.1 MB 即覆盖简体中文、日文假名与拉丁字母,三语版本共用一套字形,不会出现某语言掉字;
- OFL 允许商业使用与随游戏分发,只要求保留许可文本(已随包保留)。

渲染约定:关闭抗锯齿与 hinting,字号吸附到 9 的整数倍(见 `babel_meme_game.gd` 的 `_ui_font_size()`),
保证点阵笔画不被重采样糊掉。

上述点阵渲染约定只适用于 Boutique Bitmap 9x9。纸条的 Ma Shan Zheng 保留原字体抗锯齿，以阅读层宽度计算字号，避免毛笔轮廓被全局点阵规则改写。
