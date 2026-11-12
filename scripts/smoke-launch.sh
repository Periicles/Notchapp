#!/usr/bin/env bash
# Launches the app and fails if it exits within the observation window.
#
# Usage: scripts/smoke-launch.sh <path-to-binary> [seconds]   (default 8)
#
# A crash in @main, the app delegate or the panel setup kills the process well
# before the window ends; a healthy menu bar app keeps running until quit.
set -euo pipefail

binary="${1:?usage: smoke-launch.sh <binary> [seconds]}"
seconds="${2:-8}"

[[ -x "$binary" ]] || { echo "Not an executable: $binary" >&2; exit 2; }

"$binary" &
pid=$!
trap 'kill "$pid" 2>/dev/null || true' EXIT

for ((elapsed = 0; elapsed < seconds; elapsed++)); do
  sleep 1
  if ! kill -0 "$pid" 2>/dev/null; then
    wait "$pid" && status=0 || status=$?
    echo "NotchBar exited after ${elapsed}s (status ${status})" >&2
    exit 1
  fi
done

echo "NotchBar still running after ${seconds}s"
