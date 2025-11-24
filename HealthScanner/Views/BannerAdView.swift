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

    // AdMob Banner 广告 ID
    private static let productionAdUnitID = "ca-app-pub-5238540470214596/7691556289"

    init(adUnitID: String? = nil) {
        self.adUnitID = adUnitID ?? Self.productionAdUnitID
    }

    func makeUIView(context: Context) -> BannerView {
        let bannerView = BannerView()
        bannerView.adUnitID = adUnitID

        // 使用标准横幅广告尺寸 (320x50)
        bannerView.adSize = AdSizeBanner

        // 获取 rootViewController
        let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        if let rootViewController = windowScene?.windows.first?.rootViewController {
            bannerView.rootViewController = rootViewController
        }

        // 加载广告
        bannerView.load(Request())

        return bannerView
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 不需要更新
    }
}

// MARK: - AdMob Banner Container
struct AdMobBannerContainer: View {
    // 用于触发广告重新加载的标识符
    let refreshID: String

    init(refreshID: String = UUID().uuidString) {
        self.refreshID = refreshID
    }

    var body: some View {
        BannerAdView()
            .frame(height: 50) // 标准横幅广告高度
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .id(refreshID) // 当 refreshID 变化时，强制重新创建广告视图
    }
}

#Preview {
    AdMobBannerContainer()
}
