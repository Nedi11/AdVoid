import SwiftUI

struct HomeView: View {
    @Environment(TunnelController.self) private var tunnel
    @Environment(BlocklistManager.self) private var lists
    @Environment(StatsModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    PowerButton(isOn: tunnel.isOn, isBusy: tunnel.status == .connecting || tunnel.status == .disconnecting) {
                        Task { await tunnel.toggle() }
                    }
                    .padding(.top, 24)

                    VStack(spacing: 6) {
                        Text(tunnel.statusText)
                            .font(.title2.weight(.semibold))
                        Text(tunnel.isOn
                             ? "Ads and trackers are blocked in every app."
                             : "Tap to block ads and trackers across your iPhone.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    if let error = tunnel.lastError {
                        Label(error, systemImage: "exclamationmark.triangle.fill")
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(title: "Blocked today", value: model.stats.blockedToday.formatted(), tint: .red)
                        StatTile(title: "Lookups today", value: model.stats.queriesToday.formatted(), tint: .blue)
                        StatTile(title: "Blocked share", value: "\(model.blockedPercent)%", tint: .orange)
                        StatTile(title: "Blocked all time", value: model.stats.blockedAllTime.formatted(), tint: .purple)
                    }

                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("\(lists.totalDomains.formatted()) domains on the blocklist")
                        Spacer()
                        if lists.isUpdating { ProgressView() }
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .navigationTitle("AdVoid")
        }
    }
}

private struct PowerButton: View {
    let isOn: Bool
    let isBusy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isOn ? Color.green.gradient : Color.gray.opacity(0.25).gradient)
                    .frame(width: 180, height: 180)
                    .shadow(color: isOn ? .green.opacity(0.45) : .clear, radius: 24)
                if isBusy {
                    ProgressView().controlSize(.large).tint(.white)
                } else {
                    Image(systemName: isOn ? "checkmark.shield.fill" : "shield.slash")
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(isOn ? .white : .secondary)
                }
            }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact, trigger: isOn)
        .animation(.spring(duration: 0.35), value: isOn)
        .accessibilityLabel(isOn ? "Turn protection off" : "Turn protection on")
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.title.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText())
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.background.secondary, in: .rect(cornerRadius: 16))
    }
}
