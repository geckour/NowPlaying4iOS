//
//  SpotifyRepository.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/15.
//

import Foundation
import OAuthSwift
import SwiftUI
import MediaPlayer

class UpdateTrackRepository {
    
    static let standard = UpdateTrackRepository()
    
    private let oauthswift = OAuth2Swift(
        consumerKey: Bundle.main.infoDictionary?["SPOTIFY_CLIENT_KEY"] as? String ?? "",
        consumerSecret: Bundle.main.infoDictionary?["SPOTIFY_CLIENT_SECRET"] as? String ?? "",
        authorizeUrl: "https://accounts.spotify.com/authorize",
        accessTokenUrl: "https://accounts.spotify.com/api/token",
        responseType: "code"
    )
    
    init() {
        oauthswift.accessTokenBasicAuthentification = true
    }
    
    func authorize(track: Track, modifiers: [FormatPatternModifier]) {
        oauthswift.authorize(
            withCallbackURL: URL(string: "np4ios://spotify.callback"),
            scope: "user-read-private%20user-read-playback-state",
            state: generateState(withLength: 20)
        ) { result in
            switch result {
            case .success(let (credential, _, _)):
                self.saveCredentials(credential: credential)
                self.updateWithSpotify(track: track, modifiers: modifiers)
            case .failure(let error):
                print(error.localizedDescription)
            }
        }
    }
    
    func updateWithSpotify(track: Track, modifiers: [FormatPatternModifier]) {
        if let tokenData = KeyChainRepository.standard.getFromKeyChainOrNull(service: "oauth-token", account: "spotify") {
            let token = String(data: tokenData, encoding: .utf8)!
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player")!)
            request.httpMethod = "GET"
            request.url?.append(queryItems: [URLQueryItem(name: "market", value: "from_token")])
            request.allHTTPHeaderFields = [
                "Authorization": "Bearer \(token)",
                "Accept-Language": "ja",
                "Content-Type": "application/json"
            ]
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print(error.localizedDescription)
                } else {
                    if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                        print(statusCode)
                        switch statusCode / 100 {
                        case 2:
                            do {
                                if (statusCode == 204) {
                                    throw NoContentError.spotify
                                } else {
                                    if let data = data {
                                        let spotifyResult = try JSONDecoder().decode(SpotifyNowPlayingResult.self, from: data)
                                        DispatchQueue.main.async {
                                            track.update(
                                                title: spotifyResult.item.name,
                                                artist: spotifyResult.item.artists.map { artist in artist.name }.joined(separator: ", "),
                                                album: spotifyResult.item.album.name,
                                                spotifyUrl: spotifyResult.item.external_urls["spotify"],
                                                modifiers: modifiers
                                            )
                                        }
                                        
                                        URLSession.shared.dataTask(with: URL(string: spotifyResult.item.album.images.first!.url)!) { data, response, error in
                                            if let data = data {
                                                DispatchQueue.main.async {
                                                    track.update(
                                                        title: spotifyResult.item.name,
                                                        artist: spotifyResult.item.artists.map { artist in artist.name }.joined(separator: ", "),
                                                        album: spotifyResult.item.album.name,
                                                        spotifyUrl: spotifyResult.item.external_urls["spotify"],
                                                        artwork: UIImage(data: data),
                                                        modifiers: modifiers
                                                    )
                                                }
                                            }
                                        }.resume()
                                        return
                                    }
                                }
                            } catch {
                                print(error.localizedDescription)
                            }
                            return
                        default:
                            if (UserDefaults.standard.object(forKey: "token-expires-at") != nil) {
                                let expiresAt = UserDefaults.standard.double(forKey: "token-expires-at") as TimeInterval
                                if let refreshTokenData = KeyChainRepository.standard.getFromKeyChainOrNull(service: "refresh-token", account: "spotify") {
                                    if (Date(timeIntervalSince1970: expiresAt).timeIntervalSinceNow < 0) {
                                        self.oauthswift.renewAccessToken(withRefreshToken: String(data: refreshTokenData, encoding: .utf8)!) { result in
                                            switch result {
                                            case .success(let (credential, _, _)):
                                                self.saveCredentials(credential: credential)
                                                self.updateWithSpotify(track: track, modifiers: modifiers)
                                                return
                                            case .failure(let error):
                                                print(error.localizedDescription)
                                            }
                                        }
                                    }
                                }
                            }
                            if (statusCode == 401) {
                                self.clearCredentials()
                                self.authorize(track: track, modifiers: modifiers)
                            }
                        }
                    }
                }
                
                let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem
                var artwork: UIImage? = nil
                if let a = item?.artwork {
                    artwork = a.image(at: a.bounds.size)
                }
                DispatchQueue.main.async {
                    track.update(
                        title: item?.title ?? "",
                        artist: item?.artist ?? "",
                        album: item?.albumTitle ?? "",
                        composer: item?.composer,
                        artwork: artwork,
                        modifiers: modifiers
                    )
                }
            }.resume()
        }
    }
    
    func saveCredentials(credential: OAuthSwiftCredential) {
        let _ = KeyChainRepository.standard.setIntoKeyChain(value: credential.oauthToken, service: "oauth-token", account: "spotify")
        let _ = KeyChainRepository.standard.setIntoKeyChain(value: credential.oauthRefreshToken, service: "refresh-token", account: "spotify")
        UserDefaults.standard.set(credential.oauthTokenExpiresAt?.timeIntervalSince1970, forKey: "token-expires-at")
    }
    
    func clearCredentials() {
        KeyChainRepository.standard.deleteFromKeyChain(service: "oauth-token", account: "spotify")
        KeyChainRepository.standard.deleteFromKeyChain(service: "refresh-token", account: "spotify")
        UserDefaults.standard.removeObject(forKey: "token-expires-at")
    }
}

struct SpotifyNowPlayingResult: Decodable {
    let item: SpotifyTrack
    
    struct SpotifyTrack: Decodable {
        let id: String
        let external_urls: [String:String]
        let name: String
        let album: SpotifyAlbum
        let artists: [SpotifyArtist]
        
        struct SpotifyAlbum: Decodable {
            let name: String
            let images: [SpotifyImage]
        }
        
        struct SpotifyImage: Decodable {
            let url: String
            let height: Int
            let width: Int
        }
        
        struct SpotifyArtist: Decodable {
            let name: String
        }
    }
}

enum NoContentError: Error {
    case spotify
}
