#!/usr/bin/env python3
"""Extract reachable chapter-one shared Chinese copy without editing game files."""
import ast
import argparse
import hashlib
import json
import re
from pathlib import Path

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[2])
parser.add_argument('--output', type=Path, default=Path('/private/tmp/aphasia-current-chapter-extract-20261013/shared.json'))
args = parser.parse_args()
ROOT = args.project.resolve()
OUT = args.output.resolve()
HOST = 'scripts/babel_meme_game.gd'
HAN = re.compile(r'[\u4e00-\u9fff]')
STR = re.compile(r'"(?:\\.|[^"\\])*"')
sections = []


def section(sid, title):
    s = {'id': sid, 'title': title, 'entries': []}
    sections.append(s)
    return s


def add(s, eid, zh, context, file, locator):
    s['entries'].append({'id': eid, 'zh': zh, 'context': context,
                         'source_file': file, 'source_locator': locator,
                         'source_literal': json.dumps(zh, ensure_ascii=False)})


def constant(file, name):
    text = (ROOT / file).read_text()
    m = re.search(r'^const ' + re.escape(name) + r'\s*(?::[^=\n]+)?\s*:?=\s*', text, re.M)
    start = m.end()
    first = text[start]
    stack, quoted, escaped = [], False, False
    for end in range(start, len(text)):
        c = text[end]
        if quoted:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == '"': quoted = False
        elif c == '"': quoted = True
        elif c in '[{(': stack.append(c)
        elif c in ']})':
            stack.pop()
            if not stack: break
    raw = text[start:end + 1]
    value = ast.literal_eval(raw)
    return value, text.count('\n', 0, start) + 1, raw


def collect_functions(s, file, funcs, context, exclude=(), allow=None):
    current = ''
    existing = {}
    for entry in s['entries']:
        if entry['source_file'] == file: existing[entry['zh']] = entry
    for n, line in enumerate((ROOT / file).read_text().splitlines(), 1):
        match = re.match(r'(?:static )?func (\w+)', line)
        if match: current = match[1]
        if current not in funcs or line.lstrip().startswith('#'): continue
        for ordinal, match in enumerate(STR.finditer(line), 1):
            zh = ast.literal_eval(match.group())
            if not HAN.search(zh) or zh in exclude or (allow is not None and zh not in allow): continue
            locator = f'func {current}; line {n}; literal {ordinal}; {line.strip()}'
            if zh in existing:
                existing[zh]['source_locator'] += '\n' + locator
                continue
            lhs = re.search(r'(?:var\s+)?([\w.]+)\s*(?::=|=)', line)
            target = lhs.group(1).replace('.', '_') if lhs else 'copy'
            digest = hashlib.sha1(zh.encode()).hexdigest()[:7]
            eid = f'{s["id"]}.{current.lstrip("_")}.{target}.{digest}'
            add(s, eid, zh, context, file, locator)
            existing[zh] = s['entries'][-1]


shared = '第一章 CRT 与解锁后的手机实际复用；此源文案也被其他章节共用，回填时会同时影响它们。'
world = section('c1.world', '第一章｜门、灯开关与 CRT 交付')
collect_functions(world, HOST, {'_show_chapter_task'}, '第一章地下室每轮 NPC 的操作面板；开发标识也是当前实际显示文字。')
collect_functions(world, HOST, {'_render_world_prompt'}, '第一章开场门的 F 键提示；不包含已单独整理的开场 30 句。', allow={'打开门'})
collect_functions(world, 'scripts/world/chapter_world.gd', {'_build_basement'}, '第一章地下室 CRT 的 F 键目标名称。', allow={'CRT 教学端（开发）'})
collect_functions(world, 'scripts/world/basement_atmosphere.gd', {'_build_light_switch'}, '第一章地下室灯开关的 F 键目标名称。')
# The function name is deliberately discovered to survive minor source refactors.
for n, line in enumerate((ROOT / 'scripts/world/basement_atmosphere.gd').read_text().splitlines(), 1):
    if 'set_meta("display_name", "灯开关")' in line and not any(e['zh'] == '灯开关' for e in world['entries']):
        add(world, 'c1.world.light_switch.name', '灯开关', '第一章地下室灯开关的 F 键目标名称。', 'scripts/world/basement_atmosphere.gd', f'line {n}; {line.strip()}')
collect_functions(world, 'scripts/ui/chapter_terminal_session.gd', {'_build_shell'}, '第一章 CRT 固定界面；当前开发字样原样保留。')
labels, _, _ = constant('scripts/ui/chapter_terminal_session.gd', 'APP_LABELS')
for key, value in labels.items():
    add(world, f'c1.crt.app.{key}', value, '第一章 CRT 应用切换按钮。', 'scripts/ui/chapter_terminal_session.gd', f'const APP_LABELS[{key!r}]')

cards, base, raw = constant(HOST, 'SOCIAL_POST_CARDS')
seeds, seed_base, seed_raw = constant('scripts/narrative/pickup_char_pool.gd', 'POST_SEEDS')
for card in cards:
    cid = card['id']
    s = section('shared.post.' + cid, '信号瀑布｜' + card['caption'])
    for field, label in [('caption', '瀑布流标题'), ('handle', '发帖账号'), ('text', '帖子正文（污染前原文）')]:
        add(s, f'shared.post.{cid}.{field}', card[field], label + '。' + shared,
            HOST, f'const SOCIAL_POST_CARDS[id={cid!r}].{field}')
    seed = seeds[cid]
    add(s, f'shared.post.{cid}.pickup_line', seed['line']['zh'], '帖子详情的拾字句；可拾字：' + '、'.join(seed['units']['zh']) + '。' + shared,
        'scripts/narrative/pickup_char_pool.gd', f'const POST_SEEDS[{cid!r}].line.zh')
    for i, comment in enumerate(seed['comments']):
        for field, label in [('handle', '评论账号'), ('text', '评论正文')]:
            add(s, f'shared.post.{cid}.comment.{i+1}.{field}', comment[field]['zh'],
                f'{label}；显示时间 {comment["time"]}；本条可拾字：' + ('、'.join(comment['units']['zh']) or '无') + '。' + shared,
                'scripts/narrative/pickup_char_pool.gd', f'const POST_SEEDS[{cid!r}].comments[{i}].{field}.zh')

ui = section('shared.phone_ui', '共享｜信号瀑布、手机与笔记本界面')
functions = {'_render_app', '_render_social_app', '_render_social_home_page', '_render_social_detail_page',
             '_render_social_publish_page', '_render_publish_sentence_area', '_render_social_profile_page',
             '_render_social_bottom_nav', '_render_notebook_app', '_render_sentence_composer'}
collect_functions(ui, HOST, functions, shared,
                  exclude={'无法定位', '设备保持无信号。附近内容无法取得位置。', '今天不能再投稿'})
collect_functions(ui, HOST, {'_build_ui'}, '第一章解锁后可见的手机主页；' + shared,
                  allow={'无信号', '选择一个窗口', '帖\n信号瀑布', '本\n语言工坊', '每个 App 会在手机旁打开独立窗口。', '社交媒体 App', '笔记本 App'})
collect_functions(ui, HOST, {'_update_visibility'}, '第一章手机入口及锁定状态；' + shared,
                  allow={'放下手机', '\n未解锁'})
channels, _, _ = constant(HOST, 'SOCIAL_CHANNELS')
for channel in channels:
    add(ui, 'shared.phone.channel.' + channel['id'], channel['label'], shared, HOST, f'const SOCIAL_CHANNELS[id={channel["id"]!r}].label')
for name in ['REATTRIBUTION_TEMPLATES', 'ANON_HANDLES']:
    data, _, _ = constant('scripts/narrative/echo_quote_content.gd', name)
    add(ui, 'shared.echo.' + name.lower(), data['zh'], '玩家最新投稿自动回流为评论；高污染时使用归因反转模板，%s 保留为玩家句子。' + shared,
        'scripts/narrative/echo_quote_content.gd', f'const {name}.zh')
collect_functions(ui, 'scripts/ui/draggable_button.gd', {'set_drag_payload'},
    '发布句槽字块继承此拖动按钮；悬停提示中的 %s 为当前字块。' + shared)
collect_functions(ui, HOST, {'_corrupt'},
    '帖子正文的动态污染替换词；同一正文可能按污染等级替换为这些词或方框/省略号。' + shared,
    allow={'哈吉米', '沉默'})

feedback = section('shared.feedback', '共享｜拾字、投稿和窗口操作反馈')
collect_functions(feedback, HOST, {'set_view_state', '_on_social_follow_pressed', '_on_social_like_pressed',
    '_close_app_window', '_open_phone_launcher', '_close_social_detail_window', '_on_app_pressed',
    '_on_canvas_tile_dropped_outside', '_on_composer_bank_tapped', '_handle_composer_drop',
    '_on_composer_submit_pressed', '_on_pickup_unit_meta'},
    '写入 log_text；手机打开时 DeskLog 显示，CRT 中同一操作会更新该状态。' + shared,
    exclude={'今天没有行动了。明天第一次拾字会重新消耗行动。', '第三层的门开了。', '出口开始存在。'})
collect_functions(feedback, HOST, {'_on_confirm_dialogue_pressed'},
    '当前发布页仍生成“确认发布”按钮，连接旧完整梗接口；第一章没有完整梗时点击会显示此提示。保留实际可达文案，不代表推荐保留旧机制。',
    allow={'发布空格里还没有完整梗。'})

dialogue_ui = section('shared.dialogue_ui', '共享｜对话操作与输入提示')
collect_functions(dialogue_ui, HOST, {'_render_reality'}, '地下室通过“交谈”打开原对话 UI；具体台词和选项另在 NPC 文稿。' + shared,
                  exclude={'%s：%s\n你说：%s\n理解度：%d%%', '回应'})

menu = section('shared.menu', '共享｜主菜单、语言与退出')
collect_functions(menu, HOST, {'_build_main_menu', '_build_language_selection_overlay', '_build_exit_confirmation_overlay'}, '全游戏共用的当前主菜单、语言选择或退出确认。')
add(menu, 'shared.locale.zh_name', '中文', '语言按钮的中文语言名。', 'scripts/localization/game_locale.gd', 'func native_language_name; default return "中文"')
add(menu, 'shared.locale.floor1', '第一层', '第一章手机帖子详情旁的层数标记；其他层数未收录。', 'scripts/localization/game_locale.gd', 'const CHINESE_LEVEL_NAMES[0]')

settings = section('shared.settings', '共享｜设置与保存')
collect_functions(settings, HOST, {'_build_settings_window', '_on_manual_save_pressed'}, '全游戏共用设置；第一章可用 Esc/F10 打开。')
collect_functions(settings, HOST, {'_menu_display_label'}, '设置中的保存、设置标题和音量标签会随污染变化；全游戏共用。',
                  allow={'保存', '设置', '音量', '留住这一段', '调整记录方式', '外面的声音', '留住这■■', '调整你能接受的部分', '它离你有多近'})

camera = section('shared.camera', '共享｜摄像头授权与连接状态')
collect_functions(camera, HOST, {'_build_camera_consent_overlay', '_populate_camera_source_option', '_refresh_camera_source_option_labels',
    '_set_camera_enabled', '_build_phone_camera_connection_overlay', '_refresh_phone_camera_connection_ui'},
    '当前嵌套工程启动时仍进行摄像头授权；与根目录新版独立体验实现不同。全游戏共用。')
collect_functions(camera, HOST, {'_on_hand_tracking_frame'}, '摄像头状态标签；全游戏共用。', allow={'已锁定指尖窗口', '等待双手四指框选'})
collect_functions(camera, 'scripts/integrations/hand_tracking_receiver.gd', {'start', 'stop', 'poll', 'ingest_packet', '_launch_sidecar'},
    '实际摄像头服务返回的状态或故障提示；全游戏共用。', exclude={'模拟关键点（非摄像头）'})

vocab = section('shared.pickup_vocabulary', '共享｜拾字字池与规则显示')
pool, _, _ = constant('scripts/narrative/pickup_char_pool.gd', 'UNIT_POOLS')
for i, unit in enumerate(pool['zh']):
    add(vocab, f'shared.pickup_pool.zh.{i+1:02d}', unit, '中文可拾取单位；修改必须同步帖子埋字、评论和合词词典，不能只改界面显示。跨章节共用。',
        'scripts/narrative/pickup_char_pool.gd', f'const UNIT_POOLS.zh[{i}]')
rules, _, _ = constant('scripts/narrative/rule_engine.gd', 'SUPPORTED_RULES')
for key, val in rules.items():
    add(vocab, 'shared.rule.' + key.replace('|', '.'), val['zh'], '第一章自由投稿可形成并在笔记本“现行规则”里显示的规则文本；包括出口规则，不等于第四层剧情。跨章节共用。',
        'scripts/narrative/rule_engine.gd', f'const SUPPORTED_RULES[{key!r}].zh')
collect_functions(vocab, 'scripts/narrative/rule_engine.gd', {'rule_display_text'}, '已投稿否定句的规则前缀；跨章节共用。', allow={'已被否定：'})

notes = [
    '范围：本机游玩/第一章-20261009 当前地下室五轮、CRT、解锁手机和十字路口；不使用根目录旧四层内容。',
    '主菜单“新游戏”绑定 start_chapter1_game；CRT 通过 ChapterTerminalSession 将现有 social/notebook/detail 控件实际放入屏幕。',
    '全部 12 个 SOCIAL_POST_CARDS 在发现列表可浏览；详情实际展示 card.text、PickupCharPool.POST_SEEDS 的中文埋字句与匿名评论。旧 tokens 的 phone_surface/doctor_surface/doll_surface 未在当前拾字详情显示，未收录。',
    '章节原30句开场、5名NPC实际剧情及第一层隐藏名牌线索由独立文稿负责，本文件不重复。',
    '预算已下架：can_spend_action 始终 true；不收资金、今日行动、今天不能再投稿、no-actions 警告、退役 HUD/梗环/旧融合/旧开场/旧结局。',
    '社交频道 only discover/following；nearby 与 tower_base 无当前入口，未收对应空态。',
    '设置没有 autoplay/history 控件，且 _build_ui 不再调用 _build_history_window；仅保留实际保存/设置/音量污染变体。',
    '十字路口只复用第一层几何并禁用旧 NPC；门显示名当前原文为 ExitDoor 和 TowerGate（英文，无中文译文），中文请求正文未将其伪写为新中文。开场门显示为“打开门”。',
    '图片/视频资产里烘焙的文字不属于可回填字符串；本次不进行 OCR。',
    '字符串保留半角逗号、换行和 %s/%d 等占位符；重复 UI 字面量在同一分组内合并并列出全部精确回填语句。',
    '投稿回流和污染画面是动态生成文本；收录生成模板/原始正文，不穷举玩家输入。',
]
source_hashes = {}
errors = []
seen_ids = set()
for s in sections:
    for entry in s['entries']:
        source = ROOT / entry['source_file']
        raw_bytes = source.read_bytes()
        raw_text = raw_bytes.decode('utf-8')
        source_hashes[entry['source_file']] = hashlib.sha256(raw_bytes).hexdigest()
        if entry['source_literal'] not in raw_text:
            errors.append('Missing literal: ' + entry['id'])
        if entry['id'] in seen_ids:
            errors.append('Duplicate id: ' + entry['id'])
        seen_ids.add(entry['id'])
        entry['source_literal_validated'] = entry['source_literal'] in raw_text
if errors:
    raise ValueError('\n'.join(errors))
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps({'sections': sections, 'scope_notes': notes,
    'source_sha256': source_hashes,
    'validation': {'unique_ids': True, 'all_source_literals_present': True,
                   'entry_count': len(seen_ids), 'source_file_count': len(source_hashes)}}, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({'output': str(OUT), 'sections': len(sections), 'entries': len(seen_ids), 'validated': True}, ensure_ascii=False))
