# 字体来源与许可

| 文件 | 字体 | 作者 | 许可 | 用途 |
|---|---|---|---|---|
| `BoutiqueBitmap9x9.ttf` | Boutique Bitmap 9x9 | scott0107000 | SIL Open Font License 1.1(全文见 `BoutiqueBitmap9x9-OFL.txt`) | 全局 UI 与对话字体 |

选择理由(依据 `docs/plans/2026-08-18-atmosphere-ui-camera-benchmark.md`):

- 研究指出本作最大的氛围短板是**没有任何自定义字体**,而对标作品普遍把字体当世界观载体;
- 9×9 点阵与「中式旧公共空间/旧登记系统」的方向一致,也贴合 P.T. 与模拟恐怖的公共信息屏质感;
- 单文件 2.1 MB 即覆盖简体中文、日文假名与拉丁字母,三语版本共用一套字形,不会出现某语言掉字;
- OFL 允许商业使用与随游戏分发,只要求保留许可文本(已随包保留)。

渲染约定:关闭抗锯齿与 hinting,字号吸附到 9 的整数倍(见 `babel_meme_game.gd` 的 `_ui_font_size()`),
保证点阵笔画不被重采样糊掉。
