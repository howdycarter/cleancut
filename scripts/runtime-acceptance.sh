#!/bin/bash
# Use an already-created, dedicated simulator. No install, reset, signing change,
# private-photo access, or network dependency resolution is performed here.
set -euo pipefail
: "${CLEANCUT_SIMULATOR_ID:?Set the UDID of your dedicated acceptance simulator}"
acceptance_root="${CLEANCUT_ACCEPTANCE_ROOT:-/tmp/cleancut-runtime-acceptance}"
result_path="${CLEANCUT_RESULT_PATH:-${acceptance_root}/Acceptance-$(date -u +%Y%m%dT%H%M%SZ).xcresult}"
cd "$(dirname "$0")/.."
# An acceptance run must attempt real Vision. Ordinary unit-test CI may skip the
# opt-in gate, but that skip never constitutes release acceptance.
export TEST_RUNNER_CLEANCUT_VISION_ACCEPTANCE=1
export TEST_RUNNER_CLEANCUT_UI_ACCEPTANCE=1
# Optional: grant Photos permission on the synthetic simulator, then explicitly
# set TEST_RUNNER_CLEANCUT_PHOTOS_ACCEPTANCE=1 to exercise the real Photos writer.
xcodebuild test \
  -project CleanCut.xcodeproj -scheme CleanCut \
  -destination "platform=iOS Simulator,id=${CLEANCUT_SIMULATOR_ID}" \
  -parallel-testing-enabled NO -jobs 2 -collect-test-diagnostics never \
  -disableAutomaticPackageResolution -onlyUsePackageVersionsFromResolvedFile \
  -derivedDataPath "$acceptance_root" -resultBundlePath "$result_path" "$@"
