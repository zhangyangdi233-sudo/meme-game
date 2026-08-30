# Babel Meme Game

Standalone Godot 4.6 psychological-horror game built from the third-chapter meme prototype. Its progression is intentionally narrow: publishing produces funds and language pollution; pollution changes floors, dialogue, history, and endings.

## Current Loop

1. Browse image-led social posts and collect language-aware units: a Chinese character, a Japanese lexical unit, or an English word. Every post detail carries a seeded pickup line and an anonymous comment section in urban-legend register; units from a per-locale pool (20-30 Chinese characters guaranteeing at least two subject, verb, and object words after dictionary merge — see `scripts/narrative/pickup_char_pool.gd`) glow inside the text. Tapping one flies it to screen center for confirmation, then shrinks it into the upper-left notebook window, leaving a gray residue in the post. The first pickup each day costs one action; the rest of that day is free.
2. Explore the physical floor and find the stitched guide doll. An authored conversation choice grants one Meme Frame once per encounter.
3. Fuse two completed memes for higher propagation and higher pollution.
4. Build around the day's signal hand, then publish for funds while accepting more pollution.
5. Put the phone away and explore the current tower floor as a first-person 3D street district.
6. Approach a billboard NPC, key NPC, physical clue object, or doll and press `F`. Every previous floor's hottest meme becomes a compulsory legacy phrase in reality dialogue.
7. On each of floors 1-3, answer the key NPC's two questions correctly to reveal that floor's prerequisite object. Collecting all three keeps the hidden fourth floor possible when pollution reaches 80%.

Each day has five effective actions. Navigation, window movement, preview placement, and editing do not spend actions.

After the fifth normal action, the inline action pulse hands off to a 3.6-second internationalist day transition before settlement restores five actions. The one-time 60% pollution flashback runs its own deterministic 3.55-second eight-beat sequence (frozen current frame, doll/doctor attribution swap over an identical protected sentence, triple echo, residue return, unregistered-area pre-memory) driven by `scripts/ui/pollution_flashback_director.gd`, then settles the day directly without stacking this transition. Its phase table, WCAG flash budget, and protected sentences are verified by `res://tests/test_flashback_sequence.gd`.

The phone launcher keeps three Apps in separate movable windows: Tower, Social, and Notebook. The social App uses a tall phone layout with an image-first, equal-width two-column feed, a separate draggable post-detail companion, and a mobile publish flow ordered as content, outcome preview, and signal hand. Following accounts and liking posts from Discover are free and persist across days; Nearby remains unavailable because the device has no location signal.

The meme bank is a right-edge radial selector that appears contextually on the social Publish page and beside the notebook. Completed memes sit on the ring and can be selected with the mouse wheel, a Mac trackpad pan, clicking, or drag and drop. The notebook opens at the upper left and separates frame crafting from two-meme fusion with browser-style tabs.

## Reality Controls

- `WASD` or arrow keys: move freely through the shared street and its open lots.
- Mouse: lowering the phone captures the cursor for free look; `Esc` releases it and a left click captures it again.
- Touchscreen: drag across the open reality view to turn and tilt the camera without spending an action.
- Mac trackpad: two-finger pan follows the physical finger direction; sliding left looks left and sliding down looks down.
- `F`: interact with the nearby NPC, doll, or revealed prerequisite object.
- `Tab`: raise or lower the phone.

The first floor starts with four open street lots along a continuous street at least 230 meters long. Floor two is a near-black irregular disc shaped by broad, walkable hill mounds and scattered detached houses. Floor three is a naturally skylit green-gray gallery whose complete ground is covered by one batched meadow. Floors 1-3 retain their established geography; floor 4 is an unregistered hidden area. All floors keep tested collision, fall recovery, fixed-focus distance blur, cold fog, and no jump-scare trigger volumes.

NPCs use front-facing faceless source portraits at the player's eye line. A separate animated 56 px black-marker layer redraws over the blank face while preserving the original portrait, color, and billboard transform. The stitched cat guide keeps the player's original artwork intact and is never covered by the NPC face effect. Once on every floor, a faceless image watcher may appear beside physical cover, play a 2.45-second non-looping cue, retreat when approached, and remain gone on that floor after saving.

## Adaptive Score

The preserved 96-second reality loop is paired with a distinct 96-second phone loop for each active tower floor. Floors 1-4 use separate original signal arrangements. A five-note `E-G-B-F#-A` motif gives the score a recognizable identity while each floor changes its sound palette and structure. All source audio is deterministic local synthesis with no external samples or transcribed melody.

Regenerate or verify the committed score with NumPy available:

```sh
python3 tools/generate_music_stems.py
python3 tools/generate_music_stems.py --verify
```

Reality conversations use a cursor-driven three-choice surface. Every ordinary NPC carries a three-turn arc that adds concrete district history and can be interrupted by failed understanding. Hovering previews the full clean intention; after selecting, any physical key reveals one language-aware unit. Pollution replaces units with red signal glyphs, while legacy phrases are inserted automatically. The first completed sentence costs one action and the remaining turns are free. NPC dialogue affects language, funds, and authored clue progress; it never grants a random Meme Frame.

Meme Frames come only from physical doll discoveries. Each floor's doll has three authored intentions, stable encounter identity, one-time reward provenance, and save-state locking. Ordinary NPCs never sell or randomly drop a frame.

The notebook now hosts a Duolingo-style free composer: collected units sit in a bank whose slots never reflow (a placed unit leaves a ghost), tap-to-place builds a sentence with no fixed grammar slots, tapping an answer tile withdraws it, and a post can go out at any length for one action. Every post gets one of three world responses — a submitted sentence that parses into the supported rule table (`scripts/narrative/rule_engine.gd`: dictionary max-match merge, then subject × predicate × polarity extraction, Baba-style canonical rule strings with negation override) becomes a standing world rule; a recognizable-but-unsupported sentence is misread; anything else returns as noise. Active rules are listed in the notebook.

Rules are how the ultimate tasks resolve: floor 3 ends only after 门可以打开 (or its ja/en equivalent) holds — the sealed door prop retires and an open frame appears — and the hidden floor 4 ending unlocks only after 出口存在 makes the exit frame exist. Rules written early are redeemed on arrival; achieved tasks stay latched even if the rule is later negated. Finishing floor 3 without every prerequisite object enters the normal ending, even at 80% pollution. Reaching 80% after collecting all three revealed objects enters the hidden fourth floor and its special ending route. Neither route displays a hidden-condition checklist to the player.

The stitched guide doll now also lives in a persistent draggable overlay (fold-only, never closable) that carries the tutorial lines and floor-task hints from the first frame to the last.

## Localization and Saves

The first launch opens a native-name language choice for Chinese, Japanese, and English before the main menu. Language can be changed again in Settings without restarting the run. Settings also provides manual save, audio, visual, and camera controls. During gameplay, `退出游戏` exists only in the fixed Settings system footer. Its only authored interruption is `真的要抛弃我吗？`; the exit commands never corrupt. At high pollution the volume label may change, but its slider remains visible and adjustable.

Chinese remains the authored source language. English and Japanese use audited catalogs covering UI, feed posts, NPC dialogue, floor events, legacy phrases, ending copy, and formatted runtime messages. English collection and corruption operate on complete words, Japanese collection preserves kanji compounds, kana groups, loanwords, and numbered nouns, and Chinese retains character-level rhythm. `res://tests/test_localization.gd` scans the three gameplay scripts for untranslated Chinese literals in addition to exercising the first-run selector and settings controls.

## Run

Open this folder in Godot 4.6 or newer. The main scene is:

```text
res://scenes/babel_meme_game.tscn
```

On this machine, the project can be launched with:

```sh
/Users/zhang/Documents/游戏/Godot_4.6.3/Godot.app/Contents/MacOS/Godot --path /Users/zhang/Documents/游戏/babel-meme-game
```

## Tests

Run the full headless suite (every `tests/test_*.gd` plus Python hand-tracker sidecars):

```sh
GODOT_BIN=/Users/zhang/Documents/游戏/Godot_4.6.3/Godot.app/Contents/MacOS/Godot \
  GODOT_HOME=/Users/zhang/Documents/游戏/.godot_home \
  tools/run_tests.sh
```

On Windows PowerShell:

```powershell
$env:GODOT_BIN = 'C:\path\to\Godot_v4.6.3-stable_win64.exe'
.\tools\run_tests.ps1
```

Run a single test:

```sh
HOME=/Users/zhang/Documents/游戏/.godot_home /Users/zhang/Documents/游戏/Godot_4.6.3/Godot.app/Contents/MacOS/Godot --headless --path /Users/zhang/Documents/游戏/babel-meme-game --script res://tests/test_meme_game_state.gd
```

The rendered publish-layout capture tool is `res://tools/capture_publish_scene.gd`.
Set `BABEL_CAPTURE_FLOOR=1`, `2`, or `3` and run `res://tools/capture_reality_district.gd` from a rendered Godot session to capture each district. Add `BABEL_CAPTURE_OVERVIEW=1` on floor two for the elevated structural QA view. Run `res://tools/capture_meme_bank_motion.gd` to save closed, opening, and open frames plus the measured scale/alpha trace. The generated-floor regression test is `res://tests/test_reality_world.gd`, and the transition/context test is `res://tests/test_day_transition.gd`. Doll evidence is captured by `capture_doll_discovery.gd`, `capture_doll_dialogue.gd`, and `capture_doll_reward.gd`.

Run the localization audit with `res://tests/test_localization.gd`. It verifies catalog parity, dynamic format strings, language-specific text units, first-run language selection, settings language switching, and source-literal coverage.

Run `res://tests/test_pickup_char_flow.gd` for the social pickup system: per-locale pool integrity (every unit seeded in a post, subject/verb/object words ≥2, rule-engine coverage), daily first-pickup action pricing, save round-trips, in-post highlight/gray states, comment sections, the notebook character bank, and the deterministic pickup flight layer.

Run `res://tests/test_rule_engine.gd` for the sentence rule engine: dictionary merge, the three response tiers, free word order, negation polarity, and an exhaustive enumeration of every ≤3-word player sentence in all three locales proving the reachable rule set equals the supported table. Run `res://tests/test_sentence_composer.gd` for the composer state machine, posting economy, ultimate-task latching (including early rules redeemed on arrival and negation never revoking an achieved task), save round-trips, the doll guide overlay, and the floor 3/4 door and exit props.

Run `res://tests/test_reality_world.gd` for continuous architecture, authored NPC population, suspense lighting, walkable clearance, and zero jump-scare trigger volumes.

Reality floors two through four also use a deterministic, floor/day-authored horror table. Movement and camera observation drive a finite light failure, a one-letter EXIT-sign absence, and a transparent distant mirage scheduled only on days four and nine. `res://tests/test_authored_horror_events.gd` verifies the state sequences and confirms that no event is an `Area3D` jump-scare trigger.

The requirement-to-evidence audit and rendered capture paths are recorded in `docs/goal_completion_matrix.md`.

## Third-party Addon

`addons/richtext2/` contains RichTextLabel2 v1.14 by chairfull under the MIT license. Its license is preserved at `addons/richtext2/LICENSE`.
