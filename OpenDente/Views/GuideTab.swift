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
    private static let sections: [GuideSection] = {
        guard let url = Bundle.main.url(forResource: "OpenDenteGuide", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let sections = try? JSONDecoder().decode([GuideSection].self, from: data) else { return [] }
        return sections
    }()
    private var filtered: [GuideSection] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return Self.sections }
        return Self.sections.compactMap { section in
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
            TextField("Rechercher une commande ou une fonction…", text: $query)
                .textFieldStyle(.roundedBorder).accessibilityLabel("Rechercher dans le guide")
                .padding([.top, .horizontal])
            if Self.sections.isEmpty {
                Text("Le guide n’a pas pu être chargé depuis l’application.").padding()
            } else if filtered.isEmpty {
                Text("Aucune commande ne correspond à cette recherche.").padding()
            } else {
                List {
                    ForEach(filtered) { section in
                        Section(section.title) {
                            ForEach(section.entries) { entry in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(entry.title).fontWeight(.semibold)
                                    Text(entry.detail).font(.callout).foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true).textSelection(.enabled)
                                    if let url = entry.url { Link("Consulter la source", destination: url) }
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
