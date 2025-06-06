//
//  ContentView.swift
//  NP4i
//
//  Created by geckour on 2023/04/13.
//

import SwiftUI
import OAuthSwift
import LinkPresentation
//import GoogleMobileAds

struct ContentView: View {
    @State private var alertDetail: AlertDetail? = nil
    private var isAlertPresented: Binding<Bool> {
        Binding(get: { alertDetail != nil }, set: { _ in })
    }
    @StateObject private var track: Track = Track()
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
                        HStack(alignment: .center) {
                            VStack(alignment: .center) {
                                Button(action: {
                                    UpdateTrackRepository.standard.authorizeWithSpotify(
                                        track: track,
                                        modifiers: modifiers,
                                        completion: onCompleteAuthorizationWithSpotify
                                    )
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
                                if (track.spotifyUrl != nil) {
                                    let spotifyURL = URL(string: "https://open.spotify.com/")!
                                    let canOpenSpotify = UIApplication.shared.canOpenURL(spotifyURL)
                                    HStack {
                                        Spacer()
                                        Image("Spotify_Icon", label: Text("Spotify icon"))
                                            .interpolation(.high)
                                            .resizable()
                                            .scaledToFit()
                                            .frame(maxWidth: 24)
                                        Text(canOpenSpotify ? "OPEN SPOTIFY" : "GET SPOTIFY FREE")
                                            .font(.body)
                                            .fontWeight(.bold)
                                            .foregroundColor(Color(red: 30 / 255.0, green: 215 / 255.0, blue: 96 / 255.0))
                                    }
                                    .frame(maxWidth: 500)
                                    .onTapGesture {
                                        if (canOpenSpotify) {
                                            UIApplication.shared.open(spotifyURL)
                                        } else {
                                            UIApplication.shared.open(URL(string: "https://apps.apple.com/app/id324684580")!)
                                        }
                                    }
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
                            .frame(minHeight: geometry.size.height)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .refreshable {
                    UpdateTrackRepository.standard.update(
                        track: track,
                        modifiers: modifiers,
                        authorizeCompletion: onCompleteAuthorizationWithSpotify,
                        requestCompletion: onCompleteRequestSpotify,
                        onlyAlreadyHasSpotifyToken: true
                    )
                }
//                AdMobBannerView()
//                    .frame(height: GADAdSizeBanner.size.height)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear(perform: {
                NotificationCenter.default
                    .addObserver(
                        forName: UIApplication.didBecomeActiveNotification,
                        object: nil,
                        queue: nil
                    ) { notification in
                        UpdateTrackRepository.standard.update(
                            track: track,
                            modifiers: modifiers,
                            authorizeCompletion: onCompleteAuthorizationWithSpotify,
                            requestCompletion: onCompleteRequestSpotify,
                            onlyAlreadyHasSpotifyToken: true
                        )
                    }
            })
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .alert(alertDetail == nil ? "" : alertDetail!.title, isPresented: isAlertPresented, presenting: alertDetail) { detail in
            Button(detail.defalultActionLabel) {
                alertDetail = nil
            }
        } message: {detail in
            if let message = detail.message {
                Text(message)
            }
        }
    }

    private func onCompleteAuthorizationWithSpotify(result: Result<SpotifyOAuthToken, Error>) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            switch result {
            case .failure(let error):
                print(error)
                alertDetail = AlertDetail(
                    title: "Failed to authorize with Spotify",
                    message: "\(error)",
                    defalultActionLabel: "OK"
                )
                break
            case .success(let token):
                UpdateTrackRepository.standard.clearCredentials()
                let saveCredentialsResult = UpdateTrackRepository.standard.saveCredentials(token: token)
                if (saveCredentialsResult.success) {
                    UpdateTrackRepository.standard.update(
                        track: track,
                        modifiers: modifiers,
                        authorizeCompletion: onCompleteAuthorizationWithSpotify,
                        requestCompletion: onCompleteRequestSpotify
                    )
                } else {
                    alertDetail = AlertDetail(
                        title: "Failed to save credentials",
                        message: saveCredentialsResult.service,
                        defalultActionLabel: "OK"
                    )
                }
                break
            }
        }
    }
    
    private func onCompleteRequestSpotify(error: Error?) {
        if let error = error {
            if (error is NoContentError) {
                return
            }

            alertDetail = AlertDetail(
                title: "Error on request to Spotify API",
                message: "\(error)",
                defalultActionLabel: "OK"
            )
        }
    }
}

class AlertDetail {
    var title: String
    var message: String?
    var defalultActionLabel: String
    
    init(
        title: String,
        message: String?,
        defalultActionLabel: String
    ) {
        self.title = title
        self.message = message
        self.defalultActionLabel = defalultActionLabel
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
