# A basement room is data; the rule engine only reads the sentence

Status: accepted

Each basement round has one room in `content/basement_rooms.json`, read through Framework `ContentJson` by `RoomContent`. A room lists its words per language, its optional vocabulary, its rules, its state (`brightness`, `hum`, `objects`) and its one-shot events. A planner changes a room by editing that file; `RoomContent.validate` fails a test on an authoring slip.

Judging has two steps with a fixed boundary. `RuleEngine.read_sentence` answers what the sentence says: subject, predicate and polarity, in any word order, through the engine's word tables plus the room's vocabulary. `RoomRules.judge` answers whether that is a rule here: it looks the reading up in the room, then falls back to a loose match that accepts a rule whose words all lie somewhere in the sentence. A hit is tier `rule`, a red post. Everything else stays `misread` or `noise`, a green post, and changes nothing.

**Rule keys stay `subject|predicate`.** `灯亮` and `灯不亮` are two rules of a room but one key, so the newest post decides, as it already did on the tower.

**No second copy of what the world looks like.** A red post writes the `world_rules` map, with the round it was made in. `RoomRules.world_state` derives the room from its data and the rules in force, so the save needs no field of its own, and a rule from another round cannot leak in. Leaving a round forgets its rules (#119 Q2-3: a rule holds in its own room). The tower's rules carry no round and stay.

**The stage only displays.** The host hands the derived state to the Reality scene adapter as `room_state`, and `ChapterOneStage` turns it into lights and objects. A room can name only the objects in `RoomContent.OBJECTS`, each of which the stage builds. A new kind of object needs code; a new use of one does not.

**Words and rules in other languages.** The file keeps `zh`, `ja` and `en` fields from the start. An empty word list keeps the whole pool, and a rule already reads in every language through the engine's word tables, so a room is playable before its translation exists.

**The exit is not part of this.** Rules change the room and never open the exit. #124 moves the exit conditions into room data.

The tower still uses `RuleEngine.parse` with `SUPPORTED_RULES`. It is out of the demo's path (`LEVEL_ORDER`), and rewriting it would serve nothing.

Events are stored and validated here (`id`, `trigger`, then whatever their cue needs) but nothing runs them yet. #114 plays them and records that they fired. `hum` is the same: stored, not yet heard, until #114 brings the sound.
