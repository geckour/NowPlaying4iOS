//
//  NowPlaying4iOSApp.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/13.
//

import SwiftUI
import OAuthSwift

@main
struct NowPlaying4iOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.scheme == "np4ios" && url.host == "spotify.callback" {
                        OAuthSwift.handle(url: url)
                    }
                }
        }
    }
}
