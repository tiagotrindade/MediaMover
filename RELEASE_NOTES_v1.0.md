# MediaMover v1.0.0
**Release Date:** October 27, 2023

This landmark release marks the official v1.0 of MediaMover. It's a complete reimagining of the user experience, centered on safety, clarity, and efficiency. We are proud to introduce the new **Operation Wizards**, which guide users step-by-step through organization and renaming tasks, making them more intuitive and safer than ever.

---

### ✨ NEW FEATURES

*   **✨ Organization Wizard (V2):** A brand new, step-by-step interface for organizing your files. You can now preview the folder structure, choose between "Copy" and "Move" with clear safety prompts, and track progress in real-time.

*   **✨ Rename Wizard (V2):** A powerful and visual way to build new filenames. Add custom text, sequential numbers, dates, or the original name, and see an instant preview of the result before applying.

*   **🛡️ File Integrity Verification:** When using the "Move" operation, MediaMover now calculates a file's checksum (SHA256) before and after the operation. If the hashes don't match, the operation is halted, ensuring your data is **never** corrupted during the transfer. (Fixes `BUG-01`)

*   **🔍 Filename Conflict Detection:** The Rename Wizard now proactively detects and warns you if your naming pattern creates duplicate filenames, preventing errors before they happen. (Fixes `TC-REN-003`)

### 🐛 BUG FIXES

*   **[CRITICAL]** Fixed a data corruption bug (`BUG-01`) where moving files could result in 0-byte files if the operation was interrupted. The new integrity check resolves this.

*   **[SAFE]** The application no longer overwrites existing files in the destination folder by default. Files with conflicting names are now safely skipped to prevent data loss. (Fixes `BUG-02`)

*   **[LOGIC]** Fixed an issue where the destination folder structure was created incorrectly, sometimes duplicating folder names. (Fixes `BUG-03`)

*   **[USABILITY]** The app now prevents selecting the same folder for both source and destination in the Organization wizard. (Fixes `TC-ORG-006`)

*   **[USABILITY]** The Rename Wizard now automatically adds the file extension if it isn't specified, preventing the creation of typeless files.

*   **[ROBUSTNESS]** Invalid characters in filenames (like `/` or `:`) are now automatically sanitized in the Rename Wizard to prevent failures.

---

Thank you for using MediaMover! This update is a major leap forward in the application's reliability and ease of use.
