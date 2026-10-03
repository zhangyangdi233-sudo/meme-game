# Babel Meme Game

Psychological-horror Godot game about language pollution, social publishing, and tower-floor exploration.

## Architecture

**Framework**:
Reusable Godot modules under `framework/` that know nothing about this game's rules, content, or progression.
_Avoid_: addon (when we mean this repo's seam, not third-party plugins), shared, utils

**Game**:
Babel-specific state, narrative, floor composition, and the main scene wiring under `scripts/` and `scenes/`.
_Avoid_: app, core (when used loosely)

**Seam**:
The rule that Framework may be called from Game; Framework must not call back into Game.
_Avoid_: boundary, layer (when used as a synonym for this rule)

Parallel **adapter extractions** under `scripts/integrations/` (`camera_session`, `game_audio_controller`), `scripts/game/` (`social_feed_content`, `narrative_overlay_director`), and `scripts/ui/game_ui_theme.gd` shrink `babel_meme_game.gd` without changing MemeGameState API; see `docs/design/meme_game_state_public_surface.md`.

**Reality scene adapter**:
Game-side facade and composition root for the 3D street. Host talks to this one module via interaction outcomes and look pose, not live world objects. Locomotion and look pose stay on this facade. Internally it may later call a Floor generator and Floor composer.
_Avoid_: Framework, Reality HUD, host reading live world objects as the API, treating locomotion / proximity / floor composition as three host-facing adapters today, letting the main scene compose 3D pieces directly

**Floor generator**:
Framework module that builds walkable space, collision, and generic geometry from engine primitives (cubes and the like). It does not know Babel rules, dolls, catalogs, or which floor the player is on. Cubes are the stand-in for objects; imported 3D models are not required.
_Avoid_: RealityFloorGenerator (current Game bag that mixes generation and composition), Floor composer, moving today's generator into Framework as-is, blocking generation on authored meshes

**Floor composer**:
Game module that assembles one tower floor from catalogs and snapshots: who stands where, which items exist, which authored events run. It uses a Floor generator for geometry; that geometry is engine primitives unless a later ticket introduces templates. Interaction stays an interaction outcome, not node signals as the host API.
_Avoid_: treating the composer as Framework, host talking to the composer instead of the Reality scene adapter, one authored .tscn per floor as the source of truth, assuming imported 3D models

**Interaction outcome**:
The Reality scene adapter's report of nearby approach, conversation, or pickup, looked up by id and kind. Host and Reality HUD read this instead of live world objects.
_Avoid_: publish outcome (funds/pollution), live actor/item, treating the whole nearby crowd as the API

**Look pose**:
The Reality scene adapter's player position and first-person yaw/pitch.
_Avoid_: reading adapter fields as the host API, camera node as the look contract

**Session mode**:
The outer flow's current state: main menu, prologue, gameplay, narrative, or ending. The reusable machine (state interface + manager) is Framework; the five state scripts are Game and are created and injected at boot. Rules flags are transition conditions, not a way to infer the screen. See ADR 0004.
_Avoid_: deriving the screen from overlay flags, treating language picker or camera consent as flow states, a single FSM for phone apps or conversations, putting Babel state names inside Framework

**Content catalog**:
Authored narrative copy grouped by domain and looked up by id. MemeGameState stores ids, not sentences.
_Avoid_: strings file, localization dump, 文案系統

**ContentJson**:
Framework module that reads and caches `content/*.json`. Game catalogs call it; they do not parse JSON themselves.
_Avoid_: per-feature JSON loader, new parser

**Language material**:
Locale-native phrases that *are* the language mechanic (pickup units, echo templates). Each locale writes its own; they do not go through the UI catalog.
_Avoid_: UI copy, translation entry, content catalog (when meaning pickup or echo text)

**Layout scene**:
An editor-authored `.tscn` that owns a fixed screen's layout and look; its panel script only mounts it, tints it, and wires intents. Build UI from code only when the item count is decided at runtime. The main menu (`scenes/ui/main_menu.tscn`) is the first one.
_Avoid_: fixed layouts built from `Control.new()` and pixel offsets, @tool scripts that generate the layout, the global UI theme walk repainting a layout scene

**Palette role**:
A named color slot of the UI palette (`surface`, `ink`, `menu_bg`, …), set as `palette_role` metadata on a node in a Layout scene. Tinting swaps the RGB for the active palette and keeps the alpha authored in the editor.
_Avoid_: literal colors on palette-driven nodes, one node group per color

## Development

**Primary platform**: Windows (Godot 4.6+ editor and headless tests).

**Tests**: `tools\run_tests.bat` or `.\tools\run_tests.ps1`; set `GODOT_BIN` to your Godot executable. See `docs/agents/testing.md`.

**macOS**: still supported for Godot and optional Continuity Camera hand-tracking; use `tools/run_tests.sh` with `GODOT_BIN` set.
