//
//  AppDeligate.swift
//  NP4i
//
//  Created by geckour on 2023/04/14.
//

import Foundation
import UIKit
import OAuthSwift
import FirebaseCore
//import GoogleMobileAds

let firstLaunchKey = "firstLaunchKey"

class AppDelegate : NSObject, UIApplicationDelegate {
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey  : Any] = [:]) -> Bool {
        if url.host == "oauth-callback" {
            OAuthSwift.handle(url: url)
        }
        return true
    }
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
//        GADMobileAds.sharedInstance().start(completionHandler: nil)
        return true
    }
}
