import Charts
import SwiftUI

struct StatsView: View {
    @Environment(StatsModel.self) private var model
    @Environment(TunnelController.self) private var tunnel

    private var stats: Stats { model.stats }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        Figure(value: stats.blockedAllTime.formatted(), title: "Blocked all time")
                        Figure(value: stats.queriesAllTime.formatted(), title: "Lookups all time")
                        Figure(value: "\(allTimePercent)%", title: "Blocked share")
                        Figure(value: model.safariTotal.formatted(), title: "Safari ads removed")
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Since \(stats.since.formatted(date: .abbreviated, time: .omitted))")
                }

                Section("Today by hour") {
                    HourlyChart(stats: stats)
                        .frame(height: 180)
                        .padding(.vertical, 8)
                }

                Section("Blocked per day, last 30 days") {
                    DailyChart(days: stats.days)
                        .frame(height: 160)
                        .padding(.vertical, 8)
                }

                RankedSection(title: "Top blocked", rows: stats.topBlocked(10).map { ($0.domain, $0.count) },
                              empty: "Nothing blocked yet.")

                RankedSection(title: "Companies blocked",
                              rows: TrackerCompanies.top(from: stats.blockedCounts, limit: 8).map { ($0.company, $0.count) },
                              empty: "No known tracking companies blocked yet.",
                              footer: "Grouped from blocked domains that belong to well-known ad and analytics companies.")

                RankedSection(title: "Most used", rows: stats.topAllowed(10).map { ($0.domain, $0.count) },
                              empty: "No lookups yet.",
                              footer: "Domains your apps looked up most that weren't blocked.",
                              color: ChartColor.allowed)

                if !model.safariCounts.isEmpty {
                    RankedSection(title: "Removed in Safari",
                                  rows: model.safariCounts.sorted { $0.value > $1.value }.map { (SafariCountLabel.name(for: $0.key), $0.value) },
                                  empty: "")
                }
            }
            .navigationTitle("Stats")
            .toolbar {
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Reset stats", systemImage: "arrow.counterclockwise", role: .destructive) {
                        model.reset(via: tunnel)
                    }
                }
            }
        }
    }

    private var allTimePercent: Int {
        guard stats.queriesAllTime > 0 else { return 0 }
        return Int((Double(stats.blockedAllTime) / Double(stats.queriesAllTime) * 100).rounded())
    }
}

enum SafariCountLabel {
    static func name(for key: String) -> String {
        switch key {
        case "youtubeAdsSkipped": "YouTube ads skipped"
        case "youtubeAdsStripped": "YouTube ads stripped"
        case "youtubeSlotsHidden": "YouTube ad slots hidden"
        case "instagramSponsoredHidden": "Instagram sponsored posts"
        default: key
        }
    }
}

/// Colors validated for colorblind separation and contrast in both appearances.
enum ChartColor {
    static let allowed = Color(light: 0x2A78D6, dark: 0x3987E5)
    static let blocked = Color(light: 0xEB6834, dark: 0xD95926)
}

private extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}

private struct Figure: View {
    let value: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .contentTransition(.numericText())
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }
}

private struct HourlyChart: View {
    let stats: Stats
    @State private var selectedDate: Date?

    private struct Bar: Identifiable {
        let hour: Int
        let date: Date
        let kind: String
        let count: Int
        var id: String { "\(hour)-\(kind)" }
    }

    private var startOfDay: Date { Calendar.current.startOfDay(for: Date()) }

    private func date(forHour hour: Int) -> Date {
        Calendar.current.date(byAdding: .hour, value: hour, to: startOfDay) ?? startOfDay
    }

    private var bars: [Bar] {
        (0..<24).flatMap { hour in [
            Bar(hour: hour, date: date(forHour: hour), kind: "Blocked", count: stats.hourlyBlocked[hour]),
            Bar(hour: hour, date: date(forHour: hour), kind: "Allowed", count: stats.hourlyQueries[hour] - stats.hourlyBlocked[hour]),
        ] }
    }

    private var selectedHour: Int? {
        selectedDate.map { Calendar.current.component(.hour, from: $0) }
    }

    var body: some View {
        Chart {
            ForEach(bars) { bar in
                BarMark(x: .value("Hour", bar.date, unit: .hour), y: .value("Lookups", bar.count))
                    .foregroundStyle(by: .value("Kind", bar.kind))
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: bar.kind == "Allowed" ? 3 : 0,
                                                      topTrailingRadius: bar.kind == "Allowed" ? 3 : 0))
            }
            if let selectedHour {
                RuleMark(x: .value("Hour", date(forHour: selectedHour), unit: .hour))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        tooltip(for: selectedHour)
                    }
            }
        }
        .chartForegroundStyleScale(["Allowed": ChartColor.allowed, "Blocked": ChartColor.blocked])
        .chartXScale(domain: startOfDay...date(forHour: 24))
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                AxisValueLabel(format: .dateTime.hour())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartLegend(position: .top, alignment: .leading)
    }

    private func tooltip(for hour: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(date(forHour: hour).formatted(.dateTime.hour()))–\(date(forHour: hour + 1).formatted(.dateTime.hour()))")
                .font(.caption.weight(.semibold))
            Text("\(stats.hourlyBlocked[hour]) blocked").font(.caption)
            Text("\(stats.hourlyQueries[hour]) lookups").font(.caption).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.background, in: .rect(cornerRadius: 8))
        .shadow(color: .black.opacity(0.12), radius: 4)
    }
}

private struct DailyChart: View {
    let days: [DaySummary]
    @State private var selectedDate: Date?

    private var selected: DaySummary? {
        guard let selectedDate else { return nil }
        return days.first { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }
    }

    var body: some View {
        Chart {
            ForEach(days) { day in
                BarMark(x: .value("Day", day.date, unit: .day), y: .value("Blocked", day.blocked))
                    .foregroundStyle(ChartColor.blocked)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 3, topTrailingRadius: 3))
            }
            if let selected {
                RuleMark(x: .value("Day", selected.date, unit: .day))
                    .foregroundStyle(.secondary.opacity(0.3))
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.date, format: .dateTime.month().day()).font(.caption.weight(.semibold))
                            Text("\(selected.blocked) blocked of \(selected.queries)").font(.caption)
                        }
                        .padding(8)
                        .background(.background, in: .rect(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.12), radius: 4)
                    }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: max(1, days.count / 5))) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(.quaternary)
                AxisValueLabel()
            }
        }
        .chartXSelection(value: $selectedDate)
    }
}

private struct RankedSection: View {
    let title: String
    let rows: [(String, Int)]
    let empty: String
    var footer: String?
    var color: Color = ChartColor.blocked

    var body: some View {
        Section {
            if rows.isEmpty {
                Text(empty).foregroundStyle(.secondary)
            }
            let maxCount = rows.map(\.1).max() ?? 1
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("\(index + 1)").font(.caption.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 18, alignment: .leading)
                        Text(row.0).font(.subheadline).lineLimit(1).truncationMode(.middle)
                        Spacer()
                        Text(row.1.formatted()).font(.subheadline.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    GeometryReader { geo in
                        Capsule()
                            .fill(color)
                            .frame(width: max(4, geo.size.width * CGFloat(row.1) / CGFloat(maxCount)))
                    }
                    .frame(height: 4)
                    .padding(.leading, 26)
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text(title)
        } footer: {
            if let footer { Text(footer) }
        }
    }
}
