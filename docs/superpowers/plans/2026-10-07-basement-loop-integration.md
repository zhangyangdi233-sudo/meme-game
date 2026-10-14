# Basement Loop Integration Implementation Plan

> For agentic workers: execute independent modules with subagent-driven-development and verify each result before integration. User authorization covers local implementation; do not commit, push, delete in bulk, modify Blender files, or control native UI.

**Goal:** Connect the existing 18 m black-water opening and authored basement to the current game, with event-gated narration, five help-gated visits, persistent progress, and a three-item crossroads gate.

**Architecture:** Keep the existing main scene, controller, UI, and floor generator. A small state director owns chapter progress; imported world adapters consume the asset contract. Reusable door and video components have no narrative text or implicit timers that advance progress.

**Tech Stack:** Godot 4.6.3, GDScript, glTF/GLB, native VideoStreamPlayer and SubViewport. No new third-party plugin dependency.

## Task 1 State and persistence

Files: `scripts/progression/basement_loop_director.gd`, `tests/test_basement_loop_director.gd`, `scripts/meme_game_state.gd`.

- [x] Write failing tests for closed opening, correct narrator sequence, entrance seal, matching task/round token, duplicate rewards, four loopbacks, fifth exit, three unique chapter items, and save round-trips.
- [x] Implement dictionary state with `initial_progress()`, `normalize_progress(raw)`, and `dispatch(progress, event_id, payload)`. Dispatch returns `{accepted, progress, transition}`. State uses `phase`, zero-based `round_index`, `narrator_completed`, `entrance_locked`, completed task IDs, chapter reward IDs, and `transition_serial`.
- [x] Use non-narrative IDs `basement_npc_01..05`, `basement_help_01..05`, `chapter1_gate_item_01..03`. Store configurable reward mapping separately from old hidden-ending prerequisites. Development mapping awards items in rounds 1, 3, 5 and is explicitly marked development-only.
- [x] Add `chapter1_progress` to MemeGameState serialization. Keep `{}` for legacy `new_run` callers/old saves; expose `start_chapter1()` and `notify_chapter1(event_id, payload)` for the main-scene bridge. Missing old-save data never forces chapter replay.
- [x] Run new tests and existing state/playthrough tests. Confirm old prerequisite lists stay unchanged by chapter events.

Example assertions:

```gdscript
var p: Dictionary = Director.initial_progress()
assert(not Director.dispatch(p, "opening_door_crossed", {}).accepted)
assert(not Director.dispatch(p, "narration_completed", {"sequence_id": "wrong"}).accepted)
var completed := Director.dispatch(p, "narration_completed", {"sequence_id": "chapter1_opening"})
assert(completed.accepted)
assert(completed.progress.phase == "opening")
```

## Task 2 Physical door and screen components

Files: `scripts/world/chapter_door.gd`, `scripts/world/chapter_video_screen.gd`, `tests/test_chapter_components.gd`.

- [x] Write failing headless tests for locked door denial, closed physical blocker, opened passability, permanent entry seal, no automatic narration events, blank video safety, and distinct screen materials.
- [x] Door binds a pivot and separate portal collision shape. Only an authorized request opens it; portal collision stays active until opening completes. Safe entry threshold, not the door component's timer, requests `close_and_lock()`.
- [x] Screen binds a MeshInstance3D surface, creates a private material, and accepts an optional local VideoStream. No external media and no autoplay. Expose `set_stream`, `play`, `stop`; stop when removed/reset.
- [x] Run component tests with synthetic nodes. Binding real anchor names is deferred only until the exact asset contract exists; no substitute basement geometry is built.

## Task 3 Main-scene bridge and imported world

Files: `scripts/world/chapter_world.gd`, small changes in `scripts/babel_meme_game.gd`, targeted population option in `scripts/reality_floor_generator.gd`, `tests/test_chapter1_main_bridge.gd`.

- [x] Read exact contract, then copy completed GLB/manifest into `assets/chapter1` and verify file hashes. Resolve named anchor transforms from the imported scene rather than fixed coordinates.
- [x] Add a stage host that supplies spawn, recovery, active actors, interaction range, door thresholds, and environment. It instantiates only one stable-ID development actor per basement visit.
- [x] New-game bridge calls `start_chapter1`; continuing old saves retains the old route. Restore phase before player transform. Suppress pollution/day world switching while the chapter owns space.
- [x] Keep existing first-person input and settings. Stage-specific recovery preserves height and uses valid safe anchors; interactions use world-space range and line-of-sight where needed.
- [x] Formal content remains absent. An explicit `--chapter1-dev` command-line option exposes a persistent development label and separate narration/help completion controls; normal startup does not silently skip or auto-complete them.
- [x] Fifth exit uses existing crossroads geometry with actor/item population disabled. The independent gate checks chapter item IDs before entering existing floor two.

## Task 4 Verify the real route

Files: `tools/verify_chapter1_walk.gd`, `tools/capture_chapter1.gd`, local launch helper and run documentation.

- [x] Run headless integration tests including save at each stage, no skip from duplicate trigger requests, and no hidden-item contamination.
- [x] Import assets with Godot, run main-project rendered capture and collision walk through stairs, TV, right passage, NPC, and exit for five visits. No desktop or Blender UI automation.
- [x] Capture opening distance/door detail, every visit, sealed entry, NPC zone, existing crossroads, and final gate. Record measured runtime rather than infer from Blender renders.
- [x] Run existing state, playthrough, world, save, key-item, main-scene, and affected localization tests. Keep unrelated existing modifications intact.
- [x] Review spec compliance and code quality, repair actionable issues, rerun the affected tests, and document limitations and launch commands.

Test command pattern (all tests use isolated APPDATA):

```powershell
$env:APPDATA = 'D:\aphasia\outputs\basement_integration_audit\test_profile'
& 'D:\aphasia\tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:\aphasia\meme-game' --script 'res://tests/test_basement_loop_director.gd'
```

Baseline before implementation: five core tests exit 0. Existing world/save tests have exit-time RID/ObjectDB/resource diagnostics; compare new runs to the saved baseline rather than reporting the baseline as entirely clean.
