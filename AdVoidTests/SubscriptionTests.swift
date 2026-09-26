import StoreKit
import StoreKitTest
import Testing
@testable import AdVoid

private final class BundleToken {}

/// The local StoreKit file, used for purchases in Xcode runs, mirrors the App Store plans.
@Suite(.serialized)
struct SubscriptionTests {
    private static let productIDs: Set = ["advoid_pro_monthly", "advoid_pro"]

    @Test func storeKitFileHasPlans() async throws {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "AdVoid", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.disableDialogs = true

        let products = try await Product.products(for: Self.productIDs)
        #expect(Set(products.map(\.id)) == Self.productIDs)

        let yearly = try #require(products.first { $0.id == "advoid_pro" })
        let trial = try #require(yearly.subscription?.introductoryOffer)
        #expect(trial.paymentMode == .freeTrial)
        let period = trial.period
        #expect((period.unit == .week && period.value == 1) || (period.unit == .day && period.value == 7))

        let monthly = try #require(products.first { $0.id == "advoid_pro_monthly" })
        #expect(monthly.subscription?.introductoryOffer == nil)
        #expect(yearly.subscription?.subscriptionGroupID == monthly.subscription?.subscriptionGroupID)
    }

    @Test func recordedExpiryControlsAccess() async {
        let saved = Subscription.recordedExpiry
        defer { Subscription.record(activeUntil: saved) }
        let now = Date()
        Subscription.record(activeUntil: now.addingTimeInterval(3600))
        #expect(await Subscription.isActive(at: now))
        Subscription.record(activeUntil: nil)
        #expect(Subscription.recordedExpiry == nil)
    }
}
