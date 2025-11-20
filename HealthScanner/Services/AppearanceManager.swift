//
//  AppearanceManager.swift
//  HealthScanner
//
//  Created on 2025-10-31
//

import Foundation
import SwiftUI
import Combine

/// 外观模式管理器
class AppearanceManager: ObservableObject {
    static let shared = AppearanceManager()

    @Published var currentMode: AppearanceMode = .system

    private init() {
        // 从 UserDefaults 读取保存的设置
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.currentMode = AppearanceMode(rawValue: savedMode) ?? .system
    }

    /// 更新外观模式并保存
    func updateMode(_ mode: AppearanceMode) {
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "appearanceMode")
        applyAppearance()
    }

    /// 应用外观模式
    func applyAppearance() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        for window in windowScene.windows {
            switch currentMode {
            case .system:
                window.overrideUserInterfaceStyle = .unspecified
            case .light:
                window.overrideUserInterfaceStyle = .light
            case .dark:
                window.overrideUserInterfaceStyle = .dark
            }
        }
    }
}

/// 外观模式枚举
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "settings.appearance.system".localized
        case .light:
            return "settings.appearance.light".localized
        case .dark:
            return "settings.appearance.dark".localized
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }
}
