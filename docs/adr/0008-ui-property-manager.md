# UI reads unique state from models on a global PropertyManager

Status: accepted

Passing a prepared dictionary into each screen copies the same fact until the copies disagree. Every fact that exists in one copy moves into a model. A screen that is open registers for the models it displays and updates itself. The host stops pushing bags. This decision does not add the code yet. Tracker: #44.

## Shape

**Service registry.** A global table from a string to one shared object. The host binds it at boot. Anyone, including a screen, resolves by that string. The host does not hand the object down. Binding the same string twice is an error. Tests get a separate clear, not a silent overwrite. Service names live in `ServiceKeys` under `scripts/`.

**Property manager.** The service stored under that registry. It only stores models by name. It does not hold raw values and it does not notify anyone. It is not a Godot autoload: the host creates it and binds it, so tests can bind a clean one. Resolving a missing name is an error.

**Model.** One single-copy value, plus its name, its initial value, and its observers. `changed` is one signal with many listeners. Registering calls the listener once with the current value, then again whenever the value changes. The same listener cannot register twice. Callers fetch the model from the property manager on every read or write. They do not keep the model. Anyone may write. A write of the wrong type reports an error and keeps the previous value. A new run resets the same model to its initial value. Replacing the model would leave open screens listening to the old one.

**Factory.** It receives a name and an initial value and returns a model that remembers that name. It does not list game names. An array becomes a list model. A dictionary becomes a map model. Anything else becomes a value model, locked to the initial value's type. Optional bounds (`min`, `max`) are parameters on that call. The factory forwards them. It does not know that pollution is 0–100. GDScript has no generics for custom classes, so the stored value is a `Variant` checked at runtime.

**Lists and maps.** A read returns a deep copy. Changing that copy does not notify anyone. Add, remove, and replace go through the model's methods, which store a new copy and emit `changed`.

**Names.** Every model name, and which save list it belongs to, lives in `PropertyKeys` under `scripts/`. Three lists: the run (saved with the session), preferences (saved apart from the run), and facts that are not saved (`has_save` is one: the file is the source, the model only publishes whether it exists). Save, load, and new run follow those lists. The generic types live under `framework/`. `PropertyKeys`, `ServiceKeys`, and the boot registration live under `scripts/`. Framework must not name pollution, floors, or memes (ADR 0001).

## What stays outside

A screen computes what it shows. Palette comes from pollution. Action pips come from `actions_remaining`. The continue button's enabled state comes from `has_save`. Those results are not models.

Which screen is installed stays a Session mode enter and exit (ADR 0004). Opening registers and syncs. Closing unregisters. A closed screen receives nothing, so a change cannot open it. The screen manager stays host-created and only opens or hides a screen (ADR 0007). Player actions still arrive as UI intents. The handler writes the model.

Values that move every frame stay on the screen that owns them. The notebook canvas keeps tile positions on its bodies. It writes the map model once before the notebook closes or redraws, and once before save. Per-frame writes are a separate fix: #45.

## Migration

Every single-copy fact moves, not only a short first list. The first implementation is the framework types plus the main menu observing `pollution` and `has_save`. Later tickets move HUD money and actions, settings, the ending, the phone, conversation, inventory, and the feed. As a domain moves, delete the matching field on `MemeGameState` and retire that domain's change signal. Leave the signals whose fields have not moved. Two notifications for one fact is the copy this decision removes.
