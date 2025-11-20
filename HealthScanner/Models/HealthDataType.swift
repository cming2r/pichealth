//
//  HealthDataType.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation

/// 健康數據類型
enum HealthDataType: String, Codable, CaseIterable {
    case weight = "體重"
    case height = "身高"
    case bloodPressure = "血壓"
    case heartRate = "心率"
    case bloodSugar = "血糖"
    case bodyTemperature = "體溫"

    /// 顯示名稱（本地化）
    var displayName: String {
        switch self {
        case .weight:
            return "health.weight".localized
        case .height:
            return "health.height".localized
        case .bloodPressure:
            return "health.bloodPressure".localized
        case .heartRate:
            return "health.heartRate".localized
        case .bloodSugar:
            return "health.bloodSugar".localized
        case .bodyTemperature:
            return "health.bodyTemperature".localized
        }
    }

    var icon: String {
        switch self {
        case .weight:
            return "scalemass.fill"
        case .height:
            return "ruler.fill"
        case .bloodPressure:
            return "heart.text.square.fill"
        case .heartRate:
            return "heart.fill"
        case .bloodSugar:
            return "drop.fill"
        case .bodyTemperature:
            return "thermometer"
        }
    }

    var unit: String {
        switch self {
        case .weight:
            return "kg"
        case .height:
            return "cm"
        case .bloodPressure:
            return "mmHg"
        case .heartRate:
            return "bpm"
        case .bloodSugar:
            return "mg/dL"
        case .bodyTemperature:
            return "°C"
        }
    }
}
