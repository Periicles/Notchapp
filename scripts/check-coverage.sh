#!/usr/bin/env bash
# Fails when line coverage of the measured sources drops below a threshold.
#
# Usage: scripts/check-coverage.sh [threshold-percent]   (default 80)
#
# Run after `swift test --enable-code-coverage`. Four files are left out of the
# measure because they are thin glue over a live window server and cannot run
# in CI: the @main app entry, the panel controller, and the two NSWindow /
# NSView subclasses it installs. Everything else — including the SwiftUI views,
# rendered for real by the E2E tests — counts.
set -euo pipefail

threshold="${1:-80}"
excluded=(
  "NotchBarApp.swift"
  "NotchPanel/NotchPanelController.swift"
  "NotchPanel/NotchPanelWindow.swift"
  "NotchPanel/TrackingContainerView.swift"
)

codecov_json="$(swift test --show-codecov-path)"
[[ -f "$codecov_json" ]] || { echo "No coverage data at $codecov_json — run swift test --enable-code-coverage first." >&2; exit 2; }

python3 - "$codecov_json" "$threshold" "${excluded[@]}" <<'PY'
import json
import sys

path, threshold, *excluded = sys.argv[1], float(sys.argv[2]), *sys.argv[3:]
files = json.load(open(path))["data"][0]["files"]

rows, covered, total = [], 0, 0
for entry in files:
    name = entry["filename"]
    if "/Sources/" not in name:
        continue
    relative = name.split("/Sources/", 1)[1]
    if relative in excluded:
        continue
    lines = entry["summary"]["lines"]
    covered += lines["covered"]
    total += lines["count"]
    rows.append((lines["percent"], lines["covered"], lines["count"], relative))

for percent, hit, count, relative in sorted(rows):
    print(f"{percent:6.1f}%  {hit:4}/{count:<4}  {relative}")

overall = 100 * covered / total
print(f"\nLine coverage: {overall:.1f}% ({covered}/{total}), required {threshold:.0f}%")
print(f"Excluded from the measure: {', '.join(excluded)}")
if overall < threshold:
    sys.exit(f"Coverage {overall:.1f}% is below the {threshold:.0f}% threshold")
PY
