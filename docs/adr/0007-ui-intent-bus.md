# Every UI tells the host through one event bus

Status: accepted

Any UI that reports a player action uses the game event bus. The host listens in one place. The main menu is the first caller (`start_game`, `continue_game`, `exit_game`, `language_picker`). Every other UI surface moves onto that same bus: fixed screens and controls whose count is known only at runtime.

The event carries the answer when the action has one: locale, ending choice, post, author, token, drag payload, volume, allow or skip, and the same kind of value.

## Event shape

`intent_emitted(intent_name: String, payload: Dictionary)`. A screen calls `emit_intent(intent_name, payload = {})`. An action without an answer sends an empty payload, so the main menu's calls did not change.

Intent names and each one's payload keys live in `UiIntents` under `scripts/` (Game side; Framework does not know it), beside `PropertyKeys` and `ServiceKeys`. One constant per intent, with its payload written in the comment, and one constant per payload key, for example `LANGUAGE_SELECTED` → `{KEY_LOCALE: String}`. The host and screens use the constants, not bare strings.

The host creates the bus and binds it in the service registry under `ServiceKeys.UI_EVENT_BUS` (ADR 0008). Binding twice is an error; tests clear the registry. A control built at runtime (a language choice, a post card, a tile) resolves the bus itself and emits; the host does not hand it down. A fixed layout scene still lists `BUTTON_INTENTS`.

The host is the only listener. It listens while it is in the tree and stops when it leaves; a later host in the same process reuses the bound bus. Its handler takes the answer and writes the model (ADR 0008); the screen does not.

Buttons that only hide or fold their own window (language "back", quit "return", doll-guide collapse) are UI too. They emit on this bus instead of a private signal or a direct call. Day transition, flashback, and action spend have no player control; when one is added, it uses this bus.

**Already on the bus:** the main menu, the language picker's choice (`LANGUAGE_SELECTED`), the phone launcher (app icons, phone close, app window close), camera consent (allow / skip, chosen source), and the phone-camera connection overlay (retry, continue, disable). A runtime-built control raises with `GameEventBus.raise(intent, payload)`, which resolves the bound bus.

**Still on private signals or callbacks** (this decision does not edit them):

- Prologue finished
- Ending language choice, and restart
- Language picker "back", and the settings language option
- Quit confirm
- Settings actions, history open, and whether settings is open
- HUD settings
- Social feed, including cards, likes, follows, and the composer
- Reality conversation choices
- Reality language composer
- Notebook craft, fusion, and canvas tiles

Opening and closing via the screen manager (create once, hide, reuse) stays on the main menu until a later ticket. This decision is only the interface UI uses to notify the host. Tracker: #43.
