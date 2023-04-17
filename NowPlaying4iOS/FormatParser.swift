//
//  FormatParser.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/15.
//

import Foundation
import SwiftUI

extension String {
    func splitIncludeDelimiter(delimiters: String...) -> [String] {
        var result = [self]
        delimiters.forEach { delimiter in
            result = result.flatMap {
                $0.components(separatedBy: delimiter)
                    .flatMap { [$0, delimiter] }
                    .dropLast()
                    .filter { $0 != "" }
            }
        }
        return result
    }
    
    func splitConsideringEscape() -> [String] {
        let splitList = self.splitIncludeDelimiter(
            delimiters:
                FormatPattern.S_QUOTE_DOUBLE.rawValue,
            FormatPattern.S_QUOTE.rawValue,
            FormatPattern.TITLE.rawValue,
            FormatPattern.ARTIST.rawValue,
            FormatPattern.ALBUM.rawValue,
            FormatPattern.COMPOSER.rawValue,
            FormatPattern.SPOTIFY_URL.rawValue,
            FormatPattern.NEW_LINE.rawValue
        )
        let escapes: [(offset: Int, element: String)] = splitList.enumerated().filter { $0.element == "'" }
        if (escapes.isEmpty) {
            return splitList
        }
        
        var result = [String]()
        for i in stride(from: 0,to: escapes.count - 1, by: 2) {
            result.append(
                contentsOf:
                    splitList[
                        (i == 0 ? 0 : escapes[i - 1].offset + 1)..<escapes[i].offset
                    ].map { $0 }
            )
            
            result.append(
                splitList[
                    escapes[i].offset..<escapes[i + 1].offset + 1
                ].joined(separator: "")
            )
        }
        
        result.append(
            contentsOf:
                splitList[
                    ((escapes[escapes.count - 1].offset + 1 < splitList.count - 1) ? escapes[escapes.count - 1].offset + 1 : splitList.count - 1)..<splitList.count
                ]
        )
        
        return result.filter { !$0.isEmpty }
    }
    
    func withModifiers(
        modifiers: [FormatPatternModifier],
        identifier: FormatPattern
    ) -> String {
        let prefix = modifiers.getPrefix(value: identifier.rawValue)
        let suffix = modifiers.getSuffix(value: identifier.rawValue)
        return "\(prefix)\(self)\(suffix)"
    }
}

extension Array where Element == FormatPatternModifier {
    func getPrefix(value: String) -> String {
        return self.first(where: { m in m.id.rawValue == value })?.prefix ?? ""
    }
    
    func getSuffix(value: String) -> String {
        return self.first(where: { m in m.id.rawValue == value })?.suffix ?? ""
    }
}

class FormatParser {
    
    static func getSharingSubject(
        track: Track,
        sharingFormatText: String,
        modifiers: [FormatPatternModifier],
        requireMatchAllPattern: Bool = false
    ) -> String {
        let regex = try! Regex("^'([\\s\\S]+)'$")
        return sharingFormatText.splitConsideringEscape().map {
            var result = ""
            let matches = $0.matches(of: regex)
            if (!matches.isEmpty) {
                result = matches.map { String($0.0) }.joined(separator: "")
            } else {
                switch ($0) {
                case FormatPattern.S_QUOTE.rawValue:
                    result = ""
                case FormatPattern.S_QUOTE_DOUBLE.rawValue:
                    result = "'"
                case FormatPattern.TITLE.rawValue:
                    result = track.title.withModifiers(modifiers: modifiers, identifier: FormatPattern.TITLE)
                case FormatPattern.ARTIST.rawValue:
                    result = track.artist.withModifiers(modifiers: modifiers, identifier: FormatPattern.ARTIST)
                case FormatPattern.ALBUM.rawValue:
                    result = track.album.withModifiers(modifiers: modifiers, identifier: FormatPattern.ALBUM)
                case FormatPattern.COMPOSER.rawValue:
                    result = track.composer?.withModifiers(modifiers: modifiers, identifier: FormatPattern.COMPOSER) ?? ""
                case FormatPattern.SPOTIFY_URL.rawValue:
                    result = track.spotifyUrl?.withModifiers(modifiers: modifiers, identifier: FormatPattern.SPOTIFY_URL) ?? ""
                case FormatPattern.NEW_LINE.rawValue:
                    result = "\n"
                default:
                    result = $0
                }
            }
            return result
        }.joined(separator: "")
    }
}

enum FormatPattern: String, CaseIterable, Encodable, Decodable {
    case S_QUOTE = "'"
    case S_QUOTE_DOUBLE = "''"
    case TITLE = "TI"
    case ARTIST = "AR"
    case ALBUM = "AL"
    case COMPOSER = "CO"
    case SPOTIFY_URL = "SU"
    case NEW_LINE = "\\n"
}

struct FormatPatternModifier: Identifiable, Encodable, Decodable {

    let id: FormatPattern
    var prefix: String = ""
    var suffix: String = ""
}

func getReplaceablePatterns() -> [FormatPattern] {
    return FormatPattern.allCases.filter { ![FormatPattern.S_QUOTE, FormatPattern.S_QUOTE_DOUBLE, FormatPattern.NEW_LINE].contains($0) }
}
