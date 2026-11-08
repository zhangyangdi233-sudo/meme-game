---
name: ship-ticket
description: 從頭到尾做完一張 GitHub 票：以 TDD 實作、code-review、驗收、關票，最後用重構角度白話說明。使用者說「做 #N」「ship ticket N」時使用。
disable-model-invocation: true
argument-hint: <票號>
---

## 流程

1. **實作到關票**：讀 `.claude/skills/implement-ticket/SKILL.md`，以票號 `$ARGUMENTS` 照做。
2. **說明**：最後用重構的角度，白話文告訴使用者改了什麼：
   - 原本的問題是什麼、重構方向是什麼。
   - 每個被改動的腳本各一段，需有「前因 → 做法 → 結果」。
   - 沒採納的審查建議，與留給後續票的事項。
