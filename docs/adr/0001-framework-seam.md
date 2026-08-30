# Framework directory as the game seam

Status: accepted

Reusable Godot modules live under `framework/` (grouped as `ui/`, `input/`, and `integrations/`). Game-specific rules, content, and wiring stay under `scripts/`, `scenes/`, and narrative assets.

**Dependency direction:** `framework/**` must not import, preload, or reference game paths (`res://scripts/`, `MemeGameState`, pollution, tower floors, meme/social vocabulary, and similar). The game may depend on framework; never the reverse.

**Why not addons/ or a separate repo:** This repo is not publishing shared libraries yet. A top-level `framework/` folder is enough to mark the seam and keep modules extractable for a future Godot project without submodule or release overhead.

**Enforcement:** `tests/test_framework_seam.gd` scans `framework/**` source files (`.gd`, `.py`, `.sh`, `.txt`, `.md`) for forbidden tokens. A batch runner (`tools/run_tests.sh`, `tools/run_tests.ps1`) runs the full headless suite so refactors cannot silently break imports.

**Considered:** `gdcruiser` / architecture-guard for dependency graphs — deferred until CI exists; the seam test is the baseline guard.

**Consequences:** Moving a script into `framework/` requires stripping game knowledge and renaming game-flavoured identifiers (for example `RadialMemeRing` → `RadialSelectorRing`). Remaining B-group helpers still embedded in `babel_meme_game.gd` stay game-side until extracted.
