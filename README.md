# MediaMover

A native macOS app to organize photos and videos into folders based on EXIF metadata or file dates. Inspired by PhotoMove2, with full video and RAW format support.

## Download

**[Download latest DMG](https://github.com/tiagotrindade/MediaMover/releases/latest)** — macOS 14+ (Apple Silicon & Intel)

## Features

### Media Organization
- **EXIF-based sorting** — reads DateTaken from photo EXIF data
- **Video metadata** — reads creation date from MOV, MP4, MKV and other formats
- **7 folder patterns** — YYYY/MM/DD, YYYY/MM, YYYY_MM_DD, with camera model variants
- **Copy or Move mode** — choose whether to keep or move originals
- **Fallback dating** — uses file modification date when no metadata is available

### Integrity Verification
- **Post-copy checksum** verification enabled by default
- **XXHash64** — fast hashing for large batches
- **SHA-256** — option for maximum security
- Detects corrupted copies immediately after transfer

### Duplicate Detection
- **Ask Each Time** — per-file dialog: rename, replace, replace if larger, or skip (with "apply to all" option)
- **Automatic** — configurable default action (rename / replace / replace if larger)
- **Don't Move** — skip all duplicates

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

### Supported Formats

**Photos**: JPG, JPEG, PNG, HEIC, HEIF, TIFF, TIF, BMP, GIF, WebP

**RAW Photos**: CR2, CR3, CRW (Canon), NEF, NRW (Nikon), ARW, SR2, SRF (Sony), DNG (Adobe), ORF (Olympus), RAF (Fujifilm), RW2 (Panasonic), PEF (Pentax), SRW (Samsung), X3F (Sigma), IIQ, 3FR, FFF (Medium Format), RWL, MRW, ERF, KDC, DCR

**Videos**: MOV, MP4, AVI, MKV, M4V, 3GP, WMV, FLV, WebM, MTS, M2TS, TS, MPG, MPEG, VOB

**RAW Video**: BRAW (Blackmagic), R3D (RED), ARI/ARR (ARRI), CRM (Canon Cinema)

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1/M2/M3) or Intel Mac

## Build from Source

```bash
# Build and run
swift build && swift run

# Create .app bundle
make app

# Create .dmg for distribution
make dmg
```

## Usage

1. Select a **source folder** containing photos/videos
2. Select a **destination folder**
3. Choose a folder pattern (e.g., YYYY/MM/DD)
4. Configure mode (Copy/Move), duplicate handling, and integrity verification
5. Click **Scan** to discover media files and read metadata
6. Click **Organize** to start

Use the **undo button** (top-right) to reverse the last operation, or the **log button** to review activity history.

## License

MIT License
