# FolioSort

A native macOS app to organize and rename photos, videos, and other files based on EXIF metadata, GPS location, or file dates. Features a flexible template engine for folder structures, preset profiles, regex-powered mass rename, reverse geocoding, Free/Pro tiers, and full undo support.

## Download

**[Download latest DMG](https://github.com/tiagotrindade/FolioSort/releases/latest)** — macOS 14+ (Apple Silicon & Intel)

## Screenshots

| Mover | Rename |
|:---:|:---:|
| ![Mover](docs/screenshot-mover.png) | ![Rename](docs/screenshot-rename.png) |

## Features

### Media Organization (Mover)
- **Custom folder templates** — build folder structures with tokens like `{YYYY}/{MM}/{DD}`, `{Camera}`, `{City}`, `{Month}`, and more
- **Preset profiles** — 4 built-in presets (Photography by date, Photography by camera, Video production, Archive flat) plus user-created profiles
- **Simple & Advanced modes** — clean pattern dropdown for quick use, or toggle Advanced for full template builder with token palette
- **EXIF-based sorting** — reads DateTaken from photo EXIF data
- **Video metadata** — reads creation date from MOV, MP4, MKV and other formats
- **Copy or Move mode** — choose whether to keep or move originals
- **Rename with date prefix** — optionally prepend date-time to filenames during organization
- **Videos subfolder** — separate videos into a dedicated `Videos` subfolder within each date folder
- **Non-media files** — optionally include documents, archives, and any other file types
- **Preview before organizing** — scan files and review the folder tree before committing
- **Thumbnail previews** — toggle on/off for faster scanning on large libraries
- **Drag & drop** — drop source and destination folders directly onto the app

### GPS Reverse Geocoding
- **Automatic location detection** — reads GPS coordinates from photo/video EXIF data
- **Reverse geocoding** — resolves GPS to city, country, state using Apple's CLGeocoder
- **Location tokens** — use `{City}`, `{Country}`, `{State}`, `{Locality}` in folder templates
- **Smart caching** — in-memory + disk cache with coordinate rounding (~110m precision)
- **Rate limiting** — respects Apple's geocoding limits with request coalescing
- **Cancellable** — geocoding tasks respect cancellation during long scans

### Date Handling
- **EXIF date chain**: DateTimeOriginal → DateTimeDigitized → TIFFDateTime (supports scanned photos)
- **Subsecond precision**: parses EXIF dates with milliseconds (e.g. Nikon, Sony cameras)
- **File Creation Date** fallback (default) when no EXIF/metadata is found
- **File Modification Date** fallback as alternative
- **Skip** files with no metadata date available
- **UTC-consistent** folder sorting — all dates interpreted in UTC to avoid timezone drift

### Mass Rename
- **Pattern-based rename** — 7 naming patterns (Date prefix, Date-Time, Sequential, Camera model, etc.)
- **Regex rename** — find/replace with `NSRegularExpression`, capture groups (`$1`, `$2`), case-insensitive option
- **Live preview** — see before/after filenames with regex match highlighting
- **Common regex presets** — Remove prefix, Replace spaces, Extract date digits, Remove trailing numbers
- **Rename in place or copy** — rename files where they are, or copy to a new folder
- **Non-media file handling** — "other" files get a simplified date-prefix rename path

### Integrity Verification
- **Post-copy/move checksum** verification enabled by default
- **XXHash64** — fast hashing for large batches (Free tier)
- **SHA-256** — option for maximum security (Pro)
- **Move mode**: source hash computed before the move and compared after

### Cloud/NAS Import (Pro)
- **Network volumes** — use SMB/AFP NAS shares (Synology, QNAP, etc.) as source or destination
- **iCloud Drive** — full support for iCloud Drive folders, including cloud-only files
- **Auto-download** — detects not-downloaded iCloud files and downloads them before processing, with progress tracking
- **Volume badges** — visual indicators in Source/Destination panels showing volume type (NAS, iCloud)
- **Per-file indicators** — cloud download icons and network badges on individual files in the file list
- **Resilient transfers** — retry logic with exponential backoff (1s, 3s, 9s) for network file operations
- **Disconnect handling** — automatic pause/resume when network volumes disconnect and reconnect
- **Transfer speed** — real-time MB/s display during network operations
- **Space checking** — available disk space shown on destination, with low-space warning before starting
- **Connect to Server** — mount SMB/AFP shares directly from the app

### Duplicate Detection
- **Skip** — skip all duplicates (Free tier)
- **Ask Each Time** — per-file dialog: rename, replace, replace if larger, or skip (with "apply to all" option) (Pro)
- **Automatic** — configurable default action: rename, replace, or replace if larger (Pro)

### Activity Log
- Full operation log with timestamps and status indicators
- Searchable and filterable (by status or text)
- Export log file for external review

### Undo
- Reverse the last batch operation with one click
- Copy undo: removes copied files
- Move undo: moves files back to original location
- Persistent history across sessions (up to 50 batches)
- Automatic cleanup of empty directories

### Buy FolioSort Pro

**€9.99 / $9.99 — One-time purchase, no subscription.**

**[Buy FolioSort Pro](https://foliosort.lemonsqueezy.com/checkout/buy/ea44ddb0-9fa7-4555-a0cb-17e7bab0e8d5)**

1. Click the link above → complete checkout
2. Receive your **license key** by email
3. Open FolioSort → Settings → **Upgrade to Pro** → paste your key → **Activate**
4. Done — Pro unlocked forever on that Mac

- License key stored securely in macOS Keychain
- Works offline (7-day grace period between validations)
- Transfer your license to another Mac anytime (deactivate → reactivate)

### Free & Pro Tiers

FolioSort works out of the box with a generous Free tier. Pro unlocks advanced features for power users.

| Feature | Free | Pro |
|---|:---:|:---:|
| Files per operation | 100 | Unlimited |
| Folder presets | 3 | All |
| Custom templates | — | ✓ |
| Custom profiles | — | ✓ |
| Rename presets | 3 | All |
| Regex rename | — | ✓ |
| RAW photo formats | — | ✓ |
| RAW video formats | — | ✓ |
| Other (non-media) files | — | ✓ |
| SHA-256 hashing | — | ✓ |
| Advanced duplicate handling | — | ✓ |
| Rename with date prefix | — | ✓ |
| Videos subfolder | — | ✓ |
| Reverse geocoding | — | ✓ |
| Location tokens (City, Country) | — | ✓ |
| Extended EXIF tokens (Lens, ISO) | — | ✓ |
| Activity log search & export | — | ✓ |
| Persistent undo history | — | ✓ |
| Cloud/NAS Import (SMB/AFP/iCloud) | — | ✓ |

### Supported Formats

**Photos**: JPG, JPEG, PNG, HEIC, HEIF, TIFF, TIF, BMP, GIF, WebP

**RAW Photos** (Pro): CR2, CR3, CRW (Canon), NEF, NRW (Nikon), ARW, SR2, SRF (Sony), DNG (Adobe), ORF (Olympus), RAF (Fujifilm), RW2 (Panasonic), PEF (Pentax), SRW (Samsung), X3F (Sigma), IIQ, 3FR, FFF (Medium Format), RWL, MRW, ERF, KDC, DCR

**Videos**: MOV, MP4, AVI, MKV, M4V, 3GP, WMV, FLV, WebM, MTS, M2TS, TS, MPG, MPEG, VOB

**RAW Video** (Pro): BRAW (Blackmagic), R3D (RED), ARI/ARR (ARRI), CRM (Canon Cinema)

**Other** (Pro): Any file type can be included via the "Other Files" toggle

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1/M2/M3/M4) or Intel Mac

## Build from Source

```bash
# Build and run
swift build && swift run

# Create release DMG
make dmg
```

## Usage

The app uses a sidebar with four sections: **Mover**, **Rename**, **Activity**, and **Settings**. A guided onboarding wizard is shown on first launch.

### Mover (Organize files into folders)
The Mover view has three panels: source file list, configuration, and a live folder tree preview.

1. Select a **source folder** — click **Scan** to enumerate files
   - Supports local folders, mounted NAS volumes, and iCloud Drive (Pro)
   - iCloud-only files are automatically downloaded before processing
2. Select a **destination folder** in the config panel
   - Available disk space is shown; low-space warning appears if needed
3. Choose a **folder pattern** from the dropdown (YYYY/MM/DD, YYYY_MM_DD, etc.)
4. Toggle **Advanced** to access the full template builder with token palette, presets, and profiles
5. Configure options: Mode (Copy/Move), Rename with date, File types, Duplicates, Integrity verification, Date fallback
6. The **Preview panel** updates live as you change settings
7. Click **Start** to organize
   - Network operations show real-time transfer speed (MB/s) and auto-retry on failure

### Rename (Batch rename files)
1. Select a **source folder** — click **Scan**
2. Choose **Pattern** or **Regex** mode
3. For Pattern: pick a naming pattern (Date prefix, Sequential, Camera model, etc.)
4. For Regex: enter find/replace patterns with live match highlighting
5. Choose **Rename in Place** or **Copy to Folder**
6. Preview the before/after filenames in the right panel
7. Click **Rename All** (or **Copy & Rename**) to apply

### Activity
Full operation history with timestamps, status indicators, search, and export.

### Settings
View Pro status, activate/deactivate license key, and manage preferences. Shows masked license key, validation status (active/offline/expired), and a deactivation option to transfer your license to another Mac.

### Undo
Use the **Undo** button in the toolbar to reverse the last operation.

## License

MIT License
