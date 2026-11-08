# Reality scene adapter stays one Game facade

Host reaches the 3D street only through the Reality scene adapter, via interaction outcomes and look pose. Internal splits (locomotion, proximity, floor composition) may happen later, but they stay behind that facade: they are not three host-facing adapters, and the facade does not move into Framework.

Splitting internals waits until snapshot tickets that still consume this seam are done (at least Reality HUD snapshot refresh). Locomotion stays on the facade; the first later split is Floor composer versus Floor generator, not walking (ADR 0006). Pushing the facade into Framework would smuggle Babel knowledge across the Game seam (ADR 0001).

## Amended (#111): the basement CRT terminal

The basement CRT is one more interaction outcome (`terminal`) and its pushed-in view rides on the look pose (`view_position`). The host also hands the adapter two values the outcome and the pose cannot carry: the terminal's display texture with its VHS setting (`show_terminal_display`), and a camera ray to answer where it meets the CRT's glass as a UV (`terminal_screen_uv`). Both are plain values; the host still reaches neither the stage nor its mesh.

## Amended (#112): the basement rounds

Each basement round's NPC is an ordinary actor outcome, so the host starts its conversation the way it starts any other. Walking out through the round's open exit is not an outcome the host asks for: the stage raises it once as the `BASEMENT_EXIT_CROSSED` game event, as it already raises the knock, and the host's listener records it in the state; the adapter then builds the next round (or, since #121, the white door passage) on its next ensure. The host still reaches neither the stage nor its doors.

## Amended (#121): the white door passage

The passage's door is not an outcome the host asks for either: the stage raises walking into its light once as the `PASSAGE_DOOR_ENTERED` game event, and the host then asks for `enter_passage`, which reports the walk in as the same `door` outcome the white door uses. The demo's end stands on the passage's stage behind its screen, so it builds no tower street.

## Amended (#113): the phone on the basement's table

The phone lying on the basement's table is one more interaction outcome (`phone`, action `pick_up_phone`). The host tells the adapter whether the phone is owned through its deps (`phone_owned`), so a rebuilt or loaded round lays no second phone; picking it up is an `apply_interaction` that takes it off the table. The host still reaches neither the stage nor its table.

## Amended (#127): what the X-ray shows

While the X-ray looks (X held, or the hands' frame), the host asks the adapter which of the round's X-ray objects stand in reach (`exit_objects_in_reach`, names in, names out) and hands them to the state; the object the state then opens is reported as the ordinary `exit` outcome. It is a plain value like the CRT's UV; the host still reaches neither the stage nor the clock.
