# Rain 性格与两份叙事参考的可读性研究

研究日期：2026-10-05。用途：为《Aphasia》的蛋黄酱先生提炼行为与语言规律，并核实 Subliminal 开场旁白、Endless Monday NPC 对话是否真正可读。

本次确实读到了 Cosmic Ultramarine 的 Rain 中文对白。Subliminal 只读到旁白音频条目名，Endless Monday 只读到程序字符串与资源路径；没有拿到后二者的对白正文。因此，本报告不把概括的引导技巧或 NPC 风格归因于后二者。

## 文件盘点和可复核范围

| 参考 | 本地资源情况 | 本次实际结果 |
| --- | --- | --- |
| Cosmic Ultramarine | 157 文件，Unity 2019.4.15f1 资源；9 个 Addressables bundle | 静态展开 6 个小于 20 MB 的 bundle；其中 fd4485b0fe34994badfa5f0b4f840076.bundle 含 187 个可解码 UTF-8 TextAsset。未展开另外 3 个大型 bundle，未读其媒体内容 |
| Subliminal | 81 文件；UE pak/utoc/ucas、FMOD bank、18 个 mp4 | 读取 Narration.bank 的 FSB5 名称表共 236 条；读取 pak 尾部，索引加密标志为 1。未解密索引，未解码或转写旁白，未观看视频 |
| Endless Monday Dreams and Deadlines | 31 文件；GameMaker data.win、data 下正文和本地化 dat、声音 dat | 完整提取 data.win 的 STRG 共 10077 条，检索对白、角色、加载、加密相关项；正文 dat 未读为文本。未运行游戏、没有从程序日志推断角色性格 |

所有原始参考均保持不变。读取脚本、文件统计、资源定位、提取文本位于 [reference_extracts/voices](D:/aphasia/outputs/narrative/reference_extracts/voices)。脚本只读本地数据并将结果写到自己的目录，不执行提取出的 Lua、游戏程序或远程代码；没有安装依赖、批量删除或使用 Git。

### Rain 原始来源与定位方式

原包：[fd4485b0fe34994badfa5f0b4f840076.bundle](<D:/aphasia/参考/Cosmic Ultramarine/Cosmic Ultramarine_Data/StreamingAssets/aa/StandaloneWindows/fd4485b0fe34994badfa5f0b4f840076.bundle>)。内部节点为 `CAB-07f6f0179661b2a4319a74c09b96188e`。下列行号是 TextAsset 提取后的行号，二进制原包本身没有行号。各 TextAsset 的 path_id 和节点内 object_offset 保存在 [cosmic_manifest.json](D:/aphasia/outputs/narrative/reference_extracts/voices/cosmic_manifest.json)。

| 本报告简称 | TextAsset 和可读副本 | 实际阅读范围 |
| --- | --- | --- |
| normal | [cfg_lang_sc_normal_detail](D:/aphasia/outputs/narrative/reference_extracts/voices/cosmic/fd4485b0_3822026114910763576_cfg_lang_sc_normal_detail.txt) | 开场 1001010301–1001010311；Rain 初见 1002100301–1002100601、休息 1006030301–1006030601、童年回忆 1009030301–1009030306、门前 1010030301–1010030305；检索末段 Rain／Rain？引用作身份排除 |
| topic | [cfg_lang_sc_topic_detail](D:/aphasia/outputs/narrative/reference_extracts/voices/cosmic/fd4485b0_-3116581732500876400_cfg_lang_sc_topic_detail.txt) | 全表 131 条，行 2–132；以 cfg_rain_topic_detail 的同 ID 映射确认用途 |
| memory | [cfg_lang_sc_memory_detail](D:/aphasia/outputs/narrative/reference_extracts/voices/cosmic/fd4485b0_4664084016761795085_cfg_lang_sc_memory_detail.txt) | 全表 48 条，行 2–49，含拍照、紫藤、露营、极光、圣诞 |
| clue | [cfg_lang_sc_clue_detail](D:/aphasia/outputs/narrative/reference_extracts/voices/cosmic/fd4485b0_8447237765213692459_cfg_lang_sc_clue_detail.txt) | 全表 31 条，行 2–32，含身份问答、任务提示、雷达操作 |

同时阅读了 Rain 话题/线索/记忆映射、角色表，以及 special 中文表。未逐条阅读英文对应版本、所有非 Rain 主线、好感和后日谈表；提取成功不等于全文细读。没有用画面、配音、实际等待时间来验证节奏，以下结论只覆盖文本。

## Rain 可以转化的角色规律

以下左列是原文支持的观察，右列是对蛋黄酱先生的创作建议，二者不是同一个角色设定。

| 原文观察及依据 | 用于蛋黄酱先生的建议 |
| --- | --- |
| 先处理眼前的不适和危险，再说明背景。初见先带玩家离开、伸手；随后加保护、提供回来求助的位置。normal 行 93–100，ID 1002100304–1002100311；topic 行 10–12，ID 100109–100111 | 先提醒水渍、松线、站稳，带玩家看见具体求助者。信任由实际帮助产生，不能用“我是向导，所以听我的”代替 |
| 知识有边界。对宇宙网络明确说是猜测；解释玩家身世前先承认自己只知道网友关系；还会怀疑自己也忘了东西。topic 行 16–18，100501–100503；clue 行 6–9、13，200201–200204、200304 | 能解释拾词和发布，却对来处、自己记忆和后果保持不同程度的含糊。诚实的“不记得”与出于自保的转移话题要有行为区别，不能统统写成玄谜 |
| 幽默建立共同关系。拿失忆 RPG 和村长开玩笑，最后落到“可以回来休息”的承诺。topic 行 52–56，101801–101805 | 玩笑要接在玩家的处境上，并带出可执行的照顾。让主角反驳、纠正、还嘴，避免布偶单方面卖萌 |
| 热情有非常具体的偏好。食物、汽水、旧鼠标、半透明塑料都有触感、价格或使用经验。topic 行 31–32、48–51、62–67、84–89、99–101，101001–101002 等 | 选择两三种属于布偶的偏好即可，例如珍惜干燥、缝线、口袋里的小东西。不要移植 Rain 的网络文化目录，也不要每句话都加拟声词 |
| 能力与笨拙同时存在。会构建露营地，却忘了龙肉的火焰免疫；有备用杯面，仍使活动继续。memory 行 15–21，300302–300307 | 布偶可在小事上判断失误并补救，才能与对大事的回避形成区别。不能将每次失误都写成神秘伏笔 |
| 情绪变化体现在长度和动作上。极光面前断句、沉默，想邀请现实见面又收回，结尾转向“还有工作”。memory 行 27–35，309801–309809 | 重要压力点突然短句、按住腹部缝口、停止玩笑；无需直接解释他怕消失。语气变化应由眼前压力触发 |
| 提示落在具体物与反馈上。雷达教学解释数字、扫描距离、进度条，再安排山胡椒树上的试验物。clue 行 23–25，200801–200803 | 教程依次说明眼前问题、可拿的词、拖放动作、发布按钮、场景结果。失败时只补当前缺失的信息，不一口气解释污染与结局 |

可以把蛋黄酱先生的判断顺序写成：先让埃弥亣继续行动 → 帮他解决可见小事 → 尽量保住二人熟悉的相处方式 → 一旦追问会动摇这种关系，立刻转移到下一件事。这个顺序是结合本项目企划的原创提炼，不能据此声称 Rain 本身具有同样的自保动机。

### 不应借用的部分

Rain 的数码怀旧、游戏开发者身份、文学书单与亲密邀约不能整包挪用；Aphasia 的信任与隐瞒结构不同。尤其不能把 normal 的 `Rain？` 当作 Rain：ID 1097010307 明确自称阿特曼，前后是在借用她的外观。另一个易误读点是 `cfg_rain_chat` 只有“测试内容1/2/3”，不能纳入风格样本。

## Subliminal 的未读边界

原文件：[Narration.bank](D:/aphasia/参考/Subliminal/Subliminal/Content/FMOD/Desktop/Narration.bank)，47,362,272 字节，FSB5 起始偏移 255872。名称表中确有 `Max_Introduction (1)`（sample 4，名称偏移 326031）、`ZH_Max_Introduction  `（sample 53，327299）和 `Max_Introduction`（sample 209，331180）。详见 [音频名称表](D:/aphasia/outputs/narrative/reference_extracts/voices/subliminal_audio_names.jsonl) 与 [资源审计](D:/aphasia/outputs/narrative/reference_extracts/voices/subliminal_audit.json)。

这些证据只能证明有这些命名的音频资源，不能证明哪一个在本地版本开场播放，更不能证明旁白说了什么。未得到可读字幕或音频转写，故不分析其措辞、口吻、提示顺序，也不生成仿称原文。后续若取得有时间码的字幕或合法可读的旁白文本，再按“当前状态—下一动作—可见反馈—失败补充提示”逐段核对；这四项目前只是本项目的检查框架。

## Endless Monday 的未读边界

原文件：[data.win](<D:/aphasia/参考/Endless Monday Dreams and Deadlines/data.win>)。STRG 块偏移 1607872；[提取表](D:/aphasia/outputs/narrative/reference_extracts/voices/endless_strings.jsonl) 每行保留原条目序号、原文件字节偏移和文本。条目 4182–4187（行 4183–4188）含 `data/d.dat`、`data/r.dat`、`data/s.dat`、`data/b.dat`、`data/b.yarn` 的加载路径；简中资源在条目 2726–2730（行 2727–2731）。这些路径支持继续定位，但本地并没有相应的明文 yarn/csv 正文。

STRG 条目 8723–8734（行 8724–8735）可见 Sphinx 的加解密函数名。为识别格式，只读查阅了 [Sphinx 官方仓库说明](https://github.com/JujuAdams/Sphinx)和 [DecryptBufferExt 源文件](https://raw.githubusercontent.com/JujuAdams/Sphinx/main/scripts/SphinxDecryptBufferExt/SphinxDecryptBufferExt.gml)：该库使用压缩后按伪随机序列异或的方法。函数名与 dat 的非文本内容使“正文经该库处理”成为合理推断，但没有读取调用代码或解密键，不能宣称已经完全确认具体参数。本次没有执行远程代码，也没有解出 NPC 原文。

因此不为 Penny、Whiskey 或其他角色编造性格结论，也不把调试日志的随意口吻当角色对白。Aphasia 的其他 NPC 仍应根据自身欲望、恐惧、办事逻辑、对主角的称呼和不同的回避方式来区分；这是项目写作建议，当前不能归功于对 Endless Monday 对话的实读。

## 当前可用于改稿的结论

Rain 为蛋黄酱先生提供的是“让关心先成为行动”的方法，及知识有限、话题有偏好、情绪会改变句长的证据。布偶的自保和回避、主角对正常身份的固执来自 Aphasia 两份企划；不能反过来声称参考作品证明了这些设定。Subliminal 和 Endless Monday 留作待补正文的来源，当前写作与审校应显式保留这一缺口。
