"""Run opt-in native mouse tests in independent short-lived Windows windows."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', default=os.environ.get('GODOT_BINARY') or shutil.which('godot'))
    parser.add_argument('--output', type=Path, default=root / 'artifacts/mouse-capture-window-20261016')
    parser.add_argument('--timeout', type=float, default=90)
    args = parser.parse_args()
    if sys.platform != 'win32':
        parser.error('this native regression requires Windows; headless cannot verify OS capture')
    if not args.godot:
        parser.error('provide --godot <Godot executable>, GODOT_BINARY, or godot on PATH')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    profile = output / 'isolated-profile'
    profile.mkdir(exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(profile), XDG_DATA_HOME=str(profile),
               APHASIA_MOUSE_PROBE_PYTHON=sys.executable,
               APHASIA_MOUSE_CAPTURE_OUTPUT=str(output))
    command = [args.godot, '--path', str(root), '--rendering-method', 'gl_compatibility',
               '--audio-driver', 'Dummy', '--max-fps', '60', '--log-file', str(output / 'engine.log'),
               '--script', 'res://tests/test_mouse_capture_window.gd']
    started = time.monotonic()
    try:
        run = subprocess.run(command, cwd=root, env=env, capture_output=True, text=True,
                             encoding='utf8', errors='replace', timeout=args.timeout,
                             creationflags=subprocess.CREATE_NO_WINDOW)
        code, log = run.returncode, run.stdout + run.stderr
    except subprocess.TimeoutExpired as error:
        code = -1
        chunks = [error.stdout or '', error.stderr or '']
        log = ''.join(x.decode('utf8', errors='replace') if isinstance(x, bytes) else x for x in chunks)
        log += f'\nNative test exceeded {args.timeout}s and its process was terminated.\n'
    (output / 'test.log').write_text(log, encoding='utf8')
    result = {'passed': code == 0 and 'native mouse capture passed' in log
              and 'SCRIPT ERROR:' not in log and 'Parse Error:' not in log,
              'exit_code': code, 'seconds': round(time.monotonic() - started, 2)}
    (output / 'results.json').write_text(json.dumps(result, indent=2), encoding='utf8')
    print(json.dumps(result), flush=True)
    print(log[-10000:])
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
