# A basement room is data; the rule engine only reads the sentence

Status: accepted

Each basement round has one room in `content/basement_rooms.json`, read through Framework `ContentJson` by `RoomContent`. A room lists its words per language, its optional vocabulary, its rules, its escapes, its state (`brightness`, `hum`, `objects`) and its one-shot events. A planner changes a room by editing that file; `RoomContent.validate` fails a test on an authoring slip.

Judging has two steps with a fixed boundary. `RuleEngine.read_sentence` answers what the sentence says: subject, predicate and polarity, in any word order, through the engine's word tables plus the room's vocabulary. `RoomRules.judge` answers whether that is a rule here: it looks the reading up in the room, then falls back to a loose match that accepts a rule whose words all lie somewhere in the sentence. A hit is tier `rule`, a red post. Everything else stays `misread` or `noise`, a green post, and changes nothing.

**Rule keys stay `subject|predicate`.** `灯亮` and `灯不亮` are two rules of a room but one key, so the newest post decides, as it already did on the tower.

**No second copy of what the world looks like.** A red post writes the `world_rules` map, with the round it was made in. `RoomRules.world_state` derives the room from its data and the rules in force, so the save needs no field of its own, and a rule from another round cannot leak in. Leaving a round forgets its rules, because the next room starts from its own data. This is not #119 Q2-3's mechanism: there a rule stops working in the next room because its subject word is polluted (#117), and nothing records used rules. The two agree for now. The tower's rules carry no round and stay.

**The stage only displays.** The host hands the derived state to the Reality scene adapter as `room_state`, and `ChapterOneStage` turns it into lights and objects. A room can name only the objects in `RoomContent.OBJECTS`, each of which the stage builds. A new kind of object needs code; a new use of one does not.

**Words and rules in other languages.** The file keeps `zh`, `ja` and `en` fields from the start. An empty word list keeps the whole pool, and a rule already reads in every language through the engine's word tables, so a room is playable before its translation exists.

**The exit is room data too.** A room lists its `escapes`, and any one that holds delivers the round (`RoomRules.escaped`). `delivery` is this round's post plus the NPC's conversation; `rule` names one of the room's rules in force. A rule changes the room either way; it opens the exit only where the room declares it. All five rooms start on `delivery`, so #120's answer changes the data, not the code. A later way out (the NPC behind the door, the X-ray) adds a kind and the fact that decides it.

**Opening is remembered, not derived.** The room's look follows the rules in force, but the exit stays open once earned: `delivered` in the chapter progress is saved, and taking the rule back does not shut it. A player who wrote their way out is never trapped by their next post. The saved field keeps its name, so older saves load unchanged.

The tower still uses `RuleEngine.parse` with `SUPPORTED_RULES`. It is out of the demo's path (`LEVEL_ORDER`), and rewriting it would serve nothing.

Events are stored and validated here (`id`, `trigger`, then whatever their cue needs) but nothing runs them yet. #114 plays them and records that they fired. `hum` is the same: stored, not yet heard, until #114 brings the sound.
