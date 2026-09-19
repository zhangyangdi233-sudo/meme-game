# Floor generator is Framework; Floor composer is Game

Walkable geometry and generic placement belong in a Floor generator under Framework. Who appears on a tower floor, which items exist, and which authored events run belong in a Game Floor composer that reads catalogs and snapshots. The Reality scene adapter remains the only host-facing composition root (ADR 0005).

Do not start this split while snapshot work still consumes the facade (ADR 0005). First extract in Game: peel the Floor composer off today's mixed generator. Only then consider a Framework Floor generator. Do not move the mixed class into Framework. Cubes stay the geometry. Locomotion is not part of this split. Tracker: [#18 深化 Reality：Floor composer 與 Floor generator](https://github.com/zhangyangdi233-sudo/meme-game/issues/18), blocked by #15.
