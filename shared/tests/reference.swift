import Foundation
import NepaliCore
let arguments = CommandLine.arguments
let dictionaries = try EngineDictionaries(directory: URL(fileURLWithPath: arguments[1]))
let engine = Transliterator(dictionaries: dictionaries)
let mode = [TypingLanguage.nepali, .english, .allNepali][Int(arguments[2])!]
for token in arguments.dropFirst(3) {
    var session = InputSession(engine: engine)
    session.setLanguage(mode)
    let values = session.append(token) ? session.candidates : [token]
    print(values.map { $0.utf8.map { String(format: "%02x", $0) }.joined() }.joined(separator: "\t"))
}
