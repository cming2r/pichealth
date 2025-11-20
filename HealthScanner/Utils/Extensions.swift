//
//  Extensions.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation
import SwiftUI

// MARK: - Date Extensions

extension Date {
    /// 格式化為友善的時間字串
    func toFriendlyString() -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(self) {
            return "今天 " + self.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(self) {
            return "昨天 " + self.formatted(date: .omitted, time: .shortened)
        } else {
            return self.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

// MARK: - Color Extensions

extension Color {
    /// 根據健康數據類型返回顏色
    static func color(for type: HealthDataType) -> Color {
        switch type {
        case .weight:
            return .blue
        case .height:
            return .green
        case .bloodPressure:
            return .red
        case .heartRate:
            return .pink
        case .bloodSugar:
            return .orange
        case .bodyTemperature:
            return .purple
        }
    }
}

// MARK: - Double Extensions

extension Double {
    /// 格式化為指定小數位數的字串
    func formatted(decimalPlaces: Int) -> String {
        String(format: "%.\(decimalPlaces)f", self)
    }
}
