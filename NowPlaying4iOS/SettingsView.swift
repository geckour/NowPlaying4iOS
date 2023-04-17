//
//  SettingsView.swift
//  NowPlaying4iOS
//
//  Created by geckour on 2023/04/15.
//

import SwiftUI

let SETTINGS_KEY_FORMAT_STRING = "settings_key_format_string"
let SETTINGS_DEFAULT_FORMAT_STRING = "#NowPlaying TI - AR (AL)"
let SETTINGS_KEY_FORMAT_MODIFIERS = "settings_key_format_modifiers"

struct SettingsView: View {
    @Binding var formatString: String
    @Binding var modifiers: [FormatPatternModifier]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(LocalizedStringKey("SettingsSectionShareTitle")) {
                    NavigationLink(destination: SettingsSentenceFormatView(formatString: $formatString)) {
                        HStack {
                            Text(LocalizedStringKey("SettingsItemFormatPatternTitle"))
                        }
                    }
                    NavigationLink(destination: SettingsSentenceFormatModifierView(modifiers: $modifiers)) {
                        HStack {
                            Text(LocalizedStringKey("SettingsItemFormatPatternModifierTitle"))
                        }
                    }
                }
            }
            .navigationTitle(LocalizedStringKey("SettingsTitle"))
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct SettingsSentenceFormatView: View {
    @Binding var formatString: String
    
    var body: some View {
        VStack {
            Text(LocalizedStringKey("SettingsDetailFormatPatternDescription"))
            TextField(LocalizedStringKey("SettingsDetailFormatPatternHint"), text: $formatString)
                .onChange(of: formatString) {
                    UserDefaults.standard.set($0, forKey: SETTINGS_KEY_FORMAT_STRING)
                }
        }
        .textFieldStyle(.roundedBorder)
        .navigationTitle(LocalizedStringKey("SettingsDetailFormatPatternTitle"))
        .navigationBarTitleDisplayMode(.large)
        .padding(.horizontal, 40)
        .frame(maxWidth: .infinity)
    }
}

struct SettingsSentenceFormatModifierView: View {
    @Binding var modifiers: [FormatPatternModifier]
    
    var body: some View {
        List {
            ForEach($modifiers) { $modifier in
                HStack {
                    TextField(LocalizedStringKey("SettingsDetailFormatPatternModifierPrefixLabel"), text: $modifier.prefix, axis: .vertical)
                        .multilineTextAlignment(.trailing)
                        .onChange(of: modifier.prefix) { _ in
                            UserDefaults.standard.set(try! JSONEncoder().encode(modifiers), forKey: SETTINGS_KEY_FORMAT_MODIFIERS)
                        }
                    Text(modifier.id.rawValue)
                    TextField(LocalizedStringKey("SettingsDetailFormatPatternModifierSuffixLabel"), text: $modifier.suffix, axis: .vertical)
                        .onChange(of: modifier.suffix) { _ in
                            UserDefaults.standard.set(try! JSONEncoder().encode(modifiers), forKey: SETTINGS_KEY_FORMAT_MODIFIERS)
                        }
                }
            }
        }
        .textFieldStyle(.roundedBorder)
        .navigationTitle(LocalizedStringKey("SettingsDetailFormatPatternModifierTitle"))
        .navigationBarTitleDisplayMode(.large)
        .padding()
        .frame(maxWidth: .infinity)
    }
}
