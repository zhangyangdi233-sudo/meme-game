"""Run the native CRT light-lifetime regression; headless is not equivalent.

Windows: use normal desktop permissions. The Godot test hides its Window and
renders an actual SubViewport. A supplied save is only read and copied into
the isolated profile; the user's normal AppData is never the test profile.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", type=Path, default=repo.parent / "tools/godot-4.6.3/Godot_v4.6.3-stable_win64_console.exe")
    parser.add_argument("--output", type=Path, default=repo / "artifacts/crt-renderer-lifecycle")
    parser.add_argument("--save-copy", type=Path, help="Optional first-basement save copy, opened read-only")
    parser.add_argument("--renderer", choices=["both", "forward_plus", "gl_compatibility"], default="both")
    args = parser.parse_args()
    if not args.godot.is_file():
        parser.error(f"Godot executable not found: {args.godot}")
    if args.save_copy and not args.save_copy.is_file():
        parser.error(f"Save copy not found: {args.save_copy}")
    renderers = ["forward_plus", "gl_compatibility"] if args.renderer == "both" else [args.renderer]
    reports = []
    for renderer in renderers:
        output = args.output.resolve() / renderer
        profile = output / "profile"
        profile.mkdir(parents=True, exist_ok=True)
        env = os.environ.copy()
        env.update(APPDATA=str(profile), XDG_DATA_HOME=str(profile), CRT_RENDER_OUTPUT=str(output))
        env.pop("CRT_RENDER_SAVE_COPY", None)
        if args.save_copy:
            env["CRT_RENDER_SAVE_COPY"] = str(args.save_copy.resolve())
        command = [str(args.godot.resolve()), "--path", str(repo), "--rendering-method", renderer,
                   "--rendering-driver", "vulkan" if renderer == "forward_plus" else "opengl3",
                   "--log-file", str(output / "engine.log"), "--script", "res://tests/test_chapter_crt_renderer_lifecycle.gd"]
        options = {}
        if os.name == "nt":
            startup = subprocess.STARTUPINFO()
            startup.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            startup.wShowWindow = subprocess.SW_HIDE
            options.update(startupinfo=startup, creationflags=subprocess.CREATE_NO_WINDOW)
        try:
            result = subprocess.run(command, cwd=repo, env=env, capture_output=True, text=True,
                                    encoding="utf-8", errors="replace", timeout=120, **options)
            text = result.stdout + result.stderr
            code = result.returncode
        except subprocess.TimeoutExpired as error:
            # subprocess.run terminates only the child it created on timeout.
            text = "Native renderer timed out after 120 seconds.\n"
            text += (error.stdout or b"").decode("utf-8", "replace") if isinstance(error.stdout, bytes) else (error.stdout or "")
            code = -1
        (output / "console.log").write_text(text, encoding="utf-8")
        engine_log = output / "engine.log"
        combined = text + (engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else "")
        forbidden = [needle for needle in ("BUG, indexing", "SCRIPT ERROR", "Parse Error", "SHADER ERROR",
                                          "Shader compilation failed", "shader_compile", "CrashHandlerException",
                                          "Program crashed") if needle in combined]
        passed = code == 0 and not forbidden and "CRT native renderer lifecycle passed" in combined
        report = {"renderer": renderer, "passed": passed, "exit_code": code, "errors": forbidden, "log": str(engine_log)}
        reports.append(report)
        print(json.dumps(report, ensure_ascii=False), flush=True)
    args.output.resolve().mkdir(parents=True, exist_ok=True)
    (args.output.resolve() / "report.json").write_text(json.dumps(reports, indent=2, ensure_ascii=False), encoding="utf-8")
    return 0 if all(item["passed"] for item in reports) else 1


if __name__ == "__main__":
    sys.exit(main())
