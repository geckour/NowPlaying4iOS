//
//  ActivityView.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/14.
//

import SwiftUI
import UIKit
import LinkPresentation

struct ShareSheet: UIViewControllerRepresentable {
    
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: applicationActivities
        )
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

final class ShareActivityItemSource: NSObject, UIActivityItemSource {
    private let linkMetaData: LPLinkMetadata
    
    init(linkMetadata: LPLinkMetadata) {
        self.linkMetaData = linkMetadata
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        return activityViewControllerPlaceholderItem(activityViewController)
    }
    
    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        return linkMetaData
    }
    
    static func createLocalImageUrl(image: UIImage, forImageNamed name: String) -> URL? {
        let fileManager = FileManager.default
        let cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let url = cacheDirectory.appendingPathComponent("\(name).png")
        
        if fileManager.fileExists(atPath: url.path) {
            do {
                try image.pngData()?.write(to: url)
            } catch {
                print(error)
            }
        } else {
            fileManager.createFile(atPath: url.path, contents: image.pngData(), attributes: nil)
        }
        
        return url
    }
}
