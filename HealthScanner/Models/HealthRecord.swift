//
//  HealthRecord.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation
import SwiftData

/// 健康紀錄數據模型（本機儲存）
@Model
final class HealthRecord {
    var id: UUID
    var type: HealthDataType
    var value: Double
    var systolic: Double? // 收縮壓（血壓專用）
    var diastolic: Double? // 舒張壓（血壓專用）
    var timestamp: Date
    var imageUrl: String? // 圖片 URL（來自 API）
    var notes: String?
    var isSyncedToHealthKit: Bool

    init(
        id: UUID = UUID(),
        type: HealthDataType,
        value: Double,
        systolic: Double? = nil,
        diastolic: Double? = nil,
        timestamp: Date = Date(),
        imageUrl: String? = nil,
        notes: String? = nil,
        isSyncedToHealthKit: Bool = false
    ) {
        self.id = id
        self.type = type
        self.value = value
        self.systolic = systolic
        self.diastolic = diastolic
        self.timestamp = timestamp
        self.imageUrl = imageUrl
        self.notes = notes
        self.isSyncedToHealthKit = isSyncedToHealthKit
    }

    /// 顯示格式化的值
    var formattedValue: String {
        switch type {
        case .bloodPressure:
            if let sys = systolic, let dia = diastolic {
                return "\(Int(sys))/\(Int(dia)) \(type.unit)"
            }
            return "N/A"
        default:
            return String(format: "%.1f %@", value, type.unit)
        }
    }
}
