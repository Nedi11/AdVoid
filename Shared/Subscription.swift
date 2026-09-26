import Foundation
import StoreKit

/// Whether the user has AdVoid Pro, readable from the app and its extensions.
///
/// The app records what RevenueCat reports. The extensions can't run RevenueCat,
/// so they read that record and fall back to StoreKit, which also covers a
/// renewal that happened while the app wasn't opened.
enum Subscription {
    static let entitlementID = "pro"

    private static let expiryKey = "proExpiresAt"

    /// Called by the app after RevenueCat reports the entitlement. `nil` means not subscribed.
    static func record(activeUntil expiry: Date?) {
        AppGroup.defaults.set(expiry, forKey: expiryKey)
    }

    /// When the recorded entitlement ends, or `nil` if none is recorded.
    static var recordedExpiry: Date? {
        AppGroup.defaults.object(forKey: expiryKey) as? Date
    }

    static func isActive(at date: Date = Date()) async -> Bool {
        if let expiry = recordedExpiry, expiry > date { return true }
        return await hasStoreKitEntitlement()
    }

    /// Any current subscription to this app counts: every plan unlocks Pro, so this
    /// doesn't need to know product IDs, which are managed in RevenueCat.
    static func hasStoreKitEntitlement() async -> Bool {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productType == .autoRenewable,
               transaction.revocationDate == nil {
                return true
            }
        }
        return false
    }
}
