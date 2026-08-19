import Cocoa
import ApplicationServices
import SafariServices

private enum TranslationMatcher {
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

    static func menuScore(_ text: String) -> Int {
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

    static func buttonScore(_ text: String) -> Int {
        let score = menuScore(text)
        return score == 100 ? 80 : score
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
        var result: [AXUIElement] = []
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var index = 0

        while index < queue.count && result.count < maximumElements {
            let (element, depth) = queue[index]
            index += 1

            if depth > 0 {
                result.append(element)
            }

            guard depth < maximumDepth else {
                continue
            }

            for child in children(of: element) {
                queue.append((child, depth + 1))
            }
        }

        return result
    }

    static func bestElement(
        under root: AXUIElement,
        maximumDepth: Int,
        acceptedRoles: Set<String>,
        minimumScore: Int = 1,
        score: (String) -> Int
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

                let elementScore = score(searchableText(of: element))
                return elementScore >= minimumScore
                    ? (element, elementScore)
                    : nil
            }
            .max { $0.1 < $1.1 }?
            .0
    }
}

private enum TranslationResult {
    case translated
    case alreadyTranslated
    case safariNotRunning
    case noSafariWindow
    case permissionRequired
    case translationUnavailable
    case automationFailed(String)
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

        safari.activate(options: [.activateAllWindows])
        let application = AXUIElementCreateApplication(
            safari.processIdentifier
        )

        guard let focusedWindow = AccessibilityTree.element(
            application,
            attribute: kAXFocusedWindowAttribute as CFString
        ) else {
            return .noSafariWindow
        }

        if pageAppearsTranslated(in: focusedWindow) {
            return .alreadyTranslated
        }

        // Hidden menu descendants can accept AXPress without actually invoking
        // their command. Open Safari's View menu first, then press only the
        // visible “Translate to …” menu item.
        if pressTranslationCommandInViewMenu(in: application) {
            return .translated
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
                return .translated
            }
        }

        return .automationFailed(
            "Safari의 번역 버튼은 찾았지만 번역 언어 메뉴를 선택하지 못했습니다."
        )
    }

    private func pressTranslationCommandInViewMenu(
        in application: AXUIElement
    ) -> Bool {
        guard let menuBar = AccessibilityTree.element(
            application,
            attribute: kAXMenuBarAttribute as CFString
        ) else {
            return false
        }

        let menuBarItems = AccessibilityTree.children(of: menuBar)
        guard let viewMenuItem = menuBarItems.first(where: {
            guard let title = AccessibilityTree.string(
                $0,
                attribute: kAXTitleAttribute as CFString
            ) else {
                return false
            }
            return viewMenuTitles.contains(title)
        }) else {
            return false
        }

        guard press(viewMenuItem) else {
            return false
        }

        RunLoop.current.run(
            until: Date(timeIntervalSinceNow: 0.15)
        )

        guard let translationItem = AccessibilityTree.bestElement(
            under: viewMenuItem,
            maximumDepth: 8,
            acceptedRoles: Set([kAXMenuItemRole as String]),
            minimumScore: 100,
            score: TranslationMatcher.menuScore
        ) else {
            dismissOpenMenu()
            return false
        }

        if press(translationItem) {
            return true
        }

        dismissOpenMenu()
        return false
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
        AXUIElementPerformAction(
            element,
            kAXPressAction as CFString
        ) == .success
    }

    private func dismissOpenMenu() {
        guard let source = CGEventSource(
            stateID: .hidSystemState
        ) else {
            return
        }

        CGEvent(
            keyboardEventSource: source,
            virtualKey: 53,
            keyDown: true
        )?.post(tap: .cghidEventTap)
        CGEvent(
            keyboardEventSource: source,
            virtualKey: 53,
            keyDown: false
        )?.post(tap: .cghidEventTap)
    }

    private func pageAppearsTranslated(
        in window: AXUIElement
    ) -> Bool {
        let originalPageTerms = [
            "원본 보기",
            "원본으로 돌아가기",
            "View Original",
            "Show Original",
            "原文を表示",
            "显示原文",
            "顯示原文",
        ]

        let acceptedRoles = Set([
            kAXButtonRole as String,
            kAXMenuButtonRole as String,
            kAXPopUpButtonRole as String,
        ])

        return containers(
            under: window,
            maximumDepth: 8,
            acceptedRoles: toolbarRoles
        ).contains { toolbar in
            AccessibilityTree.bestElement(
                under: toolbar,
                maximumDepth: 6,
                acceptedRoles: acceptedRoles,
                score: { text in
                    originalPageTerms.contains(
                        where: text.localizedCaseInsensitiveContains
                    ) ? 1 : 0
                }
            ) != nil
        }
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
        case .translated, .alreadyTranslated:
            terminateSoon()

        case .safariNotRunning:
            showError(
                title: "Safari가 열려 있지 않습니다",
                message: "Safari에서 번역할 페이지를 연 뒤 다시 클릭하세요."
            )

        case .noSafariWindow:
            showError(
                title: "Safari 창을 찾을 수 없습니다",
                message: "번역할 Safari 창과 탭을 열어 주세요."
            )

        case .permissionRequired:
            requestAccessibilityPermissionOnce()
            terminateSoon()

        case .translationUnavailable:
            showError(
                title: "이 페이지에서는 번역을 사용할 수 없습니다",
                message:
                    "Safari의 페이지 메뉴에 번역 사용 가능 표시가 있는지 확인해 주세요."
            )

        case let .automationFailed(message):
            showError(
                title: "번역을 시작하지 못했습니다",
                message: message
            )
        }
    }

    private func showError(
        title: String,
        message: String
    ) {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "확인")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
        NSApp.terminate(nil)
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

@main
enum SafariTranslateApplication {
    static func main() {
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        application.delegate = appDelegate
        application.run()
        withExtendedLifetime(appDelegate) {}
    }
}
