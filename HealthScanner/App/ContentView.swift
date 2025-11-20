//
//  ContentView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 1

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

                // 掃描頁面
                ScanView()
                    .tabItem {
                        Label("tab.scan".localized, systemImage: "camera.fill")
                    }
                    .tag(1)
                    .environment(\.selectedTab, $selectedTab)

                // 設定
                SettingsView()
                    .tabItem {
                        Label("tab.settings".localized, systemImage: "gearshape.fill")
                    }
                    .tag(2)
                    .environment(\.selectedTab, $selectedTab)
            }

            // 廣告橫幅（緊貼在 Tab Bar 上方）
            VStack(spacing: 0) {
                Spacer()
                AdMobBannerContainer()
                    .background(Color(.systemBackground))
                // 预留 Tab Bar 的高度空间
                Color.clear
                    .frame(height: 49) // Tab Bar 的标准高度
            }
            .ignoresSafeArea(.keyboard) // 避免键盘弹出时的影响
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
