//
//  HealthPermissionGuideView.swift
//  HealthScanner
//
//  Created on 2025-10-21
//

import SwiftUI

/// 健康 App 權限設定指南頁面
struct HealthPermissionGuideView: View {
    @EnvironmentObject var healthKitService: HealthKitService

    var body: some View {
        List {
            // 設定步驟
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    StepView(
                        number: 1,
                        title: "permission.step1.title".localized
                    )

                    Divider()

                    StepView(
                        number: 2,
                        title: "permission.step2.title".localized
                    )

                    Divider()

                    StepView(
                        number: 3,
                        title: "permission.step3.title".localized
                    )

                    Divider()

                    StepView(
                        number: 4,
                        title: "permission.step4.title".localized
                    )

                    Divider()

                    StepView(
                        number: 5,
                        title: "permission.step5.title".localized
                    )
                }
                .padding(.vertical, 8)
            } header: {
                Text("permission.steps.header".localized)
            } footer: {
                Text("permission.steps.footer".localized)
            }

            // 快速操作
            Section {
                Button(action: {
                    openHealthPermissionSettings()
                }) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.pink)
                        Text("permission.quickAction".localized)
                            .foregroundColor(.blue)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("permission.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 開啟健康權限設定
    private func openHealthPermissionSettings() {
        // 先嘗試請求授權（如果是第一次，會彈出對話框）
        healthKitService.requestAuthorization()

        // 延遲一點，給時間顯示授權對話框
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 無論授權對話框是否顯示，都打開健康 App
            // 用戶可以在健康 App 中手動設定權限
            openHealthApp()
        }
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
                    print("✅ 已打開健康 App")
                    return
                }
            }
        }

        print("❌ 無法打開健康 App")
    }
}

/// 步驟視圖組件
struct StepView: View {
    let number: Int
    let title: String
    let description: String?

    init(number: Int, title: String, description: String? = nil) {
        self.number = number
        self.title = title
        self.description = description
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 步驟編號
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 28, height: 28)
                Text("\(number)")
                    .font(.system(.subheadline, design: .rounded))
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // 步驟內容
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

#Preview {
    NavigationStack {
        HealthPermissionGuideView()
            .environmentObject(HealthKitService())
    }
}
