import Foundation

struct CatalogExercise: Decodable, Identifiable {
    let id: String
    let name_it: String
    let aliases: [String]
    let category: String
    let primary_muscles: [String]
    let equipment: [String]
}
private struct CatalogEnvelope: Decodable { let exercises: [CatalogExercise] }

enum ExerciseCatalog {
    static let all: [CatalogExercise] = {
        guard let url = Bundle.main.url(forResource: "exercise_catalog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let result = try? JSONDecoder().decode(CatalogEnvelope.self, from: data) else { return [] }
        return result.exercises
    }()
    static func search(_ query: String) -> [CatalogExercise] {
        let q = query.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Array(all.prefix(35)) }
        return Array(all.filter { ex in
            ([ex.name_it] + ex.aliases).contains { $0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).contains(q) }
        }.prefix(35))
    }
}
