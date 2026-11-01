import SwiftUI
import Clarity

private let ink = Color(red: 0.12, green: 0.14, blue: 0.25)
private let blue = Color(red: 0.20, green: 0.28, blue: 0.88)
private let pink = Color(red: 0.98, green: 0.77, blue: 0.86)
private let yellow = Color(red: 0.98, green: 0.92, blue: 0.54)
private let paper = Color(red: 0.97, green: 0.97, blue: 0.99)

@main
struct FormaApp: App {
    @StateObject private var replay = ReplayController()
    var body: some Scene {
        WindowGroup {
            ShopView().environmentObject(replay).tint(blue).preferredColorScheme(.light)
                .task {
                    if !ProcessInfo.processInfo.arguments.contains("-disableClarity") { replay.start() }
                }
        }
    }
}

@MainActor
final class ReplayController: ObservableObject {
    @Published var projectID = UserDefaults.standard.string(forKey: "clarityProjectID") ?? "yvieorzea5"
    @Published var status = "Recording is off"
    @Published var started = false
    @Published var paused = false
    @Published var sessionURL: URL?
    @Published var attempted = false

    func start() {
        guard !attempted else { return }
        let id = projectID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.range(of: "^[a-z0-9]+$", options: .regularExpression) != nil else {
            status = "Paste the project ID, not the dashboard URL."
            return
        }
        projectID = id
        UserDefaults.standard.set(id, forKey: "clarityProjectID")
        attempted = true
        status = "Connecting to Clarity…"
        ClaritySDK.setOnSessionStartedCallback { [weak self] _ in
            guard let self else { return }
            self.started = true
            self.status = "Session started • upload not yet verified"
            self.sessionURL = ClaritySDK.getCurrentSessionUrl().flatMap(URL.init(string:))
            print("Forma Clarity session started: \(self.sessionURL?.absoluteString ?? "URL pending")")
            ClaritySDK.setCustomTag(key: "demo", value: "advoid-forma")
            ClaritySDK.setCustomUserId("forma-demo")
        }
        if !ClaritySDK.initialize(config: ClarityConfig(projectId: id, logLevel: .verbose)) {
            status = "Could not initialize. Check your ID and relaunch to retry."
        }
    }

    func togglePause() {
        if paused { ClaritySDK.resume() } else { ClaritySDK.pause() }
        paused.toggle()
        status = paused ? "Recording paused" : "Session resumed • upload not yet verified"
    }

    func newTake() {
        guard started else { return }
        status = "Starting a new take…"
        if !ClaritySDK.startNewSession(callback: { [weak self] _ in
            self?.sessionURL = ClaritySDK.getCurrentSessionUrl().flatMap(URL.init(string:))
            self?.status = "New session started • upload not yet verified"
            ClaritySDK.setCustomTag(key: "demo", value: "advoid-forma")
            ClaritySDK.setCustomUserId("forma-demo")
        }) { status = "Could not start a new session. Try again shortly." }
    }

    func event(_ name: String) {
        guard started, !paused else { return }
        ClaritySDK.sendCustomEvent(value: name)
    }
}

struct Product: Identifiable, Hashable {
    let id: Int
    let name: String
    let category: String
    let price: Int
    let symbol: String
    let shade: Int
    var color: Color {
        [Color(red: 0.87, green: 0.89, blue: 1.0), pink,
         Color(red: 0.99, green: 0.95, blue: 0.73), Color(red: 0.90, green: 0.85, blue: 0.97)][shade]
    }
    static let all = [
        Product(id: 1, name: "Everyday tote", category: "Carry", price: 38, symbol: "bag.fill", shade: 0),
        Product(id: 2, name: "Slow morning mug", category: "Home", price: 24, symbol: "cup.and.saucer.fill", shade: 1),
        Product(id: 3, name: "Studio headphones", category: "Tech", price: 129, symbol: "headphones", shade: 2),
        Product(id: 4, name: "Weekend backpack", category: "Carry", price: 78, symbol: "backpack.fill", shade: 3),
        Product(id: 5, name: "Reading light", category: "Home", price: 56, symbol: "lamp.desk.fill", shade: 0),
        Product(id: 6, name: "Pocket camera", category: "Tech", price: 149, symbol: "camera.fill", shade: 1)
    ]
}

struct ProductArt: View {
    let product: Product
    var large = false
    var body: some View {
        ZStack {
            product.color
            Circle().fill(.white.opacity(0.25)).frame(width: large ? 245 : 125).offset(x: 35, y: -20)
            Image(systemName: product.symbol)
                .font(.system(size: large ? 115 : 65, weight: .regular))
                .foregroundStyle(blue.opacity(0.85))
                .rotationEffect(.degrees(-10))
                .shadow(color: blue.opacity(0.10), radius: 0, x: 5, y: 7)
        }.frame(height: large ? 300 : 172).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ShopView: View {
    @EnvironmentObject private var replay: ReplayController
    @State private var tab = "Discover"
    @State private var category = "All"
    @State private var query = ""
    @State private var favorites: Set<Int> = []
    @State private var cart: [Int: Int] = [:]
    @State private var selected: Product?
    @State private var setup = false
    @State private var checkout = false
    private var count: Int { cart.values.reduce(0, +) }
    private var total: Int { Product.all.reduce(0) { $0 + $1.price * (cart[$1.id] ?? 0) } }
    private var visible: [Product] {
        Product.all.filter {
            (tab != "Saved" || favorites.contains($0.id)) &&
            (category == "All" || $0.category == category || tab == "Saved") &&
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query))
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                HStack(spacing: 12) {
                    Text("ADS").font(.system(size: 30, weight: .black, design: .rounded))
                        .tracking(-1).foregroundStyle(blue)
                        .padding(.horizontal, 11).padding(.vertical, 3)
                        .background(yellow, in: RoundedRectangle(cornerRadius: 9))
                        .rotationEffect(.degrees(-4))
                    Text("A little out\nof the ordinary.").font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ink.opacity(0.65))
                }
                Spacer()
                Button { setup = true } label: {
                    Image(systemName: "slider.horizontal.3").font(.title3).frame(width: 44, height: 44)
                        .foregroundStyle(blue).background(.white, in: Circle())
                }.accessibilityLabel("Demo settings")
            }.padding(.horizontal, 24).padding(.bottom, 14)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if tab == "Bag" { bag }
                    else {
                        if tab == "Discover" { hero }
                        else { Text("Your favorites.").font(.system(size: 32, weight: .bold, design: .rounded)) }
                        HStack {
                            Image(systemName: "magnifyingglass")
                            TextField("Find your next favorite", text: $query)
                                .submitLabel(.search).clarityMask()
                                .onSubmit { replay.event("search_submitted") }
                            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") } }
                        }.font(.subheadline).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 15))
                        if tab == "Discover" {
                            HStack(spacing: 10) {
                                ForEach(["All", "Home", "Carry", "Tech"], id: \.self) { item in
                                    Button { category = item; replay.event("category_" + item.lowercased()) } label: {
                                        Text(item).font(.system(size: 13, weight: .medium)).padding(.horizontal, 18).padding(.vertical, 11)
                                            .background(category == item ? blue : .white, in: Capsule())
                                            .foregroundStyle(category == item ? .white : ink)
                                    }
                                }
                            }
                        }
                        HStack {
                            Text(tab == "Saved" ? "Worth coming back for" : "The everyday edit").font(.system(size: 22, weight: .bold, design: .rounded))
                            Spacer()
                            Text("\(visible.count) pieces").font(.caption).foregroundStyle(.secondary)
                        }
                        if visible.isEmpty {
                            Text(tab == "Saved" ? "Tap a heart to save something you love." : "No pieces found. Try another search.")
                                .foregroundStyle(.secondary).padding(.vertical, 40)
                        }
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 22) {
                            ForEach(visible) { product in
                                VStack(alignment: .leading, spacing: 7) {
                                    Button { selected = product; replay.event("view_product_\(product.id)") } label: {
                                        ProductArt(product: product)
                                    }.accessibilityIdentifier("product_\(product.id)").overlay(alignment: .topTrailing) {
                                        Button { toggleFavorite(product) } label: {
                                            Image(systemName: favorites.contains(product.id) ? "heart.fill" : "heart")
                                                .font(.system(size: 14)).foregroundStyle(favorites.contains(product.id) ? blue : ink)
                                                .frame(width: 32, height: 32).background(favorites.contains(product.id) ? pink : .white.opacity(0.9), in: Circle())
                                        }.accessibilityLabel("Save \(product.name)").padding(10)
                                    }
                                    Text(product.name).font(.system(size: 14, weight: .semibold, design: .rounded))
                                    Text("$\(product.price)").font(.system(size: 13, weight: .semibold)).foregroundStyle(blue)
                                }
                            }
                        }
                        Text("Good finds. A little personality. Very you.").font(.caption).foregroundStyle(.secondary).padding(.vertical, 16)
                    }
                }.padding(24)
            }
            HStack(spacing: 0) {
                tabButton("Discover", icon: "square.grid.2x2")
                tabButton("Saved", icon: "heart")
                tabButton("Bag", icon: "bag", suffix: count > 0 ? " (\(count))" : "")
            }.padding(.top, 14).padding(.bottom, 8).background(.white)
        }
        .foregroundStyle(ink).background(paper)
        .sheet(isPresented: $setup) { SetupView().environmentObject(replay) }
        .sheet(item: $selected) { product in
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Text("THE ADS COLLECTION").font(.caption).tracking(2)
                    Spacer()
                    Button { selected = nil } label: { Image(systemName: "xmark").padding(10) }.accessibilityLabel("Close product")
                }
                ProductArt(product: product, large: true)
                HStack {
                    Text(product.name).font(.system(size: 30, weight: .bold, design: .rounded))
                    Spacer()
                    Text("$\(product.price)").font(.title2)
                }
                Text("A little less ordinary. A thoughtfully designed essential to make the everyday feel good.")
                    .foregroundStyle(.secondary).lineSpacing(5)
                Label("Free delivery on orders over $75", systemImage: "shippingbox").font(.subheadline)
                Spacer()
                Button {
                    cart[product.id, default: 0] += 1
                    replay.event("add_to_bag_\(product.id)")
                    selected = nil
                } label: { Text("Add to bag  ·  $\(product.price)").frame(maxWidth: .infinity).padding(18) }
                    .background(blue, in: Capsule()).foregroundStyle(.white)
            }.padding(24).padding(.top, 12).background(paper).foregroundStyle(ink)
        }
        .alert("You're all set", isPresented: $checkout) {
            Button("Keep exploring", role: .cancel) { cart = [:]; tab = "Discover" }
        } message: { Text("This was a demo order. No payment was taken.") }
    }
    private var hero: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("THE GOOD STUFF").font(.system(size: 10, weight: .bold)).tracking(1.7)
                    .foregroundStyle(blue).padding(.horizontal, 12).padding(.vertical, 8)
                    .background(yellow, in: Capsule()).rotationEffect(.degrees(-3))
                Spacer()
                Image(systemName: "sparkle").font(.system(size: 28, weight: .medium)).foregroundStyle(pink)
                    .rotationEffect(.degrees(12)).accessibilityHidden(true)
            }
            Text("Everyday finds.\nExtra personality.")
                .font(.system(size: 34, weight: .heavy, design: .rounded)).tracking(-1.2)
                .fixedSize(horizontal: false, vertical: true)
            Text("Little things worth making room for.")
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.85))
        }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, alignment: .leading)
            .background(blue, in: RoundedRectangle(cornerRadius: 24))
    }
    private var bag: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Your bag.").font(.system(size: 36, weight: .bold, design: .rounded))
            Text(count == 0 ? "A little room for something good." : "Good choices. All in one place.").foregroundStyle(.secondary)
            ForEach(Product.all.filter { cart[$0.id, default: 0] > 0 }) { product in
                HStack(spacing: 16) {
                    Image(systemName: product.symbol).font(.system(size: 32)).frame(width: 80, height: 90)
                        .background(product.color, in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 10) {
                        Text(product.name).font(.system(size: 15, weight: .medium))
                        Text("$\(product.price)").font(.subheadline)
                        HStack(spacing: 18) {
                            Button { cart[product.id, default: 0] -= 1; replay.event("remove_from_bag") } label: { Image(systemName: "minus.circle") }
                                .accessibilityLabel("Remove one \(product.name)")
                            Text("\(cart[product.id, default: 0])").monospacedDigit()
                            Button { cart[product.id, default: 0] += 1; replay.event("increase_quantity") } label: { Image(systemName: "plus.circle") }
                                .accessibilityLabel("Add one \(product.name)")
                        }
                    }
                    Spacer()
                }
            }
            if count > 0 {
                Divider()
                HStack { Text("Subtotal"); Spacer(); Text("$\(total)") }.font(.title3.bold())
                Text("Demo checkout • no payment details needed").font(.caption).foregroundStyle(.secondary)
                Button { replay.event("demo_checkout_completed"); checkout = true } label: {
                    Text("Place demo order").frame(maxWidth: .infinity).padding(18)
                }.background(blue, in: Capsule()).foregroundStyle(.white)
            }
        }
    }
    private func toggleFavorite(_ product: Product) {
        if favorites.contains(product.id) { favorites.remove(product.id) } else { favorites.insert(product.id) }
        replay.event("favorite_\(product.id)")
    }
    private func tabButton(_ name: String, icon: String, suffix: String = "") -> some View {
        Button {
            tab = name; query = ""
            replay.event("tab_" + name.lowercased())
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon + (tab == name ? ".fill" : "")).font(.system(size: 20))
                    .frame(width: 54, height: 30)
                    .background(tab == name ? yellow.opacity(0.6) : .clear, in: Capsule())
                Text(name + suffix).font(.system(size: 10, weight: .medium))
            }.frame(maxWidth: .infinity).foregroundStyle(tab == name ? blue : .gray)
        }
    }
}

struct SetupView: View {
    @EnvironmentObject private var replay: ReplayController
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Connect your demo") {
                    Text("This demo can send your activity inside Ads to Microsoft Clarity for session replay. Use fictional interactions for filming.")
                    TextField("Clarity project ID", text: $replay.projectID)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().clarityMask()
                        .disabled(replay.attempted)
                    if !replay.attempted {
                        Button("Start recording this demo") { replay.start() }
                    }
                    Text(replay.status).font(.footnote)
                    if replay.attempted && !replay.started {
                        Text("If this stays here, check the project ID, internet connection, and Clarity support for your iOS version. Relaunch Ads to retry.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
                if replay.started {
                    Section("Filming controls") {
                        Button(replay.paused ? "Resume recording" : "Pause recording") { replay.togglePause() }
                        Button("Start a new take") { replay.newTake() }.disabled(replay.paused)
                        if let url = replay.sessionURL {
                            Link("Open this session in Clarity", destination: url)
                            ShareLink("Share session link", item: url)
                        }
                        Text("Session started means the SDK is running. Confirm the replay in Clarity before filming your dashboard.").font(.footnote)
                    }
                }
                Section("Quick setup") {
                    Link("Create a free Clarity mobile project", destination: URL(string: "https://clarity.microsoft.com/")!)
                    Text("Choose a mobile app project. Copy its project ID from Settings → Overview and paste it above. Stay on Wi-Fi while filming.")
                    Text("Browse → save a favorite → open a product → add to bag → place a demo order. Full replays can take up to two hours to appear.")
                    Text("Recording starts automatically for your configured project. Use Pause recording to stop capture. Clarity is installed only in this separate demo app.")
                }.font(.subheadline)
            }.navigationTitle("Demo setup")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }.tint(blue)
    }
}
