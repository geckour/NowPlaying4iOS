//
//  ContentView.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/13.
//

import SwiftUI
import OAuthSwift
import LinkPresentation
import GoogleMobileAds

struct ContentView: View {
    @StateObject private var track: Track = Track(title: "", artist: "", album: "")
    @State private var isPresentActivityController = false
    
    @State private var formatString = UserDefaults.standard.string(forKey: SETTINGS_KEY_FORMAT_STRING) ?? SETTINGS_DEFAULT_FORMAT_STRING
    @State var modifiers: [FormatPatternModifier] = UserDefaults.standard.data(forKey: SETTINGS_KEY_FORMAT_MODIFIERS)
        .map {
            try! JSONDecoder().decode([FormatPatternModifier].self, from: $0)
        } ?? getReplaceablePatterns().map { FormatPatternModifier(id: $0) }
    @State private var attachArtwork = (UserDefaults.standard.object(forKey: SETTINGS_KEY_ATTACH_ARTWORK) != nil) ? UserDefaults.standard.bool(forKey: SETTINGS_KEY_ATTACH_ARTWORK) : true
    
    var body: some View {
        return NavigationStack {
            VStack(alignment: .leading) {
                NavigationLink(destination: SettingsView(formatString: $formatString, modifiers: $modifiers, attachArtwork: $attachArtwork)) {
                    Image(systemName: "gearshape").imageScale(.large)
                }
                GeometryReader { geometry in
                    ScrollView {
                        VStack(alignment: .center) {
                            Button(action: {
                                UpdateTrackRepository.standard.authorize(track: track, modifiers: modifiers)
                            }) {
                                Label(LocalizedStringKey("SpotifyAuthTitle"), systemImage: "globe")
                            }.padding(.top, 20)
                            if let artwork = track.artwork {
                                Image(uiImage: artwork)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxWidth: 500)
                                    .padding(.top, 20)
                            }
                            Text(track.shareText).padding(.top, 8)
                            Button(action: { isPresentActivityController = true }) {
                                Label(LocalizedStringKey("ShareActionTitle"), systemImage: "square.and.arrow.up")
                            }
                            .padding(.top, 20)
                            .sheet(isPresented: $isPresentActivityController) {
                                ShareSheet(activityItems: track.getItem(attachArtwork: attachArtwork), applicationActivities: nil)
                                    .presentationDetents([.medium])
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: geometry.size.height - GADAdSizeBanner.size.height)
                    }
                }
                .refreshable {
                    UpdateTrackRepository.standard.updateWithSpotify(track: track, modifiers: modifiers)
                }
                AdMobBannerView()
                    .frame(height: GADAdSizeBanner.size.height)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: { UpdateTrackRepository.standard.updateWithSpotify(track: track, modifiers: modifiers) })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

class Track: ObservableObject {
    var title: String
    var artist: String
    var album: String
    var composer: String?
    var spotifyUrl: String?
    var appleMusicUrl: String?
    
    @Published var artwork: UIImage?
    @Published var shareText: String
    
    init(
        title: String = "",
        artist: String = "",
        album: String = "",
        shareText: String = ""
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.shareText = shareText
    }
    
    func update(
        title: String,
        artist: String,
        album: String,
        composer: String? = nil,
        spotifyUrl: String? = nil,
        appleMusicUrl: String? = nil,
        artwork: UIImage? = nil,
        artworkURL: URL? = nil,
        modifiers: [FormatPatternModifier]
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.composer = composer
        self.spotifyUrl = spotifyUrl
        self.appleMusicUrl = appleMusicUrl
        self.artwork = artwork
        if let artworkURL = artworkURL {
            updateArtworkWithURL(url: artworkURL)
        }
        updateShareText(modifiers: modifiers)
    }
    
    private func updateArtworkWithURL(url: URL) {
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                if let error = error {
                    print(error.localizedDescription)
                }
                return
            }
            
            DispatchQueue.main.async {
                self.artwork = UIImage(data: data)
            }
        }.resume()
    }
    
    private func updateShareText(modifiers: [FormatPatternModifier]) {
        shareText = FormatParser.getSharingSubject(
            track: self,
            sharingFormatText: UserDefaults.standard.string(
                forKey: SETTINGS_KEY_FORMAT_STRING
            ) ?? SETTINGS_DEFAULT_FORMAT_STRING,
            modifiers: modifiers
        )
    }
    
    func getItem(attachArtwork: Bool) -> [Any] {
        var item: [Any] = [getMetadataItemSource(attachArtwork: attachArtwork), shareText]
        if (attachArtwork) {
            if let artwork = artwork {
                item.append(artwork)
            }
        }
        return item
    }
    
    private func getMetadataItemSource(attachArtwork: Bool) -> ShareActivityItemSource {
        let metadata = LPLinkMetadata()
        metadata.title = shareText
        if (attachArtwork) {
            if let artwork = artwork {
                metadata.iconProvider = NSItemProvider(
                    contentsOf: ShareActivityItemSource.createLocalImageUrl(
                        image: artwork,
                        forImageNamed: "artwork"
                    )
                )
            }
        }
        return ShareActivityItemSource(linkMetadata: metadata)
    }
}
