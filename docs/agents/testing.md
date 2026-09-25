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

**Fast** — skips GDScript tests that `load("res://scenes/babel_meme_game.tscn")` (22 files after the harness split). Use after small module-only changes.

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

## What runs (61 tests)

### GDScript (59)

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
| `test_player_echo_quote` | state | echo quote stages (deterministic) |
| `test_flashback_sequence` | module | director timeline + determinism |
| `test_ui_font_theme` | module | `PixelFontTheme` + `GameUiTheme` |
| `test_reality_scene_adapter` | module | RealitySceneAdapter floor tables |
| `test_floor_composer` | module | Floor composer roster for one tower floor |
| `test_framework_seam`, `test_rule_engine`, `test_language_bridge`, `test_narrative_session_catalog`, … | module | no main scene |
| `test_simplified_language_ui` | **adapter** | removed legacy UI copy |
| `test_player_echo_quote_ui` | **adapter** | social echo comment wiring |
| `test_flashback_sequence_scene` | **adapter** | flashback overlay playback |
| `test_day_transition_scene` | **adapter** | day overlay, meme-bank retirement |
| `test_main_scene` | **adapter** | integration smoke |
| `test_settings_exit_safety`, `test_localization` | **adapter** | settings / locale UI |
| `test_social_feed_layout`, `test_sentence_composer` | **adapter** | phone shell layout |
| `test_pickup_char_flow`, `test_save_progress` | **adapter** | input lock, save file |
| `test_hud_drawer`, `test_hand_xray` | **adapter** | HUD / camera overlay |
| `test_phone_shell_refresh_ui`, `test_reality_hud_refresh_ui`, `test_surface_refresh_ui` | **adapter** | per-surface snapshot refresh; Session mode visibility |
| `test_reality_world`, `test_responsive_layout` | **adapter** | 3D + layout |
| `test_audio_runtime`, `test_language_corruption_ui` | **adapter** | audio routing, polluted menu |
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
