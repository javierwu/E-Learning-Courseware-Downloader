# E-Learning Courseware Downloader

An interactive download tool for E-Learning platforms, supporting Windows, macOS, and Linux.

## Features

- **Dynamic Domain Detection**: Automatically extracts domain from your URL - no hardcoded credentials
- **Multi-Platform Support**: Windows (PowerShell), macOS/Linux (Bash)
- **Batch Download**: Download multiple courseware without re-entering credentials
- **Multiple Format Support**: PDF, PPT, PPTX, DOC, DOCX, MP4, XLS, XLS
- **Slide Viewer Support**: Downloads PPTs converted to online slide viewers as individual images

## Quick Start

### Windows

**Method 1: Double-click (Recommended)**
```
Double-click Courseware_Download.bat
```

**Method 2: PowerShell**
```powershell
powershell -ExecutionPolicy Bypass -File .\Courseware_Download.ps1
```

### macOS / Linux

```bash
chmod +x courseware_download.sh
./courseware_download.sh
```

## Input Format

Enter the **full** courseware page URL when prompted.

**Example:**
```
https://elearning.example.com/clientcn/courseware-pdf?id=xxx&title=xxx
```

The tool will:
1. Extract the domain name (e.g., `example.com`) from your URL
2. Build API endpoints dynamically
3. Download the courseware file

## Requirements

### Windows
- Windows 10/11
- PowerShell 5.0+ (pre-installed)
- curl (pre-installed on Windows 10 1803+)

### macOS / Linux
- curl (pre-installed)
- bash

## Output Files

Downloaded files are saved in the same directory as the script.

**Single file:**
```
Courseware_YYYYMMDD_HHMMSS.{ext}
```

**Slide viewer (PPT converted to images):**
```
PresentationTitle/
└── slides/
    └── pic/
        ├── slide1.JPG
        ├── slide2.JPG
        └── ...
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Cannot load file because running scripts is disabled" | Use `Courseware_Download.bat` or run: `powershell -ExecutionPolicy Bypass -File .\Courseware_Download.ps1` |
| "curl is not recognized" | Install curl from https://curl.se/download.html |
| "Download failed - invalid file" | Check username/password and verify you have permission to access the resource |
| "Unable to extract domain from URL" | Make sure you enter the **full URL**, not just the resource ID |
| PPT downloads as folder of images | Some presentations are converted to online slide viewers - this is expected behavior |

## How It Works

```
User Input URL
     ↓
Extract Domain (e.g., example.com)
     ↓
Build API Endpoints (dynamic)
     ↓
CAS SSO Authentication
     ↓
Download Courseware
```

## Security

- **No hardcoded credentials**: Domain and endpoints are extracted from your input URL
- **No data storage**: No sensitive information is stored or transmitted
- **Session isolation**: Cookies are stored in temporary files and cleaned up after use

## File Structure

```
E-Learning-Courseware-Downloader/
├── Courseware_Download.ps1      # Windows PowerShell script
├── Courseware_Download.bat      # Windows launcher (double-click)
├── courseware_download.sh       # macOS/Linux script
└── README.md                    # This file
```

## Disclaimer

This tool is for **learning purposes only**. Do not use for commercial purposes.

## License

MIT License - Use at your own risk

## Version

v1.0 - Dynamic domain extraction, multi-platform support
