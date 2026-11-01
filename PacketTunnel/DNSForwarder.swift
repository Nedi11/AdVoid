import Foundation
import Network
import os

/// Relays allowed queries to the upstream resolver, encrypted with DNS-over-HTTPS.
///
/// When DoH can't be reached (a network that blocks it, say) and plain fallback is allowed,
/// queries go over one UDP socket for a while before DoH is tried again. There, each query
/// gets a fresh transaction ID so replies can be matched back to the app that asked, then
/// the original ID is restored. Without fallback, the asking app gets SERVFAIL instead.
final class DNSForwarder {
    private struct Pending {
        let packet: UDPPacket
        let originalID: UInt16
        let sentAt: DispatchTime
    }

    private static let timeout: DispatchTimeInterval = .seconds(5)
    /// How long to stay on plain DNS after DoH fails before trying it again.
    private static let fallbackPeriod: DispatchTimeInterval = .seconds(60)

    private let log = Logger(subsystem: "com.roxuh.advoid", category: "dns")
    private let upstream: UpstreamDNS
    private let host: NWEndpoint.Host
    private let allowsPlainFallback: Bool
    private let queue: DispatchQueue
    private let deliver: (UDPPacket) -> Void
    private let session: URLSession
    private var inFlight = 0
    private var plainUntil: DispatchTime?
    private var isStopped = false
    private var connection: NWConnection?
    private var pending: [UInt16: Pending] = [:]
    private var sweepTimer: DispatchSourceTimer?

    init(upstream: UpstreamDNS, allowsPlainFallback: Bool, queue: DispatchQueue, deliver: @escaping (UDPPacket) -> Void) {
        self.upstream = upstream
        self.host = NWEndpoint.Host(upstream.address)
        self.allowsPlainFallback = allowsPlainFallback
        self.queue = queue
        self.deliver = deliver

        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 3
        config.waitsForConnectivity = false
        config.urlCache = nil
        // Completions run on `queue`, like everything else here.
        let completions = OperationQueue()
        completions.underlyingQueue = queue
        completions.maxConcurrentOperationCount = 1
        session = URLSession(configuration: config, delegate: nil, delegateQueue: completions)
    }

    /// Call on `queue`.
    func start() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.dropExpired() }
        timer.resume()
        sweepTimer = timer
    }

    /// Call on `queue`.
    func stop() {
        isStopped = true
        session.invalidateAndCancel()
        sweepTimer?.cancel()
        sweepTimer = nil
        connection?.cancel()
        connection = nil
        pending.removeAll()
    }

    /// Call on `queue`.
    func forward(_ packet: UDPPacket) {
        guard packet.payload.count >= 12 else { return }
        if let plainUntil, plainUntil > .now() {
            sendPlain(packet)
        } else {
            sendEncrypted(packet)
        }
    }

    // MARK: - DNS-over-HTTPS

    private func sendEncrypted(_ packet: UDPPacket) {
        guard inFlight < 512 else { return }
        var request = URLRequest(url: upstream.dohURL)
        request.httpMethod = "POST"
        request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
        request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
        request.httpBody = Data(packet.payload)

        inFlight += 1
        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self, !isStopped else { return }
            inFlight -= 1
            // The resolver echoes the query's ID, so the answer goes straight back.
            if let data, data.count >= 12, (response as? HTTPURLResponse)?.statusCode == 200 {
                deliver(packet.reply(with: [UInt8](data)))
            } else {
                encryptedFailed(packet, error: error)
            }
        }.resume()
    }

    private func encryptedFailed(_ packet: UDPPacket, error: Error?) {
        if allowsPlainFallback {
            if (plainUntil ?? .now()) <= .now() {
                log.notice("DNS-over-HTTPS failed (\(error?.localizedDescription ?? "bad response")); using plain DNS for a while")
            }
            plainUntil = .now() + Self.fallbackPeriod
            sendPlain(packet)
        } else if let query = DNSQuery(packet.payload) {
            deliver(packet.reply(with: query.failureResponse()))
        }
    }

    // MARK: - Plain DNS fallback

    private func sendPlain(_ packet: UDPPacket) {
        guard pending.count < 4096 else { return }
        var query = packet.payload
        let originalID = query.uint16(at: 0)

        var id = UInt16.random(in: .min ... .max)
        while pending[id] != nil { id = UInt16.random(in: .min ... .max) }
        query.setUInt16(id, at: 0)
        pending[id] = Pending(packet: packet, originalID: originalID, sentAt: .now())

        if connection == nil { connect() }
        connection?.send(content: Data(query), completion: .idempotent)
    }

    private func connect() {
        let connection = NWConnection(host: host, port: 53, using: .udp)
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            switch state {
            case .failed, .cancelled:
                guard let self, let connection, connection === self.connection else { return }
                self.connection = nil
            default:
                break
            }
        }
        // Switching between Wi-Fi and cellular leaves the old socket on a dead path.
        connection.betterPathUpdateHandler = { [weak self, weak connection] hasBetterPath in
            guard hasBetterPath, let self, let connection, connection === self.connection else { return }
            connection.cancel()
            self.connection = nil
        }
        self.connection = connection
        connection.start(queue: queue)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receiveMessage { [weak self, weak connection] data, _, _, error in
            guard let self, let connection else { return }
            if let data { handleResponse([UInt8](data)) }
            if error == nil, connection === self.connection { receive(on: connection) }
        }
    }

    private func handleResponse(_ response: [UInt8]) {
        guard response.count >= 12 else { return }
        var response = response
        guard let query = pending.removeValue(forKey: response.uint16(at: 0)) else { return }
        response.setUInt16(query.originalID, at: 0)
        deliver(query.packet.reply(with: response))
    }

    private func dropExpired() {
        let cutoff = DispatchTime.now() - Self.timeout
        pending = pending.filter { $0.value.sentAt > cutoff }
    }
}
