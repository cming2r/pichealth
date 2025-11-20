//
//  APIModels.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation

/// API 請求模型
struct ScanRequest: Codable {
    let image: String // Base64 編碼的圖片（包含 data URI 前綴）
    let deviceId: String // 裝置唯一識別碼
    let countryCode: String? // 國碼（如 TW、HK、US 等）
    let deviceType: String? // 設備類型（如 mobile、tablet、desktop）
    let addFrom: String? // 來源（如 iOS App、Android App、Web）
    let ipAddress: String? // 用戶 IP 位置

    enum CodingKeys: String, CodingKey {
        case image
        case deviceId = "device_id"
        case countryCode = "country_code"
        case deviceType = "device_type"
        case addFrom = "add_from"
        case ipAddress = "ip_address"
    }
}

/// API 回應模型
struct ScanResponse: Codable {
    let success: Bool
    let deviceType: String // "blood_pressure", "body_measurement", "blood_glucose", "unknown"
    let bloodPressure: BloodPressureData?
    let bodyMeasurement: BodyMeasurementData?
    let bloodGlucose: BloodGlucoseData?
    let year: String? // 測量年份 "2024"（若為 nil 則使用今年）
    let monthday: String? // 測量月日 "01-15"
    let time: String? // 測量時間 "09:30"
    let imageUrl: String? // 圖片 URL（存儲在 Cloudflare R2）
    let rawText: String? // 原始 OCR 文本
    let error: String? // 錯誤訊息
    let message: String? // 附加訊息

    enum CodingKeys: String, CodingKey {
        case success, deviceType, bloodPressure, bodyMeasurement, bloodGlucose
        case year, monthday, time, rawText, error, message
        case imageUrl = "image_url"
    }

    /// 計算完整的測量日期
    /// 若 year 為 nil，則使用當前年份
    var measurementDate: Date? {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())

        // 使用提供的年份，若無則使用今年
        let yearString = year ?? String(currentYear)

        guard let monthday = monthday else {
            return nil
        }

        // 組合完整日期字符串
        let fullDateString = "\(yearString)-\(monthday)"

        // 解析日期
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")

        if let parsedDate = dateFormatter.date(from: fullDateString) {
            // 如果有時間，添加時間資訊
            if let time = time {
                let timeComponents = time.split(separator: ":").compactMap { Int($0) }
                if timeComponents.count >= 2 {
                    var components = calendar.dateComponents([.year, .month, .day], from: parsedDate)
                    components.hour = timeComponents[0]
                    components.minute = timeComponents[1]
                    return calendar.date(from: components)
                }
            }
            return parsedDate
        }

        return nil
    }
}

/// 血壓數據
struct BloodPressureData: Codable {
    let systolic: Double? // 收縮壓 mmHg
    let diastolic: Double? // 舒張壓 mmHg
    let pulse: Double? // 脈搏 bpm
}

/// 身體測量數據
struct BodyMeasurementData: Codable {
    let height: Double? // 身高數值
    let heightUnit: String? // "cm", "ft", "in"
    let weight: Double? // 體重數值
    let weightUnit: String? // "kg", "lbs"
}

/// 血糖數據
struct BloodGlucoseData: Codable {
    let glucose: Double? // 血糖值
    let unit: String? // "mg/dL", "mmol/L"
    let measurementType: String? // "fasting" (空腹), "postprandial" (餐後), "random" (隨機)
}

/// API 錯誤模型
struct APIError: Codable, Error {
    let success: Bool
    let deviceType: String?
    let error: String
    let message: String
    let rawText: String?

    var localizedDescription: String {
        return message
    }
}
