import NetworkExtension
import os

/// A DNS-only tunnel. The system sends every DNS query to `TunnelAddress.dns`,
/// which is the only route into the tunnel; everything else bypasses it.
/// Blocked names are answered locally, the rest are relayed upstream.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let log = Logger(subsystem: "com.roxuh.shield", category: "tunnel")
    private let queue = DispatchQueue(label: "com.roxuh.shield.tunnel")
    private var rules = FilterRules.load()
    private var forwarder: DNSForwarder?
    private let stats = StatsRecorder()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")

        let ipv4 = NEIPv4Settings(addresses: [TunnelAddress.local], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: TunnelAddress.dns, subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4

        let dns = NEDNSSettings(servers: [TunnelAddress.dns])
        dns.matchDomains = [""] // use this resolver for every domain
        settings.dnsSettings = dns
        settings.mtu = 1500

        let forwarder = DNSForwarder(upstream: UpstreamDNS.current.address, queue: queue) { [weak self] packet in
            self?.write(packet)
        }
        self.forwarder = forwarder

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self else { return }
            if let error {
                log.error("Failed to apply tunnel settings: \(error.localizedDescription)")
                completionHandler(error)
                return
            }
            queue.async {
                forwarder.start()
                self.stats.start(on: self.queue)
            }
            log.info("Tunnel started with \(self.rules.blocklist.count) blocked domains")
            readPackets()
            completionHandler(nil)
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        queue.async {
            self.forwarder?.stop()
            self.forwarder = nil
            self.stats.stop()
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        let message = String(decoding: messageData, as: UTF8.self)
        queue.async {
            switch TunnelMessage(rawValue: message) {
            case .reloadRules:
                self.rules = FilterRules.load()
                self.log.info("Reloaded rules: \(self.rules.blocklist.count) blocked domains")
            case .resetStats:
                self.stats.reset()
            case nil:
                break
            }
            completionHandler?(nil)
        }
    }

    private func readPackets() {
        packetFlow.readPackets { [weak self] packets, _ in
            guard let self else { return }
            queue.async {
                for packet in packets { self.handle(packet) }
            }
            readPackets()
        }
    }

    private func handle(_ data: Data) {
        guard let packet = UDPPacket(ipv4: data), packet.destinationPort == 53 else { return }
        guard let query = DNSQuery(packet.payload) else {
            forwarder?.forward(packet)
            return
        }

        if rules.isBlocked(query.name) {
            write(packet.reply(with: query.blockedResponse()))
            stats.record(domain: query.name, blocked: true)
        } else {
            forwarder?.forward(packet)
            stats.record(domain: query.name, blocked: false)
        }
    }

    private func write(_ packet: UDPPacket) {
        packetFlow.writePackets([packet.ipv4Data()], withProtocols: [NSNumber(value: AF_INET)])
    }
}

struct FilterRules {
    let blocklist: DomainMatcher
    let allowlist: DomainMatcher

    static func load() -> FilterRules {
        FilterRules(blocklist: DomainMatcher(contentsOf: AppGroup.blocklistURL),
                    allowlist: DomainMatcher(contentsOf: AppGroup.allowlistURL))
    }

    func isBlocked(_ domain: String) -> Bool {
        !allowlist.matches(domain) && blocklist.matches(domain)
    }
}
