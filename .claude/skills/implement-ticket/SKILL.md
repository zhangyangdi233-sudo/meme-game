---
name: implement-ticket
description: 把一張 GitHub 票從實作做到關票：TDD、提交、code-review、驗收。ship-ticket 系列共用的流程，不含最後的說明。
disable-model-invocation: true
argument-hint: <票號>
---

處理票號 `$ARGUMENTS`；若是由其他 skill 指過來讀到這份檔案，把 `$ARGUMENTS` 換成該 skill 給的票號。全程用繁體中文、白話文回覆。

## 流程

1. **讀票**：`gh issue view $ARGUMENTS --comments`，並讀 `CONTEXT.md` 與相關 ADR。票的驗收條件就是完成標準。
2. **實作**：用 `/tdd` 在事先約好的接縫（seam）上實作。每個行為先寫會失敗的測試，確認它真的紅，再寫最少的實作轉綠。平常跑單檔測試（`tools\run_tests.ps1 -Filter <名稱>`），全部做完才跑一次完整測試。遵守 `AGENTS.md` 與 `docs/agents/gdscript-contracts.md`。
3. **提交**：Conventional Commits，摘要用繁體中文，票完成時內文寫 `Closes #N`。
4. **審查**：用 `/code-review`（固定點為實作前的 commit）。硬性違規與正確性問題要修；不採納的建議要說明理由。修完再跑完整測試並提交。
5. **驗收**：逐條對照票的驗收條件，確認每一條有程式或測試佐證。全部達成後，用 `gh issue close $ARGUMENTS --comment "..."` 關票，留言逐條列出驗收結果；若有範圍外的改動或遺留事項，一併寫明。有未達成的條件就不要關票，直接告訴使用者。

## 注意

- 不要略過 TDD；若某個行為無法先寫測試，說明原因。
- 不要 push，除非使用者要求。
