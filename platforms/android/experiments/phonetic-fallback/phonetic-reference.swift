import Foundation
let engine = Transliterator()
while let line = readLine() { print(engine.phonetic(line)) }
