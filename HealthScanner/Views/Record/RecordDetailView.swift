//
//  RecordDetailView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI

struct RecordDetailView: View {
    let record: HealthRecord
    @Environment(\.dismiss) var dismiss
    @State private var loadedImage: UIImage? = nil
    @State private var isLoadingImage = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 圖標和類型
                    VStack(spacing: 12) {
                        Image(systemName: record.type.icon)
                            .font(.system(size: 60))
                            .foregroundColor(iconColor)

                        Text(record.type.displayName)
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding()

                    // 數值
                    VStack(spacing: 8) {
                        Text("record.value".localized)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Text(record.formattedValue)
                            .font(.system(size: 36, weight: .bold))
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 詳細資訊
                    VStack(alignment: .leading, spacing: 16) {
                        Text("record.details".localized)
                            .font(.headline)

                        InfoRow(label: "record.time".localized, value: record.timestamp.formatted(date: .long, time: .shortened))

                        if record.type == .bloodPressure {
                            if let systolic = record.systolic {
                                InfoRow(label: "health.systolic".localized, value: "\(Int(systolic)) mmHg")
                            }
                            if let diastolic = record.diastolic {
                                InfoRow(label: "health.diastolic".localized, value: "\(Int(diastolic)) mmHg")
                            }
                        }

                        InfoRow(
                            label: "record.syncStatus".localized,
                            value: record.isSyncedToHealthKit ? "record.synced".localized : "record.notSynced".localized,
                            valueColor: record.isSyncedToHealthKit ? .green : .secondary
                        )

                        if let notes = record.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("record.notes".localized)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)

                                Text(notes)
                                    .font(.body)
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // 照片
                    if let imageUrl = record.imageUrl {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("record.photo".localized)
                                .font(.headline)

                            if isLoadingImage {
                                ProgressView()
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            } else if let loadedImage = loadedImage {
                                Image(uiImage: loadedImage)
                                    .resizable()
                                    .scaledToFit()
                                    .cornerRadius(12)
                                    .shadow(radius: 3)
                            } else {
                                Text("無法載入圖片")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 200)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .onAppear {
                            loadImageFromURL(imageUrl)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("record.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("record.done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }

    private var iconColor: Color {
        switch record.type {
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

    /// 從 URL 載入圖片
    private func loadImageFromURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            return
        }

        isLoadingImage = true

        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        self.loadedImage = image
                        self.isLoadingImage = false
                    }
                } else {
                    await MainActor.run {
                        self.isLoadingImage = false
                    }
                }
            } catch {
                print("載入圖片失敗: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoadingImage = false
                }
            }
        }
    }
}

/// 資訊行
struct InfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundColor(valueColor)
        }
    }
}

#Preview {
    RecordDetailView(
        record: HealthRecord(
            type: .bloodPressure,
            value: 120,
            systolic: 120,
            diastolic: 80,
            timestamp: Date(),
            notes: "早上量測",
            isSyncedToHealthKit: true
        )
    )
}
