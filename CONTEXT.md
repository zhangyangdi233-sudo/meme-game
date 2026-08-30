# Babel Meme Game

Psychological-horror Godot game about language pollution, social publishing, and tower-floor exploration.

## Architecture

**Framework**:
Reusable Godot modules under `framework/` that know nothing about this game's rules, content, or progression.
_Avoid_: addon (when we mean this repo's seam, not third-party plugins), shared, utils

**Game**:
Babel-specific state, narrative, floor generation, and the main scene wiring under `scripts/` and `scenes/`.
_Avoid_: app, core (when used loosely)

**Seam**:
The dependency boundary between Framework and Game. Framework may be called from Game; Framework must not call back into Game.
_Avoid_: boundary, layer
