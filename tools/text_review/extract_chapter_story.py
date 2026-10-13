#!/usr/bin/env python3
"""Extract only reachable chapter-one basement narrative; never modify game sources."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTENT = "scripts/narrative/language_corruption_content.gd"
WORLD = "scripts/world/chapter_world.gd"
STATE = "scripts/meme_game_state.gd"
TOKEN = re.compile(r'\s+|\#[^\n]*|"(?:\\.|[^"\\])*"|-?\d+(?:\.\d+)?|[A-Za-z_][A-Za-z_0-9]*|.', re.S)


class Source:
    def __init__(self, relative: str):
        self.relative = relative
        self.text = (ROOT / relative).read_text(encoding="utf-8")
        self.sha256 = hashlib.sha256((ROOT / relative).read_bytes()).hexdigest()
        self.locations = {}

    def constant(self, name: str):
        match = re.search(r"^const " + re.escape(name) + r"\s*:?=\s*", self.text, re.M)
        if not match:
            raise ValueError(f"Missing {name} in {self.relative}")
        tokens = [m for m in TOKEN.finditer(self.text, match.end()) if not m.group().isspace() and not m.group().startswith("#")]
        position = 0

        def parse(path):
            nonlocal position
            token = tokens[position]
            position += 1
            value = token.group()
            if value in ("{", "["):
                result = {} if value == "{" else []
                closing = "}" if value == "{" else "]"
                while tokens[position].group() != closing:
                    if value == "{":
                        key = parse(path + ("__key__",))
                        assert tokens[position].group() == ":"
                        position += 1
                        result[key] = parse(path + (key,))
                    else:
                        result.append(parse(path + (len(result),)))
                    if tokens[position].group() == ",":
                        position += 1
                    else:
                        assert tokens[position].group() == closing
                position += 1
                return result
            if value.startswith('"'):
                result = json.loads(value)
                self.locations[(name,) + path] = self.locator(token, name, list(path))
                return result
            if value in ("true", "false", "null"):
                return {"true": True, "false": False, "null": None}[value]
            if re.fullmatch(r"-?\d+(?:\.\d+)?", value):
                return float(value) if "." in value else int(value)
            raise ValueError(f"Unsupported literal {value!r} in {name}")

        return parse(())

    def locator(self, token, constant=None, data_path=None):
        prefix = self.text[:token.start()]
        result = {
            "kind": "gdscript_string_literal",
            "line": prefix.count("\n") + 1,
            "column": token.start() - prefix.rfind("\n"),
            "char_start": token.start(),
            "char_end": token.end(),
            "offset_unit": "unicode_codepoint",
            "raw_literal": token.group(),
            "source_sha256": self.sha256,
        }
        if constant is not None:
            result.update(constant=constant, data_path=data_path)
        return result

    def function_literal(self, function, literal):
        match = re.search(r"^func " + re.escape(function) + r"\(", self.text, re.M)
        assert match
        end_match = re.search(r"^func ", self.text[match.end():], re.M)
        end = match.end() + end_match.start() if end_match else len(self.text)
        candidates = [m for m in TOKEN.finditer(self.text, match.start(), end) if m.group().startswith('"') and json.loads(m.group()) == literal]
        assert len(candidates) == 1, (function, literal, len(candidates))
        location = self.locator(candidates[0])
        location["function"] = function
        return location


def build():
    content, world, state = Source(CONTENT), Source(WORLD), Source(STATE)
    first_turns = content.constant("REALITY_DIALOGUES_BY_FLOOR")[1]
    followups = content.constant("REALITY_FOLLOWUPS_BY_NPC_INDEX")
    guard = content.constant("KEY_NPC_DIALOGUES_BY_FLOOR")[1]
    names = world.constant("BASEMENT_NPC_NAMES")
    hidden = state.constant("PREREQUISITE_ITEMS")[1]
    sections = []

    def entry(section, entry_id, source, constant, path, text, context):
        assert isinstance(text, str) and text
        location = source.locations[(constant,) + tuple(path)]
        assert json.loads(location["raw_literal"]) == text
        section["entries"].append({"id": entry_id, "zh": text, "context": context,
                                   "source_file": source.relative, "source_locator": location})

    def turn(section, prefix, constant, path, data, number, role):
        entry(section, prefix + ".npc", content, constant, path + ["line"], data["line"], f"{role}｜第{number}轮对话｜NPC说话；所有选项共用这句题面。")
        entry(section, prefix + ".result", content, constant, path + ["result"], data["result"], f"{role}｜第{number}轮对话｜说完玩家句子后显示的动作/结果旁白；并非下一句玩家选项。")
        for index, choice in enumerate(data["choices"]):
            choice_prefix = prefix + ".choice." + choice["id"]
            condition = ("；这是隐藏线索正确选项" if choice.get("correct") else "；这是隐藏线索错误选项") if "correct" in choice else "；当前代码不按该选项单独分叉题面"
            for field, title in [("summary", "选项按钮短标题"), ("sentence", "玩家选择后逐字说出的完整句子／悬停预览")]:
                entry(section, choice_prefix + "." + field, content, constant, path + ["choices", index, field], choice[field], f"{role}｜第{number}轮对话｜选项{index + 1} {title}{condition}。")

    for round_index, archetype in enumerate(["lamp_keeper", "latecomer", "echo_tenant", "copyist", "believer"]):
        role = f"地下室第{round_index + 1}轮·{names[round_index]}"
        prefix = "ch1.story.basement." + archetype
        section = {"id": prefix, "title": role, "entries": []}
        sections.append(section)
        entry(section, prefix + ".name", world, "BASEMENT_NPC_NAMES", [round_index], names[round_index], role + "｜角色显示名；实际由当前地下室世界创建，不使用未出场人物。")
        if round_index == 0:
            for index, data in enumerate(guard["turns"]):
                turn(section, prefix + f".turn{index + 1:02}", "KEY_NPC_DIALOGUES_BY_FLOOR", [1, "turns", index], data, index + 1, role)
            for field, context in [("success_line", "两轮都选择正确答案后，接在第2轮结果之后，并追加隐藏物位置提示"), ("failure_line", "任一轮选错后，接在第2轮结果之后；不会揭示隐藏物位置")]:
                entry(section, prefix + "." + field, content, "KEY_NPC_DIALOGUES_BY_FLOOR", [1, field], guard[field], role + "｜" + context + "。")
        else:
            source_index = round_index - 1
            turn(section, prefix + ".turn01", "REALITY_DIALOGUES_BY_FLOOR", [1, source_index], first_turns[source_index], 1, role)
            for index, data in enumerate(followups[source_index]["turns"]):
                turn(section, prefix + f".turn{index + 2:02}", "REALITY_FOLLOWUPS_BY_NPC_INDEX", [source_index, "turns", index], data, index + 2, role)
            entry(section, prefix + ".interrupt", content, "REALITY_FOLLOWUPS_BY_NPC_INDEX", [source_index, "interrupt"], followups[source_index]["interrupt"], role + "｜理解判定失败时追加在本轮结果之后；此次交谈立即中止，不能继续剩余轮次。")

    section = {"id": "ch1.story.hidden_clue", "title": "地下室隐藏线索：旧名牌", "entries": []}
    sections.append(section)
    for field, context in [("label", "已接入隐藏物数据的名称；任务面板采用通用拾取按钮，不在该按钮上直接印出此名称"), ("location_hint", "护灯人两轮答对后实际显示的位置提示；当前仍保留街道/路灯措辞，按源码原文提取，不替作者修写")]:
        entry(section, "ch1.story.hidden_clue." + field, state, "PREREQUISITE_ITEMS", [1, field], hidden[field], context + "。")
    text = "你收起了这一层不该留下的东西。"
    section["entries"].append({"id": "ch1.story.hidden_clue.collected", "zh": text,
                               "context": "收取已显形旧名牌后写入事件日志的故事反馈。当前通过NPC任务面板拾取。",
                               "source_file": STATE, "source_locator": state.function_literal("collect_prerequisite_item", text)})
    sections.append({"id": "ch1.story.crossroads", "title": "十字路口（当前没有独立对白）", "entries": []})
    notes = [
        "本提取只读取当前工程 本机游玩/第一章-20261009，不读取根目录旧四层工程；不重复已确认的开场30条旁白。",
        "实际调用：chapter_world.gd::_build_current_npc → source_actor_id/source_actor_type → babel_meme_game.gd::_start_chapter_source_dialogue → meme_game_state.gd::_reality_dialogue_for_actor。五轮依次映射 key_npc_1_keynpc、npc_1_npc0、npc_1_npc1、npc_1_npc2、npc_1_npc3，地下室期间 tower_floor=1。",
        "护灯人共2轮，每轮3个选项；其余4人各3轮、每轮3个选项。选项摘要和玩家完整句分别可编辑。普通NPC各选项当前共用本轮结果与后续题面，理解判定失败追加对应interrupt并结束交谈。",
        "未提取旧帖目击者、2/3层对白、医生/布偶场景、subtext创作注释、未调用的人格片段、docs创作稿。没有凭名字相似而把这些内容当作当前地下室剧情。",
        "十字路口 chapter_world.gd::_build_crossroads 调用 Generator.rebuild(1,...,false) 明确不生成人物和旧拾取物；无当前独立NPC对白。远门操作文字归共用界面稿，进入远门后 tower_floor=2 已超出本稿范围。",
        "隐藏物名牌数据及地点实际沿用旧设定；当前收取入口是地下室NPC任务面板。原始位置提示虽写主路和路灯仍会显示，已原样保留供作者改写。",
        "source_locator 使用原文件SHA256、常量名/字段路径或函数名、Unicode字符起止位置、原始字符串字面量，供回填前核验。回填须先验证原文；不要全局替换同文字符串。",
    ]
    ids = [e["id"] for s in sections for e in s["entries"]]
    assert len(ids) == len(set(ids)) == 126
    return {"sections": sections, "scope_notes": notes}


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("/private/tmp/aphasia-current-chapter-extract-20261013/story.json"))
    args = parser.parse_args()
    result = build()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"output": str(args.output), "entries": sum(len(s["entries"]) for s in result["sections"]), "sections": [{"id": s["id"], "entries": len(s["entries"])} for s in result["sections"]]}, ensure_ascii=False))
