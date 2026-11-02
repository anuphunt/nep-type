#!/usr/bin/env python3
"""Exercise the current picker's runtime catalog/search in an isolated Swift process.

Reads the app source and extracts its exact catalog and system catalog builder.
The whitespace-token search predicate is mirrored below, and the script refuses
to run if the corresponding app-source expression has changed. No app files are
written, installed, or sent over the network.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

root = Path(__file__).resolve().parent
project_source = root.parents[1] / "Sources/NepaliKeyboard/main.swift"
workspace_source = root.parent / "neptype-dev/Sources/NepaliKeyboard/main.swift"
source = Path(sys.argv[1]) if len(sys.argv) > 1 else (project_source if project_source.exists() else workspace_source)
raw = source.read_text(encoding="utf-8")
catalog = raw[raw.index("    lazy var emojiCatalog:"):raw.index("    var statusItem:")]
builder = raw[raw.index("    static func systemEmojiCatalog("):raw.index("    func applicationDidFinishLaunching(")]
checks = ["query.split(whereSeparator: { $0.isWhitespace }).map(String.init)",
          "terms.allSatisfy { item.element.1.contains($0) || item.element.0.contains($0) }"]
if not all(x in raw for x in checks):
    raise SystemExit("Picker search implementation changed; review evaluator before use")
swift = '''import Foundation
struct Case: Decodable { let category: String; let query: String; let expected: [String] }
final class Catalog {
''' + catalog + builder + '''}
let fixture = try JSONDecoder().decode([Case].self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let catalog = Catalog().emojiCatalog
var rows: [[String: Any]] = []
var summary: [String: [String: Int]] = [:]
for item in fixture {
    let terms = item.query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased().split(whereSeparator: { $0.isWhitespace }).map(String.init)
    let matches = catalog.filter { entry in terms.isEmpty || terms.allSatisfy { entry.1.contains($0) || entry.0.contains($0) } }
    // Research-only alternative: word-prefix matching, never installed.
    let prefixMatches = catalog.filter { entry in
        let words = entry.1.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init)
        return terms.isEmpty || terms.allSatisfy { term in words.contains { $0.hasPrefix(term) } || entry.0.contains(term) }
    }
    func bytesEqual(_ left: String, _ right: String) -> Bool { Array(left.utf8) == Array(right.utf8) }
    let rank = matches.firstIndex { match in item.expected.contains { bytesEqual($0, match.0) } }
    let prefixRank = prefixMatches.firstIndex { match in item.expected.contains { bytesEqual($0, match.0) } }
    summary[item.category, default: [:]]["queries", default: 0] += 1
    if rank != nil { summary[item.category, default: [:]]["found", default: 0] += 1 }
    if let rank, rank < 24 { summary[item.category, default: [:]]["first_page", default: 0] += 1 }
    if prefixRank != nil { summary[item.category, default: [:]]["prefix_found", default: 0] += 1 }
    rows.append(["category":item.category,"query":item.query,"expected":item.expected,"found":rank != nil,"rank_zero_based":rank.map { $0 as Any } ?? NSNull(),"match_count":matches.count,"first_results":matches.prefix(5).map { ["emoji":$0.0,"name":$0.1] },"prefix_found":prefixRank != nil,"prefix_count":prefixMatches.count,"prefix_first_results":prefixMatches.prefix(5).map { ["emoji":$0.0,"name":$0.1] }])
}
let output: [String: Any] = ["catalog_count":catalog.count,"summary":summary,"cases":rows]
let data = try JSONSerialization.data(withJSONObject: output, options: [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes])
FileHandle.standardOutput.write(data); FileHandle.standardOutput.write(Data("\\n".utf8))
'''
with tempfile.TemporaryDirectory(prefix="neptype-emoji-study-") as temp:
    temp = Path(temp)
    (temp / "main.swift").write_text(swift, encoding="utf-8")
    subprocess.run(["xcrun", "swiftc", "-O", "-module-cache-path", str(temp / "cache"), str(temp / "main.swift"), "-o", str(temp / "evaluate")], check=True)
    run = subprocess.run([str(temp / "evaluate"), str(root / "cases.json")], check=True, capture_output=True)
    result = json.loads(run.stdout)
result["app_source_sha256"] = hashlib.sha256(source.read_bytes()).hexdigest()
result["fixture_sha256"] = hashlib.sha256((root / "cases.json").read_bytes()).hexdigest()
result["method"] = "Exact extracted catalog, mirrored current whitespace/substring predicate; full UTF-8 emoji equality; not GUI/VoiceOver testing"
print(json.dumps(result, ensure_ascii=False, indent=2))
