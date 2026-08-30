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

**Fast** — skips GDScript tests that load `scenes/babel_meme_game.tscn` (~22 files). Use after small module-only changes.

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

## What runs (46 tests)

### GDScript (44)

Headless Godot `--script res://tests/test_….gd`. Each file is a standalone `SceneTree` test.

**Loads main scene** (`--fast` skips these): `test_main_scene`, `test_settings_exit_safety`, `test_localization`, `test_social_feed_layout`, `test_sentence_composer`, `test_pickup_char_flow`, `test_save_progress`, `test_day_transition`, `test_hud_drawer`, `test_hand_xray`, `test_flashback_sequence`, `test_reality_world`, `test_responsive_layout`, `test_audio_runtime`, `test_language_corruption_ui`, `test_simplified_language_core`, `test_doll_ui_flow`, and others that `grep` for `babel_meme_game.tscn`.

**Module-only** (always run, even in `--fast`): `test_framework_seam`, `test_pollution_stage`, `test_meme_game_state`, `test_rule_engine`, `test_language_bridge`, `test_cinematic_bars`, `test_settings_history_panel`, `test_drag_controls`, etc.

### Python (2)

- `test_hand_tracker_candidates.py`
- `test_hand_tracker_lifecycle.py`

Both should pass on Windows when Python 3 is available.

## When to run what

| Change type | Minimum |
|---|---|
| `framework/**` only | `-Fast` (must include `test_framework_seam`) |
| New `scripts/ui/*_panel.gd` | `-Filter` matching that area + main-scene tests if wired |
| `babel_meme_game.gd` adapter / node names | Full suite |
| Before push | Full suite |

There is **no CI** and **no git hook**; tests run only when you or an agent invokes a runner.

## Single test (Windows)

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/test_pollution_stage.gd
```

## Agents

- Prefer `tools\run_tests.bat` or `.\tools\run_tests.ps1` in this repo.
- Do not assume macOS-only Godot paths in handoff prompts.
- If Godot is not installed in the agent environment, report which `-Filter` the human should run locally.
