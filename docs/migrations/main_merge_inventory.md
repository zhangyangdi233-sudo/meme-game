# `main` 合併盤點（#141）

`main` 停在 `4fa71b1`（#85，企劃 10 月的第一章）。`dev` 從 `7951a0e` 分岔後重做了整個第一章，兩邊已經不能逐檔合併。這份盤點把 `main` 從分岔點起動過的 400 個路徑全部分類，並寫下 #131 合回 `main` 的做法。

## 結論

合回 `main` 時，合併結果**完全等於 `dev` 的樹**。`main` 上還需要的內容已經在本票搬進或移植到 `dev`；其他內容都只留在 `main` 的歷史裡，隨時能用 `git show 4fa71b1:<路徑>` 取回。

| 分類 | 路徑數 | 處理 |
|---|---:|---|
| 搬進 `dev` | 20 | 原樣或加註後放進 `dev` 的同一路徑，大檔走 LFS |
| 移植修正 | 6 | `main` 的程式修正改寫進 `dev` 的對應檔，`main` 的版本丟棄 |
| 兩邊相同 | 8 | 內容一致（白門 GLB 在 `dev` 是 LFS 指標） |
| 已被 `dev` 取代 | 171 | 不搬 |
| 只有封存價值 | 195 | 不搬，留在歷史 |

## 搬進 `dev`

| 路徑 | 理由 |
|---|---|
| `docs/design_originals/`（企劃案、遊戲整體流程、地下室草圖） | 企劃的原始設計，第二層以後（#137）還要用 |
| `docs/narrative/`（對白修訂版、逐句對照、任務動機提示鏈、教程順序、四份研究） | 第一到三層的 NPC 任務與結局草稿，#115、#137 的參考；README 加註它不是目前的遊戲內容 |
| `source_assets/blender_basement_loop_v2/Opening_WhiteDoor_v2.blend` | 遊戲仍在用的開場白門 GLB 的可編輯原始檔（39 MB，LFS）；README 改寫成只講這一份 |
| `source_assets/.gdignore` | 讓 Godot 不匯入 `.blend` |
| `assets/audio/dialogue/README.md`、`voice_sources.json` | `dev` 播的地下室耳語的來源與 CC0 出處；README 改寫成只講 `dev` 有的檔 |

LFS 新增 `*.docx`、`*.pdf` 與 `docs/narrative/*.html`；`docs/design_originals/`、`docs/narrative/` 沿用 `main` 的 `-text`，保持位元組一致。`source_assets/` 底下的 `.md` 與 `.gdignore` 不進 LFS。

## 移植的修正

| `main` 的修正 | 移到 `dev` 的哪裡 | 測試 |
|---|---|---|
| 手部追蹤在 Windows 判斷程序存活：已結束但仍有人持有 handle 的程序被當成還活著 | `framework/integrations/hand_tracking/hand_tracker.py` | `tests/test_hand_tracker_lifecycle.py` 兩個新案例 |
| 字塊拖放：停手後放開仍被舊速度甩出、放開時跳回拖動前的位置 | `framework/ui/word_physics_canvas.gd` | `tests/test_word_physics_canvas.gd` 的拖放案例 |
| X 光撕裂條畫出手框外 | `framework/ui/hand_xray_overlay.gd` | `tests/test_hand_xray_clip.gd` |
| `.gitignore` 的 `.blend1`、venv、憑證、`outputs/` 等 | `.gitignore` | — |

## 已被 `dev` 取代（不搬）

- `main` 的第一章實作：`scripts/world/`、`scripts/ui/chapter_*`、`scripts/progression/`、`scripts/narrative/`、`scripts/audio/`、`shaders/chapter_crt*`，以及 31 個測它們的 `tests/test_*.gd`、`tools/` 的截圖與驗證腳本。`dev` 由 Chapter stage、CRT terminal、Chapter one progress 等重做（見 `CONTEXT.md`）。
- `main` 對共用檔的修改：`scripts/babel_meme_game.gd`、`scripts/meme_game_state.gd`、`scripts/localization/`（CRT 的 VHS 偏好，`dev` 是 `terminal_vhs_enabled`）、`tests/test_sentence_composer.gd`、`tests/test_reality_world.gd`、`AGENTS.md`、`README.md`、`.gitattributes`。
- `assets/chapter1/` 的 v2 地下室、純建築版、資產庫、`atmosphere/` 貼圖與兩份契約 JSON：地下室已換成 v3b（#128）。
- 字塊畫布的「CRT 大字塊尺寸」與「版面晚到時保留位置」：`dev` 的 CRT 不用大字塊，實測晚到的版面也不會挪動字塊。
- `shaders/vhs_screen.gdshader` 的調柔與 `scripts/reality_floor_generator.gd` 的塔樓 NPC 站地修正：塔樓不在 demo 內，留給 #137 時再評估。

## 只有封存價值（留在歷史）

- 交接與證據：`docs/handoff/`、`docs/superpowers/` 的 7 份計畫、`GAME_FLOW_MEMORY.md`、`docs/chapter1-integration.md`、`tools/build_revision_handoff.py`、`tools/verify_basement_revision.py`。
- 10/13 的中文文字回填：`docs/text_review/`、`tools/text_review/`，對象是 `main` 的舊文字。
- 本機啟動器：`support/`。
- 舊地下室原始檔：`source_assets/` 除上面搬走的以外（`Basement_Loop_v2.blend`、家具資產庫、預覽、貼圖源稿、製作腳本、`basement_atmosphere/`）。
- 沒接進 `dev` 的音訊：`assets/audio/foley/` 地毯腳步（CC0）與 `tools/prepare_carpet_foley.py`、`03_muted_narrator/` 旁白單音、`D_whisper_fragments/` 耳語短音。要加腳步或旁白聲時從 `558edf6`、`a5ad585` 取回。

## 合回 `main` 的做法（#131）

先確認 `main` 仍是 `4fa71b1`；若有新 commit，這份盤點要重做。

```sh
git switch main
git merge --no-ff --no-commit dev   # 會停在 13 個衝突上
git read-tree --reset -u dev        # 整棵樹換成 dev 的，衝突一併解掉
git diff --cached --stat dev        # 必須沒有輸出
git commit
```

一般 merge，`main` 的歷史保留，不用強推。

2026-11-07 用這個做法試合（`dev` 為本票完成時），`read-tree` 後的樹與 `dev` 完全相同。直接 merge 的話：

- **24 個衝突**，全部取 `dev` 的版本：
  - 兩邊各自新增：`.gitattributes`、`AGENTS.md`、白門 GLB（`main` 是一般檔、`dev` 是 LFS 指標，內容相同），以及本票搬進的 `docs/design_originals/` 兩份 docx、`docs/narrative/` 的 docx、html 與 README、`source_assets/` 的 `.gdignore`、白門 `.blend` 與 README、`assets/audio/dialogue/README.md`（LFS 或加註造成的差異）。
  - 兩邊都改：`.gitignore`、`README.md`、`babel_meme_game.gd`、`game_locale.gd`、`meme_game_state.gd`、`reality_floor_generator.gd`、`test_sentence_composer.gd`，以及已移植修正的 `hand_tracker.py`、`hand_xray_overlay.gd`、`word_physics_canvas.gd`、`test_hand_tracker_lifecycle.py`、`test_word_physics_canvas.gd`。
- **3 個檔會被 Git 默默合進 `main` 的修改**而不報衝突：`ui_catalog.gd`、`vhs_screen.gdshader`、`test_reality_world.gd`。
- `main` 獨有的舊實作、測試與封存檔會全部留在合併結果裡，舊測試會壞。

所以不要逐檔解衝突，整棵樹換成 `dev` 的。
