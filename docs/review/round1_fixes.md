# Round 1 修复记录(响应 round1_critic.md)

Builder 对 Critic 六维审查清单的处置。复验:全量测试套件 + test_flashback_sequence 新增用例。

## P1(全部修复)

| 条目 | 处置 |
|---|---|
| P1-1 双重 12px 错位 | ChairSeat 恢复同一局部坐标,错位只由 SceneryRoot 承担一次;测试新增"椅子局部坐标一致 + scenery 差值恰为 12px"断言 |
| P1-2 配色开局烘焙 | `_play_pollution_flashback` 在播放前用触发瞬间的 `_theme_color` 重新 `configure_colors` 并 `build_phases()` 重建;重建用立即 `free()` 防同名改名 |
| P1-3 headless 截帧报错 | `_capture_frozen_frame_texture` 增加 `DisplayServer.get_name()=="headless"` 守卫(沿用 `_capture_phone_layer_for_xray` 惯例) |
| P1-4 钉定断言永真式 | 改为逐项比较 anchors/offsets 全等 |
| P1-5 信号完成路径零覆盖 | 新增"自然走完时间线"用例:逐帧记录相位可见顺序 == PHASES 顺序,且日结由 `sequence_finished` 信号驱动 |
| P1-6 双重日结无防护 | 新增"第二次 finish 后 day 不变"断言 |

## P2(修复 8 条,搁置 3 条并说明)

已修:P2-1(时间线走完且信号未连接时自行 stop 收场)、P2-3(duck 改为延迟 0.28s 后 100ms 速降,与分镜"保持再死"一致)、P2-4(回声行正向断言 + segments 拼回关键句)、P2-5(断言措辞不再过度承诺)、P2-7(自然运行相位顺序测试即覆盖)、P2-8(移除未使用的 accent 配色)、P2-9(黑帧构建合并为带参单函数)、P2-11(WCAG 帮助函数计入退场翻转,测试同步)。

搁置(记录在案):

- P2-2 WAV 3.55-3.70s 静默尾:保留。finish 必然 stop 音频,尾段是防御性余量,无听感影响。
- P2-6 pending=true 存档卡死:当前流程产不出该存档(闪回期间输入锁定、日结即清 pending);列入 Round 5 防御性加固清单,避免本轮扩大改动面。
- P2-10 `language_corruption_content.gd.uid`:Godot 4.6 导入器生成的合法 UID 文件,按引擎官方建议应入库。
