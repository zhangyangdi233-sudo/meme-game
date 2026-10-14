# 项目协作约定

## 工作分支和版本

- 后续游戏修改统一在 `codex/chapter1-text-20261013` 分支进行，并跟踪 `origin/codex/chapter1-text-20261013`；除非用户另有要求，不再切回旧日期分支继续开发。
- 第一章以 2026-10-13 的提交 `a5ad585b7868861ac6578cad02224653ea9f3358` 为内容基准，后续修改在此基础上继续。
- 上述版本已完整包含 `codex/chapter1-tunnel-handoff-20261009` 的提交 `42a6c78005803a279a53568827e49974cecc9f1c`；旧分支保留作历史记录。
- Windows 当前工程为 `D:\aphasia\meme-game`，用户启动入口为 `D:\aphasia\启动游戏.cmd`；流程说明见 `GAME_FLOW_MEMORY.md`。
- 验证使用 Godot 4.6.3 和 `tools/verify_basement_revision.py`。测试写入隔离存档目录，保留用户正式存档。

## 文件删除限制

禁止批量删除文件或目录。不要使用 `del /s`、`rd /s`、`rmdir /s`、`Remove-Item -Recurse` 或 `rm -rf`。

需要删除文件时，只能一次删除一个明确路径的文件。如果需要批量删除，应停止操作并询问用户，让用户手动删除。
