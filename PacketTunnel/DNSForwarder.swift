import Foundation
import Network

/// Relays allowed queries to the upstream resolver over one UDP socket.
/// Each query gets a fresh transaction ID so replies can be matched back to
/// the app that asked, then the original ID is restored.
final class DNSForwarder {
    private struct Pending {
        let packet: UDPPacket
        let originalID: UInt16
        let sentAt: DispatchTime
    }

    private static let timeout: DispatchTimeInterval = .seconds(5)

    private let upstream: NWEndpoint.Host
    private let queue: DispatchQueue
    private let deliver: (UDPPacket) -> Void
    private var connection: NWConnection?
    private var pending: [UInt16: Pending] = [:]
    private var sweepTimer: DispatchSourceTimer?

    init(upstream: String, queue: DispatchQueue, deliver: @escaping (UDPPacket) -> Void) {
        self.upstream = NWEndpoint.Host(upstream)
        self.queue = queue
        self.deliver = deliver
    }

    /// Call on `queue`.
    func start() {
        connect()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2)
        timer.setEventHandler { [weak self] in self?.dropExpired() }
        timer.resume()
        sweepTimer = timer
    }

    /// Call on `queue`.
    func stop() {
        sweepTimer?.cancel()
        sweepTimer = nil
        connection?.cancel()
        connection = nil
        pending.removeAll()
    }

    /// Call on `queue`.
    func forward(_ packet: UDPPacket) {
        guard packet.payload.count >= 12, pending.count < 4096 else { return }
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
        let connection = NWConnection(host: upstream, port: 53, using: .udp)
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
