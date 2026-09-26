import SwiftUI

struct ActivityView: View {
    @Environment(StatsModel.self) private var model
    @Environment(BlocklistManager.self) private var lists
    @Environment(TunnelController.self) private var tunnel

    @State private var filter = Filter.all
    @State private var search = ""
    /// What the list shows. Follows new lookups only while live, so rows don't
    /// shift under the user's finger while they're reading or swiping.
    @State private var shown: [QueryLogEntry] = []
    @State private var isAtTop = true
    @State private var isPaused = false

    enum Filter: String, CaseIterable {
        case all = "All"
        case blocked = "Blocked"
        case allowed = "Allowed"
    }

    private var isLive: Bool { isAtTop && !isPaused }

    /// Lookups that arrived since the list was frozen.
    private var newCount: Int {
        guard let newest = shown.first else { return model.stats.recent.count }
        return model.stats.recent.firstIndex(of: newest) ?? model.stats.recent.count
    }

    private var entries: [QueryLogEntry] {
        shown.filter { entry in
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
            ScrollViewReader { proxy in
                List {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .id(Self.topID)

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
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top < 40
                } action: { _, atTop in
                    isAtTop = atTop
                }
                .overlay(alignment: .bottom) {
                    if !isLive && newCount > 0 {
                        Button {
                            isPaused = false
                            withAnimation { proxy.scrollTo(Self.topID, anchor: .top) }
                        } label: {
                            Label(newCount >= Stats.recentLimit ? "Lots of new activity" : "\(newCount) new",
                                  systemImage: "arrow.up")
                                .font(.subheadline.weight(.semibold))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .animation(.snappy, value: !isLive && newCount > 0)
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
            .toolbar {
                Button(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill") {
                    isPaused.toggle()
                }
            }
            .onAppear { shown = model.stats.recent }
            .onChange(of: model.stats.recent) { _, latest in
                if isLive { shown = latest }
            }
            .onChange(of: isLive) { _, live in
                if live { shown = model.stats.recent }
            }
        }
    }

    private static let topID = "top"
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
