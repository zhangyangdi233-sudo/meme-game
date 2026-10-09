# 第一章接入与运行

2026 年 10 月 9 日。主菜单的新游戏已接入黑水白门、五轮地下室、每轮出口后的黑暗隧道与白门、空旷十字路口和第二层。开场在玩家可操作后等待 10 秒，播放完整敲门声，再允许靠近白门按 F 启动开门过场。正式旁白与任务正文暂缓；旁白接口保留，但不再控制开门。地下室已有实际 CRT 教学操作和 NPC 交付流程，功能目标明确标记为开发内容，可从普通新游戏完成五轮。

**启动与操作**

在 PowerShell 执行：

```powershell
& "D:\aphasia\Start-Chapter1-Dev.ps1"
```

[启动器](/D:/aphasia/Start-Chapter1-Dev.ps1) 使用 Godot 4.6.3，显式传入 `--chapter1-dev`，将存档和偏好隔离到 `D:\aphasia\outputs\chapter1_development\profile`。首次运行后日志写入 `D:\aphasia\outputs\chapter1_development\chapter1_latest.log`。选择主菜单的新游戏开始；没有开发参数时不显示完成按钮。

| 操作 | 按键或入口 |
| --- | --- |
| 移动、转向 | WASD、鼠标；点击世界重新捕获鼠标 |
| 开发面板显隐 | F9，仅开发模式；显示时释放鼠标，隐藏后恢复视角控制 |
| 设置开关 | Esc 或 F10，任何时候均可使用，包括开门过场；打开时释放鼠标，关闭后恢复被暂停的流程 |
| 返回主菜单 | 设置底部固定的返回主菜单按钮；取消正在等待或播放的开场声音与动画 |
| 手机切换 | Tab，从地下室开始可用；开场禁止打开 |
| 开场白门 | 听完敲门声后靠近，出现“打开门”提示时按 F；随后自动转场，无需穿门 |
| CRT 教学端 | 靠近电视按 F，鼠标操作屏内应用；点击“退出屏幕”或按 Tab 返回行走 |
| 本轮 NPC | 靠近按 F，可交付本轮投稿、进入原对话，或拾取已显形的隐藏线索 |
| 地下室出口与十字路口远门 | 靠近后按 F，开门后穿过 |
| 黑隧道尽头白光门 | 沿隧道走到白门，按 F；门开、全白遮挡后进入下一轮，第五轮进入十字路口 |

1. 开场距白门 18 米。玩家可操作后等待 10 秒，听完约 6.243 秒的敲门声；靠近白门看到“打开门”提示后按 F，自动进入地下室。无需触发开发旁白事件，也无需自行穿过门框。
2. 每轮从楼梯顶进入；越过入口安全位置后，身后门关闭并永久锁住本轮入口。下楼绕过前方 TV 区，经右侧通道到后方 NPC。
3. 靠近 CRT 按 F，在信号瀑布中拾字，在旁边笔记本里组句并投稿。每轮至少需要一条带当轮任务和令牌的成功投稿；已有字可重复使用，失败和重试不消耗普通每日行动；这项规则持续到十字路口，进入第二层才恢复常规预算。退出 CRT，靠近本轮 NPC 按 F，再点击“交付本轮投稿”。开发面板仅用于检查。
4. 走到左后方地面出口，按 F 开门并穿过，连续走入12米黑隧道；这时仍是同一个地下室世界和轮次。到尽头白光门再按 F，镜头靠近并开门，画面全白后才换场。前四轮在下一轮楼梯顶淡入，第五轮在十字路口淡入。
5. 第 1、3、5 轮交付后分别解锁手机的信号瀑布、笔记本、巴别塔。完成五轮并拥有三个应用权限后，走到十字路口远门，按 F 开门并穿过，进入现有第二层。

五轮依次承接原第一层的护灯人、迟到者、回声住户、抄写员、无名信徒，沿用已有角色贴图和对话；没有编写新任务正文。章节编号 `basement_npc_01` 至 `05`、任务 `basement_help_01` 至 `05` 与原 `source_actor_id/type` 分开保存。护灯人的原对话仍可显形第一层隐藏线索，显形后即使进入后续地下室轮次，也可从本轮 NPC 面板独立领取。它不完成教程或授予应用。远门是程序生成的简易占位门。

开场按 F 后的顺序固定为：0.35 秒镜头对准整扇门、1.6 秒门动画、0.35 秒淡黑、在全黑时切换地下室、0.12 秒黑场、0.35 秒淡入。开门时隐藏门后的固定白光面，避免它遮住转动的门扇；门框与轮廓灯保留。过场接管移动与视角。Esc / F10 的设置入口始终可用；设置打开期间暂停开场计时、敲门播放和过场，关闭后继续。返回主菜单取消尚未完成的声音与动画，避免旧场景回调继续推进。

**资产与存档边界**

最终资源来自 [blender_basement_loop_v2](/D:/aphasia/outputs/blender_basement_loop_v2)，复制到 [assets/chapter1](/D:/aphasia/meme-game/assets/chapter1)。源文件与工程内副本 SHA256 一致：

| 资源 | SHA256 |
| --- | --- |
| `Basement_Loop_v2.glb` | `2A23945D767B028877C11211676885EFFB1A9BAFBB6D79B78C05BEB7935D01AC` |
| `asset_library/kids_chair.glb` | `78646C398848116CAD75A24102018E33CDFD688105E1485B5D79BE7C92D3E195` |
| `Opening_WhiteDoor_v2.glb` | `A318B980649425F053BA17A00D35A97CE38AA829485EFAF37B89BD507392FE85` |

[逐节点材质补丁对比](/D:/aphasia/outputs/basement_integration_audit/chair_material_attribute_comparison.json)确认只有两份资产各16个木件材质改变；位置、法线、索引、层级与变换精确一致，40个碰撞体、7个锚点、两个门轴及三个X-ray标记保留。重新导出仅产生小于 `1e-6` 的UV末位差异。本次材质补丁未重跑完整玩法或重拍截图。

源与工程合同的 `status` 已设为 `asset_runtime_validated`，`latest_runtime_validation` 指向本轮教程与木材验证；其他字段保持一致。最终合同 SHA256 为 `E4D4F0833DC49830750FFE34E859A1207E4762467CF87E21478C00EE9ED4B35A`。

标记、门铰链和碰撞由 [asset_contract.json](/D:/aphasia/meme-game/assets/chapter1/asset_contract.json) 绑定；不回退到旧地下室房型。十字路口保留原几何，新路线关闭原 NPC、玩偶和旧收藏物生成。

敲门声使用 stephan 的 [Knocking on Wood or Door](https://commons.wikimedia.org/wiki/File:Knocking_on_wood_or_door.ogg)。[文件许可页](https://commons.wikimedia.org/wiki/File:Knocking_on_wood_or_door.ogg#Licensing)记载作者将录音释放到公有领域，页面的 Permission 段明确允许商用。工程文件为 [opening_door_knock.ogg](/D:/aphasia/meme-game/assets/audio/sfx/opening_door_knock.ogg)，来源、下载地址、许可证明和校验值保存在 [opening_door_knock.LICENSE.txt](/D:/aphasia/meme-game/assets/audio/sfx/opening_door_knock.LICENSE.txt)。该录音为 44100 Hz 双声道、约 6.243 秒；只移除了非音频 Ogg Skeleton 元数据流，音频页未转码、裁剪或改写。

运行时已校准 GLB 灯光：地下室隐藏导入的高强度灯，主区和后区使用低亮度、轻微偏绿的锚点灯；楼梯门灯已从新模型排除。CRT 屏幕前方按合同实际坐标添加局部绿光，不投射硬阴影；近景校色后能量为 0.20、范围 2.25，避免外壳成为整片荧光绿。绿色墙纸和地毯使用新导入材质，家具与扶手以原木为目标；儿童椅导出时丢失对象材质覆盖的问题已在模型端修正，最新房间和独立椅子 GLB 已同步并重新导入。[Godot 材质验证454项](/D:/aphasia/outputs/basement_integration_audit/verify_kids_chair_pbr_runtime.json)通过，两份资产各16个木件的网格材质与实际材质都是 `PBR_AgedWalnut.001`，反照率贴图均为1024×1024，没有残留青绿色漆材质。开场保留原灯并缩放能量至 0.01，配合 Filmic 白点 6.0 保留白门面板细节。本轮未改开场资产与门/碰撞合同；源合同已依据后续用户指令修正 `opening.gate_rule`，工程副本已同步敲门规则和 CRT 教程元数据。楼梯顶初始俯视为 28°，手动视角不受限制。章节世界隐藏旧 HUD 边缘、手机按钮和上下遮幅，设置与手机界面仍可按上表打开。

`chapter1_progress` 单独保存阶段、轮次、敲门完成状态 `opening_knock_completed`、旁白状态、封门、帮助结果、应用权限 `unlocked_app_ids` 和转换令牌。敲门听完后保存并继续，不会再次等待或重播；未听完时保存并回读，会从可操作后重新等待 10 秒，再播放完整录音。应用权限不使用隐藏结局的 `collected_prerequisite_item_ids`。旧章节存档只依据连续有效的已完成任务迁移权限，旧门钥匙不再作为远门条件，伪造或未完成任务对应的权限不会保留。对于同时缺少新权限字段和新奖励映射、仍处于有效地下室/十字路口、零行动且待日结的旧章节存档，迁移会同日恢复 `max_actions` 并清除待日结/待闪回，保留日期、楼层、奖励、污染与已看闪回状态。这是针对旧教程版本的兼容策略；新格式和塔内存档不套用。状态存档版本保持 5；缺少 `chapter1_progress` 的旧存档继续旧路线。主菜单调用 `start_chapter1_game()`，原 `new_game()` 保留给旧路线测试和预览。

**正式系统接入接口**

可信旁白系统确认完成后，仍可调用主场景的 `notify_chapter1()` 记录旁白状态；此接口不解锁白门，也不切换地下室：

```gdscript
main.notify_chapter1("narration_completed", {"sequence_id": "chapter1_opening"})
```

开场流程使用以下独立事件：

| 事件 | 参数与发送边界 |
| --- | --- |
| `opening_knock_completed` | `{"sequence_id": "chapter1_opening"}`；由开场世界在敲门完整播放结束后发送，持久化 `opening_knock_completed` 并允许白门交互 |
| `opening_door_opened` | 由开门过场到达全黑的房间切换回调发送，进入地下室；仅来自此回调，不由门口位置、旁白事件或普通按键直接发送 |

按 F 只请求启动过场；开门动画完成并淡黑之后才提交房间切换。旧的 `DEV: emit narration completed` 按钮仅供旁白接口检查，不再用于跳过敲门或开门。

任务开始时捕获本轮 `transition_serial`、NPC ID 和任务 ID，完成后提交原值，避免旧回调读取新轮次令牌：

```gdscript
main.notify_chapter1("npc_help_completed", {
    "npc_id": captured_npc_id,
    "task_id": captured_task_id,
    "round_token": captured_round_token,
})
```

返回值为 `{accepted, progress, transition}`。入口阈值和地下室出口事件也必须携带本轮 `round_token`，由世界宿主发送。错误阶段、错误角色或任务、过期令牌和重复完成都被拒绝。地下室任务门锁不能由计时器、靠近门或普通交谈结束替代；开场白门则使用上述敲门完成与过场事件。状态实现见 [basement_loop_director.gd](/D:/aphasia/meme-game/scripts/progression/basement_loop_director.gd)，奖励映射在 `reward_config.task_app_unlocks` 中独立配置。当前玩家交付入口还会检查 `has_current_chapter_submission()`，只接受当轮成功的非空自由组句投稿；草稿、旧轮投稿或单独交谈不会交付。

**CRT 与手机共用应用**

[chapter_terminal_session.gd](/D:/aphasia/meme-game/scripts/ui/chapter_terminal_session.gd) 临时把原有的三个应用窗口、社交详情和拾字动画层移入 1600×1200 的 `SubViewport`，投到 GLB 的真实屏幕曲面；[chapter_terminal.gd](/D:/aphasia/meme-game/scripts/world/chapter_terminal.gd) 以三角形 UV 交点转发点击、滚动、拖拽和键盘输入。默认同屏显示信号瀑布与笔记本，巴别塔单独显示。退出前恢复原控件实例、父节点和布局，镜头回到玩家位置；没有第二份词库或投稿状态。

手机的三个应用初始锁定，已解锁应用可离开 CRT 使用。入口、旧发布和组句回调、拾字自动弹窗、自动选择下一窗口与存档恢复都检查权限。CRT 内三个教学工具可用，但不会写入手机窗口权限。设置中的“全局画面 VHS”与“开启 CRT 屏幕 VHS 质感”分开，后者默认打开，立即生效并单独持久化；切换全屏 VHS、音量、语言或摄像头不会覆盖它。效果使用屏幕材质自身纹理，覆盖教学界面和教学会话中的视频，不采样整屏画面。设置打开时取消屏内按下/拖拽而不触发按钮；关闭后恢复输入。返回主菜单或换场先恢复控件再释放会话。活动会话持续固定屏内布局，避免字号放大后异步最小尺寸计算把投稿按钮挤出屏幕。

**X-ray 出口箭头**

地下室仅有三组手绘红箭头，位置与朝向由合同 `xray_exit_guides.marks` 指定，用来提示出口路线；普通视野不显示地面红线或墙上箭头。使用现有设置中的电脑摄像头或手机备用摄像头入口，再用双手拇指与食指框出矩形，箭头才会出现在这个 X-ray 窗口内。普通摄像头无有效手势、失手超过 420 毫秒、关闭摄像头、打开手机界面或设置、过场及离开地下室时均隐藏；载入需重新获取手势。

实现以第 20 渲染层隔离导入标记，在模型加入场景树前处理 `extras.xray_only` 与合同名称，关闭标记的投影和 GI。普通主相机永久排除该层；[chapter_xray_view.gd](/D:/aphasia/meme-game/scripts/world/chapter_xray_view.gd) 的副相机跟随主视角，共享场景，只在有效手势时刷新，将纹理送入原有手势窗口。撕裂贴图也裁剪到窗口内，边框特效保留。返回手机或切换房间不会把旧截图、旧手势恢复为可见箭头。

专项验证：渲染层隔离 51 项、真实 UI/手势状态与三张导入标记 45 项、窗口贴图边界 28 项通过；原手势核心测试通过。实机使用实际设置控件和手部帧处理入口，以测试关键点代替硬件，生成 [普通视野](/D:/aphasia/outputs/basement_integration_audit/chapter1_xray_01_normal.png)、[X-ray 窗口](/D:/aphasia/outputs/basement_integration_audit/chapter1_xray_02_active.png)、[关闭后](/D:/aphasia/outputs/basement_integration_audit/chapter1_xray_03_disabled.png)。同一箭头区域的红色像素分别为 0、2861、0；排除原有边框带后，窗外 85736 个采样无超过 3% 的差异。详见 [渲染记录](/D:/aphasia/outputs/basement_integration_audit/chapter1_xray_capture_results.json)。未开启真实摄像头，不能据此声称已验证物理摄像头识别。

儿童椅木材修复前的绿色氛围留档为 [楼梯](/D:/aphasia/outputs/basement_integration_audit/chapter1_lighting_review_stairs.png) 和 [电视区](/D:/aphasia/outputs/basement_integration_audit/chapter1_lighting_review_tv.png)，CRT 开关机与局部光联动通过；电视墙上的过大硬阴影已移除。新组件的 89 项合成检查通过，未测试实际视频解码。资产哈希与保留元数据记录见 [green_revision_assets.json](/D:/aphasia/outputs/basement_integration_audit/green_revision_assets.json)。本轮未重跑五轮实走或性能测试。主场景测试及渲染捕获仍报告退出时 RID/ObjectDB/资源清理诊断，未将全部诊断归为历史问题。

**CRT 教程验收（2026-10-07 基线）**

实现校验值、专项结果和限制汇总于 [chapter_terminal_verification.json](/D:/aphasia/outputs/basement_integration_audit/chapter_terminal_verification.json)。

实际导入模型的 [最终渲染报告](/D:/aphasia/outputs/basement_integration_audit/chapter1_terminal_capture_results.json) 为 62 项通过、五张 PNG 写入成功。摄像机射线经过真实曲面 UV，依次点击帖子、在原 RichTextLabel 正文拾“门”、点击笔记本字块入句、点击可见的“投稿这句话”，产生带当轮来源的投稿，再由 NPC 面板交付后只解锁手机社交应用。不是仅调用投稿处理函数的截图验收。

- [CRT 瀑布与笔记本，VHS 开](/D:/aphasia/outputs/basement_integration_audit/chapter1_terminal_02_apps_vhs_on.png)
- [同一画面，VHS 关](/D:/aphasia/outputs/basement_integration_audit/chapter1_terminal_03_apps_vhs_off.png)
- [字块入句、投稿前预览](/D:/aphasia/outputs/basement_integration_audit/chapter1_terminal_05_sentence_preview.png)
- [手机初始全锁](/D:/aphasia/outputs/basement_integration_audit/chapter1_terminal_01_phone_locked.png) / [首轮后仅社交解锁](/D:/aphasia/outputs/basement_integration_audit/chapter1_terminal_04_phone_social_unlocked.png)

对照时固定镜头、全局 VHS 关闭、应用动画和着色器时间。屏内 56,580 个采样有 2,611 个超过 2.5% RGB 差异；排除屏幕边缘 14 像素后，屏外 95,889 个采样零变化。扫描线降至 180 条并按像素导数抗锯齿，正文使用至少 27 像素的屏内字号；右侧投稿按钮底边为 1140，完整位于 1200 高视口内。

组件 60 项、会话 57 项、世界教程 105 项通过。[主场景专项302项](/D:/aphasia/outputs/basement_integration_audit/test_chapter_terminal_flow.final.log)通过，覆盖五轮原 UI 处理入口、首轮连续 25 次投稿、五次 NPC 交付、第 1/3/5 轮实际保存并继续、原隐藏线索显形后跨轮领取、权限防绕过、设置取消按下/恢复、返回主菜单、布局恢复与相机归位。旧句子编辑器、章节 X-ray/手势、开发面板回归也通过。实际点击与像素证据来自一轮真实渲染；五轮交付证据来自主场景自动化，没有将旧开发完成按钮实走结果作为本次权限验收。

主场景测试与捕获退出仍报告 RID/ObjectDB/资源清理诊断；测试通过不表示日志完全无警告。摄像头以测试接收器替代；本轮未开启真实摄像头，也未验证实际用户视频解码或重测性能。

**本地视频**

地下室的 `ChapterVideoScreen` 节点已绑定独立屏幕材质，默认显示绿色待机。将用户提供并导入的本地 `VideoStream` 传给 `set_stream(stream)`，再显式调用 `play()`；`stop()` 或自然播放结束后恢复当前教学界面；没有教学会话时恢复绿色待机。绑定和设置资源都不自动播放；视频播放时不叠加待机绿色。

`power_off()` 停止播放、显示黑屏并熄灭局部绿光；`power_on()` 恢复教学界面或待机与局部绿光，不自动播放。`set_standby_color(color)` 可配置待机颜色，场景使用资产合同的 `art_direction.crt_standby_srgb`。组件提供 `power_changed(powered_on)`、`playback_finished`、`playback_failed(reason)`、`playback_stopped` 信号；空资源播放请求安全返回 `false`，失败原因为 `no_stream`，保留原开关机状态。自然结束停止视口刷新，释放或重绑恢复原材质。实现见 [chapter_video_screen.gd](/D:/aphasia/meme-game/scripts/world/chapter_video_screen.gd)。目前没有提供实际媒体，测试仅覆盖资源隔离、待机与电源状态、清理和合成完成信号，尚未验证真实解码、画面和音频。

**验证证据与限制**

以下三项及其退出诊断属于本次敲门与开门过场修改前的集成基线，保留用于回归比较，不能作为新开场流程已通过的证明：

- 14 个不同测试套件通过，退出码均为 0：基础 11 项见 [chapter_regression_results.json](/D:/aphasia/outputs/basement_integration_audit/chapter_regression_results.json)；另有世界、资产绑定、主场景桥接。最新复验见 [chapter_final_verification.json](/D:/aphasia/outputs/basement_integration_audit/chapter_final_verification.json)，资产绑定记录见 [chapter_asset_binding_test.log](/D:/aphasia/outputs/chapter_asset_binding_test.log)。组件测试包含 73 项检查。
- 主游戏控制器自动实走已通过五轮完整动线、远门及第二层；五轮各在封门后和帮助后保存继续，加十字路口一次，共 11 次。结果见 [chapter1_walk_results.json](/D:/aphasia/outputs/basement_integration_audit/chapter1_walk_results.json)，日志见 [walk_chapter1.log](/D:/aphasia/outputs/basement_integration_audit/walk_chapter1.log)。
- RTX 4070 Ti 实际渲染输出 16 张主游戏图像，使用显式开发状态布置场景，实走另行验证。完整索引见 [chapter1_capture_results.json](/D:/aphasia/outputs/basement_integration_audit/chapter1_capture_results.json)，日志见 [capture_chapter1.log](/D:/aphasia/outputs/basement_integration_audit/capture_chapter1.log)。可直接查看 [开场](/D:/aphasia/outputs/basement_integration_audit/chapter1_opening_clean.png)、[楼梯顶](/D:/aphasia/outputs/basement_integration_audit/chapter1_stairs_clean.png)、[TV 区](/D:/aphasia/outputs/basement_integration_audit/chapter1_tv_clean.png)、[右侧通道](/D:/aphasia/outputs/basement_integration_audit/chapter1_right_passage.png)、[NPC 与出口](/D:/aphasia/outputs/basement_integration_audit/chapter1_npc_and_exit.png)、[十字路口远门](/D:/aphasia/outputs/basement_integration_audit/chapter1_far_gate.png)。捕获数据包含场景重载与 `RenderingServer.force_draw()` 的影响，`frame_ms` 不是稳定帧率基准。

断言通过不等于退出日志完全干净。`test_reality_world` 和 `test_save_progress` 的退出资源泄漏类别、数量与 [原基线](/D:/aphasia/outputs/basement_integration_audit/baseline_test_results.json) 一致；主场景和本地化测试也报告退出清理诊断，但缺少对应旧基线，不能把所有泄漏都认定为原有问题。回归结果未记录运行中脚本错误，原有三处未提交修改在验证前后哈希一致。

**本次开场修改的验证范围**

2026 年 10 月 7 日，Godot 4.6.3 无界面音频验证退出码为 0。`AudioStreamOggVorbis.load_from_file()` 返回非空，`get_length()` 为 6.243265 秒；`AudioStreamPlayer3D` 在距监听点 18 米、`unit_size=18`、`volume_db=-3` 的配置下开始播放，经过 6.259 秒收到 `finished`，随后 `playing=false`，未触发 10 秒超时。验证脚本为 [verify_knock_audio.gd](/D:/aphasia/outputs/opening_door_audit/verify_knock_audio.gd)，日志为 [verify_knock_audio.log](/D:/aphasia/outputs/opening_door_audit/verify_knock_audio.log)，使用独立的 `audio_profile` 存档目录。

本次另有 13 个相关测试套件断言通过、退出码均为 0：开场完整流程、章节状态、章节世界、主场景桥接、门过场、门组件、鼠标输入、设置退出、本地化、响应式布局、现实世界、存档与主场景。日志保存在 [opening_door_audit](/D:/aphasia/outputs/opening_door_audit)。其中 [flow_green.log](/D:/aphasia/outputs/opening_door_audit/flow_green.log) 覆盖 10 秒门槛、真实声音播放完成、设置暂停、距离与 F 交互、自动进入地下室、保存继续及过场中返回主菜单；[door_transition.log](/D:/aphasia/outputs/opening_door_audit/door_transition.log) 的 64 项检查覆盖过场顺序、暂停、取消及旧场景释放。主场景类测试仍有退出时的资源清理诊断，未把断言通过表述为日志完全无警告。

实际渲染捕获并检查了六个阶段：[白门待开](/D:/aphasia/outputs/opening_door_audit/door_01_ready.png)、[整扇门取景](/D:/aphasia/outputs/opening_door_audit/door_02_closeup.png)、[门扇转动](/D:/aphasia/outputs/opening_door_audit/door_03_opening.png)、[全黑切换](/D:/aphasia/outputs/opening_door_audit/door_04_black.png)、[地下室落点](/D:/aphasia/outputs/opening_door_audit/door_05_basement.png)、[设置固定按钮](/D:/aphasia/outputs/opening_door_audit/door_06_settings.png)。捕获使用已完成敲门的测试存档布置状态，再通过视口发送 F；等待和声音完成由上述流程测试另行覆盖。画面检查据此修复了固定白光面的遮挡，并调整镜头距离使整扇门入画。

本轮没有人工试听，也没有重新执行完整五轮实走或性能测量；下述性能数据仍为历史基线。地下室截图记录捕获时的画面，不代表其他并行房间美术修改的最终状态。

**稳定渲染补测（历史基线）**

在 RTX 4070 Ti / Forward+ / 1600×900 下，每个场景先预热 3 秒，再测量 10 秒。使用真实隐藏视口，每帧强制绘制确保发生渲染；结果包含强制绘制同步开销，不代表可见窗口的最高帧率。测试工具为 `tools/profile_chapter1.gd`，原始结果见 [chapter1_performance_results.json](/D:/aphasia/outputs/basement_integration_audit/chapter1_performance_results.json)。

| 场景 | 场景建立 | 稳定段平均 FPS | 帧时间 P50 / P95 / 最大 |
| --- | --- | --- | --- |
| 黑水开场 | 420.50 ms | 90.01 | 11.21 / 11.95 / 13.01 ms |
| 地下室 TV 区 | 483.19 ms | 89.99 | 10.96 / 12.20 / 12.46 ms |

稳定段没有复现截图记录中 410–910 ms 的数值，原截图指标混入了场景重建；没有单独测量首次着色器编译的占比。本线程未启动 Blender 渲染，也未与自己的其他 Godot 捕获并行。环境无法可靠列出其他进程的 GPU 占用，不能断言 Blender 没有影响。随后 GPU 采样仍显示整机约 67–69% 占用；该采样晚于性能窗口，不能用于归因性能窗口内的负载。可见运行验收仍应观察用户实际窗口与显示设置。

**2026-10-09：连续隧道与可读性更新（当前版）**

- 新组件 `scripts/world/chapter_exit_tunnel.gd` 在原出口后连接12×2.1×2.7米实体黑暗走廊。门口保持同一世界、同一轮次和令牌，安全走入1.3米后 `basement_tunnel_entered` 保存 `exit_tunnel_entered`，旧出口在玩家身后关闭。尽头白门靠近按F才触发 `tunnel_door_requested`；镜头接近、开门和白色淡出完成后，主场景才提交 `basement_exit_requested`。前四轮进入下一轮楼梯顶，第五轮进入十字路口。
- 当前GLB的旧即时返回口有 `Exit_VestibuleBack` 背板。运行时隐藏这一个网格，并按其准确包围盒匹配且仅停用一个导入碰撞；不改源GLB、不动其余墙壁。匹配不唯一时明确拒绝建成场景。物理行走和门口射线均已验证可通行。
- 隧道中段位置与标志支持保存/继续；白门重载为可重新按F的关闭状态。Esc暂停门与镜头过渡，中途返回主菜单取消回调。开门意外失败会恢复同轮同位置并解除输入锁，可重试；重建或过期实例回调不能推进新存档。
- 全屏VHS强度由0.58–0.80降到0.44–0.60，初始0.46，抖动位移随强度衰减，扫描线/雪噪减淡。固定画面与原图平均偏差下降约18%–22%。CRT局部VHS和全屏开关仍相互独立。
- CRT正文基准及应用小字下限36px；主题额外字距1px、额外行距6px。顶部工具栏保留26/28px。字块至少54×54、36px，长词按实际字宽扩展，并同步物理碰撞、点击和保存坐标。手机沿用原字块尺寸。笔记本内容填满滚动区，空提示可换行；底部提交按钮完整留在1600×1200屏幕内。

本轮证据：[汇总](/D:/aphasia/outputs/tunnel_readability_20261009/verification_summary.json)、[79项真实渲染转场检查](/D:/aphasia/outputs/tunnel_readability_20261009/tunnel_flow_results.json)、[76步物理行走](/D:/aphasia/outputs/basement_integration_audit/chapter1_walk_results.json)、[66项CRT真实UV交互与排版](/D:/aphasia/outputs/basement_readability_20261009/chapter1_terminal_capture_results.json)。物理行走包括五轮走廊、五次隧道中段保存/继续、第五白门进入十字路口和原远门进入第二层；NPC任务在此行走脚本中由测试事件完成。另行307项主场景UI流程覆盖实际投稿处理、五次NPC交付与三次读档。状态166项、门过渡103项、会话62项、世界与词块回归通过。

代表画面：[黑暗隧道](/D:/aphasia/outputs/tunnel_readability_20261009/tunnel_02_dark_corridor.png)、[白门开启](/D:/aphasia/outputs/tunnel_readability_20261009/tunnel_04_white_door_opening.png)、[完整遮挡换场](/D:/aphasia/outputs/tunnel_readability_20261009/tunnel_05_opaque_swap.png)、[CRT放大后](/D:/aphasia/outputs/basement_readability_20261009/chapter1_terminal_05_sentence_preview.png)。主场景退出资源清理诊断仍有记录；以上不代表真实摄像头、用户视频解码或性能复测。
