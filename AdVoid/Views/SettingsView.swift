import SafariServices
import StoreKit
import SwiftUI

struct SettingsView: View {
    @Environment(BlocklistManager.self) private var lists
    @Environment(TunnelController.self) private var tunnel
    @State private var upstream = UpstreamDNS.current
    @State private var showingAddList = false

    var body: some View {
        NavigationStack {
            Form {
                SubscriptionSection()

                Section {
                    EssentialsToggle()
                    ForEach(lists.builtInSources) { source in
                        BlocklistToggle(source: source)
                    }
                    NavigationLink("Sources & licenses") {
                        CreditsView()
                    }
                } header: {
                    Text("Blocklists")
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
                        LabeledContent("Last updated", value: lastUpdated.formatted(.relative(presentation: .named)))
                    }
                    if let error = lists.lastError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                } footer: {
                    Text("Lists check for updates when you open AdVoid, at most every 12 hours. iOS doesn't let them update while the app is closed.")
                }

                SafariSection()

                Section("Your rules") {
                    NavigationLink {
                        DomainListEditor(kind: .allowed)
                    } label: {
                        LabeledContent("Always allow", value: "\(lists.allowlist.count)")
                    }
                    NavigationLink {
                        DomainListEditor(kind: .blocked)
                    } label: {
                        LabeledContent("Always block", value: "\(lists.customBlocked.count)")
                    }
                }

                Section {
                    Picker("Resolver", selection: $upstream) {
                        ForEach(UpstreamDNS.allCases) { dns in
                            Text("\(dns.name) (\(dns.address))").tag(dns)
                        }
                    }
                    .onChange(of: upstream) { _, value in
                        UpstreamDNS.current = value
                        Task { await tunnel.restartIfRunning() }
                    }
                } header: {
                    Text("Upstream DNS")
                } footer: {
                    Text("Lookups that aren't blocked are sent here.")
                }

                Section("How it works") {
                    HowItWorksRow(symbol: "shield.lefthalf.filled", tint: .green, title: "Blocks at the source",
                                  text: "AdVoid runs a VPN on your iPhone that only looks at DNS, the lookups apps make before connecting. Lookups for ad and tracker domains get a dead end, so those requests never go out.")
                    HowItWorksRow(symbol: "lock.fill", tint: .blue, title: "Stays on your iPhone",
                                  text: "Your other traffic isn't routed through AdVoid, and your activity history never leaves this device. Allowed lookups go to the DNS provider you choose, unencrypted.")
                    HowItWorksRow(symbol: "play.rectangle.fill", tint: .red, title: "YouTube needs Safari",
                                  text: "YouTube serves ads from the same domains as its videos, so DNS can't separate them. The Safari extension removes them on youtube.com. No blocker can reach ads inside the YouTube app.")
                    HowItWorksRow(symbol: "exclamationmark.triangle.fill", tint: .orange, title: "What can get around it",
                                  text: "Apps that use their own encrypted DNS, and Safari with iCloud Private Relay on. iOS runs one VPN at a time, so another VPN turns AdVoid off.")
                }

                Section {
                    Link("Privacy policy", destination: AppLinks.privacy)
                    Link("Terms of use", destination: AppLinks.terms)
                    Link("Get help", destination: AppLinks.support)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingAddList) {
                AddBlocklistView()
            }
        }
    }
}

private struct BlocklistToggle: View {
    let source: BlocklistSource
    @Environment(BlocklistManager.self) private var lists

    var body: some View {
        Toggle(isOn: Binding(
            get: { lists.enabledIDs.contains(source.id) },
            set: { on in Task { await lists.setEnabled(source, on) } }
        )) {
            VStack(alignment: .leading, spacing: 3) {
                Text(source.name)
                Text(source.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(source.isCustom ? 1 : nil)
                    .truncationMode(.middle)
                if let count = lists.domainCount(for: source) {
                    Text("\(count.formatted()) domains")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

private struct HowItWorksRow: View {
    let symbol: String
    let tint: Color
    let title: String
    let text: String

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
                Text("\(BlocklistManager.essentialsDomainCount.formatted()) domains")
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

        var title: String { self == .allowed ? "Always allow" : "Always block" }
        var footer: String {
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
                ForEach(domains, id: \.self) { Text($0) }
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
    @Environment(SubscriptionModel.self) private var subscription
    @State private var showingManage = false

    var body: some View {
        if SubscriptionModel.isConfigured {
            Section("Subscription") {
                LabeledContent("AdVoid Pro", value: detail)
                Button("Manage subscription", systemImage: "creditcard") {
                    showingManage = true
                }
            }
            .manageSubscriptionsSheet(isPresented: $showingManage)
        }
    }

    private var detail: String {
        guard let end = subscription.periodEnd?.formatted(date: .abbreviated, time: .omitted) else { return "Active" }
        if subscription.isTrial { return "Free trial until \(end)" }
        return subscription.willRenew ? "Renews \(end)" : "Ends \(end)"
    }
}

private struct SafariSection: View {
    @Environment(StatsModel.self) private var model

    var body: some View {
        Section {
            HStack {
                Text("Status")
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: model.safariExtensionActive ? "checkmark.circle.fill" : "exclamationmark.circle")
                    Text(model.safariExtensionActive ? "On" : "Not set up")
                }
                .foregroundStyle(model.safariExtensionActive ? .green : .orange)
            }
            if !model.safariExtensionActive {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Open Settings › Apps › Safari › Extensions")
                    Text("2. Tap AdVoid and turn it on")
                    Text("3. Set youtube.com to Allow")
                }
                .font(.subheadline)
                Button("Open Safari Extensions", systemImage: "gear") {
                    SafariExtensionSettings.open()
                }
            }
        } header: {
            Text("YouTube in Safari")
        } footer: {
            Text("Removes YouTube video ads when you use youtube.com in Safari. Watch YouTube in Safari instead of the app to go ad-free.")
        }
    }
}

private struct CreditsView: View {
    @Environment(BlocklistManager.self) private var lists

    var body: some View {
        List {
            Section {
                Text(lists.catalog.notice)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(lists.catalog.lists) { entry in
                Section(entry.name) {
                    LabeledContent("Maintained by", value: entry.source.author)
                    LabeledContent("Domains", value: entry.domainCount.formatted())
                    LabeledContent("Updated", value: entry.updatedAt.formatted(date: .abbreviated, time: .omitted))
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

enum SafariExtensionSettings {
    static let extensionID = "com.roxuh.advoid.safari"

    /// Goes straight to AdVoid in Safari's extension settings where iOS allows it,
    /// otherwise to AdVoid's page in Settings.
    @MainActor
    static func open() {
        if #available(iOS 26.2, *) {
            SFSafariSettings.openExtensionsSettings(forIdentifiers: [extensionID]) { error in
                if error != nil { openAppSettings() }
            }
        } else {
            openAppSettings()
        }
    }

    @MainActor
    private static func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
