# Testing

How to run the headless test suite on the **primary development platform (Windows)** and on macOS/Linux.

## Runners

| Platform | Command |
|---|---|
| Windows (recommended) | `tools\run_tests.bat` or `.\tools\run_tests.ps1` |
| macOS / Linux | `tools/run_tests.sh` |

All runners execute every `tests/test_*.gd` file headlessly, then (unless skipped) `tests/test_hand_tracker_*.py`.

## One-time setup (Windows)

1. Install **Godot 4.6+** (project targets 4.6.3).
2. Point `GODOT_BIN` at the executable, for example:

```powershell
$env:GODOT_BIN = 'C:\Godot\Godot_v4.6.3-stable_win64.exe'
```

`tools\run_tests.bat` also tries `C:\Godot\Godot_v4.6.3-stable_win64.exe` when the variable is unset.

3. Optional: isolate Godot editor cache (avoids polluting your user profile):

```powershell
$env:GODOT_HOME = "$env:USERPROFILE\.godot_home"
```

(`GODOT_HOME` is used by `run_tests.sh` on Unix; Windows headless tests usually do not need it.)

4. Python 3 on `PATH` for hand-tracker sidecar tests.

## Modes

**Fast** — skips GDScript tests that `load("res://scenes/babel_meme_game.tscn")` (27 files after the harness split). Use after small module-only changes.

```powershell
.\tools\run_tests.ps1 -Fast
tools\run_tests.bat -Fast
```

**Full** — all `test_*.gd` plus Python sidecar tests. Use before push or after UI / main-scene refactors.

```powershell
.\tools\run_tests.ps1
```

**Filter** — run tests whose **filename** matches a regex:

```powershell
.\tools\run_tests.ps1 -Filter social
.\tools\run_tests.ps1 -Filter "settings|localization"
```

**Skip Python:**

```powershell
.\tools\run_tests.ps1 -SkipPython
```

## macOS / Linux

```sh
export GODOT_BIN=/path/to/Godot
export GODOT_HOME="$HOME/.godot_home"   # optional
tools/run_tests.sh --fast
tools/run_tests.sh
tools/run_tests.sh --filter social
```

`run_tests.sh` falls back to a developer-specific macOS path only when `GODOT_BIN` is unset; always set `GODOT_BIN` in CI or new machines.

## What runs (109 tests)

### GDScript (107)

Headless Godot `--script res://tests/test_….gd`. Each file is a standalone `SceneTree` test.

#### Module-only harness convention

Prefer **state + harness** when the behavior lives in `MemeGameState`, `PollutionStage`, extracted UI modules (`GameUiTheme`, `settings_history_panel`), or narrative content scripts — without needing the full adapter tree.

Shared helpers live in `tests/harness/minimal_game_harness.gd`:

- `new_state()` — `MemeGameState.new()` + `new_run()`
- `find_node_by_name`, `collect_control_text` — Control-tree probes when a tiny scene is still needed
- `craft_token(...)` — notebook / pickup test token dictionaries

```gdscript
const Harness = preload("res://tests/harness/minimal_game_harness.gd")

func _run() -> void:
    var game := Harness.new_state()
    # assert on game.* directly
```

When a file mixes state checks with adapter UI, **split** into `test_<area>.gd` (fast) and `test_<area>_scene.gd` or `test_<area>_ui.gd` (skipped in `--fast`).

#### Classification (`--fast` skips main-scene loaders)

| File | Tier | Notes |
|---|---|---|
| `test_meme_game_state` | state | `RefCounted` state only |
| `test_pollution_stage` | state | `PollutionStage` rules |
| `test_language_corruption_state` | state | hidden route, history, floor transitions |
| `test_doll_system` | state | doll encounters, save migration, notebook craft |
| `test_playthrough_flow` | state | five-action phone → doctor day |
| `test_simplified_language_core` | state | metrics, publish preview, hidden floor |
| `test_action_outcome` | state | publish, fusion, and doctor sentence outcomes: success, spent action, feedback key, settlement (funds, pollution, flashback, day change) |
| `test_player_echo_quote` | state | echo quote stages (deterministic) |
| `test_flashback_sequence` | module | director timeline + determinism |
| `test_ui_font_theme` | module | `PixelFontTheme` + `GameUiTheme` |
| `test_dialog_screen` | module | a dialog opened from the registry builds one to three translated buttons left to right, closes before the callback, skips an empty, null or stale callback (warning on stale), refuses a second open or a bad button count, takes Escape and first focus from `cancel_index`, closes without callbacks when its owner leaves, blocks clicks (also from UI added after it opened), focus and hotkeys below and follows the pollution palette |
| `test_main_menu_scene` | module | main menu Layout scene, palette roles; no separate continue button; an open menu's START continues once `has_save` is true; with a save, holding START 0.8 s by mouse, Enter, Space or pad A opens the restart dialog before release and that release raises nothing, a shorter hold continues, and without a save a hold only starts a new game; the dialog words its question and YES / NO from the catalog with NO focused and taking Escape, YES raises `RESTART_REQUESTED`, closing the menu closes it; the hold hint shows only with a save, is worded on open and darkens while START is hovered or focused; the debug panel shows the held seconds |
| `test_game_locale_preferences` | module | language / volume preference models, preferences file |
| `test_settings_history_panel`, `test_language_selection_panel` | module | the settings panel owns the settings-open model, always watches pollution for its labels, and while open watches preference, autoplay and save-status models; the open history window watches the recorded lines; an exit request opens the shared dialog with the plea, 返回 (focused, Escape) and 仍然退出, only 仍然退出 raises the exit confirm, and the panel builds no confirmation nodes |
| `test_ending_screen_panel` | module | open ending screen watches the chosen ending language |
| `test_phone_launcher_panel` | module | shown phone launcher watches the phone-open and foreground-app models |
| `test_notebook_app_panel` | module | shown notebook watches the held-word, meme, sentence, world-rule and fusion-slot models; hiding writes canvas positions once; it keeps and repaints its own tab; every notebook action raises its intent with the right name and payload |
| `test_reality_conversation_panel` | module | shown conversation panel watches the conversation progress models; it keeps the hovered choice and every conversation action raises its intent with the right name and payload |
| `test_social_feed_panel` | module | shown social app watches the follow, like, held-word, meme, sentence, last-result and published models and repaints itself; it keeps its own page, channel and open post; every social action raises its intent with the right name and payload; it registers its drag handles with the bound window manager and declares no signal |
| `test_social_intent_handler` | module | on an empty bus with `PropertyBoot`, the social intent handler writes likes, follows, the tutorial post count, the window close, pickups, composer drops, taps and submit to the state, words the feedback line, and returns the presentation the host should run |
| `test_notebook_intent_handler` | module | on an empty bus, the notebook intent handler places bank taps and tiles dropped on the answer area, posts the sentence, writes the resting canvas positions, fills the fusion slots from the `selected_meme` model, fuses, words the feedback line, and returns the presentation |
| `test_doctor_sentence_intent_handler` | module | on an empty bus, the doctor sentence handler keeps the `selected_language_token` model, places tokens in the doctor's slots, words the refusals, clears the selection once a sentence is spoken, and returns the presentation |
| `test_settings_intent_handler` | module | on an empty bus, the settings handler writes volume and autoplay, marks the exit prompt seen, and names the settings, save, VHS, history, main menu and quit presentations; it leaves `settings_open` to the panel |
| `test_doll_guide_panel`, `test_playtest_assist_panel` | module | shown guide and playtest panel watch the tutorial progress and floor facts and word their own lines |
| `test_guide_line` | module | guide and test-hint wording from tutorial progress and floor facts alone |
| `test_settings_prologue_ending_intents` | module | settings window, HUD settings button, prologue and ending screen raise their intents with the right name and payload |
| `test_game_event_bus` | module | intent name and payload; the bus binds once under `ServiceKeys.UI_EVENT_BUS`; game events reach only their subscribers, many at once, never the intent listener, and stop after unsubscribe |
| `test_game_audio_controller` | module | the audio controller subscribes to `SFX_REQUESTED`, `COVER_WATCHER_APPEARED` and `DAY_SETTLED` while in the tree, restarts the cue's player, plays the watcher stinger and lets it finish when the watcher vanishes, and re-syncs the mix from the host's inputs when the day settles |
| `test_day_settlement_feedback` | module | the desk-line subscriber, once attached: a settled day clears the meme selection and shows the latest log line; a finished flashback shows the "already the next day" line; a day the flashback settles shows it too, so the line ends on the new day whichever event comes first; a detached one hears nothing |
| `test_narrative_overlay_director` | module | while in the tree the director answers `FLASHBACK_FINISHED` by closing the flashback and asking the host to settle, once; with no flashback on screen, or out of the tree, it settles nothing; a flashback played to its end raises the event; the overlay mounts with no callback |
| `test_cover_watcher_sightings` | module | the sightings subscribe to the watcher events once attached: an appearance marks its floor seen in the run they were last pointed at, a withdrawal records its line, and a detached one hears nothing |
| `test_desk_log_label` | module | the desk log watches the feedback text model while in the tree and translates it through the bound UI theme |
| `test_camera_session_status` | module | the camera session words its status label and translates it through the bound UI theme, again after a language switch |
| `test_property_watch` | module | shared register / sync / unregister helper; a freed owner lets go |
| `test_reality_scene_adapter` | module | RealitySceneAdapter floor tables; while in the tree a `DAY_SETTLED` ends the conversation and forgets the nearby targets |
| `test_framework_seam`, `test_rule_engine`, `test_language_bridge`, `test_narrative_session_catalog`, … | module | no main scene |
| `test_simplified_language_ui` | **adapter** | removed legacy UI copy |
| `test_player_echo_quote_ui` | **adapter** | social echo comment wiring |
| `test_flashback_sequence_scene` | **adapter** | flashback overlay playback |
| `test_day_transition_scene` | **adapter** | day overlay, meme-bank retirement; the host raises one `DAY_SETTLED` per settlement and the desk line, selection and street react; a finished flashback shows the next-day line |
| `test_main_scene` | **adapter** | integration smoke |
| `test_dialog_scene` | **adapter** | boot binds the dialog manager; the debug-only title panel opens the 1/2/3-button samples and logs the press; its save simulation (follow / saved / empty) writes only the `has_save` model, shows the actual save and leaves the file untouched, and a simulated save without a file falls back to a new game; an open dialog sits above every other game UI; a rebuilt world leaves it closed and reusable |
| `test_settings_exit_safety`, `test_localization` | **adapter** | settings / locale UI |
| `test_social_feed_layout`, `test_sentence_composer` | **adapter** | phone shell layout; the social app and detail windows drag through the host's window manager, and the host connects no social panel signal |
| `test_pickup_char_flow`, `test_save_progress` | **adapter** | input lock, save file; START continues from the save, holding it and answering YES starts a new game and leaves the save file, starts a new game with the prologue without one, and falls back to a new game with one warning when the save is corrupt or missing |
| `test_settings_intents_scene` | **adapter** | routing smoke: the host hands volume, VHS, history, exit request and the settings button to the settings handler and presents them, the exit request as the dialog; closing by model restores the chrome; 仍然退出 saves the run and preferences before quitting |
| `test_notebook_intents_scene` | **adapter** | routing smoke: the host hands bank taps, craft, fusion drops and fuse to the notebook handler and presents the submit and the action |
| `test_reality_intents_scene` | **adapter** | the host routes conversation choice and continue itself; routing smoke for the doctor sentence handler (token press, refused confirm); the host keeps no transient selection |
| `test_canvas_positions_save` | **adapter** | saving writes resting tile positions into the model once |
| `test_hud_drawer`, `test_hand_xray` | **adapter** | HUD / camera overlay |
| `test_phone_shell_refresh_ui`, `test_reality_hud_refresh_ui`, `test_surface_refresh_ui` | **adapter** | per-surface snapshot refresh; Session mode visibility; composer intents repaint the publish page from the sentence model without a host redraw |
| `test_reality_world`, `test_responsive_layout` | **adapter** | 3D + layout |
| `test_audio_runtime`, `test_language_corruption_ui` | **adapter** | audio routing (the host raises the land and hinge cues; a watcher appearance plays the stinger and marks the floor without a host handler or adapter signal), polluted menu |
| `test_doll_ui_flow` | **adapter** | 3D doll interaction (craft → `test_doll_system`) |

Re-count skipped files: `grep -l 'load("res://scenes/babel_meme_game.tscn")' tests/test_*.gd`

### Python (2)

- `test_hand_tracker_candidates.py`
- `test_hand_tracker_lifecycle.py`

Both should pass on Windows when Python 3 is available.

## When to run what

| Change type | Minimum |
|---|---|
| `framework/**` only | `-Fast` (must include `test_framework_seam`) |
| `meme_game_state.gd`, pollution, doll flows | `-Fast` (`test_meme_game_state`, `test_pollution_stage`, `test_doll_system`) |
| New `scripts/ui/*_panel.gd` | `-Filter` matching that area + scene tests if wired |
| `babel_meme_game.gd` adapter / node names | Full suite |
| Before push | Full suite |

There is **no git hook**; local tests run when you or an agent invokes a runner. **CI** runs the same Windows full suite on push and pull requests targeting `dev` or `main`.

## CI (GitHub Actions)

Workflow: [`.github/workflows/tests.yml`](../../.github/workflows/tests.yml)

| Local (Windows) | CI |
|---|---|
| `windows-latest` runner matches the primary dev platform | same |
| `GODOT_BIN` → `C:\Godot\Godot_v4.6.3-stable_win64.exe` | same path; downloaded on first run, then cached |
| `.\tools\run_tests.ps1` (full suite) | same command |
| Python 3 on `PATH` for `test_hand_tracker_*.py` | runner ships Python 3 |

**Equivalent local command before push:**

```powershell
$env:GODOT_BIN = 'C:\Godot\Godot_v4.6.3-stable_win64.exe'
.\tools\run_tests.ps1
```

CI does **not** pass `-Fast` or `-Filter`; a green local full run is the closest pre-push check. Use `-Fast` locally for iteration; rely on CI (or a local full run) before merging adapter or main-scene changes.

**Fresh checkout / CI:** `run_tests` runs `godot --headless --import` once when `.godot/global_script_class_cache.cfg` is missing. That builds the global `class_name` registry and imports textures (e.g. `assets/generated/**`) before any test script loads. Local dev with an existing `.godot/` from the editor skips import.

## Single test (Windows)

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_pollution_stage.gd
```

## Agents

- Prefer `tools\run_tests.bat` or `.\tools\run_tests.ps1` in this repo.
- Do not assume macOS-only Godot paths in handoff prompts.
- New state-level coverage: use `minimal_game_harness.gd`; add `*_scene.gd` / `*_ui.gd` only when the adapter tree is required.
- If Godot is not installed in the agent environment, report which `-Filter` the human should run locally.
