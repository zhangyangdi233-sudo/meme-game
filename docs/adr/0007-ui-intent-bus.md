# Every UI tells the host through one event bus

Status: accepted

Any UI that reports a player action uses the game event bus. The host listens in one place. The main menu is the first caller (`start_game`, `continue_game`, `exit_game`, `language_picker`). Every other UI surface moves onto that same bus: fixed screens and controls whose count is known only at runtime.

The event carries the answer when the action has one: locale, ending choice, post, author, token, drag payload, volume, allow or skip, and the same kind of value. Today's bus only carries a name; the follow-up has to carry the answer with the event.

Buttons that only hide or fold their own window (language "back", quit "return", doll-guide collapse) are UI too. They emit on this bus instead of a private signal or a direct call. Day transition, flashback, and action spend have no player control; when one is added, it uses this bus.

**Already on the bus:** the main menu.

**Still on private signals or callbacks** (this decision does not edit them):

- Prologue finished
- Ending language choice, and restart
- Language choice
- Quit confirm
- Camera consent allow / skip, and the chosen camera source
- Phone-camera retry, continue, and disable
- Settings actions, history open, and whether settings is open
- HUD settings
- Phone app icons and window close
- Social feed, including cards, likes, follows, and the composer
- Reality conversation choices
- Reality language composer
- Notebook craft, fusion, and canvas tiles

Opening and closing via the screen manager (create once, hide, reuse) stays on the main menu until a later ticket. This decision is only the interface UI uses to notify the host. Tracker: #43.
