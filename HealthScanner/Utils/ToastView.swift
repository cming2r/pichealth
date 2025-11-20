//
//  ToastView.swift
//  HealthScanner
//
//  Created on 2025-10-21
//

import SwiftUI

/// Toast 提示組件
struct ToastView: View {
    let message: String
    let icon: String?
    let showProgress: Bool
    let backgroundColor: Color

    init(message: String, icon: String? = "checkmark.circle.fill", showProgress: Bool = false, backgroundColor: Color = Color.black.opacity(0.8)) {
        self.message = message
        self.icon = icon
        self.showProgress = showProgress
        self.backgroundColor = backgroundColor
    }

    var body: some View {
        HStack(spacing: 12) {
            if showProgress {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
            } else if let icon = icon {
                Image(systemName: icon)
                    .font(.title3)
            }

            Text(message)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

/// Toast 修飾符
struct ToastModifier: ViewModifier {
    @Binding var isShowing: Bool
    let message: String
    let icon: String?
    let showProgress: Bool
    let backgroundColor: Color
    let duration: TimeInterval

    func body(content: Content) -> some View {
        ZStack {
            content

            if isShowing {
                VStack {
                    Spacer()

                    ToastView(message: message, icon: icon, showProgress: showProgress, backgroundColor: backgroundColor)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 50)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isShowing)
                .zIndex(1)
                .onAppear {
                    // 如果 duration > 0，則自動隱藏；否則需要手動控制
                    if duration > 0 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                            withAnimation {
                                isShowing = false
                            }
                        }
                    }
                }
            }
        }
    }
}

extension View {
    /// 顯示 Toast 提示
    /// - Parameters:
    ///   - isShowing: 是否顯示
    ///   - message: 提示訊息
    ///   - icon: 圖示（預設為打勾圖示）
    ///   - showProgress: 是否顯示載入指示器
    ///   - backgroundColor: 背景顏色（預設為半透明黑色）
    ///   - duration: 顯示時長（秒，設為 0 表示需要手動控制）
    func toast(isShowing: Binding<Bool>, message: String, icon: String? = "checkmark.circle.fill", showProgress: Bool = false, backgroundColor: Color = Color.black.opacity(0.8), duration: TimeInterval = 2.0) -> some View {
        modifier(ToastModifier(isShowing: isShowing, message: message, icon: icon, showProgress: showProgress, backgroundColor: backgroundColor, duration: duration))
    }
}

#Preview {
    VStack {
        Text("主內容")
            .font(.title)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toast(isShowing: .constant(true), message: "已儲存")
}
