# AdVoid

Network-level ad and tracker blocker for iOS. A local packet-tunnel VPN that only
carries DNS: blocked domains get `0.0.0.0` / `::`, everything else is relayed to the
chosen upstream resolver. No traffic leaves the phone except ordinary DNS lookups.

- `AdVoid/` – SwiftUI app: on/off, stats, activity log, blocklists, allow/block rules
- `PacketTunnel/` – `NEPacketTunnelProvider` DNS filter and upstream forwarder
- `SafariExtension/` – Safari web extension for what DNS can't reach: strips ad data from
  YouTube player responses, skips any ad that still plays, hides YouTube ad slots, and
  reports counts to the app. Test the page script with
  `node SafariExtension/Tests/youtube-main.test.mjs`.
- `Shared/` – packet/DNS parsing, blocklist parser, hashed domain matcher, stats

Blocklists are compiled into sorted 64-bit hashes in the app group and memory-mapped
by the extension (~1.8 MB for 230k domains), keeping it far under the extension memory limit.

The project is generated with XcodeGen: edit `project.yml`, then run `xcodegen generate`.
Packet tunnels don't run in the Simulator; test on a device. Launch a Debug build with
`-demoStats` to fill the Stats tab with sample data.
