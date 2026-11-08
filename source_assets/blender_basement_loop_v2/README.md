# 開場黑水與白門的可編輯原始檔

`Opening_WhiteDoor_v2.blend` 是遊戲實際載入的 [Opening_WhiteDoor_v2.glb](../../assets/chapter1/Opening_WhiteDoor_v2.glb) 的 Blender 原始檔：黑水與遠處的白光門。貼圖已打包在 `.blend` 內，沒有外部連結。它在 Git LFS 裡，本目錄有 `.gdignore`，Godot 不會匯入。

改完後重新匯出 GLB 蓋過 `assets/chapter1/Opening_WhiteDoor_v2.glb`；門的位置、出生點與碰撞由 `scripts/world/chapter_one_stage.gd` 依模型擺放，改動門的位置要一起確認。

## 這裡沒有的東西

2026-10-09 的交接副本原本還有舊地下室（`Basement_Loop_v2.blend`）、11 類家具資產庫、預覽圖、貼圖源稿與製作腳本。地下室已換成企劃的 v3b 模型（#128），這些只留在 `main` 的歷史裡（commit `a8c5c7e`），需要時用 `git show a8c5c7e:<路徑>` 取回。整理理由見 [main 合併盤點](../../docs/migrations/main_merge_inventory.md)。
