import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system, french = "fr", english = "en"
    var id: String { rawValue }

    func resolvedCode(preferredLanguages: [String] = Locale.preferredLanguages) -> String {
        if self != .system { return rawValue }
        return preferredLanguages.first?.lowercased().hasPrefix("fr") == true ? "fr" : "en"
    }

    var title: String {
        switch self {
        case .system: String(localized: "Automatique (langue du Mac)", bundle: L10n.bundle)
        case .french: "Français"
        case .english: "English"
        }
    }
}

/// Language preferences are independent of charging settings and never issue commands.
@MainActor
final class LanguageSettings: ObservableObject {
    static let shared = LanguageSettings()
    static let preferenceKey = "interfaceLanguage"
    private let defaults: UserDefaults
    @Published var selection: AppLanguage {
        didSet { defaults.set(selection.rawValue, forKey: Self.preferenceKey) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = AppLanguage(rawValue: defaults.string(forKey: Self.preferenceKey) ?? "system") ?? .system
    }
}

enum L10n {
    static var languageCode: String {
        let choice = AppLanguage(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "system") ?? .system
        return choice.resolvedCode()
    }

    static var bundle: Bundle { bundle(for: languageCode) }

    static func documentationURL(_ address: String) -> URL {
        let localized = languageCode == "fr" ? address : address
            .replacingOccurrences(of: "support.apple.com/fr-fr/", with: "support.apple.com/en-us/")
            .replacingOccurrences(of: "www.apple.com/fr/batteries/", with: "www.apple.com/batteries/")
        return URL(string: localized)!
    }

    static func bundle(for languageCode: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}

/// Refreshes presentation immediately without restarting the app or its helper.
struct LocalizedRoot<Content: View>: View {
    @ObservedObject private var language = LanguageSettings.shared
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .environment(\.locale, Locale(identifier: language.selection.resolvedCode()))
            .id(language.selection)
            .tint(AppPalette.accent)
    }
}
