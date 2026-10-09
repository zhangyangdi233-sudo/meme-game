# Opening door implementation and verification plan

> For agentic workers: keep the existing working-tree changes intact. Independent audio, chapter-state, and transition-component work is delegated in this session; integration and rendered verification remain with the main agent.

**Goal:** After ten active seconds in the opening, play one door knock; after it finishes, nearby F performs a slow door close-up and enters the basement. Esc always provides settings and a return to the main menu.

**Architecture:** `ChapterWorld` owns the ten-second wait and positional recording. `BasementLoopDirector` stores the completed-knock flag and validates room progression. `ChapterDoorTransition` owns camera framing, door animation, blackout, and fade-in. The main scene owns input, pause, menu cancellation, and stage replacement.

**Tech stack:** Godot 4.6.3, GDScript, the existing opening GLB, Ogg Vorbis.

## Accepted behavior

- The timer begins in the playable opening, never on the main menu. Settings pauses it.
- The public-domain recording plays once from the door after at least ten seconds. F is unavailable until playback finishes.
- Nearby F starts a 0.35-second camera framing of the full door, 1.6-second door opening, 0.35-second fade to black, room switch, 0.12-second black hold, and 0.35-second fade-in.
- Opening the door enters the authored basement spawn without requiring threshold crossing.
- Esc and F10 open/close settings even while gameplay input is locked. Return-to-menu remains in the fixed settings footer.
- Settings pauses audio and the cinematic. Returning to the main menu cancels pending audio, animations, and room callbacks.
- Saves retain `opening_knock_completed`. An unfinished cue restarts its wait on continue; a completed cue does not repeat. Existing post-opening saves migrate without losing progression.
- Independent narration and later NPC task hooks remain available, but narration no longer unlocks the opening door.

## Implementation steps

- [x] Verify a commercially usable recording and retain its source, permission statement, and checksum in `assets/audio/sfx/opening_door_knock.LICENSE.txt`.
- [x] Add failing chapter-state tests for the new completion flag and `opening_door_opened`; implement guarded dispatch and old-save migration.
- [x] Add failing viewport-input tests for Esc, timing, actual audio completion, F, save/continue, and returning to the main menu during a cinematic.
- [x] Implement positional audio, a nearby opening-door interaction, and explicit pause handling in `chapter_world.gd`.
- [x] Implement and independently test `chapter_door_transition.gd`, including callback order, cancellation, and freeing the old world at the black frame.
- [x] Integrate settings, the fixed return button, animation input locks, localization, and scene cleanup in `babel_meme_game.gd`.
- [x] Update the old chapter tests and capture/walk fixtures to use the new event chain.
- [x] Inspect actual rendered opening, moving leaf, black frame, basement, and settings; repair any visible asset occlusion.
- [x] Record final targeted regression results and rendered evidence in the chapter integration notes.

## Verification commands

Use isolated APPDATA under `D:/aphasia/outputs/opening_door_audit`, and run:

```powershell
& 'D:/aphasia/tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe' --headless --path 'D:/aphasia/meme-game' --script res://tests/test_opening_door_flow.gd
& 'D:/aphasia/tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe' --path 'D:/aphasia/meme-game' --script res://tools/capture_opening_door_transition.gd
```

Other affected suites: basement-loop director, chapter world, main bridge, door transition, door components, mouse input, settings exit safety, localization, responsive layout, reality world, and saved progress. Preserve exit-time resource diagnostics in logs; assertion success does not mean a clean shutdown log.
