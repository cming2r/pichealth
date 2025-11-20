//
//  HealthScannerApp.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI
import GoogleMobileAds

@main
struct HealthScannerApp: App {
    // 初始化 HealthKit 服務
    @StateObject private var healthKitService = HealthKitService()
    @StateObject private var storageService = StorageService()
    @StateObject private var appearanceManager = AppearanceManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitService)
                .environmentObject(storageService)
                .onAppear {
                    // 初始化 Google Mobile Ads SDK
                    MobileAds.shared.start()

                    // 應用外觀模式
                    appearanceManager.applyAppearance()

                    // 設置 StorageService 的 HealthKitService 引用
                    storageService.healthKitService = healthKitService

                    // 初始化裝置識別碼（確保 Keychain 中有 ID）
                    _ = DeviceIdentifierService.shared.deviceIdentifier

                    // 請求 HealthKit 權限
                    healthKitService.requestAuthorization()
                }
        }
    }
}
