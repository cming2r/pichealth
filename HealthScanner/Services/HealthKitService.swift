//
//  HealthKitService.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import Foundation
import HealthKit
import Combine

/// HealthKit 服務 - 處理與 Apple 健康 app 的整合
class HealthKitService: ObservableObject {
    private let healthStore = HKHealthStore()
    @Published var isAuthorized = false

    /// 檢查 HealthKit 是否可用
    var isHealthKitAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    /// 定義需要的健康數據類型
    private var healthTypesToRead: Set<HKSampleType> {
        let types: [HKSampleType] = [
            HKObjectType.quantityType(forIdentifier: .bodyMass)!,
            HKObjectType.quantityType(forIdentifier: .height)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodGlucose)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!
        ]
        // 注意：不能將 .bloodPressure correlation type 加入授權請求
        // Apple 不允許對 correlation type 直接授權
        // 必須對組成 correlation 的各個類型授權（systolic, diastolic）
        return Set(types)
    }

    private var healthTypesToWrite: Set<HKSampleType> {
        healthTypesToRead
    }

    /// 請求 HealthKit 授權
    func requestAuthorization() {
        guard isHealthKitAvailable else {
            print("HealthKit 不可用")
            return
        }

        healthStore.requestAuthorization(toShare: healthTypesToWrite, read: healthTypesToRead) { [weak self] success, error in
            DispatchQueue.main.async {
                // 注意：HealthKit 的 success 不代表用戶授權所有項目
                // 只要用戶沒有完全拒絕就會返回 true
                // 實際的授權狀態需要在寫入時才能確定
                self?.isAuthorized = success

                if let error = error {
                    print("HealthKit 授權錯誤: \(error.localizedDescription)")
                    self?.isAuthorized = false
                } else if success {
                    // 如果沒有錯誤且返回成功，設置為已授權
                    self?.isAuthorized = true
                    print("HealthKit 授權請求已發送")
                }
            }
        }
    }

    /// 請求特定類型的授權（例如血壓）
    func requestAuthorizationFor(types: [HealthDataType]) async throws {
        guard isHealthKitAvailable else {
            throw NSError(domain: "HealthKit", code: 0, userInfo: [NSLocalizedDescriptionKey: "HealthKit 不可用"])
        }

        var typesToShare: Set<HKSampleType> = []

        for type in types {
            switch type {
            case .bloodPressure:
                // 血壓需要兩個類型
                if let systolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
                   let diastolic = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) {
                    typesToShare.insert(systolic)
                    typesToShare.insert(diastolic)
                }
            case .weight:
                if let type = HKObjectType.quantityType(forIdentifier: .bodyMass) {
                    typesToShare.insert(type)
                }
            case .height:
                if let type = HKObjectType.quantityType(forIdentifier: .height) {
                    typesToShare.insert(type)
                }
            case .heartRate:
                if let type = HKObjectType.quantityType(forIdentifier: .heartRate) {
                    typesToShare.insert(type)
                }
            case .bloodSugar:
                if let type = HKObjectType.quantityType(forIdentifier: .bloodGlucose) {
                    typesToShare.insert(type)
                }
            case .bodyTemperature:
                if let type = HKObjectType.quantityType(forIdentifier: .bodyTemperature) {
                    typesToShare.insert(type)
                }
            }
        }

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: typesToShare, read: typesToShare) { success, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    /// 檢查特定健康數據類型的授權狀態
    func checkAuthorizationStatus(for type: HealthDataType) -> HKAuthorizationStatus {
        // 血壓需要檢查兩個類型（收縮壓和舒張壓）
        if type == .bloodPressure {
            guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
                  let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
                return .notDetermined
            }

            let systolicStatus = healthStore.authorizationStatus(for: systolicType)
            let diastolicStatus = healthStore.authorizationStatus(for: diastolicType)

            // 兩者都需要授權
            if systolicStatus == .sharingAuthorized && diastolicStatus == .sharingAuthorized {
                return .sharingAuthorized
            } else if systolicStatus == .notDetermined || diastolicStatus == .notDetermined {
                return .notDetermined
            } else {
                return .sharingDenied
            }
        }

        // 其他類型正常處理
        let identifier: HKQuantityTypeIdentifier
        switch type {
        case .weight:
            identifier = .bodyMass
        case .height:
            identifier = .height
        case .heartRate:
            identifier = .heartRate
        case .bloodSugar:
            identifier = .bloodGlucose
        case .bodyTemperature:
            identifier = .bodyTemperature
        case .bloodPressure:
            identifier = .bloodPressureSystolic // 不會執行到這裡
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return .notDetermined
        }

        return healthStore.authorizationStatus(for: quantityType)
    }

    /// 獲取未授權的數據類型列表
    func getUnauthorizedTypes() -> [HealthDataType] {
        let allTypes: [HealthDataType] = [.weight, .height, .bloodPressure, .heartRate, .bloodSugar, .bodyTemperature]

        return allTypes.filter { type in
            let status = checkAuthorizationStatus(for: type)
            // notDetermined 表示尚未請求或用戶拒絕
            // sharingDenied 在寫入時會被返回（隱私保護，讀取時看不到）
            return status == .notDetermined
        }
    }

    /// 儲存健康紀錄到 HealthKit
    func saveHealthRecord(_ record: HealthRecord) async throws {
        guard isAuthorized else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "未授權 HealthKit"])
        }

        switch record.type {
        case .weight:
            try await saveQuantity(
                value: record.value,
                unit: .gramUnit(with: .kilo),
                identifier: .bodyMass,
                date: record.timestamp
            )

        case .height:
            try await saveQuantity(
                value: record.value,
                unit: .meterUnit(with: .centi),
                identifier: .height,
                date: record.timestamp
            )

        case .bloodPressure:
            guard let systolic = record.systolic, let diastolic = record.diastolic else {
                throw NSError(domain: "HealthKit", code: 2, userInfo: [NSLocalizedDescriptionKey: "血壓數據不完整"])
            }
            try await saveBloodPressure(systolic: systolic, diastolic: diastolic, date: record.timestamp)

        case .heartRate:
            try await saveQuantity(
                value: record.value,
                unit: HKUnit.count().unitDivided(by: .minute()),
                identifier: .heartRate,
                date: record.timestamp
            )

        case .bloodSugar:
            try await saveQuantity(
                value: record.value,
                unit: HKUnit.gramUnit(with: .milli).unitDivided(by: .literUnit(with: .deci)),
                identifier: .bloodGlucose,
                date: record.timestamp
            )

        case .bodyTemperature:
            try await saveQuantity(
                value: record.value,
                unit: .degreeCelsius(),
                identifier: .bodyTemperature,
                date: record.timestamp
            )
        }
    }

    /// 儲存一般數值型數據
    private func saveQuantity(value: Double, unit: HKUnit, identifier: HKQuantityTypeIdentifier, date: Date) async throws {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "無效的數據類型"])
        }

        let quantity = HKQuantity(unit: unit, doubleValue: value)
        let sample = HKQuantitySample(type: quantityType, quantity: quantity, start: date, end: date)

        try await healthStore.save(sample)
    }

    /// 儲存血壓數據（需要同時儲存收縮壓和舒張壓）
    private func saveBloodPressure(systolic: Double, diastolic: Double, date: Date) async throws {
        guard let systolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            throw NSError(domain: "HealthKit", code: 4, userInfo: [NSLocalizedDescriptionKey: "無效的血壓類型"])
        }

        // 檢查授權狀態
        let systolicStatus = healthStore.authorizationStatus(for: systolicType)
        let diastolicStatus = healthStore.authorizationStatus(for: diastolicType)

        print("血壓授權狀態 - 收縮壓: \(systolicStatus.rawValue), 舒張壓: \(diastolicStatus.rawValue)")

        // 如果未授權，嘗試請求授權
        if systolicStatus != .sharingAuthorized || diastolicStatus != .sharingAuthorized {
            print("血壓未授權，正在請求授權...")

            do {
                try await requestAuthorizationFor(types: [.bloodPressure])
                print("血壓授權請求已發送")

                // 重新檢查授權狀態
                let newSystolicStatus = healthStore.authorizationStatus(for: systolicType)
                let newDiastolicStatus = healthStore.authorizationStatus(for: diastolicType)

                print("重新檢查授權狀態 - 收縮壓: \(newSystolicStatus.rawValue), 舒張壓: \(newDiastolicStatus.rawValue)")

                // 注意：即使請求了，用戶可能還是沒授權，這時需要提示
                if newSystolicStatus != .sharingAuthorized || newDiastolicStatus != .sharingAuthorized {
                    throw NSError(
                        domain: "HealthKit",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "血壓數據需要授權。請允許寫入「血壓收縮壓」和「血壓舒張壓」權限。"]
                    )
                }
            } catch {
                throw NSError(
                    domain: "HealthKit",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "未授權血壓數據寫入。請到健康 App 中開啟「血壓收縮壓」和「血壓舒張壓」的寫入權限。"]
                )
            }
        }

        let unit = HKUnit.millimeterOfMercury()
        let systolicQuantity = HKQuantity(unit: unit, doubleValue: systolic)
        let diastolicQuantity = HKQuantity(unit: unit, doubleValue: diastolic)

        let systolicSample = HKQuantitySample(type: systolicType, quantity: systolicQuantity, start: date, end: date)
        let diastolicSample = HKQuantitySample(type: diastolicType, quantity: diastolicQuantity, start: date, end: date)

        // 使用 HKCorrelation 將收縮壓和舒張壓關聯在一起
        // 這樣健康 App 才會將它們視為一筆完整的血壓紀錄
        guard let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            throw NSError(domain: "HealthKit", code: 7, userInfo: [NSLocalizedDescriptionKey: "無法建立血壓關聯類型"])
        }

        let bloodPressureCorrelation = HKCorrelation(
            type: bloodPressureType,
            start: date,
            end: date,
            objects: Set([systolicSample, diastolicSample])
        )

        do {
            try await healthStore.save(bloodPressureCorrelation)
            print("血壓儲存成功 - 收縮壓: \(systolic), 舒張壓: \(diastolic)")
        } catch {
            print("血壓儲存失敗: \(error.localizedDescription)")
            throw NSError(
                domain: "HealthKit",
                code: 6,
                userInfo: [NSLocalizedDescriptionKey: "血壓儲存失敗：\(error.localizedDescription)。請確認已在健康 App 中開啟血壓相關權限。"]
            )
        }
    }

    /// 刪除健康紀錄從 HealthKit
    func deleteHealthRecord(_ record: HealthRecord) async throws {
        guard isAuthorized else {
            throw NSError(domain: "HealthKit", code: 1, userInfo: [NSLocalizedDescriptionKey: "未授權 HealthKit"])
        }

        // 只刪除已同步到 HealthKit 的紀錄
        guard record.isSyncedToHealthKit else {
            return
        }

        switch record.type {
        case .bloodPressure:
            // 血壓儲存為 HKCorrelation，需要刪除 correlation 而不是單獨的樣本
            try await deleteBloodPressureCorrelation(timestamp: record.timestamp)

        case .weight:
            try await deleteSample(identifier: .bodyMass, timestamp: record.timestamp)

        case .height:
            try await deleteSample(identifier: .height, timestamp: record.timestamp)

        case .heartRate:
            try await deleteSample(identifier: .heartRate, timestamp: record.timestamp)

        case .bloodSugar:
            try await deleteSample(identifier: .bloodGlucose, timestamp: record.timestamp)

        case .bodyTemperature:
            try await deleteSample(identifier: .bodyTemperature, timestamp: record.timestamp)
        }
    }

    /// 刪除血壓 Correlation 及其包含的樣本
    private func deleteBloodPressureCorrelation(timestamp: Date) async throws {
        guard let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
            throw NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "無效的血壓類型"])
        }

        // 建立時間範圍查詢條件（前後 2 秒內的數據）
        let startDate = timestamp.addingTimeInterval(-2)
        let endDate = timestamp.addingTimeInterval(2)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // 查詢符合條件的 correlation
        let correlations = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCorrelation], Error>) in
            let query = HKCorrelationQuery(type: bloodPressureType, predicate: predicate, samplePredicates: nil) { _, correlations, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let correlations = correlations {
                    continuation.resume(returning: correlations)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }

        // 刪除找到的 correlation 和其中的樣本
        if !correlations.isEmpty {
            // 收集所有需要刪除的樣本（包括 correlation 內的收縮壓和舒張壓）
            var samplesToDelete: [HKSample] = []

            for correlation in correlations {
                // 添加 correlation 本身
                samplesToDelete.append(correlation)

                // 添加 correlation 中的所有樣本（收縮壓和舒張壓）
                samplesToDelete.append(contentsOf: correlation.objects)
            }

            print("正在刪除 \(samplesToDelete.count) 個血壓相關樣本")

            // 一次性刪除所有樣本
            try await healthStore.delete(samplesToDelete)

            print("血壓數據刪除成功")
        } else {
            print("警告：未找到符合時間條件的血壓數據")
        }
    }

    /// 刪除特定時間戳的樣本
    private func deleteSample(identifier: HKQuantityTypeIdentifier, timestamp: Date) async throws {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw NSError(domain: "HealthKit", code: 3, userInfo: [NSLocalizedDescriptionKey: "無效的數據類型"])
        }

        // 建立時間範圍查詢條件（前後 2 秒內的數據）
        let startDate = timestamp.addingTimeInterval(-2)
        let endDate = timestamp.addingTimeInterval(2)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        // 查詢符合條件的樣本
        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }

        // 刪除找到的樣本
        if !samples.isEmpty {
            try await healthStore.delete(samples)
        }
    }

    /// 讀取最近的健康數據
    func fetchRecentData(for type: HealthDataType, limit: Int = 10) async throws -> [HKQuantitySample] {
        let identifier: HKQuantityTypeIdentifier

        switch type {
        case .weight:
            identifier = .bodyMass
        case .height:
            identifier = .height
        case .bloodPressure:
            identifier = .bloodPressureSystolic
        case .heartRate:
            identifier = .heartRate
        case .bloodSugar:
            identifier = .bloodGlucose
        case .bodyTemperature:
            identifier = .bodyTemperature
        }

        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            throw NSError(domain: "HealthKit", code: 5, userInfo: [NSLocalizedDescriptionKey: "無效的數據類型"])
        }

        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples as? [HKQuantitySample] {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }
    }

    /// 檢查紀錄是否仍存在於 HealthKit
    func checkRecordExistsInHealthKit(_ record: HealthRecord) async -> Bool {
        // 建立時間範圍查詢條件（前後 2 秒內的數據）
        let startDate = record.timestamp.addingTimeInterval(-2)
        let endDate = record.timestamp.addingTimeInterval(2)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)

        do {
            switch record.type {
            case .bloodPressure:
                // 血壓需要檢查 correlation
                guard let bloodPressureType = HKCorrelationType.correlationType(forIdentifier: .bloodPressure) else {
                    return false
                }

                let correlations = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKCorrelation], Error>) in
                    let query = HKCorrelationQuery(type: bloodPressureType, predicate: predicate, samplePredicates: nil) { _, correlations, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let correlations = correlations {
                            continuation.resume(returning: correlations)
                        } else {
                            continuation.resume(returning: [])
                        }
                    }
                    healthStore.execute(query)
                }

                return !correlations.isEmpty

            case .weight:
                return try await checkQuantitySampleExists(identifier: .bodyMass, predicate: predicate)

            case .height:
                return try await checkQuantitySampleExists(identifier: .height, predicate: predicate)

            case .heartRate:
                return try await checkQuantitySampleExists(identifier: .heartRate, predicate: predicate)

            case .bloodSugar:
                return try await checkQuantitySampleExists(identifier: .bloodGlucose, predicate: predicate)

            case .bodyTemperature:
                return try await checkQuantitySampleExists(identifier: .bodyTemperature, predicate: predicate)
            }
        } catch {
            print("檢查 HealthKit 紀錄時發生錯誤: \(error.localizedDescription)")
            return false
        }
    }

    /// 檢查數量樣本是否存在
    private func checkQuantitySampleExists(identifier: HKQuantityTypeIdentifier, predicate: NSPredicate) async throws -> Bool {
        guard let quantityType = HKObjectType.quantityType(forIdentifier: identifier) else {
            return false
        }

        let samples = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[HKSample], Error>) in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let samples = samples {
                    continuation.resume(returning: samples)
                } else {
                    continuation.resume(returning: [])
                }
            }
            healthStore.execute(query)
        }

        return !samples.isEmpty
    }
}
