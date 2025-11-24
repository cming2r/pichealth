//
//  ResultConfirmView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI

struct ResultConfirmView: View {
    let scanResponse: ScanResponse
    let capturedImage: UIImage?

    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var storageService: StorageService
    @Environment(\.dismiss) var dismiss
    @Environment(\.selectedTab) var selectedTab

    @State private var isSaving = false
    @State private var savedSuccessfully = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingAuthorizationAlert = false
    @State private var showToast = false
    @State private var selectedDate: Date = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 預覽圖片
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 120)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                    }

                    // 檢測結果
                    if scanResponse.success {
                        if hasValidData(scanResponse) {
                            // 有檢測到數據
                            VStack(spacing: 16) {
                                Text("result.detected".localized)
                                    .font(.headline)

                                detectDataViews(for: scanResponse)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            // 日期時間選擇
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("result.measurementTime".localized)
                                        .font(.headline)

                                    Spacer()

                                    Text(relativeTimeText)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    DatePicker("", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                                        .datePickerStyle(.compact)
                                        .labelsHidden()

                                    Spacer()

                                    // "設為現在" 按鈕（只在非現在時間時顯示）
                                    if !isNowTime {
                                        Button(action: {
                                            selectedDate = Date()
                                        }) {
                                            Text("time.setToNow".localized)
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)

                            // 儲存按鈕
                            Button(action: {
                                saveData()
                            }) {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                } else if savedSuccessfully {
                                    Label("result.saved".localized, systemImage: "checkmark")
                                } else {
                                    Label("result.save".localized, systemImage: "heart.fill")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(savedSuccessfully ? Color.green : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .disabled(isSaving || savedSuccessfully)
                            .padding(.horizontal)
                        } else {
                            // 沒有檢測到數據
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.orange)

                                Text("result.noData.title".localized)
                                    .font(.headline)

                                Text("result.noData.message".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("result.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("result.cancel".localized) {
                        dismiss()
                    }
                }
            }
            .toast(isShowing: $showToast, message: "toast.saved".localized)
            .onAppear {
                initializeDate()
            }
            .alert("result.error.title".localized, isPresented: $showingError) {
                Button("result.confirm".localized, role: .cancel) {}
            } message: {
                Text(errorMessage ?? "scan.error.unknown".localized)
            }
            .alert("result.permission.title".localized, isPresented: $showingAuthorizationAlert) {
                Button("scan.camera.permission.settings".localized, role: .none) {
                    goToSettings()
                }
                Button("result.cancel".localized, role: .cancel) {}
            } message: {
                Text("result.permission.message".localized)
            }
        }
    }

    @ViewBuilder
    private func detectDataViews(for response: ScanResponse) -> some View {
        VStack(spacing: 12) {
            // 血壓數據
            if let bp = response.bloodPressure {
                if let systolic = bp.systolic, let diastolic = bp.diastolic {
                    dataRow(icon: "heart.text.square.fill", title: "health.bloodPressure".localized,
                           value: "\(Int(systolic))/\(Int(diastolic)) mmHg", color: .red)
                }
                if let pulse = bp.pulse {
                    dataRow(icon: "heart.fill", title: "health.pulse".localized,
                           value: "\(Int(pulse)) bpm", color: .pink)
                }
            }

            // 身體測量數據
            if let body = response.bodyMeasurement {
                if let height = body.height {
                    let heightUnit = body.heightUnit ?? "cm"
                    dataRow(icon: "ruler.fill", title: "health.height".localized,
                           value: "\(String(format: "%.1f", height)) \(heightUnit)", color: .green)
                }
                if let weight = body.weight {
                    let weightUnit = body.weightUnit ?? "kg"
                    dataRow(icon: "scalemass.fill", title: "health.weight".localized,
                           value: "\(String(format: "%.1f", weight)) \(weightUnit)", color: .blue)
                }
            }

            // 血糖數據
            if let glucose = response.bloodGlucose {
                if let value = glucose.glucose {
                    let unit = glucose.unit ?? "mg/dL"
                    let typeText = getGlucoseTypeText(glucose.measurementType)
                    dataRow(icon: "drop.fill", title: "health.bloodSugar".localized + typeText,
                           value: "\(String(format: "%.1f", value)) \(unit)", color: .orange)
                }
            }
        }
    }

    /// 獲取血糖測量類型文字
    private func getGlucoseTypeText(_ type: String?) -> String {
        guard let type = type else { return "" }
        switch type {
        case "fasting": return "bloodSugar.fasting".localized
        case "postprandial": return "bloodSugar.postprandial".localized
        case "random": return "bloodSugar.random".localized
        default: return ""
        }
    }

    /// 檢查是否有有效數據
    private func hasValidData(_ response: ScanResponse) -> Bool {
        // 檢查血壓數據
        if let bp = response.bloodPressure {
            if bp.systolic != nil || bp.diastolic != nil || bp.pulse != nil {
                return true
            }
        }

        // 檢查身體測量數據
        if let body = response.bodyMeasurement {
            if body.height != nil || body.weight != nil {
                return true
            }
        }

        // 檢查血糖數據
        if let glucose = response.bloodGlucose {
            if glucose.glucose != nil {
                return true
            }
        }

        return false
    }

    private func dataRow(icon: String, title: String, value: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 30)

            Text(title)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    /// 計算相對時間文字
    private var relativeTimeText: String {
        let now = Date()
        let interval = now.timeIntervalSince(selectedDate)

        // 如果是未來時間
        if interval < 0 {
            return "time.future".localized
        }

        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)

        // 3分鐘內
        if minutes < 3 {
            return "time.now".localized
        }
        // 1小時內
        else if minutes < 60 {
            return "time.minutesAgo".localized(minutes)
        }
        // 3小時內（1-3小時）
        else if hours < 3 {
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "time.hoursAgo".localized(hours)
            } else {
                return "time.hoursMinutesAgo".localized(hours, remainingMinutes)
            }
        }
        // 24小時內（3-24小時）
        else if hours < 24 {
            return "time.hoursAgo".localized(hours)
        }
        // 超過24小時
        else {
            return "time.daysAgo".localized(days)
        }
    }

    /// 判斷是否為"現在"時間（過去3分鐘內）
    private var isNowTime: Bool {
        let now = Date()
        let interval = now.timeIntervalSince(selectedDate)

        // 如果是未來時間，一定不是"現在"
        if interval < 0 {
            return false
        }

        // 只有過去 3 分鐘內才算"現在"
        let minutes = Int(interval / 60)
        return minutes < 3
    }

    /// 初始化日期時間
    private func initializeDate() {
        // 使用新的 measurementDate 計算屬性
        if let parsedDate = scanResponse.measurementDate {
            selectedDate = parsedDate
            return
        }

        // 否則使用現在時間（已經是預設值）
    }

    /// 前往設定頁面
    private func goToSettings() {
        // 關閉當前頁面
        dismiss()
        // 切換到設定 Tab 並導航到權限設定頁面
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            selectedTab?.wrappedValue = 2
            // 再延遲一點，確保 Tab 切換完成後才發送導航通知
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: .navigateToHealthPermissions, object: nil)
            }
        }
    }

    /// 儲存數據
    private func saveData() {
        isSaving = true
        errorMessage = nil

        Task {
            do {
                // 建立紀錄
                var records: [HealthRecord] = []

                // 處理血壓數據
                if let bp = scanResponse.bloodPressure {
                    if let systolic = bp.systolic, let diastolic = bp.diastolic {
                        let record = HealthRecord(
                            type: .bloodPressure,
                            value: systolic,
                            systolic: systolic,
                            diastolic: diastolic,
                            timestamp: selectedDate,
                            imageUrl: scanResponse.imageUrl,
                            notes: nil
                        )
                        records.append(record)
                    }

                    // 如果有脈搏數據，另外儲存
                    if let pulse = bp.pulse {
                        let record = HealthRecord(
                            type: .heartRate,
                            value: pulse,
                            timestamp: selectedDate,
                            imageUrl: scanResponse.imageUrl,
                            notes: nil
                        )
                        records.append(record)
                    }
                }

                // 處理身體測量數據
                if let body = scanResponse.bodyMeasurement {
                    // 身高
                    if let height = body.height {
                        // 將身高轉換為公分（HealthKit 使用公分）
                        let heightInCm: Double
                        switch body.heightUnit?.lowercased() {
                        case "ft":
                            heightInCm = height * 30.48 // 英尺轉公分
                        case "in":
                            heightInCm = height * 2.54 // 英寸轉公分
                        default:
                            heightInCm = height // 已經是公分
                        }

                        let record = HealthRecord(
                            type: .height,
                            value: heightInCm,
                            timestamp: selectedDate,
                            imageUrl: scanResponse.imageUrl,
                            notes: nil
                        )
                        records.append(record)
                    }

                    // 體重
                    if let weight = body.weight {
                        // 將體重轉換為公斤（HealthKit 使用公斤）
                        let weightInKg: Double
                        if body.weightUnit?.lowercased() == "lbs" {
                            weightInKg = weight * 0.453592 // 磅轉公斤
                        } else {
                            weightInKg = weight // 已經是公斤
                        }

                        let record = HealthRecord(
                            type: .weight,
                            value: weightInKg,
                            timestamp: selectedDate,
                            imageUrl: scanResponse.imageUrl,
                            notes: nil
                        )
                        records.append(record)
                    }
                }

                // 處理血糖數據
                if let glucose = scanResponse.bloodGlucose {
                    if let value = glucose.glucose {
                        // 將血糖轉換為 mg/dL（HealthKit 使用 mg/dL）
                        let glucoseInMgDl: Double
                        if glucose.unit?.lowercased() == "mmol/l" {
                            glucoseInMgDl = value * 18.0182 // mmol/L 轉 mg/dL
                        } else {
                            glucoseInMgDl = value // 已經是 mg/dL
                        }

                        let record = HealthRecord(
                            type: .bloodSugar,
                            value: glucoseInMgDl,
                            timestamp: selectedDate,
                            imageUrl: scanResponse.imageUrl,
                            notes: nil
                        )
                        records.append(record)
                    }
                }

                // 先儲存到 HealthKit（如果失敗，整個流程都會失敗）
                for record in records {
                    try await healthKitService.saveHealthRecord(record)
                }

                // HealthKit 儲存成功後，才儲存到本機
                for record in records {
                    // 標記為已同步
                    record.isSyncedToHealthKit = true
                    // 儲存到本機
                    try storageService.saveRecord(record)
                }

                await MainActor.run {
                    isSaving = false
                    savedSuccessfully = true

                    // 顯示 Toast
                    showToast = true

                    // 延遲後切換到紀錄頁面並關閉當前頁面
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        // 切換到紀錄頁面（tab 0）
                        selectedTab?.wrappedValue = 0
                        // 關閉當前頁面
                        dismiss()
                    }
                }

            } catch {
                await MainActor.run {
                    isSaving = false

                    // 檢查是否為權限錯誤
                    let errorDescription = error.localizedDescription
                    if errorDescription.contains("未授權") || errorDescription.contains("Not authorized") || errorDescription.contains("HealthKit") {
                        // 權限錯誤，顯示授權引導
                        showingAuthorizationAlert = true
                    } else {
                        // 其他錯誤
                        errorMessage = errorDescription
                        showingError = true
                    }
                }
            }
        }
    }
}

#Preview {
    let mockResponse = try! JSONDecoder().decode(ScanResponse.self, from: """
    {
        "success": true,
        "device_type": "blood_pressure",
        "blood_pressure": {
            "systolic": 120,
            "diastolic": 80,
            "pulse": 72
        },
        "body_measurement": null,
        "blood_glucose": null,
        "year": "2024",
        "monthday": "01-15",
        "time": "09:30",
        "image_url": "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_abc123.png",
        "raw_text": "SYS: 120 DIA: 80 PULSE: 72",
        "error": null,
        "message": "成功識別血壓數據"
    }
    """.data(using: .utf8)!)

    return ResultConfirmView(
        scanResponse: mockResponse,
        capturedImage: nil
    )
    .environmentObject(HealthKitService())
    .environmentObject(StorageService())
}
