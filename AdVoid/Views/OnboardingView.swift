import SwiftUI

/// Explains what AdVoid does before the paywall, shown once on first launch.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let symbol: String
        let tint: Color
        let title: String
        let body: String
    }

    private let pages = [
        Page(symbol: "shield.lefthalf.filled", tint: .green,
             title: "Block ads in every app",
             body: "AdVoid stops apps and websites from reaching ad and tracker servers, so ads load less and you're followed less. It works across your whole iPhone, not just in one browser."),
        Page(symbol: "lock.iphone", tint: .blue,
             title: "Stays on your iPhone",
             body: "AdVoid uses a VPN that runs only on your iPhone and only checks which addresses apps look up. Your browsing isn't sent to us or anyone else. iOS will ask you to allow it the first time you turn protection on."),
        Page(symbol: "safari", tint: .orange,
             title: "YouTube and Instagram in Safari",
             body: "Some ads come from the same servers as the videos and posts, so no app can block them inside the YouTube and Instagram apps. Turn on the AdVoid Safari extension and use those sites in Safari to skip them."),
    ]

    private var isLast: Bool { page == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    PageView(page: pages[index]).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.primary : Color.secondary.opacity(0.3))
                        .frame(width: index == page ? 20 : 8, height: 8)
                }
            }
            .animation(.snappy, value: page)
            .padding(.bottom, 24)

            Button {
                if isLast { onFinish() } else { withAnimation { page += 1 } }
            } label: {
                Text(isLast ? "Get started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(.green)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    private struct PageView: View {
        let page: Page

        var body: some View {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: page.symbol)
                    .font(.system(size: 64, weight: .semibold))
                    .foregroundStyle(page.tint)
                    .frame(width: 140, height: 140)
                    .background(page.tint.opacity(0.12), in: .circle)
                VStack(spacing: 12) {
                    Text(page.title)
                        .font(.title.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(page.body)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    OnboardingView {}
}
