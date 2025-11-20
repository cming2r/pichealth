//
//  APIService.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation
import UIKit

/// API 服務 - 處理與後端的通訊
class APIService {
    static let shared = APIService()

    private let baseURL = "https://vvmg.cc/api/v1"

    // 從 Info.plist 讀取 API Key
    private var apiKey: String {
        Bundle.main.object(forInfoDictionaryKey: "OCR_API_KEY") as? String ?? ""
    }

    // 快取 IP 地址（避免重複請求）
    private var cachedIPAddress: String?

    private init() {}

    /// 獲取用戶的公網 IP 地址
    private func fetchPublicIPAddress() async -> String? {
        // 如果已經有快取的 IP，直接返回
        if let cached = cachedIPAddress {
            return cached
        }

        // 使用 ipify API 獲取公網 IP（免費且穩定）
        guard let url = URL(string: "https://api.ipify.org?format=text") else {
            return nil
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let ipAddress = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                cachedIPAddress = ipAddress
                return ipAddress
            }
        } catch {
            print("獲取 IP 地址失敗: \(error.localizedDescription)")
        }

        return nil
    }

    /// 獲取裝置類型
    private func getDeviceType() -> String {
        let idiom = UIDevice.current.userInterfaceIdiom
        switch idiom {
        case .phone:
            return "mobile"
        case .pad:
            return "tablet"
        case .mac:
            return "desktop"
        default:
            return "mobile"
        }
    }

    /// 獲取國碼（從裝置地區設定）
    private func getCountryCode() -> String {
        return Locale.current.region?.identifier ?? "US"
    }

    /// 上傳圖片進行識別
    func scanImage(_ image: UIImage) async throws -> ScanResponse {
        // 先縮小圖片尺寸（限制最大邊長為 1024px，對 OCR 來說已足夠）
        let resizedImage = resizeImage(image, maxDimension: 1024)

        // 對於 OCR，使用較高質量的 JPEG 以確保文字清晰
        // 先嘗試 0.7 質量（平衡清晰度和檔案大小）
        guard var imageData = resizedImage.jpegData(compressionQuality: 0.7) else {
            throw NSError(
                domain: "APIService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "無法處理圖片"]
            )
        }

        var dataURI: String
        let maxSize = 2 * 1024 * 1024 // 2MB

        // 如果圖片太大，嘗試逐步降低質量
        if imageData.count > maxSize {
            print("圖片過大 (\(imageData.count / 1024) KB)，嘗試降低質量...")

            // 先嘗試 0.5 質量
            if let compressed = resizedImage.jpegData(compressionQuality: 0.5) {
                imageData = compressed
                print("壓縮後大小: \(imageData.count / 1024) KB")
            }

            // 如果還是太大，嘗試 0.3 質量
            if imageData.count > maxSize, let compressed = resizedImage.jpegData(compressionQuality: 0.3) {
                imageData = compressed
                print("再次壓縮後大小: \(imageData.count / 1024) KB")
            }

            // 如果還是太大，拋出錯誤
            if imageData.count > maxSize {
                throw NSError(
                    domain: "APIService",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: "圖片太大（\(imageData.count / 1024 / 1024) MB），請使用較小的圖片或選擇其他照片"]
                )
            }
        }

        print("最終圖片大小: \(imageData.count / 1024) KB，格式: JPEG")

        // 添加 data URI 前綴
        let base64String = imageData.base64EncodedString()
        dataURI = "data:image/jpeg;base64,\(base64String)"

        // 獲取 IP 地址（非同步，不阻塞主流程）
        let ipAddress = await fetchPublicIPAddress()

        // 建立請求（包含裝置資訊和 metadata）
        let request = ScanRequest(
            image: dataURI,
            deviceId: DeviceIdentifierService.shared.deviceIdentifier,
            countryCode: getCountryCode(),
            deviceType: getDeviceType(),
            addFrom: "iOS App",
            ipAddress: ipAddress
        )

        // 發送請求
        guard let url = URL(string: "\(baseURL)/ocr-health") else {
            throw NSError(
                domain: "APIService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "無效的 URL"]
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.timeoutInterval = 60 // 60 秒超時（OCR 處理需要較長時間）

        let encoder = JSONEncoder()
        urlRequest.httpBody = try encoder.encode(request)

        let (data, response) = try await URLSession.shared.data(for: urlRequest)

        // 檢查回應
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "APIService",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "無效的回應"]
            )
        }

        // 處理速率限制標頭
        if let remainingHeader = httpResponse.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remaining = Int(remainingHeader), remaining <= 2 {
            print("警告：剩餘請求次數僅有 \(remaining) 次")
        }

        // 處理不同的 HTTP 狀態碼
        switch httpResponse.statusCode {
        case 200...299:
            // 成功 - 解析回應
            let decoder = JSONDecoder()
            let scanResponse = try decoder.decode(ScanResponse.self, from: data)
            return scanResponse

        case 401:
            throw NSError(
                domain: "APIService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "API Key 無效或已過期，請檢查設定"]
            )

        case 429:
            // 速率限制
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NSError(
                    domain: "APIService",
                    code: 429,
                    userInfo: [NSLocalizedDescriptionKey: "超過速率限制：\(apiError.message)"]
                )
            }
            throw NSError(
                domain: "APIService",
                code: 429,
                userInfo: [NSLocalizedDescriptionKey: "超過速率限制，請稍後再試"]
            )

        case 400:
            // 請求錯誤
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NSError(
                    domain: "APIService",
                    code: 400,
                    userInfo: [NSLocalizedDescriptionKey: apiError.message]
                )
            }
            throw NSError(
                domain: "APIService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "請求參數錯誤"]
            )

        default:
            // 其他錯誤
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw NSError(
                    domain: "APIService",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: apiError.message]
                )
            }
            throw NSError(
                domain: "APIService",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "伺服器錯誤 (\(httpResponse.statusCode))"]
            )
        }
    }

    /// 測試用：模擬 API 回應
    func mockScanImage(_ image: UIImage) async throws -> ScanResponse {
        // 模擬網路延遲
        try await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 秒

        // 生成當前日期時間
        let now = Date()
        let dateFormatter = DateFormatter()

        // 年份
        dateFormatter.dateFormat = "yyyy"
        let currentYear = dateFormatter.string(from: now)

        // 月日
        dateFormatter.dateFormat = "MM-dd"
        let currentMonthDay = dateFormatter.string(from: now)

        // 時間
        dateFormatter.dateFormat = "HH:mm"
        let currentTime = dateFormatter.string(from: now)

        // 隨機返回不同類型的數據
        let mockTypes: [ScanResponse] = [
            // 血壓計 - 正常血壓（有年份）
            ScanResponse(
                success: true,
                deviceType: "blood_pressure",
                bloodPressure: BloodPressureData(
                    systolic: 120,
                    diastolic: 80,
                    pulse: 72
                ),
                bodyMeasurement: nil,
                bloodGlucose: nil,
                year: currentYear,
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_abc123.png",
                rawText: "SYS: 120 DIA: 80 PULSE: 72",
                error: nil,
                message: "成功識別血壓數據"
            ),
            // 血壓計 - 偏高血壓（無年份，應該使用今年）
            ScanResponse(
                success: true,
                deviceType: "blood_pressure",
                bloodPressure: BloodPressureData(
                    systolic: 135,
                    diastolic: 88,
                    pulse: 78
                ),
                bodyMeasurement: nil,
                bloodGlucose: nil,
                year: nil, // 測試無年份的情況
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_def456.png",
                rawText: "SYS: 135 DIA: 88 PULSE: 78",
                error: nil,
                message: "成功識別血壓數據"
            ),
            // 血壓計 - 隨機值
            ScanResponse(
                success: true,
                deviceType: "blood_pressure",
                bloodPressure: BloodPressureData(
                    systolic: Double.random(in: 110...140),
                    diastolic: Double.random(in: 70...90),
                    pulse: Double.random(in: 60...85)
                ),
                bodyMeasurement: nil,
                bloodGlucose: nil,
                year: currentYear,
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_ghi789.png",
                rawText: "模擬 OCR 文本",
                error: nil,
                message: "成功識別血壓數據"
            ),
            // 身高體重計
            ScanResponse(
                success: true,
                deviceType: "body_measurement",
                bloodPressure: nil,
                bodyMeasurement: BodyMeasurementData(
                    height: Double.random(in: 150...180),
                    heightUnit: "cm",
                    weight: Double.random(in: 50...90),
                    weightUnit: "kg"
                ),
                bloodGlucose: nil,
                year: currentYear,
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_jkl012.png",
                rawText: "模擬 OCR 文本",
                error: nil,
                message: "成功識別身體測量數據"
            ),
            // 血糖計 - 正常空腹血糖 (mg/dL)
            ScanResponse(
                success: true,
                deviceType: "blood_glucose",
                bloodPressure: nil,
                bodyMeasurement: nil,
                bloodGlucose: BloodGlucoseData(
                    glucose: 95,
                    unit: "mg/dL",
                    measurementType: "fasting"
                ),
                year: currentYear,
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_mno345.png",
                rawText: "GLU: 95 mg/dL",
                error: nil,
                message: "成功識別血糖數據"
            ),
            // 血糖計 - 偏高餐後血糖 (mg/dL)
            ScanResponse(
                success: true,
                deviceType: "blood_glucose",
                bloodPressure: nil,
                bodyMeasurement: nil,
                bloodGlucose: BloodGlucoseData(
                    glucose: 145,
                    unit: "mg/dL",
                    measurementType: "postprandial"
                ),
                year: currentYear,
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_pqr678.png",
                rawText: "GLU: 145 mg/dL (餐後)",
                error: nil,
                message: "成功識別血糖數據"
            ),
            // 血糖計 - mmol/L 單位
            ScanResponse(
                success: true,
                deviceType: "blood_glucose",
                bloodPressure: nil,
                bodyMeasurement: nil,
                bloodGlucose: BloodGlucoseData(
                    glucose: Double.random(in: 4.0...7.0),
                    unit: "mmol/L",
                    measurementType: "random"
                ),
                year: currentYear,
                monthday: currentMonthDay,
                time: currentTime,
                imageUrl: "https://pub-80f324273afb494bb00b9dbbd5d970a1.r2.dev/TW_stu901.png",
                rawText: "模擬 OCR 文本",
                error: nil,
                message: "成功識別血糖數據"
            )
        ]

        return mockTypes.randomElement()!
    }

    /// 縮小圖片尺寸以減少上傳大小
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size

        // 如果圖片已經夠小，直接返回
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }

        // 計算縮放比例
        let scale = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // 使用高質量的圖片渲染器縮放圖片
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }

        return resizedImage
    }
}
