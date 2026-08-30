# Authored session copy lives in a Content catalog

Status: accepted

Prologue, epilogue, doctor lines, prerequisite item copy, and ending language choices are authored in `content/narrative_session.json` and read through Framework `ContentJson`. Game code looks them up by id and locale via `NarrativeSessionCatalog`. `MemeGameState` stores ids, not sentences.

**Why not a new JSON loader:** `ContentJson` already caches `content/*.json`. Per-feature parsers would duplicate that seam.

**Why not the UI catalog:** those files are chrome translations keyed from Chinese source. Session narrative is Content catalog copy; pickup units and echo templates stay Language material.

**Left in the UI catalog:** prerequisite `location_hint` keys, because `event_log` still stores Chinese and the HUD translates it.
