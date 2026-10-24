# Reality scene adapter stays one Game facade

Host reaches the 3D street only through the Reality scene adapter, via interaction outcomes and look pose. Internal splits (locomotion, proximity, floor composition) may happen later, but they stay behind that facade: they are not three host-facing adapters, and the facade does not move into Framework.

Splitting internals waits until snapshot tickets that still consume this seam are done (at least Reality HUD snapshot refresh). Locomotion stays on the facade; the first later split is Floor composer versus Floor generator, not walking (ADR 0006). Pushing the facade into Framework would smuggle Babel knowledge across the Game seam (ADR 0001).

## Amended (#111): the basement CRT terminal

The basement CRT is one more interaction outcome (`terminal`) and its pushed-in view rides on the look pose (`view_position`). The host also hands the adapter two values the outcome and the pose cannot carry: the terminal's display texture with its VHS setting (`show_terminal_display`), and a camera ray to answer where it meets the CRT's glass as a UV (`terminal_screen_uv`). Both are plain values; the host still reaches neither the stage nor its mesh.

## Amended (#112): the basement rounds

Each basement round's NPC is an ordinary actor outcome, so the host starts its conversation the way it starts any other. Walking out through the round's open exit is not an outcome the host asks for: the stage raises it once as the `BASEMENT_EXIT_CROSSED` game event, as it already raises the knock, and the host's listener records it in the state; the adapter then builds the next round (or the crossroads) on its next ensure. The host still reaches neither the stage nor its doors.
