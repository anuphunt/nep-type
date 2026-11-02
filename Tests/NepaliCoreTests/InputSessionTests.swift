import XCTest
@testable import NepaliCore

final class InputSessionTests: XCTestCase {
    override class func setUp() {
        super.setUp()
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        setenv("LEKHA_ALIAS_INDEX", project.appendingPathComponent("data/compiled/google-ne-aliases.tsv").path, 1)
        setenv("LEKHA_AKSHARANTAR_INDEX", project.appendingPathComponent("data/compiled/aksharantar-indiccorp-v1.tsv").path, 1)
    }

    func testIncrementalCompositionAndCommit() {
        var session = InputSession()
        XCTAssertTrue(session.append("m")); XCTAssertTrue(session.append("a"))
        XCTAssertEqual(session.markedText, "म")
        XCTAssertTrue(session.candidates.contains("ma"))
        XCTAssertEqual(session.commit(keepContext: true), "म")
        XCTAssertFalse(session.isComposing)
        XCTAssertEqual(session.context, ["ma"])
    }

    func testContextChangesAmbiguousWord() {
        var english = InputSession()
        XCTAssertTrue(english.append("the")); XCTAssertEqual(english.commit(keepContext: true), "the")
        XCTAssertTrue(english.append("man")); XCTAssertEqual(english.markedText, "man")
        var nepali = InputSession()
        XCTAssertTrue(nepali.append("mero")); XCTAssertEqual(nepali.commit(keepContext: true), "मेरो")
        XCTAssertTrue(nepali.append("man")); XCTAssertEqual(nepali.markedText, "मन")
        XCTAssertEqual(english.markedText, "man") // sessions are isolated
    }

    func testSentencePunctuationStopsContextAtBoundary() {
        let engine = Transliterator()
        for prefix in ["the.", "the,", "the?", "the!"] {
            var session = InputSession()
            XCTAssertTrue(session.append(prefix))
            _ = session.commit(keepContext: true)
            XCTAssertTrue(session.context.isEmpty, "Context leaked after \(prefix)")
            XCTAssertTrue(session.append("man"))
            XCTAssertEqual(session.markedText, engine.contextChoices(in: "man")[0].preferred)
        }
        var quoted = InputSession()
        XCTAssertTrue(quoted.append("the")); _ = quoted.commit(keepContext: true)
        XCTAssertTrue(quoted.append("(man"))
        XCTAssertEqual(quoted.markedText, "(" + engine.contextChoices(in: "man")[0].preferred)
    }

    func testNepaliSentenceStopAndOriginalAreAvailable() {
        var session = InputSession()
        XCTAssertTrue(session.append("namaste."))
        XCTAssertEqual(session.markedText, "नमस्ते।")
        XCTAssertTrue(session.candidates.contains("namaste."))
        XCTAssertTrue(session.select("namaste."))
        XCTAssertEqual(session.commit(keepContext: true), "namaste.")
        XCTAssertTrue(session.append("namaste."))
        XCTAssertEqual(session.commit(keepContext: true), "नमस्ते।")
        XCTAssertTrue(session.context.isEmpty)
        XCTAssertTrue(session.append("ma")); _ = session.commit(keepContext: true)
        XCTAssertTrue(session.append("office."))
        XCTAssertEqual(session.markedText, "office।")
        XCTAssertTrue(session.candidates.contains("office."))
        var english = InputSession()
        XCTAssertTrue(english.append("office."))
        XCTAssertEqual(english.markedText, "office.")
    }

    func testSentenceStateDoesNotCrossResetCancelOrModeChange() {
        for boundary in 0..<3 {
            var session = InputSession()
            XCTAssertTrue(session.append("ma")); _ = session.commit(keepContext: true)
            if boundary == 0 { session.reset() }
            if boundary == 1 { XCTAssertTrue(session.append("x")); _ = session.cancel() }
            if boundary == 2 { session.setLanguage(.english); session.setLanguage(.nepali) }
            XCTAssertTrue(session.append("office."))
            XCTAssertEqual(session.markedText, "office.")
        }
    }

    func testTerminalStopPreservesLiteralsEllipsesAndAbbreviations() {
        for (source, expected) in [("namaste...", "नमस्ते..."), ("Dr.", "Dr."), ("ma.com", "ma.com"), ("3.14", "3.14")] {
            var session = InputSession(); XCTAssertTrue(session.append(source))
            XCTAssertEqual(session.markedText, expected, source)
        }
        var session = InputSession(); XCTAssertTrue(session.append("ma."))
        XCTAssertEqual(session.markedText, "म।")
        XCTAssertTrue(session.append("com"))
        XCTAssertEqual(session.markedText, "ma.com")
        XCTAssertEqual(session.cancel(), "ma.com")
    }

    func testAllNepaliModeComposesEnglishAndPreservesLiteralChoices() {
        var session = InputSession()
        session.setLanguage(.allNepali)
        XCTAssertTrue(session.append("office"))
        XCTAssertNotEqual(session.markedText, "office")
        XCTAssertTrue(session.markedText.unicodeScalars.contains { (0x0900...0x097F).contains($0.value) })
        XCTAssertTrue(session.candidates.contains("office"))
        XCTAssertTrue(session.select("office"))
        XCTAssertEqual(session.commit(), "office")
        XCTAssertTrue(session.append("example.com"))
        XCTAssertEqual(session.markedText, "example.com")
        XCTAssertEqual(session.cancel(), "example.com")
        XCTAssertTrue(session.append("office."))
        XCTAssertTrue(session.markedText.hasSuffix("।"))
        XCTAssertTrue(session.candidates.contains("office."))
    }

    func testSelectionCancelBackspaceAndReset() {
        var session = InputSession()
        XCTAssertTrue(session.append("pani")); XCTAssertTrue(session.select("पानी"))
        XCTAssertEqual(session.markedText, "पानी")
        XCTAssertEqual(session.cancel(), "pani")
        XCTAssertFalse(session.isComposing)
        XCTAssertTrue(session.append("namaste")); XCTAssertTrue(session.backspace())
        XCTAssertEqual(session.roman, "namast")
        session.reset(); XCTAssertFalse(session.backspace()); XCTAssertNil(session.commit())
    }

    func testLanguageModeAndUnacceptedEvents() {
        var session = InputSession()
        XCTAssertFalse(session.append("नमस्ते")); XCTAssertFalse(session.append("a b"))
        session.setLanguage(.english); XCTAssertFalse(session.append("hello"))
        session.setLanguage(.nepali); XCTAssertTrue(session.append("hello"))
        XCTAssertEqual(session.cancel(), "hello")
    }

    func testExplicitLanguageToggleAndSessionIsolation() {
        var first = InputSession()
        var second = InputSession()
        XCTAssertTrue(first.append("namaste"))
        XCTAssertEqual(first.commit(), "नमस्ते")
        first.toggleLanguage()
        XCTAssertFalse(first.append("hello"))
        XCTAssertTrue(second.append("namaste"))
        XCTAssertEqual(second.cancel(), "namaste")
        first.toggleLanguage()
        XCTAssertTrue(first.append("ma"))
        XCTAssertEqual(first.cancel(), "ma")
    }

    func testTokenRemainsUncommittedUntilLiteralBecomesRecognizable() {
        let literals = ["https://example.com/a?x=1", "www.example.com", "user@example.com", "src/main.swift", "my_var", "foo.bar", "myVar", "thing123", "const=ma"]
        for literal in literals {
            var session = InputSession()
            for character in literal { XCTAssertTrue(session.append(String(character)), literal) }
            XCTAssertEqual(session.markedText, literal, literal)
            XCTAssertEqual(session.candidates, [literal], literal)
            XCTAssertEqual(session.commit(), literal, literal)
        }
        var session = InputSession()
        XCTAssertTrue(session.append("ma")); XCTAssertEqual(session.markedText, "म")
        XCTAssertTrue(session.append(".")); XCTAssertEqual(session.markedText, "म।")
        XCTAssertTrue(session.append("com")); XCTAssertEqual(session.markedText, "ma.com")
        XCTAssertEqual(session.cancel(), "ma.com")
    }

    func testSentencePunctuationAndLiteralBackspace() {
        var session = InputSession()
        XCTAssertTrue(session.append("(namaste!),"))
        XCTAssertEqual(session.markedText, "(नमस्ते!),")
        XCTAssertEqual(session.commit(), "(नमस्ते!),")
        XCTAssertTrue(session.append("ma_x")); XCTAssertEqual(session.markedText, "ma_x")
        XCTAssertTrue(session.backspace()); XCTAssertTrue(session.backspace())
        XCTAssertEqual(session.markedText, "म")
        XCTAssertEqual(session.cancel(), "ma")
    }

    func testBackticksPersistAcrossWhitespaceAndResetAtFocusBoundary() {
        var session = InputSession()
        XCTAssertTrue(session.append("`ma")); XCTAssertEqual(session.commit(keepContext: true, keepLiteralState: true), "`ma")
        XCTAssertTrue(session.append("mero")); XCTAssertEqual(session.commit(keepContext: true, keepLiteralState: true), "mero")
        XCTAssertTrue(session.append("ho`")); XCTAssertEqual(session.commit(keepContext: true, keepLiteralState: true), "ho`")
        XCTAssertTrue(session.append("ma")); XCTAssertEqual(session.commit(), "म")
        XCTAssertTrue(session.append("`ma")); _ = session.commit(keepLiteralState: true)
        session.reset()
        XCTAssertTrue(session.append("ma")); XCTAssertEqual(session.commit(), "म")
    }

    func testIncompleteCodeDelimiterBackspaceDoesNotLeakMode() {
        var session = InputSession()
        XCTAssertTrue(session.append("`")); XCTAssertTrue(session.backspace())
        XCTAssertTrue(session.append("ma")); XCTAssertEqual(session.commit(keepLiteralState: true), "म")
        XCTAssertTrue(session.append("ma")); XCTAssertEqual(session.commit(), "म")
    }

    func testCandidateCyclingAndContextLimit() {
        var session = InputSession()
        XCTAssertTrue(session.append("pani"))
        let original = session.markedText
        session.cycle(1); XCTAssertNotEqual(session.markedText, original)
        session.cycle(-1); XCTAssertEqual(session.markedText, original)
        _ = session.commit(keepContext: true)
        for _ in 0..<7 { XCTAssertTrue(session.append("ma")); _ = session.commit(keepContext: true) }
        XCTAssertEqual(session.context.count, 4)
        session.reset(); XCTAssertTrue(session.context.isEmpty)
    }
}
