# Goal Completion Matrix

Date: 2026-08-10

This matrix is the handoff contract for independent review. A row is complete only when implementation, automated evidence, and observable runtime evidence agree.

## Verification Baseline

- Godot: `4.6.3.stable`
- Automated suite: every `res://tests/test_*.gd` script is run headlessly as an independent SceneTree test.
- Deterministic asset checks cover active visual assets, UI/audio assets, the cover-watcher stinger, and phone-music stems.
- Rendered captures cover the Japanese feed, floors two and three, NPC dialogue, physical doll discovery/dialogue/reward, authored horror events, the cover-watcher sequence, and the meme-bank motion sequence.
- Short-lived capture scripts still produce Godot shutdown-time RID/resource warnings after a successful saved frame. No GDScript error, scene-load failure, or rendering failure occurs; this is recorded as a harness limitation rather than hidden.

## Requirement Evidence

| # | Requirement | Implementation evidence | Automated evidence | Runtime evidence |
| --- | --- | --- | --- | --- |
| 1 | Japanese social cards have equal width; heights may differ; cards open. | `babel_meme_game.gd` builds two equal-width independent `VBoxContainer` columns inside `SocialFeedMasonry`, assigns each card to the shorter column, clips localized copy, and keeps the whole card as its pointer target. | `test_social_feed_layout.gd` compares every rendered width within 0.5 px, requires staggered heights, verifies 10 px adjacency inside each independent column so short cards cannot create grid-row holes, then injects a real pointer click and verifies the detail page. | `tools/current_social_japanese.png`, `tools/current_social_japanese_detail.png` |
| 2 | Floor three uses full-map grass and brighter natural light; floor two returns to near-black. | `reality_floor_generator.gd` creates one 50,000+ instance grass MultiMesh over the complete map bounds. Floor 2 ambient/key energy are 0.14/0.30; floor 3 uses 0.68/1.18 with cleaner fog and skylights. | `test_reality_world.gd` checks full culling bounds, coverage ratio 1.0, density, natural-light metadata, and the floor 2/3 energy separation. | `tools/current_reality_floor_2.png`, `tools/current_reality_floor_3.png` |
| 3 | Preserve phone-down music and route a distinct loop to every active floor. | Four active 96-second stereo phone loops plus the preserved reality loop are selected by floors 1-4 in `babel_meme_game.gd`; an older floor-five synthesis remains compatibility-only and is never selected. | `test_phone_music_assets.gd` verifies deterministic source assets; `test_audio_runtime.gd` verifies active floor routing and crossfade behavior. | Runtime audio players load and play in `test_audio_runtime.gd`; metadata is in `assets/generated/audio/babel_liminal_score.json`. |
| 4 | Remove frame purchasing and random NPC drops; obtain Meme Frames through discovered doll conversations. | Floors 1-3 spawn a physical `doll` actor using the project owner's exact guide art. Three authored choices can grant different one-time frame IDs; pollution gating, claimed IDs, provenance, and V3-to-V4 save migration are explicit. Ordinary NPCs never grant frames. | `test_doll_system.gd`, `test_doll_ui_flow.gd`, `test_main_scene.gd`, `test_reality_world.gd`, and `test_meme_game_state.gd` cover state, UI, world placement, repeat locking, and removed-shop normalization. | `tools/current_doll_discovery.png`, `tools/current_doll_dialogue.png`, `tools/current_doll_reward.png`. |
| 5 | Add recognizable low-poly horror/dreamcore objects, place them logically, and make them non-pickup. | Nine original procedural families: false window, water cooler, CRT cart, payphone, folding chair, vending machine, fluorescent troffer, supply crates, and pipe manifold. | `test_reality_world.gd` requires every family, at least 18 instances, defining silhouette parts, original procedural metadata, and zero pickup/interactable paths. | `tools/current_floor_2_*.png` and `tools/current_floor_3_*.png`; rationale in `docs/design/backrooms_prop_research.md`. |
| 6 | Floor two is a large uneven irregular circle with sparse scattered houses and player-visible small hills. | A 96 by 24 segment unequal-radius ArrayMesh disc combines thirteen deterministic smooth mounds with matching trimesh collision. Nine detached physical houses are spread across both axes and multiple elevations; only six are gameplay rooms. Production metadata derives house coverage from actual box footprints divided by the shoelace area of the authored boundary polygon. | `test_reality_world.gd` independently reads terrain vertices, requires at least four metres of height range and a raised crest in every quadrant, sums live `BoxMesh` footprints and projected mesh-triangle area, requires a 35,000+ planar area and at most 1% house coverage, then compares the result with production metadata. It also checks center fill, boundary clamping, collision, nine physical houses, three scenery-only houses, and two-axis/elevation spread. | `tools/current_reality_floor_2.png`, `tools/current_reality_floor_2_overview.png`, plus floor-two artifact captures. |
| 7 | Fixed focal depth keeps nearby content clear and distant content soft. | The reality camera remains at a fixed 58 degree FOV in walking and NPC interaction. Far DOF begins at 18 m over a 12 m transition; near blur is disabled. | `test_reality_world.gd` checks FOV before and during interaction, all DOF attributes, and the `near_clear_far_soft` profile. | Distance falloff is visible in floor and object captures. |
| 8 | Simplify the meme bank and use `easeOutQuint` for contextual motion. | Meme bank is contextual to notebook/publish only; its radial selector supports wheel, trackpad, touch, and clicks. Godot `TRANS_QUINT + EASE_OUT` implements the requested GSAP `power5.out` curve without a web dependency. | `test_day_transition.gd` checks contextual visibility, interrupted open/close tweens, curve metadata, and no action cost; `test_drag_controls.gd` checks ring movement and the same curve. | `tools/current_meme_bank_closed.png`, `tools/current_meme_bank_opening.png`, `tools/current_meme_bank_open.png`, and `tools/current_meme_bank_motion_trace.json` form a live three-sample motion record; `tools/current_notebook_view.png` and `tools/current_publish_view.png` show both contexts. |
| 9 | Learn from the local Milk installation's atmosphere and writing without weakening originality. | Presentation uses short observation/correction beats, viewpoint-bound UI, selective disruptions, and ordinary-object anchors. No archive, dialogue, image, or audio was copied into the project. | `test_localization.gd`, `test_richtext_effects.gd`, and dialogue/state tests protect authored cadence and playable flow. | Direction and originality boundary: `docs/design/character_and_narrative_direction.md`, `docs/design/denpa_cartoon_horror_direction.md`. |
| 10 | Improve English/Japanese localization as localization rather than literal substitution. | Parallel catalogs cover active UI, feed, NPCs, doll dialogue, events, endings, dynamic formats, and language-specific tokenization. Removed shop, Tarot, relic, and fifth-floor UI copy is absent from active catalogs. | `test_localization.gd` checks catalog-key parity, ordered placeholder parity, terminology, native sample lines, source-literal coverage, and Chinese/English/Japanese text-unit rules. | `tools/current_social_english.png`, `tools/current_social_japanese.png`, `tools/current_language_selection.png`; audit in `docs/research/localization_voice_audit.md`. |
| 11 | NPC face obstruction is animated, opaque black handwriting on a separate layer. | Untouched NPC `Billboard` and independent `FaceScribbleOverlay` are unshaded camera-facing sprites; the overlay uses a four-frame atlas, 56 px black strokes, higher render priority, and no multiply/dark rectangle. The guide doll keeps its original face and has no scribble overlay. | `test_reality_world.gd` checks source preservation, transform registration, shader path/parameters, billboard behavior, opacity, width, priority, and doll exemption. | `tools/current_npc_character_view.png`, `tools/current_npc_character_view_phase_b.png`, and doll captures. |
| 12 | Keep progression simple and hide the fourth-floor condition. | Global HUD exposes Pollution, Funds, and Actions; day remains an internal scheduler and floor appears only inside the Tower App. Heat, Clarity, threshold discounts, Tarot, shops, and random frame rewards are gone. The Tower App does not display prerequisite counts or a hidden-route checklist. | `test_simplified_language_core.gd`, `test_main_scene.gd`, and state/playthrough tests protect the reduced surface and pollution thresholds. | `docs/design/mechanics_surface_audit.md` records every retained and removed value. |
| 12A | NPC and guide art should feel unsettling, indie, and slightly cartoon rather than mature-realistic. | Three curated 1024 x 1536 NPC portraits share faceless cream heads, restrained green/black print grain, compact proportions, and role-specific props. The permanent guide is the project owner's exact stitched-cat artwork. | `test_character_assets.gd` pins the curated sources, guide hash, transparent canvas, palette, and featureless NPC face region; `test_reality_world.gd` verifies floor-independent colors. | Source assets under `assets/generated/characters/`; current NPC and doll captures above. |
| 13 | Overall presentation should use restrained psychological-horror craft inspired by repeated-space, compliance, and subjective-perception references. | Deterministic light-memory, failed-sign, rare mirage, language-pollution flashback, inherited-language pressure, and non-jumpscare spatial repetition form one authored system. | `test_authored_horror_events.gd`, `test_playthrough_flow.gd`, `test_language_corruption_state.gd`, and `test_main_scene.gd` cover scheduling, state transitions, progression, and both ending routes. | `tools/current_horror_*.png`; research synthesis in `docs/design/psychological_horror_event_research.md`. |
| A | NPCs are eye-level, slightly cartoon, and have no facial details. | All three NPC source images are featureless. Runtime normalizes portraits to the first-person eye line and keeps image and handwriting layers billboarding together. The smaller doll is framed with a doll-specific camera pitch. | `test_character_assets.gd`, `_assert_actor_face_veil()` in `test_reality_world.gd`, and `test_doll_ui_flow.gd`. | Latest NPC and doll captures above. |
| B | A faceless watcher appears once per floor behind nearby cover, retreats on approach, vanishes, and plays a 2-3 second cue. | Per-floor persistent seen state, cropped image billboard exposing roughly half the body, physical cover, a strict delay-plus-view trigger, 6.4 m approach threshold, quint retreat, and 2.45 s non-looping generated stinger. | `test_cover_watcher.gd` computes visible width from live geometry and verifies that neither looking away nor moving quickly can bypass the appearance delay. `test_save_progress.gd` drives the real generator signal through the main scene, checks audio, approaches until vanished, saves, continues, and verifies the event cannot rebuild. `test_audio_runtime.gd` verifies the cue. | `tools/current_horror_cover_watcher.png`, `tools/current_horror_cover_watcher_retreat.png`, `tools/current_horror_cover_watcher_gone.png`. |

## Test Command

Each test is a standalone SceneTree script.

**Windows (primary):**

```powershell
$env:GODOT_BIN = 'C:\Godot\Godot_v4.6.3-stable_win64.exe'
& $env:GODOT_BIN --headless --path . --script res://tests/test_reality_world.gd
```

Or run the full suite: `tools\run_tests.bat`

**macOS / Linux:**

```bash
GODOT_BIN=/path/to/Godot \
  GODOT_HOME="$HOME/.godot_home" \
  $GODOT_BIN --headless --path . --script res://tests/test_reality_world.gd
```

## Asset Integrity Commands

```bash
python3 tools/generate_visual_assets.py --verify
python3 tools/generate_audio_assets.py --verify
python3 tools/generate_cover_watcher_stinger.py --verify
/Users/zhang/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 tools/generate_music_stems.py --verify
```
