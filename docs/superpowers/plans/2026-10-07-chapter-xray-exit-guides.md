# Chapter X-ray exit guides implementation plan

> Execution uses scoped subagents in the shared checkout. No commits or source Blender edits in this chat.

**Goal:** Show at most three authored red exit arrows only inside the existing camera-driven four-fingertip X-ray window.

**Architecture:** Imported marker meshes use render layer 20. The normal camera excludes that layer; a secondary camera shares the current World3D and follows the normal camera. Its texture feeds the existing HandXRayOverlay, which already clips to the detected fingertip rectangle and expires lost tracking after 420 ms. No new player-facing mode or narrative text is added.

**Tech stack:** Godot 4.6.3, GDScript, GLB node extras, SubViewport and Camera3D.

- [ ] In `tests/test_chapter_xray_layers.gd`, prove metadata-marked roots and their geometry descendants are isolated, unmarked geometry is unchanged, and hidden marks cannot cast ordinary shadows. Run red; implement isolation in `scripts/world/chapter_world.gd`; run green.
- [ ] In `tests/test_chapter_xray_view.gd`, exercise actual camera settings controls with a fake hardware receiver and injected hand landmarks. Verify default/no-gesture state, active frame, stale tracking, phone view, settings, camera disable and chapter teardown. Run red; implement the secondary view in `scripts/world/chapter_xray_view.gd` and connect it from `scripts/babel_meme_game.gd`; run green.
- [ ] Import the final three-arrow GLB and contract from the modeling chat, verify source/copy hashes, inspect imported extras and natural wood chair materials. Preserve current opening gate metadata and opening asset.
- [ ] Capture ordinary, active X-ray and disabled states at the same authored arrow location using `tools/capture_chapter_xray.gd`; verify the arrow is confined to the gesture window. Synthetic landmarks validate the game rendering path, not physical camera detection.
- [ ] Re-capture the two existing lighting review views, inspect wood furniture and broad CRT green spill, and record the focused checks and remaining media/hardware limitations in `docs/chapter1-integration.md`.

No full-route or performance rerun is required for this bounded visual/input integration.
