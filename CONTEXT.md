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

**Floor look**:
Game module (`scripts/game/floor_look.gd`) that answers the 3D street's colors from tables: a material role, the background / ambient / fog, a light or a fixed tint, by floor, district style and UI palette. `RealityFloorGenerator` asks it for every color and decides none itself.
_Avoid_: color literals or palette blends in the generator, one `if built_floor ==` branch per color, treating it as part of the Floor composer

**Floor composer**:
Game module that assembles one tower floor from catalogs and snapshots: who stands where, which items exist, which authored events run. It uses a Floor generator for geometry; that geometry is engine primitives unless a later ticket introduces templates. Interaction stays an interaction outcome, not node signals as the host API.
_Avoid_: treating the composer as Framework, host talking to the composer instead of the Reality scene adapter, one authored .tscn per floor as the source of truth, assuming imported 3D models

**Interaction outcome**:
The Reality scene adapter's report of nearby approach, conversation, or pickup, looked up by id and kind. Host and Reality HUD read this instead of live world objects.
_Avoid_: publish outcome (pollution gain), live actor/item, treating the whole nearby crowd as the API

**Valid interaction**:
A post (free sentence submit), a conversation the player spoke in and then left, or a pickup (a social word or a world item). There are no daily actions, funds or day settlement: the run goes on until the ending. When a valid interaction completes the state runs the progress check: the pollution floor step, the floor-three finish and the hidden ending. A post that just made the exit exist holds the hidden ending back for the next one.
_Avoid_: daily actions, funds, day settlement, checking progress on a timer or when pollution changes

**Action outcome**:
What one valid interaction reports back from the state: whether it counted, whether the pollution flashback is due, and whether the progress check moved the floor. Its settlement is the flashback beat or nothing. The host presents it once: the flashback beat, or the ending, or the redrawn surfaces (which rebuild a new floor). Social char picks and free sentence submits carry one under `outcome`; leaving a conversation returns one from `end_typed_reality_conversation()`.
_Avoid_: host re-checking the floor itself, confusing it with Interaction outcome (Reality approach / conversation / pickup)

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

**Screen manager**:
Host-created opener for one fixed screen. The host builds it at boot (not an autoload). The screen script declares the scene path, layer name, and button intents. The first open instantiates; close hides; the next open reuses that instance. The main menu and the Dialog are opened this way; the Dialog's manager is bound in the service registry so any panel can open it.
_Avoid_: autoload, a manager that also closes other screens

**Dialog**:
The generic modal window any panel opens by resolving its screen manager (`ServiceKeys.DIALOG`) and calling `open(spec)`: a message and one to three buttons, each a UI catalog source key with an optional callback, plus an optional cancel button (Escape and first focus) and owner. A press closes the Dialog, then runs that button's callback. One at a time: a second open is refused with a warning. The owner leaving the tree closes it without a callback. It sits above every other game UI, takes every click, keeps the focus and holds the game's hotkeys while open, and tints itself for the pollution stage. Its text uses the language's formal font (`LocaleFont`: Roboto Condensed Bold, Noto Sans SC Medium, Noto Sans JP Medium), not the pixel font, and swaps it when the language changes; its buttons do not react to hover and show focus as an underline. Refusal, owner and callbacks live on the `DialogScreen`; there is no dialog service. See ADR 0007 for why its callbacks are allowed.
_Avoid_: a dialog service beside the screen manager, a queue of dialogs, the host forwarding opens, a callback that writes host state instead of raising on the bus

**UI intent**:
How any UI tells the host what the player did. The control emits on the game event bus; the host listens in one place. This covers every UI surface, including controls whose count is known only at runtime; no panel keeps a private signal to the host. If the action carries an answer (a locale, a post, a token, a drag), that answer rides along. The main menu is the first caller. See ADR 0007.
_Avoid_: a private signal or callback per panel (for example telling the host that a window opened: write the model instead), a second channel for runtime-built controls, dropping the answer, bare-string intent names or payload keys outside `UiIntents`

**Game event**:
Something that happened once and that several unrelated collaborators react to (a sound cue was asked for, the flashback finished). It rides the same game event bus as UI intents, but listeners subscribe by event name and there may be many; the sender does not know who listens. Names and payload keys live in `GameEvents`. Sound cues (`SFX_REQUESTED`) are the first; the cover watcher appearing and vanishing (`COVER_WATCHER_APPEARED` / `COVER_WATCHER_VANISHED`, with the floor) followed, then the pollution flashback finishing (`FLASHBACK_FINISHED`). The day settling (`DAY_SETTLED`) was removed with the action economy (#108). See ADR 0007.
_Avoid_: a game event for a fact that is true now (that is a model), listening for an intent name outside the host, handing an `AudioStreamPlayer` down so a caller can play it

**Intent handler**:
A Game module that takes one domain's UI intents from the host, changes the state, writes its feedback line, and returns an intent result naming what the host presents. The host stays the only listener and only routes and presents. Each extends the `@abstract` `IntentHandler`; the social feed, the notebook and the settings window have one. A domain's own presentation kinds live on its handler; `IntentResult` keeps the shared ones. See ADR 0007.
_Avoid_: a handler subscribing to the bus itself, a handler reaching into host nodes, the host writing state for an intent a handler claims

**Service registry**:
Global table from a string to one shared object. The host binds services at boot. Callers resolve by that string. Service names live in `ServiceKeys`.
_Avoid_: autoload, passing the same object down through every panel, binding one string twice

**Property manager**:
The service that stores models by name. It does not hold raw values and it does not notify. Screens resolve it from the service registry. See ADR 0008.
_Avoid_: a bag pushed into each screen, a second copy of a fact on the host or on `MemeGameState`

**Model**:
One single-copy value with its observers. An open screen registers and is told the current value; a later write tells every listener. The host observes a model the same way a screen does, instead of connecting to a panel. Callers fetch the model from the property manager each time. Lists and maps are copied on read and changed only through the model's methods. Names and save categories live in `PropertyKeys`.
_Avoid_: keeping a model in a field, writing a list or map in place, storing a derived label or palette as its own model, a screen opening itself because a model changed

**Property watch**:
One screen's registrations on its models, kept in one place. Starting finds every model and registers every listener (each is told the current value once); stopping unregisters them all; the screen leaving the tree stops it too. A screen builds one and starts it when it opens.
_Avoid_: a screen re-writing its own find / register / unregister code, keeping the models in fields, a listener that outlives its screen

**Palette role**:
A named color slot of the UI palette (`surface`, `ink`, `accent`, `error`, `pending`, …), set as `palette_role` metadata on a node in a Layout scene. Tinting swaps the RGB for the active palette and keeps the alpha authored in the editor. `UiPalette.VOID` (true-black horror backdrop) and `UiPalette.OUTLINE` (near-black text and 3D outline) are fixed colors, not roles: pollution never changes them.
_Avoid_: literal colors on palette-driven nodes, one node group per color, a near-black literal where `VOID` or `OUTLINE` is meant

**Scrim**:
The full-screen cover behind a window that hides the game so only that window is read (camera consent, language selection, phone camera connection). `GameUiTheme.scrim()` answers it: the active palette's `ink` at one shared strength, so it follows pollution. Not this recipe: the phone wallpaper tint, and the shared Dialog's `DialogScrim`, a lighter dimmer whose strength is authored in `dialog.tscn` because the window behind a dialog stays readable.
_Avoid_: a panel choosing its own cover alpha or a literal near-black cover

**Hairline**:
A thin divider or faint edge on a dark surface (the HUD rail, the rule above a post's comments). `GameUiTheme.hairline()` answers it: the active palette's `muted` at one shared strength. Not this recipe: the social post card's edge, a stronger `muted` that marks the card rather than divides.
_Avoid_: a panel choosing its own divider alpha

**Button tint**:
The wash behind a hovered or pressed button that has no face of its own (HUD icons, flat phone buttons). `GameUiTheme.hover_tint()` and `pressed_tint()` answer it: the active palette's `muted` at two shared strengths. Not this recipe: the sentence composer's ghost tile, a resting `muted` wash that marks an empty slot rather than a button state.
_Avoid_: a button state choosing its own wash alpha

## Development

**Primary platform**: Windows (Godot 4.6+ editor and headless tests).

**Tests**: `tools\run_tests.bat` or `.\tools\run_tests.ps1`; set `GODOT_BIN` to your Godot executable. See `docs/agents/testing.md`.

**macOS**: still supported for Godot and optional Continuity Camera hand-tracking; use `tools/run_tests.sh` with `GODOT_BIN` set.
