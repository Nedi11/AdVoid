import Foundation
import Observation
import RevenueCat

/// Tracks the Pro entitlement through RevenueCat and records it for the extensions.
@MainActor
@Observable
final class SubscriptionModel {
    enum Status { case unknown, active, inactive }

    /// Public SDK key from RevenueCat › Project settings › API keys. It's meant to ship in the app.
    static let apiKey = "appl_BHrrivQNssVkGjVGGqfAQYpIeZg"
    static var isConfigured: Bool { !apiKey.hasSuffix("REPLACE_ME") }

    private(set) var status = Status.unknown
    private(set) var isTrial = false
    private(set) var willRenew = false
    /// When the current period ends: the renewal date, or when access stops.
    private(set) var periodEnd: Date?

    func start() async {
        guard Self.isConfigured else {
            #if DEBUG
            // Lets the app run in development before the RevenueCat project exists.
            status = .active
            return
            #else
            preconditionFailure("Set SubscriptionModel.apiKey to the RevenueCat public SDK key.")
            #endif
        }
        // Unit tests run inside the app; RevenueCat would race their StoreKit test session.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: Self.apiKey)

        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            // Offline with nothing cached: StoreKit still knows about purchases.
            status = await Subscription.hasStoreKitEntitlement() ? .active : .inactive
        }
        for await info in Purchases.shared.customerInfoStream {
            apply(info)
        }
    }

    private func apply(_ info: CustomerInfo) {
        let entitlement = info.entitlements[Subscription.entitlementID]
        let active = entitlement?.isActive == true
        isTrial = entitlement?.periodType == .trial
        willRenew = entitlement?.willRenew ?? false
        periodEnd = entitlement?.expirationDate
        Subscription.record(activeUntil: active ? (entitlement?.expirationDate ?? .distantFuture) : nil)
        status = active ? .active : .inactive
    }
}
