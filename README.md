# RightClickHero

用 Swift 打造的 macOS Finder 右鍵選單增強工具，功能類似赤友右键超人。直接在右鍵選單中新增 14+ 項實用功能。

## 功能列表

| 功能 | 說明 |
|------|------|
| 新建文件 | 建立 .txt、.md、.swift、.py、.json、.html、.docx 等格式 |
| 剪切 / 貼上 | 移動檔案（補齊 macOS 缺少的剪切功能） |
| 複製路徑 | 將完整檔案路徑複製到剪貼板 |
| 圖片格式轉換 | JPG ↔ PNG ↔ WebP ↔ HEIC（macOS 11+ 原生支援，無需第三方套件） |
| 隔空投送 | 直接從右鍵選單透過 AirDrop 分享檔案 |
| 隱藏 / 顯示 | 切換檔案的隱藏屬性 |
| 徹底刪除 | 不移至垃圾桶直接刪除（含確認提示） |
| 壓縮 | 建立 ZIP 壓縮檔（支援 AES-256 加密） |
| 移動到資料夾 | 將檔案移動到任意位置 |
| 複製到資料夾 | 將檔案複製到任意位置 |
| 以指定 App 開啟 | 選擇要用哪個 App 開啟檔案 |
| 磁盤空間分析 | 以視覺化方式顯示各資料夾佔用空間 |
| 重複文件偵測 | 找出並刪除重複檔案（SHA-256 比對） |
| 截圖 | 透過 ScreenCaptureKit 擷取螢幕畫面 |

## 架構說明

```
RightClickHero.xcodeproj
├── RightClickHero/            主 App — SwiftUI 設定介面
├── RightClickHeroFinderExt/   Finder Sync Extension — 注入右鍵選單
├── RightClickHeroHelper/      XPC Login Item — 執行實際的檔案操作
└── RightClickHeroKit/         共用 Swift Package（功能邏輯 + XPC 協定）
```

Finder Extension 受沙盒限制，無法直接執行檔案操作。它會將選取的 URL 編碼為 Security-Scoped Bookmark，透過 XPC 傳送給 Helper，由 Helper 解析並執行操作。

## 系統需求

- macOS 12 Monterey 或更新版本
- Xcode 15 或更新版本
- Apple Developer 帳號（用於 Entitlements / 簽署）

## Xcode 專案設定步驟

### 1. 建立 Xcode 專案

1. 開啟 Xcode → **File › New › Project**
2. 選擇 **macOS › App**，名稱填 `RightClickHero`
3. Bundle ID：`com.yourco.RightClickHero`
4. 語言：Swift，介面：SwiftUI
5. 將產生的預設檔案替換為 `RightClickHero/` 目錄中的檔案

### 2. 新增 Finder Sync Extension Target

1. **File › New › Target › macOS › Finder Extension**
2. 名稱：`RightClickHeroFinderExt`，Bundle ID：`com.yourco.RightClickHero.FinderExt`
3. 將產生的檔案替換為 `RightClickHeroFinderExt/` 中的檔案
4. 使用 `RightClickHeroFinderExt/Info.plist` 設定 Extension 的 Info.plist

### 3. 新增 XPC Helper Target

1. **File › New › Target › macOS › Command Line Tool**
2. 名稱：`RightClickHeroHelper`，Bundle ID：`com.yourco.RightClickHeroHelper`
3. 替換 `main.swift` 並加入 `RightClickHeroHelper/` 中的其他檔案
4. 在主 App Target 的 **Build Phases** 中新增 **Copy Files** 階段：
   - Destination：`Wrapper`
   - Subpath：`Contents/Library/LoginItems`
   - 加入 `RightClickHeroHelper.app`

### 4. 新增 RightClickHeroKit 本地套件

1. **File › Add Package Dependencies › Add Local…**
2. 選擇 `RightClickHeroKit/` 目錄
3. 將 `RightClickHeroKit` 函式庫加入三個 Target

### 5. 設定 Capabilities

對每個 Target，開啟 **Signing & Capabilities** 並依下方設定：

**主 App（`RightClickHero`）**
- App Sandbox ✓
- App Groups → `group.com.yourco.rightclickhero`
- User Selected File（Read/Write）
- Network（Outgoing Connections）
- Screen Recording（透過 entitlements key 新增）

**Finder Extension（`RightClickHeroFinderExt`）**
- App Sandbox ✓
- App Groups → `group.com.yourco.rightclickhero`

**Helper（`RightClickHeroHelper`）**
- App Sandbox ✓
- App Groups → `group.com.yourco.rightclickhero`
- User Selected File（Read/Write）

各 `.entitlements` 檔案可作為參考。

### 6. 替換 Bundle ID

將所有檔案中的 `com.yourco` 替換為你自己的 reverse-domain 識別碼：

```bash
find . -type f \( -name "*.swift" -o -name "*.plist" -o -name "*.entitlements" \) \
  -exec sed -i '' 's/com\.yourco/com.YOURTEAM/g' {} +
```

### 7. 建置與執行

1. 選擇 `RightClickHero` scheme 並執行
2. 首次啟動時，Helper 會透過 `SMAppService` 自動注冊
3. 啟用 Extension：**系統設定 › 隱私權與安全性 › 延伸功能 › Finder 延伸功能**
4. 在 Finder 中對任意檔案按右鍵即可看到選單

## 檔案結構

```
RightClickHeroKit/
└── Sources/RightClickHeroKit/
    ├── XPCServiceProtocol.swift   # 共用 XPC 協定 + 常數定義
    ├── ActionRequest.swift        # ActionType 列舉、請求/回應模型
    ├── BookmarkHelper.swift       # Security-scoped bookmark 工具
    ├── SharedDefaults.swift       # App Group UserDefaults 存取器
    ├── ImageConverter.swift       # CIImage + ImageIO 圖片轉換
    ├── DiskScanner.swift          # 遞迴磁盤空間掃描器
    ├── DuplicateDetector.swift    # 大小分組 + SHA-256 重複偵測
    ├── ArchiveManager.swift       # ZIP + 加密 ZIP（ZipArchive）
    └── FileTemplateManager.swift  # 新建文件模板管理

RightClickHeroFinderExt/
├── FinderSyncExtension.swift      # FIFinderSync 子類別 — menu(for:)
├── MenuBuilder.swift              # 從啟用功能清單動態建立 NSMenu
└── XPCClient.swift                # 連接 Helper 的 NSXPCConnection

RightClickHeroHelper/
├── main.swift                     # NSXPCListener 入口點
├── HelperXPCDelegate.swift        # 接受 XPC 連線
├── ActionDispatcher.swift         # 將請求路由到各功能處理器
└── FileOperations.swift           # FileManager + NSFileCoordinator

RightClickHero/
├── App/RightClickHeroApp.swift    # @main + SMAppService 注冊
├── App/AppDelegate.swift          # 通知監聽器
├── UI/SettingsView.swift          # 主設定視窗
├── UI/MenuItemsSettingsView.swift # 功能開關清單
├── UI/DiskAnalyzerView.swift      # 磁盤空間視覺化介面
├── UI/DuplicateFinderView.swift   # 重複文件管理介面
├── Features/AirDropCoordinator.swift
└── Features/ScreenCaptureCoordinator.swift
```

## 注意事項

- **軟體卸載功能** 未包含在此版本，因為該功能需要停用沙盒，與 Mac App Store 發行規範不相容。
- **截圖功能** 需要用戶在「系統設定 › 隱私權 › 螢幕錄製」中手動授權。
- **AirDrop** 必須從主 App 程序觸發（不能直接在 Extension 中呼叫）。Extension 透過 Darwin 通知告知主 App 顯示選取器。
- macOS 15.0/15.1 有已知的 Finder Extension 管理介面問題（15.2 已修復）。若遇到此問題，可使用以下指令作為暫時解法：

```bash
pluginkit -e use -i com.yourco.RightClickHero.FinderExt
```
