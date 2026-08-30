#!/usr/bin/env bash
# Run every headless Godot SceneTree test under tests/, then optional Python sidecars.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-}"
INCLUDE_PYTHON=1
FILTER=""
FAST=0

usage() {
  cat <<'EOF'
Usage: tools/run_tests.sh [options]

Options:
  --godot PATH       Godot executable (default: GODOT_BIN env, then platform default)
  --fast             Skip tests that load scenes/babel_meme_game.tscn
  --skip-python      Skip tests/test_hand_tracker_*.py
  --filter REGEX     Only run test files whose basename matches REGEX
  -h, --help         Show this help

Examples:
  GODOT_BIN=/path/to/Godot tools/run_tests.sh --fast
  GODOT_BIN=/path/to/Godot tools/run_tests.sh
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --godot)
      GODOT_BIN="$2"
      shift 2
      ;;
    --fast)
      FAST=1
      shift
      ;;
    --skip-python)
      INCLUDE_PYTHON=0
      shift
      ;;
    --filter)
      FILTER="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$GODOT_BIN" ]]; then
  GODOT_BIN="/Users/zhang/Documents/游戏/Godot_4.6.3/Godot.app/Contents/MacOS/Godot"
fi

if [[ ! -x "$GODOT_BIN" ]]; then
  echo "Godot not found at: $GODOT_BIN" >&2
  echo "Set GODOT_BIN to your Godot 4.6+ executable." >&2
  exit 2
fi

if [[ -n "${GODOT_HOME:-}" ]]; then
  export HOME="$GODOT_HOME"
fi

ensure_godot_project_imported() {
  local class_cache="$ROOT/.godot/global_script_class_cache.cfg"
  local imported_dir="$ROOT/.godot/imported"
  local has_imported_assets=0
  if [[ -d "$imported_dir" ]] && compgen -G "$imported_dir/*.ctex" >/dev/null; then
    has_imported_assets=1
  fi
  if [[ -f "$class_cache" && "$has_imported_assets" -eq 1 ]]; then
    return 0
  fi

  echo "==> godot --import (building class cache and imported assets)"
  if ! "$GODOT_BIN" --headless --path "$ROOT" --import; then
    echo "Godot import failed." >&2
    exit 2
  fi
}

ensure_godot_project_imported

failures=()
passed=0
skipped=0

run_godot_test() {
  local test_path="$1"
  local rel="${test_path#"$ROOT"/}"
  local script_path="res://${rel//\\//}"

  if [[ -n "$FILTER" ]] && ! basename "$test_path" .gd | grep -Eq "$FILTER"; then
    return 0
  fi

  if [[ "$FAST" -eq 1 ]] && grep -q 'load("res://scenes/babel_meme_game.tscn")' "$test_path"; then
    skipped=$((skipped + 1))
    return 0
  fi

  echo "==> $script_path"
  if "$GODOT_BIN" --headless --path "$ROOT" --script "$script_path"; then
    passed=$((passed + 1))
  else
    failures+=("$script_path")
  fi
}

TEST_FILES=()
while IFS= read -r test_file; do
  TEST_FILES+=("$test_file")
done < <(find "$ROOT/tests" -maxdepth 1 -name 'test_*.gd' -type f | sort)

if [[ ${#TEST_FILES[@]} -eq 0 ]]; then
  echo "No tests/test_*.gd files found." >&2
  exit 2
fi

for test_file in "${TEST_FILES[@]}"; do
  run_godot_test "$test_file"
done

if [[ "$INCLUDE_PYTHON" -eq 1 ]]; then
  if command -v python3 >/dev/null 2>&1; then
    while IFS= read -r py_test; do
      if [[ -n "$FILTER" ]] && ! basename "$py_test" .py | grep -Eq "$FILTER"; then
        continue
      fi
      echo "==> python3 $py_test"
      if python3 "$py_test"; then
        passed=$((passed + 1))
      else
        failures+=("python3:${py_test#"$ROOT"/}")
      fi
    done < <(find "$ROOT/tests" -maxdepth 1 -name 'test_hand_tracker_*.py' -type f | sort)
  else
    echo "Skipping Python tests: python3 not found." >&2
  fi
fi

echo
if [[ "$FAST" -eq 1 ]]; then
  echo "Mode: fast (skipped $skipped scene tests)"
else
  echo "Mode: full"
fi
echo "Passed: $passed"
echo "Failed: ${#failures[@]}"

if [[ ${#failures[@]} -gt 0 ]]; then
  printf '  %s\n' "${failures[@]}"
  exit 1
fi

exit 0
