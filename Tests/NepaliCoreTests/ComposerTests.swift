import XCTest
@testable import NepaliCore

final class ComposerTests: XCTestCase {
    func testCopiedComposerHasIndependentRustHistory() {
        var original = Composer()
        original.setSource("ma pani")
        var copy = original
        let token = copy.engine.tokens(in: copy.state.source).last!
        copy.choose("पानी", for: token)
        XCTAssertEqual(original.output, "म पनि")
        XCTAssertEqual(copy.output, "म पानी")
        copy.undo()
        XCTAssertEqual(copy.output, original.output)
        original.setSource("namaste")
        XCTAssertEqual(copy.output, "म पनि")
    }

    func testLongDocumentHistoryStaysInsideRust() {
        var composer = Composer()
        let prefix = String(repeating: " ", count: 80_000)
        for index in 0..<110 { composer.setSource(prefix + "namaste" + String(index)) }
        XCTAssertEqual(composer.state.source, prefix + "namaste109")
        composer.undo()
        XCTAssertEqual(composer.state.source, prefix + "namaste108")
        composer.redo()
        XCTAssertEqual(composer.state.source, prefix + "namaste109")
    }
    override class func setUp() {
        super.setUp()
        let project = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        setenv("NEPTYPE_ALIAS_INDEX", project.appendingPathComponent("data/compiled/google-ne-aliases.tsv").path, 1)
        setenv("NEPTYPE_AKSHARANTAR_INDEX", project.appendingPathComponent("data/compiled/aksharantar-indiccorp-v1.tsv").path, 1)
    }
    let engine = Transliterator()

    func testMaileUsesNepaliSpellingDespiteEnglishDictionaryMembership() {
        XCTAssertTrue(engine.isKnownEnglish("maile"))
        for word in ["maile", "Maile"] {
            XCTAssertEqual(engine.render(word), "मैले")
            XCTAssertEqual(engine.render("\(word) yo"), "मैले यो")
            XCTAssertEqual(engine.render("\(word) office"), "मैले office")
            XCTAssertEqual(engine.render(word, language: .allNepali), "मैले")
            XCTAssertEqual(engine.render(word, language: .english), word)
            XCTAssertEqual(engine.candidates(for: word).first, "मैले")
            XCTAssertTrue(engine.candidates(for: word).contains(word))
            XCTAssertEqual(engine.render(word, overrides: [0: word]), word)
        }
    }

    func testUndoRedoAcrossEmojiInsertionAndCandidateSelection() {
        var composer = Composer()
        composer.setSource("ma pani")
        let token = engine.tokens(in: composer.state.source).last!
        composer.choose("पानी", for: token)
        XCTAssertEqual(composer.output, "म पानी")
        composer.setSource("👋 ma pani")
        XCTAssertEqual(composer.output, "👋 म पानी")
        // A stale pre-insertion range must never edit a later word.
        let beforeStale = composer.state
        composer.choose("पानी", for: token)
        XCTAssertEqual(composer.state, beforeStale)
        composer.undo()
        XCTAssertEqual(composer.output, "म पानी")
        composer.undo()
        XCTAssertEqual(composer.output, "म पनि")
        composer.redo()
        XCTAssertEqual(composer.output, "म पानी")
        composer.redo()
        XCTAssertEqual(composer.output, "👋 म पानी")
        composer.undo()
        composer.setSource("ma ghar")
        XCTAssertFalse(composer.canRedo, "New edits must discard the abandoned redo branch")
    }

    func testCorrectionSurvivesTypingAfterWordBoundary() {
        var composer = Composer()
        composer.setSource("ma pani")
        let token = engine.tokens(in: composer.state.source).last!
        composer.choose("पानी", for: token)
        composer.setSource("ma pani ")
        XCTAssertEqual(composer.output, "म पानी ")
        composer.setSource("ma pani cha.")
        XCTAssertEqual(composer.output, "म पानी छ।")
        composer.undo()
        XCTAssertEqual(composer.output, "म पानी ")
        composer.redo()
        XCTAssertEqual(composer.output, "म पानी छ।")
    }

    func testCorrectionDropsWhenWordChangesOrBecomesLiteral() {
        var composer = Composer()
        composer.setSource("ma pani")
        composer.choose("पानी", for: engine.tokens(in: composer.state.source).last!)
        composer.setSource("ma panima")
        XCTAssertNil(composer.state.overrides[3])
        composer.undo()
        XCTAssertEqual(composer.output, "म पानी")
        composer.setSource("ma pani.com")
        XCTAssertNil(composer.state.overrides[3])
        XCTAssertTrue(composer.output.contains("pani.com"))
    }

    func testEarlierEditsDiscardChangedWordButKeepUntouchedLaterWord() {
        var composer = Composer()
        composer.setSource("👋 ma pani ma")
        let words = engine.tokens(in: composer.state.source)
        composer.choose("पानी", for: words[1])
        composer.choose("मा", for: words[2])
        composer.setSource("👋 ma pani ma ")
        XCTAssertEqual(composer.state.overrides[words[1].range.location], "पानी")
        XCTAssertEqual(composer.state.overrides[words[2].range.location], "मा")
        composer.setSource("👋 ma panima ma ")
        XCTAssertNil(composer.state.overrides[words[1].range.location])
        let later = engine.tokens(in: composer.state.source).last!
        XCTAssertEqual(composer.state.overrides[later.range.location], "मा")
    }

    func testCorrectionMovesWithUntouchedWordAcrossEarlierEdits() {
        var composer = Composer()
        composer.setSource("ma pani cha")
        composer.choose("पानी", for: engine.tokens(in: composer.state.source)[1])
        composer.setSource("👋 aaja ma pani cha")
        let moved = engine.tokens(in: composer.state.source).first { $0.text == "pani" }!
        XCTAssertEqual(composer.state.overrides[moved.range.location], "पानी")
        XCTAssertTrue(composer.output.contains("पानी"))
        composer.undo()
        XCTAssertEqual(composer.output, "म पानी छ")
        composer.redo()
        XCTAssertTrue(composer.output.contains("पानी"))
        composer.setSource("pani cha")
        XCTAssertEqual(composer.state.overrides[0], "पानी")
    }

    func testRepeatedWordInsertionDoesNotTransferAnAmbiguousChoice() {
        var composer = Composer()
        composer.setSource("ma pani cha")
        composer.choose("पानी", for: engine.tokens(in: composer.state.source)[1])
        composer.setSource("ma pani pani cha")
        XCTAssertTrue(composer.state.overrides.isEmpty)
        composer.setSource("pani pani")
        composer.choose("पानी", for: engine.tokens(in: composer.state.source)[1])
        composer.setSource("pani")
        XCTAssertTrue(composer.state.overrides.isEmpty)
    }

    func testMovedCorrectionIsDroppedIfWordBecomesLiteral() {
        var composer = Composer()
        composer.setSource("ma pani cha")
        composer.choose("पानी", for: engine.tokens(in: composer.state.source)[1])
        composer.setSource("aaja ma pani.com cha")
        XCTAssertTrue(composer.state.overrides.isEmpty)
        XCTAssertTrue(composer.output.contains("pani.com"))
    }

    func testContextDistinguishesAmbiguousWordAndOffersCorrection() {
        XCTAssertEqual(engine.render("the man is here"), "the man is here")
        XCTAssertEqual(engine.render("mero man ramro cha"), "मेरो मन राम्रो छ")
        let source = "aaja pani"
        let choice = engine.contextChoices(in: source).last!
        XCTAssertTrue(choice.uncertain)
        XCTAssertEqual(choice.preferred, "पनि")
        XCTAssertTrue(engine.contextualCandidates(for: choice).contains("पानी"))
        var composer = Composer()
        composer.setSource(source)
        composer.choose("पानी", for: choice.token)
        XCTAssertEqual(composer.output, "आज पानी")
        composer.undo()
        XCTAssertEqual(composer.output, "आज पनि")
    }

    func testAuthoredAmbiguityIsVisibleEvenWhenNepaliIsLikely() {
        for (source, word, alternatives) in [
            ("mero pani cha", "pani", ["पनि", "पानी"]),
            ("mero ghar ma", "ma", ["म", "मा"])
        ] {
            let choices = engine.contextChoices(in: source)
            let choice = choices.first { $0.token.text == word }!
            XCTAssertTrue(choice.uncertain, "\(word) has unresolved authored alternatives")
            let offered = engine.contextualCandidates(for: choice)
            for spelling in alternatives { XCTAssertTrue(offered.contains(spelling)) }
            XCTAssertTrue(offered.contains(word))
        }
        let unambiguous = engine.contextChoices(in: "mero ghar")[0]
        XCTAssertFalse(unambiguous.uncertain)
    }

    func testLiteralAndSentenceBoundaries() {
        let text = "ma `some_code()` don't re-enter 👋 https://example.com/mero"
        XCTAssertEqual(engine.render(text), "म `some_code()` don't re-enter 👋 https://example.com/mero")
        let text2 = "the. man"
        let alone = engine.contextChoices(in: "man")[0]
        XCTAssertEqual(engine.contextChoices(in: text2)[1].preferred, alone.preferred)
        let code = "ma ```\nlet test = mero\nreturn man\n``` ghar"
        XCTAssertEqual(engine.render(code), "म ```\nlet test = mero\nreturn man\n``` घर")
    }

    func testIncompleteCodeAndIdentifiersStayLiteralInTypingPad() {
        let samples = [
            "ma `some_code", "ma `mero\nmero", "ma ```\nlet mero = 1",
            "mero obj.dir my_var1 userID version2 src/main.swift",
            "ma HTTPS://EXAMPLE.COM/mero test@example.COM"
        ]
        XCTAssertEqual(engine.render(samples[0]), "म `some_code")
        XCTAssertEqual(engine.render(samples[1]), "म `mero\nमेरो")
        XCTAssertEqual(engine.render(samples[2]), "म ```\nlet mero = 1")
        XCTAssertEqual(engine.render(samples[3]), "मेरो obj.dir my_var1 userID version2 src/main.swift")
        XCTAssertEqual(engine.render(samples[4]), "म HTTPS://EXAMPLE.COM/mero test@example.COM")
        XCTAssertEqual(engine.render("Namaste mero"), "नमस्ते मेरो")
    }

    func testIntentionalDictionarySpellingPrecedesPhoneticFallback() {
        let choices = engine.candidates(for: "bhaisakeko")
        XCTAssertEqual(choices.first, "भइसकेको")
        XCTAssertTrue(engine.dictionaryCandidates(for: "bhaisakeko").contains("भइसकेको"))
        XCTAssertTrue(choices.contains(engine.phonetic("bhaisakeko")))
        XCTAssertTrue(choices.contains("bhaisakeko"))
        XCTAssertEqual(engine.render("aaja bhaisakeko"), "आज भइसकेको")
        var composer = Composer()
        composer.setSource("bhaisakeko")
        composer.choose(engine.phonetic("bhaisakeko"), for: engine.tokens(in: "bhaisakeko")[0])
        XCTAssertEqual(composer.output, "भैसकेको")
        composer.undo()
        XCTAssertEqual(composer.output, "भइसकेको")
    }

    func testTypoSuggestionsStaySeparateFromIntentionalDefaults() {
        XCTAssertTrue(engine.dictionaryCandidates(for: "bato").contains("बाटो"))
        XCTAssertEqual(engine.candidates(for: "bato").first, "बाटो")
        XCTAssertTrue(engine.typoCandidates(for: "bato").contains("बटी"))
        XCTAssertFalse(engine.dictionaryCandidates(for: "bato").contains("बटी"))
        XCTAssertTrue(engine.candidates(for: "bato").contains("bato"))
        XCTAssertEqual(engine.render("bato"), "बाटो")
        XCTAssertFalse(engine.experimentalCandidates(for: "pani").contains("पानी"))
        XCTAssertEqual(Array(engine.candidates(for: "pani").prefix(2)), ["पनि", "पानी"])
        var composer = Composer()
        composer.setSource("bato")
        composer.choose("बटी", for: engine.tokens(in: "bato")[0])
        XCTAssertEqual(composer.output, "बटी")
        composer.undo()
        XCTAssertEqual(composer.output, "बाटो")
    }

    func testGeneralOfflineEnglishMembershipAndSafeAmbiguity() {
        for word in ["architecture", "mountains", "elephant", "photosynthesis", "running", "Coffee", "DOCUMENT", "airport", "happiness"] {
            XCTAssertTrue(engine.isKnownEnglish(word), word)
            XCTAssertTrue(engine.candidates(for: word).contains(word), word)
        }
        XCTAssertFalse(engine.isKnownEnglish("zzqvqxzz"))
        XCTAssertEqual(engine.candidates(for: "pani").first, "पनि")
        XCTAssertEqual(engine.candidates(for: "football").first, "फुटबल")
        XCTAssertEqual(engine.phonetic("zzqvqxzz"), engine.candidates(for: "zzqvqxzz").first)
    }

    func testKnownEnglishBorrowedWordsRetainOriginalAndOfferNepali() {
        let engine = Transliterator()
        for (word, spelling) in [("cricket", "क्रिकेट"), ("basketball", "बास्केटबल"), ("volleyball", "भलिबल")] {
            let choice = engine.contextChoices(in: "ma " + word + " khelchu")[1]
            XCTAssertEqual(choice.preferred, word)
            XCTAssertTrue(choice.uncertain)
            XCTAssertTrue(engine.contextualCandidates(for: choice).contains(spelling))
        }
    }

    func testNaturalPhrasesAndMixedEnglish() {
        XCTAssertEqual(engine.render("namaste, tapai sanchai hunuhuncha?"), "नमस्ते, तपाईं सन्चै हुनुहुन्छ?")
        XCTAssertEqual(engine.render("ma office janchu"), "म office जान्छु")
        XCTAssertEqual(engine.render("bholi meeting pachi bhetau"), "भोलि meeting पछि भेटौँ")
        XCTAssertEqual(engine.render("mero naam anup ho"), "मेरो नाम अनुप हो")
    }

    func testLiteralTextAndExistingUnicodeAreUntouched() {
        let source = "नमस्ते 👋 https://example.com/mero?x=1 anup@example.com `let ma = 1` 123\n"
        XCTAssertEqual(engine.render(source), source)
        XCTAssertEqual(engine.render("ma www.example.com/namaste"), "म www.example.com/namaste")
    }

    func testRenderedWordMappingHandlesUnicodeRepeatsOverridesAndLiterals() {
        let source = "👋 ma pani, ma https://example.com office."
        let sourceTokens = engine.tokens(in: source)
        let pani = sourceTokens.first { $0.text == "pani" }!
        let result = engine.renderWithMapping(source, language: .nepali, overrides: [pani.range.location: "पानी"])
        XCTAssertEqual(result.text, "👋 म पानी, म https://example.com office।")
        let output = result.text as NSString
        XCTAssertEqual(result.words.map { $0.source.text }, ["ma", "pani", "ma", "office"])
        XCTAssertEqual(result.words.map { output.substring(with: $0.outputRange) }, ["म", "पानी", "म", "office"])
        XCTAssertNotEqual(result.words[0].source.range.location, result.words[2].source.range.location)
        let all = engine.renderWithMapping(source, language: .allNepali)
        XCTAssertEqual(all.text, engine.render(source, language: .allNepali))
        for word in all.words { XCTAssertLessThanOrEqual(NSMaxRange(word.outputRange), (all.text as NSString).length) }
        let original = engine.renderWithMapping(source, language: .english)
        XCTAssertEqual(original.text, source)
        XCTAssertEqual(original.words.map { (original.text as NSString).substring(with: $0.outputRange) }, original.words.map { $0.source.text })
    }

    func testNepaliSentenceStopsPreserveProtectedDots() {
        XCTAssertEqual(engine.render("namaste. mero naam anup ho."), "नमस्ते। मेरो नाम अनुप हो।")
        XCTAssertEqual(engine.render("Hello world. ma office janchu."), "Hello world. म office जान्छु।")
        XCTAssertEqual(engine.render("ma 3.14 test. mero `a.b` thiyo..."), "म 3.14 test। मेरो `a.b` थियो...")
        XCTAssertEqual(engine.render("ma Dr. Sharma sanga. (namaste.)"), "म Dr. Sharma सँग। (नमस्ते।)")
        XCTAssertEqual(engine.render("namaste. ma https://example.com/test.com"), "नमस्ते। म https://example.com/test.com")
        XCTAssertEqual(engine.render("नमस्ते. ma test@example.com"), "नमस्ते। म test@example.com")
        XCTAssertEqual(engine.render("namaste.", language: .english), "namaste.")
        XCTAssertEqual(engine.render("namaste.🙂"), "नमस्ते.🙂")
        XCTAssertTrue(engine.render("hello.", language: .allNepali).hasSuffix("।"))
        var composer = Composer()
        composer.setSource("namaste.")
        XCTAssertEqual(composer.state.source, "namaste.")
        XCTAssertEqual(composer.output, "नमस्ते।")
    }

    func testAllNepaliTransliteratesEnglishAndKeepsProtectedLiterals() {
        let engine = Transliterator()
        let source = "ma office janchu, coffee please! Visit https://example.com user@example.com `git push` file_name"
        let mixed = engine.render(source, language: .nepali)
        let all = engine.render(source, language: .allNepali)
        XCTAssertTrue(mixed.contains("office"))
        XCTAssertFalse(all.contains("office"))
        XCTAssertFalse(all.contains("coffee"))
        XCTAssertFalse(all.contains("please"))
        XCTAssertFalse(all.contains("Visit"))
        for literal in ["https://example.com", "user@example.com", "`git push`", "file_name"] {
            XCTAssertTrue(all.contains(literal), "Protected literal changed: \(literal)")
        }
        XCTAssertTrue(all.contains("म"))
    }

    func testAllNepaliOriginalCanStillBeSelectedAndModeUndone() {
        var composer = Composer()
        composer.setSource("ma office janchu")
        let mixed = composer.output
        composer.setLanguage(.allNepali)
        XCTAssertFalse(composer.output.contains("office"))
        let token = composer.engine.tokens(in: composer.state.source).first { $0.text == "office" }!
        composer.choose("office", for: token)
        XCTAssertTrue(composer.output.contains("office"))
        composer.undo()
        XCTAssertFalse(composer.output.contains("office"))
        composer.undo()
        XCTAssertEqual(composer.output, mixed)
    }

    func testEnglishModeAlwaysPreservesExactOriginal() {
        let source = "ma office janchu!\nमेरो 👋"
        XCTAssertEqual(engine.render(source, language: .english), source)
    }

    func testCandidatesIncludeAmbiguityAndOriginal() {
        XCTAssertEqual(Array(engine.candidates(for: "pani").prefix(2)), ["पनि", "पानी"])
        XCTAssertTrue(engine.candidates(for: "pani").contains("pani"))
        XCTAssertEqual(engine.candidates(for: "office").first, "office")
        XCTAssertEqual(engine.candidates(for: "NASA").first, "NASA")
    }

    func testFootballAndMixedNepaliCanUseEitherScript() {
        XCTAssertEqual(engine.render("ma football khelchu"), "म फुटबल खेल्छु")
        XCTAssertEqual(engine.candidates(for: "football").first, "फुटबल")
        XCTAssertTrue(engine.candidates(for: "football").contains("football"))
        XCTAssertEqual(engine.candidates(for: "FOOTBALL").first, "FOOTBALL")
        var composer = Composer()
        composer.setSource("ma football khelchu")
        let football = engine.tokens(in: composer.state.source)[1]
        composer.choose("football", for: football)
        XCTAssertEqual(composer.output, "म football खेल्छु")
        composer.undo()
        XCTAssertEqual(composer.output, "म फुटबल खेल्छु")
        XCTAssertEqual(engine.render("ma pani khanchu"), "म पनि खान्छु")
        let phrase = "hello timro naam k ho? mero naam anup ho. malai football khelna man parchha."
        XCTAssertEqual(engine.render(phrase), "hello तिम्रो नाम के हो? मेरो नाम अनुप हो। मलाई फुटबल खेल्न मन पर्छ।")
    }

    func testPhoneticFallbackHandlesVowelMarksAndConjuncts() {
        XCTAssertEqual(engine.phonetic("namaste"), "नमस्ते")
        XCTAssertEqual(engine.phonetic("kitaab"), "किताब")
        XCTAssertEqual(engine.phonetic("prakaash"), "प्रकाश")
        XCTAssertEqual(engine.phonetic("gyan"), "ज्ञन") // raw fallback; lexicon can correct long vowels
        XCTAssertEqual(engine.phonetic(""), "")
    }

    func testSelectionUsesUTF16OffsetsAfterEmoji() {
        let source = "👋 ma pani"
        let token = engine.activeToken(in: source, caret: (source as NSString).length)!
        XCTAssertEqual(token.text, "pani")
        XCTAssertEqual(engine.render(source, overrides: [token.range.location: "पानी"]), "👋 म पानी")
        XCTAssertNil(engine.activeToken(in: "https://example.com", caret: 5))
    }

    func testChoiceAndLanguageSwitchAreUndoable() {
        var composer = Composer()
        composer.setSource("ma pani")
        let token = engine.activeToken(in: composer.state.source, caret: 7)!
        composer.choose("पानी", for: token)
        XCTAssertEqual(composer.output, "म पानी")
        composer.undo()
        XCTAssertEqual(composer.output, "म पनि")
        composer.redo()
        XCTAssertEqual(composer.output, "म पानी")
        composer.setLanguage(.english)
        XCTAssertEqual(composer.output, "ma pani")
        composer.undo()
        XCTAssertEqual(composer.output, "म पानी")
    }

    func testEditingKeepsUnchangedAndSafelyShiftedChoices() {
        var composer = Composer()
        composer.setSource("pani ma")
        let first = engine.tokens(in: composer.state.source)[0]
        composer.choose("पानी", for: first)
        composer.setSource("pani mero")
        XCTAssertEqual(composer.output, "पानी मेरो")
        composer.setSource("aaja pani mero")
        XCTAssertEqual(composer.output, "आज पानी मेरो")
        composer.undo()
        XCTAssertEqual(composer.output, "पानी मेरो")
    }

    func testOriginalCanBeChosenPerWord() {
        var composer = Composer()
        composer.setSource("ma office janchu")
        let token = engine.tokens(in: composer.state.source)[2]
        composer.choose("janchu", for: token)
        XCTAssertEqual(composer.output, "म office janchu")
        XCTAssertEqual(composer.state.source, "ma office janchu")
    }
}
