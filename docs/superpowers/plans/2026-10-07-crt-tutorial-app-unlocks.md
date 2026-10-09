# CRT tutorial and phone application unlocks

**Goal:** Make the basement a five-visit tutorial with the existing applications on the actual CRT, then unlock the same applications on the phone after visits 1, 3 and 5.

**Architecture:** Keep one shared MemeGameState. Normalize application permissions in BasementLoopDirector; retain independent hidden-ending items. A terminal session temporarily hosts existing application Control nodes in a SubViewport mapped onto the real screen mesh, with ray-to-UV input and the existing video component arbitrating screen materials. A separate persisted CRT VHS setting affects only its material.

- [x] State: introduce social/notebook/babel permissions, configurable 1/3/5 rewards, validated save migration, phone entry guards, current-round successful submission records, and tutorial practice without consuming the normal day budget. Prove stale/repeated events and prior-round submissions cannot grant new permissions.
- [x] World: preserve one original NPC identity per visit, add reachable CRT interaction and focus pose, bind the real screen mesh, and use application permissions for the far gate. Crossroads retains the gate with no NPC/task population.
- [x] Terminal: viewport content, physical screen ray/UV input, localized VHS, video/terminal/standby/power arbitration and cleanup. Verify real GUI input, screen-only material changes and restoration.
- [x] Main UI: route existing windows and pickup effects into the terminal, restore phone hosting on exit, block locked app shortcuts and callback reopening, offer a clearly labeled functional tutorial hand-in after a valid current-round submission, and retain the original key-NPC dialogue/hidden-item path.
- [x] Settings: default CRT VHS enabled, immediate toggling and independent persistence across other preference writes.
- [x] Verification: player-route terminal interaction, actual pickup/composition/submission for five rounds, application unlock persistence, ordinary controls/exit/settings, X-ray regression, and renderer screenshots. Keep X-ray evidence separate from permission-gate evidence.

No new narrative text, source Blender edits, commits or bulk deletion. The separately authorized 10-second wait + complete knock + nearby F opening remains unchanged.
