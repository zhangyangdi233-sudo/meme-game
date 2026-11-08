#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
MODEL_DIR="$SCRIPT_DIR/models"
MODEL_PATH="$MODEL_DIR/hand_landmarker.task"
MODEL_URL="https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task"

mkdir -p "$MODEL_DIR"
python3 -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip
"$VENV_DIR/bin/python" -m pip install -r "$SCRIPT_DIR/requirements.txt"
if [[ ! -f "$MODEL_PATH" ]]; then
  curl --fail --location "$MODEL_URL" --output "$MODEL_PATH"
fi
"$VENV_DIR/bin/python" "$SCRIPT_DIR/hand_tracker.py" --model "$MODEL_PATH" --self-test
