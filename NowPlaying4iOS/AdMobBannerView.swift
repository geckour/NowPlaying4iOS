//
//  AdMobBannerView.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/16.
//

import GoogleMobileAds
import SwiftUI

struct AdMobBannerView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = Bundle.main.infoDictionary?["ADMOB_BANNER_UNIT_ID"] as? String
        banner.rootViewController = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.windows.first?.rootViewController
        banner.load(GADRequest())
        return banner
    }
    
    func updateUIView(_ uiView: GADBannerView, context: Context) {}
}
