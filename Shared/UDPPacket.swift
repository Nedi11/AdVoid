import Foundation

/// An IPv4 UDP datagram read from, or written to, the tunnel's packet flow.
struct UDPPacket: Equatable {
    var sourceAddress: [UInt8]
    var destinationAddress: [UInt8]
    var sourcePort: UInt16
    var destinationPort: UInt16
    var payload: [UInt8]

    init(sourceAddress: [UInt8], destinationAddress: [UInt8], sourcePort: UInt16, destinationPort: UInt16, payload: [UInt8]) {
        self.sourceAddress = sourceAddress
        self.destinationAddress = destinationAddress
        self.sourcePort = sourcePort
        self.destinationPort = destinationPort
        self.payload = payload
    }

    init?(ipv4 data: Data) {
        let bytes = [UInt8](data)
        guard bytes.count >= 28, bytes[0] >> 4 == 4 else { return nil }
        let headerLength = Int(bytes[0] & 0x0F) * 4
        let totalLength = Int(bytes.uint16(at: 2))
        guard headerLength >= 20, totalLength <= bytes.count, totalLength >= headerLength + 8 else { return nil }
        guard bytes[9] == 17 else { return nil }                   // UDP
        guard bytes.uint16(at: 6) & 0x3FFF == 0 else { return nil } // not a fragment

        let udpLength = Int(bytes.uint16(at: headerLength + 4))
        guard udpLength >= 8, headerLength + udpLength <= totalLength else { return nil }

        sourceAddress = Array(bytes[12..<16])
        destinationAddress = Array(bytes[16..<20])
        sourcePort = bytes.uint16(at: headerLength)
        destinationPort = bytes.uint16(at: headerLength + 2)
        payload = Array(bytes[(headerLength + 8)..<(headerLength + udpLength)])
    }

    /// A packet going back the way this one came, carrying `payload`.
    func reply(with payload: [UInt8]) -> UDPPacket {
        UDPPacket(sourceAddress: destinationAddress, destinationAddress: sourceAddress,
                  sourcePort: destinationPort, destinationPort: sourcePort, payload: payload)
    }

    func ipv4Data() -> Data {
        let udpLength = 8 + payload.count
        let totalLength = 20 + udpLength

        var header: [UInt8] = [0x45, 0x00]
        header.appendUInt16(UInt16(totalLength))
        header += [0x00, 0x00, 0x00, 0x00]  // identification, flags, fragment offset
        header += [64, 17, 0x00, 0x00]      // TTL, protocol UDP, checksum placeholder
        header += sourceAddress
        header += destinationAddress
        header.setUInt16(Self.checksum(header), at: 10)

        var udp: [UInt8] = []
        udp.appendUInt16(sourcePort)
        udp.appendUInt16(destinationPort)
        udp.appendUInt16(UInt16(udpLength))
        udp.appendUInt16(0)
        udp += payload

        var pseudo = sourceAddress + destinationAddress + [0, 17]
        pseudo.appendUInt16(UInt16(udpLength))
        let udpChecksum = Self.checksum(pseudo + udp)
        udp.setUInt16(udpChecksum == 0 ? 0xFFFF : udpChecksum, at: 6)

        return Data(header + udp)
    }

    /// RFC 1071 internet checksum.
    static func checksum(_ bytes: [UInt8]) -> UInt16 {
        var sum: UInt32 = 0
        var i = 0
        while i + 1 < bytes.count {
            sum += UInt32(bytes[i]) << 8 | UInt32(bytes[i + 1])
            i += 2
        }
        if i < bytes.count { sum += UInt32(bytes[i]) << 8 }
        while sum >> 16 != 0 { sum = (sum & 0xFFFF) + (sum >> 16) }
        return ~UInt16(sum)
    }
}
