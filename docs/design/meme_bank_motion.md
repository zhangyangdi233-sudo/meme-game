# Meme Bank Motion Contract

The meme bank uses one restrained motion language for both its attached window and radial selector.

## Curve

- Design name: `easeOutQuint`
- GSAP equivalent: `power5.out`
- Godot equivalent: `Tween.TRANS_QUINT` with `Tween.EASE_OUT`

The window animates only `scale` and `modulate:a`. The radial selector animates `position`, `scale`, and `modulate:a`. Layout dimensions are never tweened.

## Timing

- Window scale: `0.28s`
- Window alpha: `0.22s`
- Ring selection: `0.34s`

Opening begins slightly reduced and translucent. Closing begins slightly enlarged and subdued, then settles into the attached tab state. A new gesture or toggle kills any unfinished tween before starting the next one, so rapid wheel, trackpad, and click input cannot queue stale motion.

## Interaction

- Wheel and trackpad pan rotate the selected meme by one step.
- Touchpad and wheel selection never spend a daily action.
- Opening, closing, and dragging the bank never spend a daily action.
- The ring remains contextual to social publishing and notebook crafting; it is absent during reality dialogue.

The runtime profiles exposed by `RadialSelectorRing.get_motion_profile()` and `_meme_bank_motion_profile()` are regression-tested. Any future motion change should update both the implementation and those contracts.
