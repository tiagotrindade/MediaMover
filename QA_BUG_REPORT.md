# FolioSort — QA Bug Report

**Date:** 2026-03-25
**Reviewer:** QA Code Review (Static Analysis)
**App Version:** v0.9
**Total Bugs Found:** 86

---

## Summary by Severity

| Severity | Count |
|----------|-------|
| CRITICAL | 7 |
| HIGH     | 27 |
| MEDIUM   | 38 |
| LOW      | 14 |

## Summary by Area

| Area | Bugs |
|------|------|
| Views (UI) | 24 |
| ViewModels (Business Logic) | 19 |
| Services (Core Engine) | 22 |
| Models (Data Layer) | 18 |
| Utilities & Pro Services | 27 |

---

## CRITICAL BUGS (7)

### C-01: Continuation Leak in ResilientFileOperator Pause/Resume
- **File:** `ResilientFileOperator.swift` ~Line 62
- **Impact:** App hang / zombie tasks
- **Description:** In `resume()`, if `pause()` is called again before `resume()` is processed, the old `pauseContinuation` is overwritten and the previous waiting task is never resumed. This creates zombie tasks that hang forever during network file operations.

### C-02: Out-of-Bounds Array Access in XXHash64
- **File:** `XXHash64.swift` ~Lines 122-136
- **Impact:** Crash
- **Description:** `readLE64()` and `readLE32()` functions don't validate that `offset + 8` (or `+4`) is within bounds of the buffer array. If called with an invalid offset from `finalize()`, the app will crash with an index out of range exception.

### C-03: GeocodingService Pending Requests Initialization Bug
- **File:** `GeocodingService.swift` ~Lines 54-59
- **Impact:** Continuation leak / lost geocoding results
- **Description:** `pendingRequests[key] = []` is set at the wrong point in the flow. The first call initializes an empty array, but subsequent concurrent calls try to append to `pendingRequests[key]?` before the initialization. This causes continuations to be lost and geocoding results to never reach waiting callers.

### C-04: Mutable State in Sendable Struct (MediaFile)
- **File:** `MediaFile.swift` ~Lines 37-40
- **Impact:** Data race
- **Description:** `MediaFile` is a `struct` marked `Sendable` but contains mutable `var` properties (`locationCity`, `locationCountry`, `locationState`, `locationLocality`). These properties are modified after creation (during reverse geocoding), which violates `Sendable` guarantees and creates data race conditions across actor boundaries.

### C-05: Force Unwraps on System APIs
- **File:** `OperationRecord.swift` ~Line 40, `ProfileManager.swift` ~Line 128
- **Impact:** Crash on restricted systems
- **Description:** `FileManager.default.urls(...).first!` force-unwraps without safety check. While extremely rare, if Application Support directory lookup fails (e.g., sandboxed environment, restricted permissions), the app will crash on launch.

### C-06: SettingsView Exposes Pro Toggle in Production
- **File:** `SettingsView.swift` ~Lines 72-108
- **Impact:** Revenue loss / security bypass
- **Description:** The "Development" section includes a toggle for Pro mode with a comment "remove before release". This allows any user to enable all Pro features without purchasing, completely bypassing the monetization system.

### C-07: UpgradeView "Restore Purchase" Not Implemented
- **File:** `UpgradeView.swift` ~Lines 98-101
- **Impact:** App Store rejection / user data loss
- **Description:** The "Restore Purchase" button has only a TODO comment. This is a mandatory App Store requirement — users who reinstall the app or switch devices cannot restore their purchase.

---

## HIGH SEVERITY BUGS (27)

### H-01: Duplicate Dialog Continuation Race Condition
- **File:** `OrganizerViewModel.swift` ~Lines 569-587
- **Description:** `askUserAboutDuplicate()` creates a `CheckedContinuation` stored in `duplicateContinuation`. If the dialog appears multiple times concurrently, the previous continuation is overwritten and never resumed, causing a runtime crash ("withCheckedContinuation called with no resume").

### H-02: Missing MainActor Isolation in DuplicateResolver Closure
- **File:** `OrganizerViewModel.swift` ~Lines 461-476
- **Description:** The closure captures `[weak self]` and accesses `rememberedDuplicateAction` without MainActor isolation. Although the ViewModel is `@MainActor`, closures passed to `FileOrganizer.organize()` run on background threads, creating a data race.

### H-03: RenameViewModel Missing destinationURL Validation
- **File:** `RenameViewModel.swift` ~Lines 385-390
- **Description:** In `executeRename()`, if `renameMode == .copyToFolder` but `selectDestination()` was never called, `destinationURL` is nil. The code proceeds without a guard, causing the entire operation to fail with obscure errors or silently skip all files.

### H-04: Cancellation Doesn't Stop Active File Operations
- **File:** `RenameViewModel.swift` ~Lines 392-433
- **Description:** The cancellation check only happens between files, not during copy/move operations. Partially-renamed files are left behind with no rollback mechanism, leaving the filesystem in an inconsistent state.

### H-05: TOCTOU in overwriteIfLarger Duplicate Handling
- **File:** `FileOrganizer.swift` ~Lines 205-222
- **Description:** File size is checked at line 206, but the file is deleted at line 209. Between these operations, the target could change, creating a time-of-check-time-of-use vulnerability that can lead to data loss.

### H-06: Verification Errors Not Counted as Failures
- **File:** `FileOrganizer.swift` ~Lines 289-295
- **Description:** When integrity verification fails, the error is logged but the file is still counted as "processed successfully" in `OperationResult`. This hides data corruption from the user.

### H-07: Fragile ISO 6709 GPS Parsing
- **File:** `MetadataExtractor.swift` ~Lines 189-196
- **Description:** The parser uses fragile sign-counting logic to split latitude/longitude. Edge cases with altitude values or non-standard formatting can cause incorrect coordinate extraction.

### H-08: Race Condition in Speed Tracking
- **File:** `ResilientFileOperator.swift` ~Lines 29-37
- **Description:** `bytesPerSecond` computed property is not async but accesses shared mutable state (`recentBytesLog`), violating actor isolation semantics.

### H-09: Memory Leak in Continuation Storage
- **File:** `ResilientFileOperator.swift` ~Lines 23-24
- **Description:** `pauseContinuation` is stored as a strong reference. Cancelled tasks waiting on the continuation are never cleaned up, causing memory leaks.

### H-10: Dynamic Format String Construction
- **File:** `TemplateEngine.swift` ~Line 304
- **Description:** `String(format: "%0\(n)d", ...)` dynamically interpolates a value into a format string. While `n` is typed as Int, the pattern is dangerous and could lead to unexpected behavior.

### H-11: Unsafe Concurrent File Writes in ActivityLogger
- **File:** `ActivityLogger.swift` ~Lines 94-97
- **Description:** File handle writes to the log file without locking. Concurrent writes from multiple operations can corrupt the log file.

### H-12: Partial Undo Failure Leaves Inconsistent State
- **File:** `OperationRecord.swift` ~Lines 102-130
- **Description:** If undoing record #3 of #5 fails, records #4 and #5 are still undone. The batch is marked as "undone" when it's only partially reversed, with no rollback mechanism.

### H-13: SuccessCount Calculation Ambiguity
- **File:** `OperationResult.swift` ~Line 18
- **Description:** `successCount = processedFiles - errors.count - skippedDuplicates - skippedNoDate` — the semantics of whether `processedFiles` includes or excludes skipped files is unclear. Could misreport success rates.

### H-14: Continuation Leak in GeocodingService Pending Requests
- **File:** `GeocodingService.swift` ~Lines 53-57
- **Description:** When a cache hit occurs for a key with pending requests, continuations are never properly resumed if the geocoding result changes between calls.

### H-15: Race Condition in Geocoding Rate Limiting
- **File:** `GeocodingService.swift` ~Lines 62-67
- **Description:** Between checking `lastRequestTime` and updating it, concurrent calls can bypass the rate limit, causing Apple's geocoding service to reject requests.

### H-16: ProManager didSet Race Condition
- **File:** `ProManager.swift` ~Lines 11-14
- **Description:** The `isPro` property's `didSet` persists to UserDefaults without verifying the write succeeded. If it fails, in-memory and persistent state diverge.

### H-17: ProfileManager Equality Only Compares ID
- **File:** `ProfileManager.swift` ~Lines 36-38
- **Description:** Two profiles with the same ID but different settings are considered equal. This violates semantic equality and can cause silent data loss when profiles are stored in Sets or compared.

### H-18: VolumeManager Weak Self Race
- **File:** `VolumeManager.swift` ~Line 238
- **Description:** In `monitorVolume()`, `weak self` is captured in a detached Task. Between the guard check and actual usage, `self` could become nil.

### H-19: Memory Leak in iCloud Download Loop
- **File:** `VolumeManager.swift` ~Lines 164-182
- **Description:** The `toDownload` array holds references throughout the polling loop and files still downloading after 10 minutes are silently abandoned.

### H-20: FileHashing Resource Leak on Error
- **File:** `FileHashing.swift` ~Lines 24-26, 41-43
- **Description:** If file operations fail during hash computation (file moved/deleted during read), the file handle may not be properly released.

### H-21: XXHash64 Fragile Bounds Checking
- **File:** `XXHash64.swift` ~Lines 53-65
- **Description:** The while loops in `finalize()` have fragile bounds checking that could fail with certain buffer sizes.

### H-22: ConfigPanel onChange Missing Preview Regeneration
- **File:** `ConfigPanel.swift` ~Lines 31-52
- **Description:** When a Pro feature is toggled off (due to free tier), the preview is not regenerated, showing stale preview data that doesn't match the actual operation.

### H-23: RenameView Button Disabled State Logic Error
- **File:** `RenameView.swift` ~Lines 37-45
- **Description:** The disabled state for regex mode doesn't align with the help text overlay conditions. When `regexError != nil AND regexMatchCount == 0`, the user sees no helpful error message.

### H-24: Start Button No Feedback for Empty Folders
- **File:** `MainView.swift` ~Lines 45-50
- **Description:** If a source folder genuinely has no files, the Start button stays disabled indefinitely without clear feedback to the user about why.

### H-25: File Collision Logic Bypasses Preview
- **File:** `RenameViewModel.swift` ~Lines 414-425
- **Description:** `executeRename()` auto-renames collisions using `uniqueURL()`, but this logic doesn't exist in preview generation. The preview shows "photo.jpg" but the actual operation produces "photo_1.jpg". Users see wrong previews.

### H-26: Task Cancellation Race in startScan/beginOrganizing
- **File:** `OrganizerViewModel.swift` ~Lines 177-179, 375-376
- **Description:** New tasks are created without cancelling previous ones. Rapid button clicks cause duplicate operations running simultaneously.

### H-27: Volume Monitor Task Leak
- **File:** `OrganizerViewModel.swift` ~Lines 420-437
- **Description:** If `startOrganizing()` is cancelled before reaching cleanup code, the `volumeMonitorTask` continues running indefinitely as an orphaned background task.

---

## MEDIUM SEVERITY BUGS (38)

### M-01: ETA Division by Zero (OrganizerViewModel)
`OrganizerViewModel.swift` ~Lines 619-626 — If `filesPerSecond` is 0, produces `Infinity` in UI.

### M-02: ETA Division by Zero (RenameViewModel)
`RenameViewModel.swift` ~Lines 451-458 — Same issue as M-01.

### M-03: State Inconsistency After Task Cancellation
`OrganizerViewModel.swift` ~Lines 509-517 — `isProcessing` set to false but `result` remains nil after cancellation.

### M-04: iCloud Download Progress Not Reset
`OrganizerViewModel.swift` ~Lines 243-266 — Stale progress values shown on subsequent scans.

### M-05: Missing Validation Before OperationHistory.addBatch()
`OrganizerViewModel.swift` ~Lines 504-507 — Empty or malformed records could corrupt undo history.

### M-06: Geocoding State Not Cleaned Up on Cancel
`OrganizerViewModel.swift` ~Lines 268-281 — Stale `geocodingMessage` in UI after cancelled scan.

### M-07: Sequence Numbering Non-Contiguous for Mixed Files
`RenameViewModel.swift` ~Lines 212-238 — Mixed photo/other files produce gaps in sequence numbers.

### M-08: Rename Task Race Condition
`RenameViewModel.swift` ~Lines 135-137 — Scan and Rename can run simultaneously without cancellation.

### M-09: Regex Validation Not Atomic
`RenameViewModel.swift` ~Lines 243-302 — Rapid typing can overwrite error states before UI displays them.

### M-10: Preview Not Updated After Pattern Revert
`RenameViewModel.swift` ~Lines 193-209 — Free tier pattern enforcement doesn't properly regenerate preview.

### M-11: Silent File Truncation at 500 Files (SourcePanel)
`SourcePanel.swift` ~Lines 120-126 — Only first 500 files shown with no clear warning to user.

### M-12: Preview Tree Truncation Without Indication
`PreviewPanel.swift` ~Lines 114-120 — Shows max 30 files per folder, silently discards rest.

### M-13: ActivityLog Filter State Inconsistency
`ActivityLogView.swift` ~Lines 145-162 — Scroll position doesn't reset when filter changes.

### M-14: ActivityLog Export Silent Failure
`ActivityLogView.swift` ~Lines 101-107 — Export failure shows generic error without cause.

### M-15: includeOtherFiles Missing Preview Regeneration
`ConfigPanel.swift` ~Lines 47-52 — Toggling "Other Files" doesn't update preview.

### M-16: Rename File Display Limit Without Warning
`RenameView.swift` ~Lines 169-173 — Only 500 files shown but all may be renamed.

### M-17: ProBadge Accessibility Issue
`ProBadgeView.swift` ~Lines 17-19 — Greyed-out content invisible to screen readers.

### M-18: ProfilePickerView Silent Binding Failure
`ProfilePickerView.swift` ~Lines 28-35 — Failed profile application doesn't update UI state.

### M-19: FolderPickerSection Path Privacy Leak
`FolderPickerSection.swift` ~Lines 10, 15 — Raw filesystem path shown instead of abbreviated path.

### M-20: TemplateBuilderView Unstable ForEach ID
`TemplateBuilderView.swift` ~Lines 80-81 — Uses `\.offset` as ID which is unstable across renders.

### M-21: ResultsView ForEach Unstable ID
`ResultsView.swift` ~Lines 80, 96 — `id: \.offset` is not stable if error list changes.

### M-22: OnboardingView Hardcoded Version
`OnboardingView.swift` ~Line 107 — No migration logic for onboarding version changes.

### M-23: Symlink Loop Not Prevented in FileEnumerator
`FileEnumerator.swift` ~Lines 33-35 — Missing `.skipsSymlinks`, can cause infinite traversal.

### M-24: GPS Reference String Validation Missing
`MetadataExtractor.swift` ~Lines 103, 107 — Only checks for "S"/"W", fails on non-standard values like "South".

### M-25: Unvalidated EXIF Array Cast
`MetadataExtractor.swift` ~Line 69 — ISO array assumed to be `[NSNumber]` without type validation.

### M-26: Source File Modified Between Copy and Verify
`FileOrganizer.swift` ~Lines 231-233 — For copy mode, source file could change between copy and hash verification.

### M-27: Missing Path Sanitization in TemplateEngine
`TemplateEngine.swift` ~Lines 330-338 — Final folder path not sanitized, allowing potential `../` traversal.

### M-28: Incomplete Illegal Character Set for Filenames
`OrganizationPattern.swift` ~Lines 66-69 — Missing null char, leading `.` (creates hidden files), and `..` path traversal.

### M-29: Pro License Check TOCTOU
`OperationRecord.swift` ~Lines 48-54 — Race condition between Pro status check and history initialization.

### M-30: Silent Disk Write Failure for Undo History
`OperationRecord.swift` ~Lines 85, 162-164 — `saveToDisk()` silently fails, losing undo history.

### M-31: Data Loss on ActivityLogger Memory Trim
`ActivityLogger.swift` ~Lines 53-54 — Discarded entries not written to disk before dropping.

### M-32: Silent Logger Initialization Failure
`ActivityLogger.swift` ~Lines 43-46 — Directory creation failure silently makes logger non-functional.

### M-33: ThumbnailService Caches Generic Icons by URL
`ThumbnailService.swift` ~Lines 33-35 — System icons cached per-URL instead of per-type, wastes memory.

### M-34: XXHash64 finalize() Can Be Called Multiple Times
`XXHash64.swift` ~Lines 35-81 — No guard against re-finalization, gives different results.

### M-35: No Error Handling in Hash Read Loop
`FileHashing.swift` ~Lines 31-35, 48-52 — `readData` failures not caught, producing incorrect hashes.

### M-36: Silent Profile Loading Failure
`ProfileManager.swift` ~Lines 323-326 — Corrupted profile files silently dropped without user warning.

### M-37: Profile Template Not Validated
`ProfileManager.swift` ~Lines 71-107 — Invalid template patterns accepted and stored.

### M-38: GeocodingService Cache File Permission Issues
`GeocodingService.swift` ~Lines 35-38, 151-154 — Cache read/write failures silently ignored.

---

## LOW SEVERITY BUGS (14)

### L-01: Hardcoded Version String "v0.9"
`StatusBarView.swift` ~Line 36 — Should read from Bundle/Info.plist.

### L-02: Regex Pluralization Grammar
`RegexRenameView.swift` ~Line 77 — "files matched" should be "files match".

### L-03: Inconsistent Video Icon Color
`RenameView.swift` ~Line 359 — Uses `.purple` for video toggle vs `.green` elsewhere.

### L-04: Preview Nodes Default to Expanded
`PreviewPanel.swift` ~Line 130 — Large hierarchies cause poor performance.

### L-05: Date Formatter Created Per Row
`ActivityLogView.swift` ~Lines 232-234 — Should be cached for performance.

### L-06: SidebarView Missing Future Case Handling
`SidebarView.swift` ~Lines 8-12 — New SidebarItem cases would crash.

### L-07: Sanitization Inconsistency (Files vs Folders)
`RenamePattern.swift` ~Lines 86-89 vs `OrganizationPattern.swift` ~Lines 66-69 — Files strip illegal chars, folders replace with underscore.

### L-08: Empty Filename Edge Case
`RenamePattern.swift` ~Lines 40-84 — Files with only an extension (e.g., `.jpg`) produce awkward names.

### L-09: Silent FileEnumerator Failures
`FileEnumerator.swift` ~Lines 25-31, 47-53 — Returns empty array on error without logging.

### L-10: Shutter Speed Format Inconsistency
`MetadataExtractor.swift` ~Lines 83-84 — Uses underscore separator instead of standard slash notation.

### L-11: Regex Compiled Repeatedly in TemplateEngine
`TemplateEngine.swift` ~Line 355 — Should be cached as static constant.

### L-12: Logging Action Mismatch in Rename Copy Mode
`RenameViewModel.swift` ~Lines 427-428 — Logs "rename-copy" for success but "rename" for errors.

### L-13: sourceVolumeType Set But Never Used
`RenameViewModel.swift` ~Lines 92, 102-109 — Suggests incomplete Pro gating.

### L-14: FeatureGate requiresPro Always Returns True
`FeatureGate.swift` ~Line 25 — All gates return `true`, even features that should be in Free tier.

---

## Top Priority Fixes (Recommended Order)

1. **C-06:** Remove Dev Pro toggle from SettingsView (REVENUE CRITICAL)
2. **C-07:** Implement Restore Purchase (APP STORE REQUIREMENT)
3. **C-01:** Fix continuation leak in ResilientFileOperator
4. **C-02:** Add bounds checking to XXHash64
5. **C-03:** Fix GeocodingService pending requests logic
6. **H-01:** Fix duplicate dialog continuation race
7. **H-06:** Count verification failures as errors
8. **H-25:** Add collision detection to rename preview
9. **H-03:** Add destinationURL validation in rename
10. **H-26:** Cancel previous tasks before starting new ones
