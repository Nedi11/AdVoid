# AdVoid production readiness assessment

Reviewed 27 September 2026. **Verdict: do not release to paying customers yet.** The app builds and its existing tests pass, but DNS reliability, rule installation, subscription transitions, and release disclosures need work. Passing a simulator suite does not establish that a packet tunnel is reliable on an iPhone.

Baseline: Git commit `07c9e1a178a0ca2a2c67b956b611c663f0f9fed0`. During the audit, outside edits removed StevenBlack from the bundled/source catalogs and added retired-list cleanup. Those edits were preserved. The race probe was rerun against the changed manager. The initial release archive describes the source snapshot built at that time, not a signed, uploaded distribution. No app implementation changes were made by this audit; its deliverables are in `output/readiness`.

## Evidence and scope

| Check | Result | Limits |
|---|---|---|
| Swift simulator suite, Xcode 27 / iOS 27 | 26 tests across 9 suites passed | Core parsing, matching, statistics, catalog and basic StoreKit configuration; no running packet tunnel |
| Existing JavaScript suite | 5 Node test-runner entries passed | Four list-builder tests and one file containing the YouTube pruning checks |
| Release archive for generic iOS device | Unsigned archive succeeded | Signing, provisioning, App Store validation and TestFlight not verified |
| Live list distribution | All five lists in fetched catalog downloaded; SHA-256, byte count, domain count, strict ordering and uniqueness passed | Point-in-time availability, not monitoring; live catalog still contained StevenBlack at fetch time |
| Native URLSession catalog request | HTTP 200, 4,474 bytes | Desktop URLSession; Python's default request received 403, while curl/native request succeeded |
| Rule-update race probe | Reproduced with actual manager/matcher code and isolated storage | Replaces AppGroup with a test directory; no device tunnel required |
| Safari behavioral probes | Four bad behaviors reproduced against actual scripts with controlled DOM/storage substitutes | Not a live YouTube/Instagram end-to-end test |
| Icon source | 1024×1024; all pixels opaque | PNG contains an alpha channel; inspect final compiled asset validation before shipping |
| Privacy manifests | Only RevenueCat's SDK manifest found in built app | No first-party manifest found in app or either extension |

Full evidence: `xcode-tests.log`, `release-archive.log`, `catalog-check.log`, `live-catalog.json`, `rule-race.log`, `rule-race-current.log`, `safari-probes.log`. Reproduction sources: `RuleRaceProbe.swift`, `safari-probes.mjs`, `check-catalog.py`.

## Release blockers

### R1 — P1: Valid DNS lookups requiring TCP cannot complete

Evidence: `PacketTunnel/PacketTunnelProvider.swift:91`, `Shared/UDPPacket.swift:29`, `PacketTunnel/DNSForwarder.swift:64`.

The tunnel accepts only IPv4 UDP packets. The forwarder uses only UDP. When an upstream response is truncated, it is returned unchanged, but a client's TCP retry to the tunnel DNS address is dropped. Clients starting with TCP are also dropped. This creates a reproducible protocol-level failure path for legitimate DNS responses; larger/DNSSEC responses particularly exercise it. Fragmented incoming IPv4 packets are also discarded without a recovery path.

Implement client-side TCP DNS handling and upstream TCP fallback, with bounded connection lifetimes and response sizes. Test truncation, explicit TCP queries, large answers and interrupted connections. [RFC 7766](https://www.rfc-editor.org/rfc/rfc7766.html) requires both transports for full general-purpose DNS implementations and describes timeout/interoperability consequences.

### R2 — P1: Resolver failures can make the phone appear offline while the app says Protected

Evidence: `PacketTunnel/DNSForwarder.swift:49–103`, `AdVoid/TunnelController.swift:18–24`.

Every allowed system DNS query depends on one configured resolver IP. There is no alternate resolver, bounded retry policy or health state. Expired and over-capacity requests are silently discarded. The UDP send completion does not surface processing errors. A better-path callback cancels the old socket without replaying outstanding requests; state `.waiting` has no explicit recovery strategy. A receive error stops the receive loop without itself replacing the connection.

The UI derives “Protected” solely from VPN connection status, which does not establish that DNS works or rules are loaded. Add a bounded recovery/failover policy, explicit failure replies where appropriate, and a provider health report covering resolver reachability, rules generation and filtering/subscription state. Test Wi-Fi/cellular transitions, captive portals, blocked UDP/53 and resolver outages on device. Do not silently bypass blocking during recovery without a deliberate documented policy.

### R3 — P1: An older rule build can overwrite a newer user choice

Evidence: `AdVoid/BlocklistManager.swift:298–320`; confirmed by `RuleRaceProbe.swift`.

`rebuild()` captures the current settings, launches a detached task, and lets that task write directly to the shared rule files. Other main-actor calls can enter while it awaits. Atomic file writes prevent partially written individual files, but do not order concurrent builds.

Observed output: immediately after disabling a 500,000-domain source, enabled IDs were empty and disk count was zero. When the older build finished, enabled IDs were still empty but disk/displayed counts became 500,000. An analogous sequence can revert allow/block changes.

Serialize publication of rule generations, or cancel/discard obsolete generations before committing. Publish block/allow files as one consistent generation and acknowledge that generation from the tunnel. Add a regression test that rapidly changes rules while a large rebuild is running.

### R4 — P1: Failed rule writes are reported as successful

Evidence: `AdVoid/BlocklistManager.swift:313–320`, `Shared/DomainMatcher.swift:22–25`, `Shared/AppGroup.swift:8–14`.

Both compiled-rule writes use `try?`. The manager then updates the displayed domain count and tells the tunnel to reload even if writes failed. Missing/unreadable rule files silently become empty matchers. AppGroup lookup also falls back to non-shared storage instead of surfacing a configuration failure. A disk/protection/entitlement failure can therefore leave old or empty filtering while the UI looks successful.

Propagate installation errors; preserve and identify the last known good generation; do not advance counts until commit succeeds. Make missing shared storage a diagnosable setup error. Test unavailable storage, failed writes, corrupted files and first boot/unlock behavior. This finding is established by source inspection, not a simulated device disk failure.

### R5 — P1: First-party required-reason API declarations are absent

The app and extensions use UserDefaults, including an App Group suite, but the archive contains only the RevenueCat SDK's manifest. An SDK's declaration is not a substitute for auditing the app's own API uses. Add appropriate `PrivacyInfo.xcprivacy` declarations to the relevant first-party bundles, verify their target membership and inspect the archive privacy report. Select reasons matching actual use, including App Group sharing. Apple documents these submission requirements in [Describing use of required reason API](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

### R6 — P1: Privacy claims and release disclosures do not match the architecture

Evidence: `AdVoid/Views/OnboardingView.swift:15–27`, `PacketTunnel/DNSForwarder.swift:64`, `AdVoid/SubscriptionModel.swift`, `AdVoid/Views/SettingsView.swift`.

Onboarding says “Everything stays on your phone.” Allowed DNS names are sent to a third-party resolver over plain UDP; RevenueCat handles subscription information; blocklist services receive download requests. DNS logs stay in shared local storage, but the blanket claim is inaccurate. “All your apps” also overstates coverage for apps using their own encrypted DNS or ads delivered from content domains. Settings explains some limitations only after the paywall.

No first-party privacy-policy/support link was found in onboarding or Settings. A remotely configured RevenueCat paywall may provide legal links; its current configuration was not inspected. Publish accurate disclosures and make privacy, terms, support and core limitations accessible before purchase. Verify App Store privacy answers against SDK configuration and actual network behavior.

Apple requires an accessible in-app privacy policy and defines additional disclosures/eligibility for VPN services and approved content-blocking providers in [App Review Guidelines 5.1.1 and 5.4](https://developer.apple.com/app-store/review/guidelines/). Confirm AdVoid's category and developer-account eligibility; this audit does not establish eligibility or predict review approval.

## Additional defects and hardening work

| ID / priority | Finding and impact | Required change / verification |
|---|---|---|
| R7 / P2 | Safari content scripts read `active` once. The probe confirmed an open paid page continues blocking after expiry, and an open unpaid page stays disabled after purchase. `youtube.js:17–22`, `instagram.js:17–18`. | Listen for storage changes, update DOM/CSS state and rescan. Refresh native entitlement on a reliable schedule/events instead of relying only on counter messages/startup. Test both transitions without reload. |
| R8 / P2 | YouTube forcibly unmutes a previously muted video after an ad (`youtube.js:59–70`). Reproduced. | Preserve the prior media mute state and restore only changes made by the extension, accounting for user changes and replaced video elements. |
| R9 / P2 | Instagram permanently marks a post checked as soon as media exists. A Sponsored label arriving later is missed (`instagram.js:20–31`). Reproduced. | Re-evaluate relevant changed posts/labels, handle recycled feed elements, and test supported locales and delayed rendering. |
| R10 / P2 | Automatic list refresh is in the initial view task, while returning to foreground only restarts stats polling (`AdVoidApp.swift:20–38`). An app that remains alive can use stale lists across many foreground visits. Settings says three days while code uses 12 hours. | Check staleness on foreground and coalesce updates; document realistic background refresh behavior and display partial failures accurately. |
| R11 / P2 | The 50 MB download check happens after `URLSession.data` has buffered the entire body (`BlocklistManager.swift:255–264`). A huge custom list can exhaust memory before rejection. | Stream/download with an enforced byte budget, validate response length when available, and bound parsed/compiled domain count and concurrent operations. |
| R12 / P2 | `restartIfRunning()` leaves on-demand enabled, gives disconnect only five seconds, and suppresses restart errors (`TunnelController.swift:95–101`). Rapid resolver changes can overlap. | Serialize start/stop/restart, handle cancellation and timeouts, coordinate on-demand, and surface failures. Validate on hardware. |
| R13 / P2 | Starter domains are always merged, even with every list switched off (`BlocklistManager.swift:309–311`). Users cannot infer the active rules from the toggles. | Make the starter list a visible source or explicitly define fallback-only behavior; test disabling all sources and allowlisting affected services. |
| R14 / P2 | A Safari activity timestamp less than a week old is displayed as “On” (`StatsModel.swift:20–24`). Disabling the extension can leave a false active status for days. | Call it “Last active” unless actual enabled/permission state can be determined; explain permission failures separately. |
| R15 / P2 | DNS responses are accepted solely by transaction ID (`DNSForwarder.swift:93–98`). There is no QR/question/type/class validation. | Match the response to its pending query, reject malformed/mismatched responses and test delayed ID reuse. This is a hardening gap, not a demonstrated remote exploit. |
| R16 / P2 | Shared subscription expiry bypasses StoreKit revocation checks until it expires; tunnel reevaluates only every six hours (`Subscription.swift:24–26`, `PacketTunnelProvider.swift:108–120`). | Define offline grace/refund/revocation behavior, promptly signal app-observed changes and test grace period, refund, renewal and expiry in both extensions. |
| R17 / P2 | No app/extension CI was found; the sole workflow tests/publishes lists. Package.resolved is explicitly ignored while RevenueCat uses a version range. | Add PR build/test checks, run Safari probes and release validation, and track the resolved dependency version for reproducible releases. |

## Privacy, security and operations review

Positive foundations: minimal DNS-only routing, narrow Safari host permissions, TLS blocklist downloads, verified list checksums, atomic individual file writes, bounded recent activity/domain counters, hashed list storage, and StoreKit verification in the entitlement fallback. The RevenueCat SDK key is a public client key by design; it is not evidence of a leaked secret.

Remaining work:

- Plain DNS offers no encryption of allowed domain queries. Make that clear; evaluate authenticated encrypted upstream transport without claiming it is currently implemented.
- Raw queried domains and dates are retained in shared UserDefaults. Decide and document logging opt-out, retention, reset semantics and backup treatment. Per-domain totals can remain indefinitely until pruned/reset; 30-day aggregate history does not make all DNS data expire after 30 days.
- Validate catalog IDs, uniqueness, URL schemes/hosts, counts and binary ordering before treating a catalog as usable. Current schema checking is mostly decoding plus version equality. Hashes provide integrity against the catalog; they do not protect against a compromised publisher/catalog.
- Add resolver error/latency counters and privacy-preserving diagnostic export. Current success-like stats are recorded before upstream success, so “allowed” does not mean “resolved.” Avoid uploading browsing history as diagnostics.
- List publishing retains previous versions and protects selected domains, which is useful. Still require alerts for repeated stale-list fallback, failed publication, bad live references and unexpected domain-count changes. The script can succeed while individual sources remain stale.
- Maintain a list rollback procedure and retain exact source snapshots/build inputs for redistributed compiled lists. Licensing review remains open: the remaining sources include GPL-licensed lists. Catalog credits and links alone do not prove redistribution obligations are met. Review exact source availability, notices and licenses; this is not a conclusion that the app itself must use GPL. See the upstream [HaGeZi license](https://raw.githubusercontent.com/hagezi/dns-blocklists/main/LICENSE) and [OISD license](https://raw.githubusercontent.com/sjhgvr/oisd/main/LICENSE).
- Clear the non-Sendable capture warning in the tunnel's subscription task; document queue confinement. Other build warnings included simulator-unreachable code and tooling/dependency notices, not build failures.

## Required release acceptance tests

These are **not completed** by this audit. A paired physical iPhone was visible, but no VPN installation/network disruption, real purchase, or hardware soak test was performed.

| Area | Minimum evidence required |
|---|---|
| Device networking | Actual packet tunnel on lowest supported iOS 26 and current supported release; IPv4, IPv6-only/NAT64, home/cellular/enterprise Wi-Fi, captive portal, VPN conflict and Private Relay behavior |
| Recovery | Repeated Wi-Fi/cellular handovers, airplane mode, sleep/wake, locked device, reboot before/after first unlock, provider termination, resolver failure; no persistent DNS outage |
| DNS correctness | A/AAAA/HTTPS/SVCB, NXDOMAIN, TCP/truncation, EDNS and large answers, concurrent ID collisions, malformed input, allowed-parent/blocked-child precedence |
| Load and battery | Idle and browsing battery comparison, sustained query load, peak extension memory on the lowest-memory supported device, maximum lists and pending requests, 24–48-hour soak |
| Rules | Rapid toggles/edits during updates, failed downloads, checksum mismatch, corrupted/missing storage, offline first launch, disk failure, retired sources and rollback; newest choice always wins |
| Subscription | TestFlight sandbox purchase, restore/reinstall/second device, cancellation, renewal, refund/revocation, billing retry/grace, offline launch, missing offerings/error UI, extension transitions without reload |
| Safari | Actual mobile YouTube/Instagram, signed-in/out, navigation/autoplay, restored tabs, permission denial, multiple locales, muted media and delayed sponsored labels; tolerate site changes |
| Accessibility | VoiceOver, large Dynamic Type, smaller screens, contrast and Reduce Motion across onboarding/paywall/settings/charts; verify no clipped purchase/restore/legal controls |
| Distribution | Signed archive/export, both extension entitlements and App Group provisioning, App Store validation, privacy report, icon validation, supported-device matrix and absence of debug/demo data |
| Store/operations | Approved products/entitlement mapping, accurate trial/price/legal copy, privacy/terms/support URLs, review notes, list/license obligations, health alerts and rollback ownership |

## Recommended implementation order

1. Fix R1–R4: DNS transport/recovery and transactional, ordered rule installation.
2. Correct disclosures and first-party privacy manifests; make release/legal/help material accessible before purchase.
3. Fix subscription synchronization and the reproduced Safari behavior defects; add regression coverage and CI.
4. Complete device, TestFlight, accessibility and endurance acceptance tests; review signing/store configuration and list redistribution obligations.
5. Repeat the readiness review on a frozen release commit and retain the signed-archive and hardware test evidence.

There is no reliable percentage-complete score from this audit. The meaningful gate is that the identified blockers are fixed and hardware acceptance evidence exists.

Final recheck: workspace HEAD became `48d0d726145f4278228e350803390fc1b42cac45` as the outside catalog/cleanup changes were committed. The follow-up simulator run again passed all 26 tests (`xcode-tests-current.log`), and the 500,000-domain race reproduced against the updated manager (`rule-race-current.log`). At completion, only `output/readiness/` was untracked; the audit did not modify app source files.
