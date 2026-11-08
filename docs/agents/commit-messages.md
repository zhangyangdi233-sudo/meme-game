# Commit messages

本 repo 使用 [Conventional Commits](https://www.conventionalcommits.org/) **前綴**。摘要使用**繁體中文**、祈使語氣；冒號後不加句號。

```
<prefix>: <繁中摘要>
```

## Prefix vocabulary

| Prefix | When to use |
|--------|-------------|
| `feat` | New or changed **player-visible** behavior: gameplay, UI, content, audio, progression |
| `fix` | Something was **wrong** and is corrected |
| `test` | Changes under `tests/` or test runners (`tools/run_tests.ps1`, `tools/run_tests.bat`, `tools/run_tests.sh`) |
| `docs` | `CONTEXT.md`, `docs/`, ADRs, agent playbooks — no runtime code |
| `refactor` | Move or reshape code **without** changing intended behavior (common for `framework/` seam work) |
| `chore` | Tooling config, `.gitattributes`, generated `.uid`, dependency bumps, repo hygiene |
| `build` | CI, packaging, release automation |

Avoid unprefixed subjects (`Add …`, `Fix …`) on new commits — older history mixes styles; new work should be consistent.

## Good examples

```
feat: 新增字元級 social pickup 與飛行動畫
fix: 對齊 playtest panel 可見性與 doll-guide 接管
test: 將 responsive layout 斷言釘在 source locale
refactor: 將 cinematic letterbox bars 抽至 framework
docs: 定義 language corruption 重新設計
chore: 透過 gitattributes 強制 LF 換行
build: 新增略過主場景載入的快速測試通道
```

## Subject line

- One line, ~72 characters when practical
- Imperative mood in 繁體中文：`新增`、`修正`、`移除`、`抽出` — not `已新增` / `修正了`
- No trailing period
- Scope tags (`feat(ui):`) are optional; use only when disambiguation helps

## Body (optional)

Separate from the subject with a blank line. Explain **why**, not a file manifest.

```
test: 穩定 Windows headless 整合測試

Pickup flow 測試在 action-spend lock 上 hang 住，且 HUD layout
assignment 透過 position.y 覆寫 offset_top。
```

## Multi-area changes

Pick the **dominant** prefix. If a commit is mostly tests with a tiny production fix required for them to pass, `test:` is fine. If production behavior changes, prefer `feat:` or `fix:`.

## Agents

Cursor rule: `.cursor/rules/commit-messages.mdc` (always applied).
