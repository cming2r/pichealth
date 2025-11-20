//
//  AccountView.swift
//  HealthScanner
//
//  Created on 2025-10-21
//

import SwiftUI

/// 帳戶頁面 - 顯示裝置識別碼
struct AccountView: View {
    @State private var showingFullID = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("account.identifier".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    HStack {
                        Text(showingFullID ? DeviceIdentifierService.shared.deviceIdentifier : DeviceIdentifierService.shared.shortIdentifier + "...")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)

                        Spacer()

                        Button(action: {
                            showingFullID.toggle()
                        }) {
                            Image(systemName: showingFullID ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            UIPasteboard.general.string = DeviceIdentifierService.shared.deviceIdentifier
                        }) {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            } footer: {
                Text("account.footer".localized)
            }
        }
        .navigationTitle("account.title".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        AccountView()
    }
}
