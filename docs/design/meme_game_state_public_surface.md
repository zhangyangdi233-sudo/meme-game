# MemeGameState public surface inventory

Phase **4b** documents what callers depend on and rolls out the **snapshot out / intent in** seam domain by domain (slices 1–7 complete). Parallel **UI/world extractions** shrink `babel_meme_game.gd` without changing MemeGameState API.

## Summary (2026-08-30, post–slice 7 + adapter read cleanup)

### 4b signal seams (MemeGameState)

| Metric | Count |
|---|---:|
| Public `var` fields | 90 |
| Public `func` methods | 103 |
| Public `const` | 27 (19 content/config + 8 script preloads) |
| Signals (before slice 1) | 0 |
| Signals (slice 1) | 1 — `social_engagement_changed` (retired once the follows and likes moved to property models) |
| Signals (slice 2A) | 2 — + `phone_shell_changed` (retired once the phone moved to property models) |
| Signals (slice 2B) | 3 — + `action_economy_changed` |
| Signals (slice 2C) | 4 — + `settings_changed` |
| Signals (slice 3a) | 5 — + `reality_conversation_changed` (retired once the conversation progress moved to property models) |
| Signals (slice 3b) | 5 — `reality_conversation_changed` emitted on all conversation intents (retired with 3a) |
| Signals (slice 4) | 6 — + `day_progress_changed` |
| Signals (slice 5) | 6 — `day_progress_changed` emits from pollution, settle, and floor transition |
| Signals (slice 6) | 7 — + `inventory_changed` (retired once held words and memes moved to property models) |
| Signals (slice 6b) | 7 — `inventory_changed` emitted on `place_token_in_slot` and `confirm_meme_fusion` (retired with 6) |
| Signals (slice 7) | 8 — + `progression_changed` |
| Signals (held words and memes moved to models) | 7 — − `inventory_changed` |
| Open adapter field writes (worst-examples table) | 0 — all retired through slice 3a |

**Adapter read convention:** new adapter render and HUD code should prefer domain snapshot helpers (`_phone_shell_snapshot()`, `_day_progress_snapshot()`, `_progression_snapshot()`, `_inventory_snapshot()`, etc.) over bare `game.*` field reads. Save/load paths and headless `MemeGameState` tests may continue to use fields directly.

**Primary caller:** `scripts/babel_meme_game.gd` (adapter). Tests call `MemeGameState` directly via `RefCounted.new()`.

**C2 problem:** callers read/write bare fields and must remember to `_render()` after mutations. Slice 1 proves one flow where the adapter reads a snapshot and listens for a change signal instead.

### Parallel adapter extractions (no new state API)

| Extraction | Module | Owns |
|---|---|---|
| Apple HUD rail | `scripts/ui/apple_hud_panel.gd` | Day/pollution/actions HUD chrome; reads adapter snapshots |
| Reality 3D scene | `scripts/world/reality_scene_adapter.gd` (slice 1) | Floor rebuild, player locomotion, proximity actors/items; MemeGameState intents stay in adapter |
| Camera / hand X-ray | `scripts/integrations/camera_session.gd` | Hand tracking receiver, X-ray overlay, enable/source intents; settings UI wiring stays in adapter |
| Adaptive audio mix | `scripts/integrations/game_audio_controller.gd` | Score players, floor phone music, flashback ducking, cover-watcher stinger |
| Social feed content | `scripts/game/social_feed_content.gd` | Post/caption/poster pure helpers consumed by `social_feed_panel` mount deps |
| UI theme factories | `scripts/ui/game_ui_theme.gd` | Palette, pixel-font theme, panel/style factories, control-tree localization |
| Narrative overlays | `scripts/game/narrative_overlay_director.gd` | Day-transition tween, action-spend overlay glue, flashback start/finish and input-lock coordination; panels stay extracted |

---

## Direct field mutation by adapter (worst examples)

These are the highest-risk couplings to retire in later 4b slices:

| Location (intent call site) | Retired mutation | Risk | 4b status |
|---|---|---|---|
| `babel_meme_game.gd:822` | ~~`game.social_followed_handles = migrated`~~ | bypasses engagement API | **Fixed** — `replace_social_followed_handles()` (slice 1) |
| `babel_meme_game.gd:1321` | ~~`game.conversation_* = …`~~ | localizes state in adapter | **Fixed** — `configure_conversation_locale()` (slice 3a) |
| `babel_meme_game.gd:2864` | ~~`game.autoplay_enabled = value`~~ | settings write without intent | **Fixed** — `set_autoplay_enabled()` (slice 2C) |
| `babel_meme_game.gd:2940` | ~~`game.exit_prompt_seen = true`~~ | one-shot flag from UI | **Fixed** — `mark_exit_prompt_seen()` (slice 2C) |
| `babel_meme_game.gd:3817` | ~~`game.active_app_window` / `active_app`~~ | phone shell closes apps inline | **Fixed** — `close_app_window()` (slice 2A) |

Most other adapter usage is **read-only** field access (`game.view_state`, `game.tower_floor`, `game.completed_memes`, …) plus method calls.

---

## Public fields by domain

### Run / day economy

`day`, `pollution`, `tower_floor`, `money`, `actions_remaining`, `max_actions_per_day`, `needs_day_settlement`, `day_ended_reason`, `pollution_flashback_seen`, `pollution_flashback_pending`, `event_log`

### Ending / tower progression

`ending_unlocked`, `ending_language_choice`, `ending_route`, `formal_floor_three_complete`, `pending_floor_transition`, `floor3_task_complete`, `floor4_task_complete`, `cover_watcher_seen_floors`

### Phone shell

`view_state`, `phone_visible`, `phone_open`, `active_app`, `active_app_window`, `autoplay_enabled`, `exit_prompt_seen`

### Social / publishing

`published_memes`, `last_publish_result`, `last_char_pick_day`, `free_sentence_units`, `world_rules`

### Notebook / meme craft

`draft_slots`, `owned_meme_frames`, `owned_meme_frame_ids`, `fusion_slots`, `fused_meme_pairs`, `dialogue_blanks`, `language_sentence_slots`, `sentence_records`

### Held words, memes, and canvas positions (run property models)

The held words (`collected_char_units`, `notebook_tokens`) and the finished memes (`completed_memes`) are list models; the notebook canvas positions (`char_canvas_positions`) are a map model. They are saved with the run and reset with it. The state exposes them as accessors: a read is a copy, an assignment replaces the whole list through the model, and picks, crafts, and fusions go through the model's `add` / `insert_at`. `char_canvas_positions` has no setter; positions arrive through `set_char_canvas_positions()`.

### Doll / prerequisite world items

`claimed_doll_ids`, `doll_choice_results`, `collected_world_item_ids`, `revealed_prerequisite_item_ids`, `collected_prerequisite_item_ids`, `key_clue_progress`, `history_entries`

### Reality conversation (typed)

The progress the conversation screen shows lives only in run property models (reset with the run, not part of the save): `conversation_phase`, `conversation_mode`, `conversation_actor_type`, `conversation_actor_label`, `conversation_prompt`, `conversation_result_line`, `conversation_choices`, `conversation_can_continue`, `conversation_feedback`, `conversation_reveal_index`, `conversation_revealed_units`. The state exposes them as accessors that read and write the models; it keeps no second copy.

The typed turn engine keeps its own plain fields: `conversation_actor_id`, `conversation_selected_choice_id`, `conversation_clean_sentence`, `conversation_attempts`, `conversation_understood`, `conversation_understanding_rolls`, `conversation_locale`, `conversation_clean_units`, `conversation_world`, `conversation_selected_token_ids`, `conversation_turns`, `conversation_turn_index`, `conversation_history`, `conversation_completed`, `conversation_interrupted`, `conversation_interrupt_line`, `conversation_action_spent`, `conversation_reward`

### Relationship / doctor dialogue

`npc_understanding`, `reality_phase`, `relationship_residue`, `last_relationship_residue_gain`, `last_relationship_money_loss`, `reality_dialogue_count`, `last_clean_sentence`, `last_polluted_sentence`, `tutorial_progress`

---

## Public methods by domain

### Session / save

`new_run()`, `to_save_data()`, `load_save_data()`

### Tutorial

`notify_tutorial()`, `get_tutorial_step()`, `skip_tutorial()`, `replay_tutorial()`

### Phone / view — **slice 2A seam**

| Kind | API |
|---|---|
| Snapshot | `get_phone_shell_snapshot()` → `{ view_state }` |
| Intent | `set_view_state()`, `set_active_app()`, `set_phone_open()`, `close_app_window(app_id, remaining_open_apps)` |

Whether the phone is open, the current app, and the foreground app window live only in the `phone_open` / `active_app` / `active_app_window` property models (saved with the run). The state reads and writes them through those models; the phone launcher watches them while shown. `phone_visible` was always the same as `phone_open`, so it is gone. There is no phone signal: the launcher listens to the models, and the adapter refreshes after its own phone intents. `view_state` stays a plain field, saved and read through the snapshot.

### Phone / view (legacy listing)

`set_phone_open()`, `set_view_state()`, `set_active_app()`

### Action economy — **slice 2B seam**

| Kind | API |
|---|---|
| Snapshot | `get_action_economy_snapshot()` → `{ actions_remaining, max_actions_per_day, needs_day_settlement, day_ended_reason }` |
| Signal | `action_economy_changed(snapshot)` — snapshot includes `change: { kind, target_id, active }` |
| Intent | `spend_action(action_type)` — emits on successful spend only |
| Query | `can_spend_action()`, `settle_day_if_needed()` |

Legacy fields `actions_remaining` / `max_actions_per_day` / `needs_day_settlement` / `day_ended_reason` remain for save/load; new adapter code should prefer snapshot + signal for HUD refresh.

### Action economy (legacy listing)

`spend_action()`, `can_spend_action()`, `settle_day_if_needed()`

### Settings — **slice 2C seam**

| Kind | API |
|---|---|
| Snapshot | `get_settings_snapshot()` → `{ autoplay_enabled, exit_prompt_seen }` |
| Signal | `settings_changed(snapshot)` — snapshot includes `change: { kind, target_id, active }` |
| Intent | `set_autoplay_enabled(bool)`, `mark_exit_prompt_seen()` |

Legacy fields `autoplay_enabled` / `exit_prompt_seen` remain for save/load; new adapter code should prefer snapshot + signal for settings UI refresh.

### Pollution / tower — **slice 4–5 seam (day progress)**

| Kind | API |
|---|---|
| Snapshot | `get_day_progress_snapshot()` → `{ day, pollution, tower_floor, needs_day_settlement, day_ended_reason, pending_floor_transition }` |
| Signal | `day_progress_changed(snapshot)` — snapshot includes `change: { kind, target_id, active }`; emits from `change_pollution()`, `settle_day_if_needed()`, and `resolve_floor_transition_at_boundary()` |
| Intent | `change_pollution(amount)`, `settle_day_if_needed()`, `resolve_floor_transition_at_boundary()` |

Legacy fields `day` / `pollution` / `tower_floor` / `needs_day_settlement` / `day_ended_reason` / `pending_floor_transition` remain for save/load; new adapter grouped reads should prefer snapshot + signal.

### Pollution / tower (legacy listing)

`change_pollution()`, `check_pollution_flashback()`, `consume_pollution_flashback()`, `request_floor_transition_for_pollution()`, `resolve_floor_transition_at_boundary()`, `complete_floor_three()`, `get_gameplay_metrics()`

### World items / prerequisites

`is_world_item_collected()`, `get_prerequisite_item_ids()`, `get_prerequisite_item_for_floor()`, `get_key_clue_progress()`, `reveal_prerequisite_item_for_floor()`, `is_prerequisite_item_revealed()`, `collect_prerequisite_item()`, `is_hidden_layer_unlocked()`, `collect_world_item()`, `has_seen_cover_watcher()`, `mark_cover_watcher_seen()`

### History

`record_history_line()`, `get_history_entries()`

### Ending — **slice 7 seam (progression)**

| Kind | API |
|---|---|
| Snapshot | `get_progression_snapshot()` → `{ ending_unlocked, ending_route, formal_floor_three_complete, floor3_task_complete, floor4_task_complete }` |
| Signal | `progression_changed(snapshot)` — snapshot includes `change: { kind, target_id, active }`; emits from `complete_floor_three()`, floor 3/4 task latches, and hidden-ending unlock in `_resolve_tower_step()` |
| Intent | `choose_ending_language()`, `complete_floor_three()` |
| Query | `get_ending_language_choices()`, `get_ending_language_output()` |

The chosen ending language lives only in the `ending_language_choice` property model (saved with the run); `choose_ending_language()` writes it and the open ending screen watches it. Legacy fields `ending_unlocked` / `ending_route` / `formal_floor_three_complete` / `floor3_task_complete` / `floor4_task_complete` remain for save/load; new adapter ending and ultimate-task render code should prefer snapshot + signal.

### Ending (legacy listing)

`get_ending_language_choices()`, `choose_ending_language()`, `get_ending_language_output()`

### Social engagement — **slice 1 seam**

The followed authors and the liked posts live only in two run property models (`social_followed_handles`, `social_liked_post_ids`), saved with the run. The state keeps no field for them.

| Kind | API |
|---|---|
| Intent | `toggle_social_follow(handle)`, `toggle_social_like(post_id)` — add or remove through the list model |
| Query | `is_social_following(handle)`, `is_social_post_liked(post_id)`, `get_social_followed_handles()` (a copy) |
| Migration | `replace_social_followed_handles(handles)` — replaces the whole list through the model |

The open social app registers on both models and repaints itself, so there is no change signal and no snapshot.

### Social char pickup / free sentence

`get_pickup_unit_pool()`, `is_social_char_collected()`, `get_collected_char_units()`, `pick_social_char()`, `get_free_sentence_units()`, `free_sentence_place()`, `free_sentence_remove()`, `free_sentence_place_at()`, `free_sentence_move()`, `free_sentence_clear()`, `get_free_sentence_text()`, `submit_free_sentence()`, `get_player_quote_stage()`, `get_player_echo_quote()`

### Char canvas

`get_char_canvas_position()`, `set_char_canvas_positions(tile_positions, locale)` — one batch from the canvas, one map write, none when nothing moved

### World rules

`is_world_rule_active()`, `get_world_rules()`

### Notebook craft / publish — **slice 6 seam (inventory)**

| Kind | API |
|---|---|
| Snapshot | `get_inventory_snapshot()` → `{ completed_memes, notebook_token_count, draft_slots, craft_slot_fills, fusion_slots }` |
| Intent | `place_token_in_slot()`, `confirm_craft()`, `place_meme_in_fusion_slot()`, `confirm_meme_fusion()`, `place_meme_in_blank()`, `confirm_dialogue()` |

The shown notebook watches the held-word and meme models and repaints itself, so there is no change signal. The snapshot stays for the craft and fusion slot labels. The retired signal also fired for `draft_slots` and `fusion_slots`, which are still plain fields; its only reader was the host, and the host repaints the phone after every fusion and slot intent (`place_token_in_slot` has no caller in the host), so nothing listened for those changes alone.

### Notebook craft / publish (legacy listing)

`pick_token()`, `get_craft_slots()`, `get_craft_sentence_preview()`, `place_token_in_slot()`, `confirm_craft()`, `place_meme_in_fusion_slot()`, `confirm_meme_fusion()`, `place_meme_in_blank()`, `confirm_dialogue()`, `get_publish_result()`

### Language bridge / doctor

`get_language_token_options()`, `place_language_token()`, `clear_language_sentence()`, `get_language_sentence_preview()`, `confirm_doctor_sentence()`, `confirm_reality_dialogue()`, `pollute_reality_sentence()`, `get_relationship_state_label()`

### Typed reality conversation — **slice 3a seam** (read-side display subset)

| Kind | API |
|---|---|
| Snapshot | `get_reality_conversation_snapshot()` → `{ phase, mode, actor_type, actor_label, prompt, result_line, choices, can_continue, feedback, reveal_index, revealed_units }` |
| Intent | `configure_conversation_locale(locale_code)` — localizes display fields internally and updates the snapshot |
| Query | `get_typed_reality_choices()`, `get_typed_reality_progress()`, `get_typed_reality_history()` |

The open conversation panel watches the progress models and repaints itself, so there is no change signal. The snapshot stays for the other readers (world prompt, language composer). Do **not** snapshot the full turn engine.

### Typed reality conversation (legacy listing)

`begin_reality_player_turn()`, `reset_reality_phase_for_day()`, `start_typed_reality_conversation()`, `reset_typed_reality_conversation()`, `continue_typed_reality_conversation()`, `configure_conversation_locale()`, `preview_typed_reality_choice()`, `select_typed_reality_choice()`, `advance_typed_reality_character()`, `get_typed_reality_spoken_sentence()`, `get_typed_reality_unrevealed_suffix()`, `get_typed_reality_unit_count()`

### Doll

`is_doll_claimed()`, `get_doll_choice_result()`

---

## Slice 1 contract (social engagement)

No snapshot and no signal. The follows and likes are two list models; the social app registers on them while shown.

**Adapter pattern:** send intents via `toggle_social_*`; the shown social app repaints itself. Log copy stays in adapter handlers.

---

## Slice 2A contract (phone shell)

```gdscript
# Snapshot (read)
{
  "view_state": "phone_down" | "npc_up",
}
```

`phone_open`, `active_app`, and `active_app_window` are property models, not snapshot fields. The old `phone_shell_changed` signal and its payload are gone.

**Adapter pattern:** read the view via `get_phone_shell_snapshot()` (or adapter `_phone_shell_snapshot()`); send intents via `set_view_state` / `set_active_app` / `close_app_window`, then refresh the app content. The phone launcher shows, hides, and raises itself from the models. Adapter-local `_open_app_windows` tracks multi-window chrome.

---

## Slice 2B contract (action economy)

```gdscript
# Snapshot (read)
{
  "actions_remaining": int,
  "max_actions_per_day": int,
  "needs_day_settlement": bool,
  "day_ended_reason": String,
}

# Signal payload = snapshot + change metadata
{
  "actions_remaining": int,
  "max_actions_per_day": int,
  "needs_day_settlement": bool,
  "day_ended_reason": String,
  "change": {
    "kind": "spend",
    "target_id": String,  # action_type passed to spend_action()
    "active": true,
  },
}
```

**Adapter pattern:** connect `action_economy_changed` → `_render()`; read economy via `get_action_economy_snapshot()`; send intents via `spend_action()`. `_after_effective_action()` no longer calls `_render()` when only actions changed — the signal covers HUD/disable-state refresh before the spend animation sets the pre-spend pip count.

---

## Slice 2C contract (settings)

```gdscript
# Snapshot (read)
{
  "autoplay_enabled": bool,
  "exit_prompt_seen": bool,
}

# Signal payload = snapshot + change metadata
{
  "autoplay_enabled": bool,
  "exit_prompt_seen": bool,
  "change": {
    "kind": "autoplay" | "exit_prompt_seen",
    "target_id": String,
    "active": bool,
  },
}
```

**Adapter pattern:** connect `settings_changed` → `_render()`; read settings via `get_settings_snapshot()` (or adapter `_settings_snapshot()`); send intents via `set_autoplay_enabled()` / `mark_exit_prompt_seen()`. Settings menu label refresh in `_render_status()` still runs on pollution-driven renders; autoplay toggle state updates when settings change via the signal path.

---

## Slice 3a contract (reality conversation display)

```gdscript
# Snapshot (read) — display subset only, not the full typed turn engine
{
  "phase": String,
  "mode": String,
  "actor_type": String,
  "actor_label": String,
  "prompt": String,
  "result_line": String,
  "choices": Array,
  "can_continue": bool,
  "feedback": String,
  "reveal_index": int,
  "revealed_units": Array,  # bounded per-character reveal payload for bbcode
}
```

**Adapter pattern:** the conversation panel registers on the progress models while shown; read display for other readers via `get_reality_conversation_snapshot()` (or adapter `_reality_conversation_snapshot()`); send locale intent via `configure_conversation_locale()`. Localization of label/prompt/result/choices happens inside that intent and writes the models.

---

## Slice 3b contract (reality conversation intents)

```gdscript
# Snapshot extension (display subset + bounded typing payload)
{
  # ...slice 3a fields...
  "revealed_units": Array,  # { clean, display, corrupted, roll } per revealed character
}
```

**Intents** (`select_typed_reality_choice`, `advance_typed_reality_character`, `continue_typed_reality_conversation`, `confirm_doctor_sentence`, `configure_conversation_locale`) write the progress models and emit nothing. The panel repaints itself; the adapter refreshes the world prompt and language composer after each intent and keeps `_after_effective_action`, locked-out cleanup, and doll sync side effects.

---

## Slice 4 contract (day progression)

```gdscript
# Snapshot (read)
{
  "day": int,
  "pollution": int,
  "tower_floor": int,
  "needs_day_settlement": bool,
  "day_ended_reason": String,
  "pending_floor_transition": int,
}

# Signal payload = snapshot + change metadata
{
  # ...snapshot fields...
  "change": {
    "kind": "pollution",
    "target_id": String,  # amount passed to change_pollution()
    "active": bool,         # true when amount > 0
  },
}
```

**Adapter pattern:** connect `day_progress_changed` → `_render()`; read grouped day/pollution/tower via `_day_progress_snapshot()` in `_render_status()`, pollution HUD tooltip, and `_pollution_stage_snapshot()`. Send pollution intents via `change_pollution()` (usually indirect through publish/craft paths). Slice 4 emits from the pollution vertical only; slice 5 adds settle and floor-transition emissions (see slice 5 contract).

---

## Slice 5 contract (day settlement and floor transition)

```gdscript
# Snapshot (read) — unchanged from slice 4
{
  "day": int,
  "pollution": int,
  "tower_floor": int,
  "needs_day_settlement": bool,
  "day_ended_reason": String,
  "pending_floor_transition": int,
}

# Signal payload = snapshot + change metadata
{
  # ...snapshot fields...
  "change": {
    "kind": "pollution" | "settle_day" | "floor_transition",
    "target_id": String,  # pollution delta, new day number, or target floor
    "active": bool,
  },
}
```

**Intent → signal mapping:**

| Intent | `change.kind` | When |
|---|---|---|
| `change_pollution(amount)` | `pollution` | when pollution, pending floor, or flashback state changes (slice 4) |
| `settle_day_if_needed()` | `settle_day` | on successful settlement; `target_id` is the new day number |
| `resolve_floor_transition_at_boundary()` | `floor_transition` | when tower floor actually advances; `target_id` is the new floor |

**`action_economy_changed` vs `day_progress_changed`:** `spend_action()` continues to emit `action_economy_changed` on every successful spend, including the last spend that sets `needs_day_settlement`. That signal owns pip count, disable-state, and the *request* to settle. `settle_day_if_needed()` emits `day_progress_changed` with kind `settle_day` and owns day rollover, action refresh, craft-slot clears, and reality reset. Do **not** duplicate an exhaustion-specific `action_economy_changed` in slice 5 — adapter HUD refresh after settlement comes from `day_progress_changed`.

**Adapter pattern:** connect `day_progress_changed` → `_render()`; remove redundant `_render()` after `settle_day_if_needed()` when the signal path already refreshed UI (e.g. `_after_effective_action`). Keep day-transition overlay orchestration side effects (`_play_day_transition`, `_finish_day_transition`, flashback finish). Read `day` / `tower_floor` via `_day_progress_snapshot()` in `_rebuild_reality_floor()` / `_ensure_reality_floor_current()` and floor-transition card updates touched in this slice.

---

## Slice 6 contract (inventory / craft)

```gdscript
# Snapshot (read)
{
  "completed_memes": Array,       # copy read from the meme model
  "notebook_token_count": int,
  "draft_slots": Dictionary,      # slot_id -> token_id
  "craft_slot_fills": Dictionary, # slot_id -> display text for adapter slot labels
  "fusion_slots": Dictionary,     # slot_id -> meme_id (slice 6b)
}
```

**Intents** (`place_token_in_slot`, `confirm_craft`, `confirm_meme_fusion`, `pick_social_char`) write the models and emit nothing. The notebook registers on the held-word and meme models while its window shows and unregisters when it hides. Its canvas hands tile positions to `set_char_canvas_positions()` in one batch before a redraw, a hide, or a save; dragged or still-falling tiles stay on the canvas. Read craft / fusion slot labels via `_inventory_snapshot()`.

---

## Slice 7 contract (progression / ending)

```gdscript
# Snapshot (read)
{
  "ending_unlocked": bool,
  "ending_route": String,
  "formal_floor_three_complete": bool,
  "floor3_task_complete": bool,
  "floor4_task_complete": bool,
}

# Signal payload = snapshot + change metadata
{
  # ...snapshot fields...
  "change": {
    "kind": "complete_floor_three" | "floor3_task" | "floor4_task" | "ending_unlock",
    "target_id": String,
    "active": bool,
  },
}
```

**Intent → signal mapping:**

| Intent / latch | `change.kind` | When |
|---|---|---|
| `complete_floor_three()` | `complete_floor_three` | on success; `target_id` is the route result (`normal-ending`, `hidden-floor`, …) |
| `_latch_ultimate_tasks_for_current_floor()` | `floor3_task` / `floor4_task` | when the corresponding task latch flips true |
| `_resolve_tower_step()` hidden branch | `ending_unlock` | when hidden-route ending unlocks at day boundary |

**Adapter pattern:** connect `progression_changed` → `_render()`; read ending screen and floor 3/4 door logic via `_progression_snapshot()` combined with `_day_progress_snapshot()` for `tower_floor`. `_render()` early-exits to `_render_ending()` when `ending_unlocked` is true in the progression snapshot.
