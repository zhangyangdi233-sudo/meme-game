# 字体来源与许可

| 文件 | 字体 | 作者 | 许可 | 用途 |
|---|---|---|---|---|
| `BoutiqueBitmap9x9.ttf` | Boutique Bitmap 9x9 | scott0107000 | SIL Open Font License 1.1(全文见 `BoutiqueBitmap9x9-OFL.txt`) | 全局 UI 与对话字体 |
| `RobotoCondensed-VariableFont_wght.ttf` | Roboto Condensed(可变字重,游戏内取 Bold 700) | Christian Robertson / The Roboto Project Authors | SIL Open Font License 1.1(全文见 `RobotoCondensed-OFL.txt`) | 英文时的 Dialog 与「hold to restart」提示 |
| `NotoSansSC-Medium.otf` | Noto Sans SC Medium | Google / Adobe(Noto CJK,源自 Source Han Sans) | SIL Open Font License 1.1(全文见 `NotoSansCJK-OFL.txt`) | 简体中文时的 Dialog 与「长按重新开始」提示 |
| `NotoSansJP-Medium.otf` | Noto Sans JP Medium | Google / Adobe(Noto CJK,源自 Source Han Sans) | SIL Open Font License 1.1(全文见 `NotoSansCJK-OFL.txt`) | 日文时的 Dialog 与重新开始提示 |

## 点阵字体

选择理由(依据 `docs/plans/2026-08-18-atmosphere-ui-camera-benchmark.md`):

- 研究指出本作最大的氛围短板是**没有任何自定义字体**,而对标作品普遍把字体当世界观载体;
- 9×9 点阵与「中式旧公共空间/旧登记系统」的方向一致,也贴合 P.T. 与模拟恐怖的公共信息屏质感;
- 单文件 2.1 MB 即覆盖简体中文、日文假名与拉丁字母,三语版本共用一套字形,不会出现某语言掉字;
- OFL 允许商业使用与随游戏分发,只要求保留许可文本(已随包保留)。

渲染约定:关闭抗锯齿与 hinting,字号吸附到 9 的整数倍(见 `babel_meme_game.gd` 的 `_ui_font_size()`),
保证点阵笔画不被重采样糊掉。

## 正式字体(Dialog 与重新开始提示)

企划确认:泛用 Dialog(问句与按钮)与主选单的重新开始提示改用正式字体,依当前语言切换(见 `scripts/ui/locale_font.gd`);
其余 UI 仍用点阵字体。

- 来源:Roboto Condensed 取自 Google Fonts 仓库 `google/fonts` 的 `ofl/robotocondensed/RobotoCondensed[wght].ttf`
  与同目录的 `OFL.txt`;Noto Sans SC / JP 取自 `notofonts/noto-cjk` 的 `Sans/SubsetOTF/SC|JP/` 与 `Sans/LICENSE`。
- Roboto Condensed 官方只发布可变字重版本,游戏以 `FontVariation` 把 `wght` 轴设为 700 取得 Bold,未修改字体文件。
- 中日各用一套:同一个汉字在中文与日文的规范字形不同,共用会让其中一种语言看起来不对。
- 版权声明:Roboto Condensed 为 Copyright 2011 The Roboto Project Authors;Noto CJK 的版权声明(Adobe,保留字体名 'Source')
  内嵌在字体文件的 name 表中,随文件一起分发。
- 未做子集化:两套中日字体合计约 13 MB,之后若要缩减包体再另行处理。
- 渲染沿用 Godot 导入默认值(开启抗锯齿与 hinting),与点阵字体的约定不同。
