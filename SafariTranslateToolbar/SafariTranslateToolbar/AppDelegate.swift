import Cocoa
import ApplicationServices
import SafariServices

nonisolated enum TranslationMatcher {
    private static let excludedTerms = [
        "report", "issue", "feedback",
        "문제", "리포트", "신고",
        "問題を報告", "报告问题", "報告問題",
    ]

    // The Safari Web Extension toolbar button also contains the word
    // “translate”. Never select our own button while looking for Safari's
    // built-in translation controls.
    private static let extensionOwnedTerms = [
        "safari 번역 버튼",
        "safari 번역 툴바",
        "이 페이지를 apple 번역으로 번역",
        "translate this page with apple translate",
        "com.team95788x96a7.safari-translate-toolbar",
    ]

    private static let preferredPatterns = [
        "translate to ",
        "로 번역",
        "으로 번역",
        "に翻訳",
        "翻译成",
        "翻譯成",
        "traduire en ",
        "traducir al ",
        "traducir a ",
        "übersetzen auf ",
        "übersetzen in ",
        "traduci in ",
        "traduzir para ",
        "vertalen naar ",
        "przetłumacz na ",
        "перевести на ",
        "dịch sang ",
        "çevir",
    ]

    private static let generalTerms = [
        "translate", "translation",
        "번역",
        "翻訳", "翻译", "翻譯",
        "traduire", "traduction",
        "traducir", "traducción",
        "übersetzen", "übersetzung",
        "traduci", "traduzione",
        "traduzir", "tradução",
        "vertalen", "vertaling",
        "tłumacz", "przetłumacz",
        "перевести", "перевод",
        "dịch",
        "çevir", "çeviri",
    ]

    static func menuScore(_ text: String, identifier: String = "") -> Int {
        // Observed in Safari 27. These are implementation details, so retain
        // localized-label fallback for Safari versions with different IDs.
        if identifier.hasPrefix("Translate-"), identifier.count > "Translate-".count {
            return 120
        }
        if ["ViewOriginalTranslation", "ReportTranslationIssue", "PreferredLanguages"]
            .contains(identifier) {
            return 0
        }
        let normalized = text
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            .lowercased()

        guard !excludedTerms.contains(where: normalized.contains) else {
            return 0
        }

        guard !extensionOwnedTerms.contains(where: normalized.contains) else {
            return 0
        }

        if preferredPatterns.contains(where: normalized.contains) {
            return 100
        }

        if generalTerms.contains(where: normalized.contains) {
            return 40
        }

        return 0
    }

    static func buttonScore(_ text: String, identifier: String = "") -> Int {
        if identifier.hasPrefix("WebExtension-") {
            return 0
        }
        if identifier == "TranslationButton" {
            return 100
        }
        let score = menuScore(text)
        return score == 100 ? 80 : score
    }

    static func originalScore(_ text: String, identifier: String = "") -> Int {
        if identifier == "ViewOriginalTranslation" { return 120 }
        guard identifier.isEmpty else { return 0 }
        let labels = ["View Original", "Show Original", "원본 보기", "원본으로 돌아가기",
                      "原文を表示", "显示原文", "顯示原文"]
        return labels.contains { text.trimmingCharacters(in: .whitespacesAndNewlines)
            .caseInsensitiveCompare($0) == .orderedSame } ? 100 : 0
    }
}

nonisolated enum TranslationTogglePolicy {
    static func shouldRestoreOriginal(enabled: Bool?) -> Bool { enabled == true }

    static func confirmedState(originalEnabled: Bool?, expectedTranslated: Bool) -> String {
        guard let originalEnabled, originalEnabled == expectedTranslated else { return "unknown" }
        return originalEnabled ? "translated" : "original"
    }
}

nonisolated enum SafariChromeTraversal {
    // A page can expose its own AXToolbar/AXMenu roles. Stop at the web area
    // before requesting its children, rather than filtering page nodes later.
    static func descendants<Element>(
        of root: Element,
        maximumDepth: Int,
        maximumElements: Int,
        role: (Element) -> String?,
        children: (Element) -> [Element]
    ) -> [Element] {
        guard maximumDepth > 0, maximumElements > 0 else { return [] }
        var result: [Element] = []
        var queue: [(Element, Int)] = [(root, 0)]
        var index = 0

        while index < queue.count {
            let (element, depth) = queue[index]
            index += 1
            guard let elementRole = role(element), elementRole != "AXWebArea" else {
                continue
            }
            if depth > 0 {
                result.append(element)
            }
            guard depth < maximumDepth else { continue }
            // Bound the queue as well as the result, even for a wide tree.
            let remaining = maximumElements - (queue.count - 1)
            guard remaining > 0 else { continue }
            queue.append(contentsOf: children(element).prefix(remaining).map {
                ($0, depth + 1)
            })
        }
        return result
    }
}

private struct AccessibilityTree {
    static func value(
        _ element: AXUIElement,
        attribute: CFString
    ) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            attribute,
            &result
        ) == .success else {
            return nil
        }
        return result
    }

    static func string(
        _ element: AXUIElement,
        attribute: CFString
    ) -> String? {
        value(element, attribute: attribute) as? String
    }

    static func bool(
        _ element: AXUIElement,
        attribute: CFString
    ) -> Bool? {
        value(element, attribute: attribute) as? Bool
    }

    static func element(
        _ element: AXUIElement,
        attribute: CFString
    ) -> AXUIElement? {
        guard
            let result = value(element, attribute: attribute),
            CFGetTypeID(result) == AXUIElementGetTypeID()
        else {
            return nil
        }

        return unsafeBitCast(result, to: AXUIElement.self)
    }

    static func children(of element: AXUIElement) -> [AXUIElement] {
        value(
            element,
            attribute: kAXChildrenAttribute as CFString
        ) as? [AXUIElement] ?? []
    }

    static func searchableText(of element: AXUIElement) -> String {
        let attributes: [CFString] = [
            kAXTitleAttribute as CFString,
            kAXDescriptionAttribute as CFString,
            kAXHelpAttribute as CFString,
            kAXIdentifierAttribute as CFString,
        ]

        return attributes
            .compactMap { string(element, attribute: $0) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func descendants(
        of root: AXUIElement,
        maximumDepth: Int,
        maximumElements: Int = 2_000
    ) -> [AXUIElement] {
        SafariChromeTraversal.descendants(
            of: root,
            maximumDepth: maximumDepth,
            maximumElements: maximumElements,
            role: { string($0, attribute: kAXRoleAttribute as CFString) },
            children: { children(of: $0) }
        )
    }

    static func bestElement(
        under root: AXUIElement,
        maximumDepth: Int,
        acceptedRoles: Set<String>,
        minimumScore: Int = 1,
        score: (String, String) -> Int
    ) -> AXUIElement? {
        descendants(of: root, maximumDepth: maximumDepth)
            .compactMap { element -> (AXUIElement, Int)? in
                guard
                    let role = string(
                        element,
                        attribute: kAXRoleAttribute as CFString
                    ),
                    acceptedRoles.contains(role),
                    bool(
                        element,
                        attribute: kAXEnabledAttribute as CFString
                    ) != false,
                    bool(
                        element,
                        attribute: "AXVisible" as CFString
                    ) != false
                else {
                    return nil
                }

                let identifier = string(
                    element, attribute: kAXIdentifierAttribute as CFString
                ) ?? ""
                let elementScore = score(searchableText(of: element), identifier)
                return elementScore >= minimumScore
                    ? (element, elementScore)
                    : nil
            }
            .max { $0.1 < $1.1 }?
            .0
    }
}

private enum TranslationResult {
    case commandInvoked(state: String)
    case safariNotRunning
    case noSafariWindow
    case permissionRequired
    case translationUnavailable
    case automationFailed
}

private final class SafariTranslator {
    private let safariBundleIdentifier = "com.apple.Safari"
    private let toolbarRoles = Set([
        kAXToolbarRole as String,
    ])
    private let openControlContainerRoles = Set([
        kAXMenuRole as String,
        "AXPopover",
    ])
    private let viewMenuTitles = Set([
        "보기",
        "View",
        "表示",
        "显示",
        "顯示",
        "Présentation",
        "Visualización",
        "Darstellung",
        "Vista",
        "Visualizar",
        "Weergave",
        "Widok",
        "Вид",
        "Xem",
        "Görüntü",
    ])

    func translateCurrentPage() -> TranslationResult {
        guard AXIsProcessTrusted() else {
            return .permissionRequired
        }

        guard let safari = NSRunningApplication
            .runningApplications(
                withBundleIdentifier: safariBundleIdentifier
            )
            .first
        else {
            return .safariNotRunning
        }

        // Activation is asynchronous on current macOS. Do not search stale
        // focus immediately, or bring every Safari window to the front.
        if !safari.isActive {
            if #available(macOS 14.0, *) {
                NSApp.yieldActivation(to: safari)
                _ = safari.activate(from: .current, options: [])
            } else {
                _ = safari.activate(options: [])
            }
        }
        let application = AXUIElementCreateApplication(
            safari.processIdentifier
        )
        AXUIElementSetMessagingTimeout(application, 0.3)

        var focusedWindow: AXUIElement?
        let focusDeadline = ProcessInfo.processInfo.systemUptime + 1.0
        repeat {
            if safari.isActive {
                focusedWindow = AccessibilityTree.element(
                    application,
                    attribute: kAXFocusedWindowAttribute as CFString
                )
                if focusedWindow != nil { break }
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
        } while ProcessInfo.processInfo.systemUptime < focusDeadline

        guard safari.isActive else { return .automationFailed }
        guard let focusedWindow else {
            return .noSafariWindow
        }

        // Hidden menu descendants can accept AXPress without actually invoking
        // their command. Open Safari's View menu first, then press only the
        // visible “Translate to …” menu item.
        if let result = pressTranslationCommandInViewMenu(in: application) {
            return result
        }

        guard pressTranslationButton(in: focusedWindow) else {
            return .translationUnavailable
        }

        for _ in 0..<8 {
            RunLoop.current.run(
                until: Date(timeIntervalSinceNow: 0.08)
            )
            if pressTranslationCommandInOpenControl(
                in: application
            ) {
                return .commandInvoked(state: confirmState(in: application, translated: true))
            }
        }

        return .automationFailed
    }

    private func pressTranslationCommandInViewMenu(
        in application: AXUIElement
    ) -> TranslationResult? {
        guard let menuBar = AccessibilityTree.element(
            application,
            attribute: kAXMenuBarAttribute as CFString
        ) else {
            return nil
        }

        let menuBarItems = AccessibilityTree.children(of: menuBar)
        let identifiedViewMenu = menuBarItems.first {
            AccessibilityTree.string(
                $0, attribute: kAXIdentifierAttribute as CFString
            ) == "SafariViewMenu"
        }
        guard let viewMenuItem = identifiedViewMenu ?? menuBarItems.first(where: {
            guard let title = AccessibilityTree.string(
                $0,
                attribute: kAXTitleAttribute as CFString
            ) else {
                return false
            }
            return viewMenuTitles.contains(title)
        }) else {
            return nil
        }

        guard press(viewMenuItem) else {
            return nil
        }

        RunLoop.current.run(
            until: Date(timeIntervalSinceNow: 0.15)
        )

        // Safari 27 can keep the toolbar label “Translation Available” even
        // after translation. Its enabled View Original command is unambiguous.
        let menuElements = AccessibilityTree.descendants(
            of: viewMenuItem, maximumDepth: 8
        )
        let originalItem = originalCommand(in: menuElements)
        let restoreOriginal = TranslationTogglePolicy.shouldRestoreOriginal(enabled: originalItem.flatMap {
            AccessibilityTree.bool($0, attribute: kAXEnabledAttribute as CFString)
        })

        // Safari 27 exposes TranslationMenu below a submenu item. Explicitly
        // open its parent before pressing a language command; a hidden item
        // may acknowledge AXPress without starting translation.
        if let translationMenu = menuElements.first(where: {
            AccessibilityTree.string(
                $0, attribute: kAXIdentifierAttribute as CFString
            ) == "TranslationMenu"
        }), let parent = AccessibilityTree.element(
            translationMenu, attribute: kAXParentAttribute as CFString
        ) {
            guard press(parent) else {
                dismissOpenMenu(viewMenuItem)
                return .automationFailed
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.1))
        }

        if restoreOriginal, let originalItem {
            guard press(originalItem) else {
                dismissOpenMenu(viewMenuItem)
                return .automationFailed
            }
            return .commandInvoked(state: confirmState(in: application, translated: false))
        }

        guard let translationItem = AccessibilityTree.bestElement(
            under: viewMenuItem,
            maximumDepth: 8,
            acceptedRoles: Set([kAXMenuItemRole as String]),
            minimumScore: 100,
            score: TranslationMatcher.menuScore
        ) else {
            dismissOpenMenu(viewMenuItem)
            return nil
        }

        if press(translationItem) {
            return .commandInvoked(state: confirmState(in: application, translated: true))
        }

        dismissOpenMenu(viewMenuItem)
        return nil
    }

    private func originalCommand(in elements: [AXUIElement]) -> AXUIElement? {
        elements.first {
            AccessibilityTree.string($0, attribute: kAXRoleAttribute as CFString)
                == kAXMenuItemRole as String
                && TranslationMatcher.originalScore(
                    AccessibilityTree.string($0, attribute: kAXTitleAttribute as CFString) ?? "",
                    identifier: AccessibilityTree.string(
                        $0, attribute: kAXIdentifierAttribute as CFString
                    ) ?? ""
                ) >= 100
        }
    }

    // AXPress only acknowledges a command. Read Safari's native menu afterward
    // before lighting the badge; never infer success from a click count.
    private func confirmState(in application: AXUIElement, translated: Bool) -> String {
        guard let initialWindow = AccessibilityTree.element(
            application, attribute: kAXFocusedWindowAttribute as CFString
        ) else { return "unknown" }
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.5))
        guard let currentWindow = AccessibilityTree.element(
            application, attribute: kAXFocusedWindowAttribute as CFString
        ), CFEqual(initialWindow, currentWindow),
        let menuBar = AccessibilityTree.element(application, attribute: kAXMenuBarAttribute as CFString),
        let viewMenu = AccessibilityTree.children(of: menuBar).first(where: {
            AccessibilityTree.string($0, attribute: kAXIdentifierAttribute as CFString) == "SafariViewMenu"
                || viewMenuTitles.contains(
                    AccessibilityTree.string($0, attribute: kAXTitleAttribute as CFString) ?? ""
                )
        }), press(viewMenu) else { return "unknown" }
        defer { dismissOpenMenu(viewMenu) }
        let deadline = ProcessInfo.processInfo.systemUptime + 2
        repeat {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.15))
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == safariBundleIdentifier,
                  let window = AccessibilityTree.element(application, attribute: kAXFocusedWindowAttribute as CFString),
                  CFEqual(initialWindow, window) else { return "unknown" }
            let elements = AccessibilityTree.descendants(of: viewMenu, maximumDepth: 8)
            let enabled = originalCommand(in: elements).flatMap {
                AccessibilityTree.bool($0, attribute: kAXEnabledAttribute as CFString)
            }
            let state = TranslationTogglePolicy.confirmedState(
                originalEnabled: enabled, expectedTranslated: translated
            )
            if state != "unknown" { return state }
        } while ProcessInfo.processInfo.systemUptime < deadline
        return "unknown"
    }

    private func pressTranslationCommandInOpenControl(
        in application: AXUIElement
    ) -> Bool {
        let acceptedRoles = Set([
            kAXMenuItemRole as String,
            kAXButtonRole as String,
        ])

        for container in containers(
            under: application,
            maximumDepth: 8,
            acceptedRoles: openControlContainerRoles
        ).reversed() {
            if let item = AccessibilityTree.bestElement(
                under: container,
                maximumDepth: 6,
                acceptedRoles: acceptedRoles,
                minimumScore: 80,
                score: TranslationMatcher.menuScore
            ) {
                return press(item)
            }
        }

        return false
    }

    private func pressTranslationButton(
        in window: AXUIElement
    ) -> Bool {
        let acceptedRoles = Set([
            kAXButtonRole as String,
            kAXMenuButtonRole as String,
            kAXPopUpButtonRole as String,
        ])

        for toolbar in containers(
            under: window,
            maximumDepth: 8,
            acceptedRoles: toolbarRoles
        ) {
            if let button = AccessibilityTree.bestElement(
                under: toolbar,
                maximumDepth: 6,
                acceptedRoles: acceptedRoles,
                score: TranslationMatcher.buttonScore
            ) {
                return press(button)
            }
        }

        return false
    }

    // Only control labels inside Safari chrome are inspected. Traversing the
    // window to locate a toolbar reads element roles, not AXValue or page text.
    private func containers(
        under root: AXUIElement,
        maximumDepth: Int,
        acceptedRoles: Set<String>
    ) -> [AXUIElement] {
        AccessibilityTree.descendants(
            of: root,
            maximumDepth: maximumDepth,
            maximumElements: 1_000
        ).filter { element in
            guard let role = AccessibilityTree.string(
                element,
                attribute: kAXRoleAttribute as CFString
            ) else {
                return false
            }
            return acceptedRoles.contains(role)
        }
    }

    private func press(_ element: AXUIElement) -> Bool {
        // If the user switches apps during a retry, stop acting on Safari.
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier
            == safariBundleIdentifier else { return false }
        return AXUIElementPerformAction(
            element,
            kAXPressAction as CFString
        ) == .success
    }

    private func dismissOpenMenu(_ menu: AXUIElement) {
        if AXUIElementPerformAction(menu, kAXCancelAction as CFString) == .success {
            return
        }
        guard let safari = NSWorkspace.shared.frontmostApplication,
              safari.bundleIdentifier == safariBundleIdentifier else { return }
        guard let source = CGEventSource(
            stateID: .hidSystemState
        ) else {
            return
        }

        CGEvent(
            keyboardEventSource: source,
            virtualKey: 53,
            keyDown: true
        )?.postToPid(safari.processIdentifier)
        CGEvent(
            keyboardEventSource: source,
            virtualKey: 53,
            keyDown: false
        )?.postToPid(safari.processIdentifier)
    }

}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let extensionIdentifier =
        "com.team95788x96a7.safari-translate-toolbar.Extension"
    private let accessibilityPromptedKey =
        "accessibilityPermissionPrompted"
    private let translator = SafariTranslator()

    private var receivedTranslationCommand = false
    private var translationInProgress = false
    private var requestID: String?

    func applicationWillFinishLaunching(
        _ notification: Notification
    ) {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(
                handleGetURLEvent(_:withReplyEvent:)
            ),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(
        _ notification: Notification
    ) {
        NSApp.setActivationPolicy(.accessory)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            guard !self.receivedTranslationCommand else {
                return
            }
            SFSafariApplication.showPreferencesForExtension(
                withIdentifier: self.extensionIdentifier
            ) { _ in
                DispatchQueue.main.async {
                    NSApp.terminate(nil)
                }
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !receivedTranslationCommand else {
            return false
        }

        SFSafariApplication.showPreferencesForExtension(
            withIdentifier: extensionIdentifier
        ) { _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        NSAppleEventManager.shared().removeEventHandler(
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURLEvent(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard
            let urlString = event.paramDescriptor(
                forKeyword: keyDirectObject
            )?.stringValue,
            let url = URL(string: urlString),
            url.scheme == "safaritranslate95788x96a7",
            url.host == "translate"
        else {
            return
        }

        receivedTranslationCommand = true
        guard !translationInProgress else { return }
        // An opaque per-click ID only; never accept tab URLs or page contents.
        requestID = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?.first(where: { $0.name == "request" })?.value
            .flatMap { UUID(uuidString: $0)?.uuidString.lowercased() }
        runTranslation()
    }

    private func runTranslation() {
        guard !translationInProgress else {
            return
        }
        translationInProgress = true

        DispatchQueue.main.async {
            let result = self.translator.translateCurrentPage()
            self.handle(result)
        }
    }

    private func handle(_ result: TranslationResult) {
        switch result {
        case .commandInvoked(let state):
            reportState(state, terminateAfterDelivery: true)

        case .safariNotRunning:
            showError(
                title: localized("error.safari_not_running.title"),
                message: localized("error.safari_not_running.message")
            )

        case .noSafariWindow:
            showError(
                title: localized("error.no_safari_window.title"),
                message: localized("error.no_safari_window.message")
            )

        case .permissionRequired:
            if UserDefaults.standard.bool(forKey: accessibilityPromptedKey) {
                showError(
                    title: localized("error.permission_required.title"),
                    message: localized(
                        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
                            ? "error.permission_required.macos27.message"
                            : "error.permission_required.message"
                    )
                )
            } else {
                reportState("unknown")
                requestAccessibilityPermissionOnce()
                terminateSoon()
            }

        case .translationUnavailable:
            showError(
                title: localized("error.translation_unavailable.title"),
                message: localized("error.translation_unavailable.message")
            )

        case .automationFailed:
            showError(
                title: localized("error.automation_failed.title"),
                message: localized("error.automation_failed.message")
            )
        }
    }

    private func showError(
        title: String,
        message: String
    ) {
        reportState("unknown")
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: localized("button.ok"))
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        alert.runModal()
        NSApp.terminate(nil)
    }

    private func localized(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func reportState(_ state: String, terminateAfterDelivery: Bool = false) {
        guard let requestID else {
            if terminateAfterDelivery { terminateSoon() }
            return
        }
        SFSafariApplication.dispatchMessage(
            withName: "translationState",
            toExtensionWithIdentifier: extensionIdentifier,
            userInfo: ["requestID": requestID, "state": state]
        ) { _ in
            if terminateAfterDelivery {
                DispatchQueue.main.async { NSApp.terminate(nil) }
            }
        }
        if terminateAfterDelivery {
            // Do not remain resident if Safari does not complete delivery.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { NSApp.terminate(nil) }
        }
    }

    private func requestAccessibilityPermissionOnce() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: accessibilityPromptedKey) else {
            return
        }

        // Never queue a permission dialog on every toolbar click. A stable
        // Developer ID signature and bundle identifier preserve the grant
        // across updates, so the system prompt is requested only once for the
        // product. A denied or manually reset grant must be enabled directly in
        // System Settings instead of starting another prompt loop.
        defaults.set(true, forKey: accessibilityPromptedKey)

        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:
                true,
        ] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func terminateSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.terminate(nil)
        }
    }
}

#if !REGRESSION_TESTS
@main
enum SafariTranslateApplication {
    static func main() {
        if CommandLine.arguments.contains("--diagnose") {
            // Deliberately report only app/OS versions and the permission bit.
            // Do not inspect Safari windows, URLs, page content, or user names.
            let version = Bundle.main.object(
                forInfoDictionaryKey: "CFBundleShortVersionString"
            ) as? String ?? "unknown"
            print("appVersion=\(version)")
            print("macOS=\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion)")
            print("accessibilityTrusted=\(AXIsProcessTrusted())")
            return
        }
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        application.delegate = appDelegate
        application.run()
        withExtendedLifetime(appDelegate) {}
    }
}
#endif
