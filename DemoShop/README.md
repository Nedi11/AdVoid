# Ads — session replay demo

A standalone fictional shopping app for filming the AdVoid ad. Clarity is linked only to this app, not AdVoid. No real checkout or payment processing exists.

## Run

Open `FormaDemo.xcodeproj` in Xcode. Select the FormaDemo scheme and an iPhone simulator or connected iPhone, then Run. For a physical phone, use your development team in Signing & Capabilities. The project uses the same team as AdVoid. Requires iOS 17 or later; Clarity currently documents support through iOS 27.

## Clarity connection (configured)

Project `yvieorzea5` is built in. Recording starts automatically when Ads launches. The setup screen provides pause/resume and a session link.

To use another project:

1. Sign in at https://clarity.microsoft.com and create a **mobile app** project.
2. Copy the project ID from **Settings → Overview**.
3. In Ads, tap the sliders button at the top right, paste the ID, and tap **Start recording this demo**.
4. Tap Done, browse products, save a favorite, add to bag, and place a demo order.
5. Return to Demo setup and choose **Open this session in Clarity** or share its link to your Mac. Confirm the actual replay appears; successful SDK initialization alone does not prove upload.

The ID is saved locally for convenience. Recording starts automatically on launch. Use Pause recording to stop capture. Launch with `-disableClarity` to edit the project ID before starting or to run offline tests. Use Wi-Fi: Clarity defaults to unmetered-network uploads. Completed recordings may take up to two hours to appear. Sessions carry the custom tag `demo=advoid-forma` and the fictional user ID `forma-demo`.

The search and project-ID fields are masked. Product visuals and catalog text use the project's masking settings. No real personal or payment data is needed.

## Suggested ad sequence

- Browse the collection, favorite the tote, open it, and add it to the bag.
- Show the same actions in the real Clarity replay on your Mac.
- If demonstrating AdVoid blocking, use a **physical iPhone**. AdVoid's packet tunnel cannot run in Simulator.
- First capture a baseline replay with AdVoid off. Then enable AdVoid and inspect the actual blocked requests while generating a separate take.
- Do not equate “no replay yet” with successful blocking: dashboard delay, upload configuration, and connectivity can produce the same symptom. Verify the relevant domain is blocked and confirm the baseline.
- Describe this as replay of activity **inside this app**, not recording the entire phone. A DNS blocker can block listed upload destinations; it does not remove or disable an embedded recording SDK.

## Development

SDK: Microsoft Clarity 4.1.2, pinned through Swift Package Manager.

Regenerate the Xcode project with `xcodegen generate --spec DemoShop/project.yml` from the repository root. ShoppingFlowTests exercises favorites, cart arithmetic, mock checkout, category filtering, and empty-ID validation without sending data to Clarity.

Official references:
- https://learn.microsoft.com/en-us/clarity/mobile-sdk/ios-sdk
- https://learn.microsoft.com/en-us/clarity/mobile-sdk/mobile-sdk-overview
