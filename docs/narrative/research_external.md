# Aphasia 叙事写作的外部方法研究

访问日期：2026-10-05。研究者：本任务的公开资料研究代理。用途：支持角色对白、任务动机与玩家提示的改写。

实际读取了女娲的 SKILL.md、MCP Market 条目指向的 daymade 技能原文，以及阿里 DeepResearch 的文档与相关代码。结论是：女娲适合建立角色判断与表达的一致性，daymade 适合管理设定证据及冲突，阿里项目适合借鉴“带着问题查证”的工具流程。三者没有提供经过游戏实测的叙事公式，以下写作方案属于本项目的方法适配。

## 三个项目的区别

| 项目 | 已核实的性质 | 本次实际状态 |
| --- | --- | --- |
| [Nuwa 女娲](https://github.com/alchaincyf/nuwa-skill) | 由 Markdown 技能指令和辅助脚本组成的人物思维框架提炼流程；README 明确允许直接阅读 SKILL.md 使用 | 已阅读技能与关键参考文件；未安装、未执行附带脚本、未完整运行人物蒸馏流程 |
| [MCP Market 的 Deep Research 条目](https://mcpmarket.com/zh/tools/skills/deep-research-5) | 指向 daymade/claude-code-skills 的 deep-research；不是阿里项目 | 已阅读条目及上游技能原文；采用其证据核查原则，不宣称完成该技能全部归档与校验流程 |
| [Alibaba Tongyi DeepResearch](https://github.com/Alibaba-NLP/DeepResearch) | 包括模型、推理程序及外部工具接入的研究代理项目 | 仅研究文档和代码；未下载模型、未运行推理、未调用其服务或在线演示 |

## 女娲对角色写作的帮助

女娲的核心工作对象包括人物判断、快速决策规则、语言习惯、价值底线及知识边界。采集维度同时覆盖自述、对话、外部评价和实际行动，可以避免仅凭几句口头禅推断整个角色。原技能也要求把原话、他人描述和研究者推断分开记录。参见 [SKILL.md 的 Phase 1 至 Phase 2](https://raw.githubusercontent.com/alchaincyf/nuwa-skill/main/SKILL.md)。

[提炼框架](https://raw.githubusercontent.com/alchaincyf/nuwa-skill/main/references/extraction-framework.md)要求检验某个判断模式是否能跨情境出现、解释新问题，并具有角色区分度；语言观察包含句长、疑问比例、确定性与转折。它区分随时间变化、因领域变化和内在价值冲突，反对把所有矛盾强行圆成一个解释。

项目适配建议：每名主要角色先写一张短卡，记录“最先注意什么、最害怕失去什么、凭什么信任人、愿意付出什么、在哪种压力下说谎”。随后让同一角色分别面对求助、拒绝、失败三个情境；行动应能从短卡推出，语气可以随关系变化。不要把外部研究对象的整套身份或原话搬进游戏。

[技能模板](https://raw.githubusercontent.com/alchaincyf/nuwa-skill/main/references/skill-template.md)把知识边界和不确定表达写入角色约束。用于虚构人物时，可以转成角色知识表：亲历、听说、猜测、隐瞒、尚不知道。对白只读取当前剧情阶段允许知道的内容，避免角色替作者提前宣布谜底。

[保真度评分卡](https://raw.githubusercontent.com/alchaincyf/nuwa-skill/main/references/fidelity-scorecard.md)把作答与评审分给不同代理，分别看判断、风格、越界时的诚实度和证据。项目可采用盲读复核：隐藏姓名，检查不同 NPC 的回答是否仍可区分；再检查角色面对未知事实时是否凭空全知。这里借用检查方式，不沿用原评分卡对质量的承诺。

## daymade 对证据和改稿的帮助

市场页强调多轮研究与 UNION 合并；当前上游 [SKILL.md](https://raw.githubusercontent.com/daymade/claude-code-skills/main/deep-research/SKILL.md)进一步强调决策问题、关键结论、反证、来源家族及原文回查。转载同一份材料的多个网页不能算独立佐证；未知信息不能靠流畅的文字补齐。当前技能还要求保留原始结果、来源台账、论断记录和研究目录，故“读过技能”不等于“完整执行该技能”。

项目适配建议：每次改稿围绕一个可回答的问题，例如“这名 NPC 为什么必须请玩家来做”“玩家此刻凭什么相信提示”“失败后角色为什么仍愿意合作”。每条回答绑定企划或流程位置；正文新增内容标为创作提案。多稿合并时保留独有的有效内容，但冲突设定需要裁决，不能因为 UNION 而全部并存。

[质量关卡](https://raw.githubusercontent.com/daymade/claude-code-skills/main/deep-research/references/quality_gates.md)以问题是否得到合适证据支持为主要标准，数量只是覆盖诊断。[旧来源评分文件](https://raw.githubusercontent.com/daymade/claude-code-skills/main/deep-research/references/source_quality_rubric.md)仍有较笼统的分层和排除规则；实际使用时需注意两份文件的粒度差异，不能用来源分数代替具体论断核对。

## 阿里 DeepResearch 的运行条件与方法边界

[README](https://github.com/Alibaba-NLP/DeepResearch#quick-start)推荐 Python 3.10 和隔离环境，支持本地模型及经配置后的 OpenRouter 路径。[依赖清单](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/requirements.txt)包含 PyTorch、Transformers、vLLM、Qwen Agent、CUDA 相关包及外部服务 SDK。[示例启动脚本](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/inference/run_react_infer.sh)会启动 GPU 0 至 7 上的模型服务；这是脚本现状，不能据此断言项目最低必须八张 GPU。本次没有测试 Windows 兼容性或硬件要求。

[环境变量示例](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/.env.example)列出 Serper 搜索凭据、Jina 阅读凭据、摘要模型 API 地址与密钥、DashScope 文件解析配置、SandboxFusion 端点，以及可选 IDP 配置。所需配置取决于启用的工具；不是每次纯文本研究都必然调用全部服务。本任务没有配置这些凭据，也没有读取本机密钥。

代码能进一步确认数据流：[搜索工具](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/inference/tool_search.py)把查询发给 Serper；[网页工具](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/inference/tool_visit.py)把网址交给 Jina，再将网页内容与阅读目标交给配置的摘要模型。因此，本地部署主模型不自动意味着所有工具数据均留在本地。本次公开检索未携带私有企划、对白或用户资料。

[提示文件](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/inference/prompt.py)要求网页阅读携带明确目标，并分出相关依据与摘要；[推理代码](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/inference/react_agent.py)将工具结果送回多轮流程。项目适配建议是每次查证只解决一个具体写作疑点，保留“原文支持什么、不能支持什么”。可以借鉴检索与证据流程，不能把模型生成的摘要自动视为已核实事实。

[FAQ](https://raw.githubusercontent.com/Alibaba-NLP/DeepResearch/main/FAQ.md)在本次读取版本仍说明 Heavy Mode 尚未完全开源，并提示复现实验依赖相同提示与工具。本次没有复现论文、评估模型表现或验证在线服务可用性。

## 用于改写的工作表

以下为根据上述方法提出的项目写作方案，并非来源已有的游戏规则。

| 对象 | 写作时填写 | 审校时验证 |
| --- | --- | --- |
| NPC 一次发言 | 眼前目标、对玩家的态度、已知事实、刻意不说的内容、希望玩家采取的动作 | 台词能否改变关系或行动；是否知道超出当前阶段的信息 |
| 任务动机 | 角色需要的结果、自己无法完成的原因、为何找玩家、玩家付出的代价、完成后的关系变化 | 去掉任务奖励后，是否仍有可信的人物需求；拒绝后是否有合理反应 |
| 提示 | 当前状态、已见线索、玩家缺失的信息、最低必要提示、失败后的更明确提示 | 是否只提示已经开放的操作；是否泄露答案或误导到不存在的系统 |
| 规则文本 | 触发条件、对象、数量或期限、状态变化、退出条件、反馈位置 | 每个数字和条件是否来自当前流程；显示文本与实际机制是否一致 |
| 旧稿复用 | 原编号、仍有效的情绪/动作、冲突设定、新用途或停用原因 | 不把旧机制换个说法重新引入；无法复用时保留编号并标明停用 |

建议按“确认玩法事实 → 角色为何关心 → 角色如何说 → 玩家能做什么 → 失败时如何解释”的顺序改稿。写作者与检查者分别负责情绪可信度和规则一致性，最后把同一情境的所有提示并排阅读，检查前后是否相互抵消。

## 已读范围和研究限制

所有链接均在 2026-10-05 通过网页读取工具打开。GitHub 内容来自访问时工具返回的 main 页面；未固定提交 SHA，不能把访问日期写成原文件发布日期。

| 来源 | 实际读取范围 |
| --- | --- |
| Nuwa 仓库首页及 README | 项目说明、使用方式、流程、边界及结构 |
| Nuwa SKILL.md | 分段读取完整技能，包括入口、采集、提炼、构建、验证、精炼与更新 |
| Nuwa extraction-framework.md、skill-template.md、fidelity-scorecard.md | 完整正文 |
| [Nuwa download_subtitles.sh](https://raw.githubusercontent.com/alchaincyf/nuwa-skill/main/scripts/download_subtitles.sh) | 完整文本；确认可选字幕流程依赖 Bash 与 yt-dlp；未执行 |
| MCP Market deep-research-5 | 条目介绍、功能、安装定位；条目属于聚合页，项目方法以原始文件为准 |
| daymade deep-research/SKILL.md | 完整正文，含当前资产约定及反模式 |
| daymade source_quality_rubric.md、quality_gates.md | 完整正文 |
| [daymade research-asset-contract.md](https://raw.githubusercontent.com/daymade/claude-code-skills/main/deep-research/references/research-asset-contract.md) | 完整正文；未运行其归档脚本，未创建其规定的完整研究资产集 |
| 阿里仓库首页及 README | 介绍、推理范式、快速开始、服务和评估说明 |
| 阿里 .env.example、requirements.txt、FAQ.md、run_react_infer.sh | 完整文本 |
| [阿里 inference 目录](https://github.com/Alibaba-NLP/DeepResearch/tree/main/inference) | 文件清单，用来定位公开源文件 |
| 阿里 prompt.py、tool_search.py、tool_visit.py、react_agent.py | 完整文本，用于检查接口、数据流与循环；不是完整代码安全审计 |

终端只读 HTTPS 请求曾因 SSL 连接失败未取得文本，随后使用网页工具完成读取；没有关闭证书校验。未下载远程仓库、安装依赖、运行远程代码、进行付费研究调用、上传任何本地文件或执行删除命令。未读取三项目的全部 examples、训练代码、技术论文全文和所有关联插件，故不评价其整体可靠性、性能或安全性。
