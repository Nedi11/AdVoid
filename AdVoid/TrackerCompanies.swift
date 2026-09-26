import Foundation

/// Maps well-known ad and tracking domains to the company that runs them.
enum TrackerCompanies {
    private static let owners: [String: String] = [
        "doubleclick.net": "Google", "googlesyndication.com": "Google", "googleadservices.com": "Google",
        "google-analytics.com": "Google", "googletagmanager.com": "Google", "googletagservices.com": "Google",
        "app-measurement.com": "Google", "crashlytics.com": "Google", "admob.com": "Google",
        "adservice.google.com": "Google", "firebaselogging-pa.googleapis.com": "Google",
        "facebook.com": "Meta", "facebook.net": "Meta", "fbcdn.net": "Meta", "instagram.com": "Meta",
        "amazon-adsystem.com": "Amazon", "assoc-amazon.com": "Amazon",
        "ads-twitter.com": "X", "twitter.com": "X", "x.com": "X",
        "tiktok.com": "TikTok", "tiktokv.com": "TikTok", "byteoversea.com": "TikTok", "ibytedtos.com": "TikTok",
        "bing.com": "Microsoft", "clarity.ms": "Microsoft", "msn.com": "Microsoft",
        "linkedin.com": "Microsoft", "app-center.ms": "Microsoft",
        "yahoo.com": "Yahoo", "yahoo.net": "Yahoo", "adtechus.com": "Yahoo",
        "appsflyer.com": "AppsFlyer", "appsflyersdk.com": "AppsFlyer",
        "adjust.com": "Adjust", "adjust.io": "Adjust", "branch.io": "Branch", "kochava.com": "Kochava",
        "applovin.com": "AppLovin", "applvn.com": "AppLovin", "unity3d.com": "Unity", "unityads.unity3d.com": "Unity",
        "ironsrc.com": "Unity", "ironsrc.mobi": "Unity", "criteo.com": "Criteo", "criteo.net": "Criteo",
        "taboola.com": "Taboola", "outbrain.com": "Outbrain", "adnxs.com": "Xandr", "adsrvr.org": "The Trade Desk",
        "scorecardresearch.com": "Comscore", "comscore.com": "Comscore", "moatads.com": "Oracle",
        "mixpanel.com": "Mixpanel", "amplitude.com": "Amplitude", "segment.io": "Twilio Segment",
        "hotjar.com": "Hotjar", "sentry.io": "Sentry", "bugsnag.com": "Bugsnag", "nr-data.net": "New Relic",
        "snapchat.com": "Snap", "sc-static.net": "Snap", "pubmatic.com": "PubMatic", "rubiconproject.com": "Magnite",
        "openx.net": "OpenX", "inmobi.com": "InMobi", "vungle.com": "Liftoff", "chartboost.com": "Chartboost",
        "onesignal.com": "OneSignal", "braze.com": "Braze", "appboy.com": "Braze", "samsungads.com": "Samsung",
    ]

    static func company(for domain: String) -> String? {
        var candidate = Substring(domain)
        while true {
            if let owner = owners[String(candidate)] { return owner }
            guard let dot = candidate.firstIndex(of: ".") else { return nil }
            candidate = candidate[candidate.index(after: dot)...]
        }
    }

    /// Blocked lookups grouped by company, largest first. Unknown owners are left out.
    static func top(from counts: [String: Int], limit: Int) -> [(company: String, count: Int)] {
        var totals: [String: Int] = [:]
        for (domain, n) in counts {
            if let company = company(for: domain) { totals[company, default: 0] += n }
        }
        return totals.sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map { (company: $0.key, count: $0.value) }
    }
}
