# 项目协作约定

## 工作分支和版本

- 后续游戏修改统一在 `codex/floor-two-maze-mouse-fix-20261016` 分支进行，并跟踪同名远程分支；此约定来自用户要求把当前全部修改发布到新分支，覆盖此前使用 `codex/chapter1-text-20261013` 的约定。
- 第一章以 2026-10-13 的提交 `a5ad585b7868861ac6578cad02224653ea9f3358` 为内容基准，后续修改在此基础上继续。
- 新分支保留 `codex/chapter1-text-20261013` 与 `codex/chapter1-tunnel-handoff-20261009` 的完整祖先历史，包括 `a5ad585b7868861ac6578cad02224653ea9f3358` 和 `42a6c78005803a279a53568827e49974cecc9f1c`。用户已要求删除两个旧分支，后续以新分支为准；历史提交继续保留。
- Windows 当前工程为 `D:\aphasia\meme-game`，用户启动入口为 `D:\aphasia\启动游戏.cmd`；流程说明见 `GAME_FLOW_MEMORY.md`。
- 验证使用 Godot 4.6.3 和 `tools/verify_basement_revision.py`。测试写入隔离存档目录，保留用户正式存档。
- Windows 可见预览与 `tools/verify_mouse_capture_window.py` 必须在正常桌面权限下运行；受限沙箱会阻止 ClipCursor，不能用其结果代表实际鼠标捕获。自动化启动时申请相应执行权限，不在游戏内绕过系统限制。

## 文件删除限制

禁止批量删除文件或目录。不要使用 `del /s`、`rd /s`、`rmdir /s`、`Remove-Item -Recurse` 或 `rm -rf`。

需要删除文件时，只能一次删除一个明确路径的文件。如果需要批量删除，应停止操作并询问用户，让用户手动删除。
