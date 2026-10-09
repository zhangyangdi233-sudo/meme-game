# Windows 原始启动入口

此处原样保存本机使用的五个启动与说明文件，便于复原原工作区。`本机启动说明.txt` 是 2026-10-05 的历史环境记录，其中分支、未提交状态和地下室尚未接入的描述已过时。

最直接的启动方式：安装 Godot 4.6.3，在项目管理器导入仓库根的 `project.godot`。也可在仓库根运行：

```powershell
& 'C:\你的工具目录\Godot_v4.6.3-stable_win64.exe' --path . --editor
& 'C:\你的工具目录\Godot_v4.6.3-stable_win64.exe' --path .
```

若要使用本目录的原始启动器，将四个 `.ps1` / `.cmd` 文件复制到克隆仓库的父目录，并保持以下布局：

```text
工作区/
  Start-Aphasia.ps1
  Start-Chapter1-Dev.ps1
  启动游戏.cmd
  打开Godot编辑器.cmd
  meme-game/project.godot
  tools/godot-4.6.3/Godot_v4.6.3-stable_win64.exe
  tools/hand-tracking-venv/Scripts/python.exe   # 需要真实摄像头追踪时配置
```

`Start-Chapter1-Dev.ps1` 使用独立开发存档，进入主菜单后选择新游戏；F9 切换开发面板。运行会在工作区 `outputs` 写日志与开发偏好，不应提交这些运行数据。

原机器手部追踪使用 Python 3.12.14 和 `mediapipe==0.10.35`。依赖声明、追踪源码及手部模型保存在仓库 `tools/hand_tracking/`。在自己的 Python 3.12 虚拟环境安装 `requirements.txt` 后，设置 `BABEL_HAND_TRACKER_PYTHON` 为该环境的 `python.exe`，再启动 Godot。没有打包 Godot 安装程序、Python runtime、venv 或个人存档。
