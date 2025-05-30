//
//  NP4iApp.swift
//  NP4i
//
//  Created by geckour on 2023/04/13.
//

import SwiftUI
import OAuthSwift

@main
struct NP4iApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onOpenURL { url in
                    if url.scheme == "np4i" && url.host == "spotify.callback" {
                        OAuthSwift.handle(url: url)
                    }
                }
        }
    }
}
