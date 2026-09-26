import Foundation

/// The single question of a DNS query, plus what's needed to answer it.
struct DNSQuery {
    static let typeA: UInt16 = 1
    static let typeAAAA: UInt16 = 28

    let id: UInt16
    let flags: UInt16
    let name: String
    let type: UInt16
    /// Offset just past the question section (after QTYPE and QCLASS).
    let questionEnd: Int
    let bytes: [UInt8]

    init?(_ bytes: [UInt8]) {
        guard bytes.count >= 12 else { return nil }
        let flags = bytes.uint16(at: 2)
        // Standard queries only (QR = 0, OPCODE = 0) with exactly one question.
        guard flags & 0x8000 == 0, (flags >> 11) & 0xF == 0, bytes.uint16(at: 4) == 1 else { return nil }

        var labels: [String] = []
        var offset = 12
        var nameLength = 0
        while true {
            guard offset < bytes.count else { return nil }
            let length = Int(bytes[offset])
            offset += 1
            if length == 0 { break }
            // Queries don't use name compression; anything else isn't worth parsing.
            guard length & 0xC0 == 0, offset + length <= bytes.count else { return nil }
            nameLength += length + 1
            guard nameLength <= 255 else { return nil }
            labels.append(String(decoding: bytes[offset..<offset + length], as: UTF8.self))
            offset += length
        }
        guard offset + 4 <= bytes.count else { return nil }

        self.id = bytes.uint16(at: 0)
        self.flags = flags
        self.name = labels.joined(separator: ".").lowercased()
        self.type = bytes.uint16(at: offset)
        self.questionEnd = offset + 4
        self.bytes = bytes
    }

    /// A NOERROR answer pointing A/AAAA at 0.0.0.0 / :: so the connection fails
    /// instantly. Other record types (HTTPS, SVCB, …) get an empty answer, which
    /// also stops HTTPS records from leaking IP hints for blocked hosts.
    func blockedResponse(ttl: UInt32 = 60) -> [UInt8] {
        let addressLength: Int? = switch type {
        case Self.typeA: 4
        case Self.typeAAAA: 16
        default: nil
        }

        var out: [UInt8] = []
        out.reserveCapacity(questionEnd + 32)
        out.appendUInt16(id)
        out.appendUInt16(0x8000 | (flags & 0x0100) | 0x0080) // QR, copy RD, RA, NOERROR
        out.appendUInt16(1)                                    // QDCOUNT
        out.appendUInt16(addressLength == nil ? 0 : 1)         // ANCOUNT
        out.appendUInt16(0)                                    // NSCOUNT
        out.appendUInt16(0)                                    // ARCOUNT
        out.append(contentsOf: bytes[12..<questionEnd])

        if let addressLength {
            out.append(contentsOf: [0xC0, 0x0C])               // pointer to the question name
            out.appendUInt16(type)
            out.appendUInt16(1)                                // class IN
            out.appendUInt16(UInt16(ttl >> 16))
            out.appendUInt16(UInt16(ttl & 0xFFFF))
            out.appendUInt16(UInt16(addressLength))
            out.append(contentsOf: repeatElement(0, count: addressLength))
        }
        return out
    }
}

extension Array where Element == UInt8 {
    func uint16(at offset: Int) -> UInt16 {
        UInt16(self[offset]) << 8 | UInt16(self[offset + 1])
    }

    mutating func appendUInt16(_ value: UInt16) {
        append(UInt8(value >> 8))
        append(UInt8(value & 0xFF))
    }

    mutating func setUInt16(_ value: UInt16, at offset: Int) {
        self[offset] = UInt8(value >> 8)
        self[offset + 1] = UInt8(value & 0xFF)
    }
}
