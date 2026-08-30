# Outer flow is a five-state FSM

Status: accepted

**Session mode** is the current state of an outer flow: main menu, prologue, gameplay, narrative, or ending. It is not derived from overlay flags.

The reusable machine (state interface + manager) lives in Framework. Game implements five state scripts, instantiates them at boot, and injects them into the manager. Framework must not import Game paths or name those five states; it only calls the interface (enter / exit / the current state's input). Game requests transitions through the manager.

Enter/exit of a Game state installs that state's UI and world key binds. Clicks on covered UI stay with the fullscreen overlay. Rules such as `ending_unlocked` trigger transitions; gameplay code does not read those flags to decide the screen. Language picker and camera consent stay UI on main menu. In-game settings are not a flow state yet.

Supersedes ADR 0003, which derived an owner from adapter flags and left a handler-level gate for later. That table lagged new overlays and had no enter/exit to bind keys. An earlier draft of this ADR kept the whole machine in Game; the mechanism is generic and belongs in Framework, the five states do not.
