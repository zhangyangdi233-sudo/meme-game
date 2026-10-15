# 第五回地下室 CRT 改动（2026-10-14）

第五回（`round_index = 4`）增加 12 台厚背 CRT：8 台下沉到地毯中，4 台嵌入墙壁。连同原来的教学 CRT，共 13 台播放用户提供的同一段视频，使用不同起点循环。前四回的 CRT 和异常行为保持原有配置。

## 视频与声音

- 用户源文件：`D:/aphasia/b5ff65f406555ac661be3f3ea2a68bbc.mp4`，保留原件。
- 游戏视频：`assets/video/basement_crt_loop.ogv`。完整约 35.6 秒内容，转为 Ogg Theora、384×288、24 fps；原始 568×320 画面保持比例并加黑边，去掉原声。
- 12 台新增 CRT 的起点依次为 `index × 1.73` 秒，主教学 CRT 为 `20.76` 秒；按解码器返回的实际视频时长取模，播放到结尾循环。所有播放器均静音。
- 默认路径可由房间合同 `basement_crt_video_path` 覆盖。视频转换来源见 [视频来源记录](../assets/video/basement_crt_loop_SOURCE.md)。
- 雪花声为 DiArchangeli 的 [TV Static.wav](https://freesound.org/people/DiArchangeli/sounds/116395/)，原作者页面标注 **CC0 1.0**。实际下载的是该页面公开的 Ogg 试听音频，保存在 `assets/audio/sfx/tv_static_diarchangeli.ogg`。游戏以 -16 dB 播放，仅取红屏阶段六秒；不循环。来源、下载地址、许可和 SHA-256 见 [声音来源记录](../assets/audio/sfx/tv_static_SOURCE.md)。

## 模型与摆放

模型使用游戏内生成的低面数网格：宽边框、鼓面玻璃、厚而向后收窄的机壳、旋钮与散热槽。主面板约 0.79 米宽、0.65 米高，厚机壳约 0.75 米深。无需修改或打开 Blender 场景。

下表位置使用导入地下室的局部坐标，单位米，Y 轴向上。地面模型的原点下移使下方边框、旋钮与机壳部分埋入地毯；墙面模型的后背穿入墙后，仅保留正面突出。

| 节点 | X | Y | Z | 类型 |
| --- | ---: | ---: | ---: | --- |
| SunkenCRT01 | 2.40 | -0.18 | 2.80 | 地面 |
| SunkenCRT02 | 2.55 | -0.20 | 0.85 | 地面 |
| SunkenCRT03 | 2.05 | -0.24 | -1.15 | 地面 |
| SunkenCRT04 | -0.75 | -0.19 | 2.80 | 地面 |
| SunkenCRT05 | -1.13 | -0.23 | 0.65 | 地面 |
| SunkenCRT06 | 0.75 | -0.22 | 1.65 | 地面 |
| SunkenCRT07 | 2.40 | -0.18 | -3.20 | 地面 |
| SunkenCRT08 | -0.95 | -0.20 | -3.75 | 地面 |
| SunkenCRT09 | 3.18 | 0.72 | 2.20 | 东墙 |
| SunkenCRT10 | 3.18 | 1.48 | -0.55 | 东墙 |
| SunkenCRT11 | -0.55 | 1.30 | 4.18 | 前墙 |
| SunkenCRT12 | 1.90 | 0.82 | -4.18 | 后墙 |

中央通路与触发区域保持可行走；这些装饰模型没有额外阻挡碰撞。

## 一次性事件

首次进入房间局部原点 `(0, 0, 0)` 周围水平半径 **0.65 米**、且入口已锁定时触发。检测限制局部 `abs(y) < 1.8`，避免楼梯高处误触发。

| 从触发开始 | 屏幕 | 灯光 | 声音 |
| --- | --- | --- | --- |
| 0–2 秒 | 13 台全部纯黑 | 原有 Light3D、灯泡发光和环境补光关闭 | 静音 |
| 2–8 秒 | 13 台全部纯红 | 新增屏幕红光照亮地毯、墙壁和天花板 | 电视雪花声 |
| 8–8.18 秒 | 13 台全部纯黑 | 红光关闭，原有照明仍关闭 | 雪花声立即停止 |
| 8.18 秒以后 | 恢复原视频/教学显示 | 恢复每盏灯、灯泡材质和环境补光原值 | 正常状态 |

触发时发出 `basement_crt_event_started`，Director 验证第五回、入口锁定和当前 `round_token` 后写入 `basement_crt_event_played = true`。在播放开头保存标记，因此中途退出、存档后继续、中心停留或再次走入均不会重播。同步进度不会打断当前正在运行的事件。

暂停时冻结事件时钟、13 路视频和雪花声。换场或节点离树时停止雪花声，并恢复外部灯、材质与主屏状态。事件期间灯开关不改变被保存的灯状态。

主教学屏使用可逆的信号覆盖，不通过停止视频制造黑/红画面。平时视频作为背景显示；附着教学终端 GUI 时让出显示面，退出终端后显示原视频。黑/红异常覆盖始终具有最高优先级，关闭教学 GUI 不能泄露底下的视频。

## 实现入口与验证

- `scripts/world/basement_crt_anomaly.gd`：模型、位置、独立播放器、灯光快照、时序和恢复。
- `scripts/world/basement_atmosphere.gd`：第五回装配、`crt_event_started` 信号、`bind_primary_screen()`、`stop_crt_event()`、暂停与位置更新。
- `scripts/world/chapter_video_screen.gd`：可逆纯色信号覆盖、循环/偏移播放、背景视频让出教学 GUI。
- `chapter_world.gd` 和 `basement_loop_director.gd` 接入中心位置与持久事件。

验证使用 Godot 4.6.3，并隔离 `APPDATA` / `XDG_DATA_HOME` 到 `artifacts/crt-verification/isolated-profile`，没有读写正式存档。

```powershell
$env:APPDATA = 'D:\aphasia\meme-game\artifacts\crt-verification\isolated-profile'
$env:XDG_DATA_HOME = $env:APPDATA
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --script res://tests/test_basement_crt_anomaly.gd
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --script res://tests/test_basement_atmosphere.gd
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --script res://tests/test_chapter_components.gd
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --script res://tests/test_chapter_terminal.gd
```

CRT 测试覆盖实际 Theora 解码和不同偏移、13 路循环与静音、教学 GUI 覆盖恢复、两秒/六秒边界、全灯与发光材质恢复、暂停、换场取消、真实 ChapterWorld 中心触发、正常 JSON 存档和读档不重播。

截图复现：同一隔离环境下运行 `--rendering-method gl_compatibility --script res://tests/capture_basement_crt_anomaly.gd`（去掉 `--headless`）。脚本隐藏主窗口，在独立 SubViewport 中拍摄。

截图位于 `artifacts/crt-verification/`：`crt-normal.png`、`crt-close.png`、`crt-black.png`、`crt-red.png`、`crt-restored.png`。已检查正常播放、厚机壳和嵌墙外形、全黑、红光铺满房间及恢复。测试日志为 `test-crt.log`，截图日志为 `capture.log`。
