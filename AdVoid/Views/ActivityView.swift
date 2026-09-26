import SwiftUI

struct ActivityView: View {
    @Environment(StatsModel.self) private var model
    @Environment(BlocklistManager.self) private var lists
    @Environment(TunnelController.self) private var tunnel

    @State private var filter = Filter.all
    @State private var search = ""

    enum Filter: String, CaseIterable {
        case all = "All"
        case blocked = "Blocked"
        case allowed = "Allowed"
    }

    private var entries: [QueryLogEntry] {
        model.stats.recent.filter { entry in
            switch filter {
            case .all: true
            case .blocked: entry.blocked
            case .allowed: !entry.blocked
            }
        }
        .filter { search.isEmpty || $0.domain.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                ForEach(entries) { entry in
                    ActivityRow(entry: entry, isAllowlisted: lists.allowlist.contains(entry.domain))
                        .swipeActions {
                            if entry.blocked {
                                Button("Allow") { Task { await lists.allow(entry.domain) } }
                                    .tint(.green)
                            } else {
                                Button("Block") { Task { await lists.block(entry.domain) } }
                                    .tint(.red)
                            }
                        }
                        .contextMenu {
                            Button("Allow \(entry.domain)", systemImage: "checkmark.circle") {
                                Task { await lists.allow(entry.domain) }
                            }
                            Button("Block \(entry.domain)", systemImage: "hand.raised") {
                                Task { await lists.block(entry.domain) }
                            }
                            Button("Copy", systemImage: "doc.on.doc") {
                                UIPasteboard.general.string = entry.domain
                            }
                        }
                }
            }
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "No activity yet",
                        systemImage: "antenna.radiowaves.left.and.right",
                        description: Text(tunnel.isOn
                                          ? "Lookups made by your apps show up here."
                                          : "Turn on protection to see what your apps connect to."))
                }
            }
            .searchable(text: $search, prompt: "Search domains")
            .navigationTitle("Activity")
        }
    }
}

private struct ActivityRow: View {
    let entry: QueryLogEntry
    let isAllowlisted: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.blocked ? "xmark.shield.fill" : "checkmark.circle")
                .foregroundStyle(entry.blocked ? .red : .secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.domain)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(entry.date, format: .dateTime.hour().minute().second())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isAllowlisted {
                Text("Allowed")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.green)
            }
        }
    }
}
