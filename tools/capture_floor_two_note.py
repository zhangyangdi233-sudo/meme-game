"""Capture the actual floor-two note with native renderers in a hidden Window."""
from pathlib import Path
import json
import os
import subprocess
import sys

repo = Path(__file__).resolve().parents[1]
engine = repo.parent / "tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe"
output = repo / "artifacts/floor-two-note-20261019"
reports = []
for renderer, driver in [("forward_plus", "vulkan"), ("gl_compatibility", "opengl3")]:
    folder = output / renderer
    profile = folder / "profile"
    profile.mkdir(parents=True, exist_ok=True)
    env = os.environ.copy()
    env.update(APPDATA=str(profile), XDG_DATA_HOME=str(profile), FLOOR_NOTE_OUTPUT=str(folder))
    options = {}
    if os.name == "nt":
        startup = subprocess.STARTUPINFO()
        startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
        startup.wShowWindow = subprocess.SW_HIDE
        options.update(startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW)
    command = [str(engine), "--path", str(repo), "--rendering-method", renderer,
               "--rendering-driver", driver, "--script", "res://tests/capture_floor_two_note.gd",
               "--log-file", str(folder / "engine.log")]
    try:
        result = subprocess.run(command, cwd=repo, env=env, capture_output=True,
                                text=True, encoding="utf-8", errors="replace", timeout=90, **options)
        text, code = result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        text, code = "Native paper capture timed out.", -1
    (folder / "console.log").write_text(text, encoding="utf-8")
    errors = [needle for needle in ["SCRIPT ERROR", "Parse Error", "SHADER ERROR", "BUG, indexing",
                                   "Shader compilation failed", "Program crashed"] if needle in text]
    passed = code == 0 and not errors and "floor two note native capture passed" in text
    report = dict(renderer=renderer, passed=passed, exit_code=code, errors=errors)
    reports.append(report)
    print(json.dumps(report), flush=True)
(output / "native-report.json").write_text(json.dumps(reports, indent=2), encoding="utf-8")
sys.exit(0 if all(report["passed"] for report in reports) else 1)
