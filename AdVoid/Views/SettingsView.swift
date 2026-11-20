import StoreKit
import SwiftUI

/// Pages under Settings, so other tabs can open one directly.
enum SettingsPage: Hashable {
    case blocklists, allowed, blocked, dns, howItWorks
}

struct SettingsView: View {
    @Binding var path: [SettingsPage]
    @Environment(BlocklistManager.self) private var lists
    /// Watched so the provider shown here updates when it's changed on its page.
    @AppStorage("upstreamDNS", store: AppGroup.defaults) private var upstreamID = UpstreamDNS.cloudflare.rawValue

    private var enabledListCount: Int {
        lists.enabledIDs.count + (lists.essentialsEnabled ? 1 : 0)
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                SubscriptionSection()

                Section {
                    NavigationLink(value: SettingsPage.blocklists) {
                        LabeledContent {
                            Text("\(enabledListCount) on")
                        } label: {
                            Label("Blocklists", systemImage: "list.bullet.rectangle")
                        }
                    }
                    NavigationLink(value: SettingsPage.allowed) {
                        LabeledContent {
                            Text(lists.allowlist.count, format: .number)
                        } label: {
                            Label("Always allow", systemImage: "checkmark.circle")
                        }
                    }
                    NavigationLink(value: SettingsPage.blocked) {
                        LabeledContent {
                            Text(lists.customBlocked.count, format: .number)
                        } label: {
                            Label("Always block", systemImage: "hand.raised")
                        }
                    }
                } header: {
                    Text("Blocking")
                } footer: {
                    Text("If something stops working, find it in Activity and swipe to allow it.")
                }

                Section {
                    NavigationLink(value: SettingsPage.dns) {
                        LabeledContent {
                            Text(verbatim: UpstreamDNS(rawValue: upstreamID)?.name ?? UpstreamDNS.current.name)
                        } label: {
                            Label("DNS provider", systemImage: "server.rack")
                        }
                    }
                    LanguagePicker()
                } header: {
                    Text("General")
                } footer: {
                    Text("System follows the language set for AdVoid in the iOS Settings app.")
                }

                Section {
                    NavigationLink(value: SettingsPage.howItWorks) {
                        Label("How it works", systemImage: "info.circle")
                    }
                    Link(destination: AppLinks.privacy) {
                        Label("Privacy policy", systemImage: "lock")
                    }
                    Link(destination: AppLinks.terms) {
                        Label("Terms of use", systemImage: "doc.text")
                    }
                    Link(destination: AppLinks.support) {
                        Label("Get help", systemImage: "questionmark.bubble")
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationDestination(for: SettingsPage.self) { page in
                switch page {
                case .blocklists: BlocklistsView()
                case .allowed: DomainListEditor(kind: .allowed)
                case .blocked: DomainListEditor(kind: .blocked)
                case .dns: DNSSettingsView()
                case .howItWorks: HowItWorksView()
                }
            }
        }
    }
}

/// Built-in and added lists, and when they last updated.
private struct BlocklistsView: View {
    @Environment(\.locale) private var locale
    @Environment(BlocklistManager.self) private var lists
    @State private var showingAddList = false

    var body: some View {
        Form {
            Section {
                EssentialsToggle()
                ForEach(lists.builtInSources) { source in
                    BlocklistToggle(source: source)
                }
            } header: {
                Text("Built-in lists")
            } footer: {
                Text("More lists block more, but are more likely to break an app or site. If something stops working, find it in Activity and swipe to allow it.")
            }

            Section {
                ForEach(lists.customSources) { source in
                    BlocklistToggle(source: source)
                        .swipeActions {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await lists.removeCustom(source) }
                            }
                        }
                        .contextMenu {
                            Button("Copy link", systemImage: "link") {
                                UIPasteboard.general.url = source.url
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await lists.removeCustom(source) }
                            }
                        }
                }
                Button("Add blocklist", systemImage: "plus") {
                    showingAddList = true
                }
            } header: {
                Text("Your blocklists")
            } footer: {
                Text("Add any list by link. It updates along with the built-in lists.")
            }

            Section {
                Button {
                    Task { await lists.updateAll() }
                } label: {
                    HStack {
                        Label("Update lists now", systemImage: "arrow.down.circle")
                        Spacer()
                        if lists.isUpdating { ProgressView() }
                    }
                }
                .disabled(lists.isUpdating)
                if let lastUpdated = lists.lastUpdated {
                    LabeledContent("Last updated", value: lastUpdated.formatted(.relative(presentation: .named).locale(locale)))
                }
                if let error = lists.lastError {
                    Text(error).font(.footnote).foregroundStyle(.red)
                }
            } footer: {
                Text("Lists check for updates when you open AdVoid, at most every 12 hours. iOS doesn't let them update while the app is closed.")
            }

            Section {
                NavigationLink("Sources & licenses") {
                    CreditsView()
                }
            }
        }
        .navigationTitle("Blocklists")
        .sheet(isPresented: $showingAddList) {
            AddBlocklistView()
        }
    }
}

/// Which resolver allowed lookups go to, and whether they may go out unencrypted.
private struct DNSSettingsView: View {
    @Environment(TunnelController.self) private var tunnel
    @State private var upstream = UpstreamDNS.current
    @State private var allowsPlainFallback = UpstreamDNS.allowsPlainFallback

    var body: some View {
        Form {
            Section {
                Picker("Provider", selection: $upstream) {
                    ForEach(UpstreamDNS.allCases) { dns in
                        Text(verbatim: "\(dns.name) (\(dns.address))").tag(dns)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
                .onChange(of: upstream) { _, value in
                    UpstreamDNS.current = value
                    Task { await tunnel.restartIfRunning() }
                }
            } header: {
                Text("Provider")
            } footer: {
                if upstream == .cloudflareSecurity {
                    Text("Cloudflare Security also blocks malware sites.")
                } else if upstream == .cloudflareFamily {
                    Text("Cloudflare Family also blocks malware and adult sites.")
                }
            }

            Section {
                Toggle("Fall back to plain DNS", isOn: $allowsPlainFallback)
                    .onChange(of: allowsPlainFallback) { _, value in
                        UpstreamDNS.allowsPlainFallback = value
                        Task { await tunnel.restartIfRunning() }
                    }
            } footer: {
                Text("Lookups go to the selected DNS provider, encrypted. Some networks block encrypted DNS. When the switch is on, AdVoid falls back to plain DNS there so you don't lose your connection.")
            }
        }
        .navigationTitle("DNS provider")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct HowItWorksView: View {
    var body: some View {
        List {
            HowItWorksRow(symbol: "shield.lefthalf.filled", tint: .green, title: "Blocks at the source",
                          text: "AdVoid runs a VPN on your iPhone that only looks at DNS, the lookups apps make before connecting. Lookups for ad and tracker domains get a dead end, so those requests never go out.")
            HowItWorksRow(symbol: "lock.fill", tint: .blue, title: "Stays on your iPhone",
                          text: "Your other traffic isn't routed through AdVoid, and your activity history never leaves this device. Allowed lookups go to the DNS provider you choose, encrypted.")
            HowItWorksRow(symbol: "play.rectangle.fill", tint: .red, title: "Some ads can't be blocked",
                          text: "YouTube and some other apps serve ads from the same servers as their content. Blocking those servers would break the app too.")
            HowItWorksRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: "What can get around it",
                          text: "Apps that use their own encrypted DNS, and Safari with iCloud Private Relay on. iOS runs one VPN at a time, so another VPN turns AdVoid off.")
        }
        .navigationTitle("How it works")
    }
}

private struct BlocklistToggle: View {
    @Environment(\.locale) private var locale
    let source: BlocklistSource
    @Environment(BlocklistManager.self) private var lists

    var body: some View {
        Toggle(isOn: Binding(
            get: { lists.enabledIDs.contains(source.id) },
            set: { on in Task { await lists.setEnabled(source, on) } }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                // Built-in descriptions come from the list catalog in English; they're translated by their text.
                (source.isCustom ? Text(verbatim: source.detail) : Text(LocalizedStringKey(source.detail)))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(source.isCustom ? 1 : nil)
                    .truncationMode(.middle)
                if let count = lists.domainCount(for: source) {
                    Text("\(count.formatted(.number.locale(locale))) domains")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private struct LanguagePicker: View {
    @Environment(LanguageSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        Picker(selection: $settings.language) {
            Text("System").tag(AppLanguage.system)
                .accessibilityIdentifier("language-option-system")
            ForEach(settings.availableLanguages) { language in
                Text(verbatim: language.nativeName).tag(language)
                    .accessibilityIdentifier("language-option-\(language.rawValue)")
            }
        } label: {
            Label("Language", systemImage: "globe")
        }
        .pickerStyle(.navigationLink)
        .accessibilityIdentifier("languagePicker")
    }
}

private struct HowItWorksRow: View {
    let symbol: String
    let tint: Color
    let title: LocalizedStringKey
    let text: LocalizedStringKey

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: symbol).foregroundStyle(tint)
        }
        .padding(.vertical, 2)
    }
}

private struct EssentialsToggle: View {
    @Environment(\.locale) private var locale
    @Environment(BlocklistManager.self) private var lists

    var body: some View {
        Toggle(isOn: Binding(
            get: { lists.essentialsEnabled },
            set: { on in Task { await lists.setEssentialsEnabled(on) } }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Essentials")
                Text("The biggest ad and tracking networks, built into AdVoid.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(BlocklistManager.essentialsDomainCount.formatted(.number.locale(locale))) domains")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct AddBlocklistView: View {
    @Environment(BlocklistManager.self) private var lists
    @Environment(\.dismiss) private var dismiss
    @State private var address = ""
    @State private var name = ""
    @State private var isAdding = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/blocklist.txt", text: $address, axis: .vertical)
                        .environment(\.layoutDirection, .leftToRight)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    TextField("Name (optional)", text: $name)
                } footer: {
                    Text("Works with hosts files (0.0.0.0 ads.example.com), plain domain lists, *.domain wildcard lists and ||domain^ adblock rules. Any subdomain of a listed domain is blocked too.")
                }

                if let error {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add blocklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isAdding {
                        ProgressView()
                    } else {
                        Button("Add", role: .confirm, action: add)
                            .disabled(address.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
            .interactiveDismissDisabled(isAdding)
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        error = nil
        isAdding = true
        Task {
            defer { isAdding = false }
            do {
                try await lists.addCustom(address: address, name: name)
                dismiss()
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}

struct DomainListEditor: View {
    enum Kind {
        case allowed, blocked

        var title: LocalizedStringKey { self == .allowed ? "Always allow" : "Always block" }
        var footer: LocalizedStringKey {
            self == .allowed
                ? "These domains and their subdomains are never blocked."
                : "These domains and their subdomains are always blocked."
        }
    }

    let kind: Kind
    @Environment(BlocklistManager.self) private var lists
    @State private var newDomain = ""
    @State private var invalid = false

    private var domains: [String] { kind == .allowed ? lists.allowlist : lists.customBlocked }

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("example.com", text: $newDomain)
                        .environment(\.layoutDirection, .leftToRight)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onSubmit(add)
                    Button("Add", action: add)
                        .disabled(newDomain.isEmpty)
                }
                if invalid {
                    Text("Enter a domain like ads.example.com").font(.footnote).foregroundStyle(.red)
                }
            } footer: {
                Text(kind.footer)
            }

            Section {
                ForEach(domains, id: \.self) { domain in
                    Text(verbatim: domain).environment(\.layoutDirection, .leftToRight)
                }
                    .onDelete { offsets in
                        let removed = offsets.map { domains[$0] }
                        Task {
                            if kind == .allowed {
                                await lists.removeFromAllowlist(removed)
                            } else {
                                await lists.removeFromCustomBlocked(removed)
                            }
                        }
                    }
            }
        }
        .navigationTitle(kind.title)
    }

    private func add() {
        var input = newDomain.trimmingCharacters(in: .whitespaces)
        if let host = URL(string: input)?.host(), input.contains("://") { input = host }
        guard let domain = BlocklistParser.validated(input) else {
            invalid = true
            return
        }
        invalid = false
        newDomain = ""
        Task {
            if kind == .allowed { await lists.allow(domain) } else { await lists.block(domain) }
        }
    }
}

private struct SubscriptionSection: View {
    @Environment(\.locale) private var locale
    @Environment(SubscriptionModel.self) private var subscription
    @State private var showingManage = false

    var body: some View {
        if SubscriptionModel.isConfigured {
            Section("Subscription") {
                LabeledContent {
                    Text(detail)
                } label: {
                    Text(verbatim: "AdVoid Pro")
                }
                Button("Manage subscription", systemImage: "creditcard") {
                    showingManage = true
                }
            }
            .manageSubscriptionsSheet(isPresented: $showingManage)
        }
    }

    private var detail: LocalizedStringKey {
        guard let end = subscription.periodEnd?.formatted(.dateTime.year().month(.abbreviated).day().locale(locale)) else { return "Active" }
        if subscription.isTrial { return "Free trial until \(end)" }
        return subscription.willRenew ? "Renews \(end)" : "Ends \(end)"
    }
}

private struct CreditsView: View {
    @Environment(\.locale) private var locale
    @Environment(BlocklistManager.self) private var lists

    var body: some View {
        List {
            Section {
                Text(LocalizedStringKey(lists.catalog.notice))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(lists.catalog.lists) { entry in
                Section(entry.name) {
                    LabeledContent("Maintained by", value: entry.source.author)
                    LabeledContent("Domains", value: entry.domainCount.formatted(.number.locale(locale)))
                    LabeledContent("Updated", value: entry.updatedAt.formatted(.dateTime.year().month(.abbreviated).day().locale(locale)))
                    Link(destination: entry.license.url) {
                        LabeledContent("License", value: entry.license.name)
                    }
                    Link("Project page", destination: entry.source.homepage)
                }
            }

            if !lists.customSources.isEmpty {
                Section {
                    ForEach(lists.customSources) { source in
                        LabeledContent(source.name, value: source.url.host() ?? "")
                    }
                } header: {
                    Text("Added by you")
                } footer: {
                    Text("Downloaded directly from their own links. Check each list's license before sharing it.")
                }
            }
        }
        .navigationTitle("Sources & licenses")
    }
}
