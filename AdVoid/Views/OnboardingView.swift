import SwiftUI

/// Explains what AdVoid does before the paywall, shown once on first launch.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0

    struct Page {
        let symbol: String
        let tint: Color
        let title: String
        let body: String
    }

    private let pages = [
        Page(symbol: "shield.fill", tint: .green,
             title: "Goodbye, ads",
             body: "AdVoid blocks ad and tracker domains across your apps and websites."),
        Page(symbol: "lock.fill", tint: .blue,
             title: "Private by design",
             body: "Blocking happens on your iPhone. We never see what you browse."),
        Page(symbol: "hand.tap.fill", tint: .purple,
             title: "Tap Allow",
             body: "Your iPhone will ask to add a VPN. Tap Allow so AdVoid can work."),
        Page(symbol: "play.rectangle.fill", tint: .red,
             title: "Some ads stay",
             body: "YouTube and a few other apps send ads from the same servers as their videos. Blocking them would break the app."),
    ]

    private var isLast: Bool { page == pages.count - 1 }
    private var tint: Color { pages[page].tint }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    PageView(page: pages[index], isCurrent: index == page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? tint : Color.secondary.opacity(0.25))
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .padding(.bottom, 28)

            Button {
                if isLast { onFinish() } else { page += 1 }
            } label: {
                Text(isLast ? "Let's go" : "Next")
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .controlSize(.large)
            .tint(tint)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            HStack(spacing: 20) {
                Link("Privacy", destination: AppLinks.privacy)
                Link("Terms", destination: AppLinks.terms)
                Link("Support", destination: AppLinks.support)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.bottom, 8)
        }
        .background {
            LinearGradient(colors: [tint.opacity(0.22), tint.opacity(0.04), .clear],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .animation(.smooth(duration: 0.45), value: page)
    }

    private struct PageView: View {
        let page: Page
        let isCurrent: Bool

        var body: some View {
            VStack(spacing: 32) {
                Spacer()
                Image(systemName: page.symbol)
                    .font(.system(size: 76, weight: .bold))
                    .foregroundStyle(.white)
                    .symbolEffect(.bounce, value: isCurrent)
                    .frame(width: 160, height: 160)
                    .background(page.tint.gradient, in: .rect(cornerRadius: 44))
                    .shadow(color: page.tint.opacity(0.4), radius: 24, y: 12)
                    .scaleEffect(isCurrent ? 1 : 0.8)
                VStack(spacing: 14) {
                    Text(page.title)
                        .font(.largeTitle.weight(.heavy))
                    Text(page.body)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .opacity(isCurrent ? 1 : 0)
                .offset(y: isCurrent ? 0 : 16)
                Spacer()
                Spacer()
            }
            .padding(.horizontal, 32)
            .animation(.spring(duration: 0.5, bounce: 0.35), value: isCurrent)
        }
    }
}

#Preview {
    OnboardingView {}
}
