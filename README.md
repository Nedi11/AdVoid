# Shield

Network-level ad and tracker blocker for iOS. A local packet-tunnel VPN that only
carries DNS: blocked domains get `0.0.0.0` / `::`, everything else is relayed to the
chosen upstream resolver. No traffic leaves the phone except ordinary DNS lookups.

- `Shield/` – SwiftUI app: on/off, stats, activity log, blocklists, allow/block rules
- `PacketTunnel/` – `NEPacketTunnelProvider` DNS filter and upstream forwarder
- `Shared/` – packet/DNS parsing, blocklist parser, hashed domain matcher, stats

Blocklists are compiled into sorted 64-bit hashes in the app group and memory-mapped
by the extension (~1.8 MB for 230k domains), keeping it far under the extension memory limit.

The project is generated with XcodeGen: edit `project.yml`, then run `xcodegen generate`.
Packet tunnels don't run in the Simulator; test on a device.
