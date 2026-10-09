#!/usr/bin/env python3
"""Process-lifecycle regression tests for the hand-tracking sidecar."""

from __future__ import annotations

import importlib.util
import os
import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
TRACKER_PATH = PROJECT_DIR / "tools" / "hand_tracking" / "hand_tracker.py"
RECEIVER_PATH = PROJECT_DIR / "scripts" / "integrations" / "hand_tracking_receiver.gd"
SPEC = importlib.util.spec_from_file_location("babel_hand_tracker", TRACKER_PATH)
assert SPEC is not None and SPEC.loader is not None
TRACKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRACKER)


class SidecarLifecycleTests(unittest.TestCase):
    def test_process_check_recognizes_an_exited_process(self) -> None:
        for exit_code in (0, 259):
            with self.subTest(exit_code=exit_code):
                child = subprocess.Popen([sys.executable, "-c", f"raise SystemExit({exit_code})"])
                child.wait(timeout=5)
                try:
                    exists = TRACKER._process_exists(child.pid)
                except OSError as exc:
                    self.fail(f"checking an exited process must return false, not raise: {exc}")
                self.assertFalse(exists, "an exited process must not be reported as alive")

    def test_process_check_does_not_terminate_a_live_process(self) -> None:
        child = subprocess.Popen(
            [sys.executable, "-c", "import time; print('ready', flush=True); time.sleep(30)"],
            stdout=subprocess.PIPE,
            text=True,
        )
        try:
            self.assertEqual(child.stdout.readline().strip(), "ready")
            self.assertTrue(TRACKER._process_exists(child.pid))
            try:
                child.wait(timeout=0.15)
            except subprocess.TimeoutExpired:
                pass
            else:
                self.fail("checking process existence must not terminate the process")
        finally:
            if child.poll() is None:
                child.terminate()
            child.wait(timeout=5)
            child.stdout.close()

    def test_godot_launcher_passes_its_process_id_to_the_sidecar(self) -> None:
        receiver_source = RECEIVER_PATH.read_text(encoding="utf-8")
        self.assertIn('"--host-pid", str(OS.get_process_id())', receiver_source)

    def test_sidecar_exits_after_its_host_process_dies(self) -> None:
        host_script = """
import os
import subprocess
import sys

sidecar = subprocess.Popen(
    [sys.executable, sys.argv[1], "--simulate", "--host-pid", str(os.getpid())],
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
    start_new_session=True,
)
print(sidecar.pid, flush=True)
"""
        host = subprocess.run(
            [sys.executable, "-c", host_script, str(TRACKER_PATH)],
            check=True,
            capture_output=True,
            text=True,
            timeout=5,
        )
        sidecar_pid = int(host.stdout.strip())

        try:
            deadline = time.monotonic() + 3.0
            while time.monotonic() < deadline and TRACKER._process_exists(sidecar_pid):
                time.sleep(0.05)
            self.assertFalse(
                TRACKER._process_exists(sidecar_pid),
                "the tracker sidecar must not survive after its owning Godot process exits",
            )
        finally:
            if TRACKER._process_exists(sidecar_pid):
                os.kill(sidecar_pid, signal.SIGTERM)


if __name__ == "__main__":
    unittest.main()
