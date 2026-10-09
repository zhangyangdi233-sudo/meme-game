"""Run the October basement regressions with isolated saves and bounded processes."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import time

TESTS = [
    'test_revision_progression', 'test_carpet_footsteps', 'test_basement_atmosphere',
    'test_basement_wall_wear', 'test_chapter_exit_preview',
    'test_basement_loop_director', 'test_chapter_app_permissions',
    'test_word_physics_canvas', 'test_notebook_canvas_reload',
    'test_ui_revision_regressions', 'test_localization', 'test_social_feed_layout',
    'test_ui_font_theme', 'test_mouse_look_input', 'test_settings_exit_safety',
    'test_chapter_camera_revision', 'test_chapter_door_transition',
    'test_chapter_world', 'test_opening_door_flow',
    'test_chapter_terminal', 'test_chapter_terminal_preferences',
    'test_chapter_terminal_session', 'test_chapter_terminal_flow',
    'test_chapter_tunnel_flow', 'test_chapter_xray_layers', 'test_chapter_xray_view',
    'test_chapter_crossroads', 'test_chapter_tutorial_world',
    'test_chapter_asset_binding', 'test_chapter_components',
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default='godot')
    parser.add_argument('--tests', nargs='*', default=TESTS)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    output = root / 'artifacts' / 'revision-final'
    output.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    for name in ('APPDATA', 'XDG_DATA_HOME'):
        env[name] = str(output / 'isolated-profile')
    (output / 'isolated-profile').mkdir(exist_ok=True)
    rows = []
    for test in args.tests:
        started = time.monotonic()
        command = [args.godot, '--headless', '--path', str(root),
                   '--log-file', str(output / (test + '.engine.log')),
                   '--script', 'res://tests/' + test + '.gd']
        try:
            run = subprocess.run(command, cwd=root, env=env, capture_output=True,
                                 text=True, encoding='utf-8', errors='replace', timeout=120)
            code, text = run.returncode, run.stdout + run.stderr
        except subprocess.TimeoutExpired as exc:
            code, text = -1, 'TIMEOUT after 120 seconds\n' + str(exc.stdout or '')
        (output / (test + '.log')).write_text(text, encoding='utf-8')
        script_error = 'SCRIPT ERROR:' in text or 'Parse Error:' in text
        success_message = 'passed' in text.lower() or ', 0 failures' in text.lower()
        passed = code == 0 and not script_error and success_message
        rows.append({'test': test, 'passed': passed, 'exit_code': code,
                     'seconds': round(time.monotonic() - started, 2),
                     'exit_cleanup_diagnostic': 'leaked' in text or 'RID allocations' in text,
                     'result_lines': [line for line in text.splitlines()
                                      if 'passed' in line.lower() or 'fail' in line.lower()],
                     'log': 'artifacts/revision-final/' + test + '.log'})
        print(('PASS' if passed else 'FAIL') + ' ' + test, flush=True)
    report = {'engine': args.godot, 'save_profile': 'artifacts/revision-final/isolated-profile',
              'tests': rows, 'passed': sum(row['passed'] for row in rows), 'total': len(rows)}
    (output / 'results.json').write_text(json.dumps(report, indent=2, ensure_ascii=False), encoding='utf-8')
    return 0 if report['passed'] == report['total'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
