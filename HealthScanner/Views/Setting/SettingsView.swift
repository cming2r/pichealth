//
//  SettingsView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var storageService: StorageService
    @StateObject private var appearanceManager = AppearanceManager.shared

    @State private var unauthorizedTypes: [HealthDataType] = []
    @State private var shouldNavigateToPermissions = false

    var body: some View {
        NavigationStack {
            List {
                // 外觀模式
                Section {
                    Picker("settings.appearance".localized, selection: $appearanceManager.currentMode) {
                        ForEach(AppearanceMode.allCases) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.displayName)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    .onChange(of: appearanceManager.currentMode) { _, newValue in
                        appearanceManager.updateMode(newValue)
                    }
                }

                // 權限設定
                Section {
                    NavigationLink {
                        HealthPermissionGuideView()
                    } label: {
                        HStack {
                            Text("settings.permissions".localized)
                            Spacer()
                            if !unauthorizedTypes.isEmpty {
                                HStack(spacing: 4) {
                                    Text("settings.permissions.needed".localized)
                                        .font(.subheadline)
                                        .foregroundColor(.orange)
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                }
                            }
                        }
                    }
                } footer: {
                    if unauthorizedTypes.isEmpty {
                        Text("settings.permissions.footer.authorized".localized)
                    } else {
                        Text("settings.permissions.footer.unauthorized".localized)
                    }
                }

                // 數據統計
                Section {
                    HStack {
                        Text("settings.totalRecords".localized)
                        Spacer()
                        Text("\(storageService.records.count)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("settings.syncedRecords".localized)
                        Spacer()
                        Text("\(storageService.records.filter { $0.isSyncedToHealthKit }.count)")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("settings.statistics".localized)
                }

                // 健康 App
                Section {
                    Button(action: {
                        openHealthApp()
                    }) {
                        HStack {
                            Text("settings.openHealthApp".localized)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("settings.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(isPresented: $shouldNavigateToPermissions) {
                HealthPermissionGuideView()
            }
            .onAppear {
                checkPermissions()
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateToHealthPermissions)) { _ in
                // 收到導航通知，自動展開權限設定頁面
                shouldNavigateToPermissions = true
            }
        }
    }

    /// 檢查權限狀態
    private func checkPermissions() {
        unauthorizedTypes = healthKitService.getUnauthorizedTypes()
    }

    /// 打開健康 App
    private func openHealthApp() {
        // 嘗試打開健康 App 的不同 URL scheme
        let urls = [
            "x-apple-health://",  // 直接打開健康 App
            UIApplication.openSettingsURLString  // 備用：打開系統設定
        ]

        for urlString in urls {
            if let url = URL(string: urlString) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                    return
                }
            }
        }
    }
}

// 定義通知名稱
extension Notification.Name {
    static let navigateToHealthPermissions = Notification.Name("navigateToHealthPermissions")
}

#Preview {
    SettingsView()
        .environmentObject(HealthKitService())
        .environmentObject(StorageService())
}
