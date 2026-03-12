# PhotoMoveApp

A macOS application that organizes photos and videos into folders based on EXIF metadata or file dates. Inspired by PhotoMove2, with extended video support.

## Features

- **EXIF-based organization** — reads DateTaken from photo EXIF data
- **Video metadata support** — reads creation date from MOV, MP4, and other video formats
- **7 folder patterns** — YYYY/MM/DD, YYYY/MM, YYYY_MM_DD, with camera model variants
- **Copy or Move** — choose whether to copy or move files
- **Duplicate detection** — SHA256 hashing with skip/rename/overwrite options
- **Fallback dating** — uses file modification date when no metadata is available

### Supported Formats

- **Photos**: JPG, JPEG, PNG, HEIC, HEIF, TIFF, TIF, CR2, NEF, ARW, DNG, ORF, RAF, RW2
- **Videos**: MOV, MP4, AVI, MKV, M4V, 3GP, WMV

## Requirements

- macOS 14 (Sonoma) or later
- Apple Silicon (M1) or Intel Mac
- Swift 6.0+

## Build & Run

```bash
# Build
swift build

# Run
swift run

# Release build
swift build -c release

# Open in Xcode
open Package.swift
```

## Usage

1. Click **Browse** to select a source folder containing photos/videos
2. Click **Browse** to select a destination folder
3. Choose a folder pattern (e.g., YYYY/MM/DD)
4. Select Copy or Move mode
5. Configure duplicate handling (Skip, Rename, or Overwrite)
6. Click **Scan** to discover media files and read metadata
7. Click **Organize** to start the operation

## License

This project is licensed under the MIT License.
