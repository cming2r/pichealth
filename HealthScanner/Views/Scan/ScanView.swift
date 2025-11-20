//
//  ScanView.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI
import UIKit
import AVFoundation

struct ScanView: View {
    @StateObject private var cameraService = CameraService()
    @EnvironmentObject var healthKitService: HealthKitService
    @EnvironmentObject var storageService: StorageService

    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingResultView = false
    @State private var scanResponse: ScanResponse?
    @State private var isScanning = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingCameraPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // 圖標和說明
                VStack(spacing: 8) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)

                    Text("scan.description".localized)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 60)

                Spacer()

                // 預覽圖片
                if let image = cameraService.capturedImage {
                    VStack(spacing: 16) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 250)
                            .cornerRadius(12)
                            .shadow(radius: 5)

                        VStack(spacing: 12) {
                            // 開始掃描
                            Button(action: {
                                scanImage()
                            }) {
                                Label("scan.start".localized, systemImage: "doc.text.magnifyingglass")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isScanning)

                            // 返回
                            Button(action: {
                                cameraService.reset()
                            }) {
                                Text("scan.back".localized)
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    // 選擇來源按鈕
                    VStack(spacing: 16) {
                        // 拍照按鈕
                        Button(action: {
                            checkCameraPermission()
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 40))
                                Text("scan.openCamera".localized)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }

                        // 相簿按鈕
                        Button(action: {
                            showingPhotoLibrary = true
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 40))
                                Text("scan.chooseFromLibrary".localized)
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 120)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("scan.title".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toast(isShowing: $isScanning, message: "scan.scanning".localized, icon: nil, showProgress: true, backgroundColor: Color.orange.opacity(0.9), duration: 0)
            .fullScreenCover(isPresented: $showingCamera) {
                ImagePicker(image: $cameraService.capturedImage, sourceType: .camera)
            }
            .fullScreenCover(isPresented: $showingPhotoLibrary) {
                PhotoPicker(image: $cameraService.capturedImage)
            }
            .sheet(isPresented: $showingResultView) {
                if let response = scanResponse {
                    ResultConfirmView(scanResponse: response, capturedImage: cameraService.capturedImage)
                        .environmentObject(healthKitService)
                        .environmentObject(storageService)
                        .onDisappear {
                            cameraService.reset()
                            scanResponse = nil
                        }
                }
            }
            .alert("scan.error.title".localized, isPresented: $showingError) {
                Button("common.ok".localized, role: .cancel) {}
            } message: {
                Text(errorMessage ?? "scan.error.unknown".localized)
            }
            .alert("scan.camera.permission.title".localized, isPresented: $showingCameraPermissionAlert) {
                Button("scan.camera.permission.settings".localized, role: .none) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
                Button("common.cancel".localized, role: .cancel) {}
            } message: {
                Text("scan.camera.permission.message".localized)
            }
        }
    }

    /// 檢查相機權限
    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            // 已授權，直接打開相機
            showingCamera = true

        case .notDetermined:
            // 尚未請求權限，請求權限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showingCamera = true
                    } else {
                        showingCameraPermissionAlert = true
                    }
                }
            }

        case .denied, .restricted:
            // 已拒絕或受限制，顯示提示
            showingCameraPermissionAlert = true

        @unknown default:
            showingCameraPermissionAlert = true
        }
    }

    /// 掃描圖片
    private func scanImage() {
        guard let image = cameraService.capturedImage else { return }

        isScanning = true
        errorMessage = nil

        Task {
            do {
                // 調用真實 API 進行識別
                let response = try await APIService.shared.scanImage(image)

                await MainActor.run {
                    isScanning = false
                    scanResponse = response
                    showingResultView = true
                }
            } catch {
                await MainActor.run {
                    isScanning = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

#Preview {
    ScanView()
        .environmentObject(HealthKitService())
        .environmentObject(StorageService())
}
