# RightClickHero — 完整建置指南

> 適用平台：macOS 12+，Xcode 15+  
> 語言：Swift 5.9+，SwiftUI  
> 最後更新：2026-04-03

---

## Part 1 — 架構說明

### 專案組成

本專案由 **4 個元件**組成，各司其職：

| 元件 | 類型 | 職責 |
|------|------|------|
| **RightClickHero** | 主 App | SwiftUI 設定視窗、註冊 Helper、處理 AirDrop 選擇器與截圖功能 |
| **RightClickHeroFinderExt** | Finder Extension | 透過 FIFinderSync 將右鍵選單注入 Finder、最小沙盒權限、發送 XPC 請求 |
| **RightClickHeroHelper** | XPC Login Item | 背景常駐程序、接收 XPC 請求、以完整存取權限執行實際檔案操作 |
| **RightClickHeroKit** | 共用 Swift Package | 所有 3 個 target 共用的協定、模型與工具類別 |

### 架構圖

```
┌─────────────────────────────────────────────────────────────────┐
│                       使用者的 Mac                               │
│                                                                   │
│   ┌──────────────────┐         ┌──────────────────────────────┐  │
│   │   Finder.app     │         │  RightClickHero.app (主 App)  │  │
│   │                  │         │  - 設定視窗 (SwiftUI)         │  │
│   │  使用者右鍵點擊   │         │  - AirDrop 選擇器            │  │
│   └────────┬─────────┘         │  - 截圖功能                   │  │
│            │ 觸發              └──────────┬───────────────────┘  │
│            ▼                             │ SMAppService 啟動     │
│   ┌──────────────────┐                   │                       │
│   │ FinderExt (沙盒) │◄──────────────────┘                       │
│   │ FIFinderSync     │  App Groups 共享資料                       │
│   │ - 建構右鍵選單   │  (UserDefaults suite)                     │
│   │ - 建立 Bookmark  │                                           │
│   └────────┬─────────┘                                           │
│            │ XPC (JSON)                                           │
│            ▼                                                      │
│   ┌──────────────────┐                                           │
│   │  XPC Helper      │  ← 背景常駐程序                           │
│   │  (Login Item)    │                                           │
│   │  - 解析 Bookmark │                                           │
│   │  - 執行檔案操作  │                                           │
│   │  - 回傳結果      │                                           │
│   └──────────────────┘                                           │
│                                                                   │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │           RightClickHeroKit (共用 Swift Package)         │   │
│   │  XPCProtocol │ ActionRequest │ SharedDefaults │ 工具類   │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### 關鍵技術說明

- **FIFinderSync**：Apple 官方 API，用於將右鍵選單注入 Finder
- **XPC + NSXPCConnection**：沙盒程序之間的跨程序通訊機制
- **SMAppService**：將 Helper 註冊為 Login Item（系統啟動時自動執行）
- **App Groups**：所有 3 個程序之間共用 UserDefaults（group.com.yourco.rightclickhero）
- **Security-Scoped Bookmarks**：跨越沙盒邊界傳遞檔案存取權限

### 資料流程

1. 使用者在 Finder 中右鍵點擊 → FinderExt 顯示右鍵選單
2. 使用者選擇功能 → FinderExt 為所選檔案建立 security-scoped bookmarks
3. FinderExt 透過 XPC 發送請求（JSON 編碼的 ActionRequest，包含 bookmark 資料）
4. XPC Helper 接收請求，將 bookmarks 解析為 URL，執行檔案操作
5. Helper 回傳 ActionResult（成功/錯誤 + 結果檔案 bookmarks）
6. FinderExt 解碼結果，顯示成功/錯誤通知

### 檔案結構

```
RightClickHero/          ← 主 App target
  App/
    RightClickHeroApp.swift
    AppDelegate.swift
  Features/
    AirDropCoordinator.swift
    ScreenCaptureCoordinator.swift
  UI/
    SettingsView.swift
    MenuItemsSettingsView.swift
    DiskAnalyzerView.swift
    DuplicateFinderView.swift
  Resources/
    Info.plist
    RightClickHero.entitlements

RightClickHeroFinderExt/ ← Finder Extension target
  FinderSyncExtension.swift
  MenuBuilder.swift
  XPCClient.swift
  Info.plist
  RightClickHeroFinderExt.entitlements

RightClickHeroHelper/    ← XPC Helper target
  main.swift
  HelperXPCDelegate.swift
  ActionDispatcher.swift
  FileOperations.swift
  Info.plist
  RightClickHeroHelper.entitlements

RightClickHeroKit/       ← Local Swift Package (無外部依賴)
  Package.swift
  Sources/RightClickHeroKit/
    XPCServiceProtocol.swift
    ActionRequest.swift
    SharedDefaults.swift
    BookmarkHelper.swift
    ImageConverter.swift
    ArchiveManager.swift
    FileTemplateManager.swift
    DiskScanner.swift
    DuplicateDetector.swift
```

### Bundle ID 對照表

> 請將 `yourco` 替換為你自己的反向網域前綴。

| 元件 | Bundle ID |
|------|-----------|
| 主 App | `com.yourco.RightClickHero` |
| FinderExt | `com.yourco.RightClickHero.FinderExt` |
| Helper | `com.yourco.RightClickHeroHelper` |
| App Group | `group.com.yourco.rightclickhero` |

---

## Part 2 — 前置準備

在開始之前，請確認以下項目均已就緒：

### 系統需求

- **macOS**：12 Monterey 或更新版本（建議 macOS 15.2+，見 Part 5 注意事項）
- **Xcode**：15.0 或更新版本
- **Apple Developer 帳號**：需具備有效的開發者帳號以簽署 App 與 Extension

### 開發者帳號設定

1. 開啟 Xcode → **Settings**（⌘,）→ **Accounts** 分頁
2. 點擊左下角 **+** 按鈕，登入你的 Apple ID
3. 確認帳號狀態顯示為已驗證
4. 在 Xcode 的 Signing & Capabilities 中，選擇你的 Team

### 重要觀念

> **為什麼需要這麼複雜的架構？**
>
> macOS 的沙盒機制限制了 Finder Extension 的檔案存取權限。FIFinderSync Extension 只能在極度受限的沙盒內執行，無法直接對檔案進行寫入或複雜操作。因此，實際的檔案操作必須委派給獨立的 XPC Helper 程序，由 Helper 以更高的權限執行。這是 Apple 官方建議的架構模式。

---

## Part 3 — Xcode 逐步建立步驟

### Step 1 — 建立主 App

1. 開啟 Xcode，選擇 **File > New > Project**
2. 平台選擇 **macOS**，範本選擇 **App**，點擊 **Next**
3. 填寫專案資訊：
   - **Product Name**：`RightClickHero`
   - **Interface**：`SwiftUI`
   - **Language**：`Swift`
   - **Bundle Identifier**：`com.yourco.RightClickHero`（將 `yourco` 替換為你的前綴）
4. **取消勾選** "Include Tests"
5. 選擇儲存位置，點擊 **Create**

> 💡 建議將專案儲存在容易找到的路徑，例如 `~/Developer/RightClickHero/`

---

### Step 2 — 新增 Finder Extension Target

1. 選擇 **File > New > Target**
2. 在搜尋框輸入 `Finder`
3. 選擇 **Finder Extension**，點擊 **Next**
4. 填寫資訊：
   - **Product Name**：`RightClickHeroFinderExt`
5. 點擊 **Finish**
6. 彈出 "Activate scheme?" 對話框時 → 點擊 **Cancel**

> ⚠️ **重要**：絕對不要點擊 "Activate"。我們要保持使用主 App scheme 來建置整個專案。

---

### Step 3 — 新增 XPC Helper Target

1. 選擇 **File > New > Target**
2. 選擇 **Command Line Tool**，點擊 **Next**
3. 填寫資訊：
   - **Product Name**：`RightClickHeroHelper`
   - **Language**：`Swift`
4. 點擊 **Finish**
5. 彈出 "Activate scheme?" 對話框時 → 點擊 **Cancel**
6. 若詢問是否建立 bridging header → 點擊 **Don't Create**

---

### Step 4 — 新增 Local Swift Package

1. 選擇 **File > New > Package**
2. 填寫資訊：
   - **Package Name**：`RightClickHeroKit`
   - **Save location**：儲存在專案資料夾**內部**（與 `.xcodeproj` 同層級）
3. 在 "Add to project/group" 下拉選單中，選擇你的專案名稱
4. 點擊 **Create**

> ⚠️ **重要**：Xcode 會詢問要將此 Package 加入哪些 targets，請**勾選全部三個 targets**（RightClickHero、RightClickHeroFinderExt、RightClickHeroHelper）。

---

### Step 5 — 確認 Package 已加入所有 Target

1. 點擊左側欄最上方的藍色專案檔案圖示
2. 逐一點擊每個 target（RightClickHero、RightClickHeroFinderExt、RightClickHeroHelper）
3. 切換到 **General** 分頁
4. 向下捲動至 **Frameworks, Libraries, and Embedded Content**
5. 確認 `RightClickHeroKit` 出現在三個 target 中

**若任一 target 缺少 RightClickHeroKit：**

1. 點擊該 target 的 General → Frameworks 區塊中的 **+** 按鈕
2. 選擇 **Add Other... → Add Package Dependency**
3. 選擇本地的 `RightClickHeroKit` Package

---

### Step 6 — 設定 App Groups Capability

**以下步驟需對 3 個 targets 各執行一次（RightClickHero、RightClickHeroFinderExt、RightClickHeroHelper）：**

1. 在左側欄點擊 target 名稱
2. 點擊 **Signing & Capabilities** 分頁
3. 點擊頂部的 **+ Capability** 按鈕
4. 新增 **App Groups**
5. 在 App Groups 區塊點擊 **+**，輸入 group identifier：
   ```
   group.com.yourco.rightclickhero
   ```
6. 若尚未有 **App Sandbox**，同樣點擊 **+ Capability** 新增

> 💡 Xcode 會自動為每個 target 建立對應的 `.entitlements` 檔案，下一步將驗證其內容。

---

### Step 7 — 設定 Entitlements

每個 target 需要各自的 `.entitlements` 檔案。Step 6 完成後 Xcode 應已自動建立，請逐一驗證內容是否正確。

**RightClickHero.entitlements** 應包含：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourco.rightclickhero</string>
</array>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.security.network.client</key>
<true/>
```

**RightClickHeroFinderExt.entitlements** 應包含：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourco.rightclickhero</string>
</array>
<key>com.apple.security.files.user-selected.read-only</key>
<true/>
```

**RightClickHeroHelper.entitlements** 應包含：

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourco.rightclickhero</string>
</array>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
```

---

### Step 8 — 設定 FinderExt 的 Info.plist

這是最容易遺漏但**至關重要**的步驟。若設定錯誤，Finder Extension 啟動時會立即崩潰。

1. 在左側欄點擊 **RightClickHeroFinderExt** target
2. 點擊頂部的 **Info** 分頁
3. 找到 **NSExtension** 列，點擊展開
4. 找到 **NSExtensionPrincipalClass** 欄位
5. 將值設定為：
   ```
   $(PRODUCT_MODULE_NAME).FinderSyncExtension
   ```

> ⚠️ **重要**：若此欄位為空，Finder Extension 將在啟動時立即崩潰，且不會有任何有意義的錯誤訊息。務必確認此值已正確設定。

---

### Step 9 — 設定 Copy Files Build Phase（內嵌 Helper）

此步驟將 Helper 嵌入主 App bundle，讓 macOS 能夠找到並啟動它。

1. 在左側欄點擊**主 App target**（RightClickHero）
2. 點擊 **Build Phases** 分頁
3. 點擊左上角的 **+** 按鈕 → 選擇 **New Copy Files Phase**
4. 在新建的 Copy Files Phase 中進行設定：
   - **Destination**：選擇 `Wrapper`（**注意：不是 Resources**）
   - **Subpath**：輸入 `Contents/Library/LoginItems`
5. 點擊此 Phase 內部的 **+** 按鈕
6. 在清單中找到並選擇 **RightClickHeroHelper**（已編譯的產品）
7. 點擊 **Add**

> 💡 完成後，Helper 將被嵌入在主 App bundle 的 `Contents/Library/LoginItems/` 路徑下，這是 macOS 要求 Login Item 必須存放的位置。

---

### Step 10 — 複製所有程式碼檔案

從 GitHub 下載所有原始碼，並複製到專案資料夾中的正確位置。

#### RightClickHeroKit/Sources/RightClickHeroKit/

- 替換 `Package.swift` 的內容
- 新增以下 9 個 Swift 檔案：
  - `XPCServiceProtocol.swift`
  - `ActionRequest.swift`
  - `SharedDefaults.swift`
  - `BookmarkHelper.swift`
  - `ImageConverter.swift`
  - `ArchiveManager.swift`
  - `FileTemplateManager.swift`
  - `DiskScanner.swift`
  - `DuplicateDetector.swift`

#### RightClickHero/（主 App）

- 替換 `RightClickHeroApp.swift`
- 替換/新增 `AppDelegate.swift`
- 新增 `AirDropCoordinator.swift`、`ScreenCaptureCoordinator.swift`
- 新增 `SettingsView.swift`、`MenuItemsSettingsView.swift`、`DiskAnalyzerView.swift`、`DuplicateFinderView.swift`
- 替換 `Info.plist`、`RightClickHero.entitlements`

#### RightClickHeroFinderExt/

- 替換 `FinderSyncExtension.swift`（Xcode 自動產生的版本需替換）
- 新增 `MenuBuilder.swift`、`XPCClient.swift`
- 替換 `Info.plist`、`RightClickHeroFinderExt.entitlements`

#### RightClickHeroHelper/

- 替換 `main.swift`
- 新增 `HelperXPCDelegate.swift`、`ActionDispatcher.swift`、`FileOperations.swift`
- 替換 `Info.plist`、`RightClickHeroHelper.entitlements`

#### 在 Finder 新增檔案後，必須將檔案加入 Xcode

在 Finder 中複製檔案後，Xcode 不會自動識別新檔案。需手動加入：

1. 在 Xcode 左側欄，右鍵點擊對應的 target 資料夾
2. 選擇 **Add Files to "RightClickHero"...**（或對應的 target 名稱）
3. 選取新增的檔案
4. 在底部勾選正確的 **Target Membership** 核取方塊
5. 點擊 **Add**

> ⚠️ **每個檔案必須確認 Target Membership 正確**。若檔案加入到錯誤的 target，將導致建置失敗或執行期錯誤。

---

### Step 11 — Build & Test

1. 在 Xcode 工具列頂部中央，確認 scheme 選擇的是 **RightClickHero**
2. 按下 **⌘B** 進行建置
3. 若有錯誤，請參閱 Part 4 進行排除
4. 建置成功後，按下 **⌘R** 執行
5. **RightClickHero 設定視窗**應該正常開啟

---

## Part 4 — 常見錯誤排除

### Error: `No such module 'RightClickHeroKit'`

**原因**：Package 未連結到該 target

**解決方式**：
1. 點擊出錯的 target
2. 前往 **General → Frameworks, Libraries, and Embedded Content**
3. 點擊 **+** → 選擇並新增 `RightClickHeroKit`

---

### Error: `Package 2 (duplicate)`

**原因**：`RightClickHeroKit` 被加入了兩次

**解決方式**：
1. 在左側欄找到重複的 `RightClickHeroKit` package 參考
2. 右鍵點擊重複項目 → **Delete**
3. 選擇 **Remove Reference**（**不是** Move to Trash）

---

### Error: `NSExtensionPrincipalClass (null)` / Finder Extension 崩潰

**原因**：`Info.plist` 中的 `NSExtensionPrincipalClass` 欄位為空

**解決方式**：
1. 點擊 **FinderExt target → Info** 分頁
2. 展開 **NSExtension**
3. 將 **NSExtensionPrincipalClass** 設定為：
   ```
   $(PRODUCT_MODULE_NAME).FinderSyncExtension
   ```

---

### Error: `OperationQueue has no member 'global'`

**原因**：混淆了 `DispatchQueue` 和 `OperationQueue` 的 API

**解決方式**：

```swift
// ❌ 錯誤寫法
OperationQueue.global()

// ✅ 正確寫法
OperationQueue()   // 建立新的實例
```

---

### Error: `Invalid Resource 'FileTemplates': File not found`

**原因**：`Package.swift` 中參照了不存在的資源目錄

**解決方式**：
1. 開啟 `RightClickHeroKit/Package.swift`
2. 找到 `resources` 陣列
3. 移除以下這行：
   ```swift
   .copy("FileTemplates")
   ```

---

### Error: `concurrent mutation of 'coordError'`

**原因**：變數在 `NSFileCoordinator` 的 closure 內寫入，但在 closure 外讀取，造成並發存取問題

**解決方式**：

在 `FileOperations.swift` 的 catch 區塊中進行以下修改：

```swift
// ❌ 錯誤寫法
catch { coordError = error as NSError }

// ✅ 正確寫法
catch let err as NSError { coordError = err }
```

---

### Error: Target Membership 未設定

**原因**：檔案已加入資料夾，但未加入 Xcode target

**解決方式**：
1. 在左側欄點擊該檔案
2. 開啟右側的 **File Inspector** 面板（右側欄最上方的圖示）
3. 在 **Target Membership** 區塊中，勾選正確的 target

---

## Part 5 — 測試步驟

### 基本功能測試

1. 確認建置成功（⌘B 無錯誤）
2. 按下 **⌘R** 執行主 App
3. **RightClickHero 設定視窗**應正常開啟

### 啟用 Finder Extension

#### macOS 13 Ventura 及更新版本（System Settings）

1. 開啟**系統設定**（System Settings）
2. 前往 **隱私權與安全性（Privacy & Security）→ 延伸功能（Extensions）→ 已加入的延伸功能（Added Extensions）**
3. 或前往 **延伸功能（Extensions）→ Finder 延伸功能（Finder Extensions）**
4. 勾選 **RightClickHeroFinderExt**

#### macOS 12 Monterey（System Preferences）

1. 開啟**系統偏好設定**（System Preferences）
2. 前往 **延伸功能（Extensions）→ Finder**
3. 勾選 **RightClickHeroFinderExt**

### 實際功能驗證

1. 開啟 **Finder**，前往任意資料夾
2. 對某個檔案**按右鍵**，或在資料夾背景按右鍵
3. 右鍵選單中應出現 **RightClickHero** 子選單，包含所有功能選項

### macOS 15.0 / 15.1 已知 Bug

> ⚠️ **注意**：Apple 在 macOS 15.0 和 15.1 中存在一個已知 Bug，導致系統設定中的 Finder Extensions 切換開關無法正常運作。若遇到此問題，請將 macOS 更新至 **15.2 或更新版本**。

---

*本指南涵蓋從零開始重建 RightClickHero 專案所需的所有步驟。如有任何疑問，請參考 Apple 官方文件中關於 FIFinderSync Extension 與 XPC Services 的章節。*
