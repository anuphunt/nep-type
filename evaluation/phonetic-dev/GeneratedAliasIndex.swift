import Foundation

/// Sorted UTF-8 alias index. Mapping the file keeps startup independent of its
/// number of rows; binary search never promotes an alias to a default choice.
enum GeneratedAliasIndex {
    private static let data: Data? = {
        let url: URL?
        if let path = ProcessInfo.processInfo.environment["NEPTYPE_ALIAS_INDEX"], !path.isEmpty {
            url = URL(fileURLWithPath: path)
        } else {
            url = Bundle.main.resourceURL?.appendingPathComponent("google-ne-aliases.tsv")
        }
        guard let url else { return nil }
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }()

    private static let aksharantarData: Data? = {
        let url: URL?
        if let path = ProcessInfo.processInfo.environment["NEPTYPE_AKSHARANTAR_INDEX"], !path.isEmpty {
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
        let key = Array(word.utf8)
        guard !key.isEmpty, key.allSatisfy({ $0 >= 97 && $0 <= 122 }) else { return [] }
        var low = 0
        var high = data.count
        while low < high {
            let midpoint = low + (high - low) / 2
            var start = midpoint
            while start > low && data[start - 1] != 10 { start -= 1 }
            var end = start
            while end < data.count && data[end] != 10 { end += 1 }
            var tab = start
            while tab < end && data[tab] != 9 { tab += 1 }
            let foundKey = data[start..<tab]
            if foundKey.elementsEqual(key) {
                guard tab < end, let text = String(data: data[(tab + 1)..<end], encoding: .utf8) else { return [] }
                return text.split(separator: "\t").map(String.init)
            }
            if foundKey.lexicographicallyPrecedes(key) { low = min(end + 1, data.count) }
            else { high = start }
        }
        return []
    }
}
