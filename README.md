# RightClickHero

A macOS Finder right-click menu enhancement app built with Swift, similar to 赤友右键超人. Adds 14+ productivity features directly to your right-click context menu.

## Features

| Feature | Description |
|---------|-------------|
| New File | Create .txt, .md, .swift, .py, .json, .html, .docx and more |
| Cut / Paste | Move files (fills macOS's missing cut shortcut) |
| Copy Path | Copy full file path to clipboard |
| Convert Image | JPG ↔ PNG ↔ WebP ↔ HEIC (macOS 11+ native, no dependencies) |
| AirDrop | Share files via AirDrop directly from right-click |
| Hide / Show | Toggle file hidden attribute |
| Permanent Delete | Delete without going to Trash (with confirmation) |
| Compress | ZIP archive (plain or AES-256 encrypted) |
| Move to Folder | Move files to any location |
| Copy to Folder | Copy files to any location |
| Open With | Choose which app opens the file |
| Disk Analyzer | Visual breakdown of folder sizes |
| Duplicate Finder | Find and delete duplicate files (SHA-256) |
| Screenshot | Capture screen via ScreenCaptureKit |

## Architecture

```
RightClickHero.xcodeproj
├── RightClickHero/            Main app — SwiftUI settings UI
├── RightClickHeroFinderExt/   Finder Sync Extension — injects the menu
├── RightClickHeroHelper/      XPC Login Item — executes file operations
└── RightClickHeroKit/         Shared Swift package (features + XPC protocol)
```

The Finder extension is sandboxed and cannot perform file operations directly.
It encodes selected URLs as security-scoped bookmarks and sends them to the
Helper via XPC. The Helper resolves the bookmarks and performs the operation.

## Requirements

- macOS 12 Monterey or later
- Xcode 15 or later
- Apple Developer account (for entitlements / signing)

## Setup in Xcode

### 1. Create the Xcode project

1. Open Xcode → **File › New › Project**
2. Choose **macOS › App**, name it `RightClickHero`
3. Bundle ID: `com.yourco.RightClickHero`
4. Language: Swift, Interface: SwiftUI
5. Replace generated files with the ones in `RightClickHero/`

### 2. Add the Finder Sync Extension target

1. **File › New › Target › macOS › Finder Extension**
2. Name: `RightClickHeroFinderExt`, Bundle ID: `com.yourco.RightClickHero.FinderExt`
3. Replace generated files with the ones in `RightClickHeroFinderExt/`
4. Set the extension's `Info.plist` from `RightClickHeroFinderExt/Info.plist`

### 3. Add the XPC Helper target

1. **File › New › Target › macOS › Command Line Tool**
2. Name: `RightClickHeroHelper`, Bundle ID: `com.yourco.RightClickHeroHelper`
3. Replace `main.swift` and add other files from `RightClickHeroHelper/`
4. In **Build Phases**, add a **Copy Files** phase to the main app target:
   - Destination: `Wrapper`
   - Subpath: `Contents/Library/LoginItems`
   - Add `RightClickHeroHelper.app`

### 4. Add RightClickHeroKit as a local package

1. **File › Add Package Dependencies › Add Local…**
2. Select the `RightClickHeroKit/` directory
3. Add `RightClickHeroKit` library to all three targets

### 5. Configure Capabilities

For each target, open **Signing & Capabilities** and add:

**Main App (`RightClickHero`)**
- App Sandbox ✓
- App Groups → `group.com.yourco.rightclickhero`
- User Selected File (Read/Write)
- Network (Outgoing Connections)
- Screen Recording (add via entitlements key)

**Finder Extension (`RightClickHeroFinderExt`)**
- App Sandbox ✓
- App Groups → `group.com.yourco.rightclickhero`

**Helper (`RightClickHeroHelper`)**
- App Sandbox ✓
- App Groups → `group.com.yourco.rightclickhero`
- User Selected File (Read/Write)

Use the provided `.entitlements` files as reference.

### 6. Replace bundle IDs

Replace `com.yourco` throughout all files with your actual reverse-domain identifier.

```bash
find . -type f \( -name "*.swift" -o -name "*.plist" -o -name "*.entitlements" \) \
  -exec sed -i '' 's/com\.yourco/com.YOURTEAM/g' {} +
```

### 7. Build and run

1. Select the `RightClickHero` scheme and run
2. On first launch, the Helper is registered via `SMAppService`
3. Enable the extension: **System Settings › Privacy & Security › Extensions › Finder Extensions**
4. Right-click any file in Finder to see the menu

## File Structure

```
RightClickHeroKit/
└── Sources/RightClickHeroKit/
    ├── XPCServiceProtocol.swift   # Shared XPC protocol + constants
    ├── ActionRequest.swift        # ActionType enum, request/response models
    ├── BookmarkHelper.swift       # Security-scoped bookmark utilities
    ├── SharedDefaults.swift       # App Group UserDefaults accessors
    ├── ImageConverter.swift       # CIImage + ImageIO image conversion
    ├── DiskScanner.swift          # Recursive disk usage scanner
    ├── DuplicateDetector.swift    # Size grouping + SHA-256 duplicate finder
    ├── ArchiveManager.swift       # ZIP + encrypted ZIP via ZipArchive
    └── FileTemplateManager.swift  # New file templates

RightClickHeroFinderExt/
├── FinderSyncExtension.swift      # FIFinderSync subclass — menu(for:)
├── MenuBuilder.swift              # Builds NSMenu from enabled features
└── XPCClient.swift                # NSXPCConnection to helper

RightClickHeroHelper/
├── main.swift                     # NSXPCListener entry point
├── HelperXPCDelegate.swift        # Accepts XPC connections
├── ActionDispatcher.swift         # Routes requests to feature handlers
└── FileOperations.swift           # FileManager + NSFileCoordinator

RightClickHero/
├── App/RightClickHeroApp.swift    # @main + SMAppService registration
├── App/AppDelegate.swift          # Notification listeners
├── UI/SettingsView.swift          # Main settings window
├── UI/MenuItemsSettingsView.swift # Feature toggle list
├── UI/DiskAnalyzerView.swift      # Disk usage UI
├── UI/DuplicateFinderView.swift   # Duplicate files UI
├── Features/AirDropCoordinator.swift
└── Features/ScreenCaptureCoordinator.swift
```

## Notes

- **App Uninstaller** is not included because it requires disabling the sandbox,
  which is incompatible with Mac App Store distribution.
- **Screenshot** requires user authorization in System Settings › Privacy › Screen Recording.
- **AirDrop** must be triggered from the main app process (not the extension).
  The extension notifies the main app via Darwin notification.
- On macOS 15.0/15.1 there is a known regression with Finder extension management UI
  (fixed in 15.2). Use `pluginkit -e use -i com.yourco.RightClickHero.FinderExt` as a workaround.
