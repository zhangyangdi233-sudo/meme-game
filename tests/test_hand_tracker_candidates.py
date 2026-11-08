#!/usr/bin/env python3
"""Deterministic camera-source candidate tests without opening camera hardware."""

from __future__ import annotations

import importlib.util
import os
import unittest
from pathlib import Path
from unittest import mock


PROJECT_DIR = Path(__file__).resolve().parents[1]
TRACKER_PATH = PROJECT_DIR / "framework" / "integrations" / "hand_tracking" / "hand_tracker.py"
SPEC = importlib.util.spec_from_file_location("babel_hand_tracker", TRACKER_PATH)
assert SPEC is not None and SPEC.loader is not None
TRACKER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(TRACKER)


class CameraCandidateTests(unittest.TestCase):
    def test_empty_macos_profiler_still_probes_phone_slots(self) -> None:
        with mock.patch.object(TRACKER.sys, "platform", "darwin"), mock.patch.object(
            TRACKER, "_macos_camera_devices", return_value=[]
        ), mock.patch.dict(os.environ, {}, clear=True):
            self.assertEqual(TRACKER._camera_candidates("computer", 0), [0])
            self.assertEqual(TRACKER._camera_candidates("phone", 0), [1, 2, 3, 4, 5])

    def test_macos_phone_match_is_first_and_computer_zero_is_excluded(self) -> None:
        devices = [
            {"_name": "FaceTime HD Camera"},
            {"_name": "Zhang's iPhone Camera", "spcamera_model-id": "Continuity Camera"},
        ]
        with mock.patch.object(TRACKER.sys, "platform", "darwin"), mock.patch.object(
            TRACKER, "_macos_camera_devices", return_value=devices
        ), mock.patch.dict(os.environ, {}, clear=True):
            candidates = TRACKER._camera_candidates("phone", 0)
            self.assertEqual(candidates[0], 1)
            self.assertNotIn(0, candidates)

    def test_explicit_phone_index_override_is_respected(self) -> None:
        with mock.patch.dict(os.environ, {"BABEL_PHONE_CAMERA_INDEX": "0"}, clear=True):
            self.assertEqual(TRACKER._camera_candidates("phone", 4), [0])


if __name__ == "__main__":
    unittest.main()
