//
//  StorageService.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation
import SwiftData
import Combine

/// 本機儲存服務 - 使用 SwiftData 管理本機數據
@MainActor
class StorageService: ObservableObject {
    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    @Published var records: [HealthRecord] = []

    // HealthKit 服務引用（用於刪除時同步刪除 HealthKit 數據）
    weak var healthKitService: HealthKitService?

    // 最近同步的紀錄 ID 集合（用於避免立即驗證剛同步的紀錄）
    private var recentlySyncedRecordIds: Set<UUID> = []

    init() {
        setupContainer()
    }

    /// 設定 SwiftData 容器
    private func setupContainer() {
        do {
            let schema = Schema([HealthRecord.self])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])

            if let container = modelContainer {
                modelContext = ModelContext(container)
                fetchRecords()
            }
        } catch {
            print("無法建立 ModelContainer: \(error)")
        }
    }

    /// 儲存紀錄
    func saveRecord(_ record: HealthRecord) throws {
        guard let context = modelContext else {
            throw NSError(domain: "Storage", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext 未初始化"])
        }

        context.insert(record)
        try context.save()
        fetchRecords()
    }

    /// 更新紀錄
    func updateRecord(_ record: HealthRecord) throws {
        guard let context = modelContext else {
            throw NSError(domain: "Storage", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext 未初始化"])
        }

        try context.save()
        fetchRecords()
    }

    /// 刪除紀錄（同時刪除本機和 HealthKit 數據）
    func deleteRecord(_ record: HealthRecord) async throws {
        guard let context = modelContext else {
            throw NSError(domain: "Storage", code: 1, userInfo: [NSLocalizedDescriptionKey: "ModelContext 未初始化"])
        }

        // 如果紀錄已同步到 HealthKit，先從 HealthKit 刪除
        if record.isSyncedToHealthKit, let healthKitService = healthKitService {
            do {
                try await healthKitService.deleteHealthRecord(record)
            } catch {
                // HealthKit 刪除失敗時紀錄錯誤，但仍繼續刪除本機紀錄
                print("從 HealthKit 刪除紀錄失敗: \(error.localizedDescription)")
            }
        }

        // 刪除本機紀錄
        context.delete(record)
        try context.save()
        fetchRecords()
    }

    /// 取得所有紀錄
    func fetchRecords() {
        guard let context = modelContext else { return }

        let descriptor = FetchDescriptor<HealthRecord>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )

        do {
            records = try context.fetch(descriptor)
        } catch {
            print("無法讀取紀錄: \(error)")
            records = []
        }
    }

    /// 取得特定類型的紀錄
    func fetchRecords(ofType type: HealthDataType) -> [HealthRecord] {
        records.filter { $0.type == type }
    }

    /// 取得最近 N 筆紀錄
    func fetchRecentRecords(limit: Int) -> [HealthRecord] {
        Array(records.prefix(limit))
    }

    /// 驗證所有紀錄的同步狀態
    /// 檢查標記為「已同步」的紀錄是否仍存在於 HealthKit，若不存在則改為「未同步」
    func verifySyncStatus() async {
        guard let healthKitService = healthKitService else {
            print("HealthKitService 未設定")
            return
        }

        var needsUpdate = false

        for record in records {
            // 跳過剛剛同步的紀錄（避免競態問題）
            if recentlySyncedRecordIds.contains(record.id) {
                print("跳過檢查剛同步的紀錄: \(record.id)")
                continue
            }

            // 只檢查標記為已同步的紀錄
            if record.isSyncedToHealthKit {
                let exists = await healthKitService.checkRecordExistsInHealthKit(record)

                // 如果在 HealthKit 中找不到，將其標記為未同步
                if !exists {
                    print("紀錄 \(record.id) 在 HealthKit 中已不存在，標記為未同步")
                    record.isSyncedToHealthKit = false
                    needsUpdate = true
                }
            }
        }

        // 如果有變更，儲存並重新載入
        if needsUpdate {
            do {
                try modelContext?.save()
                fetchRecords()
            } catch {
                print("更新同步狀態時發生錯誤: \(error.localizedDescription)")
            }
        }
    }

    /// 重新同步單一紀錄到 HealthKit
    /// 適用於之前未成功同步的紀錄
    func resyncRecord(_ record: HealthRecord) async throws {
        guard let healthKitService = healthKitService else {
            throw NSError(domain: "Storage", code: 2, userInfo: [NSLocalizedDescriptionKey: "HealthKitService 未設定"])
        }

        // 嘗試保存到 HealthKit
        try await healthKitService.saveHealthRecord(record)

        // 保存成功後，標記為已同步
        record.isSyncedToHealthKit = true

        // 將此紀錄加入最近同步的集合（避免立即被驗證）
        recentlySyncedRecordIds.insert(record.id)

        // 5 秒後從集合中移除（給 HealthKit 足夠的時間完成寫入）
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 秒
            recentlySyncedRecordIds.remove(record.id)
            print("已從最近同步集合中移除紀錄: \(record.id)")
        }

        // 儲存更新
        try modelContext?.save()
        fetchRecords()
    }
}
