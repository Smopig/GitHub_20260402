# RightClickHero

用 Swift 打造的 macOS Finder 右鍵選單增強工具，功能類似赤友右键超人。直接在右鍵選單中新增 14+ 項實用功能。

## 功能列表

| 功能 | 說明 |
|------|------|
| 新建文件 | 建立 .txt、.md、.swift、.py、.json、.html、.docx 等格式 |
| 剪切 / 貼上 | 移動檔案（補齊 macOS 缺少的剪切功能） |
| 複製路徑 | 將完整檔案路徑複製到剪貼板 |
| 圖片格式轉換 | JPG ↔ PNG ↔ WebP ↔ HEIC（macOS 11+ 原生支援） |
| 隔空投送 | 直接從右鍵選單透過 AirDrop 分享檔案 |
| 隱藏 / 顯示 | 切換檔案的隱藏屬性 |
| 徹底刪除 | 不移至垃圾桶直接刪除（含確認提示） |
| 壓縮 | 建立 ZIP 壓縮檔（macOS 內建 compression） |
| 移動到資料夾 | 將檔案移動到任意位置 |
| 複製到資料夾 | 將檔案複製到任意位置 |
| 以指定 App 開啟 | 選擇要用哪個 App 開啟檔案 |
| 磁盤空間分析 | 以視覺化方式顯示各資料夾佔用空間 |
| 重複文件偵測 | 找出並刪除重複檔案（SHA-256 比對） |
| 截圖 | 透過 ScreenCaptureKit 擷取螢幕畫面 |

## 快速安裝（不需要打開 Xcode）

需求：**macOS 12+**、**Xcode 15+** 已安裝、**Homebrew**。

```bash
git clone https://github.com/smopig/github_20260402.git RightClickHero
cd RightClickHero
make install
```

`make install` 會自動：

1. 用 [XcodeGen](https://github.com/yonki/XcodeGen) 從 `project.yml` 生成 `RightClickHero.xcodeproj`（首次會 `brew install xcodegen`）
2. 以 Release 設定 archive + export 出 `RightClickHero.app`
3. 複製到 `/Applications/`
4. 用 `pluginkit -e use` 啟用 Finder 右鍵選單擴充功能

完成後執行一次：

```bash
open /Applications/RightClickHero.app
```

首次啟動時主 App 會透過 `SMAppService` 把 Helper 註冊為 Login Item。**之後到任何 Finder 視窗按右鍵**即可看到選單。

> 若選單沒出現，到「系統設定 → 隱私權與安全性 → 延伸功能 → Finder 延伸功能」打勾。

## 其他常用指令

| 指令 | 用途 |
|------|------|
| `make project` | 只生成 `.xcodeproj`，之後想用 Xcode 開啟可手動點 Run |
| `make build` | Debug build（不安裝） |
| `make dmg` | 產出 `build/RightClickHero.dmg` 可拖拉安裝 |
| `make uninstall` | 從 `/Applications/` 移除 + 停用 Finder 擴充 |
| `make clean` | 刪除 build artifact |
| `make reset` | 連 `.xcodeproj` 一起刪掉 |

## 自訂選項

所有變數都可在 command line 覆寫：

```bash
# 用你自己的反向網域
make install BUNDLE_PREFIX=com.example

# 指定 Apple Developer Team ID（多帳號時用得到）
make install TEAM_ID=ABCDE12345
```

預設 `BUNDLE_PREFIX = com.smopig`（定義在 `Config.xcconfig`）。

## 簽署說明

- **自用單機**：預設使用 Xcode 自動簽署（Apple Development），免費 Apple ID 即可，不需要付費 Developer Program。
- **要分發給別人**：需要付費 `$99/年` Apple Developer ID 帳號，並做 notarization。本專案目前未包含 notarization 自動化（單機自用情境不需要）。

> Finder Sync Extension + SMAppService Login Item 是 Apple 強制簽署要求，**任何工具都不能繞過**。如果完全不簽署，Finder 會直接拒絕載入擴充功能。

## 架構

```
RightClickHero.xcodeproj  (由 project.yml 生成)
├── RightClickHero            主 App — SwiftUI 設定介面
├── RightClickHeroFinderExt   Finder Sync Extension — 注入右鍵選單（沙盒）
├── RightClickHeroHelper      XPC Login Item（背景 .app）— 執行檔案操作
└── RightClickHeroKit         共用 Swift Package（協定 + 工具）
```

Finder Extension 受沙盒限制無法直接執行檔案操作，會將選取的 URL 編成 Security-Scoped Bookmark，透過 XPC 送給 Helper 執行。

所有 Bundle ID / App Group / Mach Service name 都來自 `Config.xcconfig` 的 `BUNDLE_PREFIX` 變數，並在執行時透過 `BundleConfig`（位於 `RightClickHeroKit/XPCServiceProtocol.swift`）從 Info.plist 讀取——**source code 內沒有任何 hard-coded 反向網域**。

## 系統需求

- macOS 12 Monterey 或更新版本
- Xcode 15 或更新版本（含 command-line tools）
- Homebrew（用來安裝 XcodeGen）

## CI

`.github/workflows/build.yml` 在每次 push 都會用 macOS runner build 一個未簽署的 `.app` 並上傳 artifact，可用於驗證原始碼是否還能成功編譯。

## 注意事項

- **截圖功能** 需要用戶在「系統設定 → 隱私權 → 螢幕錄製」中手動授權。
- **AirDrop** 必須由主 App 程序觸發（不能直接在 Extension 內呼叫）。Extension 透過 Darwin notification 通知主 App 顯示選取器。
- macOS 15.0/15.1 有已知的 Finder Extension 管理介面問題（15.2 已修復）。`make install` 已自動執行 `pluginkit -e use` 作為解法。

## 檔案結構

```
Config.xcconfig                       單一設定來源（BUNDLE_PREFIX 等）
project.yml                           XcodeGen spec → 生成 .xcodeproj
Makefile                              一鍵建置/安裝

RightClickHeroKit/Sources/RightClickHeroKit/
├── XPCServiceProtocol.swift          XPC 協定 + BundleConfig (從 Info.plist 讀取)
├── ActionRequest.swift               ActionType 列舉、請求/回應模型
├── BookmarkHelper.swift              Security-scoped bookmark 工具
├── SharedDefaults.swift              App Group UserDefaults 存取器
├── ImageConverter.swift              圖片轉換 (CIImage + ImageIO)
├── DiskScanner.swift                 遞迴磁盤空間掃描
├── DuplicateDetector.swift           SHA-256 重複偵測
├── ArchiveManager.swift              ZIP 壓縮
└── FileTemplateManager.swift         新建文件模板

RightClickHeroFinderExt/
├── FinderSyncExtension.swift         FIFinderSync 子類別 — menu(for:)
├── MenuBuilder.swift                 從啟用功能清單動態建立 NSMenu
└── XPCClient.swift                   連接 Helper 的 NSXPCConnection

RightClickHeroHelper/
├── main.swift                        NSXPCListener 入口點
├── HelperXPCDelegate.swift           接受 XPC 連線
├── ActionDispatcher.swift            將請求路由到各功能處理器
└── FileOperations.swift              FileManager + NSFileCoordinator

RightClickHero/
├── App/RightClickHeroApp.swift       @main + SMAppService 註冊
├── App/AppDelegate.swift             通知監聽器
├── UI/SettingsView.swift             主設定視窗
├── UI/MenuItemsSettingsView.swift    功能開關清單
├── UI/DiskAnalyzerView.swift         磁盤空間視覺化
├── UI/DuplicateFinderView.swift      重複檔案管理
├── Features/AirDropCoordinator.swift
└── Features/ScreenCaptureCoordinator.swift
```
