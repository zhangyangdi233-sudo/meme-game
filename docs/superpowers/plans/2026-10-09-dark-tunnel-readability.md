# Dark tunnel and CRT readability implementation plan

> **For agentic workers:** Use subagent-driven-development for the independent state, UI and document tasks. Preserve existing uncommitted chapter work; the requested separate GitHub chat owns the final branch backup.

**Goal:** Walk continuously from each basement exit into a dark corridor, open its white door to conceal the next visit/crossroads change, soften VHS, and improve readable CRT typography.

**Architecture:** Keep the corridor within the current basement world and route. Persist `exit_tunnel_entered`, leaving round and token unchanged until the existing camera/door transition reaches full opacity. A standalone tunnel component owns geometry and the white door; the world adapter owns interactions, and main owns the covered scene replacement.

**Tech Stack:** Godot 4.6.3 / GDScript, Forward+ renderer, python-docx and rendered Word QA.

## Tunnel

- [x] Add failing Director tests for premature exit rejection, unchanged round/token on entering the corridor, five covered exits, stale tokens, and save normalization. Implement the boolean and event guards in `scripts/progression/basement_loop_director.gd`.
- [x] Change `tests/test_chapter_world.gd` to require zero `basement_exit_requested` events at the exterior threshold. Require a playable corridor, a separate white-door F event, and saved tunnel restoration; run headless and observe failure before implementing.
- [x] Create `scripts/world/chapter_exit_tunnel.gd` with a 12m walkable corridor, dark walls/ceiling, a visible white paneled door and white light behind the leaf. Attach it at the existing ExitThreshold facing outward. Include floor, side, end and door collision.
- [x] In `scripts/world/chapter_world.gd`, build the corridor in the same world, include its bounds, emit `basement_tunnel_entered` once fully inside, and expose a guarded `tunnel_door_requested` actor. Preserve entrance/NPC/CRT and opening behavior.
- [x] Add optional `cover_color: Color = Color.BLACK` to `chapter_door_transition.begin`. Keep room dispatch strictly after opacity=1. Reuse all pause/cleanup protections.
- [x] In `scripts/babel_meme_game.gd`, route the tunnel request through the transition with Color.WHITE and captured current token. Only its room callback calls `basement_exit_requested`; continue input lock through fade-in.
- [x] Exercise actual renderer frames before, during and after transfer, save/load inside tunnel, pause, repeat F, five visits and crossroads arrival. Use isolated APPDATA/save files.

## Readability

- [x] Verify the existing session theme fails new 36px/character-spacing/line-spacing checks; then set session defaults to 36px, +1px character spacing and 6px line spacing.
- [x] Reduce shader noise/scanlines and make UV jitter respect intensity. Compare fixed renderer images at ordinary and maximum pollution.
- [x] Main sets initial global VHS intensity=.46 and runtime `.44 + min(.16, pollution*.0016)`; minimum CRT `_ui_font_size` becomes 36, preserving existing phone sizing.
- [x] Give `word_physics_canvas.gd` per-instance tile metrics via `configure_tile_metrics(Vector2(54,54),36,font)` before adding CRT units. Preserve top-left save semantics, collision/hit alignment, phone defaults and fit long word units.
- [x] Run the actual curved-screen UV click/word/submit capture, inspect labels, spacing, clipping and fixed actions at the screen boundary.

## Handoff and backup

- [x] Update chapter integration/memory docs with the final tested sequence and current limits.
- [x] Create a separate Chinese Word handoff detailing local changes, old/new flow, code/asset paths, completed checks and development placeholders. Render and inspect every page.
- [ ] Once code and documentation are final, create the user-requested GitHub chat in the aphasia project to review repository scope, create a dedicated branch and upload relevant source/assets/docs without force push or deleting files. Wait for its reported result and provide its branch link.

## Commands / evidence

Run each targeted GDScript test using `D:/aphasia/tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe --headless --path D:/aphasia/meme-game --script res://tests/<test>.gd`. Exit 0 and explicit passed output are required. Renderer captures use Forward+ and hidden windows, with logs/screenshots under `D:/aphasia/outputs/tunnel_readability_20261009`. Do not claim physical webcam or real user video verification from mocked inputs.


