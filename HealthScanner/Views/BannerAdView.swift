//
//  BannerAdView.swift
//  HealthScanner
//
//  Created on 2025-10-31
//

import SwiftUI
import GoogleMobileAds

struct BannerAdView: UIViewRepresentable {
    let adUnitID: String

    // AdMob 测试广告 ID
    // 在开发测试时使用测试 ID，正式发布时使用真实 ID
    private static let testAdUnitID = "ca-app-pub-3940256099942544/2435281174" // Google 提供的测试 Banner ID
    private static let productionAdUnitID = "ca-app-pub-5238540470214596/7691556289" // 您的真实 Banner ID

    // 设置为 true 使用测试广告，false 使用真实广告
    private static let useTestAds = true

    init(adUnitID: String? = nil) {
        if let customID = adUnitID {
            self.adUnitID = customID
        } else {
            self.adUnitID = Self.useTestAds ? Self.testAdUnitID : Self.productionAdUnitID
        }
    }

    func makeUIView(context: Context) -> UIView {
        let bannerView = BannerView()
        bannerView.adUnitID = adUnitID

        // 获取屏幕宽度并使用自适应 banner
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let frame = windowScene?.windows.first?.frame ?? .zero
        let viewWidth = frame.size.width

        // 使用自适应 banner 尺寸
        bannerView.adSize = AdSize(size: CGSize(width: viewWidth, height: 50), flags: 0)

        // 获取 rootViewController
        if let rootViewController = windowScene?.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }

        // 加载广告
        bannerView.load(Request())

        let view = UIView()
        view.addSubview(bannerView)
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        // 不需要更新
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject {
        var parent: BannerAdView

        init(_ parent: BannerAdView) {
            self.parent = parent
        }
    }
}

// MARK: - AdMob Banner Container
struct AdMobBannerContainer: View {
    var body: some View {
        BannerAdView()
            .frame(height: 50) // 标准 banner 高度
            .frame(maxWidth: .infinity) // 宽度填满父容器
            .background(Color(.systemBackground))
    }
}

#Preview {
    AdMobBannerContainer()
}
