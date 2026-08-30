# Session input owner is derived from adapter flags

Status: superseded by ADR 0004

Which overlay currently owns player input is **Session mode**. The adapter derives it with `SessionInput.owner_from(prologue_visible, input_locked, game_started)` instead of storing a parallel FSM.

**Runtime owners (this slice):** `prologue`, `narrative_lock` (via existing `_input_locked`), `main_menu`, `gameplay`. `_input()` blocks world pointer routing for prologue and narrative lock. `_unhandled_input()` blocks all non-gameplay owners. UI handlers still consult `_input_locked` directly.

**Documented, not derived yet:** `ending`, `language_picker`, `camera_consent`. Ending still replaces the UI through `ending_unlocked`; first-run overlays still own their own Controls.

**Why not a stored enum written on every transition:** `_input_locked` is already the narrative-overlay lock. A second writeable mode would be two sources of truth.

**Why not Framework:** Session mode is Babel vocabulary (prologue, day-transition lock, main menu). Framework must not learn those owners.

**Left for a later slice:** a `SessionInputGate` that replaces the ~38 handler early-returns.
