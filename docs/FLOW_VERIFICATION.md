# Photo import and export verification

## October 13, 2026 follow-up

This patch is based on main `ca2009a51e247f62b35a5a82f71707afac281868`.
The prior 15-test Apple-runtime result in BUILD_AND_MONETIZATION.md is historical;
it is not a result for this patch.

### Changed behavior

- Photo loading becomes busy immediately, including a slow iCloud download.
- A newer library/camera import owns its result; older completions cannot replace
  it, clear its busy state, or show a stale error.
- Cancel dismisses the processing overlay immediately and invalidates the result.
  Cancellation is checked at Vision stage boundaries. A synchronous Vision call
  already in progress may finish internally; its cancelled result is discarded.
- Reset also invalidates in-flight imports and clears old errors.
- An invalid camera result dismisses the camera and shows an actionable error.
- Save and Share use the same pre-encoded PNG export, preserving the existing
  free/Pro resolution and background rules.
- Missing/invalid PNGs, denied/restricted Photos permission, and Photos write
  failures have actionable messages. Concurrent saves cannot create duplicate
  writes. An old save cannot show its result over a newer photo.
- Editor controls are disabled during a save. A Photos write already submitted
  cannot be retracted; cancelling its task only suppresses obsolete feedback.

### Added automated coverage (not executed here)

`PhotoFlowTests` adds 19 tests to the existing compiled test source, for 34 test
methods overall. Dependencies are injected only at the loader, foreground-removal,
permission, PNG encoding, and Photos writer boundaries. Tests exercise the real
view model with manually resumed continuations, not wall-clock sleeps.

Covered: slow load busy state, superseded load success/failure, cancel during load,
retry after cancel, reset/cancel during segmentation, superseded segmentation,
invalid/missing data, download error/retry, segmentation error, cancellation errors,
denied/restricted/authorized/limited Photos access, exact PNG payload, save failure
and retry, duplicate saves, reset or cancellation during permission, stale write
failure, missing image/encoding failure, and free/Pro encoded pixel dimensions.

These are orchestration and export regression tests. They do not run real Vision
inference or Photos permission dialogs, a share destination, camera hardware,
StoreKit production, or assistive interaction.

### Checks performed in the cloud workspace

- Verified every supplied baseline source file against the immutable GitHub blob
  hash (removed one snapshot-only trailing newline per file).
- Rechecked main SHA, open PRs, and repository instruction/workflow paths.
- `git diff --check` passed.
- Source review and test-definition inventory completed.
- No Swift compiler, Xcode, Apple SDK, simulator, or iPhone is available here.
  Compilation and all 34 XCTest methods are **not run for this patch**.
- No GitHub Actions rerun or account/billing changes were performed.

### Required Apple-runtime validation

1. Open the checked-in Xcode project; resolve packages and run the CleanCut test
   scheme with ordinary simulator signing. Preserve the test log and xcresult.
   Do not disable code signing for the StoreKit fixture tests.
2. On a physical iPhone, complete library and camera import through actual Vision
   segmentation, each background selection, Photos save, and sharing to a real
   receiving app. Inspect PNG transparency and free/Pro pixel dimensions.
3. Repeat/cancel slow iCloud imports and camera capture; cancel during segmentation;
   then import another photo. Confirm no stale photo, overlay, or alert appears.
4. Deny/re-enable camera and add-only Photos access. Test a failed download,
   no-subject image, failed save, repeated Save taps, and recovery.
5. Verify Share completion and cancellation; background/foreground transitions;
   normal and largest Dynamic Type; VoiceOver traversal including Cancel and the
   editor controls. The editor's existing non-scrollable layout still needs this
   device accessibility check.
6. Repeat the existing local StoreKit suite and separately perform the signed
   sandbox/TestFlight purchase and restore release gate.

Edits are still memory-only. Process termination discards an unfinished edit; this
patch does not introduce a photo cache or promise cold-relaunch restoration.
Neither this patch nor its synthetic image tests clears the existing physical-
device segmentation or live-store release gates.
