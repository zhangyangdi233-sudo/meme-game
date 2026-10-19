# 地毯走路实录与许可核验

用户在听过新候选后明确选择：**A 原实录，恢复自然走路节奏**。
因此当前游戏重新使用 Mihacappy 的真实录音；不使用此前 B/C 的程序合成声。

## 核验并下载的素材

| 素材 / 作者 | 动作依据 | 许可 | 当前用途 |
|---|---|---|---|
| [steps_carpet.wav / Mihacappy](https://freesound.org/people/Mihacappy/sounds/848210/) | 作者录制地毯脚步，标签 walking；原录音约0.59秒一步 | [CC0](https://creativecommons.org/publicdomain/zero/1.0/)，可免费商用，无强制署名 | 用户选择的A，正在游戏内使用 |
| [01-24 Footsteps, Rug, Slippers, Slow Pace.wav / SpliceSound](https://freesound.org/people/SpliceSound/sounds/260116/) | 作者明确说明拖鞋在毯子上慢走 | CC0 | 已下载作试听与备用 |
| [walk carpet.wav / taure](https://freesound.org/people/taure/sounds/575321/) | 作者说明穿鞋走地毯；同一包内跑步单列 | CC0 | 已下载作试听与备用 |
| [Footsteps - Carpet / AlexMurphy53](https://freesound.org/people/AlexMurphy53/sounds/542059/) | 作者说明靴子踩地毯，标签heavy、walking | [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)，可免费商用但须署名、保留许可链接及修改说明 | 已下载作试听与备用，未进入游戏 |

核验日期：2026-10-19。使用原作者页面与 Creative Commons 官方许可，未把转载站的“免费”标签当授权。
完整官方HQ MP3预览、作者HTML与许可HTML保存在 `D:/aphasia/参考/20261019-carpet-walking/`。
HQ预览是有损文件，不称作原始无损WAV；当前A使用项目中保留的官方Ogg，以保持用户认可的原有音色。
备用来源清单与SHA256见参考目录的 `sources-manifest.json` 及 `alternate/download-manifest.json`。
作者的“不用于AI训练”意愿得到遵守，素材只用于游戏音频裁切和播放。

## 为什么A曾有跑步感

原A录音8.60秒包含15次落脚，测得相邻接触中位间隔约0.59秒。
旧游戏把单步重排到0.261秒，之后B/C版本为0.409秒；两者均快于原录音。
当前普通移动速度仍为3.3单位/秒，只将单脚触发距离调整到1.95，得到0.5909秒一步。
实际冲刺输入仍使用独立的0.3112秒步频。

A的四段0.48秒旧切片保持原先65Hz/1150Hz柔和滤波，完整滤波后取40–320ms的实体落脚部分，
边缘做6ms/18ms渐变。主体与旧A波形相关系数均高于0.9999999；没有重新合成或把录音拉长降调。
四个0.28秒片段在最低0.97音高下也能于下次跑步接触前结束，保留未结束不重启的保护。
当前运行增益仍为-20dB。

## 试听与验证

- 当前游戏素材与步频：`artifacts/carpet-walk-real-20261019/A-selected-natural-walking.wav`。
- 新录音的试听片段同目录，以 `02-SpliceSound`、`03-AlexMurphy53`、`04-taure` 开头。
- 试听均仅裁切/匹配音量，未改变原始走路速度；AlexMurphy53的试听是署名CC BY 4.0衍生片段。
- `tools/prepare_carpet_foley.py --verify` 核对源文件SHA256、每个输出SHA256及逐采样复现。
- `tests/test_carpet_audio.py` 验证实际PCM格式、四段差异、时长、非静音、无削波及切口平滑。
- Godot脚步28项通过，包含真实AudioStreamPlayer播放、自然走路间隔、冲刺余量、暂停/腾空/传送静音。
- 音频运行集成通过。报告保存于 `artifacts/revision-final/results-20261019-A-recorded-walk.json`。

以前以频谱比例或峰均比定义“厚毛毯”的测试已去除：它们会错误拒绝用户选定的真实A录音。
素材听感由用户试听选择决定，不能用频谱数字替代。
