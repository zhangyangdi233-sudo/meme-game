# MemeGameState public surface inventory

Phase **4b slice 1** documents what callers currently depend on, and pilots the **snapshot out / intent in** seam on social follow/like only. Other domains stay on direct field access until later slices.

## Summary (2026-08-30)

| Metric | Count |
|---|---:|
| Public `var` fields | 90 |
| Public `func` methods | 93 |
| Public `const` | 18 content/config groups |
| Signals (before slice 1) | 0 |
| Signals (slice 1) | 1 — `social_engagement_changed` |
| Signals (slice 2A) | 2 — + `phone_shell_changed` |
| Signals (slice 2B) | 3 — + `action_economy_changed` |
| Signals (slice 2C) | 4 — + `settings_changed` |

**Primary caller:** `scripts/babel_meme_game.gd` (adapter). Tests call `MemeGameState` directly via `RefCounted.new()`.

**C2 problem:** callers read/write bare fields and must remember to `_render()` after mutations. Slice 1 proves one flow where the adapter reads a snapshot and listens for a change signal instead.

---

## Direct field mutation by adapter (worst examples)

These are the highest-risk couplings to retire in later 4b slices:

| Location | Mutation | Risk | Slice 1 status |
|---|---|---|---|
| ~~`babel_meme_game.gd:825`~~ | ~~`game.social_followed_handles = migrated`~~ | ~~bypasses engagement API~~ | **Fixed** — uses `replace_social_followed_handles()` |
| `babel_meme_game.gd:1225-1234` | `game.conversation_* = …` | localizes state in adapter | open |
| ~~`babel_meme_game.gd:2863`~~ | ~~`game.autoplay_enabled = value`~~ | ~~settings write without intent~~ | **Fixed** — uses `set_autoplay_enabled()` |
| ~~`babel_meme_game.gd:2939`~~ | ~~`game.exit_prompt_seen = true`~~ | ~~one-shot flag from UI~~ | **Fixed** — uses `mark_exit_prompt_seen()` |
| `babel_meme_game.gd:3928-3933` | `game.active_app_window` / `active_app` | phone shell closes apps inline | **Fixed** — uses `close_app_window()` |

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

`social_followed_handles`, `social_liked_post_ids`, `published_memes`, `last_publish_result`, `collected_char_units`, `last_char_pick_day`, `char_canvas_positions`, `free_sentence_units`, `world_rules`

### Notebook / meme craft

`notebook_tokens`, `draft_slots`, `completed_memes`, `owned_meme_frames`, `owned_meme_frame_ids`, `fusion_slots`, `fused_meme_pairs`, `dialogue_blanks`, `language_sentence_slots`, `sentence_records`

### Doll / prerequisite world items

`claimed_doll_ids`, `doll_choice_results`, `collected_world_item_ids`, `revealed_prerequisite_item_ids`, `collected_prerequisite_item_ids`, `key_clue_progress`, `history_entries`

### Reality conversation (typed)

`conversation_phase`, `conversation_actor_id`, `conversation_actor_type`, `conversation_actor_label`, `conversation_prompt`, `conversation_result_line`, `conversation_choices`, `conversation_selected_choice_id`, `conversation_clean_sentence`, `conversation_revealed_units`, `conversation_reveal_index`, `conversation_attempts`, `conversation_understood`, `conversation_understanding_rolls`, `conversation_feedback`, `conversation_locale`, `conversation_clean_units`, `conversation_mode`, `conversation_world`, `conversation_selected_token_ids`, `conversation_turns`, `conversation_turn_index`, `conversation_history`, `conversation_can_continue`, `conversation_completed`, `conversation_interrupted`, `conversation_interrupt_line`, `conversation_action_spent`, `conversation_reward`

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
| Snapshot | `get_phone_shell_snapshot()` → `{ view_state, active_app, active_app_window, phone_visible, phone_open }` |
| Signal | `phone_shell_changed(snapshot)` — snapshot includes `change: { kind, target_id, active }` |
| Intent | `set_view_state()`, `set_active_app()`, `set_phone_open()`, `close_app_window(app_id, remaining_open_apps)` |

Legacy fields `view_state` / `active_app` / `active_app_window` / `phone_visible` / `phone_open` remain for save/load; new adapter code should prefer snapshot + signal.

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

### Pollution / tower

`change_pollution()`, `check_pollution_flashback()`, `consume_pollution_flashback()`, `request_floor_transition_for_pollution()`, `resolve_floor_transition_at_boundary()`, `complete_floor_three()`, `get_gameplay_metrics()`

### World items / prerequisites

`is_world_item_collected()`, `get_prerequisite_item_ids()`, `get_prerequisite_item_for_floor()`, `get_key_clue_progress()`, `reveal_prerequisite_item_for_floor()`, `is_prerequisite_item_revealed()`, `collect_prerequisite_item()`, `is_hidden_layer_unlocked()`, `collect_world_item()`, `has_seen_cover_watcher()`, `mark_cover_watcher_seen()`

### History

`record_history_line()`, `get_history_entries()`

### Ending

`get_ending_language_choices()`, `choose_ending_language()`, `get_ending_language_output()`

### Social engagement — **slice 1 seam**

| Kind | API |
|---|---|
| Snapshot | `get_social_engagement_snapshot()` → `{ followed_handles, liked_post_ids }` |
| Signal | `social_engagement_changed(snapshot)` — snapshot includes `change: { kind, target_id, active }` |
| Intent | `toggle_social_follow(handle)`, `toggle_social_like(post_id)` |
| Query | `is_social_following(handle)`, `is_social_post_liked(post_id)` |
| Migration | `replace_social_followed_handles(handles)` — bulk replace + signal |

Legacy fields `social_followed_handles` / `social_liked_post_ids` remain for save/load; new adapter code should prefer snapshot + signal.

### Social char pickup / free sentence

`get_pickup_unit_pool()`, `is_social_char_collected()`, `get_collected_char_units()`, `pick_social_char()`, `get_free_sentence_units()`, `free_sentence_place()`, `free_sentence_remove()`, `free_sentence_place_at()`, `free_sentence_move()`, `free_sentence_clear()`, `get_free_sentence_text()`, `submit_free_sentence()`, `get_player_quote_stage()`, `get_player_echo_quote()`

### Char canvas

`get_char_canvas_position()`, `set_char_canvas_position()`

### World rules

`is_world_rule_active()`, `get_world_rules()`

### Notebook craft / publish

`pick_token()`, `get_craft_slots()`, `get_craft_sentence_preview()`, `place_token_in_slot()`, `confirm_craft()`, `place_meme_in_fusion_slot()`, `confirm_meme_fusion()`, `place_meme_in_blank()`, `confirm_dialogue()`, `get_publish_result()`

### Language bridge / doctor

`get_language_token_options()`, `place_language_token()`, `clear_language_sentence()`, `get_language_sentence_preview()`, `confirm_doctor_sentence()`, `confirm_reality_dialogue()`, `pollute_reality_sentence()`, `get_relationship_state_label()`

### Typed reality conversation

`begin_reality_player_turn()`, `reset_reality_phase_for_day()`, `start_typed_reality_conversation()`, `reset_typed_reality_conversation()`, `get_typed_reality_choices()`, `get_typed_reality_progress()`, `get_typed_reality_history()`, `continue_typed_reality_conversation()`, `configure_conversation_locale()`, `preview_typed_reality_choice()`, `select_typed_reality_choice()`, `advance_typed_reality_character()`, `get_typed_reality_spoken_sentence()`, `get_typed_reality_unrevealed_suffix()`, `get_typed_reality_unit_count()`

### Doll

`is_doll_claimed()`, `get_doll_choice_result()`

---

## Slice 1 contract (social engagement)

```gdscript
# Snapshot (read)
{
  "followed_handles": Array[String],
  "liked_post_ids": Array[String],
}

# Signal payload = snapshot + change metadata
{
  "followed_handles": Array[String],
  "liked_post_ids": Array[String],
  "change": {
    "kind": "follow" | "like" | "bulk_replace",
    "target_id": String,
    "active": bool,  # false for unfollow/unlike/bulk
  },
}
```

**Adapter pattern:** connect `social_engagement_changed` → `_render()`; read engagement via `get_social_engagement_snapshot()`; send intents via `toggle_social_*`. Log copy stays in adapter handlers for slice 1.

**Stop here for human review** before slice 2B (action economy).

---

## Slice 2A contract (phone shell)

```gdscript
# Snapshot (read)
{
  "view_state": "phone_down" | "npc_up",
  "active_app": String,
  "active_app_window": String,
  "phone_visible": bool,
  "phone_open": bool,
}

# Signal payload = snapshot + change metadata
{
  "view_state": String,
  "active_app": String,
  "active_app_window": String,
  "phone_visible": bool,
  "phone_open": bool,
  "change": {
    "kind": "view_state" | "active_app" | "close_app" | "phone_open",
    "target_id": String,
    "active": bool,
  },
}
```

**Adapter pattern:** connect `phone_shell_changed` → `_render()`; read shell via `get_phone_shell_snapshot()` (or adapter `_phone_shell_snapshot()`); send intents via `set_view_state` / `set_active_app` / `close_app_window`. Adapter-local `_open_app_windows` tracks multi-window chrome; state owns foreground app + view.

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

**Stop here for human review** before slice 2C (next domain).

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

**Stop here for human review** before slice 2D (next domain).
