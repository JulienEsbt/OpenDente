import SwiftUI

private struct GuideEntry: Decodable, Identifiable {
    let title: String
    let detail: String
    let url: URL?
    var id: String { title }
}
private struct GuideSection: Decodable, Identifiable {
    let title: String
    var entries: [GuideEntry]
    var id: String { title }
}

/// Offline help bundled with the app; no remote page or tracking is loaded.
struct GuideTab: View {
    @State private var query = ""
    private static let localizedSections: [String: [GuideSection]] = {
        var result: [String: [GuideSection]] = [:]
        for code in ["fr", "en"] {
            let bundle = L10n.bundle(for: code)
            let url = bundle.url(forResource: "OpenDenteGuide", withExtension: "json")
                ?? Bundle.main.url(forResource: "OpenDenteGuide", withExtension: "json")
            if let url, let data = try? Data(contentsOf: url),
               let sections = try? JSONDecoder().decode([GuideSection].self, from: data) {
                result[code] = sections
            }
        }
        return result
    }()
    private var sections: [GuideSection] { Self.localizedSections[L10n.languageCode] ?? [] }
    private var filtered: [GuideSection] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return sections }
        return sections.compactMap { section in
            if section.title.localizedCaseInsensitiveContains(query) { return section }
            var result = section
            result.entries = section.entries.filter {
                $0.title.localizedCaseInsensitiveContains(query) || $0.detail.localizedCaseInsensitiveContains(query)
            }
            return result.entries.isEmpty ? nil : result
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField(String(localized: "Rechercher une commande ou une fonction…", bundle: L10n.bundle), text: $query)
                .textFieldStyle(.roundedBorder).accessibilityLabel(String(localized: "Rechercher dans le guide", bundle: L10n.bundle))
                .padding([.top, .horizontal])
            if sections.isEmpty {
                Text(String(localized: "Le guide n’a pas pu être chargé depuis l’application.", bundle: L10n.bundle)).padding()
            } else if filtered.isEmpty {
                Text(String(localized: "Aucune commande ne correspond à cette recherche.", bundle: L10n.bundle)).padding()
            } else {
                List {
                    ForEach(filtered) { section in
                        Section(section.title) {
                            ForEach(section.entries) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.title).fontWeight(.semibold)
                                    Text(entry.detail).font(.callout).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                                    if let url = entry.url { Link(String(localized: "Consulter la source", bundle: L10n.bundle), destination: url) }
                                }
                                .padding(.vertical, 5)
                            }
                        }
                    }
                }
            }
        }
    }
}
