//
//  LocalizationHelper.swift
//  HealthScanner
//
//  Created on 2025-10-27
//

import Foundation

// MARK: - Localization Helper
extension String {
    /// 本地化字符串的便捷方法
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }

    /// 带参数的本地化字符串
    func localized(_ arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}
