# Denpa Cartoon-Horror Character Direction

## Goal

Characters must remain immediately readable, compact, and cartoon-like. Horror comes from one wrong rule inside an otherwise friendly design, not from realistic anatomy, age, dirt, gore, or generic distress.

## Research Findings

1. **Contrast is the engine.** `Happy Game` deliberately twists cute imagery and unsettling content together. Its developers describe the visual style as the anchor around which interaction was designed, rather than a horror filter added afterward. [Game Developer](https://www.gamedeveloper.com/art/honing-creepiness-through-contrast-in-horror-puzzler-happy-game)
2. **The familiar surface should betray the player.** The writer of `NEEDY GIRL OVERDOSE` describes fear emerging when a loved internet space becomes hostile and a familiar heroine behaves in ways that the genre says she should not. [Netolab interview](https://nlab.itmedia.co.jp/cont/articles/3331324/2/)
3. **Cute and denpa can be one system.** The official `Yunyun Syndrome!? Rhythm Psychosis` page explicitly frames its design as psychological, cute, and denpa, with ordinary posting as the action that corrupts the world. [Alliance Arts](https://alliance-arts.co.jp/en/products/yunyun-syndrome-rhythm-psychosis/)
4. **Subjective language matters more than realism.** Nikita Kryukov describes the first `Milk` game as manipulation of word and form before conventional game structure; contemporary coverage characterizes the sequel through psychedelic, dissociated narration and variable perspective. [Creator page](https://itch.io/profile/nikita-kryukov), [PC Gamer](https://www.pcgamer.com/surreal-visual-novel-milk-inside-a-bag-of-milk-has-a-sequel-now-milk-outside-a-bag-of-milk/)
5. **Lo-fi disruption must be authored.** `Paratopic` uses abrupt cuts, face-material shifts, and audio continuity as controlled scene grammar, not random noise. Its developers explicitly avoided antagonistic presentation that could prevent progress. [Game Developer](https://www.gamedeveloper.com/design/disturbing-players-with-unsettling-camerawork-in-i-paratopic-i-/)

The local `Milk outside a bag of milk outside a bag of milk` installation was inspected at package level. It is a Ren'Py build whose authored content is stored in `game/archive.rpa`. The archive, dialogue, images, and audio are not extracted or copied.

## Reference-Image Reading

These are design inferences from the user-provided images, not claims about their original productions:

- A small, cute silhouette can remain sympathetic while a completely featureless face and low-fidelity surroundings create uncertainty.
- A mostly monochrome composition becomes tense when one signal color is reserved for choices, props, or a spatial contradiction.
- Extreme perspective and a large abstract symbol can express a character's subjective fear without redesigning the character as realistic or grotesque.
- Repeated interface choices and duplicated visual elements communicate obsession more effectively than adding detail everywhere.

## Character Rules

- Keep proportions at roughly 5.5 to 6 heads tall, with a large readable head, simple hands, and clear prop silhouettes.
- Use two flat value groups plus one accent; retain the project's green, cream, and ink palette.
- Keep linework graphic and slightly pixel-stepped. Avoid realistic skin rendering, painterly pores, mature fashion illustration, and dense cross-hatching.
- Give each character exactly one persistent contradiction and one optional animated contradiction.
- Preserve neutral or gentle poses. No lunging, screaming, gore, weapons, or monster anatomy.
- Draw NPC source portraits with no eyes, nose, or mouth. Keep them front-facing and let props carry identity; do not restore facial details through lighting, channel offsets, or later floor variants. The stitched guide doll is exempt because it uses the project owner's exact authored art.
- Let the in-engine face veil, channel offset, and pollution system provide motion. The original character cutout is never recolored, darkened, sampled through a distortion material, or baked together with the veil. A second `FaceScribbleOverlay` sprite sits in front of it, facing the camera like the character, and plays the artist's six-drawing chalk scribble (`assets/image/npc/cover/`) on twos across the face (`shaders/npc_face_cover.gdshader`); each portrait's face position lives in `scripts/world/npc_portraits.gd`.
- The VHS post-process must preserve near-black ink after chromatic sampling so displaced color channels cannot reconstruct eyes or other facial edges through the scribble.

## Character Contradictions

| Character | Persistent contradiction | Optional runtime contradiction |
| --- | --- | --- |
| Stitched cat guide | Its seams imply several repairs, but it describes every encounter as the first | One familiar word changes position between visits |
| Archive witness | Blank cards repeat around the body in an almost regular orbit | One card changes position only while the camera looks away |
| Echo tenant | The listening receiver points back toward its owner | Key tags sway while the hand and coat remain still |
| Late arrival | Both wristwatches show the same impossible minute | The loose shoelace points toward the nearest legacy phrase |

## Writing Rules

- Start with a concrete ordinary observation, then let the speaker correct one noun or spatial relation.
- Use repetition with one changed word; never repeat a whole borrowed sentence.
- Parenthetical inner speech may disagree with spoken speech, but should not diagnose or ridicule the character.
- Keep horror specific to signal, memory, language, and social interpretation. Avoid using psychiatric illness as a visual punchline.

## Originality Boundary

All new character drawings, dialogue, props, glitches, and compositions must be original. References provide only broad craft lessons: cute/horror contrast, subjective framing, limited colors, authored repetition, and interface betrayal. No source game's character, pose, line, scene, UI frame, or asset may be reproduced.
