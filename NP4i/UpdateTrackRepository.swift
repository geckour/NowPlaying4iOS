//
//  SpotifyRepository.swift
//  NP4i
//
//  Created by geckour on 2023/04/15.
//

import Foundation
import OAuthSwift
import SwiftUI
import MediaPlayer
import MusicKit
import AuthenticationServices

class UpdateTrackRepository: NSObject {
    
    static let standard = UpdateTrackRepository()
    
    let clientId = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_KEY"] as? String ?? ""
    let clientSecret = Bundle.main.infoDictionary?["SPOTIFY_CLIENT_SECRET"] as? String ?? ""
    
    func authorizeWithSpotify(track: Track, modifiers: [FormatPatternModifier], completion: @escaping (Result<SpotifyOAuthToken, Error>) -> Void) {
        let urlString = "https://accounts.spotify.com/authorize?response_type=code&client_id=\(clientId)&scope=user-read-currently-playing&redirect_uri=np4i%3A%2F%2Fspotify.callback&state=\(self.generateState(withLength: 16))"
        let authenticationSession = ASWebAuthenticationSession(
            url: URL(string: urlString)!,
            callbackURLScheme: "np4i"
        ) { url, error in
            if let error = error {
                completion(.failure(error))
            }
            if let url = url {
                guard let code = URLComponents(url: url, resolvingAgainstBaseURL: true)?.queryItems?.first(where: { URLQueryItem in
                    URLQueryItem.name == "code"
                })?.value else {
                    return
                }
                let authorizationHeaderValue = "\(self.clientId):\(self.clientSecret)".data(using: .utf8)!.base64EncodedString()
                var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
                request.httpMethod = "POST"
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
                request.setValue("Basic \(authorizationHeaderValue)", forHTTPHeaderField:"Authorization")
                request.httpBody = "code=\(code)&redirect_uri=np4i%3A%2F%2Fspotify.callback&grant_type=authorization_code".data(using: .utf8)
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        completion(.failure(error))
                    }
                    if let data = data {
                        do {
                            let token = try JSONDecoder().decode(SpotifyOAuthToken.self, from: data)
                            completion(.success(token))
                        } catch {
                            completion(.failure(error))
                        }
                    }
                }.resume()
            }
        }
        authenticationSession.presentationContextProvider = self
        authenticationSession.prefersEphemeralWebBrowserSession = true
        authenticationSession.start()
    }
    
    func updateWithSpotify(
        track: Track,
        modifiers: [FormatPatternModifier],
        authorizeCompletion: @escaping (Result<SpotifyOAuthToken, Error>) -> Void,
        requestCompletion: @escaping (Error?) -> Void,
        onlyAlreadyHasToken: Bool = false
    ) {
        if let tokenData = KeyChainRepository.standard.getFromKeyChainOrNull(service: "oauth-token", account: "spotify") {
            let token = String(data: tokenData, encoding: .utf8)!
            var request = URLRequest(url: URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!)
            request.httpMethod = "GET"
            request.url?.append(queryItems: [URLQueryItem(name: "market", value: "from_token")])
            request.allHTTPHeaderFields = [
                "Authorization": "Bearer \(token)",
                "Accept-Language": Locale.current.language.languageCode?.identifier ?? "ja",
                "Content-Type": "application/json"
            ]
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    requestCompletion(error)
                    self.updateWithLocalAppleMusic(track: track, modifiers: modifiers)
                    return
                }
                if let statusCode = (response as? HTTPURLResponse)?.statusCode {
                    if (statusCode == 204) {
                        requestCompletion(NoContentError())
                        self.updateWithLocalAppleMusic(track: track, modifiers: modifiers)
                        return
                    }
                    if (statusCode == 200) {
                        if let data = data {
                            do {
                                let spotifyResult = try JSONDecoder().decode(SpotifyNowPlayingResult.self, from: data)
                                requestCompletion(nil)
                                if let spotifyTrack = spotifyResult.item {
                                    DispatchQueue.main.async {
                                        track.update(
                                            title: spotifyTrack.name,
                                            artist: spotifyTrack.artists.map { artist in artist.name }.joined(separator: ", "),
                                            album: spotifyTrack.album.name,
                                            spotifyUrl: spotifyTrack.external_urls.spotify,
                                            modifiers: modifiers
                                        )
                                    }
                                    
                                    URLSession.shared.dataTask(with: URL(string: spotifyTrack.album.images.first!.url)!) { data, response, error in
                                        if let data = data {
                                            DispatchQueue.main.async {
                                                track.update(
                                                    title: spotifyTrack.name,
                                                    artist: spotifyTrack.artists.map { artist in artist.name }.joined(separator: ", "),
                                                    album: spotifyTrack.album.name,
                                                    spotifyUrl: spotifyTrack.external_urls.spotify,
                                                    artwork: UIImage(data: data),
                                                    modifiers: modifiers
                                                )
                                            }
                                        }
                                    }.resume()
                                } else {
                                    requestCompletion(NoContentError())
                                    return
                                }
                            } catch {
                                requestCompletion(error)
                                return
                            }
                        } else {
                            requestCompletion(NoContentError())
                            return
                        }
                        return
                    }
                    if (UserDefaults.standard.object(forKey: "token-expires-at") != nil) {
                        let expiresAt = UserDefaults.standard.double(forKey: "token-expires-at") as TimeInterval
                        if let refreshTokenData = KeyChainRepository.standard.getFromKeyChainOrNull(service: "refresh-token", account: "spotify") {
                            if (Date(timeIntervalSince1970: expiresAt).timeIntervalSinceNow < 0) {
                                let refreshToken = String(data: refreshTokenData, encoding: .utf8)!
                                let authorizationHeaderValue = "\(self.clientId):\(self.clientSecret)".data(using: .utf8)!.base64EncodedString()
                                var request = URLRequest(url: URL(string: "https://accounts.spotify.com/api/token")!)
                                request.httpMethod = "POST"
                                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField:"Content-Type")
                                request.setValue("Basic \(authorizationHeaderValue)", forHTTPHeaderField:"Authorization")
                                request.httpBody = "refresh_token=\(refreshToken)&grant_type=refresh_token".data(using: .utf8)
                                URLSession.shared.dataTask(with: request) { data, response, error in
                                    if let error = error {
                                        authorizeCompletion(.failure(error))
                                        self.updateWithLocalAppleMusic(track: track, modifiers: modifiers)
                                    }
                                    if let data = data {
                                        do {
                                            let token = try JSONDecoder().decode(SpotifyOAuthToken.self, from: data)
                                            authorizeCompletion(.success(token))
                                            return
                                        } catch {
                                            authorizeCompletion(.failure(error))
                                            self.updateWithLocalAppleMusic(track: track, modifiers: modifiers)
                                            return
                                        }
                                    }
                                }.resume()
                                return
                            }
                        }
                    }
                }
            }.resume()
        } else {
            if (!onlyAlreadyHasToken) {
                self.authorizeWithSpotify(track: track, modifiers: modifiers, completion: authorizeCompletion)
            }
        }
    }
    
    func saveCredentials(token: SpotifyOAuthToken) -> (success: Bool, service: String?) {
        var result: (Bool, String?) = (true, nil)
        let successOAuth = KeyChainRepository.standard.setIntoKeyChain(value: token.access_token, service: "oauth-token", account: "spotify")
        if (!successOAuth) {
            result = (false, "oauth-token")
        }
        if let refreshToken = token.refresh_token {
            let successRefresh = KeyChainRepository.standard.setIntoKeyChain(value: refreshToken, service: "refresh-token", account: "spotify")
            if (!successRefresh) {
                result = (false, "refresh-token")
            }
        }
        UserDefaults.standard.set(token.expires_in, forKey: "token-expires-at")
        
        return result
    }
    
    func clearCredentials() {
        KeyChainRepository.standard.deleteFromKeyChain(service: "oauth-token", account: "spotify")
        KeyChainRepository.standard.deleteFromKeyChain(service: "refresh-token", account: "spotify")
        UserDefaults.standard.removeObject(forKey: "token-expires-at")
    }
    
    func updateWithLocalAppleMusic(track: Track, modifiers: [FormatPatternModifier]) {
        if let item = MPMusicPlayerController.systemMusicPlayer.nowPlayingItem {
            if let a = item.artwork {
                let artwork = a.image(at: a.bounds.size)
                
                if (item.playbackStoreID == "0") {
                    DispatchQueue.main.async {
                        track.update(
                            title: item.title ?? "",
                            artist: item.artist ?? "",
                            album: item.albumTitle ?? "",
                            composer: item.composer,
                            artwork: artwork,
                            modifiers: modifiers
                        )
                    }
                    return
                }
                
                Task {
                    do {
                        print(item.playbackStoreID)
                        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(item.playbackStoreID))
                        let response = try await request.response()
                        
                        if let song = response.items.first {
                            if let a2 = song.artwork {
                                let artworkURL = a2.url(width: a2.maximumWidth, height: a2.maximumHeight)!
                                
                                DispatchQueue.main.async {
                                    track.update(
                                        title: song.title,
                                        artist: song.artistName,
                                        album: song.albumTitle ?? "",
                                        composer: song.composerName,
                                        appleMusicUrl: song.url?.string,
                                        artworkURL: artworkURL,
                                        modifiers: modifiers
                                    )
                                }
                            }
                            DispatchQueue.main.async {
                                track.update(
                                    title: song.title,
                                    artist: song.artistName,
                                    album: song.albumTitle ?? "",
                                    composer: song.composerName,
                                    appleMusicUrl: song.url?.string,
                                    artwork: artwork,
                                    modifiers: modifiers
                                )
                            }
                            return
                        } else {
                            DispatchQueue.main.async {
                                track.update(
                                    title: item.title ?? "",
                                    artist: item.artist ?? "",
                                    album: item.albumTitle ?? "",
                                    composer: item.composer,
                                    artwork: artwork,
                                    modifiers: modifiers
                                )
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            track.update(
                                title: item.title ?? "",
                                artist: item.artist ?? "",
                                album: item.albumTitle ?? "",
                                composer: item.composer,
                                artwork: artwork,
                                modifiers: modifiers
                            )
                        }
                    }
                }
            } else {
                Task {
                    do {
                        let request = MusicCatalogResourceRequest<Song>(matching: \.id, equalTo: MusicItemID(item.playbackStoreID))
                        let response = try await request.response()
                        
                        if let song = response.items.first {
                            DispatchQueue.main.async {
                                track.update(
                                    title: item.title ?? "",
                                    artist: item.artist ?? "",
                                    album: item.albumTitle ?? "",
                                    composer: item.composer,
                                    appleMusicUrl: song.title,
                                    modifiers: modifiers
                                )
                            }
                            return
                        } else {
                            DispatchQueue.main.async {
                                track.update(
                                    title: item.title ?? "",
                                    artist: item.artist ?? "",
                                    album: item.albumTitle ?? "",
                                    composer: item.composer,
                                    modifiers: modifiers
                                )
                            }
                        }
                    } catch {
                        DispatchQueue.main.async {
                            track.update(
                                title: item.title ?? "",
                                artist: item.artist ?? "",
                                album: item.albumTitle ?? "",
                                composer: item.composer,
                                modifiers: modifiers
                            )
                        }
                    }
                }
            }
        } else {
            DispatchQueue.main.async {
                track.update(
                    title: "",
                    artist: "",
                    album: "",
                    modifiers: modifiers
                )
            }
        }
    }
    
    private  func generateState(withLength len: Int) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let length = UInt32(letters.count)
        
        var randomString = ""
        for _ in 0..<len {
            let rand = arc4random_uniform(length)
            let idx = letters.index(letters.startIndex, offsetBy: Int(rand))
            let letter = letters[idx]
            randomString += String(letter)
        }
        return randomString
    }
}

@available(iOS 13.0, *)
extension UpdateTrackRepository: ASWebAuthenticationPresentationContextProviding {
    
    @MainActor
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

struct SpotifyOAuthToken: Decodable {
    let access_token: String
    let expires_in: Int
    let refresh_token: String?
}

struct SpotifyNowPlayingResult: Decodable {
    let item: SpotifyTrack?
    
    struct SpotifyTrack: Decodable {
        let id: String
        let external_urls: SpotifyExternalUrl
        let name: String
        let album: SpotifyAlbum
        let artists: [SpotifyArtist]
        
        struct SpotifyExternalUrl: Decodable {
            let spotify: String
        }
        
        struct SpotifyAlbum: Decodable {
            let name: String
            let images: [SpotifyImage]
        }
        
        struct SpotifyImage: Decodable {
            let url: String
        }
        
        struct SpotifyArtist: Decodable {
            let name: String
        }
    }
}

struct NoContentError: LocalizedError {
    var errorDescription: String = "No content has been playing on Spotify."
}

enum CustomError: Error {
    case messageError(String)
}
