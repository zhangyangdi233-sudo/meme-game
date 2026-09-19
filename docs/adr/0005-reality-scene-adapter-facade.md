# Reality scene adapter stays one Game facade

Host reaches the 3D street only through the Reality scene adapter, via interaction outcomes and look pose. Internal splits (locomotion, proximity, floor composition) may happen later, but they stay behind that facade: they are not three host-facing adapters, and the facade does not move into Framework.

Splitting internals waits until snapshot tickets that still consume this seam are done (at least Reality HUD snapshot refresh). Locomotion stays on the facade; the first later split is Floor composer versus Floor generator, not walking (ADR 0006). Pushing the facade into Framework would smuggle Babel knowledge across the Game seam (ADR 0001).
