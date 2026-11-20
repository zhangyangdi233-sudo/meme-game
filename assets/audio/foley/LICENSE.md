# Carpet footsteps: recorded walking, selected A source

## Active WAVs — Mihacappy, CC0 1.0, verified 2026-10-19

`carpet_step_01.wav` through `carpet_step_04.wav` now derive from the real recording
**“steps_carpet.wav” by Mihacappy**, published March 15, 2026:

- Author's original page: https://freesound.org/people/Mihacappy/sounds/848210/
- License: https://creativecommons.org/publicdomain/zero/1.0/
- Retained source: `carpet_steps_mihacappy.ogg`
- Source download: https://cdn.freesound.org/previews/848/848210_10594370-lq.ogg

The author page explicitly marks the sound CC0 and permits commercial use,
adaptation and redistribution without requesting permission or attribution.
The author requests no AI-model training; this project only edits and plays the
recording as game audio. No model was trained. Attribution is retained here for
provenance, without implying endorsement.

The Ogg is the complete public compressed preview, not the original lossless WAV.
The source page and CC0 deed were checked again and saved in
`D:/aphasia/参考/20261019-carpet-walking/`. Source and output SHA256 hashes and
exact cut locations are in `carpet_steps_source.json`.

The user explicitly chose the original A recording after hearing new licensed
alternatives. The synthesized B/C contacts are no longer active. Current WAVs use
48 kHz mono PCM16. They preserve A's four source contacts, source normalization,
65 Hz / 1150 Hz soft filtering, and existing small pitch variations. Each original
0.48-second A cut is filtered in full before retaining its 40–320 ms region with
6 ms / 18 ms edge fades. This removes excess lead-in/tail without resynthesizing
the body or changing the recording's speed. Runtime gain remains `-20 dB`.

Normal walking now triggers every 1.95 metres at the authored 3.3 m/s speed:
**0.5909 seconds per contact**, matching the original recording's ~0.59-second
walking cadence. Actual sprint input retains its separate 0.3112-second cadence.
Each 0.28-second contact finishes even at the lowest pitch (0.97), and playing
contacts cannot be restarted mid-sound.

Reproduce with Python + NumPy + SoundFile:

```text
python tools/prepare_carpet_foley.py
python tools/prepare_carpet_foley.py --verify
python tests/test_carpet_audio.py
```

On this Windows workspace the tested interpreter is
`D:/aphasia/tools/hand-tracking-venv/Scripts/python.exe`, which already includes
NumPy; SoundFile is already installed under `D:/aphasia/tools/audio-processing`.
The system-default Python lacks NumPy. In PowerShell:

```powershell
$env:PYTHONPATH = 'D:/aphasia/tools/audio-processing'
& 'D:/aphasia/tools/hand-tracking-venv/Scripts/python.exe' tools/prepare_carpet_foley.py --verify
& 'D:/aphasia/tools/hand-tracking-venv/Scripts/python.exe' tests/test_carpet_audio.py
```

The generator verifies both source/output hashes and exact PCM reproduction.
No Python packages are required by the running game.

## Additional downloaded alternatives — not used at runtime

- SpliceSound, “01-24 Footsteps, Rug, Slippers, Slow Pace.wav”, CC0:
  https://freesound.org/people/SpliceSound/sounds/260116/
- taure, “walk carpet.wav”, CC0:
  https://freesound.org/people/taure/sounds/575321/
- AlexMurphy53, “Footsteps - Carpet”, CC BY 4.0 (commercial use requires attribution):
  https://freesound.org/people/AlexMurphy53/sounds/542059/

Their full official HQ MP3 previews and primary license evidence are retained in
the reference folder above. The audition of AlexMurphy53's recording is trimmed
and level-adjusted, licensed under https://creativecommons.org/licenses/by/4.0/.
No original files or earlier A/B/C audition artifacts were deleted.
