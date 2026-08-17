# Round 2 Evaluator 报告 — char-level social pickup

- 评审对象:`7d26f25`(fix)+ 父提交 `ff1b18b`(feat)= Round 2 全部改动
- 方法:34 个 gd 测试全部亲自实跑 + 4 个自写 /tmp 运行时探针(场景实例化)+ 1 次 /tmp 变异体反证(不触碰仓库)+ 逐条 diff/落点核对
- Godot:4.6.3-stable headless(`HOME=/tmp/godot_home`)。日期:2026-08-17

## 最终判定:带条件完成

五条最初目标全部达标(证据见 §6);P0-1 经我独立探针 + 变异体反证确认真修;修复清单声称与代码落点一一吻合;搁置理由逐条查证属实。唯一悬置条件:P1-2 "随机放在帖子里"的解读(手工分配、每局相同)Builder 自记"征求取舍"待用户签字——不阻塞我方目标清单(其中无"随机"字样),但按 Critic 引用的用户原话属未闭环项。另有 2 个我新发现的小瑕疵(§5,不阻塞)。

---

## 1. 提交与工作区

- `git log`:`7d26f25 fix: apply round-2 critic fixes ...`(2026-08-17 10:55)与 `ff1b18b feat: char-level social pickup ...`(10:13),构成 Round 2。
- `git status --porcelain` 评审前后均为空(`.godot/` 在 .gitignore 内)。全部改动 7+9 文件,新增系统集中在 `scripts/narrative/pickup_char_pool.gd`(501 行)、`scripts/ui/pickup_flight_layer.gd`、`scripts/babel_meme_game.gd`、`scripts/meme_game_state.gd`、`tests/test_pickup_char_flow.gd`。

## 2. 全量测试(34 个逐个实跑)

命令:`HOME=/tmp/godot_home <godot> --headless --path . --script res://tests/<t>` 逐个执行,记录 exit code(明细 /tmp/eval/results.txt)。

**结果:34/34 exit=0。** 33 个打印 "... tests passed";`test_hand_tracking_runtime` 打印设计内跳过("set BABEL_TEST_CAMERA_RUNTIME=1"),与 Round 1 评审时行为一致,非回归。退出时的 RID 泄漏 ERROR 行为 headless 通例噪声(绿色运行同样存在),不影响判定。

## 3. P0-1 是否真修 —— 判定:真修(探针 + 变异体双重实证)

代码落点:`scripts/babel_meme_game.gd:6437-6442` 新增 `_notebook_window_control()`,取 `_draggable_windows.get("app:notebook")`(注册键约定见 `:3570`);`_notebook_flight_target()`(`:6445`)与 `_squash_notebook_window()`(`:6452`)均改经它解析。全仓已无 `_draggable_windows.get("notebook")` 残留(grep 0 命中)。

我的探针(/tmp/probe_eval_p0.gd、/tmp/probe_eval_p2.gd,均 fail=0)实测:

| 检查 | 结果 |
|---|---|
| 笔记本窗口打开后 `_notebook_flight_target()` | (244,86),落在窗口 rect [(188,46), 610x736] **内**(Critic 修前实测为窗外兜底 (84,64)) |
| `_move_window_for_test("app:notebook",(60,90))` 后 | 目标 (304,176),位移恰为 (60,90),仍在 rect 内 → **跟随** |
| 窗口隐藏时 | 兜底 (84,64)(设计内分支) |
| 真信号路径 `meta_clicked.emit("门")` | 收字成功、扣 1 行动、飞行层 `is_animating()`、log "一个字进入了笔记本。" |
| 自然落地 | `pickup_landed` 发出(实测 ~1.87s,三拍动画走完);`_notebook_squash_tween` **非空且 valid** |
| squash 真实播放 | 逐帧采样窗口 scale,峰值恰为设计值 (1.05, 0.96),回落 (1,1) |
| 飞行中途再拖窗口 (120,60) | 目标 getter 实时重解析;字形最终中心距新目标 **1.3px**、在窗口 rect 内落地 |

**变异体反证**(/tmp/mutant 完整拷贝,仓库零触碰):把 `app:notebook` 改回 `notebook` 后跑 `test_pickup_char_flow` → exit 1,恰好红在三条新断言:"notebook window control must resolve via its app: key" / "flight target must track the notebook window position" / "landing must squash the notebook window"。**新测试是真回归闸,P1-1 的"永真断言"问题已消除。**

## 4. round2_fixes.md 声称修复 vs HEAD 落点(逐条核对,全部吻合)

| 条目 | 声称 | 落点核验 | 运行验证 |
|---|---|---|---|
| P0-1 | `_notebook_window_control()` + 测试双断言 | babel:6437-6442;测试 :162-172(跟随)、:173-186(落地+受击) | §3,含变异体红 |
| P1-1 | 真信号路径/跟随断言/落地受击/转义断言 | 测试 :157(`meta_clicked.emit`)、:152(转义)、:162-186 | 变异体证明非永真 |
| P2-1 | 飞行层 z 90→97 | babel:6337(=97);日结 :6006(=95);闪回 :6137(=100) | 探针运行时读值 97/95/100,同一 `_ui_root` 下 z 生效 |
| P2-3 | 哨兵法转义 + 回归断言 | babel:5130-5133(`String.chr(1)`);测试 :152 | 探针:`"["`→`"[lb]"`;`"[b]开[/b]"`→`[lb]b[rb]开[lb]/b[rb]` 无级联 |
| P2-5 | EN 大小写不敏感,显示原文/meta 规范形 | babel:6374-6381(`slice.to_lower()`、`matched_display`) | 探针:`[url=the]The[/url]`、`[url=I]i[/url]`;Doors/doorway 不误亮(边界保持) |
| P2-8(并入) | `is_word_character` 单一事实源 | pool:468 公开静态;babel:6399/6402 与 validator :459/461 共用;`_is_ascii_word_character` 已删 | 探针:validator 与 UI 对句首大写判定一致。注:边界"遍历"仍有 index 版/find 版两份形态,仅字符分类归一——比 Critic 原方案(整段调池方法)保守,实质风险点已除 |
| P2-7 | `is_unit_seeded_in_post` → not-in-post | state:1389-1391;pool:473-484(校验帖子**实际**埋字句+评论文本) | 探针:`灯@floor_13` 拒 not-in-post;未知 post 拒;测试 :80-81 覆盖 |
| P3-1 | 落地清理 tween 列表 | flight_layer:112 filter | 探针:两次飞行后残留 ≤1(自身回调期内暂存,下次落地清除,有界) |
| P3-2 | 字瓦片 MOUSE_FILTER_IGNORE | babel:4818-4819 | 探针运行时确认 |
| P3-6 | station_lit EN 句重写 | pool:269 "By morning the exit exists somewhere else." | 探针确认 |

## 5. 搁置项理由查证(重点 P2-4 / P2-6)

- **P2-4(正文不发光)— 理由属实**:`babel:4420` 帖子正文确为 `_label(_corrupt(str(post["text"])), ...)` 普通 Label,正文渲染要过语言污染替换,污染后的文本与池单位匹配天然互斥——这正是 Critic 自己在 P2-4 中承认的冲突。"埋字句+评论承载拾取的分层"是真实设计而非托词。诚实。残留观感问题(正文同字既不发光也不灰化)仍在,已如实记录。Critic 提的最小替代(正文已拾字灰化)未做,属可接受的范围裁剪。
- **P2-6(日文形态学)— 理由属实且有数据佐证**:我核对种子文本,ある/いる 的**合法埋点本身就前接平假名助词**——"別の場所にある"(pool:268)、"地図にある"(:348)、"まだいる?"(:328)、"内にいる。外にもいる"(:368)。若按 Critic 启发式禁"假名串中段匹配",这些 validator 强制可达的埋点全灭,文案须整体重写。"无分词器下接受超集、记录为已知限制"是诚实的工程取舍(代价:「歩いている」补助动词仍发光,语言学瑕疵保留)。
- **P2-2(0.22s 锁内连点被吞)— 理由属实**:锁来自既有全局约定 `_play_action_spend_animation`(babel:5948 `_set_input_locked(true)`,0.08+0.14s)。我的探针(/tmp/probe_eval_lock.gd)复现:锁内点击静默丢弃、锁释放后同一点击成功——影响窗口有界(~0.22s),与文档描述一致。
- **P2-9(窄屏)/ P3-4 / P3-5**:归第 3 轮,排期性搁置,宽屏默认布局(笔记本左上)即当前验收路径,可接受。
- **P1-2(随机)**:fixes 文档如实标注"手工分配+超集发光,非每局随机,已向用户说明并征求取舍"——满足 Critic "不得默默通过"的程序要求;**取舍本身待用户签字,是本判定唯一悬置条件**。

**我新发现的两个小瑕疵(不阻塞)**:
1. **P2-10 在 fixes.md 无处置行**(记账缺口)。实际:子项 2(转义测试)、3(en/ja 评论断言 :215-216/:224-226)已做;子项 1 部分(状态层末行动→`needs_day_settlement`,测试 :111-118,非 UI 级转场);**子项 4 未做**——测试中免费二拾仅隔 2 个 process_frame 便调 `_on_pickup_unit_meta`,依赖重场景帧耗 >0.11s 使 0.22s 锁恰好过期(本机 3/3 次绿,属机器相关的潜在 flake)。
2. **Critic 达标表一处证据不准**:「门可以打开」五字并非全在 floor_13 一帖——"以"仅埋于 access_record("可以进,不可以出",pool:376-380)。不影响目标 3:12 帖 Day 1 全部可见,五字当日均可达;en "door can be opened" 确为 floor_13 单帖闭环、ja ドア+ひらく 同帖闭环(探针验证)。

## 6. 对照最初目标逐条判定

| 目标 | 判定 | 证据 |
|---|---|---|
| 1. 中文逐字;20-30 字备于帖内;帖内必含同字 | **达标** | 探针:zh 池=30 个单字(ja 20/en 24),三语言无重复;`validate()` 三语言 ok=[](每单位必埋、埋字文本必含);真信号点击帖内文字收字实证;`not-in-post` 校验杜绝帖外拾取。("随机"解读悬置 → P1-2 条件) |
| 2. 评论区 + 匿名网友 | **达标** | census 探针:12/12 帖 × zh/ja/en 均有 ≥1 条评论且 handle/time/text 齐全;运行时 SocialCommentsHeader/SocialCommentText0 三语言渲染实证;文风(02:13 时间戳、"do_not_knock"/"既読つけるな" 匿名 handle)符合都市传说设定 |
| 3. 三语言可组完整句,S/V/O 各≥2 | **达标** | role_word_counts:zh 7/9/8、ja 7/6/9、en 7/9/8,negation zh2/ja1/en2;词典组成单位全在池内、池单位全可达(validate);样例句可达性实证(en 单帖、zh 跨帖 Day1、ja 单帖) |
| 4. 放大居中→缩入左上笔记本 + 已拾取提示 | **达标(本轮修复后)** | §3 全链路:三拍动画(0.36 放大 2.6x 居中→0.5 定格→0.30 缩入)、落地信号、窗口受击 squash、拖窗跟随 1.3px 精度;提示四重实证:首拾成本提示(SocialPickupCostHint)、拾取/重复 log 文案、已拾字灰色残留(`[color=#8b8f84]`)、笔记本字库瓦片 |
| 5. 既有系统零回归 | **达标** | 34/34 全部亲跑 exit 0(§2);Round 2 未触碰旧词签/存档/本地化路径(diff 范围核实);save/meme_game_state/localization/playthrough 等全绿 |

## 7. 复跑清单

- 测试明细:/tmp/eval/results.txt;各测试日志 /tmp/eval/log_*.txt
- 探针:/tmp/probe_eval_p0.gd(P0-1 主链)、/tmp/probe_eval_p2.gd(修复面+中途拖窗)、/tmp/probe_eval_lock.gd(P2-2 界定)、/tmp/probe_eval_census.gd(12 帖 census + 组句)
- 变异体:/tmp/mutant(工作树拷贝,`app:notebook`→`notebook`),日志 /tmp/eval/mutant_run.log
- 命令:`HOME=/tmp/godot_home /root/work/godot_bin/Godot_v4.6.3-stable_linux.x86_64 --headless --path <dir> --script <file>`
