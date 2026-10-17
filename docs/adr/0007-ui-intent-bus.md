# Every UI tells the host through one event bus

Status: accepted

Any UI that reports a player action uses the game event bus. The host listens in one place. The main menu is the first caller (`start_game`, `continue_game`, `exit_game`, `language_picker`). Every other UI surface moves onto that same bus: fixed screens and controls whose count is known only at runtime.

The event carries the answer when the action has one: locale, ending choice, post, author, token, drag payload, volume, allow or skip, and the same kind of value.

## Event shape

`intent_emitted(intent_name: String, payload: Dictionary)`. A screen calls `emit_intent(intent_name, payload = {})`. An action without an answer sends an empty payload, so the main menu's calls did not change.

Intent names and each one's payload keys live in `UiIntents` under `scripts/` (Game side; Framework does not know it), beside `PropertyKeys` and `ServiceKeys`. One constant per intent, with its payload written in the comment, and one constant per payload key, for example `LANGUAGE_SELECTED` → `{KEY_LOCALE: String}`. The host and screens use the constants, not bare strings.

The host creates the bus and binds it in the service registry under `ServiceKeys.UI_EVENT_BUS` (ADR 0008). Binding twice is an error; tests clear the registry. A control built at runtime (a language choice, a post card, a tile) resolves the bus itself and emits; the host does not hand it down. A fixed layout scene still lists `BUTTON_INTENTS`.

The host is the only listener. It listens while it is in the tree and stops when it leaves; a later host in the same process reuses the bound bus. Its handler takes the answer and writes the model (ADR 0008); the screen does not.

Buttons that only hide or fold their own window (language "back", quit "return", doll-guide collapse) are UI too. They emit on this bus instead of a private signal or a direct call. Day transition, flashback, and action spend have no player control; when one is added, it uses this bus. That they happened travels on the bus as a game event (see below).

**Already on the bus:** the main menu, the language picker's choice (`LANGUAGE_SELECTED`), the phone launcher (app icons, phone close, app window close), camera consent (allow / skip, chosen source), the phone-camera connection overlay (retry, continue, disable), the settings window (volume, autoplay, VHS, language option, save, return to menu, exit request and confirm, history toggle), the HUD settings button, prologue finished, and the ending screen (language choice, restart). The social feed also raises everything on the bus: channel tabs, page changes, cards, likes, follows, close, the publish confirm, pickup units, and the composer drops, taps and submit. The publish page (composer, last result, confirm) is its own panel, `SocialPublishPanel`; the social shell hands it the page host and it raises the same intents. The notebook does the same: craft, fusion, tab changes, the resting canvas positions (committed once, never per frame), tiles dropped off the canvas or tapped, and the fusion slots. The panel still repaints its own page, channel and open post first; the host hears the intent to re-theme or to act. The reality conversation does the same: choice hover, unhover and press, and the continue button. The panel keeps the hovered choice and its preview itself. The doctor sentence composer raises token press, token drop, slot press and confirm; the token picked so far is the `selected_language_token` model (not saved), written by the host and cleared when the interaction ends or the sentence is confirmed. Hover and unhover only tell the host what the panel has already painted. The settings language option reuses `LANGUAGE_SELECTED`; the host sends it to the in-run handler during a run and to the picker handler otherwise. A runtime-built control raises with `GameEventBus.raise(intent, payload)`, which resolves the bound bus.

**Now every panel that reports a player action is on the bus.** No such panel keeps a private signal to the host. Whether settings is open is the `settings_open` model: the panel writes it and shows or hides its window, and the host registers on the same model to re-evaluate the chrome. The language picker's "back" and the quit "return" only close their own window and never had a private signal.

Signals and callbacks that remain are not a player action reaching the host:

- The flashback overlay hands the host's `finish_pollution_flashback` to its director as `on_sequence_finished`. The flashback has no player control (see above), so it stays a callback until one is added.
- Low-level control signals inside one component (drag and drop, tile moves, radial selection, edge drawer expansion).
- Game-side collaborators that are not panels: the Reality scene adapter (`nearby_targets_changed`, cover watcher), the camera session (`tracking_ui_changed`), and `LanguageMaterial` (`sfx_requested` and the flight and notebook-home requests; pickup and submit return an Action outcome and write the feedback text model). It raises no redraw request: the phone screens watch the free sentence and notebook models, and the guide and playtest windows watch the tutorial progress (ADR 0008). Tracker: #74.

## Game events on the same bus

Amended: the bus also carries game events, not only player actions. A game event is something that happened once and that several unrelated collaborators react to: the day settled, a cover watcher appeared or vanished, the flashback finished, a sound cue was asked for. The `GameEventBus` signal already allows many listeners; only the rule above kept the host the sole one.

- **Intents keep one listener.** A player action still reaches only the host, whose handler writes the model. Nobody else listens for an intent name.
- **Game events may have many listeners.** The sender does not know who listens. Audio, the Reality scene adapter and the desk log subscribe on their own instead of the host calling each one in turn.
- **State stays in models.** An event says that something happened. A fact that something is true now (tracking status, nearby targets, pollution) is a model (ADR 0008). One fact never gets both an event and a model.
- **Names.** Game event names and their payload keys live in `GameEvents` under `scripts/`, beside `UiIntents`, in the same shape: one constant per event with its payload in the comment.
- **Subscribing.** A listener subscribes by event name instead of matching every intent. It subscribes while it is in the tree, or from the moment the host attaches it, and unsubscribes when it leaves, the same lifecycle as the host's listener.
- **Still not events:** signals inside one component (drag and drop, tile moves) and getters polled every frame (flight targets).

Opening and closing via the screen manager (create once, hide, reuse) stays on the main menu until a later ticket. This decision is only the interface UI uses to notify the host. Tracker: #43.
