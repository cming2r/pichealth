//
//  DeviceIdentifierService.swift
//  HealthScanner
//
//  Created on 2025-10-21
//

import Foundation
import Security

/// 裝置識別服務 - 使用 Keychain 安全儲存裝置唯一識別碼
class DeviceIdentifierService {
    static let shared = DeviceIdentifierService()

    private let keychainKey = "com.healthscanner.device.identifier"

    private init() {}

    /// 獲取裝置唯一識別碼（如果不存在則自動生成）
    var deviceIdentifier: String {
        // 先嘗試從 Keychain 讀取
        if let existingID = readFromKeychain() {
            return existingID
        }

        // 如果不存在，生成新的 UUID
        let newID = UUID().uuidString

        // 儲存到 Keychain
        saveToKeychain(newID)

        return newID
    }

    /// 獲取簡短顯示用的 ID（前8位）
    var shortIdentifier: String {
        let fullID = deviceIdentifier
        let index = fullID.index(fullID.startIndex, offsetBy: min(8, fullID.count))
        return String(fullID[..<index])
    }

    // MARK: - Keychain 操作

    /// 從 Keychain 讀取識別碼
    private func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let identifier = String(data: data, encoding: .utf8) else {
            return nil
        }

        return identifier
    }

    /// 儲存識別碼到 Keychain
    private func saveToKeychain(_ identifier: String) {
        guard let data = identifier.data(using: .utf8) else {
            print("無法將識別碼轉換為 Data")
            return
        }

        // 先刪除舊的（如果存在）
        deleteFromKeychain()

        // 建立新的
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock // 裝置解鎖後即可存取
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status != errSecSuccess {
            print("儲存識別碼到 Keychain 失敗，錯誤碼：\(status)")
        }
    }

    /// 從 Keychain 刪除識別碼（僅供測試或重置使用）
    @discardableResult
    private func deleteFromKeychain() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// 重置裝置識別碼（會生成新的 UUID）
    func resetIdentifier() {
        deleteFromKeychain()
        // 下次呼叫 deviceIdentifier 時會自動生成新的
    }
}
