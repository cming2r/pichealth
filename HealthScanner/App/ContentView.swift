//
//  ContentView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1
    @State private var adRefreshID = UUID().uuidString

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // 歷史紀錄
                HistoryView()
                    .tabItem {
                        Label("tab.records".localized, systemImage: "list.bullet")
                    }
                    .tag(0)
                    .environment(\.selectedTab, $selectedTab)
                    .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)

                // 掃描頁面
                ScanView()
                    .tabItem {
                        Label("tab.scan".localized, systemImage: "camera.fill")
                    }
                    .tag(1)
                    .environment(\.selectedTab, $selectedTab)
                    .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)

                // 設定
                SettingsView()
                    .tabItem {
                        Label("tab.settings".localized, systemImage: "gearshape.fill")
                    }
                    .tag(2)
                    .environment(\.selectedTab, $selectedTab)
                    .toolbarBackground(Color(uiColor: .systemBackground), for: .tabBar)
                    .toolbarBackground(.visible, for: .tabBar)
            }

            // 廣告橫幅（緊貼在 Tab Bar 上方）
            VStack(spacing: 0) {
                Spacer()
                AdMobBannerContainer(refreshID: adRefreshID)
                    .padding(.bottom, 49) // Tab Bar 的標準高度
            }
            .ignoresSafeArea(.keyboard)
        }
        .onChange(of: selectedTab) {
            // 切換 tab 時重新載入廣告
            adRefreshID = UUID().uuidString
        }
    }
}

// 環境變數：用於切換 Tab
struct SelectedTabKey: EnvironmentKey {
    static let defaultValue: Binding<Int>? = nil
}

extension EnvironmentValues {
    var selectedTab: Binding<Int>? {
        get { self[SelectedTabKey.self] }
        set { self[SelectedTabKey.self] = newValue }
    }
}

#Preview {
    ContentView()
        .environmentObject(HealthKitService())
        .environmentObject(StorageService())
}
