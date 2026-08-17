# Round 1 Evaluator 判定报告 — 60% 污染闪回重做

评定者:独立 Evaluator(不改代码)。评定日期:2026-08-17。
仓库:/root/work/memes-minigame @ HEAD `ca291c6`。所有验证均为本人实际运行,非纸面核对。

---

## 步骤 1:提交链与改动面

命令:`git log --oneline -8`、`git show --stat HEAD`、`git show --stat HEAD~1`、`git status --short`

```
ca291c6 fix: apply round-1 critic fixes to flashback director
ead5a03 feat: rebuild 60% pollution flashback as deterministic eight-beat director
fe42758 docs: add deep-research reports and round-1 implementation plan
```

- HEAD(ca291c6)改动 5 文件 +264/−22:`docs/review/round1_critic.md`(142 行)、`round1_fixes.md`(24 行)、`babel_meme_game.gd`、`pollution_flashback_director.gd`、`test_flashback_sequence.gd` —— 即 Critic 报告与修复同一 commit 落地。
- HEAD~1(ead5a03)改动 9 文件 +782/−152:新增 `scripts/ui/pollution_flashback_director.gd`(444 行)、`tests/test_flashback_sequence.gd`(193 行),重写 WAV(70,604→163,214 字节),storyboard 更新为 v2。
- 工作区干净(`git status --short` 无输出)。三段式提交链(研究→实现→审查修复)与验收要求一致。

## 步骤 2:旧实现移除 + 新实现确属"借鉴研究"

### 2a. 旧随机乱字方案已整体移除

命令:`git show HEAD~2:scripts/babel_meme_game.gd | grep -B2 -A40 "_scramble_flashback_words"`

旧实现(HEAD~2 第 6184-6206 行)是 8 条固定短语轮转 + 每 step 用 `randf_range` 随机摆位置/旋转/透明度的乱字黑屏:

```gdscript
label.position = Vector2(randf_range(-80.0, viewport_size.x - 120.0), randf_range(0.0, ...))
label.rotation = deg_to_rad(randf_range(-7.0, 7.0))
label.modulate.a = randf_range(0.45, 1.0)
```

HEAD 中 `grep -i scramble scripts/babel_meme_game.gd` = 0 命中;新 director `grep "randi\|randf\|shuffle\|rand"` = 0 命中(且 `test_flashback_sequence.gd:71-75` 用源码扫描把"零随机"钉成测试)。旧方案确认被整体替换,而非叠加。

### 2b. "研究结论 → 代码落点"对应表(9 组,实测核对)

研究报告 `docs/research/flashback_deep_research.md`(156 行,§0-§8,40+ 具名来源含 W3C/IEEE/rose-engine 官方页);实现 `scripts/ui/pollution_flashback_director.gd`(下称 director)+ `scripts/babel_meme_game.gd`(下称 game)+ `tools/generate_audio_assets.py`。

| # | 研究结论(出处) | 代码落点(实测证据) |
|---|---|---|
| 1 | Mouthwashing 公式:冻结当下→声音先死→硬切,不做 jump scare(§0.1、§1、技法#1/#5、§4 防惊吓三原则) | game:6102 `_capture_frozen_frame_texture()` 截当前帧;director PHASES `freeze` 0.00-0.50 展示;WAV 实测底噪 0-0.34s rms=0.203 → 0.36-0.50s rms=0.045 → gap 0.000(声音死在画面切黑之前);game:1437-1439 循环底噪 hold 0.28s 再 0.10s 速降;全片无 riser、无冲镜元素 |
| 2 | 今敏同构匹配剪辑:恒定元素钉死,背后世界整体替换(§0.2、§2(a)(c)、技法#3) | director:317-329 两场关键句 Label 文本/字号 32/锚点/offset 完全一致;:262-266 仅 SceneryRoot 整体右移 `DOCTOR_OFFSET_PX=12`;test:104-128 逐项钉定 anchors/offsets 相等 + 错位恰 12px |
| 3 | 污染元数据不污染正文(§0.3:DDLC 名牌/海猫真值色/Fata Morgana 隐名;技法#4) | director:303 名牌「玩偶」↔『医生』(引号体系互换);:438-443 名牌边框圆角↔直角;:343 归属卡 `[s]玩偶[/s]　[u]医生[/u]`;关键句字形零变化(test:130-134 断言只许名牌不同) |
| 4 | 黑帧是 150-250ms 的阅读标点,不是频闪(§4"黑帧=标点") | PHASES:black_gap_a 0.20s / black_gap_b 0.17s,均落 150-250ms 区间;gap_b 载空白说话者框【　　　】;test:41 每相位≥120ms、:62-64 黑帧≥150ms |
| 5 | 把 WCAG 2.2 三闪预算从审美自觉变成单元测试(§4 WCAG 落地、§5 防闪烁自检、§7 核查表) | PHASES 每相位带 `luminance` 元数据;director:52-69 `max_luminance_flips_in_window()` 含退场翻转;test:46-59 独立重算任意 1s 滚动窗 ≤3 |
| 6 | 静默是最响的事件;音量天花板压低(§0.4、技法#5、§4(b)) | WAV gap A 实测 rms=0.00000(数字纯零);播放电平 -8dB(game:1295);全轨最大段 rms=0.203(底噪),无爆点 |
| 7 | 妄想代理人"复述即污染"/重复错位(§2(d)、技法#8) | director:356-379 triple_echo 三行同句各缺一个不同分段、行间 9px 错位;test:160-169 正向断言每行含另两段 + 分段拼回完整关键句 |
| 8 | L-cut/反向混响音尾离线烘焙(§0.4、技法#7、§5 音频) | generate_audio_assets.py `build_flashback_samples`:2.60s 门扣带反向渐强尾;实测 2.57-2.95s rms=0.069,无响度尖峰 |
| 9 | 半阈下帧:单次 100-150ms、不重复闪烁(§2 闪灵、技法#12);梦日记式不解释(§1) | director:24 `UNREGISTERED_CARD_FLASH=0.12`(120ms 单次),:118-123 出现一次即黑场收尾,零解释;test:66-68 钉 60-200ms 区间 |

合理偏差(已有解释):耳鸣用 9.7kHz 而非研究建议的 12-14kHz —— WAV 采样率 22050Hz 的 Nyquist 上限是 11.025kHz,12-14kHz 物理上不可表示,9.7kHz 是工程必然;技法#9/#10(色差/VHS shader,★★★★ 非核心)未采用,storyboard v2 以纯 Control 节点方案自洽记录,五星核心技法(#1-#6)全部落地。

音画对位实测(python 解码 WAV 分段 RMS,与 storyboard 时间线逐拍一致):

```
roomtone hold  0.00-0.34 rms=0.203   | tinnitus     2.37-2.57 rms=0.018
roomtone dying 0.36-0.50 rms=0.045   | door+reverse 2.57-2.95 rms=0.069
gap A          0.50-0.70 rms=0.00000 | residue      2.95-3.28 rms=0.146
cloth/doll     0.72-1.40 rms=0.051   | save click   3.40-3.45 rms=0.048
phone voice    1.64-2.32 rms=0.074   | TAIL         3.55-3.70 rms=0.00000
```

相位表连续性人工复核:0.50/0.70/1.45/1.62/2.37/2.57/2.95/3.30/3.55 首尾相接无缝,`TOTAL_DURATION=3.55` 与相位和一致(test:37-44 亦断言)。

## 步骤 3:全量测试实跑

命令:33 个 `tests/test_*.gd` 逐个 `Godot_v4.6.3 --headless --path . --script`,每个 120s 超时。

```
PASS ×33(test_audio_runtime … test_tutorial_director,含 test_flashback_sequence)
TOTAL PASS=33 FAIL=0
```

契约保留证据:既有契约测试(`test_audio_runtime`、`test_day_transition`、`test_save_progress`、`test_playthrough_flow` 等)全部在通过集合内;`test_flashback_sequence` 本身断言节点名 `PollutionFlashbackOverlay`、z_index=100、finish 直接日结不叠加过场、输入锁开合。

## 步骤 4:音频资产验证

命令:`python3 tools/generate_audio_assets.py --verify; echo EXIT=$?`

```
EXIT=0
```

仓库 WAV `sha256sum` = `154a71cbcd0d…4b4584`,与 `tools/generate_audio_assets.py:22` 的 `EXPECTED_SHA256` 逐字一致;`:183` 确认由 `build_flashback_samples(3.70)` 确定性合成。

## 步骤 5:六条 P1 逐条指认(HEAD 中的修复位置)

| P1 | 修复位置(实读代码指认) | 判定 |
|---|---|---|
| P1-1 双重 12px 错位 | director:266 仅 `scenery.position.x += DOCTOR_OFFSET_PX` 一次;:272-273 `chair_seat.position = Vector2(-140.0, 10.0)` 恢复同一局部坐标(注释"错位只由 SceneryRoot 承担一次");test:123-128 断言 scenery 差值恰 12.0±0.01 且椅子局部坐标相等 | 已修 |
| P1-2 配色开局烘焙 | game:6088-6094 `_play_pollution_flashback` 播放前用 `_theme_color(...)` 重新 `configure_colors` + `build_phases()`;`_theme_color`(:5278)→ `_active_palette()`(:5272-5275)在 pollution≥60 时返回 `POLLUTION_PALETTE_5`(flash_text 39FF14,即分镜"荧光绿"),不再是开局 PALETTE_1 的 9CFF24;director:80-83 重建改用立即 `free()` 防同名改名 | 已修 |
| P1-3 headless 截帧喷错 | game:6104 `if viewport == null or DisplayServer.get_name().to_lower() == "headless": return null`,与 `_capture_phone_layer_for_xray`(:869)惯例一致;实跑 flashback 测试日志 `grep -c 'texture_2d_get\|Parameter "t" is null'` = 0(仅余 4 条与此无关的引擎退出期 RID 清理噪声) | 已修(实测无喷错) |
| P1-4 钉定断言永真式 | test:104-112 改为 offset_left/right/top/bottom + anchor_left/anchor_top 逐项 `==`,永真的 `or get_combined_minimum_size()` 右支已删除 | 已修 |
| P1-5 信号完成路径零覆盖 | test:195-225 新增自然走完用例:play 后逐帧记录相位可见顺序,不手动调 finish,等 overlay 自行隐藏(帧数护栏 100000),断言 day+1 由 `sequence_finished` 驱动、输入解锁、`seen_order == PHASES 顺序`(9 相位各按序出现一次,同时覆盖 P2-7) | 已修 |
| P1-6 双重日结未钉住 | test:185-187 第二次 `_finish_pollution_flashback()` 后 `_assert_eq_int(game.day, 2, "a second finish call must not settle a second day")` | 已修 |

六条全部在 HEAD 代码/测试中指认到位,且我实跑的 33/33 里 `test_flashback_sequence` 通过,即修复断言在真实运行中成立。

## 步骤 6:三条搁置 P2 理由核查

| P2 | 声称理由 | 核查结论 |
|---|---|---|
| P2-2 WAV 3.55-3.70s 静默尾保留 | "finish 必然 stop 音频,尾段是防御性余量,无听感影响" | 成立。实测尾段 rms=0.00000(数字纯零);game:6118-6119 finish 无条件 `_flashback_audio.stop()`,尾段确实不可达也不可闻。小瑕疵:storyboard 第 4/17 行仍写"3.70s 含尾",措辞略有误导,但搁置决定本身有 fixes 文档记录 |
| P2-6 pending=true 存档卡死 | "当前流程产不出该存档;列入 Round 5" | 成立。核查:`_begin_game_session`(game:665 起)确无 pending 处理;pending 唯一消费点在 `_after_effective_action`(:6457-6459);`_save_progress()` 调用点仅 727/3432/3522 三处,均在闪回输入锁(`_unhandled_input` :537 早退)/遮罩之后不可达;`grep NOTIFICATION_WM_CLOSE` = 0,窗口关闭不存档。正常游玩确实产不出该档 |
| P2-10 `.uid` 文件入库 | "Godot 4.6 导入器生成的合法 UID 文件,官方建议入库" | 成立。文件内容 `uid://dsgyb7jc7qloj` 为合法 UID 格式;Godot 4.4+ 官方指引即要求 `.uid` 随脚本提交版本库 |

另抽查 8 条"已修 P2":P2-1(director:146-151 完成后信号未连接时自行 stop)、P2-3(game:1437-1439 duck 改 0.28s hold + 0.10s 速降 = 0.38s,与分镜"保持再死"一致)、P2-9(黑帧构建合并为单函数 `_build_black_gap_phase(…, with_empty_speaker_plate)`)、P2-11(helper :59-60 计入退场翻转)、P2-8(`accent` 键已从 director 与两处 configure 调用移除)、P2-4/P2-5/P2-7 见测试指认 —— 均属实。

---

## 最终判定:完成

理由:

1. **最初目标达成**:简陋的随机乱字黑屏被整体移除(2a 有 diff 证据),替换为 444 行数据驱动八拍导演;deep research 报告(156 行、40+ 具名来源)与实现方案(storyboard v2)均已入库,且"研究→代码"存在 9 组可指认的具名技法对应(2b 表),不是贴皮引用。
2. **验收项全部实证通过**:33/33 测试本人实跑全绿;`--verify` EXIT=0 且 WAV 哈希与期望值一致;音画对位逐拍 RMS 实测与分镜一致;既有契约(节点名/信号/直接日结/音频 duck/存档)由通过的既有测试集证明保留。
3. **Builder/Critic 循环真实闭环**:round1_critic.md 是有牙齿的审查(6 P1 + 11 P2,含对抗性探针方法学),round1_fixes.md 的处置逐条可在 HEAD 指认;六条 P1 全部修实,三条搁置 P2 理由经独立核查全部成立。
4. **遗留为零风险级**:仅两处文案级瑕疵(storyboard"含尾"措辞;技法#9/#10 未采用属已记录的范围取舍),不影响功能、契约或可访问性承诺,不构成扣留完成判定的条件。
