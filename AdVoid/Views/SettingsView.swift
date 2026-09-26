import SwiftUI

struct SettingsView: View {
    @Environment(BlocklistManager.self) private var lists
    @Environment(TunnelController.self) private var tunnel
    @State private var upstream = UpstreamDNS.current
    @State private var showingAddList = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(BlocklistSource.builtIn) { source in
                        BlocklistToggle(source: source)
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
                    Text("Lists refresh automatically when you open the app and they're more than three days old.")
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
                    Text("AdVoid runs a local VPN on your iPhone that only handles DNS lookups. Lookups for ad and tracker domains get a dead-end answer, so those requests never leave your phone. Your other traffic isn't routed through AdVoid or sent to any server.")
                    Text("DNS blocking can't remove ads served from the same domain as the content, like YouTube's. The Safari extension handles those on the web; inside the YouTube and Instagram apps, traffic is encrypted and certificate-pinned, so no blocker can reach them. Apps using their own encrypted DNS, or iCloud Private Relay in Safari, bypass DNS blocking. iOS allows one VPN at a time.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                if let count = lists.counts[source.id] {
                    Text("\(count.formatted()) domains")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
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

private struct SafariSection: View {
    @Environment(StatsModel.self) private var model

    var body: some View {
        Section {
            LabeledContent("Status") {
                Label(model.safariExtensionActive ? "On" : "Not set up",
                      systemImage: model.safariExtensionActive ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(model.safariExtensionActive ? .green : .orange)
            }
            if !model.safariExtensionActive {
                VStack(alignment: .leading, spacing: 6) {
                    Text("1. Open Settings › Apps › Safari › Extensions")
                    Text("2. Tap AdVoid and turn it on")
                    Text("3. Set youtube.com and instagram.com to Allow")
                }
                .font(.subheadline)
                Button("Open Settings", systemImage: "gear") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }
        } header: {
            Text("YouTube & Instagram in Safari")
        } footer: {
            Text("Removes YouTube video ads and sponsored posts when you use these sites in Safari. Watch YouTube in Safari instead of the app to go ad-free.")
        }
    }
}
