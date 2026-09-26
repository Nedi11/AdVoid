import SwiftUI

struct SettingsView: View {
    @Environment(BlocklistManager.self) private var lists
    @Environment(TunnelController.self) private var tunnel
    @State private var upstream = UpstreamDNS.current

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(BlocklistSource.all) { source in
                        Toggle(isOn: Binding(
                            get: { lists.enabledIDs.contains(source.id) },
                            set: { on in Task { await lists.setEnabled(source, on) } }
                        )) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(source.name)
                                Text(source.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let count = lists.counts[source.id] {
                                    Text("\(count.formatted()) domains")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Blocklists")
                } footer: {
                    Text("More lists block more, but are more likely to break an app or site. If something stops working, find it in Activity and swipe to allow it.")
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
                    Text("Shield runs a local VPN on your iPhone that only handles DNS lookups. Lookups for ad and tracker domains get a dead-end answer, so those requests never leave your phone. Your other traffic isn't routed through Shield or sent to any server.")
                    Text("DNS blocking can't remove ads served from the same domain as the content, such as YouTube ads. Apps using their own encrypted DNS, or iCloud Private Relay in Safari, bypass it. iOS allows one VPN at a time.")
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
            .navigationTitle("Settings")
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
