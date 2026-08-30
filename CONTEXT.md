# Babel Meme Game

Psychological-horror Godot game about language pollution, social publishing, and tower-floor exploration.

## Architecture

**Framework**:
Reusable Godot modules under `framework/` that know nothing about this game's rules, content, or progression.
_Avoid_: addon (when we mean this repo's seam, not third-party plugins), shared, utils

**Game**:
Babel-specific state, narrative, floor generation, and the main scene wiring under `scripts/` and `scenes/`.
_Avoid_: app, core (when used loosely)

**Seam**:
The rule that Framework may be called from Game; Framework must not call back into Game.
_Avoid_: boundary, layer (when used as a synonym for this rule)

Parallel **adapter extractions** under `scripts/integrations/` (`camera_session`, `game_audio_controller`), `scripts/game/` (`social_feed_content`, `narrative_overlay_director`), and `scripts/ui/game_ui_theme.gd` shrink `babel_meme_game.gd` without changing MemeGameState API; see `docs/design/meme_game_state_public_surface.md`.

## Development

**Primary platform**: Windows (Godot 4.6+ editor and headless tests).

**Tests**: `tools\run_tests.bat` or `.\tools\run_tests.ps1`; set `GODOT_BIN` to your Godot executable. See `docs/agents/testing.md`.

**macOS**: still supported for Godot and optional Continuity Camera hand-tracking; use `tools/run_tests.sh` with `GODOT_BIN` set.
