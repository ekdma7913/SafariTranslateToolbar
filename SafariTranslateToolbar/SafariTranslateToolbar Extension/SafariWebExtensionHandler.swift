import AppKit
import SafariServices

final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {

    func beginRequest(with context: NSExtensionContext) {
        let request = context.inputItems.first as? NSExtensionItem
        let message = request?.userInfo?[SFExtensionMessageKey]

        guard
            let dictionary = message as? [String: Any],
            dictionary["command"] as? String == "translate",
            let url = URL(
                string: "safaritranslate95788x96a7://translate"
            )
        else {
            complete(
                context,
                ok: false,
                error: NSLocalizedString(
                    "extension.unsupported_command",
                    comment: "Unsupported native messaging command"
                )
            )
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        NSWorkspace.shared.open(
            url,
            configuration: configuration
        ) { [weak self] _, error in
            self?.complete(
                context,
                ok: error == nil,
                error: error?.localizedDescription
            )
        }
    }

    private func complete(
        _ context: NSExtensionContext,
        ok: Bool,
        error: String?
    ) {
        var payload: [String: Any] = ["ok": ok]
        if let error {
            payload["error"] = error
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: payload]
        context.completeRequest(
            returningItems: [response],
            completionHandler: nil
        )
    }
}
