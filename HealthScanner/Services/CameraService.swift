//
//  CameraService.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI
import AVFoundation
import Combine

/// 相機服務 - 處理拍照功能
@MainActor
class CameraService: ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isAuthorized = false
    @Published var showingCamera = false

    init() {
        checkAuthorization()
    }

    /// 檢查相機權限
    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor [weak self] in
                    self?.isAuthorized = granted
                }
            }
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }
    }

    /// 請求相機權限
    func requestAuthorization() async -> Bool {
        await AVCaptureDevice.requestAccess(for: .video)
    }

    /// 將圖片轉為 Base64
    func convertImageToBase64(_ image: UIImage) -> String? {
        // 壓縮圖片以減少上傳大小
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            return nil
        }
        return imageData.base64EncodedString()
    }

    /// 重設
    func reset() {
        capturedImage = nil
    }
}
