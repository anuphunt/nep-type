import Foundation

/// Sorted UTF-8 alias index. Mapping the file keeps startup independent of its
/// number of rows; binary search never promotes an alias to a default choice.
enum GeneratedAliasIndex {
    private static let data: Data? = {
        let url: URL?
        if let path = ProcessInfo.processInfo.environment["LEKHA_ALIAS_INDEX"], !path.isEmpty {
            url = URL(fileURLWithPath: path)
        } else {
            url = Bundle.main.resourceURL?.appendingPathComponent("google-ne-aliases.tsv")
        }
        guard let url else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }()

    private static let aksharantarData: Data? = {
        let url: URL?
        if let path = ProcessInfo.processInfo.environment["LEKHA_AKSHARANTAR_INDEX"], !path.isEmpty {
            url = URL(fileURLWithPath: path)
        } else {
            url = Bundle.main.resourceURL?.appendingPathComponent("aksharantar-indiccorp-v1.tsv")
        }
        guard let url else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }()

    static func lookup(_ word: String) -> [String] { lookup(word, data: data) }
    static func aksharantarLookup(_ word: String) -> [String] { lookup(word, data: aksharantarData) }

    private static func lookup(_ word: String, data: Data?) -> [String] {
        guard let data, !data.isEmpty else { return [] }
        // The generated indexes contain short Devanagari words. Treat any
        // oversized or malformed row as unavailable, not as trusted input:
        // a corrupt unique row must never become an automatic replacement.
        let maxRowBytes = 4096, maxCandidates = 64, maxScalars = 60
        let key = Array(word.utf8)
        guard !key.isEmpty, key.allSatisfy({ $0 >= 97 && $0 <= 122 }) else { return [] }
        var low = 0
        var high = data.count
        while low < high {
            let midpoint = low + (high - low) / 2
            var start = midpoint
            while start > low && data[start - 1] != 10 {
                start -= 1
                if midpoint - start > maxRowBytes { return [] }
            }
            var end = start
            while end < data.count && data[end] != 10 {
                end += 1
                if end - start > maxRowBytes { return [] }
            }
            // Both reproducible builders terminate every row with newline;
            // an unterminated final row may be a truncated candidate.
            guard end < data.count else { return [] }
            var tab = start
            while tab < end && data[tab] != 9 { tab += 1 }
            let foundKey = data[start..<tab]
            if foundKey.elementsEqual(key) {
                guard tab < end, let text = String(data: data[(tab + 1)..<end], encoding: .utf8) else { return [] }
                let values = text.split(separator: "\t", omittingEmptySubsequences: false)
                guard !values.isEmpty, values.count <= maxCandidates,
                      values.allSatisfy({ value in
                          let scalars = value.unicodeScalars
                          return !scalars.isEmpty && scalars.count <= maxScalars && scalars.allSatisfy {
                              (0x0900...0x097F).contains($0.value) || $0.value == 0x200C || $0.value == 0x200D
                          }
                      }) else { return [] }
                return values.map(String.init)
            }
            if foundKey.lexicographicallyPrecedes(key) { low = min(end + 1, data.count) }
            else { high = start }
        }
        return []
    }
}
