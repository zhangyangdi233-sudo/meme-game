## Language

與使用者的所有回覆一律使用**繁體中文**。程式碼、識別符、檔名維持英文。GitHub issue（含 spec、ticket）標題與內文使用繁體中文；PR 標題與內文維持英文。Git commit message 摘要使用繁體中文（前綴仍用 Conventional Commits）。

## Agent skills

### Issue tracker

GitHub Issues in this repo (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` and `docs/adr/`. See `docs/agents/domain.md`.

### Tests

Primary dev is **Windows**. Run `tools\run_tests.bat` or `.\tools\run_tests.ps1` with `GODOT_BIN` set. See `docs/agents/testing.md`.

### Commit messages

Conventional Commits prefixes (`feat`, `fix`, `test`, `docs`, `refactor`, `chore`, `build`). See `docs/agents/commit-messages.md`.
