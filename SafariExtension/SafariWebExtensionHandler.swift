import SafariServices

/// Receives counts from the extension's background script and stores them in the
/// app group so the AdVoid app can show them.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any]

        if let counts = message?["counts"] as? [String: Any] {
            SafariStats.add(counts.compactMapValues { ($0 as? NSNumber)?.intValue })
        } else {
            SafariStats.markSeen()
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: ["ok": true]]
        context.completeRequest(returningItems: [response])
    }
}
