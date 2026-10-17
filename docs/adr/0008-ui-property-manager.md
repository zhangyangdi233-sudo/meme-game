# UI reads unique state from models on a global PropertyManager

Status: accepted

Passing a prepared dictionary into each screen copies the same fact until the copies disagree. Every fact that exists in one copy moves into a model. A screen that is open registers for the models it displays and updates itself. The host stops pushing bags. This decision does not add the code yet. Tracker: #44.

## Shape

**Service registry.** A global table from a string to one shared object. The host binds it at boot. Anyone, including a screen, resolves by that string. The host does not hand the object down. Binding the same string twice is an error. Tests get a separate clear, not a silent overwrite. Service names live in `ServiceKeys` under `scripts/`.

**Property manager.** The service stored under that registry. It only stores models by name. It does not hold raw values and it does not notify anyone. It is not a Godot autoload: the host creates it and binds it, so tests can bind a clean one. Resolving a missing name is an error.

**Model.** One single-copy value, plus its name, its initial value, and its observers. `changed` is one signal with many listeners. Registering calls the listener once with the current value, then again whenever the value changes. The same listener cannot register twice. Callers fetch the model from the property manager on every read or write. They do not keep the model. Anyone may write. A write of the wrong type reports an error and keeps the previous value. A new run resets the same model to its initial value. Replacing the model would leave open screens listening to the old one.

**Factory.** It receives a name and an initial value and returns a model that remembers that name. It does not list game names. An array becomes a list model. A dictionary becomes a map model. Anything else becomes a value model, locked to the initial value's type. Optional bounds (`min`, `max`) are parameters on that call. The factory forwards them. It does not know that pollution is 0–100. GDScript has no generics for custom classes, so the stored value is a `Variant` checked at runtime.

**Lists and maps.** A read returns a deep copy. Changing that copy does not notify anyone. Add, remove, and replace go through the model's methods, which store a new copy and emit `changed`.

**Names.** Every model name, and which save list it belongs to, lives in `PropertyKeys` under `scripts/`. Three lists: the run (saved with the session), preferences (saved apart from the run), and facts that are not saved (`has_save` is one: the file is the source, the model only publishes whether it exists). Save, load, and new run follow those lists: the save writes every run model, so `MemeGameState` lists only the fields that have not moved yet. A run model that loading rebuilds anyway (the conversation progress) is also named in `RUN_NOT_SAVED`; a new run resets it and the save skips it. The generic types live under `framework/`. `PropertyKeys`, `ServiceKeys`, and the boot registration live under `scripts/`. Framework must not name pollution, floors, or memes (ADR 0001).

## What stays outside

A screen computes what it shows. Palette comes from pollution. Action pips come from `actions_remaining`. The continue button's enabled state comes from `has_save`. Those results are not models.

Which screen is installed stays a Session mode enter and exit (ADR 0004). Opening registers and syncs. Closing unregisters. A closed screen receives nothing, so a change cannot open it. The screen manager stays host-created and only opens or hides a screen (ADR 0007). Player actions still arrive as UI intents. The handler writes the model.

A screen's own view stays on that screen when no one else reads it. The social panel keeps its page, its channel and the post open beside the feed. The notebook keeps its tab. The screen changes them from its own buttons and repaints at once; the social panel tells the host only that the page changed, so it can theme the new nodes. The notebook has no tab buttons yet, so `select_tab()` has no caller in the game; the button that adds one also tells the host to re-theme. They are not saved. A new run starts them over: the world rebuild replaces both panels, and the host also calls `reset_view()`. So there is no fourth list for "not saved, reset on a new run". A value that would go on it is either read by one screen, and stays there, or is a fact other code needs, and becomes a run model (`RUN_NOT_SAVED` covers one that loading rebuilds). Saves made before this still carry `social_screen`, `social_channel` and `social_detail_post_index` in the world section; loading ignores them. Tracker: #58.

Values that move every frame stay on the screen that owns them. The notebook canvas keeps tile positions on its bodies. It writes the map model once before the notebook closes or redraws, and once before save. Per-frame writes are a separate fix: #45.

## Migration

Every single-copy fact moves, not only a short first list. The first implementation was the framework types plus the main menu observing `pollution` and `has_save`. As a domain moves, delete the matching field on `MemeGameState` and retire that domain's change signal. Two notifications for one fact is the copy this decision removes.

**Done:** the facts above are all models (`PropertyKeys`), and no panel keeps a private signal to the host any more (ADR 0007). Whether settings is open is one of them; the host registers on it instead of connecting to a panel.

The desk log watches the feedback text model (FEEDBACK_TEXT, not saved); the host and Language material only write that model; the host words the line from an action outcome, and Language material writes its own pickup and submit lines. Trackers: #73, #75.

Editing the free sentence or picking up a word no longer makes the host redraw the phone shell or the status line. The social publish page and the notebook watch the free sentence and held-word models and repaint themselves; the guide and playtest windows watch the tutorial progress. `LanguageMaterial` only changes the state, and its two redraw signals are gone. After the social panel repaints itself it calls the host's `theme_window` pass on that window, so the new nodes match a host redraw. A pickup or a post that spends an action still goes through the settlement, which redraws what an action changes. Tracker: #74.
