import XCTest
@testable import NepaliCore

final class LocalExperienceTests: XCTestCase {
    func testDraftRoundTripDeletionAndPrivatePreferences() throws {
        let suite = "neptype.test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let store = LocalExperience(defaults: defaults, directory: directory)
        var composer = Composer()
        composer.setSource("pani ma office janchu")
        store.remember("pani", value: "पानी", candidates: ["पानी"])
        XCTAssertTrue(store.spellings.isEmpty)
        let offered = composer.engine.candidates(for: "pani")
        let alternative = offered.first { $0 != offered.first && $0 != "pani" }!
        store.remember("pani", value: alternative, candidates: offered)
        store.remember("email@example.com", value: "private", candidates: ["private"])
        XCTAssertEqual(store.spellings, ["pani": alternative])
        composer.setPreferredSpellings(store.spellings)
        XCTAssertEqual(composer.orderedCandidates(composer.engine.candidates(for: "pani"), for: "pani").first, alternative)
        XCTAssertTrue(store.saveDraft(composer.state))
        var restored = Composer()
        XCTAssertTrue(LocalExperience(defaults: defaults, directory: directory).restore(into: &restored))
        XCTAssertEqual(restored.output, composer.output)
        store.remember("pani", value: offered.first!, candidates: offered)
        XCTAssertTrue(store.spellings.isEmpty)
        XCTAssertTrue(store.clearDraft())
        XCTAssertNil(store.loadDraft())
    }
    func testPreferencesNeverRewriteLiteralOrExplicitChoices() {
        var composer = Composer()
        composer.setPreferredSpellings(["pani":"पानी", "office":"not an offered candidate"])
        composer.setSource("pani https://pani.com `pani` office")
        let originalOutput = composer.output
        XCTAssertEqual(composer.orderedCandidates(composer.engine.candidates(for: "pani"), for: "pani").first, "पानी")
        XCTAssertTrue(composer.output.contains("https://pani.com `pani` office"))
        let token = composer.engine.tokens(in: composer.state.source).first!
        composer.choose("pani", for: token)
        XCTAssertTrue(composer.output.hasPrefix("pani"))
        composer.undo()
        XCTAssertEqual(composer.output, originalOutput)
        composer.setLanguage(.english)
        XCTAssertEqual(composer.output, composer.state.source)
    }
}
