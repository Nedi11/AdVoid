import Foundation

/// Pages App Review expects to be reachable in the app, including before purchase.
enum AppLinks {
    static let privacy = URL(string: "https://roxuh.com/advoid/privacy")!
    /// Includes Apple's standard licence agreement by reference.
    static let terms = URL(string: "https://roxuh.com/advoid/tos")!
    static let support = URL(string: "https://roxuh.com/advoid")!
}
