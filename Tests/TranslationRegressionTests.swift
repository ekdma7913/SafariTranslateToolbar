import XCTest

nonisolated final class TranslationRegressionTests: XCTestCase {
    func testToggleUsesMenuStateAndOnlyConfirmsExpectedTransition() {
        XCTAssertTrue(TranslationTogglePolicy.shouldRestoreOriginal(enabled: true))
        XCTAssertFalse(TranslationTogglePolicy.shouldRestoreOriginal(enabled: false))
        XCTAssertFalse(TranslationTogglePolicy.shouldRestoreOriginal(enabled: nil))
        XCTAssertEqual(TranslationTogglePolicy.confirmedState(originalEnabled: true, expectedTranslated: true), "translated")
        XCTAssertEqual(TranslationTogglePolicy.confirmedState(originalEnabled: false, expectedTranslated: false), "original")
        for expected in [true, false] {
            XCTAssertEqual(TranslationTogglePolicy.confirmedState(originalEnabled: nil, expectedTranslated: expected), "unknown")
            XCTAssertEqual(TranslationTogglePolicy.confirmedState(originalEnabled: !expected, expectedTranslated: expected), "unknown")
        }
    }

    func testOriginalCommandUsesIdentifierAndExactLocalizedFallback() {
        XCTAssertEqual(TranslationMatcher.originalScore("任意", identifier: "ViewOriginalTranslation"), 120)
        for label in ["View Original", "Show Original", "원본 보기", "原文を表示", "显示原文"] {
            XCTAssertEqual(TranslationMatcher.originalScore(label), 100)
        }
        for identifier in ["Translate-ko_KR", "ReportTranslationIssue", "WebExtension-test"] {
            XCTAssertEqual(TranslationMatcher.originalScore("View Original", identifier: identifier), 0)
        }
        XCTAssertEqual(TranslationMatcher.originalScore("View Original Something Else"), 0)
        XCTAssertEqual(TranslationMatcher.originalScore("한국어로 번역"), 0)
    }

    func testLanguageCommandsUseIdentifiersWithLocalizedFallback() {
        XCTAssertEqual(TranslationMatcher.menuScore("한국어로 번역"), 100)
        XCTAssertEqual(TranslationMatcher.menuScore("Translate to Korean"), 100)
        XCTAssertEqual(
            TranslationMatcher.menuScore("غير معروف", identifier: "Translate-ar"), 120
        )
        XCTAssertEqual(TranslationMatcher.menuScore("", identifier: "Translate-"), 0)
    }

    func testNonTranslationCommandsAndExtensionsAreExcluded() {
        for identifier in ["ViewOriginalTranslation", "ReportTranslationIssue", "PreferredLanguages"] {
            XCTAssertEqual(
                TranslationMatcher.menuScore("Translate to Korean", identifier: identifier), 0
            )
        }
        XCTAssertEqual(TranslationMatcher.menuScore("Report Translation Issue"), 0)
        XCTAssertEqual(TranslationMatcher.menuScore("번역 문제 리포트"), 0)
        XCTAssertEqual(TranslationMatcher.buttonScore("이 페이지를 Apple 번역으로 번역"), 0)
        XCTAssertEqual(
            TranslationMatcher.buttonScore("Translate to Korean", identifier: "WebExtension-other"), 0
        )
        XCTAssertEqual(TranslationMatcher.buttonScore("", identifier: "TranslationButton"), 100)
    }

    func testWebContentIsNeverEnumeratedEvenWithFakeChromeRoles() {
        // The page's toolbar/menu must not become a candidate, even when its
        // labels and roles imitate Safari's real translation controls.
        let children = [0: [1, 2], 1: [3], 2: [4], 3: [5]]
        let roles = [0: "AXWindow", 1: "AXWebArea", 2: "AXToolbar",
                     3: "AXToolbar", 4: "AXButton", 5: "AXMenu"]
        var enumerated: [Int] = []
        let result = SafariChromeTraversal.descendants(
            of: 0, maximumDepth: 8, maximumElements: 100,
            role: { roles[$0] },
            children: { enumerated.append($0); return children[$0] ?? [] }
        )
        XCTAssertEqual(result, [2, 4])
        XCTAssertFalse(enumerated.contains(1))
        XCTAssertFalse(enumerated.contains(3))
        XCTAssertFalse(enumerated.contains(5))
    }

    func testUnknownRolesFailClosed() {
        var enumerations = 0
        let result = SafariChromeTraversal.descendants(
            of: 0, maximumDepth: 8, maximumElements: 100,
            role: { _ in nil }, children: { _ in enumerations += 1; return [1] }
        )
        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(enumerations, 0)
    }

    func testDepthAndElementBudgets() {
        let shallow = SafariChromeTraversal.descendants(
            of: 0, maximumDepth: 1, maximumElements: 100,
            role: { _ in "AXGroup" }, children: { [$0 + 1] }
        )
        XCTAssertEqual(shallow, [1])
        let wide = SafariChromeTraversal.descendants(
            of: 0, maximumDepth: 8, maximumElements: 3,
            role: { _ in "AXGroup" }, children: { _ in Array(1...10_000) }
        )
        XCTAssertEqual(wide, [1, 2, 3])
        let cyclic = SafariChromeTraversal.descendants(
            of: 0, maximumDepth: 100, maximumElements: 5,
            role: { _ in "AXGroup" }, children: { [$0] }
        )
        XCTAssertEqual(cyclic.count, 5)
    }

    func testZeroBudgetsDoNotReadAnyElements() {
        for (depth, count) in [(0, 10), (10, 0)] {
            let result = SafariChromeTraversal.descendants(
                of: 0, maximumDepth: depth, maximumElements: count,
                role: { _ in XCTFail("Must not query roles"); return "AXWindow" },
                children: { _ in XCTFail("Must not query children"); return [] }
            )
            XCTAssertTrue(result.isEmpty)
        }
    }
}

@main
enum RegressionTestRunner {
    static func main() {
        let suite = XCTestSuite(forTestCaseClass: TranslationRegressionTests.self)
        suite.run()
        guard let run = suite.testRun, run.executionCount > 0,
              run.executionCount == suite.testCaseCount, run.hasSucceeded else {
            exit(1)
        }
    }
}
