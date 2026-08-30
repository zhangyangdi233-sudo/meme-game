#!/usr/bin/env python3
"""Process-lifecycle regression tests for the hand-tracking sidecar."""

from __future__ import annotations

import os
import signal
import subprocess
import sys
import time
import unittest
from pathlib import Path


PROJECT_DIR = Path(__file__).resolve().parents[1]
TRACKER_PATH = PROJECT_DIR / "framework" / "integrations" / "hand_tracking" / "hand_tracker.py"
RECEIVER_PATH = PROJECT_DIR / "framework" / "integrations" / "hand_tracking_receiver.gd"


def _process_exists(pid: int) -> bool:
    if pid <= 0:
        return False
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes

        process_query_limited = 0x1000
        handle = ctypes.windll.kernel32.OpenProcess(process_query_limited, False, pid)
        if not handle:
            return False
        exit_code = wintypes.DWORD()
        still_active = 259
        exists = True
        if ctypes.windll.kernel32.GetExitCodeProcess(handle, ctypes.byref(exit_code)):
            exists = exit_code.value == still_active
        ctypes.windll.kernel32.CloseHandle(handle)
        return exists
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except OSError:
        return False
    return True


class SidecarLifecycleTests(unittest.TestCase):
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
            deadline = time.monotonic() + 1.0
            while time.monotonic() < deadline and _process_exists(sidecar_pid):
                time.sleep(0.02)
            self.assertFalse(
                _process_exists(sidecar_pid),
                "the tracker sidecar must not survive after its owning Godot process exits",
            )
        finally:
            if _process_exists(sidecar_pid):
                try:
                    os.kill(sidecar_pid, signal.SIGTERM)
                except OSError:
                    pass


if __name__ == "__main__":
    unittest.main()
