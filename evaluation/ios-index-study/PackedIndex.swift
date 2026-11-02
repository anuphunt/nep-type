import Foundation
import zlib

/// Experimental read-only packed index. Not part of the shipped extension.
/// Each bounded zlib block is independently decoded; source bytes are identical
/// to the sorted TSV input and zlib validates the block checksum.
struct PackedIndex {
    private struct Block { let key: [UInt8]; let offset: Int; let compressed: Int; let raw: Int }
    private let data: Data
    private let blocks: [Block]
    private let payload: Int
    init?(path: String) {
        guard let bytes = try? Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe), bytes.count >= 44,
              Array(bytes[0..<4]) == [76,75,73,49] else { return nil }
        func integer(_ offset: Int, _ count: Int) -> UInt64? {
            guard offset >= 0, count <= 8, offset <= bytes.count - count else { return nil }
            var v: UInt64 = 0
            for i in 0..<count { v |= UInt64(bytes[offset+i]) << (8*i) }
            return v
        }
        guard let n = integer(4,4), n > 0, n <= 100_000 else { return nil }
        var cursor = 44, result: [Block] = [], expectedOffset = 0
        for _ in 0..<Int(n) {
            guard cursor < bytes.count else { return nil }
            let len = Int(bytes[cursor]); cursor += 1
            guard len > 0, cursor <= bytes.count-len else { return nil }
            let key = Array(bytes[cursor..<cursor+len]); cursor += len
            guard key.allSatisfy({ (97...122).contains($0) }),
                  (result.last == nil || result.last!.key.lexicographicallyPrecedes(key)),
                  let offset = integer(cursor,8), let compressed = integer(cursor+8,4), let raw = integer(cursor+12,4),
                  offset == UInt64(expectedOffset), compressed > 0, compressed <= 131072, raw > 0, raw <= 65536 else { return nil }
            cursor += 16
            expectedOffset += Int(compressed)
            result.append(Block(key: key, offset: Int(offset), compressed: Int(compressed), raw: Int(raw)))
        }
        guard cursor <= bytes.count, expectedOffset == bytes.count-cursor else { return nil }
        self.data = bytes; self.blocks = result; self.payload = cursor
    }
    func lookup(_ word: String) -> [String] {
        let key = Array(word.utf8)
        guard !key.isEmpty, key.allSatisfy({ (97...122).contains($0) }) else { return [] }
        var lo = 0, hi = blocks.count
        while lo < hi {
            let mid = lo + (hi-lo)/2
            if !key.lexicographicallyPrecedes(blocks[mid].key) { lo = mid+1 } else { hi = mid }
        }
        guard lo > 0 else { return [] }
        let block = blocks[lo-1]
        var raw = Data(count: block.raw)
        var outputLength = uLongf(block.raw)
        let status: Int32 = raw.withUnsafeMutableBytes { output in
            data.withUnsafeBytes { input in
                let dest = output.bindMemory(to: Bytef.self).baseAddress!
                let src = input.bindMemory(to: Bytef.self).baseAddress!.advanced(by: payload+block.offset)
                return uncompress(dest, &outputLength, src, uLong(block.compressed))
            }
        }
        guard status == Z_OK, outputLength == block.raw else { return [] }
        var low = 0, high = raw.count
        while low < high {
            let midpoint = low + (high-low)/2
            var start = midpoint
            while start > low && raw[start-1] != 10 { start -= 1; if midpoint-start > 4096 { return [] } }
            var end = start
            while end < raw.count && raw[end] != 10 { end += 1; if end-start > 4096 { return [] } }
            guard end < raw.count else { return [] }
            var tab = start
            while tab < end && raw[tab] != 9 { tab += 1 }
            let found = raw[start..<tab]
            if found.elementsEqual(key) {
                guard tab < end, let text = String(data: raw[(tab+1)..<end], encoding: .utf8) else { return [] }
                let values = text.split(separator: "\t", omittingEmptySubsequences: false)
                guard !values.isEmpty, values.count <= 64, values.allSatisfy({ value in
                    !value.unicodeScalars.isEmpty && value.unicodeScalars.count <= 60 && value.unicodeScalars.allSatisfy {
                        (0x0900...0x097F).contains($0.value) || $0.value == 0x200C || $0.value == 0x200D
                    }
                }) else { return [] }
                return values.map(String.init)
            }
            if found.lexicographicallyPrecedes(key) { low = min(end+1, raw.count) } else { high = start }
        }
        return []
    }
}
