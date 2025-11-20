# HealthScanner

一個 iOS 原生應用，用於掃描健康設備（體重機、血壓機等）的螢幕，自動識別數據並同步至 Apple 健康 App。

## 功能特點

- 📸 **相機掃描** - 拍攝健康設備螢幕
- 🤖 **AI 識別** - 透過 API 自動識別設備數據
- ❤️ **HealthKit 整合** - 自動同步至 Apple 健康 App
- 💾 **本機儲存** - 使用 SwiftData 儲存歷史記錄
- 📊 **多種數據類型支援**
  - 體重
  - 身高
  - 血壓（收縮壓/舒張壓）
  - 心率
  - 血糖
  - 體溫

## 技術架構

### 開發環境
- **iOS 17.0+**
- **Xcode 15.0+**
- **Swift 5.9+**
- **SwiftUI**

### 主要框架
- **SwiftUI** - UI 框架
- **SwiftData** - 本機數據持久化
- **HealthKit** - Apple 健康數據整合
- **AVFoundation** - 相機功能
- **URLSession** - 網路請求

### 專案結構

```
HealthScanner/
├── App/
│   ├── HealthScannerApp.swift       # App 入口
│   └── ContentView.swift            # 主頁面
├── Models/
│   ├── HealthDataType.swift         # 健康數據類型定義
│   ├── HealthRecord.swift           # 健康記錄模型
│   └── APIModels.swift              # API 請求/回應模型
├── Services/
│   ├── CameraService.swift          # 相機服務
│   ├── APIService.swift             # API 服務
│   ├── HealthKitService.swift       # HealthKit 服務
│   └── StorageService.swift         # 本機儲存服務
├── Views/
│   ├── ScanView.swift               # 掃描頁面
│   ├── ImagePicker.swift            # 相機選擇器
│   ├── ResultConfirmView.swift      # 結果確認頁面
│   ├── HistoryView.swift            # 歷史記錄頁面
│   ├── RecordDetailView.swift       # 記錄詳情頁面
│   └── SettingsView.swift           # 設定頁面
├── Resources/
├── Utils/
├── Info.plist                       # App 配置
└── HealthScanner.entitlements       # HealthKit 權限
```

## 設定步驟

### 1. 開啟專案

在 Xcode 中開啟 `HealthScanner.xcodeproj`

### 2. 配置 Bundle Identifier

在 Xcode 中設定您的 Bundle Identifier：
- 選擇專案 → Targets → HealthScanner
- 修改 Bundle Identifier（例如：`com.yourcompany.healthscanner`）

### 3. 配置簽章

在 Xcode 中配置開發團隊和 HealthKit：

1. **選擇開發團隊**
   - 在專案設定中，選擇 Targets → HealthScanner
   - 在 "Signing & Capabilities" 標籤
   - 在 "Team" 下拉選單中選擇您的 Apple Developer Team

2. **啟用 HealthKit Capability**
   - 在同一個 "Signing & Capabilities" 標籤
   - 點擊左上角的 "+ Capability" 按鈕
   - 搜尋並添加 "HealthKit"
   - 確認 HealthKit 已出現在 capabilities 列表中

3. **檢查 Entitlements**
   - 確認專案中有 `HealthScanner.entitlements` 檔案
   - 檔案中應包含 HealthKit 權限設定

### 4. 配置 API

修改 `Services/APIService.swift` 中的 API endpoint：

```swift
private let baseURL = "https://your-api-endpoint.com/api"
```

### 5. 測試模式

目前使用測試 API（`mockScanImage`），會返回模擬數據。要使用真實 API，請在 `ScanView.swift` 中修改：

```swift
// 從這個：
let response = try await APIService.shared.mockScanImage(image)

// 改為：
let response = try await APIService.shared.scanImage(image)
```

## API 規格

### 掃描請求

**POST** `/api/scan`

```json
{
  "imageBase64": "base64_encoded_image_string",
  "deviceType": "weight|height|blood_pressure" // 可選
}
```

### 掃描回應

```json
{
  "success": true,
  "detectedType": "blood_pressure",
  "confidence": 0.95,
  "message": "檢測成功",
  "data": {
    "systolic": 120,
    "diastolic": 80,
    "heartRate": 72,
    "weight": null,
    "height": null,
    "bloodSugar": null,
    "temperature": null,
    "deviceTimestamp": "2025-10-16T10:30:00Z"
  }
}
```

## 使用流程

1. **拍照** - 點擊「掃描」標籤，拍攝健康設備螢幕
2. **識別** - 點擊「開始掃描」，等待 API 識別數據
3. **確認** - 查看識別結果，可添加備註
4. **儲存** - 點擊「儲存到健康 App」，數據會同時儲存至：
   - Apple 健康 App
   - 本機數據庫
5. **查看** - 在「記錄」標籤查看歷史數據

## 權限說明

### 相機權限
用於拍攝健康設備的螢幕。

### 健康權限
用於讀寫以下健康數據：
- 體重 (Body Mass)
- 身高 (Height)
- 血壓 (Blood Pressure)
- 心率 (Heart Rate)
- 血糖 (Blood Glucose)
- 體溫 (Body Temperature)

## 注意事項

1. **僅真機測試** - HealthKit 功能僅在真實 iPhone 上可用
2. **iOS 版本** - 需要 iOS 17 或更高版本（因使用 SwiftData）
3. **隱私** - 所有數據僅儲存在本機和用戶的 iCloud（透過 HealthKit）
4. **網路** - 需要網路連線以使用 API 識別功能

## 後續開發建議

- [ ] 整合真實的 API endpoint
- [ ] 添加圖表顯示趨勢
- [ ] 支援更多健康設備類型
- [ ] 添加數據導出功能
- [ ] 支援多語言
- [ ] 添加深色模式優化
- [ ] 添加 Widget 支援

## 授權

此專案為範例專案，請根據您的需求調整使用。

## 支援

如有問題或建議，請聯繫開發團隊。
