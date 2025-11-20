//
//  HistoryView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var storageService: StorageService
    @State private var selectedType: HealthDataType?
    @State private var showingDetail = false
    @State private var selectedRecord: HealthRecord?
    @State private var syncingRecordId: UUID?
    @State private var showSyncError = false
    @State private var syncErrorMessage = ""

    var filteredRecords: [HealthRecord] {
        let records = if let type = selectedType {
            storageService.records.filter { $0.type == type }
        } else {
            storageService.records
        }

        // 按時間降序排序（最新的在上面）
        return records.sorted { $0.timestamp > $1.timestamp }
    }

    // 按日期分組的紀錄
    var groupedRecords: [(date: String, records: [HealthRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: filteredRecords) { record -> String in
            let components = calendar.dateComponents([.year, .month, .day], from: record.timestamp)
            if let date = calendar.date(from: components) {
                return formatDateForSection(date)
            }
            return ""
        }

        // 按日期排序（最新的在上面）
        return grouped.sorted { parseDate($0.key) > parseDate($1.key) }
            .map { (date: $0.key, records: $0.value.sorted { $0.timestamp > $1.timestamp }) }
    }

    // 格式化日期為 Section 標題
    private func formatDateForSection(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current

        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "today".localized
        } else if calendar.isDateInYesterday(date) {
            return "yesterday".localized
        } else {
            return formatter.string(from: date)
        }
    }

    // 解析日期字串用於排序
    private func parseDate(_ dateString: String) -> Date {
        // 特殊處理「今天」和「昨天」
        if dateString == "today".localized {
            return Date()
        } else if dateString == "yesterday".localized {
            return Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter.date(from: dateString) ?? Date.distantPast
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 篩選器
                HStack(spacing: 12) {
                    Spacer()

                    // 全部按鈕
                    FilterChip(
                        title: "history.filter.all".localized,
                        isSelected: selectedType == nil,
                        action: { selectedType = nil }
                    )

                    // 下拉式選單
                    Menu {
                        ForEach(HealthDataType.allCases, id: \.self) { type in
                            Button(action: {
                                selectedType = type
                            }) {
                                HStack {
                                    Image(systemName: type.icon)
                                    Text(type.displayName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            if let type = selectedType {
                                Image(systemName: type.icon)
                                    .font(.caption)
                                Text(type.displayName)
                                    .font(.subheadline)
                            } else {
                                Image(systemName: "line.3.horizontal.decrease.circle")
                                    .font(.caption)
                                Text("history.filter.select".localized)
                                    .font(.subheadline)
                            }
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedType != nil ? Color.blue : Color(.systemGray5))
                        .foregroundColor(selectedType != nil ? .white : .primary)
                        .cornerRadius(20)
                    }

                    Spacer()
                }
                .padding()
                .background(Color(.systemBackground))

                Divider()

                // 紀錄列表
                if filteredRecords.isEmpty {
                    emptyView
                } else {
                    List {
                        ForEach(groupedRecords, id: \.date) { group in
                            Section(header: Text(group.date).font(.headline)) {
                                ForEach(group.records) { record in
                                    HistoryRowView(
                                        record: record,
                                        isSyncing: syncingRecordId == record.id,
                                        onSync: {
                                            syncRecord(record)
                                        }
                                    )
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedRecord = record
                                        showingDetail = true
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteRecordsInGroup(group: group, at: indexSet)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("history.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selectedRecord) { record in
                RecordDetailView(record: record)
            }
            .alert("同步失敗", isPresented: $showSyncError) {
                Button("確定", role: .cancel) { }
            } message: {
                Text(syncErrorMessage)
            }
            .onAppear {
                storageService.fetchRecords()
                // 驗證同步狀態
                Task {
                    await storageService.verifySyncStatus()
                }
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            Text("history.empty.title".localized)
                .font(.headline)
                .foregroundColor(.secondary)

            Text("history.empty.message".localized)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func deleteRecordsInGroup(group: (date: String, records: [HealthRecord]), at offsets: IndexSet) {
        Task {
            for index in offsets {
                let record = group.records[index]
                do {
                    try await storageService.deleteRecord(record)
                } catch {
                    print("刪除紀錄失敗: \(error.localizedDescription)")
                }
            }
        }
    }

    private func syncRecord(_ record: HealthRecord) {
        // 設定正在同步的紀錄 ID
        syncingRecordId = record.id

        Task {
            do {
                try await storageService.resyncRecord(record)
                // 同步成功，清除同步狀態
                syncingRecordId = nil
            } catch {
                // 同步失敗，顯示錯誤訊息
                syncingRecordId = nil
                syncErrorMessage = error.localizedDescription
                showSyncError = true
            }
        }
    }
}

/// 篩選 Chip
struct FilterChip: View {
    let title: String
    var icon: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.subheadline)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(20)
        }
    }
}

/// 歷史紀錄行
struct HistoryRowView: View {
    let record: HealthRecord
    var isSyncing: Bool = false
    var onSync: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            // 圖標
            Image(systemName: record.type.icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            // 內容
            VStack(alignment: .leading, spacing: 4) {
                Text(record.type.displayName)
                    .font(.headline)

                Text(record.formattedValue)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(record.timestamp, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 同步狀態或按鈕
            if record.isSyncedToHealthKit {
                // 已同步：顯示綠色打勾
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                // 未同步：顯示同步按鈕
                Button(action: {
                    onSync?()
                }) {
                    HStack(spacing: 4) {
                        if isSyncing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                        }
                        Text("同步")
                            .font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(isSyncing)
            }
        }
        .padding(.vertical, 8)
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
}

#Preview {
    HistoryView()
        .environmentObject(StorageService())
}
