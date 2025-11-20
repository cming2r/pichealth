//
//  ImagePicker.swift
//  HealthScanner
//
//  Created on 2025-10-16
//

import SwiftUI
import UIKit

/// UIImagePickerController 的 SwiftUI 封裝
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) var dismiss

    var sourceType: UIImagePickerController.SourceType = .camera

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = sourceType
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                // 修正圖片方向（相機拍攝的圖片可能有方向問題）
                parent.image = image.fixedOrientation()
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// UIImage 擴展 - 修正圖片方向
extension UIImage {
    func fixedOrientation() -> UIImage {
        // 如果圖片方向已經正確，直接返回
        if imageOrientation == .up {
            return self
        }

        // 創建一個新的圖片上下文並重新繪製
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}
