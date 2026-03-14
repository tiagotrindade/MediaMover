### 🔴 Critical Bug Fix
This release addresses **BUG-01**, a critical issue that could cause silent data corruption and permanent data loss during 'Move' operations.

- **The Fix:** The file integrity verification process has been completely rebuilt for move operations. The application now correctly calculates the hash of the source file *before* it is moved and compares it with the hash of the destination file *after* the move is complete.
- **The Risk:** Previously, the integrity check was performed on the destination file twice, offering no real verification. This could lead to corrupted files being reported as "verified" while the original was permanently deleted.

### ✨ Features & Improvements
- **Performance:** Refactored view models and optimized the file preview list in the Rename view, resulting in significant UI performance improvements, especially with large numbers of files.
- **Housekeeping:** Resolved merge conflicts from the remote branch.
